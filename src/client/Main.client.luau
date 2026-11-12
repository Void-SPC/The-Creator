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

app.menu = Menu.new(app)

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
	if msg.type == "enter" then
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
