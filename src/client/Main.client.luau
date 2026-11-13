--!nonstrict
-- Точка входа клиента мастерской: меню, редактор и игра

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local Remotes = require(Shared.Roblox.Remotes)
local UiText = require(Shared.UiText)

local Kit = require(script.Parent.UI.Kit)
local Menu = require(script.Parent.UI.Menu)
local AdminButton = require(script.Parent.UI.AdminButton)
local Editor = require(script.Parent.Editor.Editor)
local PlayClient = require(script.Parent.Play.PlayClient)
local MafiaClient = require(script.Parent.Mafia.MafiaClient)

local player = Players.LocalPlayer

local app: any = {
	playerGui = player:WaitForChild("PlayerGui"),
	editor = nil,
	play = nil,
	pendingLogicErrors = {},
}

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

app.mode = { creator = false, showcase = nil }
app.menu = Menu.new(app)

-- Заставка на время входа в витрину: игрок не видит меню создателя
local splash = Instance.new("ScreenGui")
splash.Name = "WsSplash"
splash.ResetOnSpawn = false
splash.IgnoreGuiInset = true
splash.DisplayOrder = 30
splash.Enabled = true -- до ответа сервера меню не показываем
splash.Parent = app.playerGui
app.menu:setVisible(false)
do
	local bg = Kit.frame(splash, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Kit.C.bg })
	Kit.label(bg, UiText.L.Loading, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0.5, -20), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 20 })
end

local function applyMode(mode)
	app.mode = mode
	local hideMenu = mode.showcase ~= nil and not mode.creator
	if hideMenu then
		if app.editor then
			app.editor:destroy()
			app.editor = nil
		end
		app.menu:setVisible(false)
		splash.Enabled = app.play == nil and app.mafia == nil
	else
		splash.Enabled = false
		if not app.editor and not app.play then
			app.menu:setVisible(true)
		end
		app.menu:updateShowcase()
	end
end

-- создатель из витрины переходит в своё меню
function app:openCreatorMenu()
	Remotes.fn("Request"):InvokeServer("OpenCreatorMenu")
end

function app:openShowcase()
	if self.mode.showcase then
		self:joinByCode(self.mode.showcase.code)
	end
end

function app:openEditor(project, readOnly)
	if self.editor then
		self.editor:destroy()
	end
	self.menu:setVisible(false)
	self.editor = Editor.new(self, project, readOnly == true)
end

function app:openProject(projectId: string)
	local res = Remotes.fn("Request"):InvokeServer("OpenProject", projectId)
	if res and res.ok then
		self:openEditor(res.project, res.readOnly)
	else
		-- при ошибке загрузки ничего не создаём и ничего не перезаписываем
		self.menu:showError("load_failed")
	end
end

function app:closeEditor()
	Remotes.fn("Request"):InvokeServer("CloseProject")
	if self.editor then
		self.editor:destroy()
		self.editor = nil
	end
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	self.menu:setVisible(true)
end

-- «Мафия»: отдельный режим со своим экраном
local function openMafia()
	if app.mafia then
		return app.mafia
	end
	if app.editor then
		app.editor:destroy()
		app.editor = nil
	end
	if app.play then
		app.play:destroy()
		app.play = nil
	end
	app.menu:setVisible(false)
	splash.Enabled = false
	app.mafia = MafiaClient.new(app)
	return app.mafia
end

function app:joinMafia()
	Remotes.fn("Request"):InvokeServer("CloseProject")
	openMafia()
	local ok, res = pcall(function()
		return Remotes.fn("MafiaRequest"):InvokeServer("Join")
	end)
	if not ok or not res or not res.ok then
		self:leaveMafia()
		self.menu:showError(nil)
	end
end

function app:leaveMafia()
	if self.mafia then
		self.mafia:destroy()
		self.mafia = nil
	end
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	self.menu:setVisible(true)
end

Remotes.event("Mafia").OnClientEvent:Connect(function(msg)
	-- сервер сам привёл игрока в мафию (например, «Мафия для всех»)
	if not app.mafia and type(msg) == "table" and msg.type == "state" then
		openMafia():onMessage(msg)
	end
end)

function app:joinByCode(code: string)
	if self.editor then
		self.editor:destroy()
		self.editor = nil
	end
	local res = Remotes.fn("Request"):InvokeServer("JoinByCode", code)
	if not res or not res.ok then
		self.menu:setVisible(true)
		self.menu:showError(res and res.error)
	end
end

function app:stopPlay()
	Remotes.fn("Request"):InvokeServer("StopPlay")
end

local function leavePlay()
	if app.play then
		app.play:destroy()
		app.play = nil
	end
	if app.mode.showcase and not app.mode.creator then
		-- игрок витрины не попадает в меню создателя: возвращаем его в карту
		splash.Enabled = true
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		Remotes.fn("Request"):InvokeServer("RejoinShowcase")
		return
	end
	if app.editor then
		-- вернулись из теста: ошибки сценария показываем в редакторе
		app.editor:setEnabled(true)
		if #app.pendingLogicErrors > 0 then
			app.editor.logicErrors = app.pendingLogicErrors
			app.pendingLogicErrors = {}
			app.editor:selectTab("logic")
			Kit.toast(app.editor.gui, UiText.H.LogicErrorHint, Kit.C.bad, 4)
		end
	else
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		app.menu:setVisible(true)
	end
end

Remotes.event("Play").OnClientEvent:Connect(function(msg)
	if type(msg) ~= "table" then
		return
	end
	if msg.type == "mode" then
		applyMode({ creator = msg.creator == true, showcase = msg.showcase })
		return
	end
	if msg.type == "enter" then
		splash.Enabled = false
		if app.play then
			app.play:destroy()
		end
		app.menu:setVisible(false)
		if app.editor then
			app.editor:setEnabled(false)
		end
		app.pendingLogicErrors = {}
		app.play = PlayClient.new(app, msg)
	elseif msg.type == "leave" then
		leavePlay()
	elseif app.play then
		app.play:onMessage(msg)
	end
end)

task.spawn(AdminButton.mount, app.playerGui)
task.spawn(function()
	local res = Remotes.fn("Request"):InvokeServer("Status")
	if res and res.ok then
		applyMode({ creator = res.creator == true, showcase = res.showcase })
	else
		applyMode({ creator = false, showcase = nil })
	end
end)
