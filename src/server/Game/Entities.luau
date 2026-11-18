--!nonstrict
-- Существа музея:
--   Тьма — плоская тень; летит через открытые залы до последней двери, открывает её,
--          гасит свет и возвращается обратно быстрее. Спасает шкафчик
--   тебЯ — мраморная копия игрока; повторяет его путь по залу, пока фигурки не на местах
--   Колосс — огромная слепая статуя в зале зеркал; слышит шаги, принюхивается, идёт на мясо

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
local G

local SOUND = {
	rumble = "rbxasset://sounds/swoosh.wav",
	scream = "rbxasset://sounds/uuhhh.mp3",
	hit = "rbxasset://sounds/swordslash.wav",
	ping = "rbxasset://sounds/electronicpingshort.wav",
	stone = "rbxasset://sounds/collide.wav",
	glass = "rbxasset://sounds/flashbulb.wav",
}
E.SOUND = SOUND
local WALK_ANIM = "rbxassetid://507777826"
local IDLE_ANIM = "rbxassetid://507766388"

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function sound(parent: Instance, id: string, vol: number, speed: number?, looped: boolean?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol
	s.PlaybackSpeed = speed or 1
	s.Looped = looped == true
	s.RollOffMaxDistance = 180
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

-- лампа лопается: свет гаснет насовсем
local function burst(bulb: Instance)
	if bulb:GetAttribute("Broken") then
		return
	end
	bulb:SetAttribute("Broken", true)
	local l = bulb:FindFirstChildOfClass("PointLight")
	if l then
		l.Enabled = false
	end
	if bulb:IsA("BasePart") then
		bulb.Material = M.Glass
		bulb.Color = rgb(40, 38, 36)
		local e = Instance.new("ParticleEmitter")
		e.Rate = 0
		e.Speed = NumberRange.new(6, 14)
		e.Lifetime = NumberRange.new(0.3, 0.7)
		e.Size = NumberSequence.new(0.15, 0)
		e.Color = ColorSequence.new(rgb(255, 230, 180))
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, -40, 0)
		e.Parent = bulb
		e:Emit(14)
		Debris:AddItem(e, 2)
	end
end

local function darkenRoom(info)
	for _, b in info.lights do
		if b.Parent then
			burst(b)
		end
	end
	for _, d in info.model:GetDescendants() do
		if d:IsA("PointLight") and d.Parent and CollectionService:HasTag(d.Parent, "LabLight") then
			burst(d.Parent)
		end
	end
	sound(info.model, SOUND.glass, 0.9, 1.6)
end

-- ---------------------------------------------------------------------------
-- Тьма

E.darkActive = false

-- плоское лицо: чёрный круг с пустыми глазами; клиент заставляет его дрожать
local function darkModel(at: Vector3)
	local p = Instance.new("Part")
	p.Name = "Darkness"
	p.Size = Vector3.new(2, 2, 2)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.CFrame = CFrame.new(at)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Face"
	bb.Size = UDim2.new(17, 0, 17, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 400
	bb.Parent = p
	local function frame(name, size, pos, color, round)
		local f = Instance.new("Frame")
		f.Name = name
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.fromScale(size.X, size.Y)
		f.Position = UDim2.fromScale(pos.X, pos.Y)
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		if round then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = f
		end
		f.Parent = bb
		return f
	end
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local t = frame("Tendril", Vector2.new(0.16, 0.5), Vector2.new(0.5 + math.cos(a) * 0.3, 0.5 + math.sin(a) * 0.3), Color3.new(0, 0, 0), true)
		t.Rotation = math.deg(a) + 90
	end
	frame("Body", Vector2.new(0.66, 0.66), Vector2.new(0.5, 0.5), Color3.new(0, 0, 0), true)
	frame("EyeL", Vector2.new(0.13, 0.17), Vector2.new(0.38, 0.42), Color3.new(1, 1, 1), true)
	frame("EyeR", Vector2.new(0.13, 0.17), Vector2.new(0.62, 0.42), Color3.new(1, 1, 1), true)
	frame("Mouth", Vector2.new(0.3, 0.1), Vector2.new(0.5, 0.66), Color3.new(1, 1, 1), true)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(Color3.new(0, 0, 0))
	smoke.Size = NumberSequence.new(7, 2)
	smoke.Transparency = NumberSequence.new(0.2, 1)
	smoke.Lifetime = NumberRange.new(0.8, 1.4)
	smoke.Rate = 60
	smoke.Speed = NumberRange.new(1, 4)
	smoke.LightEmission = 0
	smoke.Parent = p
	CollectionService:AddTag(p, "Darkness")
	return p
end

function E.darkness()
	if E.darkActive then
		return
	end
	local rooms = G.loadedRooms()
	if #rooms == 0 then
		return
	end
	E.darkActive = true
	local lights = {}
	for _, info in rooms do
		for _, b in info.lights do
			table.insert(lights, b)
		end
	end
	G.sendAll({ type = "dark", phase = "warn" })
	for _, p in G.alivePlayers() do
		G.discover(p, "darkness")
	end
	G.fleeKeepers()
	-- свет мигает, пока она приближается
	local warnTime = 5
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < warnTime do
			for _, bulb in lights do
				local l = bulb.Parent and bulb:FindFirstChildOfClass("PointLight")
				if l and not bulb:GetAttribute("Broken") and l.Brightness > 0 then
					l.Enabled = math.random() < 0.5
				end
			end
			task.wait(0.07 + math.random() * 0.12)
		end
		for _, bulb in lights do
			local l = bulb.Parent and bulb:FindFirstChildOfClass("PointLight")
			if l and not bulb:GetAttribute("Broken") then
				l.Enabled = true
			end
		end
	end)
	-- путь: издалека сзади (как будто за десять дверей), через все залы до последней двери
	local legs = {}
	for _, info in rooms do
		for _, pt in info.path do
			table.insert(legs, { pos = pt, info = info })
		end
	end
	local first = legs[1].pos
	local back = (first - legs[2].pos)
	local startPos = first + (if back.Magnitude > 0.1 then back.Unit else Vector3.zAxis) * 260
	local body = darkModel(startPos)
	body.Parent = workspace
	local rumble = sound(body, SOUND.rumble, 3, 0.2, true)
	task.wait(warnTime)
	G.sendAll({ type = "dark", phase = "rush" })
	local pos = startPos
	local function fly(target: Vector3, speed: number, info)
		while (target - pos).Magnitude > 1 do
			local dt = RunService.Heartbeat:Wait()
			pos += (target - pos).Unit * math.min(speed * dt, (target - pos).Magnitude)
			body.CFrame = CFrame.new(pos)
			for _, p in G.alivePlayers() do
				local r = G.rootOf(p)
				if r and not G.isHidden(p) then
					local off = r.Position - pos
					local near = flat(off).Magnitude < 14 and math.abs(off.Y) < 14
					local same = info and G.inRoom(info, r.Position) and flat(off).Magnitude < 60
					if near or same then
						G.kill(p, "darkness")
					end
				end
			end
		end
	end
	local done = {}
	for _, leg in legs do
		fly(leg.pos, 78, leg.info)
		if not done[leg.info] then
			done[leg.info] = true
			darkenRoom(leg.info)
		end
	end
	-- открывает следующую дверь и делает зал за ней тёмным
	local opened = G.darkOpen()
	if opened then
		darkenRoom(opened)
		for _, pt in opened.path do
			fly(pt, 78, opened)
		end
		for i = #opened.path, 1, -1 do
			fly(opened.path[i], 100, opened)
		end
	end
	-- возвращается обратно чуть быстрее
	for i = #legs, 1, -1 do
		fly(legs[i].pos, 100, legs[i].info)
	end
	fly(startPos, 130, nil)
	rumble:Stop()
	body:Destroy()
	G.sendAll({ type = "dark", phase = "gone" })
	E.darkActive = false
	-- кто пережил пролёт, тот спрятался
	for _, p in G.alivePlayers() do
		G.achieve(p, "darkness_hid")
	end
end

-- ---------------------------------------------------------------------------
-- общее для ходячих статуй

local function marble(model: Model, color: Color3)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = color
			d.Material = M.Marble
			if d:IsA("MeshPart") then
				pcall(function()
					d.TextureID = ""
				end)
			end
		elseif d:IsA("SpecialMesh") then
			d.TextureId = ""
		elseif d:IsA("Decal") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
end

local function rig(desc: HumanoidDescription?, name: string, scale: number): (Model?, Humanoid?)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc or Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		return nil, nil
	end
	model.Name = name
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.MaxHealth = math.huge
	hum.Health = math.huge
	hum.BreakJointsOnDeath = false
	if scale ~= 1 then
		pcall(function()
			model:ScaleTo(scale)
		end)
	end
	return model, hum
end

local function animate(hum: Humanoid, walkSpeed: number)
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local function load(id)
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(a)
		end)
		return if ok then track else nil
	end
	local walk, idle = load(WALK_ANIM), load(IDLE_ANIM)
	if idle then
		idle.Looped = true
		idle:Play()
	end
	if walk then
		walk.Looped = true
		hum.Running:Connect(function(speed)
			if speed > 0.5 then
				if not walk.IsPlaying then
					walk:Play(0.15)
				end
				walk:AdjustSpeed(speed / walkSpeed)
			elseif walk.IsPlaying then
				walk:Stop(0.2)
			end
		end)
	end
end

-- ---------------------------------------------------------------------------
-- тебЯ: статуя игрока в зале с фигурками

local mimics = {} -- info -> состояние

function E.spawnMimic(info)
	local puzzle = info.puzzle
	-- статуя того, кто сейчас в забеге (случайного живого игрока)
	local alive = G.alivePlayers()
	local who = alive[math.random(1, math.max(1, #alive))]
	local desc = nil
	if who then
		pcall(function()
			desc = Players:GetHumanoidDescriptionFromUserId(who.UserId)
		end)
	end
	local model, hum = rig(desc, "Mimic", 1)
	if not model then
		return
	end
	marble(model, rgb(206, 202, 192))
	model:PivotTo(puzzle.mimicCF * CFrame.new(0, 3, 0))
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	model.Parent = info.model
	hum.WalkSpeed = Rules.MIMIC.speed
	CollectionService:AddTag(model, "Mimic")
	mimics[info] = { model = model, hum = hum, root = root, info = info, awake = false, log = {}, waitUntil = 0, hitAt = 0, caught = false }
end

function E.removeMimic(info)
	local mm = mimics[info]
	if mm then
		if mm.model.Parent then
			mm.model:Destroy()
		end
		mimics[info] = nil
	end
end

-- статуя рассыпается
function E.crumbleMimic(info)
	local mm = mimics[info]
	if not mm then
		return
	end
	mimics[info] = nil
	sound(mm.root, SOUND.stone, 1.6, 0.5)
	for _, d in mm.model:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("Weld") or d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end
	for _, d in mm.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = true
			d.AssemblyLinearVelocity = Vector3.new(math.random(-6, 6), 8, math.random(-6, 6))
		end
	end
	Debris:AddItem(mm.model, 6)
end

function E.mimicNear(info, pos: Vector3): boolean
	local mm = mimics[info]
	return mm ~= nil and mm.root.Parent ~= nil and (mm.root.Position - pos).Magnitude < 9
end

local function stepMimics()
	local now = os.clock()
	for info, mm in mimics do
		if not mm.model.Parent then
			mimics[info] = nil
			continue
		end
		-- за кем повторяет: первый вошедший, потом любой живой в зале
		local track = mm.track
		if track and (not G.isAlive(track) or not G.rootOf(track) or not G.inRoom(info, (G.rootOf(track) :: BasePart).Position)) then
			track = nil
		end
		if not track then
			for _, p in G.alivePlayers() do
				local r = G.rootOf(p)
				if r and G.inRoom(info, r.Position) then
					local lp = info.origin:PointToObjectSpace(r.Position)
					if mm.awake or lp.Z < -5 then
						track = p
						break
					end
				end
			end
			mm.track = track
		end
		if not track then
			continue
		end
		local r = G.rootOf(track) :: BasePart
		if not mm.awake then
			mm.awake = true
			mm.root.Anchored = false
			pcall(function()
				mm.root:SetNetworkOwner(nil)
			end)
			animate(mm.hum, Rules.MIMIC.speed)
			mm.waitUntil = now + 2
			sound(mm.root, SOUND.stone, 1.2, 0.7)
			for _, p in G.alivePlayers() do
				G.discover(p, "mimic")
			end
		end
		-- запись пути игрока со временем; статуя идёт туда, где игрок был delay секунд назад
		local last = mm.log[#mm.log]
		if not last or now - last.t > 0.12 then
			table.insert(mm.log, { t = now, x = r.Position.X, z = r.Position.Z, y = r.Position.Y })
		end
		while #mm.log > 2 and mm.log[2].t < now - Rules.MIMIC.delay - 1 do
			table.remove(mm.log, 1)
		end
		local idx = Rules.replayAt(mm.log, now)
		local e = idx and mm.log[idx]
		if e and now >= mm.waitUntil then
			local goal = Vector3.new(e.x, e.y, e.z)
			if (r.Position - mm.root.Position).Magnitude < 4.2 then
				-- догнала: секунду ждёт
				if not mm.caught then
					mm.caught = true
					mm.waitUntil = now + Rules.MIMIC.wait
					mm.hum:MoveTo(mm.root.Position)
				end
			else
				mm.caught = false
				if flat(goal - mm.root.Position).Magnitude > 0.8 then
					mm.hum:MoveTo(goal)
				else
					-- игрок тогда стоял: стоит и она
					mm.hum:MoveTo(mm.root.Position)
				end
			end
		end
		-- касание
		if now - mm.hitAt > 1.5 then
			for _, p in G.alivePlayers() do
				local pr = G.rootOf(p)
				if pr and not G.isHidden(p) and (pr.Position - mm.root.Position).Magnitude < 3.8 then
					mm.hitAt = now
					G.damage(p, Rules.MIMIC.damage, "mimic")
					G.send(p, { type = "fx", kind = "scare" })
					sound(mm.root, SOUND.hit, 1, 0.7)
					break
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Колосс

local boss = nil

-- Колосс — каменный скелет зверя размером с динозавра из зала окаменелостей: позвонки,
-- рёбра, череп с зубами, ноги из костей-блоков, длинный хвост. Чертёж ниже — в
-- «больших» единицах, всё умножается на K. Невидимый каркас R15 только двигает его
local K = 0.645
local RIG = 2
E.COLOSSUS_HEIGHT = 3 * RIG -- корень над полом

local function sc(cf: CFrame): CFrame
	return CFrame.new(cf.Position * K) * cf.Rotation
end

function E.spawnColossus(info)
	E.removeColossus()
	local model, hum = rig(nil, "Colossus", RIG)
	if not model then
		return nil
	end
	for _, dsc in model:GetDescendants() do
		if dsc:IsA("BasePart") then
			dsc.Transparency = 1
			dsc.CanQuery = false
		elseif dsc:IsA("Decal") then
			dsc:Destroy()
		end
	end
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local stone, dark, bone = rgb(206, 202, 194), rgb(128, 122, 114), rgb(226, 218, 200)
	local motors = { legs = {}, all = {} }
	local function piece(name, size: Vector3, offset: CFrame, color, jointAt: CFrame?)
		offset = sc(offset)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * K
		p.Color = color or stone
		p.Material = M.Marble
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CFrame = hrp.CFrame * offset
		local mt = Instance.new("Motor6D")
		mt.Part0 = hrp
		mt.Part1 = p
		-- сустав: точка вращения в координатах корня и та же точка в координатах детали
		local joint = if jointAt then sc(jointAt) else offset
		mt.C0 = joint
		mt.C1 = offset:Inverse() * joint
		mt.Parent = p
		p.Parent = model
		table.insert(motors.all, mt)
		return p, mt
	end
	-- позвоночник и грудная клетка
	for k = 0, 9 do
		piece("Vertebra", Vector3.new(1.9, 1.7, 1.5), CFrame.new(0, 4.4 + math.sin(k * 0.4) * 0.3, -7 + k * 1.65) * CFrame.Angles(0.15, 0, 0), if k % 2 == 0 then stone else dark)
		piece("Spike", Vector3.new(0.6, 1.4, 0.8), CFrame.new(0, 5.8 + math.sin(k * 0.4) * 0.3, -7 + k * 1.65) * CFrame.Angles(-0.3, 0, 0), dark)
	end
	for k = 0, 6 do
		local z = -5.2 + k * 1.6
		local big = 1 - math.abs(k - 2.5) / 6
		for _, sx in { -1, 1 } do
			piece("Rib", Vector3.new(0.55, 4.2 * big + 0.8, 0.7), CFrame.new(sx * 2.4 * big, 2.6, z) * CFrame.Angles(0, 0, sx * 0.4), bone)
			piece("Rib", Vector3.new(0.55, 2.6 * big + 0.6, 0.7), CFrame.new(sx * 2.7 * big, -0.2, z) * CFrame.Angles(0, 0, -sx * 0.35), bone)
		end
	end
	piece("Sternum", Vector3.new(1.4, 0.8, 9.6), CFrame.new(0, -1.5, -0.4), dark)
	piece("Shoulders", Vector3.new(6.4, 2, 2.6), CFrame.new(0, 3.2, -5.6), stone)
	piece("Pelvis", Vector3.new(5.6, 2.6, 3.4), CFrame.new(0, 3, 6.8), stone)
	piece("Crack", Vector3.new(0.25, 2.4, 2.6), CFrame.new(2.85, 3.3, 6.8) * CFrame.Angles(0.5, 0, 0), rgb(60, 58, 56))
	-- шея и череп двигаются вместе, когда он принюхивается
	local neckJoint = CFrame.new(0, 4.6, -7.4)
	local head = {}
	local function hp(name, size, offset, color)
		local _, mt = piece(name, size, offset, color, neckJoint)
		table.insert(head, mt)
	end
	hp("Neck", Vector3.new(2, 2, 2.2), CFrame.new(0, 5.4, -8.8) * CFrame.Angles(0.5, 0, 0), dark)
	hp("Neck", Vector3.new(1.8, 1.8, 2.2), CFrame.new(0, 6.5, -10.5) * CFrame.Angles(0.4, 0, 0), stone)
	hp("Neck", Vector3.new(1.7, 1.7, 2), CFrame.new(0, 7.3, -12.2) * CFrame.Angles(0.25, 0, 0), dark)
	hp("Skull", Vector3.new(3.6, 2.8, 5.4), CFrame.new(0, 8, -15.6), stone)
	hp("Snout", Vector3.new(2.6, 2, 2.6), CFrame.new(0, 7.6, -19.2), stone)
	hp("Jaw", Vector3.new(3, 0.9, 6.4), CFrame.new(0, 6.1, -16.6) * CFrame.Angles(-0.08, 0, 0), dark)
	hp("Crest", Vector3.new(0.9, 2, 4), CFrame.new(0, 10, -14.6) * CFrame.Angles(-0.3, 0, 0), dark)
	hp("BlindBrow", Vector3.new(3.8, 0.9, 1.6), CFrame.new(0, 9.2, -17), dark)
	hp("EyeSocket", Vector3.new(0.9, 0.9, 0.6), CFrame.new(-1.45, 8.4, -17.6), rgb(30, 28, 26))
	hp("EyeSocket", Vector3.new(0.9, 0.9, 0.6), CFrame.new(1.45, 8.4, -17.6), rgb(30, 28, 26))
	for k = 0, 5 do
		for _, sx in { -1, 1 } do
			hp("Tooth", Vector3.new(0.35, 0.8, 0.35), CFrame.new(sx * 1.05, 6.6, -14.4 - k * 1.05), bone)
		end
	end
	motors.head = head
	for _, mt in head do
		mt:SetAttribute("Rest", mt.C0)
	end
	-- ноги: бедро, колено, голень и ступня из каменных костей
	for _, sx in { -1, 1 } do
		for _, z in { -5.4, 6.6 } do
			local hip = CFrame.new(sx * 3.4, 1.6, z)
			local _, a = piece("Thigh", Vector3.new(2.2, 5, 2.4), CFrame.new(sx * 3.5, -0.8, z) * CFrame.Angles(if z < 0 then -0.15 else 0.2, 0, 0), stone, hip)
			local _, b = piece("Knee", Vector3.new(1.8, 1.6, 1.8), CFrame.new(sx * 3.5, -3.6, z + (if z < 0 then 0.4 else -0.5)), dark, hip)
			local _, c = piece("Shin", Vector3.new(1.6, 4.6, 1.8), CFrame.new(sx * 3.5, -6.2, z), bone, hip)
			local _, f = piece("Foot", Vector3.new(3, 0.8, 3.8), CFrame.new(sx * 3.5, -8.9, z - 0.7), dark, hip)
			table.insert(motors.legs, {
				a, b, c, f,
				phase = if (sx < 0) == (z < 0) then 0 else math.pi,
				rest = sc(hip),
				knee = sc(CFrame.new(sx * 3.5, -3.6, z)),
				ankle = sc(CFrame.new(sx * 3.5, -8.5, z - 0.3)),
			})
		end
	end
	-- хвост: всё мельче к концу и ниже
	for k = 0, 7 do
		piece("Tail", Vector3.new(1.9 - k * 0.18, 1.7 - k * 0.15, 2.2), CFrame.new(0, 3.6 - k * 0.55, 9.2 + k * 2.1) * CFrame.Angles(-0.25, 0, 0), if k % 2 == 0 then stone else dark)
	end
	for _, mt in motors.all do
		mt:SetAttribute("Home", mt.C0)
	end
	-- разложить суставы по частям тела: ноги, голова, хвост и всё остальное (корпус)
	local taken = {}
	for _, leg in motors.legs do
		for j = 1, 4 do
			taken[leg[j]] = true
		end
	end
	for _, mt in motors.head do
		taken[mt] = true
	end
	motors.body, motors.tail = {}, {}
	motors.tailPivot = sc(CFrame.new(0, 3.8, 8.2))
	local tk = 0
	for _, mt in motors.all do
		if not taken[mt] then
			if mt.Part1 and mt.Part1.Name == "Tail" then
				tk += 1
				table.insert(motors.tail, { mt = mt, k = tk, home = mt.C0 })
			else
				table.insert(motors.body, mt)
			end
		end
	end
	model:PivotTo(info.arena.spawn * CFrame.new(0, E.COLOSSUS_HEIGHT, 0))
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	model.Parent = info.model
	CollectionService:AddTag(model, "Colossus")
	boss = { model = model, hum = hum, root = root, info = info, motors = motors, state = "statue", target = nil, sniffAt = 0, until_ = 0, wanderAt = 0, path = nil, pathAt = 0, wp = 1 }
	-- пока зал не открыт, он лежит грудой каменных блоков у постамента
	local rnd = Random.new(info.desc.door * 31 + 7)
	for _, mt in motors.all do
		local home = mt:GetAttribute("Home")
		local pile = CFrame.new(rnd:NextNumber(-5, 5), -E.COLOSSUS_HEIGHT + rnd:NextNumber(0.4, 1.6), rnd:NextNumber(-6, 6)) * CFrame.Angles(rnd:NextNumber(-1.5, 1.5), rnd:NextNumber(0, 6), rnd:NextNumber(-1.5, 1.5))
		-- деталь окажется в точке pile (C0 * C1⁻¹ = pile)
		mt:SetAttribute("Pile", pile * mt.C1)
		mt.C0 = pile * mt.C1
		local _ = home
	end
	return model
end

-- сцена: блоки один за другим поднимаются из груды и встают на места
function E.assembleColossus()
	local b = boss
	if not b or b.state ~= "statue" then
		return
	end
	b.assembling = true
	local list = table.clone(b.motors.all)
	-- снизу вверх: сначала ноги, потом тело, в конце голова
	table.sort(list, function(x, y)
		return (x:GetAttribute("Home") :: CFrame).Position.Y < (y:GetAttribute("Home") :: CFrame).Position.Y
	end)
	local t0 = os.clock()
	local span, each = 3.2, 0.9
	local lastSound = 0
	while b.model.Parent and b.assembling do
		local t = os.clock() - t0
		local done = true
		for i, mt in list do
			local start = (i - 1) / #list * span
			local a = math.clamp((t - start) / each, 0, 1)
			if a < 1 then
				done = false
			end
			local from, to = mt:GetAttribute("Pile") :: CFrame, mt:GetAttribute("Home") :: CFrame
			local e = 1 - (1 - a) ^ 3
			-- взлетает дугой и встаёт на место
			mt.C0 = from:Lerp(to, e) * CFrame.new(0, math.sin(a * math.pi) * 2, 0)
		end
		if t - lastSound > 0.35 and t < span then
			lastSound = t
			sound(b.root, SOUND.stone, 0.7, 0.6 + math.random() * 0.5)
		end
		if done then
			break
		end
		task.wait()
	end
	b.assembling = false
	sound(b.root, SOUND.scream, 1.6, 0.45)
end

function E.removeColossus()
	if boss then
		if boss.model.Parent then
			boss.model:Destroy()
		end
		boss = nil
	end
end

function E.wakeColossus()
	local b = boss
	if not b or b.state ~= "statue" then
		return
	end
	-- на всякий случай все блоки точно на местах
	b.assembling = false
	for _, mt in b.motors.all or {} do
		local home = mt:GetAttribute("Home")
		if typeof(home) == "CFrame" then
			mt.C0 = home
		end
	end
	b.root.Anchored = false
	pcall(function()
		b.root:SetNetworkOwner(nil)
	end)
	animate(b.hum, 16)
	b.hum.WalkSpeed = Rules.COLOSSUS.wander
	b.state = "wander"
	b.sniffAt = os.clock() + Rules.COLOSSUS.sniffEvery
	sound(b.root, SOUND.stone, 2, 0.4)
end

-- поза головы на время: listen — прислушивается, roar — учуял и рычит, lost — потерял
-- след и мотает головой, eat — ест, stun — ослеплён светом
local function pose(b, kind: string, dur: number)
	b.pose = { kind = kind, t0 = os.clock(), dur = dur }
end

-- шум в точке
function E.noise(pos: Vector3, radius: number)
	local b = boss
	if not b or b.state == "statue" or b.state == "defeat" or b.state == "bait" or b.state == "eat" or b.state == "stun" then
		return
	end
	if (b.root.Position - pos).Magnitude > radius then
		return
	end
	if b.state == "hunt" or b.state == "listen" then
		b.target = pos
		return
	end
	-- сначала замирает и прислушивается, потом идёт на звук
	b.state = "listen"
	b.target = pos
	b.until_ = os.clock() + 1.1
	b.hum:MoveTo(b.root.Position)
	pose(b, "listen", 1.1)
end

-- на полу лежит мясо: идёт к нему
function E.bait(pos: Vector3)
	local b = boss
	if b and b.state ~= "statue" and b.state ~= "defeat" and b.state ~= "stun" then
		b.state = "bait"
		b.target = pos
		b.path = nil
	end
end

local function bossGo(goal: Vector3)
	local b = boss
	local now = os.clock()
	if not b.path or now - b.pathAt > 1.5 or (b.goal and (b.goal - goal).Magnitude > 8) then
		b.pathAt = now
		b.goal = goal
		local path = PathfindingService:CreatePath({ AgentRadius = 3.5, AgentHeight = 11, AgentCanJump = false })
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
		if flat(w.Position - b.root.Position).Magnitude < 5 then
			b.wp += 1
			w = b.path[b.wp] or w
		end
		b.hum:MoveTo(w.Position)
	end
end

-- принюхивается: шея и голова медленно водят из стороны в сторону
local function sniffAnim(b)
	b.sniffFrom = os.clock()
	sound(b.root, SOUND.rumble, 1.4, 0.5)
end

-- Походка зверя: бедро качается, колено сгибается, когда нога идёт вперёд, стопа
-- остаётся ровной; корпус покачивается и чуть пружинит на каждом шаге, на месте
-- он дышит; хвост виляет волной от основания к кончику; голова кивает в такт
-- шагам и живёт своей позой (прислушивается, рычит, ест, ослеплён)
local function animateBeast()
	local b = boss
	if not b or not b.motors or not b.motors.body or not b.root.Parent or b.state == "defeat" or b.state == "statue" then
		return
	end
	local t = os.clock()
	local dt = math.min(0.1, t - (b.lastT or t))
	b.lastT = t
	local v = b.root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	b.gait = (b.gait or 0) + dt * speed * 0.45
	local want = math.clamp(speed / 9, 0, 1)
	b.walk = (b.walk or 0) + (want - (b.walk or 0)) * math.min(1, dt * 5)
	local w = b.walk
	local stun = b.state == "stun"
	local tremble = if stun then math.sin(t * 23) * 0.03 else 0
	-- корпус
	local bob = math.abs(math.sin(b.gait)) * 0.22 * w - 0.1 * w + math.sin(t * 1.3) * 0.05 * (1 - w)
	local roll = math.sin(b.gait) * 0.035 * w + tremble
	local pitch = math.sin(b.gait * 2) * 0.012 * w + (if b.state == "eat" then 0.05 else 0)
	local body = CFrame.new(0, bob, 0) * CFrame.Angles(pitch, 0, roll)
	for _, mt in b.motors.body do
		local home = mt:GetAttribute("Home")
		if typeof(home) == "CFrame" then
			mt.C0 = body * home
		end
	end
	-- хвост
	local tp = b.motors.tailPivot
	for _, e in b.motors.tail do
		local yaw = math.sin(t * (1.1 + w * 2.2) - e.k * 0.7) * (0.03 + 0.025 * e.k) * (0.6 + w)
		if stun then
			yaw += math.sin(t * 17 + e.k) * 0.06
		end
		e.mt.C0 = body * tp * CFrame.Angles(-0.015 * e.k * w, yaw, 0) * tp:Inverse() * e.home
	end
	-- ноги
	for _, leg in b.motors.legs do
		local ph = b.gait + leg.phase
		local hipA = math.sin(ph) * 0.4 * w + tremble
		local kneeA = -math.max(0, math.cos(ph)) * 0.7 * w
		local H = leg.rest * CFrame.Angles(hipA, 0, 0) * leg.rest:Inverse()
		local K = leg.knee * CFrame.Angles(kneeA, 0, 0) * leg.knee:Inverse()
		local A = leg.ankle * CFrame.Angles(-(hipA + kneeA), 0, 0) * leg.ankle:Inverse()
		leg[1].C0 = body * H * leg.rest
		leg[2].C0 = body * H * K * leg.rest
		leg[3].C0 = body * H * K * leg.rest
		leg[4].C0 = body * H * K * A * leg.rest
	end
	-- голова
	local yaw, hpitch, hroll = 0, math.sin(b.gait * 2) * 0.05 * w, 0
	local ps = b.pose
	if ps and t - ps.t0 < ps.dur then
		local k = (t - ps.t0) / ps.dur
		if ps.kind == "listen" then
			hroll = math.sin(math.min(1, k * 3) * math.pi / 2) * 0.35
			hpitch = -0.12
		elseif ps.kind == "roar" then
			hpitch = -0.5 * math.sin(k * math.pi)
			yaw = math.sin(t * 30) * 0.04
		elseif ps.kind == "lost" then
			yaw = math.sin(k * math.pi * 4) * 0.55
			hpitch = 0.1
		elseif ps.kind == "eat" then
			hpitch = 0.5 + math.sin(t * 7) * 0.08
		elseif ps.kind == "stun" then
			hpitch = -0.55 + math.sin(t * 17) * 0.1
			yaw = math.sin(t * 5) * 0.3
		elseif ps.kind == "bite" then
			-- рывок головой вперёд и вниз
			hpitch = 0.55 * math.sin(math.min(1, k * 2.5) * math.pi)
		end
	elseif b.sniffFrom and t - b.sniffFrom < Rules.COLOSSUS.sniffTime then
		local k = (t - b.sniffFrom) / Rules.COLOSSUS.sniffTime
		yaw = math.sin(k * math.pi * 3) * 0.6
		hpitch = -0.25 * math.sin(k * math.pi)
	elseif b.state == "hunt" or b.state == "bait" then
		hpitch += 0.14
	else
		-- спокойно: медленно водит головой по сторонам
		yaw = math.sin(t * 0.45) * 0.18 * (1 - w * 0.5)
	end
	for _, mt in b.motors.head do
		local rest = mt:GetAttribute("Rest")
		if typeof(rest) == "CFrame" then
			mt.C0 = body * rest * CFrame.Angles(hpitch, yaw, hroll)
		end
	end
end

-- поражение: люстра падает на ослеплённого зверя. Ноги подгибаются, голова
-- падает, по камню бегут светящиеся трещины, и он разваливается на куски
local function defeat(b)
	b.state = "defeat"
	b.hum.WalkSpeed = 0
	b.hum:MoveTo(b.root.Position)
	b.root.Anchored = true
	G.sendAll({ type = "fx", kind = "melt" })
	sound(b.root, SOUND.scream, 2, 0.3)
	local info = b.info
	local model = b.model
	local base = b.root.CFrame
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 1.8 and model.Parent do
			local k = math.min(1, (os.clock() - t0) / 1.8)
			for _, leg in b.motors.legs do
				local side = if leg.rest.Position.X < 0 then -1 else 1
				local c0 = leg.rest * CFrame.Angles(0.2 * k, 0, side * 0.9 * k)
				for j = 1, 4 do
					leg[j].C0 = c0
				end
			end
			for _, mt in b.motors.head do
				local rest = mt:GetAttribute("Rest")
				if typeof(rest) == "CFrame" then
					mt.C0 = rest * CFrame.Angles(0.75 * k, math.sin(k * 9) * 0.1 * (1 - k), 0)
				end
			end
			b.root.CFrame = base * CFrame.new(0, -2.2 * k, 0) * CFrame.Angles(0, 0, 0.12 * k)
			task.wait()
		end
		if not model.Parent then
			return
		end
		-- трещины светятся изнутри
		local body = model:FindFirstChild("Body") :: BasePart
		for i = 1, 12 do
			local host = if i % 2 == 0 then body else (model:FindFirstChild("Chest") or body)
			if host then
				local c = Instance.new("Part")
				c.Name = "GlowCrack"
				c.Size = Vector3.new(0.3, 1.5 + math.random() * 3, 0.3)
				c.Material = Enum.Material.Neon
				c.Color = rgb(255, 214, 140)
				c.CanCollide = false
				c.Massless = true
				local hs = host.Size
				c.CFrame = host.CFrame * CFrame.new((math.random() - 0.5) * hs.X, (math.random() - 0.5) * hs.Y, (math.random() - 0.5) * hs.Z) * CFrame.Angles(math.random() * 3, math.random() * 3, math.random() * 3)
				local w = Instance.new("WeldConstraint")
				w.Part0 = host
				w.Part1 = c
				w.Parent = c
				c.Parent = model
				sound(c, SOUND.stone, 0.6, 0.6 + math.random() * 0.6)
				task.wait(0.12)
			end
		end
		local dust = Instance.new("ParticleEmitter")
		dust.Color = ColorSequence.new(rgb(210, 204, 194))
		dust.Size = NumberSequence.new(4, 8)
		dust.Transparency = NumberSequence.new(0.3, 1)
		dust.Lifetime = NumberRange.new(1.5, 2.5)
		dust.Rate = 60
		dust.Speed = NumberRange.new(2, 6)
		dust.Parent = b.root
		task.wait(0.8)
		-- разваливается: суставы рвутся, куски падают на пол
		sound(b.root, SOUND.stone, 2.4, 0.35)
		for _, dsc in model:GetDescendants() do
			if dsc:IsA("Motor6D") then
				dsc:Destroy()
			end
		end
		for _, dsc in model:GetDescendants() do
			if dsc:IsA("BasePart") and dsc ~= b.root then
				dsc.Anchored = false
				if dsc.Transparency < 1 then
					dsc.CanCollide = true
					dsc.AssemblyLinearVelocity = Vector3.new(math.random(-10, 10), math.random(4, 12), math.random(-10, 10))
				else
					dsc.CanCollide = false
				end
			end
		end
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:Destroy()
		end
		task.wait(1.5)
		dust.Rate = 0
		local pos = b.root.Position
		boss = nil
		Debris:AddItem(model, 40)
		G.bossDead(info, pos)
	end)
end

-- люстра упала: ослеплённый зверь под ней — побеждён
function E.chandelierHit(pos: Vector3, radius: number): boolean
	local b = boss
	if not b or not b.root.Parent then
		return false
	end
	local near = flat(b.root.Position - pos).Magnitude < radius
	if near and b.state == "stun" then
		defeat(b)
		return true
	end
	return false
end

local function stepColossus()
	local b = boss
	if not b or not b.root.Parent or b.state == "statue" or b.state == "defeat" then
		return
	end
	local now = os.clock()
	local C = Rules.COLOSSUS
	local arena = b.info.arena
	-- слышит шаги и ловит тех, кто рядом на полу зала (на галереях не достаёт)
	for _, p in G.alivePlayers() do
		local r = G.rootOf(p)
		if r and G.inRoom(b.info, r.Position) then
			local v = r.AssemblyLinearVelocity
			local radius = Rules.noise(Vector3.new(v.X, 0, v.Z).Magnitude, G.isSneaking(p))
			if radius > 0 then
				E.noise(r.Position, radius)
			end
			local low = r.Position.Y < arena.floorY + 7
			if low and flat(r.Position - b.root.Position).Magnitude < 6.5 and b.state ~= "eat" and b.state ~= "stun" then
				G.kill(p, "colossus")
				pose(b, "bite", 0.7)
				sound(b.root, SOUND.stone, 1.6, 0.5)
				if b.state == "hunt" then
					b.state = "wander"
					b.target = nil
				end
			end
		end
	end
	if b.state == "bait" then
		b.hum.WalkSpeed = C.hunt
		bossGo(b.target)
		if flat(b.target - b.root.Position).Magnitude < 7 then
			b.hum:MoveTo(b.root.Position)
			G.eatBait(b.info)
			local inLight = arena.lit and flat(b.target - arena.zone.Position).Magnitude < Rules.ARENA.zone
			if inLight then
				-- свет ударил в камень: зверь ослеплён и бьётся на месте
				b.state = "stun"
				b.until_ = now + Rules.ARENA.stun
				pose(b, "stun", Rules.ARENA.stun)
				sound(b.root, SOUND.scream, 2, 0.5)
				G.sendAll({ type = "fx", kind = "shake" })
			else
				-- мясо не там: съедает и уходит
				b.state = "eat"
				b.until_ = now + 2.5
				pose(b, "eat", 2.5)
				sound(b.root, SOUND.hit, 1.4, 0.4)
			end
		end
	elseif b.state == "eat" or b.state == "stun" then
		b.hum:MoveTo(b.root.Position)
		if now > b.until_ then
			b.state = "wander"
			b.target = nil
			b.pose = nil
		end
	elseif b.state == "listen" then
		b.hum:MoveTo(b.root.Position)
		if now > b.until_ then
			b.state = "hunt"
			b.hunting = true
			pose(b, "roar", 0.9)
			sound(b.root, SOUND.scream, 1.2, 0.6)
		end
	elseif b.state == "sniff" then
		b.hum:MoveTo(b.root.Position)
		if now > b.until_ then
			-- учуял того, кто рядом на полу
			local best, bestD = nil, C.sniffRange
			for _, p in G.alivePlayers() do
				local r = G.rootOf(p)
				if r and r.Position.Y < arena.floorY + 7 and not G.isHidden(p) then
					local dd = (r.Position - b.root.Position).Magnitude
					if dd < bestD then
						best, bestD = r, dd
					end
				end
			end
			if best then
				b.state = "hunt"
				b.target = best.Position
				pose(b, "roar", 0.9)
				sound(b.root, SOUND.scream, 1.2, 0.6)
			else
				if b.hunting then
					-- потерял след: мотает головой и возвращается к обходу
					pose(b, "lost", 1.6)
					b.hunting = false
				end
				b.state = "wander"
				b.target = nil
			end
			b.sniffAt = now + C.sniffEvery
		end
	elseif b.state == "hunt" and b.target then
		b.hum.WalkSpeed = C.hunt
		bossGo(b.target)
		if flat(b.target - b.root.Position).Magnitude < 6 then
			b.state = "sniff"
			b.until_ = now + C.sniffTime
			sniffAnim(b)
		end
	else
		b.hum.WalkSpeed = C.wander
		if b.pose and b.pose.kind == "lost" and now - b.pose.t0 < b.pose.dur then
			b.hum:MoveTo(b.root.Position)
			return
		end
		if now > b.sniffAt then
			b.state = "sniff"
			b.until_ = now + C.sniffTime
			sniffAnim(b)
			return
		end
		if not b.target or now > b.wanderAt or flat(b.target - b.root.Position).Magnitude < 6 then
			b.wanderAt = now + 9
			b.target = arena.wander[math.random(1, #arena.wander)]
		end
		bossGo(b.target)
	end
end

-- ---------------------------------------------------------------------------

function E.removeRoom(info)
	E.removeMimic(info)
	if boss and boss.info == info then
		E.removeColossus()
	end
end

function E.clear()
	for info in mimics do
		E.removeMimic(info)
	end
	E.removeColossus()
	for _, h in workspace:GetChildren() do
		if h.Name == "Darkness" then
			h:Destroy()
		end
	end
	E.darkActive = false
end

function E.init(game_)
	G = game_
	RunService.Heartbeat:Connect(function()
		pcall(animateBeast)
	end)
	task.spawn(function()
		while true do
			task.wait(0.15)
			local ok, err = pcall(stepMimics)
			if not ok then
				warn("[Museum] mimic: " .. tostring(err))
			end
			ok, err = pcall(stepColossus)
			if not ok then
				warn("[Museum] colossus: " .. tostring(err))
			end
		end
	end)
end

return E
