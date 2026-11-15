--!nonstrict
-- «The Labyrinth»: лобби и забег.
-- Лобби (обычный сервер): холл с рабочим лифтом. Кто зашёл в кабину, через 12 секунд
-- переносится в отдельный сервер этого же места — там идёт забег (как в DOORS).
-- Забег: 100 дверей 001–100, комнаты строятся впереди и убираются позади, двери
-- открываются сами, когда подходишь (если не заперты и не стоит Монетчик), ложные
-- двери в развилках переносят к настоящей, ящики выдвигаются с находками, предметы
-- лежат в обычном инвентаре Roblox. За дверью 100 — зал Слепого, погоня и пустота

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Rules = require(Shared.Rules)
local Plan = require(Shared.RoomPlan)
local Remotes = require(Shared.Roblox.Remotes)
local Lang = require(Shared.Lang)
local M = require(Shared.Materials)

local Props = require(script.Parent.Parent.World.Props)
local Builder = require(script.Parent.Parent.World.RoomBuilder)
local Special = require(script.Parent.Parent.World.Special)
local Entities = require(script.Parent.Entities)
local Records = require(script.Parent.Records)

local G = {}

local event: RemoteEvent
local world: Folder

-- забег идёт в зарезервированном сервере; в Studio лифт превращает этот сервер в забег
G.mode = if game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then "run" else "lobby"

local KEEP_BEHIND = 3

local run = {
	active = false,
	seed = 0,
	plan = nil,
	descs = {},
	rooms = {},
	front = 0,
	ending = false,
	chasing = false,
	keepers = {},
}
G.run = run

local players: { [Player]: any } = {}
G.players = players
local occupied: { [BasePart]: Player } = {}
local lobby = nil

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
	return s ~= nil and s.alive and not s.finished
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
		if s.alive and not s.finished and p.Parent then
			table.insert(list, p)
		end
	end
	return list
end

function G.inRoom(info, pos: Vector3): boolean
	return Builder.contains(info, pos)
end

function G.loadedRooms()
	local list = {}
	for n = math.max(1, run.front - KEEP_BEHIND), run.front do
		local info = run.rooms[n]
		if info and not info.boss then
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

local function sound(at: Instance?, id: string, vol: number, speed: number?)
	if at then
		Entities.sound(at, id, vol, speed)
	end
end

local SOUND = {
	door = "rbxasset://sounds/swoosh.wav",
	locked = "rbxasset://sounds/clickfast.wav",
	pick = "rbxasset://sounds/electronicpingshort.wav",
	drawer = "rbxasset://sounds/swoosh.wav",
	hit = "rbxasset://sounds/collide.wav",
}

-- ---------------------------------------------------------------------------
-- инвентарь: обычные инструменты Roblox в нижней панели

local ITEM_LOOK = {
	flashlight = { size = Vector3.new(0.45, 0.45, 1.5), color = Color3.fromRGB(46, 46, 50), mat = M.Metal },
	battery = { size = Vector3.new(0.4, 0.8, 0.4), color = Color3.fromRGB(40, 130, 60), mat = M.Metal },
	plant = { size = Vector3.new(0.7, 0.6, 0.7), color = Color3.fromRGB(140, 76, 54), mat = M.Brick },
	whistle = { size = Vector3.new(0.3, 0.3, 0.8), color = Color3.fromRGB(190, 190, 196), mat = M.Metal },
	lockpick = { size = Vector3.new(0.1, 0.1, 1.1), color = Color3.fromRGB(170, 170, 176), mat = M.Metal },
	key = { size = Vector3.new(0.15, 0.15, 1), color = Color3.fromRGB(190, 156, 88), mat = M.Metal },
	fuse = { size = Vector3.new(0.5, 0.5, 1), color = Color3.fromRGB(60, 110, 170), mat = M.Glass },
}

local function itemName(s, item: string, count: number): string
	local name = Lang.t(s.lang or "en", "item_" .. item)
	if count > 1 then
		name ..= " ×" .. count
	end
	return name
end

local setFlash -- ниже

local function makeTool(p: Player, item: string)
	local look = ITEM_LOOK[item]
	local tool = Instance.new("Tool")
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("Item", item)
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = look.size
	h.Color = look.color
	h.Material = look.mat
	h.CanCollide = false
	h.Massless = true
	h.Parent = tool
	local function extra(name, size, offset, color, mat, shape)
		local e = Instance.new("Part")
		e.Name = name
		e.Size = size
		e.Color = color
		e.Material = mat
		e.CanCollide = false
		e.Massless = true
		if shape then
			e.Shape = shape
		end
		e.CFrame = h.CFrame * offset
		local w = Instance.new("WeldConstraint")
		w.Part0 = h
		w.Part1 = e
		w.Parent = e
		e.Parent = tool
	end
	if item == "flashlight" then
		extra("Head", Vector3.new(0.65, 0.65, 0.4), CFrame.new(0, 0, -0.9), Color3.fromRGB(60, 60, 64), M.Metal)
		extra("Lens", Vector3.new(0.5, 0.5, 0.05), CFrame.new(0, 0, -1.12), Color3.fromRGB(255, 240, 200), M.Neon)
		local l = Instance.new("SpotLight")
		l.Name = "Beam"
		l.Face = Enum.NormalId.Front
		l.Range = 50
		l.Angle = 48
		l.Brightness = 3
		l.Color = Color3.fromRGB(255, 244, 220)
		l.Shadows = true
		l.Enabled = false
		l.Parent = h
	elseif item == "plant" then
		extra("Leaves", Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 0.6, 0), Color3.fromRGB(80, 170, 90), M.Grass, Enum.PartType.Ball)
	elseif item == "fuse" then
		extra("Cap", Vector3.new(0.6, 0.6, 0.15), CFrame.new(0, 0, -0.55), Color3.fromRGB(190, 156, 88), M.Metal)
	elseif item == "key" then
		extra("Bow", Vector3.new(0.15, 0.5, 0.5), CFrame.new(0, 0, 0.6), Color3.fromRGB(190, 156, 88), M.Metal)
	end
	tool.Activated:Connect(function()
		G.use(p, item)
	end)
	if item == "flashlight" then
		tool.Equipped:Connect(function()
			setFlash(p, true)
		end)
		tool.Unequipped:Connect(function()
			setFlash(p, false)
		end)
	end
	tool.Parent = p:FindFirstChildOfClass("Backpack")
	return tool
end

-- инструменты по содержимому инвентаря: появляются, исчезают, подписаны числом
local function syncTools(p: Player)
	local s = players[p]
	if not s or not s.alive then
		return
	end
	local n = 0
	for _ in s.keys do
		n += 1
	end
	s.inv.key = if n > 0 then n else nil
	local want = { flashlight = 1 }
	for item, count in s.inv do
		if ITEM_LOOK[item] then
			want[item] = count
		end
	end
	for item, tool in s.tools do
		if not want[item] or not tool.Parent then
			if tool.Parent then
				tool:Destroy()
			end
			s.tools[item] = nil
		end
	end
	for item, count in want do
		local tool = s.tools[item]
		if not tool then
			tool = makeTool(p, item)
			s.tools[item] = tool
		end
		tool.Name = itemName(s, item, count)
		tool.ToolTip = Lang.t(s.lang or "en", "tip_" .. item)
	end
	p:SetAttribute("Coins", s.coins)
	p:SetAttribute("Lockpicks", s.inv.lockpick or 0)
end
G.syncTools = syncTools

local function equipped(p: Player, item: string): boolean
	local char = p.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("Item") == item
end

-- ---------------------------------------------------------------------------
-- урон и смерть

function G.damage(p: Player, amount: number, cause: string?)
	local s = players[p]
	local hum = humOf(p)
	if not s or not G.isAlive(p) or not hum or s.god then
		return
	end
	s.cause = cause
	hum:TakeDamage(amount)
end

function G.kill(p: Player, cause: string?)
	local s = players[p]
	local hum = humOf(p)
	if not s or not G.isAlive(p) or not hum or s.god then
		return
	end
	s.cause = cause
	hum.Health = 0
end

local endRun

local function anyoneLeft(): boolean
	return #G.alivePlayers() > 0
end

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
	announce("PlayerDied", p.DisplayName, Rules.plate(run.front))
	if not anyoneLeft() and run.active then
		task.spawn(endRun)
	end
end

-- ---------------------------------------------------------------------------
-- фонарик в руке

function setFlash(p: Player, on: boolean)
	local s = players[p]
	if not s then
		return
	end
	s.flashOn = on and s.flash > 0 and s.alive and equipped(p, "flashlight")
	local tool = s.tools.flashlight
	local beam = tool and tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("Beam")
	if beam then
		beam.Enabled = s.flashOn
	end
	p:SetAttribute("FlashOn", s.flashOn)
	p:SetAttribute("Flash", math.ceil(s.flash))
end
G.setFlash = setFlash

-- ---------------------------------------------------------------------------
-- укрытия: шкафчики и ниши

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
		local out = part.CFrame * CFrame.new(0, -part.Size.Y / 2 + 3, -(part.Size.Z / 2 + 2.4))
		p.Character:PivotTo(CFrame.lookAt(out.Position, out.Position + part.CFrame.LookVector))
	end
end
G.unhide = unhide

local function hide(p: Player, part: BasePart)
	local s = players[p]
	if not s or not G.isAlive(p) then
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
		p.Character:PivotTo(part.CFrame * CFrame.new(0, -part.Size.Y / 2 + 3, 0.2))
		r.Anchored = true
	end
	p:SetAttribute("HiddenEye", part.CFrame * CFrame.new(0, math.min(1.6, part.Size.Y / 2 - 0.6), -part.Size.Z / 2 + 0.2))
end

-- ---------------------------------------------------------------------------
-- предметы

local function give(p: Player, item: string, amount: number?): boolean
	local s = players[p]
	if not s then
		return false
	end
	if item == "coins" then
		s.coins += amount or 1
		sound(rootOf(p), SOUND.pick, 0.5, 1.6)
		syncTools(p)
		return true
	end
	if not Rules.add(s.inv, item) then
		toast(p, "BagFull")
		return false
	end
	sound(rootOf(p), SOUND.pick, 0.6)
	syncTools(p)
	return true
end
G.give = give

function G.use(p: Player, item: string)
	local s = players[p]
	if not s or not G.isAlive(p) then
		return
	end
	if item == "flashlight" then
		if s.flash <= 0 then
			toast(p, "FlashEmpty")
		end
		setFlash(p, not s.flashOn)
	elseif item == "plant" then
		local hum = humOf(p)
		if not hum or hum.Health >= hum.MaxHealth - 1 then
			toast(p, "HealthFull")
			return
		end
		if Rules.take(s.inv, "plant") then
			hum.Health = math.min(hum.MaxHealth, hum.Health + Rules.PLANT_HEAL)
			toast(p, "Healed")
		end
	elseif item == "battery" then
		if s.flash >= Rules.FLASH_MAX - 1 then
			toast(p, "FlashFull")
			return
		end
		if Rules.take(s.inv, "battery") then
			s.flash = Rules.recharge(s.flash)
			setFlash(p, s.flashOn)
			toast(p, "Recharged")
		end
	elseif item == "whistle" then
		local now = os.clock()
		if now - (s.whistleAt or 0) < 8 then
			toast(p, "WhistleWait")
			return
		end
		s.whistleAt = now
		Entities.whistle(p)
	else
		return
	end
	syncTools(p)
end

-- ---------------------------------------------------------------------------
-- комнаты

local function descOf(n: number)
	while run.descs[0] == nil or #run.descs < n do
		local k = if run.descs[0] == nil then 0 else #run.descs + 1
		run.descs[k] = Plan.room(run.plan, k)
	end
	return run.descs[n]
end

local openDoor -- ниже

-- создать дверь с номером n в комнате info (у ложных дверей — тот же номер)
local function makeDoor(info, n: number, cf: CFrame, locked: boolean, decoy: boolean)
	local m, leaf = Props.door(info.model, cf, Rules.plate(n), locked)
	local door = { model = m, leaf = leaf, number = n, locked = locked, cf = cf, opened = false, decoy = decoy }
	if locked then
		-- отмычка: кнопка видна только тем, у кого она есть (это решает клиент)
		local trig = Props.P(m, "LockTrigger", Vector3.new(1, 1, 1), cf * CFrame.new(1.6, 4.5, 0.6), Color3.new(0, 0, 0), M.SmoothPlastic, Props.nc({ Transparency = 1 }))
		local pr = Props.prompt(trig, "lockpick", 2.5, 7)
		door.lockPrompt = pr
		pr.Triggered:Connect(function(p)
			G.pick(p, n)
		end)
	end
	return door
end

-- выдвинуть ящики и положить находки
local function openDrawers(p: Player, info, sr)
	if sr.opened then
		return
	end
	sr.opened = true
	local pr = sr.hit:FindFirstChildOfClass("ProximityPrompt")
	if pr then
		pr.Enabled = false
	end
	sound(sr.hit, SOUND.drawer, 0.6, 1.4)
	for _, dr in sr.drawers do
		local base = dr.model.WorldPivot
		local v = Instance.new("NumberValue")
		v.Changed:Connect(function(a)
			dr.model:PivotTo(base * CFrame.new(0, 0, -1.4 * a))
		end)
		local t = TweenService:Create(v, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1 })
		t:Play()
		t.Completed:Connect(function()
			v:Destroy()
		end)
	end
	task.delay(0.5, function()
		if not sr.hit.Parent then
			return
		end
		-- ключ от двери этой комнаты
		if sr.key then
			local dr = sr.drawers[1]
			local _, part = Props.pickup(info.model, dr.open, "key")
			part:SetAttribute("KeyFor", sr.key)
		end
		-- одна находка на предмет мебели, в случайном ящике
		local item, amount = Rules.loot(math.random(), run.front)
		if item ~= "nothing" then
			local dr = sr.drawers[math.random(1, #sr.drawers)]
			local cf = dr.open * CFrame.new(if sr.key and dr == sr.drawers[1] then 0.8 else 0, 0, 0)
			local _, part = Props.pickup(info.model, cf, item)
			if item == "coins" then
				part:SetAttribute("Amount", amount)
			end
		elseif not sr.key then
			toast(p, "Empty")
		end
		G.wirePickups(info)
	end)
end

function G.wirePickups(info)
	for _, d in info.model:GetDescendants() do
		if d:IsA("ProximityPrompt") and not d:GetAttribute("Wired") and d:GetAttribute("Kind") == "pick" then
			d:SetAttribute("Wired", true)
			local part = d.Parent
			d.Triggered:Connect(function(p)
				local s = players[p]
				if not s or not G.isAlive(p) or not part.Parent then
					return
				end
				local item = part:GetAttribute("Item")
				if item == "key" then
					s.keys[part:GetAttribute("KeyFor")] = true
					toast(p, "KeyTaken")
					sound(part, SOUND.pick, 0.8)
					syncTools(p)
				elseif item == "coins" then
					local a = part:GetAttribute("Amount") or 3
					give(p, "coins", a)
					toast(p, "Found_coins", a)
				elseif give(p, item) then
					toast(p, "Found_" .. item)
				else
					return
				end
				part.Parent:Destroy()
			end)
		end
	end
end

local function wireRoom(info)
	for _, cavity in info.hideSpots do
		local pr = cavity:FindFirstChildOfClass("ProximityPrompt")
		if pr and not pr:GetAttribute("Wired") then
			pr:SetAttribute("Wired", true)
			pr.Triggered:Connect(function(p)
				hide(p, cavity)
			end)
		end
	end
	for _, sr in info.searchables do
		local pr = sr.hit:FindFirstChildOfClass("ProximityPrompt")
		if pr and not pr:GetAttribute("Wired") then
			pr:SetAttribute("Wired", true)
			pr.Triggered:Connect(function(p)
				if G.isAlive(p) then
					openDrawers(p, info, sr)
				end
			end)
		end
	end
	G.wirePickups(info)
end

local function buildRoom(n: number)
	if run.rooms[n] or n > Rules.CHAPTER then
		return run.rooms[n]
	end
	local d = descOf(n)
	local prev = if n > 0 then (run.rooms[n - 1] or buildRoom(n - 1)) else nil
	local origin = if prev then prev.doorCF else CFrame.new(0, 0, 0)
	local rand = Plan.rng(run.seed + n * 7919)
	local info
	if d.kind == "boss" then
		info = Special.boss(world, d, origin, rand, prev)
	else
		info = Builder.build(world, d, origin, prev, rand)
	end
	info.n = n
	info.doorCF = info.exitCF
	run.rooms[n] = info
	if d.kind ~= "boss" then
		info.door = makeDoor(info, n + 1, info.doorCF, d.locked == true, false)
		info.decoys = {}
		for _, cf in info.decoyCFs do
			table.insert(info.decoys, makeDoor(info, n + 1, cf, false, true))
		end
	end
	-- ключ в одном из ящиков этой комнаты (или на виду, если ящиков нет)
	if d.locked then
		if #info.searchables > 0 then
			info.searchables[math.floor(rand() * #info.searchables) + 1].key = n + 1
		else
			local _, part = Props.pickup(info.model, info.watcherSpawn * CFrame.new(0, 0, 2), "key")
			part:SetAttribute("KeyFor", n + 1)
		end
	end
	if d.coin then
		local price = Rules.coinPrice(n + 1)
		local keeper, pc, pb = Special.coinKeeper(info.model, info.doorCF * CFrame.new(0, 0, 2.6) * CFrame.Angles(0, math.pi, 0), price)
		info.toll = { model = keeper, price = price, paid = false, base = keeper:GetPivot() }
		table.insert(run.keepers, info.toll)
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
	wireRoom(info)
	if info.boss then
		G.wireBoss(info)
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
	if info.toll then
		local i = table.find(run.keepers, info.toll)
		if i then
			table.remove(run.keepers, i)
		end
	end
	info.model:Destroy()
	run.rooms[n] = nil
end

local function frontSpawn(): CFrame
	local info = run.rooms[run.front] or run.rooms[0]
	return info.origin * CFrame.new(0, 3, -4)
end
G.frontSpawn = frontSpawn

local function cleanup()
	local keepFrom = run.front - KEEP_BEHIND
	for n, info in run.rooms do
		if n < keepFrom then
			local target = run.rooms[keepFrom]
			if target then
				for _, p in G.alivePlayers() do
					local r = rootOf(p)
					if r and Builder.contains(info, r.Position) then
						teleport(p, target.origin * CFrame.new(0, 3, -4))
					end
				end
			end
			destroyRoom(n)
		end
	end
end

local function swing(door)
	local leaf = door.leaf
	local base = leaf:GetPivot()
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(a)
		leaf:PivotTo(base * CFrame.Angles(0, math.rad(-100) * a, 0))
	end)
	local t = TweenService:Create(v, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1 })
	t:Play()
	t.Completed:Connect(function()
		v:Destroy()
	end)
	for _, d in leaf:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	sound(leaf:FindFirstChild("Slab"), SOUND.door, 0.8, 0.6)
end

function openDoor(n: number, force: boolean?)
	local info = run.rooms[n - 1]
	if not info or not info.door or info.door.opened then
		return false
	end
	local door = info.door
	door.opened = true
	local lock = door.model:FindFirstChild("Padlock")
	if lock then
		lock:Destroy()
	end
	if door.lockPrompt then
		door.lockPrompt.Enabled = false
	end
	swing(door)
	run.front = math.max(run.front, n)
	workspace:SetAttribute("Door", run.front)
	for _, s in players do
		s.keys[n] = nil
	end
	for p, s in players do
		if G.isAlive(p) then
			if Records.offer(p, n) then
				local ls = p:FindFirstChild("leaderstats")
				local b = ls and ls:FindFirstChild("Best")
				if b then
					(b :: IntValue).Value = n
				end
			end
			s.coins += Rules.COINS_PER_DOOR
			syncTools(p)
		end
	end
	local entered = buildRoom(n)
	buildRoom(n + 1)
	cleanup()
	workspace:SetAttribute("Light", entered.desc.light or 1)
	Entities.noise(door.model:GetPivot().Position, Rules.NOISE.door)
	if entered.boss then
		Entities.startBlind(entered)
		announce("BossHall")
	elseif entered.desc.blackout and not (run.descs[n - 1] and run.descs[n - 1].blackout) then
		announce("Blackout")
	end
	if entered.desc.hum and not force then
		task.delay(1.5 + math.random() * 3, function()
			if run.active and run.front >= n then
				Entities.hum()
			end
		end)
	end
	return true
end
G.openDoor = openDoor

local lockedToastAt: { [Player]: number } = {}

-- игрок подошёл к двери n
function G.tryOpen(p: Player, n: number)
	local s = players[p]
	if not s or not G.isAlive(p) or s.hidden then
		return
	end
	local info = run.rooms[n - 1]
	if not info or not info.door or info.door.opened then
		return
	end
	local now = os.clock()
	if info.toll and not info.toll.paid then
		return
	end
	if info.door.locked then
		if s.keys[n] then
			s.keys[n] = nil
			toast(p, "Unlocked")
			syncTools(p)
		else
			if now - (lockedToastAt[p] or 0) > 4 then
				lockedToastAt[p] = now
				sound(info.door.model:FindFirstChildWhichIsA("BasePart"), SOUND.locked, 0.8)
				toast(p, if (s.inv.lockpick or 0) > 0 then "LockedPick" else "Locked")
			end
			return
		end
	end
	openDoor(n)
end

-- отмычка у запертой двери
function G.pick(p: Player, n: number)
	local s = players[p]
	local info = run.rooms[n - 1]
	if not s or not G.isAlive(p) or not info or not info.door or info.door.opened then
		return
	end
	if Rules.take(s.inv, "lockpick") then
		toast(p, "Picked")
		syncTools(p)
		openDoor(n)
	else
		toast(p, "NoLockpick")
	end
end

-- ложная дверь в развилке: глюк, и игрока переносит к настоящей двери (или назад)
function G.decoy(p: Player, info)
	local s = players[p]
	if not s or not G.isAlive(p) then
		return
	end
	local now = os.clock()
	if now - (s.glitchAt or 0) < 2 then
		return
	end
	s.glitchAt = now
	send(p, { type = "glitch" })
	task.wait(0.35)
	local n = info.n + 1
	local blocked = info.door.locked and not s.keys[n] or (info.toll and not info.toll.paid)
	if blocked or not G.isAlive(p) then
		-- настоящая дверь закрыта: лабиринт возвращает в середину комнаты
		teleport(p, info.center * CFrame.new(0, -info.size.Y / 2 + 3, 0))
		return
	end
	if info.door.locked then
		s.keys[n] = nil
		syncTools(p)
	end
	openDoor(n)
	local nextRoom = run.rooms[n]
	if nextRoom then
		teleport(p, nextRoom.origin * CFrame.new(0, 3, -4))
	end
end

-- ---------------------------------------------------------------------------
-- Монетчик

function G.payToll(p: Player, info, how: string)
	local s = players[p]
	local t = info.toll
	if not s or not G.isAlive(p) or not t or t.paid then
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
	syncTools(p)
	for _, d in t.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			TweenService:Create(d, TweenInfo.new(1.2), { Transparency = 1 }):Play()
		elseif d:IsA("ProximityPrompt") then
			d.Enabled = false
		elseif d:IsA("PointLight") or d:IsA("BillboardGui") then
			d.Enabled = false
		end
	end
	task.delay(1.4, function()
		t.model:Destroy()
	end)
end

-- ---------------------------------------------------------------------------
-- зал Слепого и погоня

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
		gate:PivotTo(base * CFrame.new(0, 12 * a, 0))
	end)
	local t = TweenService:Create(v, TweenInfo.new(3.5, Enum.EasingStyle.Sine), { Value = 1 })
	t:Play()
	t.Completed:Connect(function()
		v:Destroy()
		for _, d in gate:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
			end
		end
		-- Слепой больше не слушает — он бежит
		run.chasing = true
		Entities.chase(info)
		announce("Run")
		G.sendAll({ type = "chase" })
	end)
	sound(gate:FindFirstChildWhichIsA("BasePart"), SOUND.hit, 2, 0.4)
end

local function repair(p: Player, info, g)
	local s = players[p]
	if not s or not G.isAlive(p) or g.done then
		return
	end
	if not g.fused then
		if Rules.take(s.inv, "fuse") then
			g.fused = true
			toast(p, "FuseIn")
			sound(g.body, SOUND.pick, 1)
			syncTools(p)
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

function G.wireBoss(info)
	for _, g in info.generators do
		local pr = g.body:FindFirstChildOfClass("ProximityPrompt")
		if pr then
			pr.Triggered:Connect(function(p)
				repair(p, info, g)
			end)
		end
	end
end

-- добежал до края: финальная сцена у игрока, дальше «Продолжение следует»
local function finish(p: Player)
	local s = players[p]
	if not s or s.finished or not s.alive then
		return
	end
	s.finished = true
	p:SetAttribute("Finished", true)
	unhide(p)
	Records.offer(p, Rules.CHAPTER)
	Records.complete(p)
	local boss = run.rooms[Rules.BOSS_DOOR]
	local edge = boss and boss.chase and boss.chase.edge
	local r = rootOf(p)
	if r and edge then
		r.Anchored = true
		p.Character:PivotTo(edge * CFrame.new(0, 3, 2))
	end
	send(p, { type = "ending", edge = edge })
	if not anyoneLeft() then
		task.spawn(endRun)
	end
end
G.finish = finish

-- ---------------------------------------------------------------------------
-- начало и конец забега

local function resetPlayer(p: Player)
	local s = players[p]
	s.alive = true
	s.finished = false
	s.cause = nil
	s.coins = 0
	s.inv = { whistle = 1 }
	s.keys = {}
	s.flash = Rules.FLASH_MAX
	s.flashOn = false
	s.sneaking = false
	s.hidden = nil
	for _, t in s.tools do
		if t.Parent then
			t:Destroy()
		end
	end
	s.tools = {}
	p:SetAttribute("Alive", true)
	p:SetAttribute("Finished", nil)
	p:SetAttribute("HiddenEye", nil)
	p:SetAttribute("Sneaking", false)
end

local function loadCharacter(p: Player, cf: CFrame, inRun: boolean)
	resetPlayer(p)
	p:LoadCharacter()
	local char = p.Character or p.CharacterAdded:Wait()
	char:WaitForChild("HumanoidRootPart", 5)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = Rules.SPEED.walk
		-- прыжков нет: проходы в лабиринте всегда без прыжка
		hum.UseJumpPower = true
		hum.JumpPower = 0
		hum.Died:Connect(function()
			onDied(p)
		end)
	end
	teleport(p, cf)
	if inRun then
		syncTools(p)
		setFlash(p, false)
	else
		players[p].alive = false
		p:SetAttribute("Alive", nil)
	end
end

local function startRun()
	run.active = true
	run.ending = false
	run.chasing = false
	run.seed = math.random(1, 2 ^ 30)
	run.plan = Plan.new(run.seed)
	run.descs = {}
	run.rooms = {}
	run.keepers = {}
	run.front = 0
	world:ClearAllChildren()
	workspace:SetAttribute("Door", 0)
	workspace:SetAttribute("Light", 1)
	workspace:SetAttribute("Mode", "run")
	buildRoom(0)
	buildRoom(1)
end

local function startPoint(): CFrame
	local start = run.rooms[0]
	return start.origin * CFrame.new(math.random(-6, 6), 3, -20 + math.random(-3, 3))
end

-- в лобби (или заново в Studio)
local function toLobby(p: Player)
	if RunService:IsStudio() then
		return
	end
	pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { p })
	end)
end
G.toLobby = toLobby

function endRun()
	if run.ending then
		return
	end
	run.ending = true
	G.sendAll({ type = "results", door = run.front })
	task.wait(10)
	if RunService:IsStudio() or G.mode == "lobby" then
		-- в Studio забег просто начинается заново
		Entities.clear()
		table.clear(occupied)
		startRun()
		for p in players do
			if p.Parent then
				task.spawn(loadCharacter, p, startPoint(), true)
			end
		end
		return
	end
	local list = {}
	for p in players do
		if p.Parent then
			table.insert(list, p)
		end
	end
	if #list > 0 then
		pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, list)
		end)
	end
end
G.endRun = endRun

-- лобби превращается в забег прямо в этом сервере (Studio и кнопка админа)
function G.startHere(list: { Player }?)
	if G.mode == "run" then
		return
	end
	G.mode = "run"
	if lobby then
		lobby.model:Destroy()
		lobby = nil
	end
	startRun()
	for p in players do
		if p.Parent then
			task.spawn(loadCharacter, p, startPoint(), true)
		end
	end
	local _ = list
end

-- ---------------------------------------------------------------------------
-- лифт в лобби: кто в кабине, через 12 секунд уезжает в отдельный сервер

local LIFT_TIME = 12
local liftAt = nil
local function lobbyStep()
	if G.mode ~= "lobby" or not lobby then
		return
	end
	local zone = lobby.zone
	local inside = {}
	for p in players do
		local r = rootOf(p)
		if r then
			local lp = zone.CFrame:PointToObjectSpace(r.Position)
			if math.abs(lp.X) < zone.Size.X / 2 and math.abs(lp.Z) < zone.Size.Z / 2 and math.abs(lp.Y) < zone.Size.Y / 2 then
				table.insert(inside, p)
			end
		end
	end
	if #inside == 0 then
		liftAt = nil
		lobby.board.Text = "001"
		return
	end
	local now = os.clock()
	liftAt = liftAt or now + LIFT_TIME
	local left = math.max(0, math.ceil(liftAt - now))
	lobby.board.Text = string.format("00:%02d  %d/4", left, math.min(#inside, 4))
	if left > 0 then
		return
	end
	liftAt = nil
	local group = {}
	for i = 1, math.min(4, #inside) do
		table.insert(group, inside[i])
		send(inside[i], { type = "lift" })
	end
	if RunService:IsStudio() then
		G.startHere(group)
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			local code = TeleportService:ReserveServer(game.PlaceId)
			local opts = Instance.new("TeleportOptions")
			opts.ReservedServerAccessCode = code
			TeleportService:TeleportAsync(game.PlaceId, group, opts)
		end)
		if not ok then
			warn("[Labyrinth] teleport: " .. tostring(err))
			for _, p in group do
				toast(p, "LiftFailed")
			end
		end
	end)
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
	workspace:SetAttribute("Mode", G.mode)
	if G.mode == "run" then
		startRun()
	else
		lobby = Special.lobby(world)
	end

	local function added(p: Player)
		local ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		local best = Instance.new("IntValue")
		best.Name = "Best"
		best.Parent = ls
		ls.Parent = p
		players[p] = { alive = false, coins = 0, inv = {}, keys = {}, flash = Rules.FLASH_MAX, tools = {}, lang = "en" }
		best.Value = Records.load(p)
		if G.mode == "run" then
			-- опоздавший попадает к остальным
			local cf = if run.front >= 2 then frontSpawn() else startPoint()
			loadCharacter(p, cf, true)
		else
			loadCharacter(p, lobby.spawn * CFrame.new(math.random(-4, 4), 0, math.random(-3, 3)), false)
		end
	end
	Players.PlayerAdded:Connect(added)
	for _, p in Players:GetPlayers() do
		task.spawn(added, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		unhide(p)
		players[p] = nil
		lockedToastAt[p] = nil
		Records.forget(p)
		if G.mode == "run" and run.active and not anyoneLeft() and #Players:GetPlayers() > 1 then
			task.spawn(endRun)
		end
	end)

	Remotes.fn("Request").OnServerInvoke = function(p: Player, action: any, arg: any)
		local s = players[p]
		if not s then
			return { ok = false }
		end
		if action == "Lang" and (arg == "en" or arg == "ru") then
			s.lang = arg
			syncTools(p)
			return { ok = true }
		elseif action == "Sneak" then
			s.sneaking = arg == true
			p:SetAttribute("Sneaking", s.sneaking)
			local hum = humOf(p)
			if hum and s.alive then
				hum.WalkSpeed = if s.sneaking then Rules.SPEED.sneak else Rules.SPEED.walk
			end
			return { ok = true }
		elseif action == "Unhide" then
			unhide(p)
			return { ok = true }
		elseif action == "Seen" and type(arg) == "number" then
			Entities.seen(p, arg)
			return nil
		elseif action == "Lobby" then
			toLobby(p)
			return { ok = true }
		elseif action == "Status" then
			syncTools(p)
			return { ok = true, best = Records.get(p), mode = G.mode }
		end
		return { ok = false }
	end

	-- двери у подошедших, ложные двери, фонарик, Монетчики, край пустоты, упавшие
	task.spawn(function()
		local t = 0
		while true do
			local dt = task.wait(0.15)
			t += dt
			pcall(lobbyStep)
			if G.mode == "run" and run.active then
				local info = run.rooms[run.front]
				local boss = run.rooms[Rules.BOSS_DOOR]
				for _, p in G.alivePlayers() do
					local s = players[p]
					local r = rootOf(p)
					if r and not s.hidden then
						if info and info.door and not info.door.opened then
							local lp = info.door.cf:PointToObjectSpace(r.Position)
							if lp.Z > -0.5 and lp.Z < 7 and math.abs(lp.X) < 4 and lp.Y > -1 and lp.Y < 8 then
								G.tryOpen(p, info.n + 1)
							end
							for _, dc in info.decoys or {} do
								local dp = dc.cf:PointToObjectSpace(r.Position)
								if dp.Z > -0.5 and dp.Z < 3.5 and math.abs(dp.X) < 3 and dp.Y > -1 and dp.Y < 8 then
									task.spawn(G.decoy, p, info)
								end
							end
						end
						-- край пустоты
						if boss and boss.chase and run.chasing then
							local ep = boss.chase.edge:PointToObjectSpace(r.Position)
							if ep.Z < 1.5 and math.abs(ep.X) < 6 then
								finish(p)
							end
						end
						if s.flashOn then
							s.flash = Rules.drain(s.flash, dt, true)
							if s.flash <= 0 then
								setFlash(p, false)
								toast(p, "FlashEmpty")
							else
								p:SetAttribute("Flash", math.ceil(s.flash))
							end
						end
						local base = (run.rooms[run.front] or run.rooms[0]).origin.Y
						if r.Position.Y < base - 60 then
							if run.chasing then
								finish(p)
							else
								teleport(p, frontSpawn())
							end
						end
					end
				end
				-- Монетчики покачиваются в воздухе
				for _, k in run.keepers do
					if not k.paid and k.model.Parent then
						k.model:PivotTo(k.base * CFrame.new(0, math.sin(t * 2) * 0.35, 0))
					end
				end
			end
		end
	end)
end

return G
