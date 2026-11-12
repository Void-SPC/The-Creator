--!nonstrict
-- Вкладка «Камера»: камера от первого лица, полоска здоровья, название карты

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local UiText = require(Shared.UiText)
local Kit = require(script.Parent.Parent.Parent.UI.Kit)

local L, H = UiText.L, UiText.H

local SettingsPanel = {}

function SettingsPanel.render(editor, panel: Frame)
	local project = editor.state.project
	local cam = project.settings.camera
	local list = Kit.scroll(panel)
	Kit.list(list, 8)
	local function set(path, value)
		local ok, err = editor.state:apply({ op = "setProject", path = path, value = value })
		if not ok then
			Kit.toast(editor.gui, tostring(err), Kit.C.bad)
		end
	end
	Kit.textbox(list, project.meta.name, L.MapNamePlaceholder, function(text)
		if text ~= "" and text ~= project.meta.name then
			set({ "meta", "name" }, text)
		end
	end, { LayoutOrder = 1 })

	local modeRow = Kit.frame(list, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = 2 })
	local first = Kit.button(modeRow, L.CameraFirst, function()
		set({ "settings", "camera", "mode" }, "first")
		editor:renderPanel()
	end, { Size = UDim2.new(0.5, -3, 1, 0) })
	local default = Kit.button(modeRow, L.CameraDefault, function()
		set({ "settings", "camera", "mode" }, "default")
		editor:renderPanel()
	end, { Size = UDim2.new(0.5, -3, 1, 0), Position = UDim2.new(0.5, 3, 0, 0) })
	Kit.setActive(first, cam.mode == "first")
	Kit.setActive(default, cam.mode == "default")

	Kit.slider(list, L.Sensitivity, cam.sensitivity, 0.1, 3, function(v)
		set({ "settings", "camera", "sensitivity" }, math.max(v, 0.1))
	end, 3)
	Kit.slider(list, L.Fov, cam.fov, 50, 100, function(v)
		set({ "settings", "camera", "fov" }, math.floor(v + 0.5))
	end, 4)
	Kit.slider(list, L.Bob, cam.bob, 0, 2, function(v)
		set({ "settings", "camera", "bob" }, v)
	end, 5)
	Kit.label(list, H.BobHint, { TextColor3 = Kit.C.dim, TextSize = 13, LayoutOrder = 6 })
	Kit.toggle(list, L.HealthBar, project.settings.hud.health, function(v)
		set({ "settings", "hud", "health" }, v)
	end, 7)
	return nil
end

return SettingsPanel
