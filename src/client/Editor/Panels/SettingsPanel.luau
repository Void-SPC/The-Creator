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

	-- время суток и смена дня и ночи
	local lt = project.settings.lighting or {}
	Kit.slider(list, L.TimeOfDay, lt.clockTime or 14, 0, 24, function(v)
		set({ "settings", "lighting", "clockTime" }, math.floor(v * 4 + 0.5) / 4 % 24)
	end, 8)
	Kit.toggle(list, L.DayNight, lt.dayNight == true, function(v)
		set({ "settings", "lighting", "dayNight" }, v)
	end, 9)
	Kit.stepper(list, L.DayLength, lt.dayMinutes or 12, 1, 1, 240, function(v)
		set({ "settings", "lighting", "dayMinutes" }, v)
	end, 10)
	Kit.label(list, H.DayNightHint, { TextColor3 = Kit.C.dim, TextSize = 13, LayoutOrder = 11, Size = UDim2.new(1, 0, 0, 40) })

	-- погода
	local w = project.settings.weather or { type = "Clear", auto = false, minutes = 5 }
	local titles = { Clear = L.WeatherClear, Rain = L.WeatherRain, Snow = L.WeatherSnow, Fog = L.WeatherFog, Storm = L.WeatherStorm }
	local _, wSlot = Kit.row(list, L.Weather, 12)
	Kit.button(wSlot, titles[w.type] or L.WeatherClear, function()
		local opts = {}
		for _, id in { "Clear", "Rain", "Snow", "Fog", "Storm" } do
			table.insert(opts, { id = id, title = titles[id] })
		end
		Kit.choose(editor.gui, L.Weather, opts, function(id)
			set({ "settings", "weather" }, { type = id, auto = w.auto == true, minutes = w.minutes or 5 })
			editor:renderPanel()
		end)
	end)
	Kit.toggle(list, L.WeatherAuto, w.auto == true, function(v)
		set({ "settings", "weather" }, { type = w.type or "Clear", auto = v, minutes = w.minutes or 5 })
	end, 13)
	Kit.stepper(list, L.WeatherMinutes, w.minutes or 5, 1, 1, 120, function(v)
		set({ "settings", "weather" }, { type = w.type or "Clear", auto = w.auto == true, minutes = v })
	end, 14)

	-- музыка карты
	local m = project.settings.music
	Kit.textbox(list, if m then m.id else "", L.Music, function(text)
		local id = string.match(text, "(%d+)")
		if id then
			set({ "settings", "music" }, { id = id, volume = if m then m.volume else 0.5 })
		elseif text == "" then
			set({ "settings", "music" }, nil)
		end
		editor:renderPanel()
	end, { LayoutOrder = 15 })
	if m then
		Kit.slider(list, L.MusicVolume, m.volume, 0, 1, function(v)
			set({ "settings", "music", "volume" }, v)
		end, 16)
	end
	return nil
end

return SettingsPanel
