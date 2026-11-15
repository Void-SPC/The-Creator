--!nonstrict
-- Существа лабиринта:
--   Гул — мигает свет, нарастает гул, вихрь с пастью проносится по комнатам; спасает
--   шкафчик или ниша
--   Смотритель — пока на него никто не смотрит, быстро идёт к ближайшему игроку
--   Слепой — в зале генераторов слышит шаги; после ворот гонится по техническому сектору

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local M = require(Shared.Materials)
local Rules = require(Shared.Rules)

local E = {}
local G

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

local function part(m, name, size, cf, color, mat, extra)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in extra or {} do
		(p :: any)[k] = v
	end
	p.Parent = m
	return p
end

local function ball(m, name, d, cf, color, mat, extra)
	local p = part(m, name, Vector3.new(d, d, d), cf, color, mat, extra)
	p.Shape = Enum.PartType.Ball
	return p
end

-- сустав-стержень между точками
local function limb(m, name, a: Vector3, b: Vector3, thick: number, color, mat)
	local len = (b - a).Magnitude
	return part(m, name, Vector3.new(thick, thick, len), CFrame.lookAt((a + b) / 2, b), color, mat)
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
				if l and not bulb:GetAttribute("Broken") and l:GetAttribute("Base") and l.Brightness > 0 then
					l.Enabled = math.random() < 0.45
				end
			end
			task.wait(0.08 + math.random() * 0.12)
		end
		for _, bulb in lights do
			local l = bulb.Parent and bulb:FindFirstChildOfClass("PointLight")
			if l and not bulb:GetAttribute("Broken") and l.Brightness > 0 then
				l.Enabled = true
			end
		end
	end)
end

-- вихрь: тёмное ядро, рваная оболочка, кольцо зубов вокруг пасти, осколки по орбите
local function humModel(at: Vector3)
	local m = Instance.new("Model")
	m.Name = "Hum"
	local core = ball(m, "Core", 5, CFrame.new(at), rgb(14, 8, 16), M.SmoothPlastic)
	ball(m, "Shell", 7.5, CFrame.new(at), rgb(40, 10, 30), M.Glass, { Transparency = 0.55 })
	ball(m, "Maw", 2.6, CFrame.new(at) * CFrame.new(0, 0, -2.2), rgb(150, 10, 20), M.Neon)
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		part(m, "Tooth", Vector3.new(0.35, 0.9, 0.35), CFrame.new(at) * CFrame.new(math.cos(a) * 1.6, math.sin(a) * 1.6, -2.6) * CFrame.Angles(0, 0, a + math.pi / 2), rgb(220, 210, 190), M.SmoothPlastic)
	end
	for k = 0, 9 do
		part(m, "Shard", Vector3.new(0.6, 1.6, 0.3), CFrame.new(at) * CFrame.Angles(k, k * 2, 0) * CFrame.new(0, 0, 5), rgb(30, 18, 26), M.Slate)
	end
	local aura = Instance.new("ParticleEmitter")
	aura.Color = ColorSequence.new(rgb(40, 8, 24))
	aura.Size = NumberSequence.new(4, 0)
	aura.Lifetime = NumberRange.new(0.5, 1)
	aura.Rate = 90
	aura.Speed = NumberRange.new(3, 8)
	aura.Parent = core
	local glow = Instance.new("PointLight")
	glow.Color = rgb(255, 40, 60)
	glow.Range = 32
	glow.Brightness = 2.2
	glow.Parent = core
	m.PrimaryPart = core
	return m, core
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
	flicker(lights, 3.8)
	local pts = {}
	for _, info in rooms do
		for _, p in info.path do
			table.insert(pts, p)
		end
	end
	local startPos = pts[1] - (pts[2] - pts[1]).Unit * 40
	local m, core = humModel(startPos)
	m.Parent = workspace
	local rumble = sound(core, SOUND.rumble, 3, 0.22, true)
	task.wait(3.8)
	G.sendAll({ type = "hum", phase = "rush" })
	local speed = 85
	local pos = startPos
	local spin = 0
	for i = 1, #pts do
		local target = pts[i]
		while (target - pos).Magnitude > 1 do
			local dt = RunService.Heartbeat:Wait()
			local step = math.min(speed * dt, (target - pos).Magnitude)
			local dir = (target - pos).Unit
			pos += dir * step
			spin += dt * 9
			m:PivotTo(CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, 0, spin))
			for _, p in G.alivePlayers() do
				local r = G.rootOf(p)
				if r and not G.isHidden(p) then
					local off = r.Position - pos
					if flat(off).Magnitude < 9 and math.abs(off.Y) < 10 then
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
	m:Destroy()
	G.sendAll({ type = "hum", phase = "gone" })
	E.humActive = false
end

-- ---------------------------------------------------------------------------
-- Смотритель: высокая тощая фигура, длинные руки с суставами и пальцами, маска

local watchers = {}
local nextId = 0

local function watcherModel(base: CFrame)
	local m = Instance.new("Model")
	m.Name = "Watcher"
	local skin = rgb(16, 14, 18)
	local pale = rgb(214, 208, 196)
	local function pt(x, y, z)
		return (base * CFrame.new(x, y, z)).Position
	end
	-- ноги
	for _, s in { -1, 1 } do
		local hip, knee, foot = pt(s * 0.5, 5.2, 0), pt(s * 0.6, 2.7, -0.3), pt(s * 0.65, 0.2, 0)
		limb(m, "Thigh", hip, knee, 0.42, skin)
		limb(m, "Shin", knee, foot, 0.34, skin)
		ball(m, "Knee", 0.5, CFrame.new(knee), skin)
		part(m, "Foot", Vector3.new(0.5, 0.25, 1.3), CFrame.new(foot) * base.Rotation * CFrame.new(0, 0, -0.35), skin)
	end
	-- туловище сужается кверху, рёбра проступают
	local body = part(m, "Body", Vector3.new(1.4, 2.2, 0.8), base * CFrame.new(0, 6.3, 0), skin, M.SmoothPlastic, { CanQuery = true })
	part(m, "Chest", Vector3.new(1.8, 2, 0.9), base * CFrame.new(0, 8.3, 0), skin, M.SmoothPlastic, { CanQuery = true })
	for k = 0, 2 do
		part(m, "Rib", Vector3.new(1.6, 0.12, 0.1), base * CFrame.new(0, 7.8 + k * 0.45, -0.47), rgb(40, 36, 42))
	end
	limb(m, "Neck", pt(0, 9.3, 0), pt(0, 10.6, -0.2), 0.35, skin)
	-- голова с маской: прорези глаз и рта, трещина
	local head = ball(m, "Head", 1.9, base * CFrame.new(0, 11.3, -0.2), skin, M.SmoothPlastic, { CanQuery = true })
	local mask = base * CFrame.new(0, 11.3, -1.05)
	part(m, "Mask", Vector3.new(1.5, 1.9, 0.18), mask, pale)
	for _, x in { -0.35, 0.35 } do
		part(m, "EyeHole", Vector3.new(0.32, 0.5, 0.06), mask * CFrame.new(x, 0.3, -0.1), rgb(0, 0, 0))
	end
	part(m, "Mouth", Vector3.new(0.8, 0.14, 0.06), mask * CFrame.new(0, -0.5, -0.1), rgb(0, 0, 0))
	part(m, "Crack", Vector3.new(0.06, 0.9, 0.04), mask * CFrame.new(0.15, 0.4, -0.1) * CFrame.Angles(0, 0, 0.3), rgb(60, 54, 50))
	-- руки ниже колен с суставами и пальцами
	for _, s in { -1, 1 } do
		local sh, el, wr = pt(s * 1.1, 9, 0), pt(s * 1.5, 6, -0.2), pt(s * 1.45, 2.6, -0.5)
		limb(m, "UpperArm", sh, el, 0.32, skin)
		limb(m, "Forearm", el, wr, 0.28, skin)
		ball(m, "Elbow", 0.4, CFrame.new(el), skin)
		ball(m, "Shoulder", 0.55, CFrame.new(sh), skin)
		for f = -1, 1 do
			limb(m, "Finger", wr, wr + (base.Rotation * Vector3.new(f * 0.25, -1.4, -0.2)), 0.1, skin)
		end
	end
	-- точка опоры — на полу между ступнями
	m.WorldPivot = base
	local _ = body
	return m, head
end

function E.spawnWatcher(info)
	nextId += 1
	local id = nextId
	local cf = info.watcherSpawn
	local look = info.center.Position
	local base = CFrame.lookAt(cf.Position, Vector3.new(look.X, cf.Y, look.Z))
	local m = watcherModel(base)
	m:SetAttribute("WatcherId", id)
	m.Parent = info.model
	CollectionService:AddTag(m, "Watcher")
	watchers[id] = { model = m, info = info, spawn = base, lastSeen = nil, frozenUntil = nil, pos = base.Position, cooldown = 0 }
	return id
end

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
		local best, bestD = nil, math.huge
		for _, p in G.alivePlayers() do
			local r = G.rootOf(p)
			if r and not G.isHidden(p) and G.inRoom(w.info, r.Position) then
				local dd = flat(r.Position - w.pos).Magnitude
				if dd < bestD then
					best, bestD = p, dd
				end
			end
		end
		if best and now > w.cooldown and Rules.watcherMoves(w.lastSeen, now, w.frozenUntil) then
			local r = G.rootOf(best) :: BasePart
			local to = flat(r.Position - w.pos)
			if to.Magnitude > 0.1 then
				w.pos += to.Unit * math.min(Rules.WATCHER_SPEED * dt, to.Magnitude)
			end
			if bestD < 3.6 then
				G.damage(best, Rules.WATCHER_DAMAGE, "watcher")
				sound(w.model:FindFirstChild("Head") or w.model, SOUND.scream, 1.2, 1.3)
				G.send(best, { type = "fx", kind = "scare" })
				w.pos = w.spawn.Position
				w.cooldown = now + 3
			end
			local face = Vector3.new(r.Position.X, w.pos.Y, r.Position.Z)
			local cf = if (face - w.pos).Magnitude > 0.1 then CFrame.lookAt(w.pos, face) else CFrame.new(w.pos)
			w.model:PivotTo(cf)
		end
	end
end

local function freezeWatchers(pos: Vector3)
	for _, w in watchers do
		if (w.pos - pos).Magnitude < 70 then
			w.frozenUntil = os.clock() + Rules.WHISTLE_FREEZE
		end
	end
end

-- ---------------------------------------------------------------------------
-- Слепой

local blind = nil

local function blindModel(cf: CFrame)
	local desc = Instance.new("HumanoidDescription")
	local skin = rgb(196, 188, 176)
	local cloth = rgb(40, 38, 42)
	desc.HeadColor = skin
	desc.LeftArmColor, desc.RightArmColor = skin, skin
	desc.TorsoColor = cloth
	desc.LeftLegColor, desc.RightLegColor = cloth, cloth
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
		model:ScaleTo(1.55)
	end)
	local function weldTo(to: BasePart?, name, size, offset: CFrame, color, mat, shape)
		if not to then
			return
		end
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = mat or M.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		if shape then
			p.Shape = shape
		end
		p.CFrame = to.CFrame * offset
		local w = Instance.new("WeldConstraint")
		w.Part0 = to
		w.Part1 = p
		w.Parent = p
		p.Parent = model
	end
	local head = model:FindFirstChild("Head") :: BasePart?
	if head then
		local s = head.Size
		-- повязка на глазах, зашитый рот, впалые щёки
		weldTo(head, "Blindfold", Vector3.new(s.X * 1.06, s.Y * 0.3, s.Z * 1.06), CFrame.new(0, s.Y * 0.12, 0), rgb(120, 104, 84), M.Fabric)
		weldTo(head, "Knot", Vector3.new(s.X * 0.3, s.Y * 0.25, s.Z * 0.2), CFrame.new(0, s.Y * 0.12, s.Z * 0.6), rgb(110, 94, 76), M.Fabric)
		weldTo(head, "Mouth", Vector3.new(s.X * 0.55, s.Y * 0.06, 0.05), CFrame.new(0, -s.Y * 0.24, -s.Z / 2 - 0.02), rgb(60, 10, 10))
		for k = -2, 2 do
			weldTo(head, "Stitch", Vector3.new(0.05, s.Y * 0.16, 0.05), CFrame.new(k * s.X * 0.1, -s.Y * 0.24, -s.Z / 2 - 0.04), rgb(30, 20, 18))
		end
		-- большие уши: он слушает
		for _, x in { -1, 1 } do
			weldTo(head, "Ear", Vector3.new(0.15, s.Y * 0.55, s.Z * 0.4), CFrame.new(x * s.X * 0.55, 0, 0) * CFrame.Angles(0, x * 0.4, 0), skin)
		end
	end
	for _, hn in { "LeftHand", "RightHand" } do
		local hand = model:FindFirstChild(hn) :: BasePart?
		if hand then
			for f = -1, 1 do
				weldTo(hand, "Finger", Vector3.new(0.1, hand.Size.Y * 2.2, 0.1), CFrame.new(f * hand.Size.X * 0.3, -hand.Size.Y * 1.3, -0.1), skin)
			end
		end
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

-- погоня: Слепой больше не прислушивается, бежит по тоннелю за ближайшим игроком
function E.chase(info)
	if not blind then
		E.startBlind(info)
	end
	if not blind then
		return
	end
	blind.state = "chase"
	blind.path = nil
	blind.chasePath = info.chase.path
	blind.chaseIdx = 1
	blind.hum.WalkSpeed = Rules.BLIND_SPEED.chase
	sound(blind.root, SOUND.scream, 2, 0.5)
end

function E.noise(pos: Vector3, radius: number, kind: string?)
	if not blind or not blind.root.Parent or blind.state == "chase" then
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
		if flat(w.Position - b.root.Position).Magnitude < 3 then
			b.wp += 1
			w = b.path[b.wp] or w
		end
		b.hum:MoveTo(w.Position)
	end
end

local function catch(b)
	for _, p in G.alivePlayers() do
		local r = G.rootOf(p)
		if r and not G.isHidden(p) and flat(r.Position - b.root.Position).Magnitude < 5 and math.abs(r.Position.Y - b.root.Position.Y) < 8 then
			G.kill(p, "blind")
			sound(b.root, SOUND.scream, 1.5, 0.6)
			return true
		end
	end
	return false
end

local function stepBlind()
	local b = blind
	if not b or not b.root.Parent then
		return
	end
	local now = os.clock()
	if b.state == "chase" then
		catch(b)
		-- ближайший живой игрок; бежит по точкам тоннеля к нему
		local best, bestD = nil, math.huge
		for _, p in G.alivePlayers() do
			local r = G.rootOf(p)
			if r then
				local dd = (r.Position - b.root.Position).Magnitude
				if dd < bestD then
					best, bestD = r, dd
				end
			end
		end
		if best then
			local path = b.chasePath
			local i = b.chaseIdx
			if path[i] and flat(path[i] - b.root.Position).Magnitude < 4 then
				b.chaseIdx = math.min(#path, i + 1)
			end
			-- если игрок рядом и в прямой видимости — прямо к нему
			if bestD < 14 then
				b.hum:MoveTo(best.Position)
			else
				b.hum:MoveTo(path[b.chaseIdx] or best.Position)
			end
		end
		return
	end
	for _, p in G.alivePlayers() do
		local r = G.rootOf(p)
		if r and not G.isHidden(p) and G.inRoom(b.info, r.Position) then
			local v = r.AssemblyLinearVelocity
			local radius = Rules.noise(Vector3.new(v.X, 0, v.Z).Magnitude, G.isSneaking(p))
			if radius > 0 and (r.Position - b.root.Position).Magnitude < radius then
				E.noise(r.Position, radius, "step")
			end
		end
	end
	if catch(b) then
		b.state = "wander"
		b.target = nil
	end
	if b.state == "hunt" and b.target then
		b.hum.WalkSpeed = Rules.BLIND_SPEED.hunt
		blindGo(b.target)
		if flat(b.target - b.root.Position).Magnitude < 4 then
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
		if flat(b.target - b.root.Position).Magnitude < 4 then
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
		if not b.target or now > b.wanderAt or flat(b.target - b.root.Position).Magnitude < 4 then
			b.wanderAt = now + 8
			local list = b.info.wander
			b.target = list[math.random(1, #list)]
		end
		blindGo(b.target)
	end
end

-- ---------------------------------------------------------------------------

function E.whistle(p: Player)
	local r = G.rootOf(p)
	if not r then
		return
	end
	sound(r, SOUND.ping, 2, 2.2)
	freezeWatchers(r.Position)
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
	E.humActive = false
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
			task.wait(0.15)
			local ok, err = pcall(stepBlind)
			if not ok then
				warn("[Labyrinth] blind: " .. tostring(err))
			end
		end
	end)
end

return E
