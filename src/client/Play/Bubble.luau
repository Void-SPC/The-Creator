--!nonstrict
-- Пузырь реплики. Один и тот же код рисует реплику в игре и в предпросмотре
-- редактора, поэтому автор видит на маленьком экране ровно то, что увидят игроки

local TextService = game:GetService("TextService")

local Bubble = {}

Bubble.FONT = Enum.Font.GothamMedium

-- Размер текста подстраивается под экран: не меньше 16 на телефоне
function Bubble.textSize(authorSize: number, viewport: Vector2): number
	local scale = math.clamp(math.min(viewport.X, viewport.Y) / 600, 0.75, 1.25)
	return math.clamp(math.floor(authorSize * scale + 0.5), 16, 40)
end

function Bubble.maxWidth(viewport: Vector2): number
	return math.floor(math.clamp(viewport.X * 0.62, 220, 460))
end

function Bubble.make(parent: Instance, text: string, textSize: number, maxWidth: number, wrap: boolean?): Frame
	local pad = 12
	local bounds = TextService:GetTextSize(text, textSize, Bubble.FONT, Vector2.new(if wrap == false then 10000 else maxWidth - pad * 2, 10000))
	local w = math.min(bounds.X + pad * 2 + 2, if wrap == false then 10000 else maxWidth)
	local h = bounds.Y + pad * 2
	local f = Instance.new("Frame")
	f.Name = "Bubble"
	f.BackgroundColor3 = Color3.fromRGB(250, 250, 252)
	f.BackgroundTransparency = 0.04
	f.BorderSizePixel = 0
	f.Size = UDim2.fromOffset(w, h)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(30, 30, 40)
	s.Transparency = 0.6
	s.Parent = f
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, -pad * 2, 1, -pad * 2)
	l.Position = UDim2.fromOffset(pad, pad)
	l.Font = Bubble.FONT
	l.TextSize = textSize
	l.TextColor3 = Color3.fromRGB(20, 22, 30)
	l.TextWrapped = wrap ~= false
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Text = text
	l.Parent = f
	f.Parent = parent
	return f
end

return Bubble
