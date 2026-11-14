--!nonstrict
-- Режим «Маньяк»: лобби, раунд, удары и способности маньяка, генераторы, доски, прятки,
-- казнь, призраки, побег. Карта — тёмная копия замка далеко от острова.
-- Чат и сообщения на экране у режима свои, игроки замка их не видят

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Rules = require(Shared.ManiacRules)
local Remotes = require(Shared.Roblox.Remotes)
local MAT = require(Shared.Materials)

local Builder = require(script.Parent.Parent.Castle.CastleBuilder)
local Npc = require(script.Parent.Parent.Castle.Npc)

local M = {}

local OFFSET = Vector3.new(2600, 0, 0)

local SOUND = {
	scream = "rbxasset://sounds/uuhhh.mp3",
	slash = "rbxasset://sounds/swordslash.wav",
	fixed = "rbxasset://sounds/electronicpingshort.wav",
	boards = "rbxasset://sounds/collide.wav",
}

local state = {
	phase = "lobby", -- lobby | countdown | playing | results
	endsAt = 0,
	players = {} :: { [Player]: any }, -- участники (в лобби и в раунде)
	maniac = nil :: Player?,
	exitOpen = false,
	gensTotal = 0,
	winner = nil,
	lastAbility = {} :: { [string]: number },
}
M.state = state

local map
local event: RemoteEvent
local hooks = {}
local gens = {} -- { body, lamp, progress, done }
local hiddenIn: { [Player]: BasePart } = {}
local occupied: { [BasePart]: Player } = {}

local function rootOf(p: Player): BasePart?
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end
local function humOf(p: Player): Humanoid?
	return p.Character and p.Character:FindFirstChildOfClass("Humanoid")
end

local function send(p: Player, msg)
	if p.Parent and not (p :: any).isBot then
		event:FireClient(p, msg)
	end
end
local function sendAll(msg)
	for p in state.players do
		send(p, msg)
	end
end
local function announce(key: string, ...)
	sendAll({ type = "announce", key = key, args = { ... } })
end

local function sound(at: Instance?, id: string, vol: number, speed: number?)
	if not at then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol
	s.PlaybackSpeed = speed or 1
	s.RollOffMaxDistance = 90
	s.Parent = at
	s:Play()
	Debris:AddItem(s, 6)
end

local function teleport(p: Player, cf: CFrame)
	local char = p.Character
	if not char then
		return
	end
	local r = rootOf(p)
	if r then
		r.Anchored = false
		r.AssemblyLinearVelocity = Vector3.zero
	end
	local hum = humOf(p)
	if hum and hum.SeatPart then
		hum.Sit = false
	end
	pcall(function()
		p:RequestStreamAroundAsync(cf.Position, 3)
	end)
	char:PivotTo(cf)
end

local function survivors()
	local list = {}
	for p, info in state.players do
		if info.role == "survivor" then
			table.insert(list, p)
		end
	end
	return list
end

-- Состояние для клиентов: каждый видит свою роль и общий счёт
local function sync()
	local states = {}
	for p, info in state.players do
		if info.role == "survivor" then
			table.insert(states, { name = p.DisplayName, st = info.st, userId = p.UserId })
		end
	end
	local done = 0
	for _, g in gens do
		if g.done then
			done += 1
		end
	end
	for p, info in state.players do
		send(p, {
			type = "state",
			phase = state.phase,
			endsAt = state.endsAt,
			role = info.role,
			st = info.st,
			ghost = info.ghost == true,
			count = (function()
				local n = 0
				for _ in state.players do
					n += 1
				end
				return n
			end)(),
			survivors = states,
			gensDone = done,
			gensTotal = state.gensTotal,
			exitOpen = state.exitOpen,
			winner = state.winner,
			maniacName = if state.maniac then state.maniac.DisplayName else nil,
		})
	end
end
M.sync = sync

-- ---------------------------------------------------------------------------
-- чат режима

local function channel(): TextChannel
	local folder = TextChatService:FindFirstChild("TextChannels") or TextChatService
	local c = folder:FindFirstChild("ManiacRoom") :: TextChannel?
	if not c then
		local nc = Instance.new("TextChannel")
		nc.Name = "ManiacRoom"
		nc.Parent = folder
		c = nc
	end
	return c :: TextChannel
end

local function setChat(p: Player, on: boolean)
	if (p :: any).isBot then
		return
	end
	local c = channel()
	local src = nil
	for _, s in c:GetChildren() do
		if s:IsA("TextSource") and s.UserId == p.UserId then
			src = s
		end
	end
	if on and not src then
		pcall(function()
			src = c:AddUserAsync(p.UserId)
		end)
	elseif not on and src then
		src:Destroy()
		src = nil
	end
	if src then
		local info = state.players[p]
		src.CanSend = not (info and info.ghost and state.phase == "playing")
	end
end

-- ---------------------------------------------------------------------------
-- облик маньяка: плащ с капюшоном, маска-череп со светящимися глазами, когти

local function dressManiac(p: Player)
	local char = p.Character
	if not char then
		return
	end
	pcall(function()
		char:ScaleTo(1.18)
	end)
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			if d.Parent:IsA("Accessory") then
				d.Transparency = 1
			else
				d.Color = Color3.fromRGB(28, 24, 26)
				d.Material = MAT.SmoothPlastic
			end
			d.CollisionGroup = "ManiacChar"
		elseif d:IsA("Decal") and d.Name == "face" then
			d.Transparency = 1
		elseif d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			d:Destroy()
		end
	end
	local root = rootOf(p)
	if root then
		root.CollisionGroup = "ManiacChar"
	end
	local weld = Npc.weldPart
	local f = Instance.new("Folder")
	f.Name = "ManiacCostume"
	f.Parent = char
	local head = char:FindFirstChild("Head")
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if head then
		weld(f, head, { Name = "Hood", Shape = Enum.PartType.Ball, Size = head.Size * 1.45, Color = Color3.fromRGB(18, 14, 16), Material = MAT.SmoothPlastic }, CFrame.new(0, 0.15, 0.2))
		weld(f, head, { Name = "Mask", Size = Vector3.new(head.Size.X * 0.9, head.Size.Y * 0.9, 0.2), Color = Color3.fromRGB(226, 218, 200), Material = MAT.SmoothPlastic }, CFrame.new(0, 0, -head.Size.Z / 2 - 0.08))
		for _, x in { -0.22, 0.22 } do
			weld(f, head, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.22, 0.22, 0.1), Color = Color3.fromRGB(255, 30, 20), Material = MAT.Neon }, CFrame.new(x, 0.12, -head.Size.Z / 2 - 0.2))
		end
		weld(f, head, { Name = "Mouth", Size = Vector3.new(0.5, 0.08, 0.05), Color = Color3.fromRGB(30, 10, 10), Material = MAT.SmoothPlastic }, CFrame.new(0, -0.3, -head.Size.Z / 2 - 0.2))
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 40, 30)
		glow.Range = 8
		glow.Brightness = 1.2
		glow.Parent = f:FindFirstChild("Eye")
	end
	if torso then
		weld(f, torso, { Name = "Cloak", Size = Vector3.new(torso.Size.X * 1.25, 5.6, 0.2), Color = Color3.fromRGB(22, 16, 18), Material = MAT.SmoothPlastic }, CFrame.new(0, -1.9, torso.Size.Z / 2 + 0.25) * CFrame.Angles(math.rad(6), 0, 0))
		weld(f, torso, { Name = "Chain", Size = Vector3.new(torso.Size.X * 1.1, 0.25, 0.25), Color = Color3.fromRGB(80, 78, 74), Material = MAT.Metal }, CFrame.new(0, 0.2, -torso.Size.Z / 2 - 0.1) * CFrame.Angles(0, 0, math.rad(25)))
	end
	for _, hn in { "RightHand", "LeftHand", "Right Arm", "Left Arm" } do
		local hand = char:FindFirstChild(hn)
		if hand and hand:IsA("BasePart") then
			for k = -1, 1 do
				weld(f, hand, { Name = "Claw", Size = Vector3.new(0.08, 1.6, 0.08), Color = Color3.fromRGB(190, 190, 196), Material = MAT.Metal }, CFrame.new(k * 0.18, -hand.Size.Y / 2 - 0.7, -0.15) * CFrame.Angles(math.rad(-15), 0, 0))
			end
		end
	end
	local hum = humOf(p)
	if hum then
		hum.WalkSpeed = Rules.SPEED.maniac
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

-- ---------------------------------------------------------------------------
-- выжившие: ранен, лежит, погиб, спасся

local function setSpeed(p: Player)
	local info = state.players[p]
	local hum = humOf(p)
	if not info or not hum then
		return
	end
	if info.role == "maniac" then
		hum.WalkSpeed = Rules.SPEED.maniac
	elseif info.st == "downed" then
		hum.WalkSpeed = Rules.SPEED.downed
		hum.JumpPower = 0
		hum.UseJumpPower = true
	elseif info.st == "injured" then
		hum.WalkSpeed = Rules.SPEED.injured
	else
		hum.WalkSpeed = Rules.SPEED.survivor
	end
	p:SetAttribute("ManiacState", info.st)
end

local function unhide(p: Player)
	local part = hiddenIn[p]
	if not part then
		return
	end
	hiddenIn[p] = nil
	occupied[part] = nil
	p:SetAttribute("HiddenEye", nil)
	local r = rootOf(p)
	if r then
		r.Anchored = false
		local out = part.CFrame * CFrame.new(0, -part.Size.Y / 2 + 3, -(part.Size.Z / 2 + 2.5))
		p.Character:PivotTo(CFrame.lookAt(out.Position, out.Position + part.CFrame.LookVector))
	end
end

local function clearPrompts(p: Player)
	local r = rootOf(p)
	if r then
		for _, pr in r:GetChildren() do
			if pr:IsA("ProximityPrompt") then
				pr:Destroy()
			end
		end
	end
end

local makeGhost -- объявлено ниже

local function down(p: Player)
	local info = state.players[p]
	info.st = "downed"
	info.downAt = os.clock()
	setSpeed(p)
	local r = rootOf(p)
	if not r then
		return
	end
	-- помочь подняться (выжившие) и добить (маньяк)
	local revive = Instance.new("ProximityPrompt")
	revive.Name = "revive"
	revive:SetAttribute("Kind", "revive")
	revive.HoldDuration = 4
	revive.MaxActivationDistance = 8
	revive.RequiresLineOfSight = false
	revive.Parent = r
	revive.Triggered:Connect(function(helper)
		local h = state.players[helper]
		if helper ~= p and h and h.role == "survivor" and Rules.isAlive(h.st) and h.st ~= "downed" and info.st == "downed" then
			info.st = Rules.revive(info.st)
			clearPrompts(p)
			local hum = humOf(p)
			if hum then
				hum.JumpPower = 50
			end
			setSpeed(p)
			sync()
		end
	end)
	local exec = Instance.new("ProximityPrompt")
	exec.Name = "execute"
	exec:SetAttribute("Kind", "execute")
	exec.HoldDuration = 1.5
	exec.MaxActivationDistance = 9
	exec.RequiresLineOfSight = false
	exec.Parent = r
	local function execute(killer)
		if killer == state.maniac and info.st == "downed" and state.players[p] == info then
			clearPrompts(p)
			send(killer, { type = "anim", kind = "execute" })
			-- казнь: жертву поднимает, кровь, крик
			r.Anchored = true
			local up = TweenService:Create(r, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { CFrame = r.CFrame * CFrame.new(0, 2.5, 0) * CFrame.Angles(math.rad(-25), 0, 0) })
			up:Play()
			sound(r, SOUND.scream, 1, 0.8)
			local burst = Instance.new("ParticleEmitter")
			burst.Color = ColorSequence.new(Color3.fromRGB(120, 0, 0))
			burst.Speed = NumberRange.new(8, 14)
			burst.SpreadAngle = Vector2.new(90, 90)
			burst.Acceleration = Vector3.new(0, -40, 0)
			burst.Size = NumberSequence.new(0.35, 0.1)
			burst.Lifetime = NumberRange.new(0.6, 1)
			burst.Rate = 0
			burst.Parent = r
			task.delay(0.8, function()
				burst:Emit(80)
				sound(r, SOUND.slash, 1, 0.7)
				task.wait(0.6)
				makeGhost(p)
			end)
		end
	end
	info.execute = execute
	exec.Triggered:Connect(execute)
	sync()
end

function makeGhost(p: Player)
	local info = state.players[p]
	if not info then
		return
	end
	unhide(p)
	clearPrompts(p)
	if info.st ~= "escaped" then
		info.st = "dead"
	end
	info.ghost = true
	-- призрак ждёт в комнате ожидания, а камера летает над картой
	teleport(p, map.lobby)
	local r = rootOf(p)
	if r then
		r.Anchored = true
	end
	setChat(p, true)
	send(p, { type = "ghost" })
	sync()
end

local function hit(p: Player, attacker: Player)
	local info = state.players[p]
	if not info or info.role ~= "survivor" or not Rules.isAlive(info.st) or info.st == "downed" then
		return
	end
	local new = Rules.hit(info.st)
	local r = rootOf(p)
	sound(r, SOUND.slash, 0.9, 0.9)
	if r then
		local burst = Instance.new("ParticleEmitter")
		burst.Color = ColorSequence.new(Color3.fromRGB(130, 0, 0))
		burst.Speed = NumberRange.new(5, 9)
		burst.SpreadAngle = Vector2.new(50, 50)
		burst.Acceleration = Vector3.new(0, -40, 0)
		burst.Size = NumberSequence.new(0.3, 0.05)
		burst.Lifetime = NumberRange.new(0.5, 0.8)
		burst.Rate = 0
		burst.Parent = r
		burst:Emit(30)
		Debris:AddItem(burst, 2)
	end
	send(p, { type = "fx", kind = "hurt" })
	if new == "downed" then
		down(p)
	else
		info.st = new
		info.hurtAt = os.clock()
		-- рывок раненого: короткое ускорение, чтобы успеть убежать
		local hum = humOf(p)
		if hum then
			hum.WalkSpeed = 24
			task.delay(2, function()
				setSpeed(p)
			end)
		end
		p:SetAttribute("ManiacState", info.st)
		sync()
	end
	local _ = attacker
end

-- ---------------------------------------------------------------------------
-- карта: генераторы, доски, выход, шкафы

local barricadeParts = {}

local function resetMap()
	for _, g in gens do
		g.progress = 0
		g.done = false
		g.lamp.Color = Color3.fromRGB(220, 30, 30)
		local l = g.lamp:FindFirstChildOfClass("PointLight")
		if l then
			l.Color = Color3.fromRGB(255, 60, 60)
		end
		g.body:SetAttribute("Progress", 0)
	end
	for _, b in barricadeParts do
		for _, part in b.parts do
			part.Transparency = part:GetAttribute("BaseT") or 0
			part.CanCollide = part:GetAttribute("BaseC") ~= false
		end
		b.block.CanCollide = true
		local pr = b.block:FindFirstChildOfClass("ProximityPrompt")
		if pr then
			pr.Enabled = true
		end
	end
	map.gate.Transparency = 0.2
	map.gate.CanCollide = true
	state.exitOpen = false
	for p in hiddenIn do
		unhide(p)
	end
end

local function openExit()
	state.exitOpen = true
	map.gate.Transparency = 1
	map.gate.CanCollide = false
	sound(map.gate, SOUND.boards, 1, 0.5)
	announce("ExitOpen")
	sync()
end

-- один ремонт генератора (удержание кнопки или ход бота)
local function repairGen(p, g)
	local info = state.players[p]
	if state.phase ~= "playing" or not g or g.done or not info or info.role ~= "survivor" or info.st == "downed" or not Rules.isAlive(info.st) then
		return
	end
	local body = g.body
	local helpers = 0
	for q, qi in state.players do
		local r = rootOf(q)
		if qi.role == "survivor" and r and (r.Position - body.Position).Magnitude < 9 then
			helpers += 1
		end
	end
	g.progress = Rules.repair(g.progress, helpers)
	body:SetAttribute("Progress", g.progress)
	local sp = body:FindFirstChild("Sparks")
	if sp then
		sp:Emit(20)
	end
	if g.progress >= 100 then
		g.done = true
		g.lamp.Color = Color3.fromRGB(60, 230, 90)
		local l = g.lamp:FindFirstChildOfClass("PointLight")
		if l then
			l.Color = Color3.fromRGB(90, 255, 120)
		end
		sound(body, SOUND.fixed, 1, 0.8)
		announce("GeneratorFixed")
		local done = 0
		for _, gg in gens do
			if gg.done then
				done += 1
			end
		end
		if done >= state.gensTotal and not state.exitOpen then
			openExit()
		end
	end
	sync()
end

local function wireMap()
	local reg = map.prompts
	for _, pr in reg.door or {} do
		pr.Triggered:Connect(function(p)
			if state.players[p] then
				Builder.toggleDoor(pr.Parent)
			end
		end)
	end
	for _, pr in reg.repair or {} do
		local body = pr.Parent
		local g
		for _, gg in gens do
			if gg.body == body then
				g = gg
			end
		end
		pr.Triggered:Connect(function(p)
			repairGen(p, g)
		end)
	end
	for _, pr in reg.barricade or {} do
		local block = pr.Parent
		local parts = {}
		for _, d in block.Parent:GetDescendants() do
			if d:IsA("BasePart") and d ~= block then
				d:SetAttribute("BaseT", d.Transparency)
				d:SetAttribute("BaseC", d.CanCollide)
				table.insert(parts, d)
			end
		end
		table.insert(barricadeParts, { block = block, parts = parts })
		pr.Triggered:Connect(function(p)
			if state.phase ~= "playing" or not state.players[p] then
				return
			end
			pr.Enabled = false
			block.CanCollide = false
			for _, part in parts do
				part.Transparency = 1
				part.CanCollide = false
			end
			sound(block, SOUND.boards, 1, 0.8)
		end)
	end
	for _, pr in reg.hide or {} do
		local part = pr.Parent
		pr.Triggered:Connect(function(p)
			local info = state.players[p]
			if state.phase ~= "playing" or not info then
				return
			end
			if info.role == "maniac" then
				-- маньяк открывает шкаф: спрятавшийся вываливается и падает
				local who = occupied[part]
				if who then
					unhide(who)
					local wi = state.players[who]
					if wi then
						wi.st = "injured"
						hit(who, p)
					end
				end
				return
			end
			if info.st == "downed" or not Rules.isAlive(info.st) then
				return
			end
			if hiddenIn[p] then
				unhide(p)
				return
			end
			if occupied[part] then
				return
			end
			hiddenIn[p] = part
			occupied[part] = p
			p.Character:PivotTo(part.CFrame * CFrame.new(0, -part.Size.Y / 2 + 3, 0))
			local r = rootOf(p)
			if r then
				r.Anchored = true
			end
			p:SetAttribute("HiddenEye", part.CFrame * CFrame.new(0, 1.2, -part.Size.Z / 2 + 0.3))
		end)
	end
end

-- ---------------------------------------------------------------------------
-- раунд

local function startRound()
	local list = {}
	for p in state.players do
		table.insert(list, p)
	end
	if #list < Rules.MIN_PLAYERS then
		state.phase = "lobby"
		sync()
		return
	end
	-- бот, созданный «маньяком», всегда маньяк; боты-выжившие маньяком не становятся
	local maniac = nil
	local candidates = {}
	for _, p in list do
		local b = p :: any
		if b.isBot and b.prefer == "maniac" and not maniac then
			maniac = p
		elseif not (b.isBot and b.prefer == "survivor") then
			table.insert(candidates, p)
		end
	end
	if not maniac then
		maniac = Rules.pickManiac(if #candidates > 0 then candidates else list, function(a, b)
			return math.random(a, b)
		end)
	end
	state.maniac = maniac
	state.winner = nil
	table.clear(state.lastAbility)
	for p, info in state.players do
		info.role = if p == maniac then "maniac" else "survivor"
		info.st = "healthy"
		info.ghost = false
		info.downAt = nil
	end
	state.gensTotal = math.min(#gens, Rules.generatorsFor(#list - 1))
	resetMap()
	-- генераторы сверх нужного числа считаются починенными заранее
	for i, g in gens do
		if i > state.gensTotal then
			g.done = true
			g.progress = 100
			g.lamp.Color = Color3.fromRGB(60, 230, 90)
		end
	end
	state.phase = "playing"
	state.endsAt = workspace:GetServerTimeNow() + Rules.ROUND_TIME
	local k = 0
	for p, info in state.players do
		setChat(p, true)
		if info.role == "survivor" then
			k += 1
			p:LoadCharacter()
			task.wait()
			teleport(p, map.survivorSpawns[(k - 1) % #map.survivorSpawns + 1])
			setSpeed(p)
			send(p, { type = "intro", role = "survivor" })
		end
	end
	if maniac then
		maniac:LoadCharacter()
		task.wait(0.2)
		teleport(maniac, map.lobby)
		dressManiac(maniac)
		send(maniac, { type = "intro", role = "maniac" })
		task.delay(Rules.MANIAC_DELAY, function()
			if state.phase == "playing" and state.maniac == maniac and maniac.Parent then
				teleport(maniac, map.maniacSpawn)
				announce("ManiacComing")
			end
		end)
	end
	sync()
end

local function endRound(winner: string)
	if state.phase ~= "playing" then
		return
	end
	state.phase = "results"
	state.winner = winner
	state.endsAt = workspace:GetServerTimeNow() + Rules.RESULTS_TIME
	announce(if winner == "maniac" then "ManiacWins" else "SurvivorsWin")
	sync()
	task.delay(Rules.RESULTS_TIME, function()
		state.phase = "lobby"
		state.maniac = nil
		for p, info in state.players do
			info.role = nil
			info.st = nil
			info.ghost = false
			hiddenIn[p] = nil
			p:SetAttribute("ManiacState", nil)
			p:SetAttribute("HiddenEye", nil)
			if p.Parent then
				p:LoadCharacter()
				task.wait()
				teleport(p, map.lobby)
			end
		end
		table.clear(occupied)
		sync()
	end)
end

-- ---------------------------------------------------------------------------
-- способности маньяка

local function ability(p: Player, name: string)
	if state.phase ~= "playing" or p ~= state.maniac then
		return { ok = false }
	end
	local now = os.clock()
	local ok, left = Rules.ready(name, state.lastAbility[name], now)
	if not ok then
		return { ok = false, left = left }
	end
	local root = rootOf(p)
	if not root then
		return { ok = false }
	end
	state.lastAbility[name] = now
	local a = Rules.ABILITIES[name]
	if name == "attack" then
		local look = root.CFrame.LookVector
		for _, q in survivors() do
			local r = rootOf(q)
			local info = state.players[q]
			if r and not hiddenIn[q] and info.st ~= "downed" and Rules.isAlive(info.st) then
				local off = r.Position - root.Position
				if off.Magnitude < a.range and (off.Magnitude < 2.5 or off.Unit:Dot(look) > 0.3) then
					hit(q, p)
					break
				end
			end
		end
	elseif name == "scream" then
		sound(root, SOUND.scream, 1.2, 0.45)
		for _, q in survivors() do
			local r = rootOf(q)
			if r and (r.Position - root.Position).Magnitude < a.range then
				send(q, { type = "fx", kind = "scare" })
				local hum = humOf(q)
				if hum and state.players[q].st ~= "downed" then
					hum.WalkSpeed = Rules.SPEED.scared
					task.delay(a.duration, function()
						setSpeed(q)
					end)
				end
			end
		end
	elseif name == "blind" then
		for _, q in survivors() do
			local r = rootOf(q)
			if r and (r.Position - root.Position).Magnitude < a.range then
				send(q, { type = "fx", kind = "blind", duration = a.duration })
			end
		end
	elseif name == "dash" then
		local hum = humOf(p)
		if hum then
			hum.WalkSpeed = Rules.SPEED.dash
			task.delay(a.duration, function()
				if hum.Parent then
					hum.WalkSpeed = Rules.SPEED.maniac
				end
			end)
		end
	elseif name == "sense" then
		local ids, chars = {}, {}
		for _, q in survivors() do
			if Rules.isAlive(state.players[q].st) then
				table.insert(ids, q.UserId)
				if q.Character then
					table.insert(chars, q.Character)
				end
			end
		end
		send(p, { type = "sense", ids = ids, chars = chars, duration = a.duration })
	end
	return { ok = true }
end

-- ---------------------------------------------------------------------------
-- Боты для проверки режима одним игроком (создаёт админ). Бот притворяется игроком:
-- у него есть Character, DisplayName, UserId (отрицательный) и LoadCharacter

local bots = {}
local botSerial = 0
local Bot = {}
Bot.__index = Bot

function Bot:SetAttribute(k, v)
	self.attrs[k] = v
end
function Bot:GetAttribute(k)
	return self.attrs[k]
end
function Bot:RequestStreamAroundAsync() end

local function botDied(bot)
	local i = state.players[bot]
	if i and state.phase == "playing" and i.role == "survivor" and Rules.isAlive(i.st) then
		i.st = "dead"
		i.ghost = true
		unhide(bot)
		sync()
	end
	task.delay(3, function()
		if state.players[bot] and bot.Parent then
			bot:LoadCharacter()
			teleport(bot, map.lobby)
			if state.phase == "playing" then
				local r = rootOf(bot)
				if r then
					r.Anchored = true
				end
			end
		end
	end)
end

function Bot:LoadCharacter()
	if self.Character then
		self.Character:Destroy()
		self.Character = nil
	end
	local desc = Instance.new("HumanoidDescription")
	local skin = ({ Color3.fromRGB(234, 184, 146), Color3.fromRGB(204, 142, 105), Color3.fromRGB(160, 110, 80) })[(self.serial % 3) + 1]
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = ({ Color3.fromRGB(70, 90, 130), Color3.fromRGB(120, 60, 50), Color3.fromRGB(70, 110, 70), Color3.fromRGB(110, 100, 60) })[(self.serial % 4) + 1]
	desc.LeftLegColor = Color3.fromRGB(50, 46, 44)
	desc.RightLegColor = Color3.fromRGB(50, 46, 44)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		return
	end
	model.Name = self.Name
	for _, d in model:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayName = self.DisplayName
	hum.WalkSpeed = Rules.SPEED.survivor
	model:PivotTo(map.lobby)
	model.Parent = map.map
	local r = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if r then
		pcall(function()
			r:SetNetworkOwner(nil)
		end)
	end
	self.Character = model
	self.nav = Npc.animate(hum)
	self.nav.model = model
	self.nav.pathAt = 0
	self.nav.wp = 1
	self.lastPos = nil
	self.stuckAt = os.clock()
	hum.Died:Connect(function()
		if self.Character == model then
			botDied(self)
		end
	end)
end

function M.addBot(prefer: string): boolean
	if #bots >= 8 then
		return false
	end
	botSerial += 1
	local bot = setmetatable({
		isBot = true,
		prefer = prefer,
		serial = botSerial,
		Name = "Bot" .. botSerial,
		DisplayName = (if prefer == "maniac" then "Bot-Maniac " else "Bot ") .. botSerial,
		UserId = -botSerial,
		Parent = workspace,
		attrs = {},
	}, Bot)
	table.insert(bots, bot)
	state.players[bot :: any] = { role = nil, st = nil, ghost = state.phase == "playing" }
	bot:LoadCharacter()
	teleport(bot :: any, map.lobby)
	if state.phase == "playing" then
		state.players[bot :: any].role = "spectator"
		local r = rootOf(bot :: any)
		if r then
			r.Anchored = true
		end
	end
	sync()
	return true
end

function M.clearBots()
	for _, bot in table.clone(bots) do
		bot.Parent = nil
		M.leave(bot :: any)
		if bot.Character then
			bot.Character:Destroy()
			bot.Character = nil
		end
	end
	table.clear(bots)
	sync()
end

-- админ: начать раунд сразу, без ожидания
function M.startNow(): boolean
	local n = 0
	for _ in state.players do
		n += 1
	end
	if n < Rules.MIN_PLAYERS or (state.phase ~= "lobby" and state.phase ~= "countdown") then
		return false
	end
	state.phase = "countdown"
	state.endsAt = workspace:GetServerTimeNow()
	return true
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function botGo(bot, goal: Vector3)
	Npc.goTo(bot.nav, goal)
end

local function botStop(bot, root: BasePart)
	bot.nav.path = nil
	bot.nav.hum:MoveTo(root.Position)
end

local function survivorBot(bot, info, root: BasePart, hum: Humanoid)
	if info.st == "downed" or hiddenIn[bot] then
		botStop(bot, root)
		return
	end
	-- бегство от маньяка
	local mr = state.maniac and rootOf(state.maniac)
	if mr and (mr.Position - map.lobby.Position).Magnitude > 40 then
		local off = flat(root.Position - mr.Position)
		if off.Magnitude < 26 then
			local away = if off.Magnitude > 0.1 then off.Unit else Vector3.xAxis
			botGo(bot, root.Position + away * 24)
			return
		end
	end
	-- выход открыт: к воротам
	if state.exitOpen then
		botGo(bot, Vector3.new(map.exitX, root.Position.Y, map.exitZ - 8))
		return
	end
	-- ближайший неисправный генератор
	local best, bestD = nil, math.huge
	for _, g in gens do
		if not g.done then
			local d = (g.body.Position - root.Position).Magnitude
			if d < bestD then
				best, bestD = g, d
			end
		end
	end
	if not best then
		botStop(bot, root)
		return
	end
	if bestD > 6.5 then
		botGo(bot, best.body.Position)
	else
		botStop(bot, root)
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(best.body.Position.X, root.Position.Y, best.body.Position.Z))
		if os.clock() - (bot.lastRepair or 0) > 3 then
			bot.lastRepair = os.clock()
			repairGen(bot, best)
		end
	end
	local _ = hum
end

local function maniacBot(bot, info, root: BasePart, hum: Humanoid)
	-- ждёт в комнате ожидания, пока его не выпустят
	if (root.Position - map.lobby.Position).Magnitude < 40 then
		return
	end
	local target, targetD = nil, math.huge
	for _, q in survivors() do
		local qi = state.players[q]
		local r = rootOf(q)
		if r and Rules.isAlive(qi.st) and not hiddenIn[q] then
			local d = (r.Position - root.Position).Magnitude
			-- лежачего добивает
			if qi.st == "downed" then
				if d < 7 and qi.execute then
					botStop(bot, root)
					qi.execute(bot)
					return
				end
				d += 30
			end
			if d < targetD then
				target, targetD = q, d
			end
		end
	end
	if target then
		local tr = rootOf(target) :: BasePart
		if targetD < 6 then
			root.CFrame = CFrame.lookAt(root.Position, Vector3.new(tr.Position.X, root.Position.Y, tr.Position.Z))
			ability(bot, "attack")
		elseif targetD < 40 and math.random() < 0.05 then
			ability(bot, "dash")
		elseif targetD < 22 and math.random() < 0.03 then
			ability(bot, "scream")
		end
		botGo(bot, tr.Position)
	else
		-- бродит между генераторами
		if not bot.wander or os.clock() - (bot.wanderAt or 0) > 12 then
			bot.wanderAt = os.clock()
			local g = gens[math.random(1, math.max(1, #gens))]
			bot.wander = g and g.body.Position or map.maniacSpawn.Position
		end
		botGo(bot, bot.wander)
	end
	local _ = info
	local __ = hum
end

local function botStep(bot)
	local info = state.players[bot]
	local char = bot.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not info or not hum or not root or hum.Health <= 0 or root.Anchored then
		return
	end
	if state.phase ~= "playing" or info.ghost or not Rules.isAlive(info.st or "healthy") and info.role == "survivor" then
		return
	end
	Builder.openDoorsNear(root.Position, 7)
	-- застрял: прыжок и новый путь
	if bot.lastPos and (bot.lastPos - root.Position).Magnitude < 0.6 and hum.MoveDirection.Magnitude > 0 then
		if os.clock() - bot.stuckAt > 1.5 then
			hum.Jump = true
			bot.nav.path = nil
			bot.stuckAt = os.clock()
		end
	else
		bot.stuckAt = os.clock()
	end
	bot.lastPos = root.Position
	if info.role == "maniac" then
		maniacBot(bot, info, root, hum)
	elseif info.role == "survivor" then
		survivorBot(bot, info, root, hum)
	end
end

-- ---------------------------------------------------------------------------
-- вход и выход из режима

function M.join(p: Player)
	if state.players[p] then
		return { ok = true }
	end
	local n = 0
	for _ in state.players do
		n += 1
	end
	if n >= Rules.MAX_PLAYERS then
		return { ok = false, error = "full" }
	end
	if hooks.beforeJoin then
		hooks.beforeJoin(p)
	end
	-- во время раунда новичок ждёт в комнате ожидания как призрак
	state.players[p] = { role = nil, st = nil, ghost = state.phase == "playing" }
	setChat(p, true)
	if not p.Character then
		p:LoadCharacter()
	end
	teleport(p, map.lobby)
	if state.phase == "playing" then
		state.players[p].role = "spectator"
		send(p, { type = "ghost" })
	end
	sync()
	return { ok = true }
end

function M.leave(p: Player)
	local info = state.players[p]
	if not info then
		return
	end
	unhide(p)
	clearPrompts(p)
	state.players[p] = nil
	setChat(p, false)
	p:SetAttribute("ManiacState", nil)
	if state.phase == "playing" then
		if p == state.maniac then
			endRound("survivors")
		end
	end
	if info.role == "maniac" and p.Parent then
		p:LoadCharacter()
	end
	if hooks.afterLeave and p.Parent then
		hooks.afterLeave(p)
	end
	sync()
end

function M.inGame(p: Player): boolean
	return state.players[p] ~= nil
end

function M.init(h)
	hooks = h or {}
	event = Remotes.event("Maniac")
	pcall(function()
		PhysicsService:RegisterCollisionGroup("ManiacBlock")
		PhysicsService:RegisterCollisionGroup("ManiacChar")
		PhysicsService:CollisionGroupSetCollidable("ManiacBlock", "Default", false)
		PhysicsService:CollisionGroupSetCollidable("ManiacBlock", "ManiacChar", true)
	end)
	map = Builder.buildManiac(OFFSET)
	for _, g in map.generators do
		table.insert(gens, { body = g.body, lamp = g.lamp, progress = 0, done = false })
	end
	wireMap()

	Remotes.fn("ManiacRequest").OnServerInvoke = function(p: Player, action: any, arg: any)
		if action == "Join" then
			return M.join(p)
		elseif action == "Leave" then
			M.leave(p)
			return { ok = true }
		elseif action == "Ability" and type(arg) == "string" then
			return ability(p, arg)
		elseif action == "Status" then
			sync()
			return { ok = true }
		end
		return { ok = false }
	end

	Players.PlayerRemoving:Connect(M.leave)

	-- поведение ботов
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, bot in table.clone(bots) do
				local ok, err = pcall(botStep, bot)
				if not ok then
					warn("[Maniac] bot: " .. tostring(err))
				end
			end
		end
	end)

	-- смерть и новое появление участника режима
	local function onCharacter(p: Player, char: Model)
		local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
		task.wait(0.25)
		local info = state.players[p]
		if not info then
			return
		end
		if hum then
			hum.Died:Connect(function()
				local i = state.players[p]
				if i and state.phase == "playing" and i.role == "survivor" and Rules.isAlive(i.st) then
					i.st = "dead"
					i.ghost = true
					unhide(p)
					sync()
				end
			end)
		end
		if state.phase == "playing" then
			if info.ghost then
				teleport(p, map.lobby)
				local r = rootOf(p)
				if r then
					r.Anchored = true
				end
				send(p, { type = "ghost" })
			elseif info.role == "maniac" and char:FindFirstChild("ManiacCostume") == nil then
				dressManiac(p)
			end
		elseif state.phase ~= "playing" then
			teleport(p, map.lobby)
		end
	end
	local function hook(p: Player)
		p.CharacterAdded:Connect(function(char)
			onCharacter(p, char)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end

	-- новые части тела маньяка (например, после смены одежды) тоже в его группе
	task.spawn(function()
		while true do
			task.wait(1)
			local now = workspace:GetServerTimeNow()
			local count = 0
			for _ in state.players do
				count += 1
			end
			if state.phase == "lobby" then
				if count >= Rules.MIN_PLAYERS then
					state.phase = "countdown"
					state.endsAt = now + Rules.LOBBY_COUNTDOWN
					sync()
				end
			elseif state.phase == "countdown" then
				if count < Rules.MIN_PLAYERS then
					state.phase = "lobby"
					sync()
				elseif now >= state.endsAt then
					task.spawn(startRound)
				end
			elseif state.phase == "playing" then
				local states = {}
				for p, info in state.players do
					if info.role == "survivor" then
						states[p] = info.st
						-- истёк срок лежачего
						if info.st == "downed" and info.downAt and os.clock() - info.downAt > Rules.BLEED_OUT then
							makeGhost(p)
						end
						-- побег через открытые ворота
						local r = rootOf(p)
						if state.exitOpen and r and Rules.isAlive(info.st) and info.st ~= "downed" and r.Position.Z < map.exitZ and math.abs(r.Position.X - map.exitX) < 16 then
							info.st = "escaped"
							makeGhost(p)
						end
						-- след крови за раненым
						if info.st == "injured" and r and math.random() < 0.5 then
							local drop = Instance.new("Part")
							drop.Anchored = true
							drop.CanCollide = false
							drop.CanQuery = false
							drop.Shape = Enum.PartType.Cylinder
							drop.Size = Vector3.new(0.04, 0.8, 0.8)
							drop.Color = Color3.fromRGB(110, 0, 0)
							drop.Material = MAT.SmoothPlastic
							drop.CFrame = CFrame.new(r.Position - Vector3.new(0, 2.95, 0)) * CFrame.Angles(0, 0, math.pi / 2)
							drop.Parent = map.map
							Debris:AddItem(drop, 25)
						end
						-- упавший в пустоту — погиб
						if r and r.Position.Y < -60 and Rules.isAlive(info.st) then
							makeGhost(p)
						end
					end
				end
				local w = Rules.winner(states, now >= state.endsAt)
				if w then
					endRound(w)
				end
			end
		end
	end)
end

return M
