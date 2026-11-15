--!nonstrict
-- Клиент «The Labyrinth». Без главного меню: в лобби — свой персонаж и лифт, в забеге —
-- вид от первого лица и минимум кнопок: здоровье, монеты, «тихо», выход из укрытия.
-- Предметы — в обычном инвентаре Roblox. Эффекты: Гул, глюк ложной двери, пустота за
-- окнами, погоня, финальная сцена у обрыва

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
	ending = false,
	spectating = nil :: Player?,
	shake = 0,
	lastHp = 100,
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

-- темнота: свет только от ламп и фонарика, туман гуще с глубиной
Lighting.Ambient = Color3.fromRGB(10, 9, 9)
Lighting.OutdoorAmbient = Color3.fromRGB(0, 0, 0)
Lighting.Brightness = 0
Lighting.ClockTime = 0
Lighting.FogColor = Color3.fromRGB(3, 3, 4)
Lighting.FogStart = 20
Lighting.FogEnd = 160
pcall(function()
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
end)
local tint = Instance.new("ColorCorrectionEffect")
tint.Saturation = -0.2
tint.Contrast = 0.12
tint.Parent = Lighting
local function updateFog()
	local light = workspace:GetAttribute("Light") or 1
	Lighting.FogEnd = 70 + 100 * light
	tint.Saturation = -0.2 - (1 - light) * 0.3
end
workspace:GetAttributeChangedSignal("Light"):Connect(updateFog)

-- ---------------------------------------------------------------------------
-- экран

local gui = Instance.new("ScreenGui")
gui.Name = "Labyrinth"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local black = Ui.frame(gui, { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40 })
local red = Ui.frame(gui, { BackgroundColor3 = Color3.fromRGB(140, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 41 })

local toastBox = Ui.frame(gui, { BackgroundTransparency = 1, Size = UDim2.new(0.9, 0, 0, 160), Position = UDim2.new(0.05, 0, 0.66, 0), ZIndex = 50 })
Ui.list(toastBox, 4)
local function toast(text: string, color: Color3?, seconds: number?)
	local l = Ui.label(toastBox, text, { Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, TextSize = 16, TextColor3 = color or Ui.C.text, ZIndex = 51 })
	l.TextStrokeTransparency = 0.5
	task.delay(seconds or 2.6, function()
		TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(0.6, function()
			l:Destroy()
		end)
	end)
end

local banner = Ui.label(gui, "", { Font = Ui.TITLE, TextSize = 34, TextColor3 = Ui.C.text, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0.24, 0), TextTransparency = 1, ZIndex = 52 })
banner.TextStrokeTransparency = 1
local function showBanner(text: string, seconds: number?)
	banner.Text = text
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.5
	task.delay(seconds or 3, function()
		if banner.Text == text then
			TweenService:Create(banner, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local function flashRed(strength: number)
	red.BackgroundTransparency = 1 - strength
	TweenService:Create(red, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()
end

-- ---------------------------------------------------------------------------
-- интерфейс забега: тонкая полоска здоровья и монеты слева, «тихо» справа

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

-- «тихо»: человечек стоит или пригнулся
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

-- выход из шкафчика
local leaveBtn = Ui.button(gui, "", function()
	task.spawn(request, "Unhide")
end, { Size = UDim2.fromOffset(160, 48), Position = UDim2.new(0.5, -80, 1, -150), Visible = false, ZIndex = 30 })

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
-- подписи кнопок и табличек на языке игрока; отмычку видно, только если она есть

local function localize(d: Instance)
	if d:IsA("ProximityPrompt") then
		local kind = d:GetAttribute("Kind")
		if kind then
			d.ActionText = T("p_" .. kind, d:GetAttribute("Price") or 0)
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
	if app.ending then
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
workspace:GetAttributeChangedSignal("Mode"):Connect(setCamera)

local hiddenEye = nil
player:GetAttributeChangedSignal("HiddenEye"):Connect(function()
	local eye = player:GetAttribute("HiddenEye")
	hiddenEye = if typeof(eye) == "CFrame" then eye else nil
	leaveBtn.Visible = hiddenEye ~= nil
	if not hiddenEye then
		setCamera()
	end
end)

player:GetAttributeChangedSignal("Sneaking"):Connect(function()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		-- пригнулся: камера ниже
		TweenService:Create(hum, TweenInfo.new(0.25), { CameraOffset = if player:GetAttribute("Sneaking") then Vector3.new(0, -1.6, 0) else Vector3.zero }):Play()
	end
end)

-- свет фонарика идёт от камеры (у себя); у других — из фонарика в руке
local camLight = Instance.new("Part")
camLight.Name = "LabCamLight"
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
-- взгляд на Смотрителя

local seenAt = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function checkWatchers()
	if app.dead or not inRun() then
		return
	end
	local now = os.clock()
	for _, m in CollectionService:GetTagged("Watcher") do
		local id = m:GetAttribute("WatcherId")
		local head = m:FindFirstChild("Head")
		if id and head then
			local from = camera.CFrame.Position
			for _, partName in { "Head", "Chest", "Body" } do
				local part = m:FindFirstChild(partName)
				if part then
					local vp, onScreen = camera:WorldToViewportPoint(part.Position)
					if onScreen and vp.Z > 0 and (part.Position - from).Magnitude < 90 then
						rayParams.FilterDescendantsInstances = { player.Character, m, camLight }
						local hit = workspace:Raycast(from, part.Position - from, rayParams)
						if not hit and now - (seenAt[id] or 0) > 0.12 then
							seenAt[id] = now
							task.spawn(request, "Seen", id)
							break
						end
					end
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- пустота за окнами: тяжёлое неровное дыхание, громче у окна

local voidSound = Instance.new("Sound")
voidSound.SoundId = "rbxasset://sounds/swoosh.wav"
voidSound.Looped = true
voidSound.PlaybackSpeed = 0.09
voidSound.Volume = 0
voidSound.Parent = gui
voidSound:Play()
local drone = Instance.new("Sound")
drone.SoundId = "rbxasset://sounds/swoosh.wav"
drone.Looped = true
drone.PlaybackSpeed = 0.05
drone.Volume = 0.15
drone.Parent = gui
drone:Play()

local function voidStep(t: number)
	local pos = camera.CFrame.Position
	local best = math.huge
	for _, g in CollectionService:GetTagged("VoidWindow") do
		if g:IsA("BasePart") then
			best = math.min(best, (g.Position - pos).Magnitude)
		end
	end
	local near = math.clamp(1 - best / 26, 0, 1)
	-- дыхание: вдох-выдох неровный
	local breath = 0.6 + 0.4 * math.sin(t * 1.3) * math.sin(t * 0.37 + 1)
	voidSound.Volume = near * 0.9 * breath
	voidSound.PlaybackSpeed = 0.08 + 0.02 * math.sin(t * 0.9)
	drone.Volume = if inRun() then 0.12 + (1 - (workspace:GetAttribute("Light") or 1)) * 0.25 else 0.06
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
			local y = math.random()
			Ui.frame(glitch, {
				BackgroundColor3 = Color3.fromHSV(math.random(), 0.8, math.random() * 0.8 + 0.2),
				BackgroundTransparency = 0.2 + math.random() * 0.5,
				Size = UDim2.new(1, 0, 0, math.random(4, 40)),
				Position = UDim2.new(math.random() * 0.2 - 0.1, 0, y, 0),
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
-- смерть, наблюдение, возврат в лобби

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
		if q ~= player and q:GetAttribute("Alive") and not q:GetAttribute("Finished") and q.Character then
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

local function onDead(msg)
	app.dead = true
	hiddenEye = nil
	leaveBtn.Visible = false
	hud.Visible = false
	deathTitle.Text = T("Died")
	deathCause.Text = T("cause_" .. (msg.cause or "unknown")) .. "\n" .. T("DiedAt", Rules.plate(msg.door or 0))
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
-- финал: край пустоты, Слепой за спиной, шаг в темноту, «Продолжение следует»

local endBox = Ui.frame(gui, { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 70 })
local endText = Ui.label(endBox, "", { Font = Ui.TITLE, TextSize = 40, TextColor3 = Ui.C.text, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0.4, 0), TextTransparency = 1, ZIndex = 71 })
local endBtn = Ui.button(endBox, "", function()
	task.spawn(request, "Lobby")
end, { Size = UDim2.fromOffset(220, 48), Position = UDim2.new(0.5, -110, 0.4, 90), Visible = false, ZIndex = 71, BackgroundColor3 = Ui.C.line })

local function playEnding(edge: CFrame?)
	app.ending = true
	hud.Visible = false
	leaveBtn.Visible = false
	if not edge then
		edge = camera.CFrame
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local base = edge * CFrame.new(0, 4.6, 2.4)
	-- местная копия Слепого для сцены
	local monster
	local src = CollectionService:GetTagged("Blind")[1]
	if src then
		local ok, c = pcall(function()
			return src:Clone()
		end)
		if ok and c then
			for _, d in c:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
				end
			end
			c.Parent = workspace
			monster = c
		end
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local cf
		if t < 2 then
			-- смотрим в пустоту, медленно, с дрожью
			cf = base * CFrame.Angles(math.sin(t * 7) * 0.004, 0, 0)
		elseif t < 3.6 then
			-- оборачиваемся: он бежит по тоннелю
			local a = math.clamp((t - 2) / 0.7, 0, 1)
			cf = base * CFrame.Angles(0, math.pi * a, 0)
			if monster then
				local k = math.clamp((t - 2) / 1.6, 0, 1)
				local mp = edge * CFrame.new(0, 0, 24 - 14 * k) * CFrame.Angles(0, 0, 0)
				monster:PivotTo(mp)
			end
		elseif t < 4.4 then
			local a = math.clamp((t - 3.6) / 0.5, 0, 1)
			cf = base * CFrame.Angles(0, math.pi * (1 - a), 0)
		else
			-- шаг вперёд и падение
			local k = t - 4.4
			cf = base * CFrame.new(0, -k * k * 9, -k * 6) * CFrame.Angles(-math.min(1.2, k * 0.8), 0, 0)
			black.BackgroundTransparency = math.clamp(1 - k / 1.4, 0, 1)
		end
		camera.CFrame = cf
		if t > 6 then
			conn:Disconnect()
			if monster then
				monster:Destroy()
			end
			endBox.Visible = true
			endText.Text = T("ToBeContinued")
			TweenService:Create(endText, TweenInfo.new(2), { TextTransparency = 0 }):Play()
			task.delay(2.5, function()
				endBtn.Text = T("BackToLobby")
				endBtn.Visible = true
			end)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- настройки: язык, тени; в забеге — вернуться в лобби

local panel = Ui.frame(gui, { BackgroundTransparency = 0.08, Size = UDim2.fromOffset(260, 220), Position = UDim2.new(1, -272, 0, 92), Visible = false, ZIndex = 80 })
Ui.corner(panel, 10)
Ui.pad(panel, 10)
local function buildPanel()
	panel:ClearAllChildren()
	Ui.corner(panel, 10)
	Ui.pad(panel, 10)
	Ui.list(panel, 8)
	Ui.label(panel, T("Settings"), { Font = Ui.BOLD, TextSize = 18, ZIndex = 81, LayoutOrder = 1 })
	local row = Ui.frame(panel, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), ZIndex = 81, LayoutOrder = 2 })
	for i, l in { "en", "ru" } do
		Ui.button(row, string.upper(l), function()
			app.lang = l
			task.spawn(request, "Lang", l)
			localizeAll()
			refreshHud()
			buildPanel()
		end, { Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new((i - 1) * 0.5, (i - 1) * 4, 0, 0), ZIndex = 82, BackgroundColor3 = if app.lang == l then Ui.C.line else Ui.C.panel })
	end
	Ui.button(panel, T("Shadows") .. ": " .. (if Lighting.GlobalShadows then T("On") else T("Off")), function()
		Lighting.GlobalShadows = not Lighting.GlobalShadows
		buildPanel()
	end, { ZIndex = 82, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 40) })
	if inRun() then
		Ui.button(panel, T("BackToLobby"), function()
			task.spawn(request, "Lobby")
		end, { ZIndex = 82, LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 40) })
	end
end
Ui.button(gui, "⚙", function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		buildPanel()
	end
end, { Size = UDim2.fromOffset(40, 36), Position = UDim2.new(1, -52, 0, 50), TextSize = 20, BackgroundTransparency = 0.5, ZIndex = 79 })

-- админ-панель (только создателям)
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
		panel.Visible = false
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
	elseif msg.type == "announce" then
		showBanner(T(msg.key, table.unpack(msg.args or {})), 3.5)
	elseif msg.type == "hum" then
		if msg.phase == "warn" then
			showBanner(T("HumWarn"), 2.5)
			app.shake = math.max(app.shake, 0.25)
			flashRed(0.15)
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
		end
	elseif msg.type == "glitch" then
		task.spawn(playGlitch)
	elseif msg.type == "chase" then
		app.shake = 0.15
		flashRed(0.3)
	elseif msg.type == "lift" then
		showBanner(T("Going"), 4)
		TweenService:Create(black, TweenInfo.new(2), { BackgroundTransparency = 0 }):Play()
		task.delay(8, function()
			TweenService:Create(black, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()
		end)
	elseif msg.type == "dead" then
		onDead(msg)
	elseif msg.type == "ending" then
		playEnding(msg.edge)
	elseif msg.type == "results" then
		if not app.ending then
			showBanner(T("Results", Rules.plate(msg.door or 0)), 6)
		end
	end
end)

-- клавиатура: C или Ctrl — тихо, E или пробел — выйти из укрытия
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or app.dead or not inRun() then
		return
	end
	if input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.LeftControl then
		setSneak(not app.sneaking)
	elseif hiddenEye and (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Q) then
		task.spawn(request, "Unhide")
	end
end)

-- ---------------------------------------------------------------------------
-- новый персонаж

local function onCharacter(char: Model)
	app.dead = false
	app.spectating = nil
	app.ending = false
	hiddenEye = nil
	deathBox.Visible = false
	spectBox.Visible = false
	endBox.Visible = false
	endBtn.Visible = false
	leaveBtn.Visible = false
	black.BackgroundTransparency = 1
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
	hud.Visible = inRun()
	setCamera()
	refreshHud()
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end
workspace:GetAttributeChangedSignal("Mode"):Connect(function()
	hud.Visible = inRun() and not app.dead
end)

-- кадр: шкафчик, тряска, фонарик, Смотритель, пустота
local watchT = 0
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	if app.ending then
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
	-- свой фонарик светит из камеры, свет из руки у себя выключен
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
	if watchT > 0.1 then
		watchT = 0
		checkWatchers()
	end
	voidStep(t)
	if app.dead and app.spectating and not app.spectating:GetAttribute("Alive") then
		spectate(1)
	end
end)

localizeAll()
updateFog()
refreshHud()
