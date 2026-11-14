--!nonstrict
-- Главное меню «The Castle»: название, маленькое RP в углу, Играть, Мафия, Настройки,
-- Как играть; переключатель EN и RU справа вверху. За меню камера медленно облетает замок

local RunService = game:GetService("RunService")

local Ui = require(script.Parent.Ui)

local Menu = {}
Menu.__index = Menu

function Menu.new(app)
	local self = setmetatable({}, Menu)
	self.app = app
	local gui = Instance.new("ScreenGui")
	gui.Name = "CastleMenu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = app.playerGui
	self.gui = gui
	self.t = 0
	self:build()
	self.conn = RunService.RenderStepped:Connect(function(dt)
		if not gui.Enabled then
			return
		end
		self.t += dt
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		local a = self.t * 0.04
		local pos = Vector3.new(math.sin(a) * 260, 95 + math.sin(self.t * 0.1) * 8, math.cos(a) * 300 - 20)
		cam.CFrame = CFrame.lookAt(pos, Vector3.new(0, 30, 10))
		cam.FieldOfView = 60
	end)
	return self
end

function Menu:build()
	local app = self.app
	local T = app.T
	self.gui:ClearAllChildren()
	local gui = self.gui
	-- затемнение снизу, чтобы кнопки читались поверх замка
	local fade = Ui.frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Ui.C.shade, BackgroundTransparency = 0.25 })
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 0.1) })
	grad.Parent = fade
	local v = Ui.viewport()
	local small = v.Y < 500
	local title = Ui.label(gui, T("Title"), {
		Font = Ui.TITLE,
		TextSize = if small then 52 else 78,
		TextColor3 = Ui.C.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, if small then 64 else 96),
		Position = UDim2.new(0, 0, if small then 0.08 else 0.14, 0),
	})
	local st = Instance.new("UIStroke")
	st.Color = Color3.new(0, 0, 0)
	st.Transparency = 0.4
	st.Thickness = 2
	st.Parent = title
	local col = Ui.frame(gui, { BackgroundTransparency = 1, Size = UDim2.fromOffset(math.min(300, v.X - 40), 4 * (Ui.TAP + 10)), Position = UDim2.new(0.5, -math.min(300, v.X - 40) / 2, if small then 0.34 else 0.42, 0) })
	Ui.list(col, 10)
	local function big(text, order, fn, accent)
		local b = Ui.button(col, text, fn, { LayoutOrder = order, TextSize = 19, Font = Ui.FONT_BOLD, BackgroundTransparency = 0.15, BackgroundColor3 = if accent then Ui.C.line else Ui.C.panel })
		return b
	end
	big(T("Play"), 1, function()
		app:play()
	end, true)
	big(T("Maniac"), 2, function()
		app:openManiac()
	end)
	big(T("Settings"), 3, function()
		self:openSettings()
	end)
	big(T("HowToPlay"), 4, function()
		self:openTutorial()
	end)
	-- язык: сначала английский, потом русский
	local langBox = Ui.frame(gui, { BackgroundTransparency = 1, Size = UDim2.fromOffset(2 * 56 + 6, 40), Position = UDim2.new(1, -2 * 56 - 18, 0, 12 + 36) })
	Ui.list(langBox, 6, true)
	for i, l in { "en", "ru" } do
		local b = Ui.button(langBox, string.upper(l), function()
			app:setLang(l)
		end, { Size = UDim2.fromOffset(56, 40), LayoutOrder = i, Font = Ui.FONT_BOLD })
		Ui.setActive(b, app.lang == l)
	end
	Ui.label(gui, T("Rp"), { Font = Ui.TITLE, TextSize = 22, TextColor3 = Ui.C.gold, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromOffset(80, 30), Position = UDim2.new(1, -96, 1, -42) })
end

function Menu:setVisible(on: boolean)
	self.gui.Enabled = on
	if not on then
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
	end
end

-- Настройки звука, камеры и графики; сохраняются в профиле игрока
function Menu.settingsSheet(app, gui: Instance)
	local T = app.T
	local s = app.settings
	local _, c = Ui.sheet(gui, T("Settings"), function()
		app:saveSettings()
		app:sheetClosed()
	end)
	local o = 0
	local function n()
		o += 1
		return o
	end
	Ui.slider(c, T("Volume"), s.volume, 0, 1, function(x)
		s.volume = x
		app:applySettings()
	end, n())
	Ui.slider(c, T("MusicVolume"), s.music, 0, 1, function(x)
		s.music = x
		app:applySettings()
	end, n())
	Ui.toggle(c, T("Footsteps"), s.footsteps, T("On"), T("Off"), function(x)
		s.footsteps = x
		app:applySettings()
	end, n())
	Ui.slider(c, T("CameraSway"), s.bob, 0, 1, function(x)
		s.bob = x
		app:applySettings()
	end, n())
	Ui.slider(c, T("Sensitivity"), s.sensitivity, 0.2, 2, function(x)
		s.sensitivity = x
		app:applySettings()
	end, n())
	Ui.slider(c, T("Fov"), s.fov, 60, 100, function(x)
		s.fov = x
		app:applySettings()
	end, n())
	Ui.toggle(c, T("Shadows"), s.shadows, T("On"), T("Off"), function(x)
		s.shadows = x
		app:applySettings()
	end, n())
	Ui.toggle(c, T("Effects"), s.effects, T("On"), T("Off"), function(x)
		s.effects = x
		app:applySettings()
	end, n())
	Ui.toggle(c, T("Language"), app.lang == "ru", "RU", "EN", function(x)
		app:setLang(if x then "ru" else "en")
	end, n())
end

function Menu:openSettings()
	Menu.settingsSheet(self.app, self.gui)
end

-- Обучение: несколько страниц на выбранном языке
function Menu.tutorialSheet(app, gui: Instance)
	local T = app.T
	local pages = {
		{ T("Title"), T("Welcome") },
		{ T("Roles"), T("Roles") },
		{ T("Food") .. " · " .. T("Drink"), T("Needs") },
		{ T("Take"), T("Inventory") },
		{ T("King"), T("KingTip") },
		{ T("Rp"), T("RulesTip") },
	}
	local i = 1
	local frame, content, close = Ui.sheet(gui, T("Tutorial"), function()
		app:sheetClosed()
	end, 460)
	local _ = frame
	local head = Ui.label(content, "", { Font = Ui.TITLE, TextSize = 24, TextColor3 = Ui.C.gold, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1, ZIndex = 43 })
	local body = Ui.label(content, "", { TextSize = 17, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, ZIndex = 43, TextYAlignment = Enum.TextYAlignment.Top })
	local counter = Ui.label(content, "", { TextColor3 = Ui.C.dim, TextSize = 14, LayoutOrder = 3, ZIndex = 43, TextXAlignment = Enum.TextXAlignment.Center })
	local row = Ui.frame(content, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Ui.TAP), LayoutOrder = 4, ZIndex = 43 })
	local function show()
		head.Text = pages[i][1]
		body.Text = pages[i][2]
		counter.Text = string.format("%d / %d", i, #pages)
	end
	Ui.button(row, T("Back"), function()
		i = math.max(1, i - 1)
		show()
	end, { Size = UDim2.new(0.5, -4, 1, 0), ZIndex = 43 })
	Ui.button(row, T("Next"), function()
		if i == #pages then
			close()
			return
		end
		i += 1
		show()
	end, { Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new(0.5, 4, 0, 0), ZIndex = 43, BackgroundColor3 = Ui.C.line })
	show()
end

function Menu:openTutorial()
	Menu.tutorialSheet(self.app, self.gui)
end

function Menu:destroy()
	self.conn:Disconnect()
	self.gui:Destroy()
end

return Menu
