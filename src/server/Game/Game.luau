--!nonstrict
-- Забег по лабиринту: комнаты строятся впереди и убираются позади, двери с номерами,
-- ключи (только для своей двери), отмычки, Сборщик платы, предметы, фонарик, шкафы,
-- рабочий лифт между секторами, зал Слепого, смерть и наблюдение, рекорды

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Rules = require(Shared.Rules)
local Plan = require(Shared.RoomPlan)
local Remotes = require(Shared.Roblox.Remotes)
local M = require(Shared.Materials)

local Props = require(script.Parent.Parent.World.Props)
local Builder = require(script.Parent.Parent.World.RoomBuilder)
local Special = require(script.Parent.Parent.World.Special)
local Entities = require(script.Parent.Entities)
local Records = require(script.Parent.Records)

local G = {}

local event: RemoteEvent
local world: Folder

local KEEP_BEHIND = 3 -- сколько открытых комнат остаётся позади

local run = {
	active = false,
	seed = 0,
	plan = nil,
	descs = {} :: { [number]: any },
	rooms = {} :: { [number]: any },
	front = 0, -- номер последней открытой двери
	sector = 1,
	ending = false,
}
G.run = run

-- состояние игроков: alive, coins, inv, keys, flash, flashOn, sneaking, hidden, god
local players: { [Player]: any } = {}
G.players = players
local occupied: { [BasePart]: Player } = {}

-- ---------------------------------------------------------------------------
-- общее

function G.rootOf(p: Player): BasePart?
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end
local rootOf = G.rootOf

local function humOf(p: Player): Humanoid?
	return p.Character and p.Character:FindFirstChildOfClass("Humanoid")
end
G.humOf = humOf

function G.send(p: Player, msg)
	if p.Parent then
		event:FireClient(p, msg)
	end
end
local send = G.send

function G.sendAll(msg)
	event:FireAllClients(msg)
end

local function toast(p: Player, key: string, ...)
	send(p, { type = "toast", key = key, args = { ... } })
end
G.toast = toast

local function announce(key: string, ...)
	G.sendAll({ type = "announce", key = key, args = { ... } })
end
G.announce = announce

function G.isAlive(p: Player): boolean
	local s = players[p]
	return s ~= nil and s.alive
end

function G.isHidden(p: Player): boolean
	local s = players[p]
	return s ~= nil and s.hidden ~= nil
end

function G.isSneaking(p: Player): boolean
	local s = players[p]
	return s ~= nil and s.sneaking == true
end

function G.alivePlayers(): { Player }
	local list = {}
	for p, s in players do
		if s.alive and p.Parent then
			table.insert(list, p)
		end
	end
	return list
end

function G.inRoom(info, pos: Vector3): boolean
	return Builder.contains(info, pos)
end

-- загруженные комнаты от старой к новой (без стартовой), до последней открытой
function G.loadedRooms()
	local list = {}
	for n = math.max(1, run.front - KEEP_BEHIND), run.front do
		local info = run.rooms[n]
		if info and not info.boss and not info.elevator then
			table.insert(list, info)
		end
	end
	return list
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
	pcall(function()
		p:RequestStreamAroundAsync(cf.Position, 3)
	end)
	char:PivotTo(cf)
end
G.teleport = teleport

local function syncInv(p: Player)
	local s = players[p]
	if not s then
		return
	end
	local n = 0
	for _ in s.keys do
		n += 1
	end
	s.inv.key = if n > 0 then n else nil
	p:SetAttribute("Coins", s.coins)
	send(p, { type = "inv", coins = s.coins, inv = s.inv })
end
G.syncInv = syncInv

local function sound(at: Instance?, id: string, vol: number, speed: number?)
	if at then
		Entities.sound(at, id, vol, speed)
	end
end

local SOUND = {
	door = "rbxasset://sounds/swoosh.wav",
	locked = "rbxasset://sounds/clickfast.wav",
	pick = "rbxasset://sounds/electronicpingshort.wav",
	coin = "rbxasset://sounds/electronicpingshort.wav",
	hit = "rbxasset://sounds/collide.wav",
	gate = "rbxasset://sounds/collide.wav",
}

-- ---------------------------------------------------------------------------
-- урон и смерть

function G.damage(p: Player, amount: number, cause: string?)
	local s = players[p]
	local hum = humOf(p)
	if not s or not s.alive or not hum or s.god then
		return
	end
	s.cause = cause
	hum:TakeDamage(amount)
end

function G.kill(p: Player, cause: string?)
	local s = players[p]
	local hum = humOf(p)
	if not s or not s.alive or not hum or s.god then
		return
	end
	s.cause = cause
	hum.Health = 0
end

local endRun -- объявлено ниже

local function onDied(p: Player)
	local s = players[p]
	if not s or not s.alive then
		return
	end
	s.alive = false
	p:SetAttribute("Alive", false)
	local part = s.hidden
	if part then
		occupied[part] = nil
		s.hidden = nil
	end
	send(p, { type = "dead", cause = s.cause or "unknown", door = run.front })
	announce("PlayerDied", p.DisplayName, run.front)
	if #G.alivePlayers() == 0 and run.active then
		task.spawn(endRun)
	end
end

-- ---------------------------------------------------------------------------
-- фонарик

local function flashlight(p: Player)
	local char = p.Character
	local head = char and char:FindFirstChild("Head")
	if not head then
		return nil
	end
	local l = head:FindFirstChild("Flashlight") :: SpotLight?
	if not l then
		local nl = Instance.new("SpotLight")
		nl.Name = "Flashlight"
		nl.Range = 48
		nl.Angle = 55
		nl.Brightness = 3.2
		nl.Color = Color3.fromRGB(255, 244, 220)
		nl.Shadows = true
		nl.Face = Enum.NormalId.Front
		nl.Enabled = false
		nl.Parent = head
		l = nl
	end
	return l
end

local function setFlash(p: Player, on: boolean)
	local s = players[p]
	if not s then
		return
	end
	s.flashOn = on and s.flash > 0 and s.alive
	local l = flashlight(p)
	if l then
		l.Enabled = s.flashOn
	end
	p:SetAttribute("FlashOn", s.flashOn)
	p:SetAttribute("Flash", math.ceil(s.flash))
end
G.setFlash = setFlash

-- ---------------------------------------------------------------------------
-- шкафы

local function unhide(p: Player)
	local s = players[p]
	local part = s and s.hidden
	if not part then
		return
	end
	s.hidden = nil
	occupied[part] = nil
	p:SetAttribute("HiddenEye", nil)
	local r = rootOf(p)
	if r then
		r.Anchored = false
		local out = part.CFrame * CFrame.new(0, -part.Size.Y / 2 + 3, -(part.Size.Z / 2 + 2.5))
		p.Character:PivotTo(CFrame.lookAt(out.Position, out.Position + part.CFrame.LookVector))
	end
end
G.unhide = unhide

local function hide(p: Player, part: BasePart)
	local s = players[p]
	if not s or not s.alive then
		return
	end
	if s.hidden == part then
		unhide(p)
		return
	end
	if s.hidden or occupied[part] then
		toast(p, "ClosetTaken")
		return
	end
	s.hidden = part
	occupied[part] = p
	local r = rootOf(p)
	if r then
		p.Character:PivotTo(part.CFrame * CFrame.new(0, -part.Size.Y / 2 + 3, 0))
		r.Anchored = true
	end
	-- камера смотрит сквозь щель между дверцами
	p:SetAttribute("HiddenEye", part.CFrame * CFrame.new(0, 1.6, -part.Size.Z / 2 + 0.25))
end

-- ---------------------------------------------------------------------------
-- предметы

local ITEM_SOUND = SOUND.pick

local function give(p: Player, item: string, amount: number?): boolean
	local s = players[p]
	if not s then
		return false
	end
	if item == "coins" then
		s.coins += amount or 1
		sound(rootOf(p), SOUND.coin, 0.6, 1.5)
		syncInv(p)
		return true
	end
	if not Rules.add(s.inv, item) then
		toast(p, "BagFull")
		return false
	end
	sound(rootOf(p), ITEM_SOUND, 0.6)
	syncInv(p)
	return true
end
G.give = give

function G.use(p: Player, item: string)
	local s = players[p]
	if not s or not s.alive then
		return { ok = false }
	end
	if item == "plant" then
		local hum = humOf(p)
		if not hum or hum.Health >= hum.MaxHealth then
			toast(p, "HealthFull")
			return { ok = false }
		end
		if Rules.take(s.inv, "plant") then
			hum.Health = math.min(hum.MaxHealth, hum.Health + Rules.PLANT_HEAL)
			toast(p, "Healed")
		end
	elseif item == "battery" then
		if s.flash >= Rules.FLASH_MAX - 1 then
			toast(p, "FlashFull")
			return { ok = false }
		end
		if Rules.take(s.inv, "battery") then
			s.flash = Rules.recharge(s.flash)
			setFlash(p, s.flashOn)
			toast(p, "Recharged")
		end
	elseif item == "whistle" then
		if (s.inv.whistle or 0) <= 0 then
			return { ok = false }
		end
		local now = os.clock()
		if now - (s.whistleAt or 0) < 8 then
			toast(p, "WhistleWait")
			return { ok = false }
		end
		s.whistleAt = now
		Entities.whistle(p)
	else
		return { ok = false }
	end
	syncInv(p)
	return { ok = true }
end

-- ---------------------------------------------------------------------------
-- комнаты

local function descOf(n: number)
	while #run.descs < n or run.descs[0] == nil do
		local k = if run.descs[0] == nil then 0 else #run.descs + 1
		run.descs[k] = Plan.room(run.plan, k)
	end
	return run.descs[n]
end

local openDoor -- объявлено ниже

local function wireDoor(info, n: number, cf: CFrame, locked: boolean)
	-- у зала Слепого дверь стоит в кабине лифта (зал убирается во время поездки)
	local holder = info.next or info
	local m, leaf, pr = Props.door(holder.model, cf, n, locked)
	info.door = { model = m, leaf = leaf, prompt = pr, number = n, locked = locked, opened = false }
	pr.Triggered:Connect(function(p)
		G.tryOpen(p, n)
	end)
end

-- ключ кладётся на стол или комод этой же комнаты
local function placeKey(info, n: number, rand)
	local spots = info.tops
	local cf
	if #spots > 0 then
		cf = spots[math.floor(rand() * #spots) + 1]
	else
		cf = info.center * CFrame.new(0, -info.size.Y / 2, 0)
	end
	local _, part = Props.pickup(info.model, cf, "key")
	part:SetAttribute("KeyFor", n)
end

-- монеты и батарейки на виду (немного)
local function placeLoot(info, rand)
	for _, cf in info.tops do
		if rand() < 0.35 then
			local r = rand()
			local item = if r < 0.6 then "coins" elseif r < 0.85 then "battery" else "plant"
			local _, part = Props.pickup(info.model, cf, item)
			if item == "coins" then
				part:SetAttribute("Amount", 1 + math.floor(rand() * 4))
			end
		end
	end
end

local function buildRoom(n: number)
	if run.rooms[n] then
		return run.rooms[n]
	end
	local d = descOf(n)
	local origin
	if n == 0 then
		origin = CFrame.new(0, 0, 0)
	else
		local prev = run.rooms[n - 1] or buildRoom(n - 1)
		origin = prev.doorCF
	end
	local info
	local rand = Plan.rng(run.seed + n * 7919)
	if d.kind == "boss" then
		info = Special.boss(world, d, origin, rand)
		local ed = table.clone(d)
		ed.kind = "elevator"
		ed.w, ed.l, ed.h = Plan.SIZES.elevator.w, Plan.SIZES.elevator.l, Plan.HEIGHT.elevator
		ed.turn = 0
		info.next = Special.elevator(world, ed, info.exitCF)
		info.doorCF = info.next.exitCF
		info.elevatorInfo = info.next
	elseif d.kind == "elevator" then
		info = Special.elevator(world, d, origin)
		info.doorCF = info.exitCF
		info.elevatorInfo = info
	else
		info = Builder.build(world, d, origin)
		info.doorCF = info.exitCF
	end
	info.n = n
	run.rooms[n] = info
	-- выходная дверь с номером
	wireDoor(info, n + 1, info.doorCF, d.locked == true)
	if d.locked then
		placeKey(info, n + 1, rand)
	end
	if not info.boss and not info.elevator and n > 0 then
		placeLoot(info, rand)
	end
	if d.toll then
		local price = Rules.tollPrice(n + 1)
		local keeper, pc, pb = Special.tollKeeper(info.model, info.doorCF * CFrame.new(0, 0, 2.8) * CFrame.Angles(0, math.pi, 0), price)
		info.toll = { model = keeper, price = price, paid = false }
		pc.Triggered:Connect(function(p)
			G.payToll(p, info, "coins")
		end)
		pb.Triggered:Connect(function(p)
			G.payToll(p, info, "blood")
		end)
	end
	if d.watcher then
		Entities.spawnWatcher(info)
	end
	-- кнопки мебели и предметов этой комнаты
	G.wireRoom(info)
	if info.next then
		G.wireRoom(info.next)
	end
	return info
end
G.buildRoom = buildRoom

local function destroyRoom(n: number)
	local info = run.rooms[n]
	if not info then
		return
	end
	Entities.removeRoom(info)
	for part, p in occupied do
		if part:IsDescendantOf(info.model) then
			unhide(p)
		end
	end
	info.model:Destroy()
	if info.next then
		info.next.model:Destroy()
	end
	run.rooms[n] = nil
end

-- игроки, отставшие в убираемой комнате, переносятся вперёд
local function cleanup()
	local keepFrom = run.front - KEEP_BEHIND
	for n, info in run.rooms do
		if n > 0 and n < keepFrom then
			local target = run.rooms[keepFrom]
			if target then
				for _, p in G.alivePlayers() do
					local r = rootOf(p)
					if r and Builder.contains(info, r.Position) then
						teleport(p, target.origin * CFrame.new(0, 3, -3))
					end
				end
			end
			destroyRoom(n)
		end
	end
end

-- створка поворачивается на петлях
local function swing(door)
	local leaf = door.leaf
	local base = leaf:GetPivot()
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(a)
		leaf:PivotTo(base * CFrame.Angles(0, math.rad(-95) * a, 0))
	end)
	local t = TweenService:Create(v, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1 })
	t:Play()
	t.Completed:Connect(function()
		v:Destroy()
	end)
	for _, d in leaf:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	sound(door.leaf:FindFirstChild("Slab"), SOUND.door, 0.8, 0.6)
end

-- открыть дверь n (force — без проверок, для админа и лифта)
function openDoor(n: number, force: boolean?)
	local info = run.rooms[n - 1]
	if not info or not info.door or info.door.opened then
		return false
	end
	local door = info.door
	door.opened = true
	door.prompt.Enabled = false
	local lock = door.model:FindFirstChild("Padlock")
	if lock then
		lock:Destroy()
	end
	swing(door)
	run.front = math.max(run.front, n)
	run.sector = Rules.sectorOf(n)
	workspace:SetAttribute("Door", run.front)
	workspace:SetAttribute("Sector", run.sector)
	-- ключи от этой двери больше не нужны и не уносятся дальше
	for _, s in players do
		s.keys[n] = nil
	end
	for p, s in players do
		if s.alive then
			if Records.offer(p, n) then
				local ls = p:FindFirstChild("leaderstats")
				local b = ls and ls:FindFirstChild("Best")
				if b then
					(b :: IntValue).Value = n
				end
			end
			-- немного монет за каждую дверь
			s.coins += 1
			syncInv(p)
		end
	end
	local entered = buildRoom(n)
	buildRoom(n + 1)
	cleanup()
	Entities.noise(door.model:GetPivot().Position, Rules.NOISE.door)
	if entered.boss then
		Entities.startBlind(entered)
		announce("BossHall")
	end
	if entered.desc.hum and not force then
		task.delay(1.5 + math.random() * 3, function()
			if run.active and run.front >= n then
				Entities.hum()
			end
		end)
	end
	if Rules.isSectorEnd(n) then
		announce("SectorEnd", run.sector)
	end
	return true
end
G.openDoor = openDoor

function G.tryOpen(p: Player, n: number)
	local s = players[p]
	if not s or not s.alive or s.hidden then
		return
	end
	local info = run.rooms[n - 1]
	if not info or not info.door then
		return
	end
	if info.toll and not info.toll.paid then
		toast(p, "TollBlocks", info.toll.price)
		return
	end
	if info.elevatorInfo and not info.elevatorInfo.rideDone then
		toast(p, "RideFirst")
		return
	end
	if info.door.locked then
		if s.keys[n] then
			s.keys[n] = nil
			toast(p, "Unlocked")
		elseif Rules.take(s.inv, "lockpick") then
			toast(p, "Picked")
		else
			sound(info.door.model:FindFirstChild("Trigger"), SOUND.locked, 0.8)
			toast(p, "Locked")
			return
		end
		syncInv(p)
	end
	openDoor(n)
end

-- ---------------------------------------------------------------------------
-- Сборщик платы

function G.payToll(p: Player, info, how: string)
	local s = players[p]
	local t = info.toll
	if not s or not s.alive or not t or t.paid then
		return
	end
	if how == "coins" then
		if s.coins < t.price then
			toast(p, "NotEnoughCoins", t.price)
			return
		end
		s.coins -= t.price
		toast(p, "PaidCoins", t.price)
	else
		local hum = humOf(p)
		if not hum then
			return
		end
		hum.Health = Rules.afterBloodToll(hum.Health)
		send(p, { type = "fx", kind = "blood" })
		toast(p, "PaidBlood")
	end
	t.paid = true
	syncInv(p)
	-- сборщик растворяется
	for _, d in t.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			TweenService:Create(d, TweenInfo.new(1.2), { Transparency = 1 }):Play()
		elseif d:IsA("ProximityPrompt") then
			d.Enabled = false
		elseif d:IsA("PointLight") then
			d.Enabled = false
		end
	end
	task.delay(1.4, function()
		t.model:Destroy()
	end)
end

-- ---------------------------------------------------------------------------
-- кнопки мебели и предметов в комнате

local function bossOf(part: Instance)
	for _, info in run.rooms do
		if info.boss and part:IsDescendantOf(info.model) then
			return info
		end
	end
	return nil
end

local function openBigGate(info)
	if info.gateOpen then
		return
	end
	info.gateOpen = true
	announce("GateOpen")
	local gate = info.bigGate
	local base = info.bigGateHome
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(a)
		gate:PivotTo(base * CFrame.new(0, 15 * a, 0))
	end)
	local t = TweenService:Create(v, TweenInfo.new(4, Enum.EasingStyle.Sine), { Value = 1 })
	t:Play()
	t.Completed:Connect(function()
		v:Destroy()
		for _, d in gate:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
			end
		end
	end)
	sound(gate:FindFirstChildWhichIsA("BasePart"), SOUND.gate, 2, 0.4)
	Entities.noise(base.Position, Rules.NOISE.gate, "gate")
	for _, lamp in info.lights do
		local l = lamp:FindFirstChildOfClass("PointLight")
		if l then
			l.Color = Color3.fromRGB(255, 230, 190)
			l.Brightness = 1.3
		end
		lamp.Color = Color3.fromRGB(255, 230, 190)
	end
end

local function repair(p: Player, info, g)
	local s = players[p]
	if not s or not s.alive or g.done then
		return
	end
	if not g.fused then
		if Rules.take(s.inv, "fuse") then
			g.fused = true
			toast(p, "FuseIn")
			sound(g.body, SOUND.pick, 1)
			syncInv(p)
		else
			toast(p, "NeedFuse")
		end
		return
	end
	g.progress = Rules.repair(g.progress)
	local sp = g.body:FindFirstChild("Sparks")
	if sp then
		(sp :: ParticleEmitter):Emit(25)
	end
	sound(g.body, SOUND.hit, 1.2, 0.8)
	Entities.noise(g.body.Position, Rules.NOISE.repair, "repair")
	if g.progress >= 100 then
		g.done = true
		g.lamp.Color = Color3.fromRGB(60, 230, 90)
		local l = g.lamp:FindFirstChildOfClass("PointLight")
		if l then
			l.Color = Color3.fromRGB(90, 255, 120)
		end
		local done = 0
		for _, gg in info.generators do
			if gg.done then
				done += 1
			end
		end
		announce("GeneratorFixed", done, #info.generators)
		if done >= #info.generators then
			openBigGate(info)
		end
	else
		toast(p, "Repairing", g.progress)
	end
end

local ride -- объявлено ниже

function G.wireRoom(info)
	for _, d in info.model:GetDescendants() do
		if d:IsA("ProximityPrompt") and not d:GetAttribute("Wired") then
			local kind = d:GetAttribute("Kind")
			local part = d.Parent
			if kind == "hide" then
				d:SetAttribute("Wired", true)
				d.Triggered:Connect(function(p)
					hide(p, part)
				end)
			elseif kind == "search" then
				d:SetAttribute("Wired", true)
				d.Triggered:Connect(function(p)
					if not G.isAlive(p) or part:GetAttribute("Searched") then
						return
					end
					part:SetAttribute("Searched", true)
					d.Enabled = false
					local item, amount = Rules.loot(math.random(), run.front)
					if item == "nothing" then
						toast(p, "Empty")
					elseif give(p, item, amount) then
						toast(p, "Found_" .. item, amount)
					end
				end)
			elseif kind == "pick" then
				d:SetAttribute("Wired", true)
				d.Triggered:Connect(function(p)
					local s = players[p]
					if not s or not s.alive or not part.Parent then
						return
					end
					local item = part:GetAttribute("Item")
					if item == "key" then
						local n = part:GetAttribute("KeyFor")
						s.keys[n] = true
						toast(p, "KeyTaken")
						sound(part, SOUND.pick, 0.8)
						syncInv(p)
					elseif item == "coins" then
						give(p, "coins", part:GetAttribute("Amount") or 2)
						toast(p, "Found_coins", part:GetAttribute("Amount") or 2)
					elseif not give(p, item) then
						return
					else
						toast(p, "Found_" .. item, 1)
					end
					part.Parent:Destroy()
				end)
			elseif kind == "repair" then
				d:SetAttribute("Wired", true)
				local boss = bossOf(part)
				if boss then
					for _, g in boss.generators do
						if g.body == part then
							d.Triggered:Connect(function(p)
								repair(p, boss, g)
							end)
						end
					end
				end
			elseif kind == "ride" then
				d:SetAttribute("Wired", true)
				d.Triggered:Connect(function(p)
					ride(p, info)
				end)
			elseif kind == "shop" then
				d:SetAttribute("Wired", true)
				d.Triggered:Connect(function(p)
					if G.isAlive(p) then
						send(p, { type = "shop" })
					end
				end)
			end
		end
	end
end

function G.buy(p: Player, item: string)
	local s = players[p]
	if not s or not s.alive then
		return { ok = false }
	end
	-- покупать можно только у автомата в лифте
	local r = rootOf(p)
	local near = false
	for _, info in run.rooms do
		local e = info.elevatorInfo
		if e and r and Builder.contains(e, r.Position) then
			near = true
		end
	end
	if not near then
		return { ok = false, error = "far" }
	end
	local ok, coins, why = Rules.buy(s.inv, s.coins, item)
	if not ok then
		toast(p, if why == "coins" then "NotEnoughCoins" else "BagFull", Rules.PRICES[item] or 0)
		return { ok = false, error = why }
	end
	s.coins = coins
	syncInv(p)
	return { ok = true }
end

-- ---------------------------------------------------------------------------
-- лифт: только вертикально и только на один сектор вперёд

function ride(p: Player, info)
	if not G.isAlive(p) or info.riding or info.rideDone then
		return
	end
	local owner = nil
	for n, r in run.rooms do
		if r.elevatorInfo == info then
			owner = n
		end
	end
	if not owner then
		return
	end
	info.riding = true
	local from = info.desc.sector
	announce("ElevatorLeaving", 8)
	task.wait(8)
	if not run.active then
		return
	end
	-- кто не успел — заходит в кабину
	local k = 0
	for _, q in G.alivePlayers() do
		local r = rootOf(q)
		if r and not Special.inCabin(info, r.Position) then
			unhide(q)
			k += 1
			teleport(q, info.cabinCenter * CFrame.new(((k % 3) - 1) * 3, 0, (math.floor(k / 3) % 3 - 1) * 2.5))
		end
	end
	info.gate:PivotTo(info.gate:GetPivot() - Vector3.new(0, 10.5, 0))
	info.gateBlock.CanCollide = true
	G.sendAll({ type = "ride", from = from, to = from + 1 })
	local rumble = Entities.sound(info.model, Entities.SOUND.rumble, 1.5, 0.3, true)
	-- старый сектор исчезает, кабина «едет»
	for n in run.rooms do
		if n > 0 and n < owner then
			destroyRoom(n)
		end
	end
	local holder = run.rooms[owner]
	if holder and holder.boss then
		Entities.stopBlind()
		holder.model:Destroy()
	end
	-- детали из зала дальше не нужны
	for q, s in players do
		if s.inv.fuse then
			s.inv.fuse = nil
			syncInv(q)
		end
	end
	task.wait(7)
	rumble:Stop()
	info.rideDone = true
	run.sector = from + 1
	workspace:SetAttribute("Sector", run.sector)
	announce("SectorWelcome", run.sector)
	openDoor(owner + 1, true)
end

-- ---------------------------------------------------------------------------
-- начало и конец забега

local function spawnPoint(): CFrame
	local start = run.rooms[0]
	return start.origin * CFrame.new(math.random(-6, 6), 3, -20 + math.random(-3, 3))
end

local function frontSpawn(): CFrame
	local info = run.rooms[run.front] or run.rooms[0]
	if info.boss and info.elevatorInfo then
		info = info.elevatorInfo
	end
	return info.origin * CFrame.new(0, 3, -4)
end

local function resetPlayer(p: Player)
	local s = players[p]
	s.alive = true
	s.cause = nil
	s.coins = 0
	s.inv = {}
	s.keys = {}
	s.flash = Rules.FLASH_MAX
	s.flashOn = false
	s.sneaking = false
	s.hidden = nil
	p:SetAttribute("Alive", true)
	p:SetAttribute("HiddenEye", nil)
end

local function loadCharacter(p: Player, cf: CFrame)
	resetPlayer(p)
	p:LoadCharacter()
	local char = p.Character or p.CharacterAdded:Wait()
	char:WaitForChild("HumanoidRootPart", 5)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = Rules.SPEED.walk
		hum.Died:Connect(function()
			onDied(p)
		end)
	end
	teleport(p, cf)
	setFlash(p, false)
	syncInv(p)
end

local function startRun()
	run.active = true
	run.ending = false
	run.seed = math.random(1, 2 ^ 30)
	run.plan = Plan.new(run.seed)
	run.descs = {}
	run.rooms = {}
	run.front = 0
	run.sector = 1
	world:ClearAllChildren()
	workspace:SetAttribute("Door", 0)
	workspace:SetAttribute("Sector", 1)
	buildRoom(0)
	buildRoom(1)
end

function endRun()
	if run.ending then
		return
	end
	run.ending = true
	G.sendAll({ type = "results", door = run.front, sector = run.sector })
	task.wait(7)
	Entities.clear()
	table.clear(occupied)
	startRun()
	for p in players do
		if p.Parent then
			task.spawn(loadCharacter, p, spawnPoint())
		end
	end
end
G.endRun = endRun

-- игрок нажал «Играть»: если забег уже далеко, переносится к остальным
function G.play(p: Player)
	local s = players[p]
	if not s then
		return { ok = false }
	end
	if s.alive and run.front >= 2 then
		local r = rootOf(p)
		local start = run.rooms[0]
		if r and start and Builder.contains(start, r.Position) then
			teleport(p, frontSpawn())
		end
	end
	return { ok = true, best = Records.get(p), door = run.front, alive = s.alive }
end

-- ---------------------------------------------------------------------------

function G.init()
	Players.CharacterAutoLoads = false
	event = Remotes.event("Game")
	world = Instance.new("Folder")
	world.Name = "Labyrinth"
	world.Parent = workspace
	Records.init()
	Entities.init(G)
	startRun()

	local function added(p: Player)
		local ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		local best = Instance.new("IntValue")
		best.Name = "Best"
		best.Parent = ls
		ls.Parent = p
		players[p] = { alive = false, coins = 0, inv = {}, keys = {}, flash = Rules.FLASH_MAX }
		best.Value = Records.load(p)
		loadCharacter(p, spawnPoint())
	end
	Players.PlayerAdded:Connect(added)
	for _, p in Players:GetPlayers() do
		task.spawn(added, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		unhide(p)
		players[p] = nil
		Records.forget(p)
		if run.active and #G.alivePlayers() == 0 and #Players:GetPlayers() > 1 then
			task.spawn(endRun)
		end
	end)

	Remotes.fn("Request").OnServerInvoke = function(p: Player, action: any, arg: any)
		local s = players[p]
		if not s then
			return { ok = false }
		end
		if action == "Play" then
			return G.play(p)
		elseif action == "Flash" then
			setFlash(p, not s.flashOn)
			if s.flash <= 0 then
				toast(p, "FlashEmpty")
			end
			return { ok = true }
		elseif action == "Sneak" then
			s.sneaking = arg == true
			local hum = humOf(p)
			if hum and s.alive then
				hum.WalkSpeed = if s.sneaking then Rules.SPEED.sneak else Rules.SPEED.walk
			end
			return { ok = true }
		elseif action == "Use" and type(arg) == "string" then
			return G.use(p, arg)
		elseif action == "Buy" and type(arg) == "string" then
			return G.buy(p, arg)
		elseif action == "Seen" and type(arg) == "number" then
			Entities.seen(p, arg)
			return nil
		elseif action == "Status" then
			syncInv(p)
			return { ok = true, best = Records.get(p), door = run.front, alive = s.alive }
		end
		return { ok = false }
	end

	-- фонарик садится, упавшие возвращаются, отставшие в убранных комнатах переносятся
	task.spawn(function()
		while true do
			local dt = task.wait(0.25)
			for p, s in players do
				if s.alive and s.flashOn then
					s.flash = Rules.drain(s.flash, dt, true)
					if s.flash <= 0 then
						setFlash(p, false)
						toast(p, "FlashEmpty")
					else
						p:SetAttribute("Flash", math.ceil(s.flash))
					end
				end
				local r = rootOf(p)
				if s.alive and r and r.Position.Y < -60 then
					teleport(p, frontSpawn())
				end
			end
		end
	end)
	local _ = M
end

return G
