--!nonstrict
-- Скримеры: что видит игрок в момент гибели. У каждого существа свой:
-- Тьма врывается в лицо, Колосс смыкает каменные челюсти (съедает), тебЯ —
-- мраморное лицо с трещинами бросается вплотную, Монетчик — огромная монета,
-- Пролом затягивает в чёрный туннель. Длится около полутора секунд

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Scares = {}

local player = Players.LocalPlayer

local layer: ScreenGui? = nil
local function getLayer(): ScreenGui
	if layer and layer.Parent then
		return layer
	end
	local g = Instance.new("ScreenGui")
	g.Name = "Scare"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 100
	pcall(function()
		g.ScreenInsets = Enum.ScreenInsets.None
	end)
	g.Parent = player:WaitForChild("PlayerGui")
	layer = g
	return g
end

local function frame(parent, color: Color3, x, y, w, h, round: number?, z: number?)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.ZIndex = z or 2
	if round then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(round, 0)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

-- квадратный холст в центре экрана (по меньшей стороне): лицо не сплющивается
local function square(parent)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = 3
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.DominantAxis = Enum.DominantAxis.Height
	ar.Parent = f
	f.Parent = parent
	return f
end

local function sound(id: string, vol: number, speed: number)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol
	s.PlaybackSpeed = speed
	s.Parent = getLayer()
	s:Play()
	task.delay(4, function()
		s:Destroy()
	end)
	return s
end

local SND = {
	scream = "rbxasset://sounds/uuhhh.mp3",
	rumble = "rbxasset://sounds/swoosh.wav",
	stone = "rbxasset://sounds/collide.wav",
	glass = "rbxasset://sounds/flashbulb.wav",
	ping = "rbxasset://sounds/electronicpingshort.wav",
}

-- ближайшая к игроку модель или деталь с тегом
local function nearest(tag: string): Instance?
	local cam = workspace.CurrentCamera
	local best, bestD = nil, math.huge
	for _, d in CollectionService:GetTagged(tag) do
		local pos = if d:IsA("Model") then d:GetPivot().Position elseif d:IsA("BasePart") then d.Position else nil
		if pos then
			local dd = (pos - cam.CFrame.Position).Magnitude
			if dd < bestD then
				best, bestD = d, dd
			end
		end
	end
	return best
end

-- камера резко поворачивается к точке и подаётся к ней
local function lunge(target: Vector3?, dur: number, push: number)
	if not target then
		return
	end
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local from = cam.CFrame
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = math.min(1, (os.clock() - t0) / dur)
		local e = 1 - (1 - k) ^ 3
		local look = CFrame.lookAt(from.Position, target)
		local cf = from:Lerp(look, math.min(1, e * 1.6))
		local toward = (target - from.Position)
		local dist = math.min(toward.Magnitude - 2, push)
		cam.CFrame = cf + toward.Unit * dist * e
		cam.CFrame *= CFrame.Angles((math.random() - 0.5) * 0.04 * e, (math.random() - 0.5) * 0.04 * e, 0)
		if k >= 1 then
			conn:Disconnect()
		end
	end)
end

-- общий конец: белая вспышка и тьма
local function blackout(root, at: number)
	local black = frame(root, Color3.new(0, 0, 0), 0.5, 0.5, 1, 1, nil, 20)
	black.BackgroundTransparency = 1
	task.delay(at, function()
		black.BackgroundTransparency = 0
	end)
end

-- Тьма: чёрное лицо со щупальцами налетает в упор, мерцает, рот раскрывается
local function darkness(root)
	lunge((function()
		local d = nearest("Darkness")
		return if d and d:IsA("BasePart") then d.Position else nil
	end)(), 0.3, 6)
	sound(SND.rumble, 3, 0.5)
	sound(SND.scream, 3, 0.75)
	local sq = square(root)
	local face = frame(sq, Color3.new(0, 0, 0), 0.5, 0.5, 0.2, 0.2, nil, 4)
	face.BackgroundTransparency = 1
	local tendrils = {}
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		local t = frame(face, Color3.new(0, 0, 0), 0.5 + math.cos(a) * 0.32, 0.5 + math.sin(a) * 0.32, 0.17, 0.55, 0.5, 4)
		t.Rotation = math.deg(a) + 90
		table.insert(tendrils, { t, a })
	end
	frame(face, Color3.new(0, 0, 0), 0.5, 0.5, 0.7, 0.7, 0.5, 5)
	local eyeL = frame(face, Color3.new(1, 1, 1), 0.37, 0.41, 0.13, 0.18, 0.5, 6)
	local eyeR = frame(face, Color3.new(1, 1, 1), 0.63, 0.41, 0.13, 0.18, 0.5, 6)
	local mouth = frame(face, Color3.new(1, 1, 1), 0.5, 0.67, 0.3, 0.08, 0.5, 6)
	local tint = frame(root, Color3.fromRGB(80, 0, 0), 0.5, 0.5, 1, 1, nil, 1)
	tint.BackgroundTransparency = 1
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local k = math.min(1, t / 0.55)
		local s = 0.2 + k ^ 2 * 2.4
		face.Size = UDim2.fromScale(s, s)
		face.Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.04 * k, 0.5 + (math.random() - 0.5) * 0.04 * k)
		face.Rotation = math.sin(t * 40) * 6 * k
		mouth.Size = UDim2.fromScale(0.3 + k * 0.08, 0.08 + k * 0.22)
		mouth.Position = UDim2.fromScale(0.5, 0.67 + k * 0.06)
		for _, e in tendrils do
			e[1].Size = UDim2.fromScale(0.17, 0.55 + math.sin(t * 25 + e[2] * 3) * 0.12)
		end
		-- мерцание: глаза и рот вспыхивают, фон бьёт красным
		local flick = math.random() < 0.35
		eyeL.BackgroundColor3 = if flick then Color3.fromRGB(255, 60, 60) else Color3.new(1, 1, 1)
		eyeR.BackgroundColor3 = eyeL.BackgroundColor3
		tint.BackgroundTransparency = if flick then 0.4 else 0.8
		if t > 1.1 then
			conn:Disconnect()
		end
	end)
	blackout(root, 0.75)
	task.wait(1.4)
end

-- Колосс: камера дёргается к его голове, сверху и снизу смыкаются каменные челюсти
local function colossus(root)
	local boss = nearest("Colossus")
	local head = boss and boss:FindFirstChild("Skull", true)
	lunge(if head and head:IsA("BasePart") then head.Position else nil, 0.35, 10)
	sound(SND.scream, 3, 0.4)
	local stone, dark, bone = Color3.fromRGB(196, 190, 180), Color3.fromRGB(60, 56, 52), Color3.fromRGB(236, 228, 210)
	local function jaw(top: boolean)
		local j = Instance.new("Frame")
		j.BorderSizePixel = 0
		j.BackgroundColor3 = stone
		j.AnchorPoint = Vector2.new(0.5, if top then 1 else 0)
		j.Size = UDim2.fromScale(1.3, 0.6)
		j.Position = UDim2.fromScale(0.5, if top then 0 else 1)
		j.ZIndex = 5
		j.Parent = root
		local g = Instance.new("UIGradient")
		g.Rotation = if top then 90 else -90
		g.Color = ColorSequence.new(dark, stone)
		g.Parent = j
		-- зубы по кромке
		for k = 0, 13 do
			local x = (k + 0.5) / 14
			local tooth = frame(j, bone, x, if top then 1 else 0, 0.045, 0.2, 0.15, 6)
			tooth.Rotation = 45
			tooth.Size = UDim2.new(0.04, 0, 0.04 * 1.3 / 0.6 * 2.2, 0)
		end
		-- трещины в камне
		for k = 0, 4 do
			local c = frame(j, dark, 0.15 + k * 0.18, if top then 0.6 else 0.4, 0.004, 0.3, nil, 6)
			c.Rotation = (k % 2 - 0.5) * 50
		end
		return j
	end
	local top, bottom = jaw(true), jaw(false)
	local t0 = os.clock()
	local snapped = false
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		-- сначала раскрываются шире, потом резко смыкаются
		local open = if t < 0.35 then 0.1 + t * 0.4 else math.max(0, 0.24 - (t - 0.35) * 2.4)
		local shake = if t > 0.45 then (math.random() - 0.5) * 0.03 else 0
		top.Position = UDim2.fromScale(0.5 + shake, 0.5 - open)
		bottom.Position = UDim2.fromScale(0.5 - shake, 0.5 + open)
		if open <= 0 and not snapped then
			snapped = true
			sound(SND.stone, 3, 0.35)
			sound(SND.stone, 2, 0.6)
		end
		if t > 1.3 then
			conn:Disconnect()
		end
	end)
	local red = frame(root, Color3.fromRGB(120, 0, 0), 0.5, 0.5, 1, 1, nil, 7)
	red.BackgroundTransparency = 1
	task.delay(0.48, function()
		red.BackgroundTransparency = 0.3
	end)
	blackout(root, 0.9)
	task.wait(1.4)
end

-- тебЯ: бледное мраморное лицо с пустыми глазами бросается в экран и трескается
local function mimic(root)
	local m = nearest("Mimic")
	local head = m and m:FindFirstChild("Head", true)
	lunge(if head and head:IsA("BasePart") then head.Position else nil, 0.25, 4)
	sound(SND.stone, 3, 0.5)
	sound(SND.scream, 2, 1.1)
	local marble, shade = Color3.fromRGB(214, 208, 198), Color3.fromRGB(150, 144, 136)
	local sq = square(root)
	local face = frame(sq, marble, 0.5, 0.5, 0.3, 0.38, 0.45, 4)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(marble, shade)
	g.Rotation = 70
	g.Parent = face
	frame(face, Color3.fromRGB(20, 18, 18), 0.33, 0.4, 0.18, 0.12, 0.5, 5)
	frame(face, Color3.fromRGB(20, 18, 18), 0.67, 0.4, 0.18, 0.12, 0.5, 5)
	frame(face, shade, 0.5, 0.56, 0.08, 0.16, 0.3, 5)
	local mouth = frame(face, Color3.fromRGB(30, 26, 26), 0.5, 0.75, 0.3, 0.04, 0.5, 5)
	local cracks = {}
	for k = 0, 6 do
		local c = frame(face, Color3.fromRGB(70, 66, 62), 0.3 + k * 0.07, 0.2 + (k % 3) * 0.2, 0.012, 0.0, nil, 6)
		c.Rotation = (k * 37) % 120 - 60
		table.insert(cracks, c)
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local k = math.min(1, t / 0.3)
		face.Size = UDim2.fromScale(0.3 + k * 1.3, 0.38 + k * 1.6)
		face.Rotation = -8 * k + math.sin(t * 50) * 2
		mouth.Size = UDim2.fromScale(0.3, 0.04 + math.min(1, t / 0.6) * 0.14)
		for i, c in cracks do
			c.Size = UDim2.fromScale(0.012, math.min(0.5, math.max(0, t - 0.3 - i * 0.04) * 1.5))
		end
		if t > 1.2 then
			conn:Disconnect()
		end
	end)
	task.delay(0.35, function()
		sound(SND.glass, 2, 0.6)
	end)
	blackout(root, 0.85)
	task.wait(1.3)
end

-- Монетчик: огромная золотая монета с усами крутится и наезжает, звон
local function coinkeeper(root)
	local m = nearest("CoinKeeper")
	lunge(if m and m:IsA("Model") then m:GetPivot().Position + Vector3.new(0, 2.7, 0) else nil, 0.3, 3)
	local gold, dark = Color3.fromRGB(226, 182, 64), Color3.fromRGB(150, 110, 30)
	local sq = square(root)
	local coin = frame(sq, dark, 0.5, 0.5, 0.4, 0.4, 0.5, 4)
	local inner = frame(coin, gold, 0.5, 0.5, 0.86, 0.86, 0.5, 5)
	frame(inner, dark, 0.5, 0.42, 0.1, 0.18, 0.3, 6)
	for _, sx in { -1, 1 } do
		local mu = frame(inner, Color3.fromRGB(36, 24, 14), 0.5 + sx * 0.17, 0.6, 0.3, 0.07, 0.5, 6)
		mu.Rotation = sx * -15
		frame(inner, Color3.fromRGB(36, 24, 14), 0.5 + sx * 0.33, 0.53, 0.08, 0.08, 0.5, 6)
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local k = math.min(1, t / 0.6)
		-- «вращение» монеты: ширина то сужается, то расширяется
		local spin = math.abs(math.cos(t * 9))
		local s = 0.4 + k * 1.6
		coin.Size = UDim2.fromScale(s * math.max(0.08, spin), s)
		if t > 1.2 then
			conn:Disconnect()
		end
	end)
	for i = 0, 5 do
		task.delay(i * 0.12, function()
			sound(SND.ping, 1.5, 0.7 + i * 0.1)
		end)
	end
	blackout(root, 0.9)
	task.wait(1.3)
end

-- Пролом: зал тянется в точку, кольца тьмы сходятся, всё уходит в черноту
local function void(root)
	local cam = workspace.CurrentCamera
	sound(SND.rumble, 3, 0.25)
	local sq = square(root)
	local rings = {}
	for k = 0, 5 do
		local r = frame(sq, Color3.new(0, 0, 0), 0.5, 0.5, 3, 3, 0.5, 4)
		r.BackgroundTransparency = 1
		local st = Instance.new("UIStroke")
		st.Color = Color3.new(0, 0, 0)
		st.Thickness = 40
		st.Parent = r
		table.insert(rings, { r, k })
	end
	local fov0 = cam.FieldOfView
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		cam.FieldOfView = math.min(120, fov0 + t * 60)
		cam.CFrame *= CFrame.Angles(0, 0, math.sin(t * 3) * 0.01)
		for _, e in rings do
			local s = math.max(0, 3 - (t * 2.4 + e[2] * 0.4))
			e[1].Size = UDim2.fromScale(s, s)
		end
		if t > 1.4 then
			conn:Disconnect()
			cam.FieldOfView = fov0
		end
	end)
	blackout(root, 1.0)
	task.wait(1.5)
end

local PLAY = { darkness = darkness, colossus = colossus, mimic = mimic, coinkeeper = coinkeeper, void = void }

-- показать скример для причины гибели; ждёт, пока он закончится
function Scares.play(cause: string?)
	local fn = PLAY[cause or ""]
	if not fn then
		return
	end
	local g = getLayer()
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ClipsDescendants = true
	root.Parent = g
	local ok, err = pcall(fn, root)
	if not ok then
		warn("[Museum] scare: " .. tostring(err))
	end
	task.delay(0.6, function()
		root:Destroy()
	end)
end

return Scares
