--!nonstrict
-- Оформление интерфейса замка: тёмное дерево, тёплое золото, крупные кнопки для пальца.
-- Все надписи приходят из Lang, здесь только элементы

local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Ui = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Ui.C = {
	shade = rgb(8, 6, 5),
	bg = rgb(18, 14, 12),
	panel = rgb(30, 24, 20),
	panel2 = rgb(48, 38, 30),
	line = rgb(120, 92, 56),
	text = rgb(242, 230, 208),
	dim = rgb(176, 160, 134),
	gold = rgb(226, 184, 96),
	red = rgb(176, 46, 46),
	health = rgb(196, 58, 58),
	food = rgb(214, 140, 60),
	drink = rgb(70, 140, 214),
	good = rgb(96, 170, 104),
}
Ui.FONT = Enum.Font.GothamMedium
Ui.FONT_BOLD = Enum.Font.GothamBold
Ui.TITLE = Enum.Font.Garamond
Ui.TAP = if UserInputService.TouchEnabled then 50 else 42

function Ui.viewport(): Vector2
	local cam = workspace.CurrentCamera
	return if cam then cam.ViewportSize else Vector2.new(1024, 768)
end

function Ui.corner(parent: Instance, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = parent
	return c
end

function Ui.stroke(parent: Instance, color: Color3?, t: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or Ui.C.line
	s.Thickness = t or 1
	s.Transparency = 0.2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Ui.pad(parent: Instance, p: number)
	local u = Instance.new("UIPadding")
	u.PaddingLeft = UDim.new(0, p)
	u.PaddingRight = UDim.new(0, p)
	u.PaddingTop = UDim.new(0, p)
	u.PaddingBottom = UDim.new(0, p)
	u.Parent = parent
	return u
end

function Ui.list(parent: Instance, gap: number?, horizontal: boolean?)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap or 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	if horizontal then
		l.FillDirection = Enum.FillDirection.Horizontal
	end
	l.Parent = parent
	return l
end

function Ui.frame(parent: Instance?, props): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Ui.C.panel
	f.BorderSizePixel = 0
	for k, v in props or {} do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

function Ui.label(parent: Instance?, text: string, props): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Ui.FONT
	l.TextColor3 = Ui.C.text
	l.TextSize = 16
	l.TextWrapped = true
	l.Text = text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Size = UDim2.new(1, 0, 0, 22)
	for k, v in props or {} do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

function Ui.button(parent: Instance?, text: string, onClick: (() -> ())?, props): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = Ui.C.panel2
	b.BorderSizePixel = 0
	b.Font = Ui.FONT
	b.TextColor3 = Ui.C.text
	b.TextSize = 16
	b.TextWrapped = true
	b.Text = text
	b.Size = UDim2.new(1, 0, 0, Ui.TAP)
	Ui.corner(b, 6)
	Ui.stroke(b)
	for k, v in props or {} do
		(b :: any)[k] = v
	end
	if onClick then
		b.Activated:Connect(onClick)
	end
	b.Parent = parent
	return b
end

function Ui.setActive(b: GuiObject, on: boolean)
	b.BackgroundColor3 = if on then Ui.C.line else Ui.C.panel2
end

-- Окно по центру экрана с заголовком и прокруткой. Возвращает (окно, содержимое, закрыть)
function Ui.sheet(gui: Instance, title: string, onClose: (() -> ())?, width: number?)
	local v = Ui.viewport()
	local w = math.min(width or 440, v.X - 24)
	local h = math.min(560, v.Y - 70)
	local shade = Instance.new("TextButton")
	shade.Name = "Sheet"
	shade.Text = ""
	shade.AutoButtonColor = false
	shade.BackgroundColor3 = Ui.C.shade
	shade.BackgroundTransparency = 0.4
	shade.Size = UDim2.fromScale(1, 1)
	shade.ZIndex = 40
	shade.Parent = gui
	local f = Ui.frame(shade, { Size = UDim2.fromOffset(w, h), Position = UDim2.new(0.5, -w / 2, 0.5, -h / 2), BackgroundColor3 = Ui.C.bg, ZIndex = 41 })
	Ui.corner(f, 10)
	Ui.stroke(f, Ui.C.gold, 1.5)
	Ui.label(f, title, { Font = Ui.TITLE, TextSize = 28, TextColor3 = Ui.C.gold, Size = UDim2.new(1, -70, 0, 44), Position = UDim2.fromOffset(16, 6), ZIndex = 42 })
	local function close()
		shade:Destroy()
		if onClose then
			onClose()
		end
	end
	Ui.button(f, "X", close, { Size = UDim2.fromOffset(Ui.TAP, Ui.TAP - 6), Position = UDim2.new(1, -Ui.TAP - 8, 0, 8), ZIndex = 43, Font = Ui.FONT_BOLD })
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.Size = UDim2.new(1, -24, 1, -64)
	s.Position = UDim2.fromOffset(12, 56)
	s.ScrollBarThickness = 5
	s.ScrollBarImageColor3 = Ui.C.line
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.ZIndex = 42
	s.Parent = f
	Ui.list(s, 8)
	Ui.pad(s, 2)
	return f, s, close
end

-- Выбор из списка поверх всего (игрок, вариант аргумента)
function Ui.choose(gui: Instance, title: string, options: { { id: any, title: string } }, onPick: (any) -> ())
	local _, content, close = Ui.sheet(gui, title, nil, 380)
	for i, o in options do
		Ui.button(content, o.title, function()
			close()
			onPick(o.id)
		end, { LayoutOrder = i, ZIndex = 43 })
	end
end

-- Ввод текста или числа
function Ui.prompt(gui: Instance, title: string, okText: string, onDone: (string) -> ())
	local _, content, close = Ui.sheet(gui, title, nil, 380)
	local box = Instance.new("TextBox")
	box.Text = ""
	box.PlaceholderText = ""
	box.ClearTextOnFocus = false
	box.Font = Ui.FONT
	box.TextSize = 16
	box.TextColor3 = Ui.C.text
	box.BackgroundColor3 = Ui.C.panel
	box.Size = UDim2.new(1, 0, 0, Ui.TAP)
	box.ZIndex = 43
	box.LayoutOrder = 1
	Ui.corner(box, 6)
	Ui.stroke(box)
	box.Parent = content
	Ui.button(content, okText, function()
		local t = box.Text
		close()
		onDone(t)
	end, { LayoutOrder = 2, ZIndex = 43, BackgroundColor3 = Ui.C.line })
end

-- Короткое сообщение вверху экрана
function Ui.toast(gui: Instance, text: string, color: Color3?, seconds: number?)
	local v = Ui.viewport()
	local w = math.min(480, v.X - 32)
	local size = TextService:GetTextSize(text, 16, Ui.FONT, Vector2.new(w - 24, 1000))
	local f = Ui.frame(gui, { Size = UDim2.fromOffset(w, size.Y + 20), Position = UDim2.new(0.5, -w / 2, 0, 70), BackgroundColor3 = color or Ui.C.panel, BackgroundTransparency = 0.1, ZIndex = 90 })
	Ui.corner(f, 8)
	Ui.stroke(f, Ui.C.line)
	Ui.label(f, text, { Size = UDim2.new(1, -24, 1, -20), Position = UDim2.fromOffset(12, 10), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 91 })
	task.delay(seconds or 3, function()
		f:Destroy()
	end)
	return f
end

-- Слайдер 0..1 (или lo..hi) для пальца
function Ui.slider(parent: Instance, title: string, value: number, lo: number, hi: number, onChange: (number) -> (), order: number)
	local row = Ui.frame(parent, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Ui.TAP), LayoutOrder = order })
	Ui.label(row, title, { Size = UDim2.new(0.42, -4, 1, 0), TextColor3 = Ui.C.dim, TextSize = 15, ZIndex = 43 })
	local bar = Ui.frame(row, { BackgroundColor3 = Ui.C.panel2, Size = UDim2.new(0.58, -50, 0, 8), Position = UDim2.new(0.42, 0, 0.5, -4), ZIndex = 43 })
	Ui.corner(bar, 4)
	local fill = Ui.frame(bar, { BackgroundColor3 = Ui.C.gold, Size = UDim2.fromScale(0, 1), ZIndex = 44 })
	Ui.corner(fill, 4)
	local val = Ui.label(row, "", { Size = UDim2.new(0, 46, 1, 0), Position = UDim2.new(1, -46, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 14, ZIndex = 43 })
	local function show(v)
		fill.Size = UDim2.fromScale(math.clamp((v - lo) / (hi - lo), 0, 1), 1)
		val.Text = if hi > 10 then string.format("%d", v) else string.format("%.1f", v)
	end
	show(value)
	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.new(0.58, -50, 1, 0)
	hit.Position = UDim2.new(0.42, 0, 0, 0)
	hit.ZIndex = 45
	hit.Parent = row
	local dragging, last = false, value
	local function at(x)
		local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
		local v = lo + (hi - lo) * a
		v = if hi > 10 then math.floor(v + 0.5) else math.floor(v * 10 + 0.5) / 10
		show(v)
		return v
	end
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			last = at(input.Position.X)
		end
	end)
	local c1 = UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			last = at(input.Position.X)
		end
	end)
	local c2 = UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			onChange(last)
		end
	end)
	row.Destroying:Connect(function()
		c1:Disconnect()
		c2:Disconnect()
	end)
	return row
end

function Ui.toggle(parent: Instance, title: string, value: boolean, onText: string, offText: string, onChange: (boolean) -> (), order: number)
	local row = Ui.frame(parent, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Ui.TAP), LayoutOrder = order })
	Ui.label(row, title, { Size = UDim2.new(0.42, -4, 1, 0), TextColor3 = Ui.C.dim, TextSize = 15, ZIndex = 43 })
	local state = value
	local b
	b = Ui.button(row, if state then onText else offText, function()
		state = not state
		b.Text = if state then onText else offText
		Ui.setActive(b, state)
		onChange(state)
	end, { Size = UDim2.new(0.58, 0, 1, -4), Position = UDim2.new(0.42, 0, 0, 2), ZIndex = 43 })
	Ui.setActive(b, state)
	return row
end

return Ui
