--!nonstrict
-- NPC замка: стражники короля (идут за королём, по приказу атакуют игрока),
-- тренировочный манекен, который отвечает ударом, и парящая статуя жреца с книгой

local MAT = require(game:GetService("ReplicatedStorage").Workshop.Shared.Materials)
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")

local Npc = {}

local WALK_ANIM = "rbxassetid://507777826"
local IDLE_ANIM = "rbxassetid://507766388"
local SLASH_ANIM = "rbxassetid://522635514"

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function weldPart(parent: Instance, to: BasePart, props, offset: CFrame)
	local p = Instance.new(props.Class or "Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "Class" then
			(p :: any)[k] = v
		end
	end
	p.CFrame = to.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = p
	w.Parent = p
	p.Parent = parent
	return p
end
Npc.weldPart = weldPart

-- ---------------------------------------------------------------------------
-- Стражники короля

Npc.minions = {} :: { any }

local function rootOf(model: Model?): BasePart?
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function aliveHum(model: Model?): Humanoid?
	local h = model and model:FindFirstChildOfClass("Humanoid")
	if h and h.Health > 0 then
		return h
	end
	return nil
end

function Npc.aliveCount(): number
	local n = 0
	for _, m in Npc.minions do
		if aliveHum(m.model) then
			n += 1
		end
	end
	return n
end

local function dressMinion(model: Model)
	local head = model:FindFirstChild("Head") :: BasePart?
	local torso = model:FindFirstChild("UpperTorso") :: BasePart?
	local hand = model:FindFirstChild("RightHand") :: BasePart?
	if head then
		weldPart(model, head, { Name = "Helmet", Size = Vector3.new(1.35, 0.9, 1.35), Color = rgb(170, 172, 180), Material = MAT.Metal }, CFrame.new(0, 0.35, 0))
		weldPart(model, head, { Name = "Plume", Size = Vector3.new(0.25, 0.9, 1.1), Color = rgb(214, 172, 80), Material = MAT.SmoothPlastic }, CFrame.new(0, 1.1, 0.1))
	end
	if torso then
		weldPart(model, torso, { Name = "Tabard", Size = Vector3.new(1.7, 1.9, 0.15), Color = rgb(150, 20, 30), Material = MAT.SmoothPlastic }, CFrame.new(0, -0.2, -0.55))
		weldPart(model, torso, { Name = "Emblem", Size = Vector3.new(0.6, 0.6, 0.05), Color = rgb(214, 172, 80), Material = MAT.Metal }, CFrame.new(0, 0.1, -0.65))
	end
	if hand then
		weldPart(model, hand, { Name = "Blade", Size = Vector3.new(0.2, 3.2, 0.4), Color = rgb(200, 202, 210), Material = MAT.Metal }, CFrame.new(0, -0.3, -1.6) * CFrame.Angles(math.rad(90), 0, 0))
		weldPart(model, hand, { Name = "Guard", Size = Vector3.new(0.9, 0.2, 0.2), Color = rgb(214, 172, 80), Material = MAT.Metal }, CFrame.new(0, -0.3, 0))
	end
end

function Npc.spawnMinion(at: CFrame, parent: Instance)
	local desc = Instance.new("HumanoidDescription")
	local skin = ({ rgb(234, 184, 146), rgb(204, 142, 105), rgb(160, 110, 80), rgb(110, 75, 55) })[math.random(1, 4)]
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = rgb(60, 60, 70)
	desc.LeftLegColor = rgb(40, 40, 46)
	desc.RightLegColor = rgb(40, 40, 46)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		return nil
	end
	model.Name = "RoyalGuard"
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	hum.MaxHealth = 120
	hum.Health = 120
	hum.WalkSpeed = 15
	for _, s in model:GetDescendants() do
		if s:IsA("Script") or s:IsA("LocalScript") then
			s:Destroy()
		end
	end
	dressMinion(model)
	model:SetAttribute("Minion", true)
	model:PivotTo(at)
	model.Parent = parent
	local root = rootOf(model)
	if root then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local function load(id)
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok2, track = pcall(function()
			return animator:LoadAnimation(a)
		end)
		return if ok2 then track else nil
	end
	local m = { model = model, hum = hum, walk = load(WALK_ANIM), idle = load(IDLE_ANIM), slash = load(SLASH_ANIM), lastHit = 0, path = nil, pathAt = 0, wp = 1 }
	if m.idle then
		m.idle.Looped = true
		m.idle:Play()
	end
	if m.walk then
		m.walk.Looped = true
	end
	hum.Running:Connect(function(speed)
		if not m.walk then
			return
		end
		if speed > 0.5 then
			if not m.walk.IsPlaying then
				m.walk:Play(0.15)
			end
			m.walk:AdjustSpeed(speed / 14)
		elseif m.walk.IsPlaying then
			m.walk:Stop(0.2)
		end
	end)
	hum.Died:Connect(function()
		task.delay(4, function()
			model:Destroy()
		end)
	end)
	table.insert(Npc.minions, m)
	return m
end

function Npc.clearMinions()
	for _, m in Npc.minions do
		if m.model then
			m.model:Destroy()
		end
	end
	table.clear(Npc.minions)
end

-- идти к точке: напрямую, если путь свободен, иначе по навигационной сетке
local function goTo(m, goal: Vector3)
	local root = rootOf(m.model)
	if not root then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { m.model }
	local dir = goal - root.Position
	local hit = workspace:Raycast(root.Position, dir, params)
	if not hit or (hit.Position - goal).Magnitude < 4 then
		m.path = nil
		m.hum:MoveTo(goal)
		return
	end
	local now = os.clock()
	if not m.path or now - m.pathAt > 1.5 then
		m.pathAt = now
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
		local ok = pcall(function()
			path:ComputeAsync(root.Position, goal)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			m.path = path:GetWaypoints()
			m.wp = 2
		else
			m.path = nil
			m.hum:MoveTo(goal)
			return
		end
	end
	local wps = m.path
	if wps and wps[m.wp] then
		local w = wps[m.wp]
		if (Vector3.new(w.Position.X, root.Position.Y, w.Position.Z) - root.Position).Magnitude < 3 then
			m.wp += 1
			w = wps[m.wp] or w
		end
		if w.Action == Enum.PathWaypointAction.Jump then
			m.hum.Jump = true
		end
		m.hum:MoveTo(w.Position)
	end
end

-- Один шаг поведения всех стражников. leader — король (или nil), target — цель атаки
function Npc.stepMinions(leader: Player?, target: Model?, onHit: (Model, Humanoid) -> ())
	local leaderRoot = leader and rootOf(leader.Character)
	local i = 0
	for k = #Npc.minions, 1, -1 do
		local m = Npc.minions[k]
		if not m.model.Parent or m.hum.Health <= 0 then
			table.remove(Npc.minions, k)
		end
	end
	for _, m in Npc.minions do
		i += 1
		local root = rootOf(m.model)
		if not root then
			continue
		end
		local tRoot = target and aliveHum(target) and rootOf(target)
		if tRoot then
			local d = (tRoot.Position - root.Position).Magnitude
			if d > 4.5 then
				goTo(m, tRoot.Position)
			else
				m.hum:MoveTo(root.Position)
				root.CFrame = CFrame.lookAt(root.Position, Vector3.new(tRoot.Position.X, root.Position.Y, tRoot.Position.Z))
			end
			if d < 6 and os.clock() - m.lastHit > 1 then
				m.lastHit = os.clock()
				if m.slash then
					m.slash:Play()
				end
				onHit(target :: Model, aliveHum(target) :: Humanoid)
			end
		elseif leaderRoot then
			-- строй позади короля
			local side = if i % 2 == 0 then 1 else -1
			local row = math.ceil(i / 2)
			local spot = (leaderRoot.CFrame * CFrame.new(side * 3, 0, 4 + row * 3.5)).Position
			if (spot - root.Position).Magnitude > 3 then
				goTo(m, spot)
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Тренировочный манекен: принимает удары и отвечает

function Npc.buildDummy(at: CFrame, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "TrainingDummy"
	local function p(name, size, cf, color, mat)
		local x = Instance.new("Part")
		x.Name = name
		x.Size = size
		x.CFrame = at * cf
		x.Color = color
		x.Material = mat
		x.Anchored = true
		x.Parent = m
		return x
	end
	local root = p("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(0, 0, 0), rgb(150, 120, 80), MAT.Cardboard)
	root.Transparency = 1
	p("Post", Vector3.new(0.6, 6, 0.6), CFrame.new(0, -1, 0), rgb(90, 62, 40), MAT.Wood)
	p("Base", Vector3.new(3, 0.6, 3), CFrame.new(0, -3.7, 0), rgb(70, 50, 34), MAT.Wood)
	p("Torso", Vector3.new(2, 2.4, 1.1), CFrame.new(0, 0.6, 0), rgb(196, 168, 120), MAT.Cardboard)
	local head = p("Head", Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 2.5, 0), rgb(196, 168, 120), MAT.Cardboard)
	head.Shape = Enum.PartType.Ball
	local arm = p("Arm", Vector3.new(3.6, 0.5, 0.5), CFrame.new(0, 1.2, -0.2), rgb(90, 62, 40), MAT.Wood)
	p("Target", Vector3.new(1.2, 1.2, 0.1), CFrame.new(0, 0.7, -0.6), rgb(170, 30, 30), MAT.SmoothPlastic)
	local hum = Instance.new("Humanoid")
	hum.MaxHealth = 400
	hum.Health = 400
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	hum.BreakJointsOnDeath = false
	hum.Parent = m
	m.PrimaryPart = root
	m:SetAttribute("Dummy", true)
	m.Parent = parent
	local home = arm.CFrame
	local busy = false
	local dummy = { model = m, hum = hum }
	-- удар в ответ: рука-палка разворачивается в сторону обидчика
	function dummy.onHit(attacker: Model)
		hum.Health = math.max(1, hum.Health)
		if busy then
			return
		end
		busy = true
		task.delay(0.35, function()
			local aRoot = rootOf(attacker)
			if aRoot then
				local swing = TweenService:Create(arm, TweenInfo.new(0.18, Enum.EasingStyle.Back), { CFrame = home * CFrame.Angles(0, math.rad(80), 0) })
				swing:Play()
				swing.Completed:Wait()
				local d = (aRoot.Position - root.Position).Magnitude
				local ah = aliveHum(attacker)
				if ah and d < 8 then
					ah:TakeDamage(6)
					aRoot.AssemblyLinearVelocity = (aRoot.Position - root.Position).Unit * 30 + Vector3.new(0, 15, 0)
				end
				TweenService:Create(arm, TweenInfo.new(0.4), { CFrame = home }):Play()
			end
			busy = false
		end)
	end
	task.spawn(function()
		while m.Parent do
			task.wait(2)
			if hum.Health < hum.MaxHealth then
				hum.Health = math.min(hum.MaxHealth, hum.Health + 40)
			end
		end
	end)
	return dummy
end

-- ---------------------------------------------------------------------------
-- Парящая статуя жреца в мантии с книгой; покачивание делает клиент (атрибут Float)

function Npc.buildPriest(at: CFrame, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "FloatingPriest"
	local STONE = rgb(190, 186, 178)
	local function p(name, shape, size, cf, color, mat)
		local x = Instance.new("Part")
		x.Name = name
		x.Shape = shape or Enum.PartType.Block
		x.Size = size
		x.CFrame = at * cf
		x.Color = color or STONE
		x.Material = mat or MAT.Marble
		x.Anchored = true
		x.CanCollide = false
		x.Parent = m
		return x
	end
	local Cyl, Ball = Enum.PartType.Cylinder, Enum.PartType.Ball
	-- мантия: расширяется книзу
	for k = 0, 4 do
		local r = 4.2 - k * 0.55
		p("Robe", Cyl, Vector3.new(1.3, r, r), CFrame.new(0, k * 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2))
	end
	p("Shoulders", Ball, Vector3.new(3.2, 1.4, 2.2), CFrame.new(0, 6, 0))
	p("Head", Ball, Vector3.new(1.5, 1.6, 1.5), CFrame.new(0, 7.2, 0))
	p("Hood", Ball, Vector3.new(2, 2.1, 2), CFrame.new(0, 7.35, 0.25))
	p("Beard", nil, Vector3.new(0.9, 1.2, 0.3), CFrame.new(0, 6.6, -0.7))
	for _, s in { -1, 1 } do
		p("Sleeve", nil, Vector3.new(0.8, 0.8, 2.4), CFrame.new(s * 1.1, 5.3, -1) * CFrame.Angles(math.rad(-15), 0, 0))
		p("Hand", Ball, Vector3.new(0.6, 0.6, 0.6), CFrame.new(s * 0.9, 5.1, -2.2))
	end
	-- раскрытая книга со светящимися страницами
	p("Cover", nil, Vector3.new(2.6, 0.15, 1.7), CFrame.new(0, 5.3, -2.4) * CFrame.Angles(math.rad(-25), 0, 0), rgb(120, 40, 40), MAT.Leather)
	local pages = p("Pages", nil, Vector3.new(2.4, 0.12, 1.5), CFrame.new(0, 5.42, -2.42) * CFrame.Angles(math.rad(-25), 0, 0), rgb(255, 236, 190), MAT.Neon)
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 220, 160)
	light.Range = 16
	light.Brightness = 1.4
	light.Parent = pages
	local dust = Instance.new("ParticleEmitter")
	dust.Rate = 6
	dust.Lifetime = NumberRange.new(2, 3)
	dust.Speed = NumberRange.new(0.5, 1)
	dust.Size = NumberSequence.new(0.15)
	dust.LightEmission = 1
	dust.Color = ColorSequence.new(rgb(255, 230, 170))
	dust.Parent = pages
	m:SetAttribute("Float", true)
	m.Parent = parent
	return m
end

return Npc
