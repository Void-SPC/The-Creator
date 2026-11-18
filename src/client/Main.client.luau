--!nonstrict
-- Клиент «The Museum». Меню нет: на улице — свой персонаж, в музее — вид от первого
-- лица и минимум кнопок: здоровье, монеты, «тихо», журнал, выход из шкафчика.
-- Предметы — в инвентаре Roblox. Диалоги, кодовый замок, журнал существ, сцены,
-- Тьма, проломы в пустоту, звук шагов по разным полам

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local Remotes = require(Shared.Roblox.Remotes)
local Lang = require(Shared.Lang)
local Rules = require(Shared.Rules)
local AdminCommands = require(Shared.AdminCommands)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local app = {
	lang = if string.sub(player.LocaleId or "", 1, 2) == "ru" then "ru" else "en",
	sneaking = false,
	dead = false,
	scene = false, -- идёт сцена: камерой управляет она
	tbc = false,
	spectating = nil :: Player?,
	shake = 0,
	lastHp = 100,
	steps = true,
	ambience = true,
	journal = {} :: { [string]: boolean },
	ach = {} :: { [string]: boolean },
	arrived = false,
}

local function T(key: string, ...)
	return Lang.t(app.lang, key, ...)
end

local function request(...)
	local ok, res = pcall(function(...)
		return Remotes.fn("Request"):InvokeServer(...)
	end, ...)
	return if ok then res else nil
end

local function inRun(): boolean
	return workspace:GetAttribute("Mode") == "run"
end

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	-- свой инвентарь внизу экрана вместо стандартного
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)
task.spawn(request, "Lang", app.lang)
task.spawn(function()
	local r = request("Journal")
	if r and r.journal then
		for id in r.journal do
			app.journal[id] = true
		end
	end
	if r and type(r.ach) == "table" then
		for id in r.ach do
			app.ach[id] = true
		end
	end
end)

-- ---------------------------------------------------------------------------
-- свет: на улице ночь с луной, в музее темно; за проломами и окнами только чернота

local tint = Instance.new("ColorCorrectionEffect")
tint.Parent = Lighting
local sky = Instance.new("Sky")
sky.Name = "VoidSky"
sky.StarCount = 0
sky.CelestialBodiesShown = false
for _, face in { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" } do
	(sky :: any)[face] = "rbxasset://textures/blackBkg_square.png"
end
local function applyLighting()
	local light = workspace:GetAttribute("Light") or 1
	Lighting.ClockTime = 0
	Lighting.FogColor = Color3.fromRGB(3, 3, 4)
	pcall(function()
		Lighting.EnvironmentDiffuseScale = 0
		Lighting.EnvironmentSpecularScale = 0
	end)
	if inRun() then
		Lighting.Ambient = Color3.fromRGB(10, 9, 9)
		Lighting.OutdoorAmbient = Color3.fromRGB(0, 0, 0)
		Lighting.Brightness = 0
		Lighting.FogStart = 20
		Lighting.FogEnd = 80 + 100 * light
		tint.Saturation = -0.2 - (1 - light) * 0.3
		tint.Contrast = 0.12
		sky.Parent = Lighting
	else
		Lighting.Ambient = Color3.fromRGB(34, 38, 54)
		Lighting.OutdoorAmbient = Color3.fromRGB(44, 50, 72)
		Lighting.Brightness = 1.2
		Lighting.FogStart = 60
		Lighting.FogEnd = 320
		tint.Saturation = -0.1
		tint.Contrast = 0.05
		sky.Parent = nil
	end
end
workspace:GetAttributeChangedSignal("Light"):Connect(applyLighting)

-- ---------------------------------------------------------------------------
-- экран

local gui = Instance.new("ScreenGui")
gui.Name = "Museum"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- слой на весь экран, включая вырез камеры и закруглённые края телефона
local fullGui = Instance.new("ScreenGui")
fullGui.Name = "MuseumFull"
fullGui.ResetOnSpawn = false
fullGui.IgnoreGuiInset = true
fullGui.DisplayOrder = -1
pcall(function()
	fullGui.ScreenInsets = Enum.ScreenInsets.None
end)
fullGui.Parent = playerGui

local black = Ui.frame(gui, { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40 })
local red = Ui.frame(gui, { BackgroundColor3 = Color3.fromRGB(140, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 41 })

local function flashRed(strength: number)
	red.BackgroundTransparency = 1 - strength
	TweenService:Create(red, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()
end

local toastBox = Ui.frame(gui, { BackgroundTransparency = 1, Size = UDim2.new(0.9, 0, 0, 120), Position = UDim2.new(0.05, 0, 0.62, 0), ZIndex = 50 })
Ui.list(toastBox, 4)
local function toast(text: string, color: Color3?, seconds: number?)
	local l = Ui.label(toastBox, text, { Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, TextSize = 16, TextColor3 = color or Ui.C.text, ZIndex = 51 })
	l.TextStrokeTransparency = 0.5
	task.delay(seconds or 2.4, function()
		TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(0.6, function()
			l:Destroy()
		end)
	end)
end

-- реплика внизу экрана: буквы появляются по одной
local lineBox = Ui.frame(gui, { BackgroundTransparency = 0.25, Size = UDim2.new(0.7, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0.15, 0, 0.78, 0), Visible = false, ZIndex = 55 })
Ui.corner(lineBox, 8)
Ui.pad(lineBox, 12)
local lineText = Ui.label(lineBox, "", { TextSize = 18, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 56 })
local lineId = 0
local function say(text: string, robotic: boolean?)
	lineId += 1
	local id = lineId
	lineBox.Visible = true
	lineText.Font = if robotic then Enum.Font.Code else Ui.FONT
	lineText.Text = text
	lineText.MaxVisibleGraphemes = 0
	local beep = Instance.new("Sound")
	beep.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	beep.Volume = if robotic then 0.5 else 0
	beep.Parent = gui
	task.spawn(function()
		local n = utf8.len(text) or #text
		for i = 1, n do
			if lineId ~= id then
				break
			end
			lineText.MaxVisibleGraphemes = i
			if robotic and i % 3 == 0 then
				beep.PlaybackSpeed = 0.5 + (i % 5) * 0.06
				beep:Play()
			end
			task.wait(if robotic then 0.05 else 0.035)
		end
		task.wait(3.5)
		beep:Destroy()
		if lineId == id then
			lineBox.Visible = false
		end
	end)
end

-- ---------------------------------------------------------------------------
-- интерфейс забега

local hud = Ui.frame(gui, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 10 })
local hpBack = Ui.frame(hud, { BackgroundColor3 = Color3.fromRGB(30, 26, 24), BackgroundTransparency = 0.4, Size = UDim2.fromOffset(150, 6), Position = UDim2.new(0, 16, 0, 52), ZIndex = 11 })
Ui.corner(hpBack, 3)
local hpFill = Ui.frame(hpBack, { BackgroundColor3 = Color3.fromRGB(170, 40, 40), Size = UDim2.fromScale(1, 1), ZIndex = 12 })
Ui.corner(hpFill, 3)
local coinText = Ui.label(hud, "", { Font = Ui.BOLD, TextSize = 15, TextColor3 = Ui.C.gold, Size = UDim2.fromOffset(150, 20), Position = UDim2.new(0, 16, 0, 62), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11 })
coinText.TextStrokeTransparency = 0.6
local flBack = Ui.frame(hud, { BackgroundColor3 = Color3.fromRGB(30, 26, 24), BackgroundTransparency = 0.4, Size = UDim2.fromOffset(150, 4), Position = UDim2.new(0, 16, 0, 86), Visible = false, ZIndex = 11 })
Ui.corner(flBack, 2)
local flFill = Ui.frame(flBack, { BackgroundColor3 = Color3.fromRGB(230, 210, 120), Size = UDim2.fromScale(1, 1), ZIndex = 12 })
Ui.corner(flFill, 2)

-- присесть / встать: стрелка вниз — присесть, вверх — встать
local sneakBtn = Ui.iconButton(hud, 64, nil, { Position = UDim2.new(1, -84, 1, -210), BackgroundTransparency = 0.35, ZIndex = 11 })
local sneakIcon = Ui.chevron(sneakBtn, false)
local function setSneak(on: boolean)
	app.sneaking = on
	sneakIcon:Destroy()
	sneakIcon = Ui.chevron(sneakBtn, on)
	sneakBtn.BackgroundColor3 = if on then Ui.C.line else Ui.C.panel
	task.spawn(request, "Sneak", on)
end
sneakBtn.Activated:Connect(function()
	setSneak(not app.sneaking)
end)

local leaveBtn = Ui.button(gui, "", function()
	task.spawn(request, "Unhide")
end, { Size = UDim2.fromOffset(160, 48), Position = UDim2.new(0.5, -80, 1, -150), Visible = false, ZIndex = 30 })

-- вид из шкафчика: тёмная дверца с узкими прорезями, сквозь которые видно зал
local slits = Ui.frame(fullGui, { BackgroundTransparency = 1, Size = UDim2.new(1, 40, 1, 40), Position = UDim2.fromOffset(-20, -20), Visible = false, ZIndex = 28 })
do
	local gap, bar = 0.035, 0.085
	local y = 0.2
	Ui.frame(slits, { BackgroundColor3 = Color3.fromRGB(8, 9, 9), Size = UDim2.fromScale(1, y), ZIndex = 28 })
	for _ = 1, 5 do
		y += gap
		Ui.frame(slits, { BackgroundColor3 = Color3.fromRGB(8, 9, 9), Size = UDim2.fromScale(1, bar), Position = UDim2.fromScale(0, y), ZIndex = 28 })
		y += bar
	end
	Ui.frame(slits, { BackgroundColor3 = Color3.fromRGB(8, 9, 9), Size = UDim2.fromScale(1, 1 - y), Position = UDim2.fromScale(0, y), ZIndex = 28 })
	for _, x in { 0, 0.88 } do
		Ui.frame(slits, { BackgroundColor3 = Color3.fromRGB(8, 9, 9), Size = UDim2.fromScale(0.12, 1), Position = UDim2.fromScale(x, 0), ZIndex = 28 })
	end
end

local function refreshHud()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hp = if hum then math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1) else 0
	hpFill.Size = UDim2.fromScale(hp, 1)
	coinText.Text = "● " .. (player:GetAttribute("Coins") or 0)
	local fl = (player:GetAttribute("Flash") or Rules.FLASH_MAX) / Rules.FLASH_MAX
	flFill.Size = UDim2.fromScale(math.clamp(fl, 0, 1), 1)
	local tool = char and char:FindFirstChildOfClass("Tool")
	-- заряд фонарика показан в его ячейке инвентаря
	flBack.Visible = false
	local _t = tool
	leaveBtn.Text = T("Leave")
end
player:GetAttributeChangedSignal("Coins"):Connect(refreshHud)
player:GetAttributeChangedSignal("Flash"):Connect(refreshHud)

-- ---------------------------------------------------------------------------
-- подписи кнопок и вывесок на языке игрока

local function localize(d: Instance)
	if d:IsA("ProximityPrompt") then
		local kind = d:GetAttribute("Kind")
		if kind then
			d.ActionText = T("p_" .. kind)
			if kind == "lockpick" then
				d.Enabled = (player:GetAttribute("Lockpicks") or 0) > 0
			end
		end
	elseif d:IsA("TextLabel") and d:GetAttribute("LangKey") then
		d.Text = T(d:GetAttribute("LangKey"))
	end
end
local function localizeAll()
	for _, d in workspace:GetDescendants() do
		localize(d)
	end
end
workspace.DescendantAdded:Connect(localize)
player:GetAttributeChangedSignal("Lockpicks"):Connect(function()
	for _, d in workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") and d:GetAttribute("Kind") == "lockpick" then
			localize(d)
		end
	end
end)

-- ---------------------------------------------------------------------------
-- камера

local function setCamera()
	if app.scene or app.tbc then
		return
	end
	if inRun() and not app.dead then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		player.CameraMode = Enum.CameraMode.Classic
	end
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 75
end

local hiddenEye = nil
player:GetAttributeChangedSignal("HiddenEye"):Connect(function()
	local eye = player:GetAttribute("HiddenEye")
	hiddenEye = if typeof(eye) == "CFrame" then eye else nil
	leaveBtn.Visible = hiddenEye ~= nil
	slits.Visible = hiddenEye ~= nil
	if not hiddenEye then
		setCamera()
	end
end)

player:GetAttributeChangedSignal("Sneaking"):Connect(function()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		TweenService:Create(hum, TweenInfo.new(0.25), { CameraOffset = if player:GetAttribute("Sneaking") then Vector3.new(0, -2, 0) else Vector3.zero }):Play()
	end
end)

-- свет своего фонарика идёт от камеры
local camLight = Instance.new("Part")
camLight.Name = "CamLight"
camLight.Anchored = true
camLight.CanCollide = false
camLight.CanQuery = false
camLight.Transparency = 1
camLight.Size = Vector3.new(0.2, 0.2, 0.2)
camLight.Parent = workspace
local beam = Instance.new("SpotLight")
beam.Face = Enum.NormalId.Front
beam.Range = 52
beam.Angle = 50
beam.Brightness = 3
beam.Color = Color3.fromRGB(255, 244, 220)
beam.Shadows = true
beam.Enabled = false
beam.Parent = camLight

-- ---------------------------------------------------------------------------
-- звуки: гул музея, дыхание пустоты у проломов, шаги по разным полам

local drone = Instance.new("Sound")
drone.SoundId = "rbxasset://sounds/swoosh.wav"
drone.Looped = true
drone.PlaybackSpeed = 0.05
drone.Volume = 0
drone.Parent = gui
drone:Play()
local voidSound = Instance.new("Sound")
voidSound.SoundId = "rbxasset://sounds/swoosh.wav"
voidSound.Looped = true
voidSound.PlaybackSpeed = 0.09
voidSound.Volume = 0
voidSound.Parent = gui
voidSound:Play()

-- Шаги: на каждый шаг — свой короткий звук, набор слоёв зависит от поверхности
-- (паркет стучит глуше, мрамор звонко и с эхом зала, металл звенит, ковёр глушит,
-- трава и песок шуршат). Стандартный звук бега у своего персонажа выключен
local SND = {
	step = "rbxasset://sounds/action_footsteps_plastic.mp3",
	knock = "rbxasset://sounds/collide.wav",
	click = "rbxasset://sounds/clickfast.wav",
	rustle = "rbxasset://sounds/swoosh.wav",
	land = "rbxasset://sounds/action_jump_land.mp3",
}
-- слой: звук, высота, громкость, эквалайзер (низ, середина, верх), эхо
local STEP_SETS = {
	wood = { { SND.step, 0.78, 0.6, { 3, 2, -8 } }, { SND.knock, 0.5, 0.1, { 4, 0, -10 } } },
	stone = { { SND.step, 1.22, 0.62, { -4, 1, 3 }, true }, { SND.click, 0.55, 0.05, { -6, 0, 2 }, true } },
	tile = { { SND.step, 1.38, 0.55, { -6, 0, 4 }, true } },
	concrete = { { SND.step, 0.98, 0.6, { 0, 1, -2 } }, { SND.land, 1.6, 0.12, { 0, 0, -4 } } },
	metal = { { SND.step, 1.08, 0.55, { -2, 3, 2 } }, { SND.click, 0.38, 0.14, { -4, 4, 0 }, true } },
	soft = { { SND.step, 0.6, 0.28, { 2, -4, -18 } } },
	grass = { { SND.rustle, 2.6, 0.22, { -6, 0, 2 } }, { SND.step, 0.52, 0.25, { 2, -2, -14 } } },
	sand = { { SND.rustle, 1.7, 0.2, { 0, -2, -4 } }, { SND.step, 0.48, 0.2, { 2, -4, -16 } } },
}
local M_ = Enum.Material
local MAT_SET = {
	[M_.WoodPlanks] = "wood", [M_.Wood] = "wood",
	[M_.Marble] = "stone", [M_.Slate] = "stone", [M_.Granite] = "stone", [M_.Limestone] = "stone", [M_.Sandstone] = "stone", [M_.Basalt] = "stone",
	[M_.CeramicTiles] = "tile", [M_.Glass] = "tile", [M_.Ice] = "tile", [M_.SmoothPlastic] = "tile", [M_.Plastic] = "tile",
	[M_.Concrete] = "concrete", [M_.Pavement] = "concrete", [M_.Cobblestone] = "concrete", [M_.Brick] = "concrete", [M_.Plaster] = "concrete", [M_.Asphalt] = "concrete",
	[M_.Metal] = "metal", [M_.DiamondPlate] = "metal", [M_.CorrodedMetal] = "metal", [M_.Foil] = "metal",
	[M_.Carpet] = "soft", [M_.Fabric] = "soft",
	[M_.Grass] = "grass", [M_.LeafyGrass] = "grass", [M_.Ground] = "grass", [M_.Mud] = "grass",
	[M_.Sand] = "sand", [M_.Snow] = "sand",
}
local stepFolder = Instance.new("Folder")
stepFolder.Name = "Steps"
stepFolder.Parent = gui
local stepPool = {}
for name, layers in STEP_SETS do
	stepPool[name] = {}
	for li, layer in layers do
		local pair = {}
		for k = 1, 2 do
			local snd = Instance.new("Sound")
			snd.SoundId = layer[1]
			snd.Volume = layer[3]
			local eq = Instance.new("EqualizerSoundEffect")
			eq.LowGain, eq.MidGain, eq.HighGain = layer[4][1], layer[4][2], layer[4][3]
			eq.Parent = snd
			if layer[5] then
				local rv = Instance.new("ReverbSoundEffect")
				rv.DecayTime = 1.2
				rv.WetLevel = -14
				rv.DryLevel = 0
				rv.Parent = snd
			end
			snd.Parent = stepFolder
			pair[k] = snd
		end
		stepPool[name][li] = { layer = layer, pair = pair, turn = 1 }
	end
end
local stride = { dist = 0, foot = 1 }
local function footfall(set: string, quiet: boolean)
	for _, l in stepPool[set] or stepPool.concrete do
		local snd = l.pair[l.turn]
		l.turn = 3 - l.turn
		snd.PlaybackSpeed = l.layer[2] * (0.94 + math.random() * 0.12)
		snd.Volume = l.layer[3] * (if quiet then 0.35 else 1) * (0.85 + math.random() * 0.3)
		snd:Play()
	end
end
local function stepSound(dt: number)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		return
	end
	local run = root:FindFirstChild("Running")
	if run and run:IsA("Sound") then
		run.Volume = 0
	end
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	if hum.FloorMaterial == Enum.Material.Air or speed < 1 or not app.steps or hiddenEye then
		stride.dist = math.min(stride.dist, 1.5)
		return
	end
	stride.dist += speed * dt
	local len = if app.sneaking then 2.6 else 3.9
	if stride.dist >= len then
		stride.dist = 0
		footfall(MAT_SET[hum.FloorMaterial] or "concrete", app.sneaking)
	end
end

-- Нельзя забираться на экспонаты, мебель и постаменты: если персонаж встал на
-- что-то, что не пол зала, он возвращается туда, где стоял на полу
local climb = { safe = nil :: CFrame?, y = 0 }
local climbRay = RaycastParams.new()
climbRay.FilterType = Enum.RaycastFilterType.Exclude
local WALK_NAMES = { Floor = true, Step = true, Ramp = true, StairLanding = true, Gallery = true, Porch = true, Stair = true, StairRamp = true, Path = true, Ground = true, Threshold = true }
local function walkable(part: Instance): boolean
	if part:IsA("Terrain") or WALK_NAMES[part.Name] then
		return true
	end
	local par = part.Parent
	if par and par:IsA("Model") then
		local n = par.Name
		return string.sub(n, 1, 5) == "Room_" or n == "Annex" or n == "Lobby"
	end
	return false
end
local function antiClimb()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or app.scene or app.dead or hiddenEye or root.Anchored then
		climb.safe = nil
		return
	end
	if hum.FloorMaterial == Enum.Material.Air then
		return
	end
	climbRay.FilterDescendantsInstances = { char }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -9, 0), climbRay)
	if not hit then
		return
	end
	if walkable(hit.Instance) then
		climb.safe = root.CFrame
		climb.y = hit.Position.Y
	elseif climb.safe and hit.Position.Y - climb.y > 0.4 then
		root.CFrame = CFrame.new(climb.safe.Position) * root.CFrame.Rotation
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function voidStep(t: number, dt: number)
	local pos = camera.CFrame.Position
	local near = 0
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	for _, g in CollectionService:GetTagged("VoidGap") do
		if g:IsA("BasePart") then
			local lp = g.CFrame:PointToObjectSpace(pos)
			local half = (g:GetAttribute("Width") or 16) / 2
			local along = math.max(0, math.abs(lp.Z) - half)
			local dist = math.sqrt(lp.X * lp.X + along * along)
			near = math.max(near, math.clamp(1 - dist / 40, 0, 1))
			-- пустота тянет к пролому: сильнее всего прямо напротив дыры
			if root and not hiddenEye and not app.dead and along < 5 and math.abs(lp.X) < 16 then
				local dir = g:GetAttribute("Dir")
				if typeof(dir) == "Vector3" then
					local strength = (5 + 7 * math.clamp(1 - math.abs(lp.X) / 13, 0, 1)) * (1 - along / 5)
					root.CFrame += dir * strength * dt
				end
			end
		end
	end
	local breath = 0.6 + 0.4 * math.sin(t * 1.3) * math.sin(t * 0.37 + 1)
	voidSound.Volume = if app.ambience then near * 1.1 * breath else 0
	voidSound.PlaybackSpeed = 0.08 + 0.02 * math.sin(t * 0.9)
	drone.Volume = if not app.ambience then 0 elseif inRun() then 0.1 + (1 - (workspace:GetAttribute("Light") or 1)) * 0.25 else 0.04
end

-- Тьма: плоское лицо дрожит, глаза и рот дёргаются
local function darkStep(t: number)
	for _, d in CollectionService:GetTagged("Darkness") do
		local face = d:FindFirstChild("Face")
		if face then
			for _, f in face:GetChildren() do
				if f.Name == "Tendril" then
					f.Rotation += 6 + math.random() * 8
					f.Size = UDim2.fromScale(0.12 + math.random() * 0.1, 0.4 + math.random() * 0.25)
				elseif f.Name == "EyeL" or f.Name == "EyeR" then
					f.Size = UDim2.fromScale(0.13, 0.12 + math.abs(math.sin(t * 9)) * 0.1)
				elseif f.Name == "Mouth" then
					f.Size = UDim2.fromScale(0.26 + math.sin(t * 13) * 0.06, 0.08 + math.abs(math.sin(t * 7)) * 0.16)
				elseif f.Name == "Body" then
					f.Size = UDim2.fromScale(0.64 + math.sin(t * 17) * 0.03, 0.64 + math.cos(t * 15) * 0.03)
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- глюк ложной двери

local glitch = Ui.frame(gui, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 45, Visible = false })
local function playGlitch()
	glitch.Visible = true
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	s.Volume = 1.2
	s.Parent = gui
	for _ = 1, 10 do
		glitch:ClearAllChildren()
		for _ = 1, 9 do
			Ui.frame(glitch, {
				BackgroundColor3 = Color3.fromHSV(math.random(), 0.8, math.random() * 0.8 + 0.2),
				BackgroundTransparency = 0.2 + math.random() * 0.5,
				Size = UDim2.new(1, 0, 0, math.random(4, 40)),
				Position = UDim2.new(math.random() * 0.2 - 0.1, 0, math.random(), 0),
				ZIndex = 46,
			})
		end
		s.PlaybackSpeed = 0.4 + math.random() * 1.6
		s:Play()
		camera.FieldOfView = 70 + math.random(-12, 12)
		task.wait(0.05)
	end
	glitch:ClearAllChildren()
	glitch.Visible = false
	camera.FieldOfView = 75
	s:Destroy()
end

-- ---------------------------------------------------------------------------
-- окна: Монетчик, кодовый замок, журнал

local function panel(w: number, h: number, z: number)
	local f = Ui.frame(gui, { BackgroundTransparency = 0.06, Size = UDim2.fromOffset(w, h), Position = UDim2.new(0.5, -w / 2, 0.5, -h / 2), Visible = false, ZIndex = z })
	Ui.corner(f, 10)
	Ui.pad(f, 14)
	return f
end

local coinBox = panel(340, 250, 64)
local function openCoin(price: number)
	coinBox:ClearAllChildren()
	Ui.corner(coinBox, 10)
	Ui.pad(coinBox, 14)
	Ui.list(coinBox, 10)
	Ui.label(coinBox, T("CoinLine"), { TextSize = 18, Size = UDim2.new(1, 0, 0, 56), ZIndex = 65, LayoutOrder = 1 })
	Ui.label(coinBox, T("CoinPrice", price), { Font = Ui.BOLD, TextColor3 = Ui.C.gold, TextSize = 20, ZIndex = 65, LayoutOrder = 2 })
	Ui.button(coinBox, T("PayGold"), function()
		local r = request("Pay", "gold")
		if r and r.ok then
			coinBox.Visible = false
		elseif r and r.error == "coins" then
			toast(T("NoGold"), Ui.C.red)
		else
			coinBox.Visible = false
		end
	end, { ZIndex = 65, LayoutOrder = 3, BackgroundColor3 = Ui.C.line })
	Ui.button(coinBox, T("PaySelf"), function()
		coinBox.Visible = false
		request("Pay", "self")
	end, { ZIndex = 65, LayoutOrder = 4 })
	coinBox.Visible = true
end

local CODE_RGB = { Color3.fromRGB(190, 40, 40), Color3.fromRGB(50, 90, 200), Color3.fromRGB(50, 150, 70), Color3.fromRGB(226, 190, 60) }
local keyBox = panel(280, 380, 64)
local function openKeypad(order)
	keyBox:ClearAllChildren()
	Ui.corner(keyBox, 10)
	Ui.pad(keyBox, 14)
	local entered = ""
	local slots = {}
	for i = 1, 4 do
		local f = Ui.frame(keyBox, { BackgroundColor3 = CODE_RGB[order[i]], Size = UDim2.fromOffset(54, 54), Position = UDim2.fromOffset((i - 1) * 64, 0), ZIndex = 65 })
		Ui.corner(f, 6)
		slots[i] = Ui.label(f, "", { Font = Ui.BOLD, TextSize = 30, Size = UDim2.fromScale(1, 1), ZIndex = 66, TextColor3 = Color3.new(1, 1, 1) })
	end
	local function show()
		for i = 1, 4 do
			slots[i].Text = string.sub(entered, i, i)
		end
	end
	local function press(ch: string)
		if #entered >= 4 then
			return
		end
		entered ..= ch
		show()
		if #entered == 4 then
			local r = request("Code", entered)
			if r and r.ok then
				keyBox.Visible = false
			else
				flashRed(0.2)
				entered = ""
				show()
			end
		end
	end
	for n = 1, 9 do
		Ui.button(keyBox, tostring(n), function()
			press(tostring(n))
		end, { Size = UDim2.fromOffset(76, 56), Position = UDim2.fromOffset(((n - 1) % 3) * 86, 70 + math.floor((n - 1) / 3) * 64), TextSize = 22, ZIndex = 65 })
	end
	Ui.button(keyBox, T("Clear"), function()
		entered = ""
		show()
	end, { Size = UDim2.fromOffset(120, 48), Position = UDim2.fromOffset(0, 270), ZIndex = 65 })
	Ui.button(keyBox, "✕", function()
		keyBox.Visible = false
	end, { Size = UDim2.fromOffset(120, 48), Position = UDim2.fromOffset(132, 270), ZIndex = 65 })
	keyBox.Visible = true
end

-- третий замок: нажать восемь экспонатов по порядку их римских номеров
local ODD_ICON = { wrench = "🔧", gear = "⚙️", teapot = "🫖", skull = "💀", crown = "👑", mask = "🎭", clock = "🕰️", boot = "🥾", bottle = "🍾", gem = "💎", bulb = "💡", bigkey = "🗝️" }
local orderBox = panel(360, 400, 64)
local function openOrder(items)
	orderBox:ClearAllChildren()
	Ui.corner(orderBox, 10)
	Ui.pad(orderBox, 14)
	local picked = {}
	local buttons = {}
	local title = Ui.label(orderBox, T("Order"), { Font = Ui.BOLD, TextSize = 17, Size = UDim2.new(1, -50, 0, 30), ZIndex = 65 })
	local _ = title
	Ui.button(orderBox, "✕", function()
		orderBox.Visible = false
	end, { Size = UDim2.fromOffset(40, 30), Position = UDim2.new(1, -40, 0, 0), ZIndex = 66 })
	local function reset()
		table.clear(picked)
		for _, b in buttons do
			b.BackgroundColor3 = Ui.C.panel
		end
	end
	for k = 1, 8 do
		local id = items[k]
		local b = Ui.button(orderBox, (ODD_ICON[id] or "?") .. "\n" .. T("odd_" .. tostring(id)), nil, { Size = UDim2.fromOffset(76, 150), Position = UDim2.fromOffset(((k - 1) % 4) * 84, 40 + math.floor((k - 1) / 4) * 160), TextSize = 13, TextWrapped = true, ZIndex = 65 })
		buttons[k] = b
		b.Activated:Connect(function()
			if table.find(picked, k) then
				return
			end
			table.insert(picked, k)
			b.BackgroundColor3 = Ui.C.line
			if #picked == 8 then
				local r = request("Order", picked)
				if r and r.ok then
					orderBox.Visible = false
				else
					flashRed(0.2)
					reset()
				end
			end
		end)
	end
	orderBox.Visible = true
end

local JOURNAL = { "darkness", "mimic", "coinkeeper", "colossus", "void" }
local journalBox = panel(420, 420, 62)
journalBox.Size = UDim2.new(0, 420, 0.82, 0)
journalBox.Position = UDim2.new(0.5, -210, 0.09, 0)
local function openJournal()
	journalBox:ClearAllChildren()
	Ui.corner(journalBox, 10)
	Ui.pad(journalBox, 14)
	journalBox.BackgroundColor3 = Color3.fromRGB(46, 38, 28)
	Ui.label(journalBox, T("Journal"), { Font = Ui.TITLE, TextSize = 28, TextColor3 = Ui.C.gold, Size = UDim2.new(1, -50, 0, 34), ZIndex = 63 })
	Ui.button(journalBox, "✕", function()
		journalBox.Visible = false
	end, { Size = UDim2.fromOffset(40, 34), Position = UDim2.new(1, -40, 0, 0), ZIndex = 64 })
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, 0, 1, -44)
	scroll.Position = UDim2.fromOffset(0, 44)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 6
	scroll.ZIndex = 63
	scroll.Parent = journalBox
	Ui.list(scroll, 10)
	local any = false
	for i, id in JOURNAL do
		if app.journal[id] then
			any = true
			Ui.label(scroll, T("j_" .. id), { Font = Ui.TITLE, TextSize = 24, TextColor3 = Ui.C.gold, Size = UDim2.new(1, -8, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 64, LayoutOrder = i * 2 })
			Ui.label(scroll, T("j_" .. id .. "_t"), { TextSize = 16, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 64, LayoutOrder = i * 2 + 1 })
		end
	end
	if not any then
		Ui.label(scroll, T("JournalEmpty"), { TextColor3 = Ui.C.dim, ZIndex = 64, Size = UDim2.new(1, 0, 0, 40) })
	end
	journalBox.Visible = true
end
local journalBtn = Ui.iconButton(gui, 46, function()
	if journalBox.Visible then
		journalBox.Visible = false
	else
		openJournal()
	end
end, { Position = UDim2.new(0, 16, 0, 100), BackgroundTransparency = 0.35, ZIndex = 11 })
Ui.bookIcon(journalBtn)

-- достижения: список с описаниями (открывается в лобби — кнопкой или у доски)
local ACH = { "darkness", "darkness_hid", "coinkeeper", "coin_paid", "mimic_solved", "door50", "colossus_down", "door100", "finale" }
local achBox = panel(440, 460, 62)
-- по высоте экрана: на телефоне в альбомной ориентации места мало
achBox.Size = UDim2.new(0, 440, 0.82, 0)
achBox.Position = UDim2.new(0.5, -220, 0.09, 0)
local function openAchievements()
	achBox:ClearAllChildren()
	Ui.corner(achBox, 10)
	Ui.pad(achBox, 14)
	achBox.BackgroundColor3 = Color3.fromRGB(30, 34, 40)
	local got = 0
	for _, id in ACH do
		if app.ach[id] then
			got += 1
		end
	end
	Ui.label(achBox, T("Achievements") .. "  " .. got .. "/" .. #ACH, { Font = Ui.TITLE, TextSize = 26, TextColor3 = Ui.C.gold, Size = UDim2.new(1, -50, 0, 34), ZIndex = 63, TextXAlignment = Enum.TextXAlignment.Left })
	Ui.button(achBox, "✕", function()
		achBox.Visible = false
	end, { Size = UDim2.fromOffset(40, 34), Position = UDim2.new(1, -40, 0, 0), ZIndex = 64 })
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, 0, 1, -44)
	scroll.Position = UDim2.fromOffset(0, 44)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 6
	scroll.ZIndex = 63
	scroll.Parent = achBox
	Ui.list(scroll, 8)
	for i, id in ACH do
		local on = app.ach[id] == true
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 62)
		row.BackgroundColor3 = if on then Color3.fromRGB(70, 60, 34) else Color3.fromRGB(44, 46, 50)
		row.LayoutOrder = i
		row.ZIndex = 63
		row.Parent = scroll
		Ui.corner(row, 8)
		local mark = Ui.frame(row, { BackgroundTransparency = 1, Size = UDim2.fromOffset(44, 62), ZIndex = 64 })
		if on then
			Ui.trophyIcon(mark)
		else
			Ui.chevron(mark, true, Ui.C.dim)
		end
		Ui.label(row, T("a_" .. id), { Font = Ui.TITLE, TextSize = 20, TextColor3 = if on then Ui.C.gold else Ui.C.dim, Size = UDim2.new(1, -52, 0, 26), Position = UDim2.fromOffset(48, 4), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 64 })
		Ui.label(row, T("a_" .. id .. "_t"), { TextSize = 14, TextWrapped = true, Size = UDim2.new(1, -52, 0, 30), Position = UDim2.fromOffset(48, 30), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 64 })
	end
	achBox.Visible = true
end
local achBtn = Ui.iconButton(gui, 46, function()
	if achBox.Visible then
		achBox.Visible = false
	else
		openAchievements()
	end
end, { Position = UDim2.new(0, 16, 0, 154), BackgroundTransparency = 0.35, ZIndex = 11 })
Ui.trophyIcon(achBtn)
local function refreshAchBtn()
	achBtn.Visible = not inRun()
	journalBtn.Visible = not app.dead and not app.scene
end
refreshAchBtn()
workspace:GetAttributeChangedSignal("Mode"):Connect(refreshAchBtn)

-- ---------------------------------------------------------------------------
-- смерть и наблюдение

local deathBox = Ui.frame(gui, { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 60 })
local deathTitle = Ui.label(deathBox, "", { Font = Ui.TITLE, TextSize = 44, TextColor3 = Ui.C.red, Size = UDim2.new(1, 0, 0, 56), Position = UDim2.new(0, 0, 0.3, 0), ZIndex = 61 })
local deathCause = Ui.label(deathBox, "", { TextSize = 18, Size = UDim2.new(0.9, 0, 0, 50), Position = UDim2.new(0.05, 0, 0.3, 64), ZIndex = 61 })
local spectBox = Ui.frame(gui, { BackgroundTransparency = 1, Size = UDim2.fromOffset(300, 100), Position = UDim2.new(0.5, -150, 1, -130), Visible = false, ZIndex = 60 })
local spectName = Ui.label(spectBox, "", { TextSize = 16, Size = UDim2.new(1, 0, 0, 24), ZIndex = 61 })
spectName.TextStrokeTransparency = 0.5
local nextBtn = Ui.button(spectBox, "", nil, { Size = UDim2.new(0.5, -4, 0, 44), Position = UDim2.new(0, 0, 0, 30), ZIndex = 61 })
local lobbyBtn = Ui.button(spectBox, "", function()
	task.spawn(request, "Lobby")
end, { Size = UDim2.new(0.5, -4, 0, 44), Position = UDim2.new(0.5, 4, 0, 30), ZIndex = 61, BackgroundColor3 = Ui.C.line })

local function spectate(step: number)
	local list = {}
	for _, q in Players:GetPlayers() do
		if q ~= player and q:GetAttribute("Alive") and q.Character then
			table.insert(list, q)
		end
	end
	nextBtn.Text = T("SpectateNext")
	lobbyBtn.Text = T("BackToLobby")
	if #list == 0 then
		spectName.Text = ""
		return
	end
	local idx = table.find(list, app.spectating) or 0
	idx = (idx + step - 1) % #list + 1
	local q = list[idx]
	app.spectating = q
	local hum = q.Character:FindFirstChildOfClass("Humanoid")
	player.CameraMode = Enum.CameraMode.Classic
	camera.CameraType = Enum.CameraType.Custom
	if hum then
		camera.CameraSubject = hum
	end
	spectName.Text = T("Spectating", q.DisplayName)
end
nextBtn.Activated:Connect(function()
	spectate(1)
end)

local function closePanels()
	coinBox.Visible = false
	keyBox.Visible = false
	orderBox.Visible = false
	journalBox.Visible = false
end

local function onDead(msg)
	app.dead = true
	hiddenEye = nil
	leaveBtn.Visible = false
	slits.Visible = false
	hud.Visible = false
	closePanels()
	deathTitle.Text = T("Died")
	local id = msg.cause
	deathCause.Text = (if id and Lang.en["j_" .. id] then T("j_" .. id) .. "\n" else "") .. T("DiedAt", Rules.plate(msg.door or 0))
	deathBox.Visible = true
	task.delay(4, function()
		if app.dead then
			deathBox.Visible = false
			spectBox.Visible = true
			spectate(1)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- сцены

-- Колосс: камера уходит к статуе, та оживает, камера возвращается
local function sceneBoss(focus: CFrame)
	app.scene = true
	hud.Visible = false
	closePanels()
	local from = camera.CFrame
	local lookAt = (focus * CFrame.new(0, 5, 0)).Position
	local to = CFrame.lookAt((focus * CFrame.new(9, 7, -24)).Position, lookAt)
	camera.CameraType = Enum.CameraType.Scriptable
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t < 1.6 then
			camera.CFrame = from:Lerp(to, TweenService:GetValue(t / 1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
		elseif t < 6 then
			local push = (t - 1.6) / 4.4
			camera.CFrame = to * CFrame.new(0, 0, -push * 6) * CFrame.Angles((math.random() - 0.5) * 0.01 * push * 4, (math.random() - 0.5) * 0.01 * push * 4, 0)
		else
			conn:Disconnect()
			app.scene = false
			hud.Visible = inRun() and not app.dead
			setCamera()
		end
	end)
end

-- дверь 100: открывается, вход, дверь захлопывается, взгляд назад и снова вперёд
local function sceneFinal(door: CFrame)
	app.scene = true
	hud.Visible = false
	closePanels()
	camera.CameraType = Enum.CameraType.Scriptable
	local eye = CFrame.new(0, 4.6, 0)
	local a = door * CFrame.new(0, 0, 7) * eye
	local b = door * CFrame.new(0, 0, -8) * eye
	local t0 = os.clock()
	local slammed = false
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local cf
		if t < 0.8 then
			cf = a
		elseif t < 2.6 then
			cf = a:Lerp(b, TweenService:GetValue((t - 0.8) / 1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
		elseif t < 3.5 then
			if not slammed then
				slammed = true
				app.shake = 0.8
				task.delay(0.4, function()
					app.shake = 0
				end)
			end
			cf = b * CFrame.Angles(0, math.pi * math.clamp((t - 2.7) / 0.6, 0, 1), 0)
		elseif t < 4.8 then
			cf = b * CFrame.Angles(0, math.pi, 0)
		elseif t < 5.8 then
			cf = b * CFrame.Angles(0, math.pi * (1 - math.clamp((t - 4.8) / 0.9, 0, 1)), 0)
		else
			conn:Disconnect()
			app.scene = false
			hud.Visible = inRun() and not app.dead
			setCamera()
			return
		end
		if app.shake > 0 then
			cf *= CFrame.Angles((math.random() - 0.5) * 0.03, (math.random() - 0.5) * 0.03, 0)
		end
		camera.CFrame = cf
	end)
end

-- «Продолжение следует»: экран можно закрыть и вернуть, камера кружит вокруг героя
local tbcBox = Ui.frame(gui, { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 70 })
local tbcTitle = Ui.label(tbcBox, "", { Font = Ui.TITLE, TextSize = 46, TextColor3 = Ui.C.gold, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0.34, 0), ZIndex = 71 })
tbcTitle.TextStrokeTransparency = 0.4
local tbcLine = Ui.frame(tbcBox, { BackgroundColor3 = Ui.C.gold, Size = UDim2.new(0, 260, 0, 2), Position = UDim2.new(0.5, -130, 0.34, 66), ZIndex = 71 })
local _ = tbcLine
local tbcLobby = Ui.button(tbcBox, "", function()
	task.spawn(request, "Lobby")
end, { Size = UDim2.fromOffset(220, 48), Position = UDim2.new(0.5, -110, 0.34, 90), ZIndex = 71, BackgroundColor3 = Ui.C.line })
local tbcOpen
local function setTbc(on: boolean)
	app.tbc = on
	tbcBox.Visible = on
	tbcOpen.Visible = not on
	tbcTitle.Text = T("ToBeContinued")
	tbcLobby.Text = T("BackToLobby")
	hud.Visible = not on and inRun() and not app.dead
	if on then
		camera.CameraType = Enum.CameraType.Scriptable
	else
		setCamera()
	end
end
Ui.button(tbcBox, "✕", function()
	setTbc(false)
end, { Size = UDim2.fromOffset(44, 40), Position = UDim2.new(1, -60, 0, 50), ZIndex = 71 })
tbcOpen = Ui.button(gui, "…", function()
	setTbc(true)
end, { Size = UDim2.fromOffset(48, 40), Position = UDim2.new(0.5, -24, 0, 50), Visible = false, ZIndex = 69, BackgroundTransparency = 0.4 })

-- ---------------------------------------------------------------------------
-- настройки и админ-панель

local setBox = Ui.frame(gui, { BackgroundTransparency = 0.08, Size = UDim2.fromOffset(260, 250), Position = UDim2.new(1, -272, 0, 92), Visible = false, ZIndex = 80 })
local function buildSettings()
	setBox:ClearAllChildren()
	Ui.corner(setBox, 10)
	Ui.pad(setBox, 10)
	Ui.list(setBox, 8)
	Ui.label(setBox, T("Settings"), { Font = Ui.BOLD, TextSize = 18, ZIndex = 81, LayoutOrder = 1 })
	local row = Ui.frame(setBox, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), ZIndex = 81, LayoutOrder = 2 })
	for i, l in { "en", "ru" } do
		Ui.button(row, string.upper(l), function()
			app.lang = l
			task.spawn(request, "Lang", l)
			localizeAll()
			refreshHud()
			buildSettings()
		end, { Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new((i - 1) * 0.5, (i - 1) * 4, 0, 0), ZIndex = 82, BackgroundColor3 = if app.lang == l then Ui.C.line else Ui.C.panel })
	end
	local function toggle(order: number, key: string, get: () -> boolean, set: (boolean) -> ())
		Ui.button(setBox, T(key) .. ": " .. (if get() then T("On") else T("Off")), function()
			set(not get())
			buildSettings()
		end, { ZIndex = 82, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 40) })
	end
	toggle(3, "Steps", function()
		return app.steps
	end, function(v)
		app.steps = v
	end)
	toggle(4, "Ambience", function()
		return app.ambience
	end, function(v)
		app.ambience = v
	end)
	toggle(5, "Shadows", function()
		return Lighting.GlobalShadows
	end, function(v)
		Lighting.GlobalShadows = v
	end)
end
-- настройки — рядом со стандартными кнопками Roblox (значок, меню, чат)
local setBtn = Ui.iconButton(gui, 40, function()
	setBox.Visible = not setBox.Visible
	if setBox.Visible then
		buildSettings()
	end
end, { BackgroundTransparency = 0.25, ZIndex = 79 })
Ui.gearIcon(setBtn)
local adminSlot = nil
local function placeTopbar()
	local inset = GuiService.TopbarInset
	local x = if inset.Width > 0 then inset.Min.X + 6 else 240
	local h = if inset.Height > 0 then inset.Height else 44
	local y = inset.Min.Y + (h - 40) / 2
	setBtn.Position = UDim2.fromOffset(x, y)
	setBox.Position = UDim2.fromOffset(x, y + 48)
	if adminSlot then
		adminSlot.Position = UDim2.fromOffset(x + 48, y)
	end
end
placeTopbar()
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeTopbar)

task.spawn(function()
	local ok, res = pcall(function()
		return Remotes.fn("AdminRequest"):InvokeServer("Status")
	end)
	if not ok or not res or not res.admin then
		return
	end
	local ap = Ui.frame(gui, { BackgroundTransparency = 0.08, Size = UDim2.fromOffset(290, 400), Position = UDim2.new(1, -302, 0, 92), Visible = false, ZIndex = 85 })
	Ui.corner(ap, 10)
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 6
	scroll.ZIndex = 86
	scroll.Parent = ap
	Ui.pad(scroll, 8)
	Ui.list(scroll, 6)
	local function fill()
		for _, c in scroll:GetChildren() do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		for i, c in AdminCommands.LIST do
			Ui.button(scroll, if app.lang == "ru" then c.ru else c.en, function()
				local r = Remotes.fn("AdminRequest"):InvokeServer("Run", c.id)
				toast(if r and r.ok then T("Done") else T("Failed"), if r and r.ok then Ui.C.good else Ui.C.red, 2)
			end, { LayoutOrder = i, ZIndex = 87, Size = UDim2.new(1, -4, 0, 40), TextSize = 14 })
		end
	end
	adminSlot = Ui.button(gui, string.upper(T("Admin")), function()
		ap.Visible = not ap.Visible
		setBox.Visible = false
		if ap.Visible then
			fill()
		end
	end, { Size = UDim2.fromOffset(70, 40), TextSize = 12, BackgroundTransparency = 0.25, ZIndex = 79, TextColor3 = Ui.C.gold })
	placeTopbar()
	ap.Position = UDim2.new(0, adminSlot.Position.X.Offset, 0, adminSlot.Position.Y.Offset + 48)
end)

-- ---------------------------------------------------------------------------
-- инвентарь: ячейки внизу экрана, в каждой — объёмная моделька предмета.
-- Нажми ячейку (или 1–9), чтобы взять предмет в руку; ещё раз — убрать

local ITEM_ORDER = { flashlight = 1, battery = 2, plant = 3, lockpick = 4, key = 5, hammer = 6, meat = 7, pole = 8, lens = 9, coldkey = 10, clockkey = 11 }
local invBar = Ui.frame(gui, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(0, 70), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 12 })
Ui.list(invBar, 8, true)
local invName = Ui.label(gui, "", { Font = Ui.BOLD, TextSize = 15, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -88), Size = UDim2.fromOffset(300, 22), ZIndex = 12 })
invName.TextStrokeTransparency = 0.5
local invTools: { Tool } = {}

local function myTools(): { Tool }
	local list = {}
	local bp = player:FindFirstChildOfClass("Backpack")
	for _, holder in { bp, player.Character } do
		if holder then
			for _, t in holder:GetChildren() do
				if t:IsA("Tool") then
					table.insert(list, t)
				end
			end
		end
	end
	table.sort(list, function(a, b)
		return (ITEM_ORDER[a:GetAttribute("Item") or ""] or 99) < (ITEM_ORDER[b:GetAttribute("Item") or ""] or 99)
	end)
	return list
end

-- моделька предмета в окошке ячейки
local function itemView(tool: Tool, parent: GuiObject)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.new(1, -8, 1, -8)
	vp.Position = UDim2.fromOffset(4, 4)
	vp.Ambient = Color3.fromRGB(150, 140, 130)
	vp.LightColor = Color3.fromRGB(255, 236, 210)
	vp.LightDirection = Vector3.new(-1, -1.4, -0.6)
	vp.ZIndex = parent.ZIndex + 1
	local m = Instance.new("Model")
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then
		return vp
	end
	local base = handle.CFrame
	for _, d in tool:GetDescendants() do
		if d:IsA("BasePart") then
			local c = Instance.new("Part")
			c.Size = d.Size
			c.Color = d.Color
			c.Material = d.Material
			c.Transparency = d.Transparency
			c.Anchored = true
			if d:IsA("Part") then
				c.Shape = d.Shape
			end
			c.CFrame = base:ToObjectSpace(d.CFrame)
			c.Parent = m
		end
	end
	m.Parent = vp
	local cf, size = m:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 35
	local r = math.max(size.X, size.Y, size.Z)
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(r * 1.1, r * 0.9, r * 1.5), cf.Position)
	cam.Parent = vp
	vp.CurrentCamera = cam
	vp.Parent = parent
	return vp
end

local function equipToggle(tool: Tool)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or app.dead or hiddenEye then
		return
	end
	if tool.Parent == char then
		hum:UnequipTools()
	else
		hum:EquipTool(tool)
	end
end

local function rebuildInv()
	for _, c in invBar:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	invTools = myTools()
	local held = nil
	for i, tool in invTools do
		local on = tool.Parent == player.Character
		local slot = Ui.button(invBar, "", function()
			equipToggle(tool)
		end, { Size = UDim2.fromOffset(62, 62), BackgroundTransparency = if on then 0.05 else 0.3, LayoutOrder = i, ZIndex = 12 })
		local st = slot:FindFirstChildOfClass("UIStroke")
		if st then
			st.Color = if on then Ui.C.gold else Ui.C.line
			st.Thickness = if on then 2.4 else 1.2
			st.Transparency = 0
		end
		itemView(tool, slot)
		Ui.label(slot, tostring(i), { Font = Ui.BOLD, TextSize = 11, TextColor3 = Ui.C.dim, Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(4, 2), ZIndex = 15, TextXAlignment = Enum.TextXAlignment.Left })
		local count = string.match(tool.Name, "×(%d+)$")
		if count then
			local badge = Ui.label(slot, count, { Font = Ui.BOLD, TextSize = 13, TextColor3 = Ui.C.text, Size = UDim2.fromOffset(22, 16), Position = UDim2.new(1, -24, 1, -18), ZIndex = 15, TextXAlignment = Enum.TextXAlignment.Right })
			badge.TextStrokeTransparency = 0.4
		end
		if tool:GetAttribute("Item") == "flashlight" then
			local fl = (player:GetAttribute("Flash") or Rules.FLASH_MAX) / Rules.FLASH_MAX
			local back = Ui.frame(slot, { BackgroundColor3 = Color3.fromRGB(20, 18, 16), Size = UDim2.new(1, -12, 0, 4), Position = UDim2.new(0, 6, 1, -7), ZIndex = 15 })
			Ui.frame(back, { BackgroundColor3 = Color3.fromRGB(230, 210, 120), Size = UDim2.fromScale(math.clamp(fl, 0, 1), 1), ZIndex = 16 })
		end
		if on then
			held = tool
		end
	end
	invName.Text = if held then (string.gsub(held.Name, " ×%d+$", "")) else ""
	invBar.Visible = not app.dead and not app.scene and not app.tbc
end

local invQueued = false
local function queueInv()
	if invQueued then
		return
	end
	invQueued = true
	task.defer(function()
		invQueued = false
		rebuildInv()
	end)
end
local function watchHolder(h: Instance?)
	if not h then
		return
	end
	h.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then
			c:GetPropertyChangedSignal("Name"):Connect(queueInv)
			queueInv()
		end
	end)
	h.ChildRemoved:Connect(queueInv)
	for _, c in h:GetChildren() do
		if c:IsA("Tool") then
			c:GetPropertyChangedSignal("Name"):Connect(queueInv)
		end
	end
	queueInv()
end
player.ChildAdded:Connect(function(c)
	if c:IsA("Backpack") then
		watchHolder(c)
	end
end)
watchHolder(player:FindFirstChildOfClass("Backpack"))
player.CharacterAdded:Connect(watchHolder)
watchHolder(player.Character)
player:GetAttributeChangedSignal("Flash"):Connect(queueInv)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local n = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
	if n >= 1 and n <= 9 and invTools[n] then
		equipToggle(invTools[n])
	end
end)

-- ---------------------------------------------------------------------------
-- атмосфера: затемнение по краям экрана, пыль в воздухе, покачивание головы при ходьбе

local vignette = Ui.frame(fullGui, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 })
for _, e in { { 0, 0, 1, 0.22, 90 }, { 0, 0.78, 1, 0.22, -90 }, { 0, 0, 0.18, 1, 0 }, { 0.82, 0, 0.18, 1, 180 } } do
	local f = Ui.frame(vignette, { BackgroundColor3 = Color3.new(0, 0, 0), Position = UDim2.fromScale(e[1], e[2]), Size = UDim2.fromScale(e[3], e[4]), ZIndex = 2 })
	local g = Instance.new("UIGradient")
	g.Rotation = e[5]
	g.Transparency = NumberSequence.new(0.25, 1)
	g.Parent = f
end

local dustPart = Instance.new("Part")
dustPart.Name = "Dust"
dustPart.Anchored = true
dustPart.CanCollide = false
dustPart.CanQuery = false
dustPart.CanTouch = false
dustPart.Transparency = 1
dustPart.Size = Vector3.new(36, 14, 36)
local dust = Instance.new("ParticleEmitter")
dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
dust.Shape = Enum.ParticleEmitterShape.Box
dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
dust.Rate = 14
dust.Lifetime = NumberRange.new(6, 10)
dust.Speed = NumberRange.new(0.05, 0.3)
dust.SpreadAngle = Vector2.new(180, 180)
dust.Size = NumberSequence.new(0.06)
dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(1, 1) })
dust.Color = ColorSequence.new(Color3.fromRGB(240, 226, 200))
dust.LightInfluence = 1
dust.RotSpeed = NumberRange.new(-20, 20)
dust.Parent = dustPart
dustPart.Parent = workspace

local bob = { t = 0, amp = 0 }
RunService:BindToRenderStep("MuseumBob", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local run = inRun()
	vignette.Visible = run and not app.tbc
	dust.Enabled = run
	if run then
		dustPart.CFrame = CFrame.new(camera.CFrame.Position)
	end
	if app.scene or app.tbc or hiddenEye or app.dead or not run then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		return
	end
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local moving = speed > 1 and hum.FloorMaterial ~= Enum.Material.Air
	if moving then
		bob.t += dt * (if app.sneaking then 6 else 9.5) * math.clamp(speed / 15, 0.5, 1.2)
	end
	local want = if moving then (if app.sneaking then 0.05 else 0.12) else 0
	bob.amp += (want - bob.amp) * math.min(1, dt * 6)
	local a = bob.amp
	local breathe = math.sin(os.clock() * 1.5) * 0.015
	camera.CFrame *= CFrame.new(math.cos(bob.t) * a * 0.55, math.abs(math.sin(bob.t)) * a - a * 0.5 + breathe, 0) * CFrame.Angles(0, 0, math.cos(bob.t) * a * 0.05)
end)

-- ---------------------------------------------------------------------------
-- сообщения сервера

Remotes.event("Game").OnClientEvent:Connect(function(msg)
	if msg.type == "toast" then
		toast(T(msg.key, table.unpack(msg.args or {})))
	elseif msg.type == "dark" then
		if msg.phase == "warn" then
			app.shake = math.max(app.shake, 0.2)
		elseif msg.phase == "rush" then
			app.shake = 1.3
		else
			app.shake = 0
		end
	elseif msg.type == "fx" then
		if msg.kind == "scare" then
			flashRed(0.6)
			app.shake = 0.6
			task.delay(0.5, function()
				app.shake = 0
			end)
		elseif msg.kind == "blood" then
			flashRed(0.75)
		elseif msg.kind == "shake" then
			app.shake = 1
			task.delay(0.9, function()
				app.shake = 0
			end)
		elseif msg.kind == "melt" then
			app.shake = 0.5
			task.delay(4, function()
				app.shake = 0
			end)
		end
	elseif msg.type == "glitch" then
		task.spawn(playGlitch)
	elseif msg.type == "achieve" then
		app.ach[msg.id] = true
		toast(T("AchNew", T("a_" .. msg.id)), Ui.C.gold, 4)
	elseif msg.type == "openAch" then
		openAchievements()
	elseif msg.type == "journal" then
		app.journal[msg.id] = true
		if msg.new then
			toast(T("JournalNew"), Ui.C.gold, 3)
		end
	elseif msg.type == "coin" then
		openCoin(msg.price or 0)
	elseif msg.type == "keypad" then
		openKeypad(msg.order or { 1, 2, 3, 4 })
	elseif msg.type == "order" and type(msg.items) == "table" then
		openOrder(msg.items)
	elseif msg.type == "voice" then
		say(T(msg.key), true)
	elseif msg.type == "cutscene" then
		if msg.kind == "boss" and typeof(msg.focus) == "CFrame" then
			sceneBoss(msg.focus)
		elseif msg.kind == "final" and typeof(msg.door) == "CFrame" and not app.dead then
			sceneFinal(msg.door)
		end
	elseif msg.type == "tbc" then
		setTbc(true)
	elseif msg.type == "enter" then
		TweenService:Create(black, TweenInfo.new(2.5), { BackgroundTransparency = 0 }):Play()
	elseif msg.type == "enterFailed" then
		black.BackgroundTransparency = 1
	elseif msg.type == "dead" then
		onDead(msg)
	elseif msg.type == "results" then
		if not app.tbc then
			toast(T("Results", Rules.plate(msg.door or 0)), Ui.C.text, 8)
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or app.dead or not inRun() then
		return
	end
	if input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.LeftControl then
		setSneak(not app.sneaking)
	elseif input.KeyCode == Enum.KeyCode.J then
		if journalBox.Visible then
			journalBox.Visible = false
		else
			openJournal()
		end
	elseif hiddenEye and (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Q) then
		task.spawn(request, "Unhide")
	end
end)

-- ---------------------------------------------------------------------------
-- новый персонаж

local function onMode()
	applyLighting()
	queueInv()
	refreshAchBtn()
	hud.Visible = inRun() and not app.dead and not app.scene and not app.tbc
	setCamera()
	if inRun() and not app.arrived and player.Character then
		app.arrived = true
		black.BackgroundTransparency = 0
		TweenService:Create(black, TweenInfo.new(2), { BackgroundTransparency = 1 }):Play()
		task.delay(1.5, function()
			say(T("DoorShut"))
		end)
	end
end

local function onCharacter(char: Model)
	app.dead = false
	app.spectating = nil
	hiddenEye = nil
	deathBox.Visible = false
	spectBox.Visible = false
	leaveBtn.Visible = false
	if app.sneaking then
		setSneak(false)
	end
	local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
	if hum then
		camera.CameraSubject = hum
		hum.HealthChanged:Connect(function(h)
			refreshHud()
			if h < app.lastHp - 1 then
				flashRed(0.3)
			end
			app.lastHp = h
		end)
		app.lastHp = hum.Health
	end
	char.ChildAdded:Connect(refreshHud)
	char.ChildRemoved:Connect(refreshHud)
	onMode()
	refreshHud()
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end
workspace:GetAttributeChangedSignal("Mode"):Connect(onMode)

local watchT = 0
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	darkStep(t)
	voidStep(t, dt)
	stepSound(dt)
	antiClimb()
	if app.scene then
		return
	end
	if app.tbc then
		-- камера медленно кружит вокруг героя
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local a = t * 0.25
			local pos = root.Position + Vector3.new(math.cos(a) * 13, 5, math.sin(a) * 13)
			camera.CFrame = CFrame.lookAt(pos, root.Position + Vector3.new(0, 1.5, 0))
		end
		return
	end
	if hiddenEye then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = hiddenEye
	elseif camera.CameraType == Enum.CameraType.Scriptable then
		setCamera()
	end
	if app.shake > 0 then
		local a = app.shake * 0.04
		camera.CFrame *= CFrame.Angles((math.random() - 0.5) * a, (math.random() - 0.5) * a, 0)
	end
	local on = player:GetAttribute("FlashOn") == true and not app.dead
	beam.Enabled = on
	if on then
		camLight.CFrame = camera.CFrame * CFrame.new(0.6, -0.5, 0)
		local char = player.Character
		local tool = char and char:FindFirstChildOfClass("Tool")
		local hb = tool and tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("Beam")
		if hb then
			hb.Enabled = false
		end
	end
	watchT += dt
	if app.dead and app.spectating and watchT > 0.5 then
		watchT = 0
		if not app.spectating:GetAttribute("Alive") then
			spectate(1)
		end
	end
end)

localizeAll()
applyLighting()
refreshHud()
