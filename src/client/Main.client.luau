--!nonstrict
-- Точка входа клиента «The Castle»: меню, замок, мафия, админ-панель, язык и настройки

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local Remotes = require(Shared.Roblox.Remotes)
local Lang = require(Shared.Lang)

local Menu = require(script.Parent.Castle.Menu)
local CastleClient = require(script.Parent.Castle.CastleClient)
local AdminPanel = require(script.Parent.Castle.AdminPanel)
local MafiaClient = require(script.Parent.Mafia.MafiaClient)

local player = Players.LocalPlayer

local function castleRequest(...)
	local ok, res = pcall(function(...)
		return Remotes.fn("CastleRequest"):InvokeServer(...)
	end, ...)
	return if ok then res else nil
end

local app: any = {
	playerGui = player:WaitForChild("PlayerGui"),
	lang = "en",
	settings = { volume = 1, music = 0.6, footsteps = true, bob = 0.8, sensitivity = 1, fov = 75, shadows = true, effects = true },
	-- режим для MafiaClient: витрины больше нет, из мафии всегда можно выйти в меню
	mode = { creator = false, showcase = nil },
	castle = nil,
	mafia = nil,
	onLangChanged = {},
}

function app.T(key: string, ...)
	return Lang.t(app.lang, key, ...)
end

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

-- профиль: язык и настройки, сохранённые на сервере
local prof = castleRequest("Profile")
if prof and prof.ok then
	if prof.lang == "en" or prof.lang == "ru" then
		app.lang = prof.lang
	end
	if type(prof.settings) == "table" then
		for k, v in prof.settings do
			if app.settings[k] ~= nil and type(app.settings[k]) == type(v) then
				app.settings[k] = v
			end
		end
	end
end

app.menu = Menu.new(app)

function app:setLang(lang: string)
	self.lang = lang
	castleRequest("SetLang", lang)
	self.menu:build()
	for _, fn in self.onLangChanged do
		pcall(fn)
	end
	if self.castle then
		-- подписи HUD пересобираются на новом языке
		self.castle:refresh()
		self.castle:refreshInventory()
		self.castle:localizePrompts()
		self.castle.menuBtn.Text = self.T("Menu")
		self.castle.rolesBtn.Text = self.T("Roles")
		self.castle.kingBtn.Text = self.T("KingPanel")
	end
end

function app:applySettings()
	if self.castle then
		self.castle:applySettings()
	end
end

function app:saveSettings()
	castleRequest("SaveSettings", self.settings)
end

function app:sheetClosed()
	if self.castle then
		self.castle.camera:setFreeCursor(false)
	end
end

function app:play()
	if self.castle then
		return
	end
	local res = castleRequest("Enter")
	if not res or not res.ok then
		return
	end
	self.menu:setVisible(false)
	self.castle = CastleClient.new(self)
	pcall(function()
		TextChatService.ChatInputBarConfiguration.TargetTextChannel = nil
	end)
end

function app:backToMenu()
	castleRequest("Leave")
	if self.castle then
		self.castle:destroy()
		self.castle = nil
	end
	self.menu:setVisible(true)
end

function app:openMafia()
	if self.castle then
		self.castle:destroy()
		self.castle = nil
	end
	self.menu:setVisible(false)
	self.mafia = MafiaClient.new(self)
	local ok, res = pcall(function()
		return Remotes.fn("MafiaRequest"):InvokeServer("Join")
	end)
	if not ok or not res or not res.ok then
		self:leaveMafia()
	end
end

-- вызывается из MafiaClient кнопкой «Выйти из мафии»
function app:leaveMafia()
	if self.mafia then
		self.mafia:destroy()
		self.mafia = nil
	end
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	self.menu:setVisible(true)
end

-- после смерти в замке игрок остаётся в замке; меню показывается только при входе
task.spawn(AdminPanel.mount, app)
