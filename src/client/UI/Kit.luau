--!nonstrict
-- Небольшой набор элементов интерфейса, рассчитанный на касание:
-- кнопки не меньше 44 пикселей, крупный текст, прокрутка списков пальцем

local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")

local Kit = {}

Kit.C = {
	bg = Color3.fromRGB(22, 24, 30),
	panel = Color3.fromRGB(32, 35, 44),
	panel2 = Color3.fromRGB(42, 46, 58),
	line = Color3.fromRGB(60, 65, 80),
	text = Color3.fromRGB(235, 237, 242),
	dim = Color3.fromRGB(160, 166, 180),
	accent = Color3.fromRGB(88, 140, 255),
	accentDim = Color3.fromRGB(52, 78, 140),
	good = Color3.fromRGB(80, 190, 120),
	warn = Color3.fromRGB(240, 180, 60),
	bad = Color3.fromRGB(235, 80, 80),
}

local UIS = game:GetService("UserInputService")
-- на сенсорных экранах кнопки крупнее, чтобы попадать пальцем
Kit.TAP = if UIS.TouchEnabled then 52 else 44
local UiText = require(game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared"):WaitForChild("UiText"))
Kit.YES = UiText.L.Yes
local L_CANCEL = UiText.L.Cancel
local L_APPLY = UiText.L.Apply
local L_CUSTOM_COLOR = UiText.L.CustomColor
Kit.NO = UiText.L.No
Kit.FONT = Enum.Font.GothamMedium
Kit.FONT_BOLD = Enum.Font.GothamBold

function Kit.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

function Kit.viewport(): Vector2
	local cam = workspace.CurrentCamera
	return if cam then cam.ViewportSize else Vector2.new(1024, 768)
end

-- Компактный режим: телефон или узкое окно
function Kit.compact(): boolean
	local v = Kit.viewport()
	return v.X < 900 or v.Y < 520
end

local function corner(parent: Instance, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = parent
	return c
end
Kit.corner = corner

function Kit.pad(parent: Instance, p: number)
	local u = Instance.new("UIPadding")
	u.PaddingLeft = UDim.new(0, p)
	u.PaddingRight = UDim.new(0, p)
	u.PaddingTop = UDim.new(0, p)
	u.PaddingBottom = UDim.new(0, p)
	u.Parent = parent
	return u
end

function Kit.list(parent: Instance, gap: number?, horizontal: boolean?)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap or 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.Parent = parent
	return l
end

function Kit.frame(parent: Instance?, props: { [string]: any }?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Kit.C.panel
	f.BorderSizePixel = 0
	if props then
		for k, v in props do
			(f :: any)[k] = v
		end
	end
	f.Parent = parent
	return f
end

function Kit.label(parent: Instance?, text: string, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Kit.FONT
	l.TextColor3 = Kit.C.text
	l.TextSize = 16
	l.Text = text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Size = UDim2.new(1, 0, 0, 22)
	if props then
		for k, v in props do
			(l :: any)[k] = v
		end
	end
	l.Parent = parent
	return l
end

-- Заголовок и уточнение выводятся двумя строками, а не через точку
function Kit.titleBlock(parent: Instance?, title: string, subtitle: string?, order: number?)
	local f = Kit.frame(parent, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, if subtitle then 48 else 26), LayoutOrder = order or 0 })
	Kit.label(f, title, { Font = Kit.FONT_BOLD, TextSize = 18, Size = UDim2.new(1, 0, 0, 24) })
	if subtitle then
		Kit.label(f, subtitle, { TextColor3 = Kit.C.dim, TextSize = 14, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 20) })
	end
	return f
end

function Kit.button(parent: Instance?, text: string, onClick: (() -> ())?, props: { [string]: any }?): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = Kit.C.panel2
	b.BorderSizePixel = 0
	b.Font = Kit.FONT
	b.TextColor3 = Kit.C.text
	b.TextSize = 15
	b.TextWrapped = true
	b.Text = text
	b.Size = UDim2.new(1, 0, 0, Kit.TAP)
	corner(b)
	if props then
		for k, v in props do
			(b :: any)[k] = v
		end
	end
	if onClick then
		b.Activated:Connect(onClick)
	end
	b.Parent = parent
	return b
end

function Kit.setActive(b: GuiObject, active: boolean)
	b.BackgroundColor3 = if active then Kit.C.accent else Kit.C.panel2
end

function Kit.scroll(parent: Instance?, props: { [string]: any }?): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 6
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.Size = UDim2.fromScale(1, 1)
	s.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	if props then
		for k, v in props do
			(s :: any)[k] = v
		end
	end
	s.Parent = parent
	return s
end

function Kit.textbox(parent: Instance?, text: string, placeholder: string, onDone: ((string) -> ())?, props: { [string]: any }?): TextBox
	local t = Instance.new("TextBox")
	t.BackgroundColor3 = Kit.C.bg
	t.BorderSizePixel = 0
	t.Font = Kit.FONT
	t.TextColor3 = Kit.C.text
	t.PlaceholderColor3 = Kit.C.dim
	t.PlaceholderText = placeholder
	t.TextSize = 16
	t.Text = text
	t.ClearTextOnFocus = false
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Size = UDim2.new(1, 0, 0, Kit.TAP)
	corner(t, 6)
	Kit.pad(t, 8)
	if props then
		for k, v in props do
			(t :: any)[k] = v
		end
	end
	if onDone then
		t.FocusLost:Connect(function()
			onDone(t.Text)
		end)
	end
	t.Parent = parent
	return t
end

-- Подпись слева, элемент справа
function Kit.row(parent: Instance?, title: string, order: number?): (Frame, Frame)
	local r = Kit.frame(parent, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Kit.TAP), LayoutOrder = order or 0 })
	Kit.label(r, title, { Size = UDim2.new(0.42, -4, 1, 0), TextColor3 = Kit.C.dim, TextSize = 14 })
	local slot = Kit.frame(r, { BackgroundTransparency = 1, Position = UDim2.new(0.42, 0, 0, 0), Size = UDim2.new(0.58, 0, 1, 0) })
	return r, slot
end

function Kit.toggle(parent: Instance?, title: string, value: boolean, onChange: (boolean) -> (), order: number?)
	local _, slot = Kit.row(parent, title, order)
	local state = value
	local b
	b = Kit.button(slot, "", function()
		state = not state
		b.Text = if state then Kit.YES else Kit.NO
		Kit.setActive(b, state)
		onChange(state)
	end)
	b.Text = if state then Kit.YES else Kit.NO
	Kit.setActive(b, state)
	return b
end

-- Число с кнопками «−» и «+» и полем ввода (удобно пальцем)
function Kit.stepper(parent: Instance?, title: string, value: number, step: number, lo: number, hi: number, onChange: (number) -> (), order: number?)
	local _, slot = Kit.row(parent, title, order)
	local cur = value
	local box: TextBox
	local function fmt(v: number): string
		if v == math.floor(v) then
			return string.format("%d", v)
		end
		return string.format("%.2f", v)
	end
	local function set(v: number)
		v = math.clamp(math.floor(v / step * 1000 + 0.5) / 1000 * step, lo, hi)
		cur = v
		box.Text = fmt(v)
		onChange(v)
	end
	Kit.button(slot, "−", function()
		set(cur - step)
	end, { Size = UDim2.new(0, Kit.TAP, 1, 0) })
	box = Kit.textbox(slot, fmt(cur), "", function(t)
		local n = tonumber((string.gsub(t, ",", ".")))
		if n then
			set(n)
		else
			box.Text = fmt(cur)
		end
	end, { Position = UDim2.new(0, Kit.TAP + 4, 0, 0), Size = UDim2.new(1, -2 * Kit.TAP - 8, 1, 0), TextXAlignment = Enum.TextXAlignment.Center })
	Kit.button(slot, "+", function()
		set(cur + step)
	end, { Position = UDim2.new(1, -Kit.TAP, 0, 0), Size = UDim2.new(0, Kit.TAP, 1, 0) })
	return function(v: number)
		cur = v
		box.Text = fmt(v)
	end
end

-- Ползунок для пальца: перетаскивание по всей ширине
function Kit.slider(parent: Instance?, title: string, value: number, lo: number, hi: number, onChange: (number) -> (), order: number?)
	local _, slot = Kit.row(parent, title, order)
	local bar = Kit.frame(slot, { BackgroundColor3 = Kit.C.bg, Size = UDim2.new(1, -52, 0, 10), Position = UDim2.new(0, 0, 0.5, -5) })
	corner(bar, 5)
	local fill = Kit.frame(bar, { BackgroundColor3 = Kit.C.accent, Size = UDim2.fromScale(0, 1) })
	corner(fill, 5)
	local valueLabel = Kit.label(slot, "", { Size = UDim2.new(0, 48, 1, 0), Position = UDim2.new(1, -48, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 14 })
	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.new(1, -52, 1, 0)
	hit.Parent = slot
	local function show(v: number)
		local a = (v - lo) / (hi - lo)
		fill.Size = UDim2.fromScale(math.clamp(a, 0, 1), 1)
		valueLabel.Text = string.format("%.2f", v)
	end
	show(value)
	local dragging = false
	local function at(x: number)
		local a = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		local v = lo + (hi - lo) * a
		v = math.floor(v * 100 + 0.5) / 100
		show(v)
		return v
	end
	local last = value
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			last = at(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			last = at(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			onChange(last)
		end
	end)
	return show
end

-- Всплывающий список для выбора варианта
function Kit.choose(root: Instance, title: string, options: { { id: any, title: string, hint: string? } }, onPick: (any) -> ())
	local shade = Instance.new("TextButton")
	shade.Text = ""
	shade.AutoButtonColor = false
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.Size = UDim2.fromScale(1, 1)
	shade.ZIndex = 50
	shade.Parent = root
	local v = Kit.viewport()
	local w = math.min(380, v.X - 32)
	local h = math.min(#options * 50 + 70, v.Y - 60)
	local box = Kit.frame(shade, {
		Size = UDim2.fromOffset(w, h),
		Position = UDim2.new(0.5, -w / 2, 0.5, -h / 2),
		ZIndex = 51,
	})
	corner(box, 12)
	Kit.pad(box, 10)
	Kit.label(box, title, { Font = Kit.FONT_BOLD, TextSize = 17, ZIndex = 52, Size = UDim2.new(1, -50, 0, 28) })
	Kit.button(box, "✕", function()
		shade:Destroy()
	end, { Size = UDim2.fromOffset(40, 32), Position = UDim2.new(1, -40, 0, -2), ZIndex = 52 })
	local list = Kit.scroll(box, { Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 1, -36), ZIndex = 52 })
	Kit.list(list, 6)
	for i, o in options do
		local text = o.title
		if o.hint then
			text = o.title .. "\n" .. o.hint
		end
		Kit.button(list, text, function()
			shade:Destroy()
			onPick(o.id)
		end, { LayoutOrder = i, ZIndex = 53, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -8, 0, if o.hint then 52 else Kit.TAP) })
	end
	shade.Activated:Connect(function()
		shade:Destroy()
	end)
	return shade
end

-- Полная палитра: любой цвет. Квадрат насыщенности и яркости, полоса оттенка,
-- код цвета #RRGGBB и недавние цвета. Всё рассчитано на палец
Kit.recentColors = {} :: { { number } }

local function toRGB(c: Color3)
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end

function Kit.colorPicker(root: Instance, initial, onDone: ({ number }) -> ())
	local shade = Kit.frame(root, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 60 })
	local v = Kit.viewport()
	local w = math.min(380, v.X - 24)
	local box = Kit.frame(shade, { Size = UDim2.fromOffset(w, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0.5, -w / 2, 0, math.max(8, v.Y * 0.06)), ZIndex = 61 })
	corner(box, 14)
	Kit.pad(box, 12)
	Kit.list(box, 10)
	local start = initial or { 200, 200, 200 }
	local h, s, val = Color3.fromRGB(start[1], start[2], start[3]):ToHSV()

	local head = Kit.frame(box, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 1, ZIndex = 62 })
	Kit.label(head, L_CUSTOM_COLOR, { Font = Kit.FONT_BOLD, TextSize = 17, ZIndex = 62, Size = UDim2.new(1, -110, 1, 0) })
	local preview = Kit.frame(head, { Size = UDim2.fromOffset(100, 40), Position = UDim2.new(1, -100, 0, 2), ZIndex = 62 })
	corner(preview, 8)

	-- квадрат: слева направо насыщенность, снизу вверх яркость
	local sq = math.min(w - 24, math.floor(v.Y * 0.38))
	local square = Kit.frame(box, { Size = UDim2.fromOffset(w - 24, sq), LayoutOrder = 2, ZIndex = 62 })
	corner(square, 8)
	local white = Kit.frame(square, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 63 })
	corner(white, 8)
	local g1 = Instance.new("UIGradient")
	g1.Transparency = NumberSequence.new(0, 1)
	g1.Parent = white
	local black = Kit.frame(square, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 64 })
	corner(black, 8)
	local g2 = Instance.new("UIGradient")
	g2.Transparency = NumberSequence.new(1, 0)
	g2.Rotation = 90
	g2.Parent = black
	local dot = Kit.frame(square, { Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 66 })
	local ring = Instance.new("UIStroke")
	ring.Thickness = 3
	ring.Color = Color3.new(1, 1, 1)
	ring.Parent = dot
	corner(dot, 11)

	-- полоса оттенка
	local hueBar = Kit.frame(box, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 3, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 62 })
	corner(hueBar, 8)
	local hg = Instance.new("UIGradient")
	local keys = {}
	for i = 0, 6 do
		table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 % 1, 1, 1)))
	end
	hg.Color = ColorSequence.new(keys)
	hg.Parent = hueBar
	local hueMark = Kit.frame(hueBar, { Size = UDim2.new(0, 6, 1, 6), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 63 })
	corner(hueMark, 3)

	local hex = Kit.textbox(box, "", "#RRGGBB", nil, { LayoutOrder = 4, ZIndex = 62, TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.Code })

	local recentRow = Kit.frame(box, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 5, ZIndex = 62 })
	Kit.list(recentRow, 6, true)

	local function current(): { number }
		return toRGB(Color3.fromHSV(h, s, val))
	end
	local function refresh(fromHex: boolean?)
		local c = Color3.fromHSV(h, s, val)
		preview.BackgroundColor3 = c
		square.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		dot.Position = UDim2.fromScale(s, 1 - val)
		hueMark.Position = UDim2.fromScale(h, 0.5)
		if not fromHex then
			local rgb = toRGB(c)
			hex.Text = string.format("#%02X%02X%02X", rgb[1], rgb[2], rgb[3])
		end
	end
	for i, c in Kit.recentColors do
		if i > 7 then
			break
		end
		Kit.button(recentRow, "", function()
			h, s, val = Color3.fromRGB(c[1], c[2], c[3]):ToHSV()
			refresh()
		end, { Size = UDim2.fromOffset(40, 40), BackgroundColor3 = Color3.fromRGB(c[1], c[2], c[3]), LayoutOrder = i, ZIndex = 63 })
	end
	hex:GetPropertyChangedSignal("Text"):Connect(function()
		local r, g, b = string.match(hex.Text, "^#?(%x%x)(%x%x)(%x%x)$")
		if r then
			h, s, val = Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)):ToHSV()
			refresh(true)
		end
	end)

	-- перетаскивание пальцем или мышью
	local drag: string? = nil
	local function at(pos: Vector3)
		if drag == "square" then
			s = math.clamp((pos.X - square.AbsolutePosition.X) / square.AbsoluteSize.X, 0, 1)
			val = 1 - math.clamp((pos.Y - square.AbsolutePosition.Y) / square.AbsoluteSize.Y, 0, 1)
		elseif drag == "hue" then
			h = math.clamp((pos.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 0.999)
		end
		refresh()
	end
	local function begin(kind: string)
		return function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				drag = kind
				at(input.Position)
			end
		end
	end
	black.InputBegan:Connect(begin("square"))
	hueBar.InputBegan:Connect(begin("hue"))
	local c1 = UIS.InputChanged:Connect(function(input)
		if drag and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
			at(input.Position)
		end
	end)
	local c2 = UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			drag = nil
		end
	end)
	local function close()
		c1:Disconnect()
		c2:Disconnect()
		shade:Destroy()
	end

	local row = Kit.frame(box, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Kit.TAP), LayoutOrder = 6, ZIndex = 62 })
	Kit.button(row, L_CANCEL, close, { Size = UDim2.new(0.5, -4, 1, 0), ZIndex = 63 })
	Kit.button(row, L_APPLY, function()
		local c = current()
		close()
		table.insert(Kit.recentColors, 1, c)
		while #Kit.recentColors > 7 do
			table.remove(Kit.recentColors)
		end
		onDone(c)
	end, { Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new(0.5, 4, 0, 0), ZIndex = 63, BackgroundColor3 = Kit.C.accent })
	refresh()
	return shade
end

-- Окно с одним полем ввода (например, ID своей текстуры)
function Kit.prompt(root: Instance, title: string, hint: string?, placeholder: string, onDone: (string) -> ())
	local shade = Kit.frame(root, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 50 })
	local w = math.min(400, Kit.viewport().X - 32)
	local box = Kit.frame(shade, { Size = UDim2.fromOffset(w, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0.5, -w / 2, 0.2, 0), ZIndex = 51 })
	corner(box, 12)
	Kit.pad(box, 12)
	Kit.list(box, 8)
	Kit.label(box, title, { Font = Kit.FONT_BOLD, TextSize = 17, ZIndex = 52, LayoutOrder = 1 })
	if hint then
		Kit.label(box, hint, { TextColor3 = Kit.C.dim, TextSize = 13, ZIndex = 52, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 36) })
	end
	local t = Kit.textbox(box, "", placeholder, nil, { ZIndex = 52, LayoutOrder = 3 })
	local row = Kit.frame(box, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Kit.TAP), LayoutOrder = 4, ZIndex = 52 })
	Kit.button(row, L_CANCEL, function()
		shade:Destroy()
	end, { Size = UDim2.new(0.5, -4, 1, 0), ZIndex = 53 })
	Kit.button(row, L_APPLY, function()
		local v = t.Text
		shade:Destroy()
		onDone(v)
	end, { Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new(0.5, 4, 0, 0), ZIndex = 53, BackgroundColor3 = Kit.C.accent })
	return shade
end

-- Короткое уведомление внизу экрана (только в редакторе и меню)
function Kit.toast(root: Instance, text: string, color: Color3?, seconds: number?)
	local v = Kit.viewport()
	local w = math.min(520, v.X - 32)
	local size = TextService:GetTextSize(text, 15, Kit.FONT, Vector2.new(w - 24, 1000))
	local f = Kit.frame(root, {
		Size = UDim2.fromOffset(w, size.Y + 24),
		Position = UDim2.new(0.5, -w / 2, 1, -size.Y - 90),
		BackgroundColor3 = color or Kit.C.panel2,
		ZIndex = 80,
	})
	corner(f, 10)
	Kit.label(f, text, { Size = UDim2.new(1, -24, 1, -24), Position = UDim2.fromOffset(12, 12), TextSize = 15, ZIndex = 81 })
	task.delay(seconds or 3, function()
		f:Destroy()
	end)
	return f
end

return Kit
