--!nonstrict
-- Существа лабиринта:
--   Гул — мигает свет, нарастает гул, потом он проносится по всем комнатам; спасает шкаф
--   Смотритель — пока на него никто не смотрит, быстро идёт к ближайшему игроку
--   Слепой — в зале генераторов; не видит, но слышит шаги, ремонт, ворота и свисток

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local M = require(Shared.Materials)
local Rules = require(Shared.Rules)

local E = {}
local G -- игра (задаётся в init)

local SOUND = {
	rumble = "rbxasset://sounds/swoosh.wav",
	scream = "rbxasset://sounds/uuhhh.mp3",
	hit = "rbxasset://sounds/swordslash.wav",
	ping = "rbxasset://sounds/electronicpingshort.wav",
}
E.SOUND = SOUND

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function sound(parent: Instance, id: string, vol: number, speed: number?, looped: boolean?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol
	s.PlaybackSpeed = speed or 1
	s.Looped = looped == true
	s.RollOffMaxDistance = 160
	s.Parent = parent
	s:Play()
	if not looped then
		Debris:AddItem(s, 8)
	end
	return s
end
E.sound = sound

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- ---------------------------------------------------------------------------
-- Гул

E.humActive = false

local function flicker(lights, seconds: number)
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < seconds do
			for _, bulb in lights do
				local l = bulb.Parent and bulb:FindFirstChildOfClass("PointLight")
				if l and not bulb:GetAttribute("Broken") and not bulb:GetAttribute("Dark") then
					l.Enabled = math.random() < 0.45
				end
			end
			task.wait(0.08 + math.random() * 0.12)
		end
		for _, bulb in lights do
			local l = bulb.Parent and bulb:FindFirstChildOfClass("PointLight")
			if l and not bulb:GetAttribute("Broken") and not bulb:GetAttribute("Dark") then
				l.Enabled = true
			end
		end
	end)
end

function E.hum()
	if E.humActive then
		return
	end
	local rooms = G.loadedRooms()
	if #rooms == 0 then
		return
	end
	E.humActive = true
	local lights = {}
	for _, info in rooms do
		for _, b in info.lights do
			table.insert(lights, b)
		end
	end
	G.sendAll({ type = "hum", phase = "warn" })
	flicker(lights, 3.6)
	-- путь: от самой старой загруженной комнаты до последней открытой
	local pts = {}
	for _, info in rooms do
		for _, p in info.path do
			table.insert(pts, p)
		end
	end
	local body = Instance.new("Part")
	body.Name = "Hum"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(7, 7, 7)
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.Material = M.Neon
	body.Color = rgb(20, 16, 24)
	body.Transparency = 0.15
	body.CFrame = CFrame.new(pts[1] - (pts[2] - pts[1]).Unit * 40)
	local aura = Instance.new("ParticleEmitter")
	aura.Color = ColorSequence.new(rgb(40, 10, 30))
	aura.Size = NumberSequence.new(5, 0)
	aura.Lifetime = NumberRange.new(0.6, 1)
	aura.Rate = 80
	aura.Speed = NumberRange.new(2, 6)
	aura.Parent = body
	local glow = Instance.new("PointLight")
	glow.Color = rgb(255, 40, 60)
	glow.Range = 30
	glow.Brightness = 2
	glow.Parent = body
	body.Parent = workspace
	local rumble = sound(body, SOUND.rumble, 3, 0.25, true)
	task.wait(3.6)
	G.sendAll({ type = "hum", phase = "rush" })
	local speed = 80
	local pos = body.Position
	for i = 1, #pts do
		local target = pts[i]
		while (target - pos).Magnitude > 1 do
			local dt = RunService.Heartbeat:Wait()
			local step = math.min(speed * dt, (target - pos).Magnitude)
			pos += (target - pos).Unit * step
			body.CFrame = CFrame.new(pos)
			for _, p in G.alivePlayers() do
				local r = G.rootOf(p)
				if r and not G.isHidden(p) then
					local off = r.Position - pos
					if flat(off).Magnitude < 9 and math.abs(off.Y) < 9 then
						G.kill(p, "hum")
					end
				end
			end
		end
	end
	-- часть ламп после него перегорает
	for _, b in lights do
		if b.Parent and math.random() < 0.3 then
			b:SetAttribute("Broken", true)
			local l = b:FindFirstChildOfClass("PointLight")
			if l then
				l.Enabled = false
			end
			b.Material = M.Glass
		end
	end
	rumble:Stop()
	body:Destroy()
	G.sendAll({ type = "hum", phase = "gone" })
	E.humActive = false
end

-- ---------------------------------------------------------------------------
-- Смотритель

local watchers = {} -- id -> { model, root, info, spawn, lastSeen, frozenUntil }
local nextId = 0

local function watcherModel(cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "Watcher"
	local skin = rgb(14, 12, 16)
	local function part(name, size, ocf, color, mat)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf * ocf
		p.Color = color
		p.Material = mat or M.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = true
		p.Parent = m
		return p
	end
	local root = part("Body", Vector3.new(2, 9, 1.4), CFrame.new(0, 4.5, 0), skin)
	part("Head", Vector3.new(1.8, 2.2, 1.8), CFrame.new(0, 10.1, 0), skin)
	part("Mask", Vector3.new(1.4, 1.7, 0.1), CFrame.new(0, 10.1, -0.92), rgb(222, 216, 204))
	for _, x in { -0.35, 0.35 } do
		part("EyeHole", Vector3.new(0.3, 0.45, 0.05), CFrame.new(x, 10.4, -0.98), rgb(0, 0, 0))
	end
	part("Mouth", Vector3.new(0.7, 0.12, 0.05), CFrame.new(0, 9.6, -0.98), rgb(0, 0, 0))
	for _, x in { -1.4, 1.4 } do
		part("Arm", Vector3.new(0.5, 8, 0.5), CFrame.new(x, 4.6, 0) * CFrame.Angles(0, 0, x * 0.03), skin)
	end
	m.PrimaryPart = root
	return m, root
end

function E.spawnWatcher(info)
	nextId += 1
	local id = nextId
	local cf = info.watcherSpawn
	local look = info.center.Position
	local base = CFrame.lookAt(cf.Position, Vector3.new(look.X, cf.Y, look.Z))
	local m, root = watcherModel(base)
	m:SetAttribute("WatcherId", id)
	m.Parent = info.model
	CollectionService:AddTag(m, "Watcher")
	watchers[id] = { model = m, root = root, info = info, spawn = base, lastSeen = nil, frozenUntil = nil, pos = base.Position, cooldown = 0 }
	return id
end

-- клиент сообщает, что видит Смотрителя
function E.seen(p: Player, id: number)
	local w = watchers[id]
	if not w or not G.isAlive(p) then
		return
	end
	local r = G.rootOf(p)
	if r and (r.Position - w.pos).Magnitude < 90 then
		w.lastSeen = os.clock()
	end
end

function E.removeRoom(info)
	for id, w in watchers do
		if w.info == info then
			w.model:Destroy()
			watchers[id] = nil
		end
	end
end

local function stepWatchers(dt: number)
	local now = os.clock()
	for id, w in watchers do
		if not w.model.Parent then
			watchers[id] = nil
			continue
		end
		-- цель: ближайший видимый (не спрятанный) игрок в этой комнате
		local best, bestD = nil, math.huge
		for _, p in G.alivePlayers() do
			local r = G.rootOf(p)
			if r and not G.isHidden(p) and G.inRoom(w.info, r.Position) then
				local dd = (flat(r.Position - w.pos)).Magnitude
				if dd < bestD then
					best, bestD = p, dd
				end
			end
		end
		if best and now > w.cooldown and Rules.watcherMoves(w.lastSeen, now, w.frozenUntil) then
			local r = G.rootOf(best) :: BasePart
			local to = flat(r.Position - w.pos)
			if to.Magnitude > 0.1 then
				local step = math.min(Rules.WATCHER_SPEED * dt, to.Magnitude)
				w.pos += to.Unit * step
			end
			if bestD < 3.6 then
				G.damage(best, Rules.WATCHER_DAMAGE, "watcher")
				sound(w.root, SOUND.scream, 1.2, 1.3)
				G.send(best, { type = "fx", kind = "scare" })
				-- возвращается в свой угол и ждёт
				w.pos = w.spawn.Position
				w.cooldown = now + 3
			end
			local face = Vector3.new(r.Position.X, w.pos.Y, r.Position.Z)
			local cf = if (face - w.pos).Magnitude > 0.1 then CFrame.lookAt(w.pos, face) else CFrame.new(w.pos)
			w.model:PivotTo(cf)
		end
	end
end

-- свисток: все Смотрители рядом замирают
local function freezeWatchers(pos: Vector3)
	for _, w in watchers do
		if (w.pos - pos).Magnitude < 70 then
			w.frozenUntil = os.clock() + Rules.WHISTLE_FREEZE
		end
	end
end

-- ---------------------------------------------------------------------------
-- Слепой

local blind = nil -- { model, hum, root, info, state, target, confusedUntil, path, wp, pathAt }

local function blindModel(cf: CFrame)
	local desc = Instance.new("HumanoidDescription")
	local c = rgb(46, 44, 50)
	desc.HeadColor, desc.TorsoColor = c, c
	desc.LeftArmColor, desc.RightArmColor, desc.LeftLegColor, desc.RightLegColor = c, c, c, c
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		return nil
	end
	model.Name = "Blind"
	for _, d in model:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		elseif d:IsA("Decal") and d.Name == "face" then
			d:Destroy()
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.MaxHealth = math.huge
	hum.Health = math.huge
	pcall(function()
		model:ScaleTo(1.5)
	end)
	-- повязка на глазах и длинные пальцы
	local head = model:FindFirstChild("Head")
	if head then
		local band = Instance.new("Part")
		band.Name = "Blindfold"
		band.Size = Vector3.new(head.Size.X * 1.05, head.Size.Y * 0.28, head.Size.Z * 1.05)
		band.Color = rgb(150, 140, 120)
		band.Material = M.Fabric
		band.CanCollide = false
		band.Massless = true
		band.CFrame = head.CFrame * CFrame.new(0, head.Size.Y * 0.1, 0)
		local wd = Instance.new("WeldConstraint")
		wd.Part0 = head
		wd.Part1 = band
		wd.Parent = band
		band.Parent = model
		local mouth = Instance.new("Part")
		mouth.Name = "Mouth"
		mouth.Size = Vector3.new(head.Size.X * 0.6, head.Size.Y * 0.18, 0.1)
		mouth.Color = rgb(80, 10, 10)
		mouth.CanCollide = false
		mouth.Massless = true
		mouth.CFrame = head.CFrame * CFrame.new(0, -head.Size.Y * 0.25, -head.Size.Z / 2 - 0.02)
		local w2 = Instance.new("WeldConstraint")
		w2.Part0 = head
		w2.Part1 = mouth
		w2.Parent = mouth
		mouth.Parent = model
	end
	model:PivotTo(cf)
	return model, hum
end

function E.startBlind(info)
	E.stopBlind()
	local model, hum = blindModel(info.blindSpawn)
	if not model then
		return
	end
	model.Parent = info.model
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	hum.WalkSpeed = Rules.BLIND_SPEED.wander
	CollectionService:AddTag(model, "Blind")
	blind = { model = model, hum = hum, root = root, info = info, state = "wander", target = nil, confusedUntil = 0, wanderAt = 0, path = nil, pathAt = 0, wp = 1, growlAt = 0 }
end

function E.stopBlind()
	if blind then
		if blind.model then
			blind.model:Destroy()
		end
		blind = nil
	end
end

-- шум в точке: Слепой идёт туда, если услышал
function E.noise(pos: Vector3, radius: number, kind: string?)
	if not blind or not blind.root.Parent then
		return
	end
	if (blind.root.Position - pos).Magnitude > radius then
		return
	end
	if kind == "whistle" then
		blind.state = "lure"
		blind.target = pos
		blind.confusedUntil = 0
		return
	end
	if blind.state == "confused" and os.clock() < blind.confusedUntil then
		return
	end
	blind.state = "hunt"
	blind.target = pos
end

local function blindGo(goal: Vector3)
	local b = blind
	local now = os.clock()
	if not b.path or now - b.pathAt > 1.2 or (b.goal and (b.goal - goal).Magnitude > 6) then
		b.pathAt = now
		b.goal = goal
		local path = PathfindingService:CreatePath({ AgentRadius = 2.5, AgentHeight = 8, AgentCanJump = false })
		local ok = pcall(function()
			path:ComputeAsync(b.root.Position, goal)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			b.path = path:GetWaypoints()
			b.wp = 2
		else
			b.path = nil
			b.hum:MoveTo(goal)
			return
		end
	end
	local w = b.path and b.path[b.wp]
	if w then
		if (flat(w.Position - b.root.Position)).Magnitude < 3 then
			b.wp += 1
			w = b.path[b.wp] or w
		end
		b.hum:MoveTo(w.Position)
	end
end

local function stepBlind()
	local b = blind
	if not b or not b.root.Parent then
		return
	end
	local now = os.clock()
	-- слушает шаги игроков в зале
	for _, p in G.alivePlayers() do
		local r = G.rootOf(p)
		if r and not G.isHidden(p) and G.inRoom(b.info, r.Position) then
			local v = r.AssemblyLinearVelocity
			local radius = Rules.noise(Vector3.new(v.X, 0, v.Z).Magnitude, G.isSneaking(p))
			if radius > 0 and (r.Position - b.root.Position).Magnitude < radius then
				E.noise(r.Position, radius, "step")
			end
			-- поймал
			if (flat(r.Position - b.root.Position)).Magnitude < 5 and math.abs(r.Position.Y - b.root.Position.Y) < 8 then
				G.kill(p, "blind")
				sound(b.root, SOUND.scream, 1.5, 0.6)
				b.state = "wander"
				b.target = nil
			end
		end
	end
	if b.state == "hunt" and b.target then
		b.hum.WalkSpeed = Rules.BLIND_SPEED.hunt
		blindGo(b.target)
		if (flat(b.target - b.root.Position)).Magnitude < 4 then
			-- пришёл на звук и никого: прислушивается
			b.state = "confused"
			b.confusedUntil = now + 2.5
		end
		if now > b.growlAt then
			b.growlAt = now + 3
			sound(b.root, SOUND.scream, 0.7, 0.35)
		end
	elseif b.state == "lure" and b.target then
		b.hum.WalkSpeed = Rules.BLIND_SPEED.hunt
		blindGo(b.target)
		if (flat(b.target - b.root.Position)).Magnitude < 4 then
			b.state = "confused"
			b.confusedUntil = now + Rules.BLIND_CONFUSED
		end
	elseif b.state == "confused" then
		b.hum:MoveTo(b.root.Position)
		if now > b.confusedUntil then
			b.state = "wander"
		end
	else
		b.hum.WalkSpeed = Rules.BLIND_SPEED.wander
		if not b.target or now > b.wanderAt or (flat(b.target - b.root.Position)).Magnitude < 4 then
			b.wanderAt = now + 8
			local list = b.info.wander
			b.target = list[math.random(1, #list)]
		end
		blindGo(b.target)
	end
end

-- ---------------------------------------------------------------------------
-- свисток

function E.whistle(p: Player)
	local r = G.rootOf(p)
	if not r then
		return
	end
	sound(r, SOUND.ping, 2, 2.2)
	freezeWatchers(r.Position)
	-- Слепой бежит на свисток и стоит там, прислушиваясь: самому надо отойти тихо
	E.noise(r.Position, Rules.NOISE.whistle, "whistle")
end

function E.clear()
	for id, w in watchers do
		w.model:Destroy()
		watchers[id] = nil
	end
	E.stopBlind()
	for _, h in workspace:GetChildren() do
		if h.Name == "Hum" then
			h:Destroy()
		end
	end
end

function E.init(game_)
	G = game_
	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(stepWatchers, dt)
		if not ok then
			warn("[Labyrinth] watcher: " .. tostring(err))
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			local ok, err = pcall(stepBlind)
			if not ok then
				warn("[Labyrinth] blind: " .. tostring(err))
			end
		end
	end)
	local _ = TweenService
end

return E
