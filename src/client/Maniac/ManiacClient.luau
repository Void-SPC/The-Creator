--!nonstrict
-- Режим «Маньяк» на клиенте: лобби, экран раунда, кнопки способностей маньяка,
-- тёмная атмосфера с туманом и мигающим светом, сердцебиение рядом с маньяком,
-- эффекты испуга и ослепления, полёт призрака после смерти

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local TextChatService = game:GetService("TextChatService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local Rules = require(Shared.ManiacRules)
local Remotes = require(Shared.Roblox.Remotes)

local Ui = require(script.Parent.Parent.Castle.Ui)
local CameraController = require(script.Parent.Parent.Common.CameraController)
local FreeCamera = require(script.Parent.Parent.Common.FreeCamera)

local player = Players.LocalPlayer

local Client = {}
Client.__index = Client

local SND = {
	beat = "rbxasset://sounds/collide.wav",
	wind = "rbxasset://sounds/swoosh.wav",
	scream = "rbxasset://sounds/uuhhh.mp3",
	slash = "rbxasset://sounds/swordslash.wav",
	sting = "rbxasset://sounds/electronicpingshort.wav",
}
local SLASH_ANIM = "rbxassetid://522635514"

local function request(...)
	local ok, res = pcall(function(...)
		return Remotes.fn("ManiacRequest"):InvokeServer(...)
	end, ...)
	return if ok then res else nil
end

function Client.new(app)
	local self = setmetatable({}, Client)
	self.app = app
	self.conns = {}
	self.state = { phase = "lobby" }
	self.lastUse = {}
	local gui = Instance.new("ScreenGui")
	gui.Name = "ManiacHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 12
	gui.Parent = app.playerGui
	self.gui = gui
	self.camera = CameraController.new({ camera = { mode = "first", sensitivity = app.settings.sensitivity, fov = app.settings.fov, bob = app.settings.bob } })
	self:buildHud()
	self:atmosphere(true)
	self:buildSounds()
	self:watch()
	return self
end

function Client:T(key, ...)
	return self.app.T(key, ...)
end

-- ---------------------------------------------------------------------------
-- экран

function Client:buildHud()
	local gui = self.gui
	local inset = game:GetService("GuiService").TopbarInset
	local top = math.max(inset.Height, 36) + 8
	self.title = Ui.label(gui, "", { Font = Ui.TITLE, TextSize = 26, TextColor3 = Color3.fromRGB(230, 60, 50), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -260, 0, 60), Position = UDim2.new(0, 130, 0, top - 4), TextStrokeTransparency = 0.5 })
	self.info = Ui.label(gui, "", { TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(200, 200), Position = UDim2.fromOffset(14, top), TextYAlignment = Enum.TextYAlignment.Top, TextStrokeTransparency = 0.6 })
	local leave = Ui.button(gui, self:T("Leave"), function()
		request("Leave")
		self.app:leaveManiac()
	end, { Size = UDim2.fromOffset(110, 34), Position = UDim2.new(1, -122, 0, top), TextSize = 14, BackgroundTransparency = 0.2 })
	local _ = leave
	self.banner = Ui.label(gui, "", { Font = Ui.TITLE, TextSize = 36, TextColor3 = Color3.fromRGB(235, 70, 60), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -40, 0, 100), Position = UDim2.new(0, 20, 0.28, 0), Visible = false, TextStrokeTransparency = 0.3 })
	-- кнопки способностей маньяка (справа, над прыжком)
	self.abilityBox = Ui.frame(gui, { BackgroundTransparency = 1, Size = UDim2.fromOffset(240, 160), Position = UDim2.new(1, -252, 1, -330), Visible = false })
	self.abilityButtons = {}
	for i, name in Rules.ABILITY_ORDER do
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		local big = name == "attack"
		local b = Ui.button(self.abilityBox, self:T("ab_" .. name), function()
			self:useAbility(name)
		end, {
			Size = UDim2.fromOffset(74, 64),
			Position = UDim2.fromOffset(col * 80, row * 72),
			TextSize = 14,
			Font = Ui.FONT_BOLD,
			BackgroundColor3 = if big then Color3.fromRGB(120, 20, 20) else Color3.fromRGB(50, 20, 24),
			TextColor3 = Color3.fromRGB(255, 220, 210),
		})
		self.abilityButtons[name] = b
	end
	-- затемнения для ослепления и ран
	self.blackout = Ui.frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 50 })
	self.redout = Ui.frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(150, 0, 0), BackgroundTransparency = 1, ZIndex = 49 })
	self.blackout.Active = false
	self.redout.Active = false
end

function Client:refresh()
	local st = self.state
	local now = workspace:GetServerTimeNow()
	local left = math.max(0, math.floor((st.endsAt or now) - now))
	local lines = {}
	if st.phase == "lobby" then
		self.title.Text = self:T("Lobby")
		table.insert(lines, self:T("NeedPlayersFormat", st.count or 1, Rules.MIN_PLAYERS))
	elseif st.phase == "countdown" then
		self.title.Text = self:T("Lobby")
		table.insert(lines, self:T("LobbyFormat", st.count or 1, left))
	elseif st.phase == "playing" then
		local role = if st.ghost then self:T("Ghost") elseif st.role == "maniac" then self:T("Maniac") else self:T("Survivor")
		self.title.Text = role .. "   " .. self:T("TimeLeftFormat", left // 60, left % 60)
		table.insert(lines, self:T("GeneratorsFormat", st.gensDone or 0, st.gensTotal or 0))
		for _, s in st.survivors or {} do
			table.insert(lines, s.name .. "   " .. self:T("st_" .. s.st))
		end
	elseif st.phase == "results" then
		self.title.Text = if st.winner == "maniac" then self:T("ManiacWins") else self:T("SurvivorsWin")
	end
	self.info.Text = table.concat(lines, "\n")
	local isManiac = st.phase == "playing" and st.role == "maniac" and not st.ghost
	self.abilityBox.Visible = isManiac
	if isManiac then
		local t = os.clock()
		for name, b in self.abilityButtons do
			local ok, rest = Rules.ready(name, self.lastUse[name], t)
			b.Text = if ok then self:T("ab_" .. name) else string.format("%s\n%d", self:T("ab_" .. name), math.ceil(rest))
			b.BackgroundTransparency = if ok then 0 else 0.5
		end
	end
end

function Client:showBanner(text: string, seconds: number?)
	self.banner.Text = text
	self.banner.Visible = true
	local token = {}
	self.bannerToken = token
	task.delay(seconds or 4, function()
		if self.bannerToken == token then
			self.banner.Visible = false
		end
	end)
end

-- ---------------------------------------------------------------------------
-- атмосфера: ночь, туман, бледные цвета, мигающий свет

function Client:atmosphere(on: boolean)
	if on then
		self.savedLighting = {
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			Brightness = Lighting.Brightness,
			ExposureCompensation = Lighting.ExposureCompensation,
		}
		local fog = Instance.new("Atmosphere")
		fog.Name = "ManiacFog"
		fog.Density = 0.5
		fog.Haze = 2.4
		fog.Color = Color3.fromRGB(60, 44, 46)
		fog.Decay = Color3.fromRGB(30, 20, 22)
		fog.Parent = Lighting
		self.fog = fog
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "ManiacTint"
		cc.Saturation = -0.35
		cc.Contrast = 0.18
		cc.TintColor = Color3.fromRGB(255, 222, 216)
		cc.Parent = Lighting
		self.tint = cc
		-- погода замка (дождь, снег) в этом режиме не нужна
		for _, a in Lighting:GetChildren() do
			if a:IsA("Atmosphere") and a ~= fog then
				a:SetAttribute("ManiacSaved", a.Density)
				a.Density = 0
			end
		end
	else
		if self.savedLighting then
			for k, v in self.savedLighting do
				(Lighting :: any)[k] = v
			end
		end
		if self.fog then
			self.fog:Destroy()
		end
		if self.tint then
			self.tint:Destroy()
		end
		for _, a in Lighting:GetChildren() do
			if a:IsA("Atmosphere") and a:GetAttribute("ManiacSaved") then
				a.Density = a:GetAttribute("ManiacSaved")
				a:SetAttribute("ManiacSaved", nil)
			end
		end
	end
end

function Client:buildSounds()
	local cam = workspace.CurrentCamera
	local wind = Instance.new("Sound")
	wind.SoundId = SND.wind
	wind.Looped = true
	wind.PlaybackSpeed = 0.28
	wind.Volume = 0.35 * self.app.settings.volume
	wind.Parent = cam
	wind:Play()
	self.wind = wind
	self.nextBeat = 0
end

function Client:sound(id: string, vol: number, speed: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol * self.app.settings.volume
	s.PlaybackSpeed = speed or 1
	s.Parent = workspace.CurrentCamera
	s:Play()
	Debris:AddItem(s, 5)
end

-- ---------------------------------------------------------------------------
-- способности и эффекты

function Client:playSlash()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if animator then
		local a = Instance.new("Animation")
		a.AnimationId = SLASH_ANIM
		local ok, track = pcall(function()
			return animator:LoadAnimation(a)
		end)
		if ok and track then
			track.Priority = Enum.AnimationPriority.Action
			track:Play(0.05, 1, 1.4)
		end
	end
end

function Client:useAbility(name: string)
	local ok = Rules.ready(name, self.lastUse[name], os.clock())
	if not ok then
		return
	end
	self.lastUse[name] = os.clock()
	if name == "attack" then
		self:playSlash()
		self:sound(SND.slash, 0.6, 0.8)
	end
	task.spawn(request, "Ability", name)
end

function Client:shake(seconds: number, power: number)
	local t0 = os.clock()
	pcall(function()
		RunService:UnbindFromRenderStep("ManiacShake")
	end)
	RunService:BindToRenderStep("ManiacShake", Enum.RenderPriority.Camera.Value + 5, function()
		local e = os.clock() - t0
		if e > seconds then
			RunService:UnbindFromRenderStep("ManiacShake")
			return
		end
		local a = (1 - e / seconds) * power
		local cam = workspace.CurrentCamera
		cam.CFrame = cam.CFrame * CFrame.new(math.random() * a - a / 2, math.random() * a - a / 2, 0) * CFrame.Angles(0, 0, (math.random() - 0.5) * a * 0.05)
	end)
end

function Client:fade(frame: Frame, from: number, seconds: number)
	frame.BackgroundTransparency = from
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < seconds and self.gui.Parent do
			local a = (os.clock() - t0) / seconds
			frame.BackgroundTransparency = from + (1 - from) * a
			task.wait()
		end
		frame.BackgroundTransparency = 1
	end)
end

function Client:onMessage(msg)
	if type(msg) ~= "table" then
		return
	end
	if msg.type == "state" then
		local wasGhost = self.state.ghost
		self.state = msg
		if msg.phase ~= "playing" and self.ghostCam then
			self:stopGhost()
		end
		if msg.ghost and not wasGhost and msg.phase == "playing" then
			self:startGhost()
		end
		self:refresh()
	elseif msg.type == "announce" then
		self:showBanner(self:T(msg.key, table.unpack(msg.args or {})))
		self:sound(SND.sting, 0.6, 0.5)
	elseif msg.type == "intro" then
		if msg.role == "maniac" then
			self:showBanner(self:T("YouAreManiac"), 5)
			Ui.toast(self.gui, self:T("ManiacGoal"), Color3.fromRGB(90, 20, 20), 7)
		else
			self:showBanner(self:T("YouAreSurvivor"), 5)
			Ui.toast(self.gui, self:T("SurvivorGoal"), Color3.fromRGB(40, 30, 30), 8)
		end
	elseif msg.type == "fx" then
		if msg.kind == "hurt" then
			self:fade(self.redout, 0.35, 1.2)
			self:shake(0.4, 0.5)
		elseif msg.kind == "scare" then
			self:fade(self.redout, 0.5, 2.5)
			self:shake(2.5, 0.6)
			self:sound(SND.scream, 1, 0.45)
		elseif msg.kind == "blind" then
			self:fade(self.blackout, 0, msg.duration or 3.5)
		end
	elseif msg.type == "sense" then
		for _, id in msg.ids or {} do
			local q = Players:GetPlayerByUserId(id)
			if q and q.Character then
				local h = Instance.new("Highlight")
				h.FillColor = Color3.fromRGB(255, 40, 40)
				h.FillTransparency = 0.6
				h.OutlineColor = Color3.fromRGB(255, 120, 100)
				h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				h.Parent = q.Character
				Debris:AddItem(h, msg.duration or 5)
			end
		end
	elseif msg.type == "anim" then
		self:playSlash()
		task.delay(0.4, function()
			self:playSlash()
		end)
	elseif msg.type == "ghost" then
		self:startGhost()
	end
end

-- призрак: свободная камера над картой, своё тело не видно
function Client:startGhost()
	if self.ghostCam then
		return
	end
	if self.camera then
		self.camera:destroy()
		self.camera = nil
	end
	local map = workspace:FindFirstChild("ManiacMap")
	local focus = if map then map:GetPivot().Position else Vector3.new(2600, 10, 0)
	self.ghostCam = FreeCamera.new(focus + Vector3.new(0, 20, -40))
	Ui.toast(self.gui, self:T("GhostTip"), Color3.fromRGB(40, 40, 60), 6)
end

function Client:stopGhost()
	if self.ghostCam then
		self.ghostCam:destroy()
		self.ghostCam = nil
	end
	if not self.camera then
		self.camera = CameraController.new({ camera = { mode = "first", sensitivity = self.app.settings.sensitivity, fov = self.app.settings.fov, bob = self.app.settings.bob } })
	end
end

-- ---------------------------------------------------------------------------

function Client:watch()
	table.insert(self.conns, Remotes.event("Maniac").OnClientEvent:Connect(function(msg)
		self:onMessage(msg)
	end))
	-- кнопки у предметов: подписи на языке игрока, лишние для своей роли скрыты
	local function setup(pr)
		if pr:IsA("ProximityPrompt") then
			local kind = pr:GetAttribute("Kind")
			if kind then
				pr.ActionText = self:T("p_" .. kind)
			end
		end
	end
	for _, d in workspace:GetDescendants() do
		setup(d)
	end
	table.insert(self.conns, workspace.DescendantAdded:Connect(setup))
	local lights = {}
	local function addLight(d)
		if d:IsA("PointLight") and d.Parent and d.Parent:GetAttribute("Flicker") then
			table.insert(lights, { l = d, base = d.Brightness })
		end
	end
	local map = workspace:FindFirstChild("ManiacMap")
	if map then
		for _, d in map:GetDescendants() do
			addLight(d)
		end
		table.insert(self.conns, map.DescendantAdded:Connect(addLight))
	end
	local acc, roleAcc = 0, 0
	table.insert(self.conns, RunService.RenderStepped:Connect(function(dt)
		-- ночь и тусклый свет поверх смены суток замка
		Lighting.ClockTime = 0.5
		Lighting.Brightness = 0.5
		Lighting.Ambient = Color3.fromRGB(26, 20, 20)
		Lighting.OutdoorAmbient = Color3.fromRGB(24, 20, 22)
		Lighting.ExposureCompensation = -0.2
		acc += dt
		if acc > 0.09 then
			acc = 0
			for _, e in lights do
				if e.l.Parent then
					e.l.Brightness = e.base * (if math.random() < 0.06 then 0.1 else (0.75 + math.random() * 0.35))
				end
			end
		end
		roleAcc += dt
		if roleAcc > 0.5 then
			roleAcc = 0
			self:refresh()
			self:rolePrompts()
		end
		self:heartbeat()
	end))
	-- спрятался в шкафу
	table.insert(self.conns, player:GetAttributeChangedSignal("HiddenEye"):Connect(function()
		local eye = player:GetAttribute("HiddenEye")
		if not self.camera then
			return
		end
		if typeof(eye) == "CFrame" then
			self.camera:enterInside(eye)
		else
			self.camera:restore()
		end
	end))
	pcall(function()
		local tc = TextChatService:FindFirstChild("TextChannels")
		local room = tc and tc:WaitForChild("ManiacRoom", 5)
		if room then
			TextChatService.ChatInputBarConfiguration.TargetTextChannel = room
		end
	end)
	request("Status")
end

-- маньяк не видит кнопок «чинить» и «поднять», выжившие — «добить»
function Client:rolePrompts()
	local isManiac = self.state.role == "maniac"
	local map = workspace:FindFirstChild("ManiacMap")
	local function apply(pr)
		local kind = pr:GetAttribute("Kind")
		if kind == "repair" or kind == "revive" then
			pr.Enabled = not isManiac and not self.state.ghost
		elseif kind == "execute" then
			pr.Enabled = isManiac
		end
	end
	if map then
		for _, d in map:GetDescendants() do
			if d:IsA("ProximityPrompt") then
				apply(d)
			end
		end
	end
	for _, q in Players:GetPlayers() do
		local r = q.Character and q.Character:FindFirstChild("HumanoidRootPart")
		if r then
			for _, pr in r:GetChildren() do
				if pr:IsA("ProximityPrompt") then
					apply(pr)
				end
			end
		end
	end
end

-- сердцебиение выжившего: чем ближе маньяк, тем чаще и громче
function Client:heartbeat()
	if self.state.phase ~= "playing" or self.state.role ~= "survivor" or self.state.ghost then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local best = math.huge
	for _, q in Players:GetPlayers() do
		if q ~= player and q.Character and q.Character:FindFirstChild("ManiacCostume") then
			local r = q.Character:FindFirstChild("HumanoidRootPart")
			if r then
				best = math.min(best, (r.Position - root.Position).Magnitude)
			end
		end
	end
	if best < 45 and os.clock() >= self.nextBeat then
		local k = 1 - best / 45
		self.nextBeat = os.clock() + (1.3 - k * 0.9)
		self:sound(SND.beat, 0.25 + k * 0.6, 0.45)
		task.delay(0.18, function()
			self:sound(SND.beat, 0.2 + k * 0.5, 0.4)
		end)
	end
end

function Client:destroy()
	for _, c in self.conns do
		c:Disconnect()
	end
	pcall(function()
		RunService:UnbindFromRenderStep("ManiacShake")
	end)
	if self.camera then
		self.camera:destroy()
	end
	if self.ghostCam then
		self.ghostCam:destroy()
	end
	self:atmosphere(false)
	if self.wind then
		self.wind:Destroy()
	end
	self.gui:Destroy()
	pcall(function()
		TextChatService.ChatInputBarConfiguration.TargetTextChannel = nil
	end)
end

return Client
