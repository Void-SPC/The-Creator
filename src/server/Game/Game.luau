--!nonstrict
-- «The Museum»: лобби и забег.
-- Лобби (обычный сервер): ночная улица перед музеем. Кто зашёл в тёмные двери,
-- переносится в отдельный сервер этого же места — там идёт забег.
-- Забег: залы строятся впереди и убираются позади; двери открываются сами (кроме
-- запертых и загадок); Тьма, тебЯ, Монетчик, Колосс; журнал существ; на двери 050 —
-- кодовый замок и зал зеркал, на 099 — лифт, рычаги и длинная лестница к двери 100

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local BadgeService = game:GetService("BadgeService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Rules = require(Shared.Rules)
local Plan = require(Shared.RoomPlan)
local Remotes = require(Shared.Roblox.Remotes)
local Lang = require(Shared.Lang)
local M = require(Shared.Materials)

local Config = require(script.Parent.Parent.Config)
local Props = require(script.Parent.Parent.World.Props)
local Builder = require(script.Parent.Parent.World.RoomBuilder)
local Special = require(script.Parent.Parent.World.Special)
local Entities = require(script.Parent.Entities)
local Records = require(script.Parent.Records)

local G = {}

local event: RemoteEvent
local world: Folder

G.mode = if game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then "run" else "lobby"

local KEEP_BEHIND = 4

local run = { active = false, seed = 0, plan = nil, descs = {}, rooms = {}, front = 0, ending = false, done = false, keepers = {} }
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
	return Builder.contains(info, pos) or Special.onStairs(info, pos)
end

-- залы, через которые летит Тьма: от самого старого до последнего открытого
function G.loadedRooms()
	local list = {}
	for n = math.max(0, run.front - KEEP_BEHIND), run.front do
		local info = run.rooms[n]
		if info and not Rules.isSpecial(n) or (info and n == 0) then
			table.insert(list, info)
		end
	end
	return list
end

local function roomOf(pos: Vector3)
	for _, info in run.rooms do
		if G.inRoom(info, pos) then
			return info
		end
	end
	return nil
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
	switch = "rbxasset://sounds/switch.wav",
	slam = "rbxasset://sounds/collide.wav",
}

-- журнал: новая запись, значок
local function badge(p: Player, id: string)
	local badgeId = Config.BADGES[id]
	if type(badgeId) == "number" and badgeId > 0 then
		task.spawn(function()
			pcall(function()
				BadgeService:AwardBadge(p.UserId, badgeId)
			end)
		end)
	end
end

-- достижение: значок (если его ID вписан в Config) и надпись у игрока
function G.achieve(p: Player, id: string)
	if players[p] and Records.achieve(p, id) then
		send(p, { type = "achieve", id = id })
		badge(p, id)
	end
end

function G.achieveAll(id: string)
	for _, p in G.alivePlayers() do
		G.achieve(p, id)
	end
end

function G.discover(p: Player, id: string)
	if players[p] and Records.discover(p, id) then
		send(p, { type = "journal", id = id, new = true })
		badge(p, id)
	end
	if id == "darkness" or id == "coinkeeper" then
		G.achieve(p, id)
	end
end

-- ---------------------------------------------------------------------------
-- инвентарь: обычные инструменты Roblox

local ITEM_LOOK = {
	flashlight = { size = Vector3.new(0.45, 0.45, 1.5), color = Color3.fromRGB(46, 46, 50), mat = M.Metal },
	battery = { size = Vector3.new(0.4, 0.8, 0.4), color = Color3.fromRGB(40, 130, 60), mat = M.Metal },
	plant = { size = Vector3.new(0.7, 0.6, 0.7), color = Color3.fromRGB(140, 76, 54), mat = M.Brick },
	lockpick = { size = Vector3.new(0.1, 0.1, 1.1), color = Color3.fromRGB(170, 170, 176), mat = M.Metal },
	key = { size = Vector3.new(0.15, 0.15, 1), color = Color3.fromRGB(190, 156, 88), mat = M.Metal },
	hammer = { size = Vector3.new(0.2, 0.2, 1.6), color = Color3.fromRGB(112, 78, 52), mat = M.Wood },
	meat = { size = Vector3.new(0.9, 0.5, 1.2), color = Color3.fromRGB(150, 40, 40), mat = M.SmoothPlastic },
	pole = { size = Vector3.new(0.25, 0.25, 4.5), color = Color3.fromRGB(150, 110, 70), mat = M.Wood },
	lens = { size = Vector3.new(1.2, 1.2, 0.12), color = Color3.fromRGB(200, 220, 230), mat = M.Glass },
	coldkey = { size = Vector3.new(0.15, 0.15, 1), color = Color3.fromRGB(120, 170, 200), mat = M.Metal },
	clockkey = { size = Vector3.new(1, 1, 0.3), color = Color3.fromRGB(24, 22, 22), mat = M.Metal },
}

local setFlash

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
	elseif item == "key" then
		extra("Bow", Vector3.new(0.15, 0.5, 0.5), CFrame.new(0, 0, 0.6), Color3.fromRGB(190, 156, 88), M.Metal)
	elseif item == "hammer" then
		extra("Head", Vector3.new(0.9, 0.4, 0.4), CFrame.new(0, 0, -0.8), Color3.fromRGB(90, 92, 96), M.Metal)
	elseif item == "pole" then
		extra("Hook", Vector3.new(0.15, 0.6, 0.15), CFrame.new(0, 0.25, -2.2), Color3.fromRGB(70, 70, 74), M.Metal)
	elseif item == "clockkey" then
		extra("Rim", Vector3.new(1.1, 1.1, 0.2), CFrame.new(0, 0, 0.05), Color3.fromRGB(214, 170, 70), M.Metal)
		extra("Dial", Vector3.new(0.8, 0.8, 0.05), CFrame.new(0, 0, -0.17), Color3.fromRGB(244, 236, 214), M.SmoothPlastic)
	elseif item == "meat" then
		extra("Bone", Vector3.new(0.2, 0.2, 1.9), CFrame.new(0, 0, 0), Color3.fromRGB(230, 224, 204), M.SmoothPlastic)
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
		local name = Lang.t(s.lang or "en", "item_" .. item)
		tool.Name = if count > 1 then name .. " ×" .. count else name
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

local endRun
local dropFigure

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
	dropFigure(p)
	send(p, { type = "dead", cause = s.cause or "unknown", door = run.front })
	if #G.alivePlayers() == 0 and run.active and not run.done then
		task.spawn(endRun)
	end
end

-- ---------------------------------------------------------------------------
-- фонарик

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

-- ---------------------------------------------------------------------------
-- шкафчики

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
	if not s or not s.alive then
		return
	end
	if s.hidden == part then
		unhide(p)
		return
	end
	if s.hidden or occupied[part] then
		return
	end
	dropFigure(p)
	s.hidden = part
	occupied[part] = p
	local r = rootOf(p)
	if r then
		p.Character:PivotTo(part.CFrame * CFrame.new(0, -part.Size.Y / 2 + 3, 0.2))
		r.Anchored = true
	end
	-- глаза у самых прорезей дверцы: зал виден сквозь щели (их рисует клиент)
	p:SetAttribute("HiddenEye", part.CFrame * CFrame.new(0, math.min(1.9, part.Size.Y / 2 - 0.5), -part.Size.Z / 2 - 0.55))
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

local solveFigures

function G.use(p: Player, item: string)
	local s = players[p]
	if not s or not s.alive then
		return
	end
	if item == "flashlight" then
		setFlash(p, not s.flashOn)
	elseif item == "plant" then
		local hum = humOf(p)
		if hum and hum.Health < hum.MaxHealth - 1 and Rules.take(s.inv, "plant") then
			hum.Health = math.min(hum.MaxHealth, hum.Health + Rules.PLANT_HEAL)
		end
	elseif item == "battery" then
		if s.flash < Rules.FLASH_MAX - 1 and Rules.take(s.inv, "battery") then
			s.flash = Rules.recharge(s.flash)
			setFlash(p, s.flashOn)
		end
	elseif item == "hammer" then
		-- молотком можно разбить статую тебЯ, если подойти вплотную
		local r = rootOf(p)
		local info = r and roomOf(r.Position)
		if info and info.puzzle and not info.puzzle.solved and Entities.mimicNear(info, r.Position) and Rules.take(s.inv, "hammer") then
			solveFigures(info)
		end
	elseif item == "meat" then
		-- на арене мясо кладут на пол как приманку
		local r = rootOf(p)
		local info = r and roomOf(r.Position)
		if not (info and info.arena and G.dropBait(p, info)) then
			return
		end
	else
		return
	end
	syncTools(p)
end

-- ---------------------------------------------------------------------------
-- двери

local function descOf(n: number)
	while run.descs[0] == nil or #run.descs < n do
		local k = if run.descs[0] == nil then 0 else #run.descs + 1
		run.descs[k] = Plan.room(run.plan, k)
	end
	return run.descs[n]
end

local openDoor

local function makeDoor(info, n: number, cf: CFrame, opts)
	local m, leaves = Props.door(info.model, cf, opts.plate, opts.locked, opts.size, opts.style)
	local door = { model = m, leaves = leaves, number = n, locked = opts.locked, cf = cf, opened = false, decoy = opts.decoy, size = opts.size or "normal" }
	if opts.locked and not opts.noPick then
		local trig = Props.P(m, "LockTrigger", Vector3.new(1, 1, 1), cf * CFrame.new(1.2, 4.5, 0.6), Color3.new(0, 0, 0), M.SmoothPlastic, Props.nc({ Transparency = 1 }))
		local pr = Props.prompt(trig, "lockpick", 2.5, 7)
		door.lockPrompt = pr
		pr.Triggered:Connect(function(p)
			G.pick(p, n)
		end)
	end
	return door
end

-- створки поворачиваются на петлях (open = 1 — открыть, 0 — закрыть)
local function swing(door, open: boolean, time: number?)
	for _, leaf in door.leaves do
		local base = leaf:GetAttribute("Base")
		if typeof(base) ~= "CFrame" then
			base = leaf:GetPivot()
			leaf:SetAttribute("Base", base)
		end
		local dir = leaf:GetAttribute("Dir") or 1
		local v = Instance.new("NumberValue")
		v.Value = if open then 0 else 1
		v.Changed:Connect(function(a)
			leaf:PivotTo(base * CFrame.Angles(0, math.rad(-100) * a * dir, 0))
		end)
		local t = TweenService:Create(v, TweenInfo.new(time or 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = if open then 1 else 0 })
		t:Play()
		t.Completed:Connect(function()
			v:Destroy()
		end)
		for _, d in leaf:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Slab" then
				d.CanCollide = not open
			end
		end
	end
	sound(door.model:FindFirstChildWhichIsA("BasePart"), if open then SOUND.door else SOUND.slam, if open then 0.8 else 1.6, 0.6)
end

-- ---------------------------------------------------------------------------
-- ящики и находки

local wirePickups

-- один ящик: выдвинуть или задвинуть. Находка лежит внутри и ездит вместе с ящиком
local function toggleDrawer(info, sr, dr)
	if dr.busy then
		return
	end
	dr.busy = true
	if not dr.rolled then
		dr.rolled = true
		local slot = Props.model(dr.model, "Loot")
		if sr.key and sr.keyDrawer == dr then
			local _, part = Props.pickup(slot, dr.inside * CFrame.new(-0.5, 0, 0), "key")
			part:SetAttribute("KeyFor", sr.key)
		end
		local item, amount = Rules.loot(math.random(), run.front)
		if item ~= "nothing" then
			local _, part = Props.pickup(slot, dr.inside * CFrame.new(if sr.keyDrawer == dr then 0.6 else 0, 0, 0), item)
			if item == "coins" then
				part:SetAttribute("Amount", amount)
			end
		end
		wirePickups(info)
	end
	dr.open = not dr.open
	local base = dr.base or dr.model:GetPivot()
	dr.base = base
	local from, to = if dr.open then 0 else 1, if dr.open then 1 else 0
	local v = Instance.new("NumberValue")
	v.Value = from
	v.Changed:Connect(function(a)
		if dr.model.Parent then
			dr.model:PivotTo(base * CFrame.new(0, 0, -1.3 * a))
		end
	end)
	local t = TweenService:Create(v, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = to })
	t:Play()
	t.Completed:Connect(function()
		v:Destroy()
		dr.busy = false
	end)
	sound(dr.hit, SOUND.door, 0.5, if dr.open then 1.5 else 1.2)
end

function wirePickups(info)
	for _, d in info.model:GetDescendants() do
		if d:IsA("ProximityPrompt") and not d:GetAttribute("Wired") and d:GetAttribute("Kind") == "pick" then
			d:SetAttribute("Wired", true)
			local part = d.Parent
			d.Triggered:Connect(function(p)
				local s = players[p]
				if not s or not s.alive or not part.Parent then
					return
				end
				local item = part:GetAttribute("Item")
				if item == "key" then
					s.keys[part:GetAttribute("KeyFor")] = true
					sound(part, SOUND.pick, 0.8)
					syncTools(p)
				elseif item == "coins" then
					give(p, "coins", part:GetAttribute("Amount") or 3)
				elseif not give(p, item) then
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
		for _, dr in sr.drawers do
			local pr = dr.hit:FindFirstChildOfClass("ProximityPrompt")
			if pr and not pr:GetAttribute("Wired") then
				pr:SetAttribute("Wired", true)
				pr.Triggered:Connect(function(p)
					if G.isAlive(p) then
						toggleDrawer(info, sr, dr)
					end
				end)
			end
		end
	end
	wirePickups(info)
end

-- ---------------------------------------------------------------------------
-- зал с фигурками и тебЯ

function dropFigure(p: Player)
	local s = players[p]
	local fig = s and s.carry
	if not fig then
		return
	end
	s.carry = nil
	local w = fig.part:FindFirstChild("CarryWeld")
	if w then
		w:Destroy()
	end
	if fig.model.Parent and not fig.placed then
		fig.part.Anchored = true
		fig.model:PivotTo(fig.home)
		fig.held = false
	end
end

function solveFigures(info)
	local puzzle = info.puzzle
	if puzzle.solved then
		return
	end
	puzzle.solved = true
	Entities.crumbleMimic(info)
	info.sealed = false
	sound(info.model, SOUND.pick, 1.2, 0.7)
end

local function wireFigures(info)
	local puzzle = info.puzzle
	for _, fig in puzzle.figs do
		local pr = fig.part:FindFirstChildOfClass("ProximityPrompt")
		pr.Triggered:Connect(function(p)
			local s = players[p]
			if not s or not s.alive or s.carry or fig.held or fig.placed then
				return
			end
			local r = rootOf(p)
			if not r then
				return
			end
			-- фигурка в руках: держится перед игроком
			fig.held = true
			s.carry = fig
			fig.part.Anchored = false
			for _, d in fig.model:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = false
					d.Massless = true
					if d ~= fig.part then
						local wd = d:FindFirstChild("W") or Instance.new("WeldConstraint")
						wd.Name = "W"
						wd.Part0 = fig.part
						wd.Part1 = d
						wd.Parent = d
					end
				end
			end
			fig.model:PivotTo(r.CFrame * CFrame.new(0.9, 0.2, -1.6))
			local w = Instance.new("WeldConstraint")
			w.Name = "CarryWeld"
			w.Part0 = r
			w.Part1 = fig.part
			w.Parent = fig.part
			pr.Enabled = false
			sound(r, SOUND.pick, 0.6, 1.2)
		end)
	end
	for _, socket in puzzle.sockets do
		local pr = socket.part:FindFirstChildOfClass("ProximityPrompt")
		pr.Triggered:Connect(function(p)
			local s = players[p]
			local fig = s and s.carry
			if not fig or socket.filled or puzzle.solved then
				return
			end
			if fig.color == socket.color then
				s.carry = nil
				local w = fig.part:FindFirstChild("CarryWeld")
				if w then
					w:Destroy()
				end
				for _, d in fig.model:GetDescendants() do
					if d:IsA("BasePart") then
						d.Anchored = true
					end
				end
				fig.model:PivotTo(socket.top * CFrame.new(0, 0.15, 0))
				fig.placed = true
				socket.filled = true
				pr.Enabled = false
				puzzle.placed += 1
				sound(socket.part, SOUND.pick, 0.9, 1 + puzzle.placed * 0.08)
				if puzzle.placed >= puzzle.n then
					G.achieveAll("mimic_solved")
					solveFigures(info)
				end
			else
				-- не тот постамент: фигурка возвращается туда, где лежала
				sound(socket.part, SOUND.locked, 0.9, 0.7)
				dropFigure(p)
				for _, d in fig.model:GetDescendants() do
					if d:IsA("BasePart") then
						d.Anchored = true
					end
				end
				fig.model:PivotTo(fig.home)
				local fp = fig.part:FindFirstChildOfClass("ProximityPrompt")
				if fp then
					fp.Enabled = true
				end
			end
		end)
	end
end

-- ---------------------------------------------------------------------------
-- Монетчик

local function removeKeeper(t)
	t.paid = true
	local i = table.find(run.keepers, t)
	if i then
		table.remove(run.keepers, i)
	end
	if t.block.Parent then
		t.block:Destroy()
	end
end

-- убегает в норку (когда летит Тьма или когда получил своё)
local function keeperLeaves(t, fast: boolean)
	if t.gone then
		return
	end
	t.gone = true
	removeKeeper(t)
	local m = t.model
	for _, d in m:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d.Enabled = false
		end
	end
	local from = m:GetPivot()
	local to = t.hole * CFrame.new(0, 0, 1.6) * CFrame.Angles(0, math.pi, 0)
	task.spawn(function()
		if fast then
			-- заметил Тьму: вздрагивает и отступает на шаг, потом торопливо уходит
			for i = 1, 6 do
				if not m.Parent then
					return
				end
				m:PivotTo(from * CFrame.new(math.sin(i * 2.4) * 0.12, 0, 0.1 * i) * CFrame.Angles(0, 0, math.sin(i * 2.4) * 0.06))
				task.wait(0.05)
			end
			from = m:GetPivot()
		end
		-- идёт ровно, без прыжков: лишь слегка покачивается с ноги на ногу
		local dur = if fast then 1.1 else 2.2
		local look = CFrame.lookAt(from.Position, Vector3.new(to.Position.X, from.Position.Y, to.Position.Z))
		local t0 = os.clock()
		while m.Parent do
			local a = math.min(1, (os.clock() - t0) / dur)
			local pos = from.Position:Lerp(to.Position, a)
			local rot = if a < 0.9 then look.Rotation else look.Rotation:Lerp(to.Rotation, (a - 0.9) / 0.1)
			m:PivotTo(CFrame.new(pos) * rot * CFrame.Angles(0, 0, math.sin(a * math.pi * (if fast then 8 else 6)) * 0.05))
			if a >= 1 then
				break
			end
			task.wait()
		end
		if m.Parent then
			m:Destroy()
		end
	end)
	sound(t.holePart, SOUND.pick, 0.7, 1.8)
end

function G.fleeKeepers()
	for _, t in table.clone(run.keepers) do
		keeperLeaves(t, true)
	end
end

function G.pay(p: Player, how: string)
	local s = players[p]
	local r = rootOf(p)
	if not s or not s.alive or not r then
		return { ok = false }
	end
	local t = nil
	for _, k in run.keepers do
		if not k.paid and (k.model:GetPivot().Position - r.Position).Magnitude < 16 then
			t = k
		end
	end
	if not t then
		return { ok = false }
	end
	if how == "gold" then
		if s.coins < t.price then
			return { ok = false, error = "coins" }
		end
		s.coins -= t.price
	else
		local hum = humOf(p)
		if not hum then
			return { ok = false }
		end
		local left = Rules.afterSelfToll(hum.Health)
		send(p, { type = "fx", kind = "blood" })
		if left <= 0 then
			s.cause = "coinkeeper"
			hum.Health = 0
		else
			hum.Health = left
		end
	end
	syncTools(p)
	keeperLeaves(t, false)
	G.achieve(p, "coin_paid")
	return { ok = true }
end

-- место для норки: рядом с дверью, с той стороны, где до угла дальше
local function holeFor(info, size: string): CFrame
	local dw = Props.DOORS[size].w
	local best, bestRoom = nil, -math.huge
	for _, sgn in { -1, 1 } do
		local cf = info.doorCF * CFrame.new(sgn * (dw / 2 + 4.13), 0, 0)
		local lp = info.origin:PointToObjectSpace(cf.Position)
		local d = info.desc
		local room = math.min(d.w / 2 - math.abs(lp.X), -lp.Z, lp.Z + d.l)
		if info.desc.exit.turn == 0 then
			room = d.w / 2 - math.abs(lp.X)
		else
			room = math.min(-lp.Z, lp.Z + d.l)
		end
		if room > bestRoom then
			best, bestRoom = cf, room
		end
	end
	return best
end

-- ---------------------------------------------------------------------------
-- кодовый замок, арена, лифт

local function panelDone(panel: BasePart)
	panel.Color = Color3.fromRGB(60, 200, 90)
	panel.Material = M.Neon
	local pr = panel:FindFirstChildOfClass("ProximityPrompt")
	if pr then
		pr.Enabled = false
	end
	sound(panel, SOUND.pick, 1.2, 0.8)
end

local function wireCode(info)
	info.codePanel:FindFirstChildOfClass("ProximityPrompt").Triggered:Connect(function(p)
		if G.isAlive(p) and not info.locks.code then
			send(p, { type = "keypad", order = info.code.order })
		end
	end)
	info.orderPanel:FindFirstChildOfClass("ProximityPrompt").Triggered:Connect(function(p)
		if G.isAlive(p) and not info.locks.order then
			send(p, { type = "order", items = info.exhibits })
		end
	end)
end

local function nearPanel(p: Player, panel: BasePart): boolean
	local r = rootOf(p)
	return r ~= nil and G.isAlive(p) and (panel.Position - r.Position).Magnitude < 18
end

-- замок с цифрами
function G.code(p: Player, text: string)
	local info = run.rooms[Rules.CODE_ROOM]
	if not info or info.locks.code or not nearPanel(p, info.codePanel) then
		return { ok = false }
	end
	if text ~= info.code.text then
		sound(info.codePanel, SOUND.locked, 1, 0.6)
		return { ok = false }
	end
	info.locks.code = true
	info.sealed = not (info.locks.code and info.locks.order)
	panelDone(info.codePanel)
	return { ok = true }
end

-- замок с порядком экспонатов: list — номера экспонатов в том порядке, как их нажали
function G.order(p: Player, list)
	local info = run.rooms[Rules.CODE_ROOM]
	if not info or info.locks.order or not nearPanel(p, info.orderPanel) or type(list) ~= "table" then
		return { ok = false }
	end
	for i = 1, 8 do
		if list[i] ~= info.code.sequence[i] then
			sound(info.orderPanel, SOUND.locked, 1, 0.6)
			return { ok = false }
		end
	end
	info.locks.order = true
	info.sealed = not (info.locks.code and info.locks.order)
	panelDone(info.orderPanel)
	return { ok = true }
end

function G.eatBait(info)
	local a = info.arena
	if a.meat then
		a.meat:Destroy()
		a.meat = nil
	end
end

-- Колосс повержен: из обломков выкатывается ключ-часы
function G.bossDead(info, pos: Vector3?)
	local a = info.arena
	for _, p in G.alivePlayers() do
		G.achieve(p, "colossus_down")
		give(p, "coins", 40)
	end
	G.sendAll({ type = "fx", kind = "calm" })
	local at = pos or a.zone.Position
	local cf = CFrame.new(Vector3.new(at.X, a.floorY + 0.1, at.Z))
	local pm = Props.pickup(info.model, cf, "clockkey")
	local _ = pm
	wirePickups(info)
end

-- мясо можно положить где угодно на полу арены
local function dropBait(p: Player, info): boolean
	local a = info.arena
	local r = rootOf(p)
	local s = players[p]
	if not r or not s then
		return false
	end
	if r.Position.Y > a.floorY + 6 then
		-- с галереи мясо не бросить
		toast(p, "BaitFloor")
		return false
	end
	if not Rules.take(s.inv, "meat") then
		return false
	end
	G.eatBait(info)
	local pos = r.Position + r.CFrame.LookVector * 2.5
	local cf = CFrame.new(Vector3.new(pos.X, a.floorY, pos.Z)) * CFrame.Angles(0, math.random() * 6, 0)
	local mm = Props.model(info.model, "Bait")
	Props.P(mm, "Meat", Vector3.new(1.6, 0.7, 1.1), cf * CFrame.new(0, 0.35, 0), Color3.fromRGB(150, 40, 40), M.SmoothPlastic, Props.nc())
	Props.P(mm, "Bone", Vector3.new(2.3, 0.22, 0.22), cf * CFrame.new(0, 0.4, 0), Color3.fromRGB(230, 224, 204), M.SmoothPlastic, Props.nc())
	a.meat = mm
	sound(r, SOUND.slam, 0.4, 1.4)
	Entities.bait(cf.Position + Vector3.new(0, 3, 0))
	return true
end
G.dropBait = dropBait

local function arenaHas(p: Player, item: string): boolean
	local s = players[p]
	return s ~= nil and s.alive and (s.inv[item] or 0) > 0
end

-- люстра едет вверх или вниз (down: 0 — наверху, 1 — внизу)
local function moveChandelier(info, toDown: number, time: number, style)
	local ch = info.arena.chand
	ch.busy = true
	Special.drawBeam(info)
	local v = Instance.new("NumberValue")
	v.Value = ch.down or 0
	v.Changed:Connect(function(x)
		Special.placeChandelier(info, x)
	end)
	local t = TweenService:Create(v, TweenInfo.new(time, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = toDown })
	t:Play()
	t.Completed:Wait()
	v:Destroy()
	ch.down = toDown
	ch.up = toDown == 0
	ch.busy = false
	ch.slotPrompt.Enabled = toDown == 1 and ch.lens == nil
	Special.drawBeam(info)
end

local function wireArena(info)
	local a = info.arena
	local A = Rules.ARENA
	-- зеркала: держишь кнопку — зеркало плавно поворачивается; когда луч ловит
	-- следующее зеркало или люстру, оно щёлкает и встаёт точно
	for k, mr in a.mirrors do
		for _, pr in mr.glass:GetChildren() do
			if pr:IsA("ProximityPrompt") then
				local dir = if pr.Name == "turnl" then 1 else -1
				pr.PromptButtonHoldBegan:Connect(function(p)
					if G.isAlive(p) and not mr.turning then
						mr.turning = dir
						mr.by = p
						mr.noiseAt = 0
					end
				end)
				pr.PromptButtonHoldEnded:Connect(function(p)
					if mr.by == p then
						mr.turning = nil
						mr.by = nil
					end
				end)
			end
		end
		mr.k = k
	end
	local drawAt = 0
	a.conn = RunService.Heartbeat:Connect(function(dt)
		if not info.model.Parent then
			a.conn:Disconnect()
			return
		end
		local now = os.clock()
		for k, mr in a.mirrors do
			if mr.turning then
				if not G.isAlive(mr.by) then
					mr.turning = nil
					continue
				end
				local before = #(a.chain or {})
				mr.angle += mr.turning * math.rad(A.turn) * dt
				Special.turnMirror(info, k)
				if now - mr.noiseAt > 1 then
					mr.noiseAt = now
					sound(mr.glass, SOUND.switch, 0.25, 0.5)
					Entities.noise(mr.cf.Position, 22)
				end
				if now - drawAt > 0.06 then
					drawAt = now
					local chain, hit = Special.drawBeam(info)
					-- луч поймал что-то новое за этим зеркалом: щелчок и точная установка
					local idx = table.find(chain, k)
					if idx and (#chain > before or hit) and (idx < #chain or hit) then
						local cur = {}
						for j, m2 in a.mirrors do
							cur[j] = m2.angle
						end
						local path = Rules.beam(cur)
						-- нормаль = направление «наружу» минус направление «внутрь»
						local pi_, po = path[idx], path[idx + 2]
						local pm = path[idx + 1]
						if pi_ and po and pm then
							local ix, iz = pm.x - pi_.x, pm.z - pi_.z
							local il = math.sqrt(ix * ix + iz * iz)
							local ox, oz = po.x - pm.x, po.z - pm.z
							local ol = math.sqrt(ox * ox + oz * oz)
							mr.angle = math.atan2(oz / ol - iz / il, ox / ol - ix / il)
							Special.turnMirror(info, k)
							Special.drawBeam(info)
						end
						mr.turning = nil
						sound(mr.glass, SOUND.locked, 1, 1.2)
					end
				end
			end
		end
	end)
	-- лебёдка: опустить/поднять люстру
	a.drum:FindFirstChildOfClass("ProximityPrompt").Triggered:Connect(function(p)
		local ch = a.chand
		if not G.isAlive(p) or ch.busy or ch.fallen then
			return
		end
		sound(a.drum, SOUND.switch, 1, 0.6)
		Entities.noise(a.drum.Position, 30)
		task.spawn(moveChandelier, info, if ch.up then 1 else 0, 5)
	end)
	-- зеркальце в люстру
	a.chand.slotPrompt.Triggered:Connect(function(p)
		local ch = a.chand
		local s = players[p]
		if not s or not s.alive or ch.lens or not ch.down or ch.down < 1 then
			return
		end
		if not Rules.take(s.inv, "lens") then
			toast(p, "NeedLens")
			return
		end
		syncTools(p)
		ch.lens = Props.C(ch.model, "Lens", 0.12, 2, ch.slot.CFrame, Color3.fromRGB(200, 220, 230), M.Glass, { Reflectance = 0.7, CanCollide = false })
		ch.slot.Transparency = 0
		ch.slotPrompt.Enabled = false
		sound(ch.slot, SOUND.pick, 1)
	end)
	-- тормозной штырь высоко на стене: выбить длинным шестом
	local pinPrompt = a.pin:FindFirstChildOfClass("ProximityPrompt")
	pinPrompt.Triggered:Connect(function(p)
		if not G.isAlive(p) or a.pinOut then
			return
		end
		if not arenaHas(p, "pole") then
			toast(p, "NeedPole")
			return
		end
		local r = rootOf(p)
		a.pinOut = true
		pinPrompt.Enabled = false
		-- шест поднимается от рук к штырю и выбивает его
		local from = r.Position + Vector3.new(0, 1.5, 0)
		local pole = Props.rod(info.model, "PoleSwing", from, from + (a.pin.Position - from).Unit * 2, 0.3, Props.WOOD, M.Wood, Props.nc())
		local target = (a.pin.Position - from)
		local steps = 12
		for i = 1, steps do
			local tip = from + target * (i / steps)
			local len = (tip - from).Magnitude
			pole.Size = Vector3.new(0.3, 0.3, len)
			pole.CFrame = CFrame.lookAt((from + tip) / 2, tip)
			task.wait(0.04)
		end
		sound(a.pin, SOUND.slam, 1.2, 1.3)
		a.pin.Anchored = false
		a.pin.CanCollide = true
		a.pin.AssemblyLinearVelocity = Vector3.new(0, 6, 0) + (a.pin.Position - from).Unit * 8
		Debris:AddItem(a.pin, 8)
		task.wait(0.3)
		pole:Destroy()
		Entities.noise(a.pin.Position, 30)
	end)
	-- рычаг: сбросить люстру
	a.lever:FindFirstChildOfClass("ProximityPrompt").Triggered:Connect(function(p)
		local ch = a.chand
		if not G.isAlive(p) or ch.busy or ch.fallen then
			return
		end
		if not a.pinOut then
			sound(a.lever, SOUND.locked, 1, 0.6)
			toast(p, "BrakeHolds")
			return
		end
		if not ch.up then
			sound(a.lever, SOUND.locked, 1, 0.6)
			return
		end
		a.lever.CFrame = a.lever.CFrame * CFrame.Angles(0, 0, math.rad(-50))
		sound(a.drum, SOUND.slam, 1.4, 0.5)
		task.spawn(function()
			moveChandelier(info, 1.6, 0.7, Enum.EasingStyle.Quad)
			ch.fallen = true
			local pos = ch.pos
			sound(a.spot, SOUND.slam, 2.2, 0.35)
			G.sendAll({ type = "fx", kind = "shake" })
			local hit = Entities.chandelierHit(Vector3.new(pos.X, a.floorY, pos.Z), A.drop)
			if not hit then
				-- мимо: грохот слышно во всём зале, люстру поднимает лебёдка
				Entities.noise(pos, 200)
				task.wait(7)
				if info.model.Parent then
					ch.fallen = false
					moveChandelier(info, 0, 6)
					a.lever.CFrame = a.lever.CFrame * CFrame.Angles(0, 0, math.rad(50))
				end
			end
		end)
	end)
	-- холодильная камера: открывается ключом на 5 секунд и сама захлопывается
	local cold = a.cold
	cold.trigger:FindFirstChildOfClass("ProximityPrompt").Triggered:Connect(function(p)
		if not G.isAlive(p) or cold.open then
			return
		end
		if not arenaHas(p, "coldkey") then
			sound(cold.trigger, SOUND.locked, 1, 0.8)
			toast(p, "Locked")
			return
		end
		cold.open = true
		swing(cold, true, 0.8)
		task.delay(A.coldOpen, function()
			if info.model.Parent then
				swing(cold, false, 0.5)
				cold.open = false
			end
		end)
	end)
	-- механизм выхода: вставить ключ-часы и перевести стрелки как на остановленных часах
	local mech = a.mech
	local hourPr = mech.hourKnob:FindFirstChildOfClass("ProximityPrompt")
	local minPr = mech.minuteKnob:FindFirstChildOfClass("ProximityPrompt")
	mech.keyhole:FindFirstChildOfClass("ProximityPrompt").Triggered:Connect(function(p)
		local s = players[p]
		if not s or not s.alive or mech.inserted then
			return
		end
		if not Rules.take(s.inv, "clockkey") then
			sound(mech.keyhole, SOUND.locked, 1, 0.8)
			toast(p, "NeedClockKey")
			return
		end
		syncTools(p)
		mech.inserted = true
		Props.clockKey(info.model, mech.keyhole.CFrame * CFrame.new(0, 0, -0.5) * CFrame.Angles(math.pi / 2, 0, 0))
		mech.keyhole:FindFirstChildOfClass("ProximityPrompt").Enabled = false
		hourPr.Enabled = true
		minPr.Enabled = true
		sound(mech.keyhole, SOUND.switch, 1)
	end)
	local function step(hand: string)
		if not mech.inserted or mech.done then
			return
		end
		mech.h, mech.m = Rules.clockStep(mech.h, mech.m, hand)
		Special.setMechHands(info)
		sound(mech.keyhole, SOUND.switch, 0.6, 1.4)
		if mech.h == a.clock.h and mech.m == a.clock.m then
			mech.done = true
			hourPr.Enabled = false
			minPr.Enabled = false
			sound(mech.keyhole, SOUND.pick, 1.2, 0.8)
			info.sealed = false
			G.sendAll({ type = "toast", key = "ClockOpen" })
		end
	end
	hourPr.Triggered:Connect(function(p)
		if G.isAlive(p) then
			step("hour")
		end
	end)
	minPr.Triggered:Connect(function(p)
		if G.isAlive(p) then
			step("minute")
		end
	end)
end

local function wireLift(info)
	info.model:FindFirstChild("CallButton"):FindFirstChildOfClass("ProximityPrompt").Triggered:Connect(function(p)
		sound(info.model:FindFirstChild("CallButton"), SOUND.locked, 1, 0.5)
		send(p, { type = "voice", key = "LiftLocked" })
	end)
	for _, lv in info.levers do
		lv.handle:FindFirstChildOfClass("ProximityPrompt").Triggered:Connect(function(p)
			if not G.isAlive(p) or info.gate.opened then
				return
			end
			lv.on = not lv.on
			lv.model:PivotTo(lv.base * CFrame.Angles(math.rad(if lv.on then 35 else -35), 0, 0))
			sound(lv.handle, SOUND.switch, 1)
			for _, l in info.levers do
				if l.on ~= l.need then
					return
				end
			end
			info.gate.opened = true
			swing(info.gate, true, 1.2)
		end)
	end
end

-- ---------------------------------------------------------------------------
-- комнаты

local function buildRoom(n: number)
	if run.rooms[n] or n > Rules.CHAPTER then
		return run.rooms[n]
	end
	local d = descOf(n)
	local prev = if n > 0 then (run.rooms[n - 1] or buildRoom(n - 1)) else nil
	local origin = if prev then prev.doorCF else CFrame.new(0, 0, 0)
	local rand = Plan.rng(run.seed + n * 7919)
	local info
	if d.kind == "codehall" then
		info = Special.codeHall(world, d, origin, rand, prev)
	elseif d.kind == "arena" then
		info = Special.arena(world, d, origin, rand, prev)
	elseif d.kind == "lifthall" then
		info = Special.liftHall(world, d, origin, rand, prev)
	elseif d.kind == "final" then
		info = Special.final(world, d, origin, rand, prev)
	else
		info = Builder.build(world, d, origin, prev, rand)
	end
	info.n = n
	info.doorCF = info.exitCF
	run.rooms[n] = info
	if d.kind == "figures" then
		Special.figures(info, rand)
		info.sealed = true
		wireFigures(info)
		task.spawn(Entities.spawnMimic, info)
	end
	if d.kind ~= "final" then
		local special = d.kind == "codehall"
		local size = if d.kind == "lifthall" then "normal" else d.exitSize
		-- вид двери: служебные и технические — маленькие, стальные — в служебных и старых залах
		local style = nil
		if special then
			style = "code"
		elseif d.kind == "figures" then
			style = "puzzle"
		elseif size == "small" then
			style = if n % 2 == 0 then "tech" else "service"
		elseif size ~= "grand" and (d.kind == "storage" or d.kind == "tech" or d.kind == "mechanisms" or n % 5 == 0) then
			style = "metal"
		end
		info.door = makeDoor(info, n + 1, info.doorCF, { plate = Rules.plate(n + 1), locked = d.locked == true or special, size = size, noPick = special, style = style })
		info.decoys = {}
		for _, cf in info.decoyCFs do
			table.insert(info.decoys, makeDoor(info, n + 1, cf, { plate = Rules.plate(n + 1), decoy = true }))
		end
		if d.kind == "lifthall" then
			-- последнюю дверь открывают сами: удержанием кнопки
			local trig = Props.P(info.door.model, "HoldTrigger", Vector3.new(1, 1, 1), info.doorCF * CFrame.new(0, 4, 0.8), Color3.new(0, 0, 0), M.SmoothPlastic, Props.nc({ Transparency = 1 }))
			local pr = Props.prompt(trig, "open", 2.5, 8)
			info.door.hold = pr
			pr.Triggered:Connect(function(p)
				G.finale(p)
			end)
		end
	end
	if d.locked then
		if #info.searchables > 0 then
			-- ключ лежит в одном случайном ящике этого зала
			local sr = info.searchables[math.floor(rand() * #info.searchables) + 1]
			sr.key = n + 1
			sr.keyDrawer = sr.drawers[math.floor(rand() * #sr.drawers) + 1]
		else
			-- ящиков нет: ключ лежит на полу у дальней стены
			local side = if n % 2 == 0 then 1 else -1
			local cf = origin * CFrame.new(side * (d.w / 2 - 3.2), Builder.floorAt(d, -d.l + 3), -d.l + 3.4)
			local _, part = Props.pickup(info.model, cf, "key")
			part:SetAttribute("KeyFor", n + 1)
		end
	end
	if d.coin then
		local price = Rules.coinPrice(n + 1)
		local hole = holeFor(info, d.exitSize)
		local keeper, pr, block, holeModel = Special.coinKeeper(info.model, info.doorCF * CFrame.new(0, 0, 3) * CFrame.Angles(0, math.pi, 0), price, hole)
		info.toll = { model = keeper, price = price, paid = false, base = keeper:GetPivot(), block = block, hole = hole, holePart = holeModel:FindFirstChildWhichIsA("BasePart") }
		table.insert(run.keepers, info.toll)
		pr.Triggered:Connect(function(p)
			if G.isAlive(p) and not info.toll.paid then
				G.discover(p, "coinkeeper")
				send(p, { type = "coin", price = price })
			end
		end)
	end
	wireRoom(info)
	if d.kind == "codehall" then
		wireCode(info)
	elseif d.kind == "arena" then
		wireArena(info)
		task.spawn(Entities.spawnColossus, info)
	elseif d.kind == "lifthall" then
		wireLift(info)
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
	for p, s in players do
		if s.carry and s.carry.model:IsDescendantOf(info.model) then
			dropFigure(p)
		end
	end
	if info.toll and not info.toll.paid then
		removeKeeper(info.toll)
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
					if r and G.inRoom(info, r.Position) then
						unhide(p)
						teleport(p, target.origin * CFrame.new(0, 3, -4))
					end
				end
			end
			destroyRoom(n)
		end
	end
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
	if door.hold then
		door.hold.Enabled = false
	end
	swing(door, true)
	run.front = math.max(run.front, n)
	workspace:SetAttribute("Door", run.front)
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
			s.coins += Rules.COINS_PER_DOOR
			syncTools(p)
		end
	end
	local entered = buildRoom(n)
	buildRoom(n + 1)
	cleanup()
	workspace:SetAttribute("Light", entered.desc.light or 1)
	Entities.noise(door.model:GetPivot().Position, 50)
	if entered.desc.kind == "arena" then
		-- сцена: огромная статуя сходит с постамента
		local model = entered.model:FindFirstChild("Colossus")
		G.sendAll({ type = "cutscene", kind = "boss", focus = entered.arena.spawn, model = model })
		for _, p in G.alivePlayers() do
			G.discover(p, "colossus")
			G.achieve(p, "door50")
		end
		task.delay(5.5, Entities.wakeColossus)
	elseif entered.desc.kind == "voidhall" then
		for _, p in G.alivePlayers() do
			G.discover(p, "void")
		end
	end
	if entered.desc.dark and not force then
		task.delay(2 + math.random() * 4, function()
			if run.active and not run.done then
				Entities.darkness()
			end
		end)
	end
	return true
end
G.openDoor = openDoor

-- Тьма долетела до последней двери: открывает её, если это обычная дверь
function G.darkOpen()
	local n = run.front + 1
	local info = run.rooms[run.front]
	if not info or not info.door or info.door.opened or info.door.hold or info.sealed or info.door.locked or Rules.isSpecial(n) or Rules.isSpecial(run.front) then
		return nil
	end
	if not run.active or run.done then
		return nil
	end
	openDoor(n, true)
	return run.rooms[n]
end

local lockedToastAt: { [Player]: number } = {}

function G.tryOpen(p: Player, n: number)
	local s = players[p]
	if not s or not s.alive or s.hidden then
		return
	end
	local info = run.rooms[n - 1]
	if not info or not info.door or info.door.opened or info.door.hold or info.sealed then
		return
	end
	if info.toll and not info.toll.paid then
		return
	end
	if info.door.locked then
		if s.keys[n] then
			s.keys[n] = nil
			syncTools(p)
		else
			local now = os.clock()
			if now - (lockedToastAt[p] or 0) > 4 then
				lockedToastAt[p] = now
				sound(info.door.model:FindFirstChildWhichIsA("BasePart"), SOUND.locked, 0.8)
				toast(p, "Locked")
			end
			return
		end
	end
	openDoor(n)
end

function G.pick(p: Player, n: number)
	local s = players[p]
	local info = run.rooms[n - 1]
	if not s or not s.alive or not info or not info.door or info.door.opened or info.sealed then
		return
	end
	if Rules.take(s.inv, "lockpick") then
		syncTools(p)
		openDoor(n)
	end
end

-- ложная дверь: глюк, и игрок оказывается у настоящей (или в середине зала)
function G.decoy(p: Player, info)
	local s = players[p]
	if not s or not s.alive then
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
	local blocked = info.sealed or (info.door.locked and not s.keys[n]) or (info.toll and not info.toll.paid)
	if blocked or not G.isAlive(p) then
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

-- дверь 100: открывается, все входят, дверь захлопывается; дальше — заброшенный зал
function G.finale(p: Player)
	local info = run.rooms[Rules.LIFT_ROOM]
	if not G.isAlive(p) or not info or info.door.opened then
		return
	end
	openDoor(Rules.FINAL_ROOM, true)
	G.achieveAll("door100")
	local final = run.rooms[Rules.FINAL_ROOM]
	G.sendAll({ type = "cutscene", kind = "final", door = info.doorCF })
	task.wait(2.4)
	local k = 0
	for _, q in G.alivePlayers() do
		k += 1
		unhide(q)
		teleport(q, final.origin * CFrame.new(((k - 1) % 3 - 1) * 3, 3, -8 - math.floor((k - 1) / 3) * 3))
	end
	swing(info.door, false, 0.25)
	run.done = true
	task.wait(9)
	for _, q in G.alivePlayers() do
		Records.complete(q)
		G.achieve(q, "finale")
		send(q, { type = "tbc" })
	end
end

-- ---------------------------------------------------------------------------
-- начало и конец забега

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
	s.carry = nil
	for _, t in s.tools do
		if t.Parent then
			t:Destroy()
		end
	end
	s.tools = {}
	p:SetAttribute("Alive", true)
	p:SetAttribute("HiddenEye", nil)
	p:SetAttribute("Sneaking", false)
end

local function loadCharacter(p: Player, cf: CFrame, inRun: boolean)
	resetPlayer(p)
	p:LoadCharacter()
	local char = p.Character or p.CharacterAdded:Wait()
	char:WaitForChild("HumanoidRootPart", 5)
	-- персонаж чуть крупнее обычного: двери, витрины и шкафчики ему по росту
	pcall(function()
		char:ScaleTo(1.2)
	end)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = Rules.SPEED.walk
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
	run.done = false
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

-- у закрывшихся входных дверей, лицом в музей
local function startPoint(): CFrame
	local start = run.rooms[0]
	return start.origin * CFrame.new(math.random(-3, 3), 3, -5 - math.random(0, 2))
end

local function toLobby(p: Player)
	if RunService:IsStudio() then
		return
	end
	pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { p })
	end)
end

function endRun()
	if run.ending then
		return
	end
	run.ending = true
	G.sendAll({ type = "results", door = run.front })
	task.wait(10)
	if RunService:IsStudio() then
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
function G.startHere()
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
end

-- уйти группой в отдельный сервер забега
local function goIn(group: { Player })
	if RunService:IsStudio() then
		G.startHere()
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
			warn("[Museum] teleport: " .. tostring(err))
			for _, p in group do
				send(p, { type = "enterFailed" })
				teleport(p, lobby.spawn)
			end
		end
	end)
end

-- вход в музей из лобби: кто стоит во тьме за дверями три секунды, уходит в забег
local enterAt = nil
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
		enterAt = nil
		return
	end
	local now = os.clock()
	if not enterAt then
		enterAt = now + 3
		for _, p in inside do
			send(p, { type = "enter" })
		end
	end
	if now < enterAt then
		return
	end
	enterAt = nil
	local group = {}
	for i = 1, math.min(4, #inside) do
		table.insert(group, inside[i])
	end
	goIn(group)
end

-- ---------------------------------------------------------------------------

function G.init()
	Players.CharacterAutoLoads = false
	event = Remotes.event("Game")
	world = Instance.new("Folder")
	world.Name = "Museum"
	world.Parent = workspace
	Records.init()
	Entities.init(G)
	workspace:SetAttribute("Mode", G.mode)
	if G.mode == "run" then
		startRun()
	else
		lobby = Special.lobby(world)
		-- кнопка у приоткрытых дверей: войти сразу (вместе с теми, кто стоит рядом)
		local going = false
		lobby.enter.Triggered:Connect(function(p)
			if going or not rootOf(p) then
				return
			end
			going = true
			local group = { p }
			local door = lobby.enter.Parent.Position
			for q in players do
				local r = rootOf(q)
				if q ~= p and r and #group < 4 and (r.Position - door).Magnitude < 16 then
					table.insert(group, q)
				end
			end
			for _, q in group do
				send(q, { type = "enter" })
			end
			task.delay(1.2, function()
				goIn(group)
				going = false
			end)
		end)
		lobby.ach.Triggered:Connect(function(p)
			send(p, { type = "openAch" })
		end)
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
		dropFigure(p)
		players[p] = nil
		lockedToastAt[p] = nil
		Records.forget(p)
		if G.mode == "run" and run.active and not run.done and #G.alivePlayers() == 0 and #Players:GetPlayers() > 1 then
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
		elseif action == "Pay" and (arg == "gold" or arg == "self") then
			return G.pay(p, arg)
		elseif action == "Code" and type(arg) == "string" and #arg <= 8 then
			return G.code(p, arg)
		elseif action == "Order" then
			return G.order(p, arg)
		elseif action == "Journal" then
			return { ok = true, journal = Records.journal(p), ach = Records.achievements(p) }
		elseif action == "Lobby" then
			-- вернуться на улицу можно только после смерти или в конце локации
			if not s.alive or run.done or G.mode == "lobby" then
				toLobby(p)
			end
			return { ok = true }
		elseif action == "Status" then
			syncTools(p)
			return { ok = true, best = Records.get(p), mode = G.mode }
		end
		return { ok = false }
	end

	task.spawn(function()
		local t = 0
		while true do
			local dt = task.wait(0.15)
			t += dt
			pcall(lobbyStep)
			if G.mode == "run" and run.active then
				local info = run.rooms[run.front]
				for _, p in G.alivePlayers() do
					local s = players[p]
					local r = rootOf(p)
					if r and not s.hidden then
						if info and info.door and not info.door.opened and not run.done then
							local hw = Props.DOORS[info.door.size].w / 2 + 1.5
							local lp = info.door.cf:PointToObjectSpace(r.Position)
							if lp.Z > -0.5 and lp.Z < 7 and math.abs(lp.X) < hw and lp.Y > -1 and lp.Y < 10 then
								G.tryOpen(p, info.n + 1)
							end
							for _, dc in info.decoys or {} do
								local dp = dc.cf:PointToObjectSpace(r.Position)
								if dp.Z > -0.5 and dp.Z < 3.5 and math.abs(dp.X) < 3 and dp.Y > -1 and dp.Y < 8 then
									task.spawn(G.decoy, p, info)
								end
							end
						end
						if s.flashOn then
							s.flash = Rules.drain(s.flash, dt, true)
							if s.flash <= 0 then
								setFlash(p, false)
							else
								p:SetAttribute("Flash", math.ceil(s.flash))
							end
						end
						-- упал: из пролома в пустоту — гибель, иначе возврат к последней двери
						local here = roomOf(r.Position)
						if here then
							s.lastKind = here.desc.kind
							s.lastY = here.origin.Y + math.min(0, here.desc.dy)
						end
						local floorY = if s.lastKind == "lifthall" then r.Position.Y - 1 else (s.lastY or r.Position.Y)
						if not here and r.Position.Y < floorY - 30 then
							if s.lastKind == "voidhall" then
								G.kill(p, "void")
							else
								teleport(p, frontSpawn())
							end
						end
					end
				end
				for _, k in run.keepers do
					if not k.paid and k.model.Parent then
						-- стоит строго: едва заметно переносит вес и постукивает тростью
						k.model:PivotTo(k.base * CFrame.Angles(0, 0, math.sin(t * 0.9) * 0.025))
					end
				end
			end
		end
	end)
end

return G
