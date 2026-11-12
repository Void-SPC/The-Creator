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

Kit.TAP = 44
local UiText = require(game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared"):WaitForChild("UiText"))
Kit.YES = UiText.L.Yes
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
