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
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
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

local sneakBtn = Ui.button(hud, "🧍", nil, { Size = UDim2.fromOffset(64, 64), Position = UDim2.new(1, -84, 1, -210), TextSize = 34, BackgroundTransparency = 0.45, ZIndex = 11 })
local function setSneak(on: boolean)
	app.sneaking = on
	sneakBtn.Text = if on then "🧎" else "🧍"
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
	flBack.Visible = tool ~= nil and tool:GetAttribute("Item") == "flashlight"
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

-- высота и громкость шагов для материала пола
local STEP = {
	[Enum.Material.Marble] = { 1.2, 0.8 },
	[Enum.Material.Slate] = { 1.05, 0.7 },
	[Enum.Material.WoodPlanks] = { 0.9, 0.65 },
	[Enum.Material.Wood] = { 0.9, 0.65 },
	[Enum.Material.Carpet] = { 0.7, 0.2 },
	[Enum.Material.Fabric] = { 0.7, 0.2 },
	[Enum.Material.Concrete] = { 0.95, 0.6 },
	[Enum.Material.CeramicTiles] = { 1.3, 0.75 },
	[Enum.Material.DiamondPlate] = { 1.5, 0.9 },
	[Enum.Material.Metal] = { 1.5, 0.9 },
	[Enum.Material.Sand] = { 0.6, 0.3 },
	[Enum.Material.Grass] = { 0.65, 0.3 },
	[Enum.Material.Cobblestone] = { 1, 0.6 },
}
local function stepSound()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local snd = root and root:FindFirstChild("Running")
	if not snd or not hum or not snd:IsA("Sound") then
		return
	end
	local prof = STEP[hum.FloorMaterial] or { 1, 0.6 }
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	-- медленный шаг — редкие и тихие шаги
	snd.PlaybackSpeed = 1.85 * prof[1] * math.clamp(speed / 15, 0.45, 1.1)
	snd.Volume = if app.steps then prof[2] * (if app.sneaking then 0.3 else 1) else 0
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
local journalBtn = Ui.button(hud, "📖", function()
	if journalBox.Visible then
		journalBox.Visible = false
	else
		openJournal()
	end
end, { Size = UDim2.fromOffset(48, 44), Position = UDim2.new(0, 16, 0, 100), TextSize = 24, BackgroundTransparency = 0.5, ZIndex = 11 })
local _ = journalBtn

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
		Ui.label(row, if on then "🏆" else "🔒", { TextSize = 26, Size = UDim2.fromOffset(44, 62), ZIndex = 64 })
		Ui.label(row, T("a_" .. id), { Font = Ui.TITLE, TextSize = 20, TextColor3 = if on then Ui.C.gold else Ui.C.dim, Size = UDim2.new(1, -52, 0, 26), Position = UDim2.fromOffset(48, 4), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 64 })
		Ui.label(row, T("a_" .. id .. "_t"), { TextSize = 14, TextWrapped = true, Size = UDim2.new(1, -52, 0, 30), Position = UDim2.fromOffset(48, 30), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 64 })
	end
	achBox.Visible = true
end
local achBtn = Ui.button(hud, "🏆", function()
	if achBox.Visible then
		achBox.Visible = false
	else
		openAchievements()
	end
end, { Size = UDim2.fromOffset(48, 44), Position = UDim2.new(0, 16, 0, 150), TextSize = 24, BackgroundTransparency = 0.5, ZIndex = 11 })
local function refreshAchBtn()
	achBtn.Visible = not inRun()
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
Ui.button(gui, "⚙", function()
	setBox.Visible = not setBox.Visible
	if setBox.Visible then
		buildSettings()
	end
end, { Size = UDim2.fromOffset(40, 36), Position = UDim2.new(1, -52, 0, 50), TextSize = 20, BackgroundTransparency = 0.5, ZIndex = 79 })

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
	Ui.button(gui, T("Admin"), function()
		ap.Visible = not ap.Visible
		setBox.Visible = false
		if ap.Visible then
			fill()
		end
	end, { Size = UDim2.fromOffset(64, 36), Position = UDim2.new(1, -124, 0, 50), TextSize = 13, BackgroundTransparency = 0.5, ZIndex = 79, TextColor3 = Ui.C.gold })
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
	stepSound()
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
