--!nonstrict
-- Мелкие помощники интерфейса: рамки, подписи, кнопки (крупные, удобные для пальца)

local Ui = {}

Ui.FONT = Enum.Font.Gotham
Ui.BOLD = Enum.Font.GothamBold
Ui.TITLE = Enum.Font.Antique
Ui.C = {
	panel = Color3.fromRGB(18, 16, 14),
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
	local st = Instance.new("UIStroke")
	st.Color = Ui.C.line
	st.Thickness = 1.5
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = b
	if fn then
		b.Activated:Connect(fn)
	end
	b.Parent = parent
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
