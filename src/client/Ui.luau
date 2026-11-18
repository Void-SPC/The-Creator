--!nonstrict
-- Мелкие помощники интерфейса: рамки, подписи, кнопки (крупные, удобные для пальца)

local Ui = {}

Ui.FONT = Enum.Font.Gotham
Ui.BOLD = Enum.Font.GothamBold
Ui.TITLE = Enum.Font.Antique
Ui.C = {
	panel = Color3.fromRGB(22, 19, 17),
	line = Color3.fromRGB(120, 86, 46),
	text = Color3.fromRGB(236, 226, 206),
	dim = Color3.fromRGB(160, 150, 136),
	gold = Color3.fromRGB(230, 190, 110),
	red = Color3.fromRGB(190, 40, 40),
	good = Color3.fromRGB(80, 170, 90),
}

function Ui.corner(parent, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = parent
	return c
end

function Ui.frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Ui.C.panel
	for k, v in props or {} do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

function Ui.label(parent, text: string, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Ui.FONT
	l.TextSize = 16
	l.TextColor3 = Ui.C.text
	l.TextWrapped = true
	l.Text = text
	l.Size = UDim2.new(1, 0, 0, 24)
	for k, v in props or {} do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

function Ui.button(parent, text: string, fn, props)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BorderSizePixel = 0
	b.BackgroundColor3 = Ui.C.panel
	b.BackgroundTransparency = 0.1
	b.Font = Ui.BOLD
	b.TextSize = 17
	b.TextColor3 = Ui.C.text
	b.Text = text
	b.Size = UDim2.new(1, 0, 0, 46)
	for k, v in props or {} do
		(b :: any)[k] = v
	end
	Ui.corner(b)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 150))
	g.Parent = b
	local st = Instance.new("UIStroke")
	st.Color = Ui.C.line
	st.Transparency = 0.25
	st.Thickness = 1.2
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = b
	if fn then
		b.Activated:Connect(fn)
	end
	b.Parent = parent
	return b
end

-- ---------------------------------------------------------------------------
-- значки, нарисованные из рамок (без эмодзи и без загруженных картинок)

local function bit(parent, color: Color3, x, y, w, h, round: number?, rot: number?)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.Rotation = rot or 0
	f.ZIndex = parent.ZIndex + 1
	if round then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(round, 0)
		c.Parent = f
	end
	f.Parent = parent
	return f
end
Ui.bit = bit

-- холст значка поверх кнопки
function Ui.iconHolder(parent, scale: number?)
	local h = Instance.new("Frame")
	h.Name = "Icon"
	h.BackgroundTransparency = 1
	h.AnchorPoint = Vector2.new(0.5, 0.5)
	h.Position = UDim2.fromScale(0.5, 0.5)
	h.Size = UDim2.fromScale(scale or 0.56, scale or 0.56)
	h.ZIndex = parent.ZIndex + 1
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.Parent = h
	h.Parent = parent
	return h
end

function Ui.gearIcon(parent, color: Color3?)
	local h = Ui.iconHolder(parent)
	color = color or Ui.C.text
	for k = 0, 7 do
		bit(h, color, 0.5, 0.5, 0.18, 1, 0.2, k * 22.5)
	end
	bit(h, color, 0.5, 0.5, 0.78, 0.78, 1)
	bit(h, Ui.C.panel, 0.5, 0.5, 0.34, 0.34, 1)
	return h
end

function Ui.bookIcon(parent, color: Color3?)
	local h = Ui.iconHolder(parent)
	color = color or Ui.C.text
	bit(h, color, 0.27, 0.52, 0.44, 0.78, 0.12, -6)
	bit(h, color, 0.73, 0.52, 0.44, 0.78, 0.12, 6)
	bit(h, Ui.C.panel, 0.5, 0.52, 0.06, 0.8)
	for k = 0, 2 do
		bit(h, Ui.C.panel, 0.27, 0.32 + k * 0.16, 0.26, 0.04, nil, -6)
		bit(h, Ui.C.panel, 0.73, 0.32 + k * 0.16, 0.26, 0.04, nil, 6)
	end
	return h
end

function Ui.trophyIcon(parent, color: Color3?)
	local h = Ui.iconHolder(parent)
	color = color or Ui.C.gold
	bit(h, color, 0.5, 0.3, 0.66, 0.5, 0.45)
	bit(h, color, 0.5, 0.12, 0.7, 0.12)
	bit(h, color, 0.5, 0.66, 0.12, 0.24)
	bit(h, color, 0.5, 0.86, 0.5, 0.12, 0.2)
	for _, x in { 0.12, 0.88 } do
		bit(h, color, x, 0.32, 0.16, 0.3, 1)
		bit(h, Ui.C.panel, x, 0.32, 0.07, 0.16, 1)
	end
	return h
end

-- стрелка-шеврон: up = true — вверх
function Ui.chevron(parent, up: boolean, color: Color3?)
	local h = Ui.iconHolder(parent, 0.5)
	color = color or Ui.C.text
	local y = if up then 0.62 else 0.38
	local a = if up then 1 else -1
	bit(h, color, 0.32, y - a * 0.0, 0.62, 0.16, 0.5, -a * 45)
	bit(h, color, 0.68, y - a * 0.0, 0.62, 0.16, 0.5, a * 45)
	return h
end

-- круглая кнопка-значок в общем стиле
function Ui.iconButton(parent, size: number, fn, props)
	local b = Ui.button(parent, "", fn, props)
	b.Size = UDim2.fromOffset(size, size)
	local c = b:FindFirstChildOfClass("UICorner")
	if c then
		c.CornerRadius = UDim.new(0, math.floor(size * 0.28))
	end
	return b
end

function Ui.list(parent, pad: number?, horizontal: boolean?)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, pad or 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.Parent = parent
	return l
end

function Ui.pad(parent, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = parent
	return p
end

function Ui.viewport(): Vector2
	local cam = workspace.CurrentCamera
	return if cam then cam.ViewportSize else Vector2.new(800, 600)
end

return Ui
