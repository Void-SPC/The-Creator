--!nonstrict
-- Игра «The Castle»: роли, король и трон, голод и жажда, инвентарь, оружие и темница,
-- стража короля, казино, магазин, тайный ход, времена года. Все права проверяются здесь

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Rules = require(Shared.CastleRules)
local Remotes = require(Shared.Roblox.Remotes)

local Builder = require(script.Parent.CastleBuilder)
local Seasons = require(script.Parent.Seasons)
local Npc = require(script.Parent.Npc)
local Outfits = require(script.Parent.Outfits)
local Statue = require(script.Parent.Parent.Statue)
local CurrencyService = require(script.Parent.Parent.CurrencyService)

local G = {}

local SOUND = {
	slash = "rbxasset://sounds/swordslash.wav",
	unsheath = "rbxasset://sounds/unsheath.wav",
	eat = "rbxasset://sounds/action_get_up.mp3",
	coin = "rbxasset://sounds/electronicpingshort.wav",
	stone = "rbxasset://sounds/action_falling.mp3",
	click = "rbxasset://sounds/clickfast.wav",
	chime = "rbxasset://sounds/electronicpingshort.wav",
}

local state = {
	players = {} :: { [Player]: any },
	king = nil :: Player?,
	minionTarget = nil :: Player?,
	lastSummon = nil :: number?,
	cells = {} :: { [number]: Player },
	passage = false,
	gates = true,
	world = { season = "summer", weather = "Clear", needs = true, pvp = true, guardsPassage = false },
	clockBase = 9,
	clockAt = 0,
}
G.state = state

local event: RemoteEvent
local store: any
local npcFolder: Folder
local decor: Folder
local kingStatue: Model? = nil
local dummies = {}

-- ---------------------------------------------------------------------------
-- сообщения клиентам (каждый переводит ключи на свой язык)

local function send(p: Player, msg)
	if p.Parent then
		event:FireClient(p, msg)
	end
end

local function sendAll(msg)
	for p in state.players do
		send(p, msg)
	end
end

local function toast(p: Player, key: string, ...)
	send(p, { type = "toast", key = key, args = { ... } })
end
G.toast = toast

local function announce(key: string?, text: string?, ...)
	sendAll({ type = "announce", key = key, text = text, args = { ... } })
end
G.announce = announce

local function playSound(at: Instance?, id: string, volume: number?)
	if not at then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.RollOffMaxDistance = 60
	s.Parent = at
	s:Play()
	Debris:AddItem(s, 4)
end
G.playSound = playSound

local function rootOf(p: Player): BasePart?
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end
local function humOf(p: Player): Humanoid?
	return p.Character and p.Character:FindFirstChildOfClass("Humanoid")
end
G.rootOf = rootOf
G.humOf = humOf

local function teleport(p: Player, cf: CFrame)
	local char = p.Character
	if not char then
		return
	end
	local hum = humOf(p)
	if hum and hum.SeatPart then
		hum.Sit = false
		task.wait()
	end
	local r = rootOf(p)
	if r then
		r.AssemblyLinearVelocity = Vector3.zero
	end
	-- при потоковой загрузке мира сначала подгружаем место назначения
	pcall(function()
		p:RequestStreamAroundAsync(cf.Position, 3)
	end)
	char:PivotTo(cf + Vector3.new(math.random(-1, 1), 0, math.random(-1, 1)))
end
G.teleport = teleport

-- ---------------------------------------------------------------------------
-- состояние игрока: атрибуты на объекте Player видит его клиент (и только чтение)

local function hasBackpack(info): boolean
	return info.backpackItem == true or (info.owned and info.owned.backpack == true)
end

local function worn(info)
	local w = table.clone(info.worn or {})
	if info.backpackItem then
		w.backpack = true
	end
	return w
end

local function sync(p: Player)
	local info = state.players[p]
	if not info then
		p:SetAttribute("InCastle", false)
		return
	end
	p:SetAttribute("InCastle", true)
	p:SetAttribute("CastleRole", info.role)
	p:SetAttribute("Food", math.floor(info.food + 0.5))
	p:SetAttribute("Drink", math.floor(info.drink + 0.5))
	p:SetAttribute("Inv", table.concat(info.inv, ","))
	p:SetAttribute("Slots", Rules.capacity(hasBackpack(info)))
	p:SetAttribute("Jailed", info.jailed ~= nil)
	local owned, wornList = {}, {}
	for id in info.owned do
		table.insert(owned, id)
	end
	for id in info.worn do
		table.insert(wornList, id)
	end
	p:SetAttribute("Owned", table.concat(owned, ","))
	p:SetAttribute("Worn", table.concat(wornList, ","))
end
G.sync = sync

local function syncWorld()
	workspace:SetAttribute("CastleSeason", state.world.season)
	workspace:SetAttribute("CastleWeather", state.world.weather)
	workspace:SetAttribute("CastleNeeds", state.world.needs)
	workspace:SetAttribute("CastlePvp", state.world.pvp)
	workspace:SetAttribute("CastlePassage", state.passage)
	workspace:SetAttribute("CastleGuardsPassage", state.world.guardsPassage)
	workspace:SetAttribute("CastleKing", if state.king then state.king.UserId else 0)
	workspace:SetAttribute("CastleKingName", if state.king then state.king.DisplayName else "")
	workspace:SetAttribute("CastleMinions", Npc.aliveCount())
	workspace:SetAttribute("CastleSummonAt", state.lastSummon or 0)
	local counts = {}
	for _, info in state.players do
		counts[info.role] = (counts[info.role] or 0) + 1
	end
	for _, r in Rules.ROLE_ORDER do
		workspace:SetAttribute("CastleCount_" .. r, counts[r] or 0)
	end
end
G.syncWorld = syncWorld

-- ---------------------------------------------------------------------------
-- профиль: купленные украшения, надетое, язык, настройки

local function profileKey(p: Player)
	return string.format("u%d:castle", p.UserId)
end

local function saveProfile(p: Player)
	local info = state.players[p]
	local prof = G.profiles[p]
	if not prof or not prof.loaded then
		return
	end
	if info then
		prof.owned = info.owned
		prof.worn = info.worn
	end
	local data = { owned = prof.owned, worn = prof.worn, lang = prof.lang, settings = prof.settings }
	pcall(function()
		store:_update(profileKey(p), function()
			return data
		end)
	end)
	prof.dirty = false
end

G.profiles = {} :: { [Player]: any }

local function markDirty(p: Player)
	local prof = G.profiles[p]
	if prof then
		prof.dirty = true
	end
end
G.markDirty = markDirty

local dress -- объявлено ниже

local function loadProfile(p: Player)
	local prof = { owned = {}, worn = {}, lang = nil, settings = nil, loaded = false }
	G.profiles[p] = prof
	for _ = 1, 3 do
		local ok, rec = store:_get(profileKey(p))
		if ok then
			if type(rec) == "table" then
				prof.owned = type(rec.owned) == "table" and rec.owned or {}
				prof.worn = type(rec.worn) == "table" and rec.worn or {}
				prof.lang = rec.lang
				prof.settings = rec.settings
			end
			prof.loaded = true
			local info = state.players[p]
			if info then
				-- профиль пришёл после входа: купленное становится видно сразу
				for id in info.owned do
					prof.owned[id] = true
				end
				info.owned, info.worn = prof.owned, prof.worn
				dress(p)
				sync(p)
			end
			break
		end
		task.wait(2)
	end
	return prof
end

-- ---------------------------------------------------------------------------
-- одежда, инвентарь и предметы в руках

function dress(p: Player)
	local info = state.players[p]
	local char = p.Character
	if info and char then
		Outfits.apply(char, info.role, worn(info))
	end
end
G.dress = dress

local ITEM_LOOK = {
	bread = { size = Vector3.new(1.2, 0.6, 0.8), color = Color3.fromRGB(196, 140, 70), mat = Enum.Material.Sand },
	apple = { size = Vector3.new(0.7, 0.7, 0.7), color = Color3.fromRGB(190, 40, 40), shape = Enum.PartType.Ball },
	meat = { size = Vector3.new(1.2, 0.7, 0.7), color = Color3.fromRGB(140, 70, 40) },
	soup = { size = Vector3.new(0.5, 1.2, 1.2), color = Color3.fromRGB(150, 100, 60), shape = Enum.PartType.Cylinder },
	cake = { size = Vector3.new(1, 0.7, 1), color = Color3.fromRGB(250, 220, 230) },
	water = { size = Vector3.new(1.2, 0.6, 0.6), color = Color3.fromRGB(80, 140, 200), shape = Enum.PartType.Cylinder, mat = Enum.Material.Glass },
	juice = { size = Vector3.new(1.2, 0.6, 0.6), color = Color3.fromRGB(240, 150, 40), shape = Enum.PartType.Cylinder, mat = Enum.Material.Glass },
	spoon = { size = Vector3.new(0.15, 1.3, 0.25), color = Color3.fromRGB(200, 200, 210), mat = Enum.Material.Metal },
	broom = { size = Vector3.new(0.2, 4.5, 0.2), color = Color3.fromRGB(120, 85, 50), mat = Enum.Material.Wood, extra = "broom" },
	book = { size = Vector3.new(1, 0.3, 1.3), color = Color3.fromRGB(110, 40, 40), mat = Enum.Material.Fabric },
	scepter = { size = Vector3.new(0.25, 3, 0.25), color = Color3.fromRGB(214, 172, 80), mat = Enum.Material.Metal, extra = "scepter" },
	sword = { size = Vector3.new(0.25, 4, 0.5), color = Color3.fromRGB(200, 202, 210), mat = Enum.Material.Metal, extra = "sword" },
	cuffs = { size = Vector3.new(0.8, 0.3, 0.8), color = Color3.fromRGB(70, 66, 62), mat = Enum.Material.Metal, shape = Enum.PartType.Cylinder },
}

local onActivate -- объявлено ниже

local function makeTool(p: Player, item: string, slot: number): Tool
	local look = ITEM_LOOK[item] or ITEM_LOOK.bread
	local tool = Instance.new("Tool")
	tool.Name = item
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("Item", item)
	tool:SetAttribute("Slot", slot)
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = look.size
	h.Color = look.color
	h.Material = look.mat or Enum.Material.SmoothPlastic
	if look.shape then
		h.Shape = look.shape
	end
	h.CanCollide = false
	h.Massless = true
	h.Parent = tool
	if look.extra == "sword" then
		tool.GripPos = Vector3.new(0, -1.6, 0)
		local guard = Instance.new("Part")
		guard.Size = Vector3.new(1, 0.2, 0.3)
		guard.Color = Color3.fromRGB(214, 172, 80)
		guard.Material = Enum.Material.Metal
		guard.CanCollide = false
		guard.Massless = true
		guard.CFrame = h.CFrame * CFrame.new(0, -1.3, 0)
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = h, guard
		w.Parent = guard
		guard.Parent = tool
	elseif look.extra == "scepter" then
		tool.GripPos = Vector3.new(0, -0.6, 0)
		local gem = Instance.new("Part")
		gem.Shape = Enum.PartType.Ball
		gem.Size = Vector3.new(0.6, 0.6, 0.6)
		gem.Color = Color3.fromRGB(200, 30, 50)
		gem.Material = Enum.Material.Neon
		gem.CanCollide = false
		gem.Massless = true
		gem.CFrame = h.CFrame * CFrame.new(0, 1.6, 0)
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = h, gem
		w.Parent = gem
		gem.Parent = tool
	elseif look.extra == "broom" then
		tool.GripPos = Vector3.new(0, 0.5, 0)
		local b = Instance.new("Part")
		b.Size = Vector3.new(1.2, 1, 0.4)
		b.Color = Color3.fromRGB(200, 170, 100)
		b.Material = Enum.Material.Grass
		b.CanCollide = false
		b.Massless = true
		b.CFrame = h.CFrame * CFrame.new(0, -2.6, 0)
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = h, b
		w.Parent = b
		b.Parent = tool
	end
	tool.Activated:Connect(function()
		onActivate(p, item, tool)
	end)
	return tool
end

local function rebuildTools(p: Player)
	local info = state.players[p]
	local hum = humOf(p)
	local equipped: string? = nil
	if p.Character then
		local t = p.Character:FindFirstChildOfClass("Tool")
		if t then
			equipped = t:GetAttribute("Item")
			t:Destroy()
		end
	end
	local bp = p:FindFirstChildOfClass("Backpack")
	if bp then
		bp:ClearAllChildren()
	end
	if not info or not bp then
		return
	end
	local equipTool: Tool? = nil
	for i, item in info.inv do
		local t = makeTool(p, item, i)
		t.Parent = bp
		if equipped == item and not equipTool then
			equipTool = t
		end
	end
	if equipTool and hum then
		hum:EquipTool(equipTool)
	end
end

function G.giveItem(p: Player, item: string, quiet: boolean?): boolean
	local info = state.players[p]
	if not info or not Rules.ITEMS[item] then
		return false
	end
	if not Rules.canHold(item, info.role) then
		if not quiet then
			toast(p, "NotForRole")
		end
		return false
	end
	if item == "backpack" then
		info.backpackItem = true
		dress(p)
		sync(p)
		return true
	end
	local ok = Rules.addItem(info.inv, item, hasBackpack(info))
	if not ok then
		if not quiet then
			toast(p, "InventoryFull")
		end
		return false
	end
	rebuildTools(p)
	sync(p)
	playSound(rootOf(p), SOUND.click, 0.4)
	return true
end

function G.clearItems(p: Player)
	local info = state.players[p]
	if info then
		table.clear(info.inv)
		rebuildTools(p)
		sync(p)
	end
end

-- предметы, которые роль больше не может держать, исчезают
local function dropForbidden(p: Player)
	local info = state.players[p]
	if not info then
		return
	end
	for i = #info.inv, 1, -1 do
		if not Rules.canHold(info.inv[i], info.role) then
			table.remove(info.inv, i)
		end
	end
	rebuildTools(p)
end

-- ---------------------------------------------------------------------------
-- роли и король

local function counts()
	local c = {}
	for _, info in state.players do
		c[info.role] = (c[info.role] or 0) + 1
	end
	return c
end

local function updateKingStatue(userId: number)
	task.spawn(function()
		local m = Statue.spawn(userId, "stand", false, Builder.points.statue, decor, { scale = 2.2 })
		if m then
			if kingStatue then
				kingStatue:Destroy()
			end
			kingStatue = m
		end
	end)
end

local function kingFell()
	if not state.king then
		return
	end
	state.king = nil
	state.minionTarget = nil
	Npc.clearMinions()
	announce("KingFell")
	syncWorld()
end

function G.setRole(p: Player, role: string)
	local info = state.players[p]
	if not info or not Rules.ROLES[role] then
		return
	end
	if info.role == role then
		return
	end
	if role == "king" and state.king and state.king ~= p then
		G.setRole(state.king, "peasant")
	end
	if (role == "queen" or role == "commander") then
		for q, other in state.players do
			if q ~= p and other.role == role then
				other.role = "peasant"
				dress(q)
				dropForbidden(q)
				sync(q)
			end
		end
	end
	local wasKing = info.role == "king"
	info.role = role
	if wasKing and role ~= "king" then
		kingFell()
	end
	if role == "king" then
		state.king = p
		info.food, info.drink = Rules.MAX, Rules.MAX
		announce("NewKing", nil, p.DisplayName)
		updateKingStatue(p.UserId)
		G.giveItem(p, "scepter", true)
	end
	dress(p)
	dropForbidden(p)
	sync(p)
	syncWorld()
end

-- ---------------------------------------------------------------------------
-- темница

G.SENTENCE = 180 -- секунд в тюрьме; работа сокращает срок
G.WORK_CUT = 15

function G.jail(p: Player, seconds: number?)
	local info = state.players[p]
	if not info or info.jailed then
		return false
	end
	local cell = nil
	for i = 1, #Builder.cells do
		if not state.cells[i] then
			cell = i
			break
		end
	end
	cell = cell or math.random(1, #Builder.cells)
	state.cells[cell] = p
	info.jailed = cell
	info.jailUntil = os.time() + (seconds or G.SENTENCE)
	p:SetAttribute("JailUntil", info.jailUntil)
	if info.role == "king" then
		G.setRole(p, "peasant")
	end
	for i = #info.inv, 1, -1 do
		local def = Rules.ITEMS[info.inv[i]]
		if def.kind == "weapon" or info.inv[i] == "cuffs" then
			table.remove(info.inv, i)
		end
	end
	rebuildTools(p)
	teleport(p, Builder.cells[cell].inside)
	toast(p, "Jailed")
	sync(p)
	return true
end

function G.free(p: Player, toYard: boolean?)
	local info = state.players[p]
	if not info or not info.jailed then
		return false
	end
	state.cells[info.jailed] = nil
	info.jailed = nil
	info.jailUntil = nil
	p:SetAttribute("JailUntil", nil)
	teleport(p, if toYard then Builder.points.yard else Builder.points.dungeon)
	toast(p, "FreedMsg")
	sync(p)
	return true
end

-- работа узника: срок короче, немного золота
function G.work(p: Player)
	local info = state.players[p]
	if not info or not info.jailed then
		toast(p, "WorkOnlyPrisoners")
		return
	end
	info.jailUntil = (info.jailUntil or os.time()) - G.WORK_CUT
	p:SetAttribute("JailUntil", info.jailUntil)
	CurrencyService.add(p, 1)
	playSound(rootOf(p), SOUND.click, 0.6)
	if info.jailUntil <= os.time() then
		G.free(p)
	end
end

-- ---------------------------------------------------------------------------
-- тайный ход и ворота

local passageBusy = false
function G.setPassage(open: boolean)
	if passageBusy or state.passage == open then
		return
	end
	passageBusy = true
	state.passage = open
	syncWorld()
	local throne = Builder.throne
	local home = Builder.throneHome
	local v = Instance.new("NumberValue")
	v.Value = if open then 0 else 1
	v.Changed:Connect(function(a)
		throne:PivotTo(home + (Builder.throneSlide or Vector3.new(14, 0, 0)) * a)
	end)
	playSound(Builder.throneSeat, SOUND.stone, 1)
	if open then
		Builder.hatch.Transparency = 1
		Builder.hatch.CanCollide = false
	end
	local t = TweenService:Create(v, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = if open then 1 else 0 })
	t:Play()
	t.Completed:Wait()
	if not open then
		Builder.hatch.Transparency = 0
		Builder.hatch.CanCollide = true
	end
	v:Destroy()
	passageBusy = false
end

function G.setGates(open: boolean)
	if state.gates == open then
		return
	end
	state.gates = open
	local g = Builder.gate
	local base = g:GetAttribute("BaseY") or g.Position.Y
	g:SetAttribute("BaseY", base)
	playSound(g, SOUND.stone, 1)
	TweenService:Create(g, TweenInfo.new(2.5, Enum.EasingStyle.Sine), { CFrame = CFrame.new(g.Position.X, base + (if open then (Builder.gateLift or 20) else 0), g.Position.Z) }):Play()
end

-- ---------------------------------------------------------------------------
-- время суток, погода и времена года

function G.setClock(hour: number)
	state.clockBase = hour
	state.clockAt = os.clock()
	Lighting.ClockTime = hour
end

function G.setWeather(w: string)
	state.world.weather = w
	syncWorld()
end

function G.setSeason(season: string)
	state.world.season = season
	Seasons.apply(season, Builder.trees)
	state.world.weather = Seasons.defaultWeather(season)
	syncWorld()
end

function G.setNeeds(on: boolean)
	state.world.needs = on
	syncWorld()
end

function G.setPvp(on: boolean)
	state.world.pvp = on
	syncWorld()
end

-- ---------------------------------------------------------------------------
-- бой

local function attackFrom(p: Player, range: number, damage: number)
	local root = rootOf(p)
	if not root then
		return
	end
	local look = root.CFrame.LookVector
	local best = {}
	local function consider(model: Model, kind: string)
		local r = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		local h = model:FindFirstChildOfClass("Humanoid")
		if not r or not h or h.Health <= 0 or model == p.Character then
			return
		end
		local off = r.Position - root.Position
		local d = off.Magnitude
		if d > range then
			return
		end
		if d > 2 and off.Unit:Dot(look) < 0.2 then
			return
		end
		table.insert(best, { model = model, hum = h, kind = kind })
	end
	for q in state.players do
		if q.Character then
			consider(q.Character, "player")
		end
	end
	for _, m in Npc.minions do
		consider(m.model, "minion")
	end
	for _, d in dummies do
		consider(d.model, "dummy")
	end
	for _, t in best do
		if t.kind == "dummy" then
			t.hum.Health = math.max(1, t.hum.Health - damage)
			for _, d in dummies do
				if d.model == t.model then
					d.onHit(p.Character)
				end
			end
		elseif t.kind == "minion" then
			t.hum:TakeDamage(damage)
		elseif state.world.pvp then
			local target = Players:GetPlayerFromCharacter(t.model)
			local tInfo = target and state.players[target]
			if tInfo and not tInfo.jailed then
				t.hum:TakeDamage(damage)
				-- стража короля защищает короля
				if target == state.king and Npc.aliveCount() > 0 then
					state.minionTarget = p
				end
			end
		end
	end
end

local function nearestPlayer(p: Player, range: number): Player?
	local root = rootOf(p)
	if not root then
		return nil
	end
	local best, bestD = nil, range
	for q in state.players do
		local r = q ~= p and rootOf(q)
		if r then
			local d = (r.Position - root.Position).Magnitude
			if d < bestD then
				best, bestD = q, d
			end
		end
	end
	return best
end

local lastUse: { [Player]: { [string]: number } } = {}

local function cooldown(p: Player, key: string, sec: number): boolean
	lastUse[p] = lastUse[p] or {}
	local now = os.clock()
	if now - (lastUse[p][key] or 0) < sec then
		return false
	end
	lastUse[p][key] = now
	return true
end

onActivate = function(p: Player, item: string, tool: Tool)
	local info = state.players[p]
	if not info or tool.Parent ~= p.Character then
		return
	end
	local def = Rules.ITEMS[item]
	if item == "sword" then
		if not cooldown(p, "sword", def.cooldown) then
			return
		end
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
		Debris:AddItem(anim, 0.5)
		playSound(tool:FindFirstChild("Handle"), SOUND.slash, 0.7)
		attackFrom(p, 7, def.damage)
	elseif item == "cuffs" then
		if not cooldown(p, "cuffs", 2) then
			return
		end
		local target = nearestPlayer(p, 8)
		if target and target ~= state.king then
			G.jail(target)
		end
	elseif item == "broom" then
		if not cooldown(p, "broom", 1) then
			return
		end
		local h = tool:FindFirstChild("Handle")
		local e = Instance.new("ParticleEmitter")
		e.Rate = 0
		e.Speed = NumberRange.new(2, 5)
		e.Lifetime = NumberRange.new(0.6, 1)
		e.Size = NumberSequence.new(0.4, 0)
		e.Color = ColorSequence.new(Color3.fromRGB(200, 190, 170))
		e.Parent = h
		e:Emit(12)
		Debris:AddItem(e, 2)
		-- работа прислуги оплачивается
		if (info.role == "servant" or info.role == "cook") and cooldown(p, "broomPay", 20) then
			CurrencyService.add(p, 2)
		end
	elseif item == "scepter" then
		if not cooldown(p, "scepter", 1.5) then
			return
		end
		local h = tool:FindFirstChild("Handle")
		local s = Instance.new("Sparkles")
		s.SparkleColor = Color3.fromRGB(255, 220, 120)
		s.Parent = h
		Debris:AddItem(s, 2)
		playSound(h, SOUND.chime, 0.5)
	elseif item == "book" then
		if info.role == "librarian" and cooldown(p, "bookPay", 30) then
			CurrencyService.add(p, 3)
		end
		send(p, { type = "book" })
	elseif item == "spoon" then
		if cooldown(p, "spoon", 1) then
			playSound(tool:FindFirstChild("Handle"), SOUND.click, 0.5)
		end
	end
end

-- ---------------------------------------------------------------------------
-- стража короля

local function summon(p: Player, count: number?)
	local alive = Npc.aliveCount()
	local n = math.min(count or Rules.MINION_BATCH, Rules.MINION_MAX - alive)
	local base = if p then rootOf(p) else nil
	local at = if base then base.CFrame else Builder.points.throneRoom
	for i = 1, n do
		Npc.spawnMinion(at * CFrame.new((i - 1.5) * 4, 2, 6), npcFolder)
	end
	syncWorld()
	return n
end
G.summon = summon

-- ---------------------------------------------------------------------------
-- вход и выход из замка

local function addToGeneral(p: Player, on: boolean)
	local tc = TextChatService:FindFirstChild("TextChannels")
	local general = tc and tc:FindFirstChild("RBXGeneral")
	if not general then
		return
	end
	local src = nil
	for _, s in general:GetChildren() do
		if s:IsA("TextSource") and s.UserId == p.UserId then
			src = s
		end
	end
	if on and not src then
		pcall(function()
			src = (general :: TextChannel):AddUserAsync(p.UserId)
		end)
	elseif not on and src then
		src:Destroy()
		src = nil
	end
	if src then
		local info = state.players[p]
		src.CanSend = not (info and info.muted)
	end
end
G.addToGeneral = addToGeneral

function G.enter(p: Player)
	local info = state.players[p]
	local prof = G.profiles[p] or { owned = {}, worn = {} }
	if not info then
		info = { role = "peasant", food = Rules.MAX, drink = Rules.MAX, inv = {}, owned = prof.owned, worn = prof.worn, backpackItem = false }
		state.players[p] = info
	end
	addToGeneral(p, true)
	if not p.Character then
		p:LoadCharacter()
	end
	teleport(p, Builder.points.yard)
	dress(p)
	rebuildTools(p)
	sync(p)
	syncWorld()
	return { ok = true }
end

function G.leave(p: Player)
	local info = state.players[p]
	if not info then
		return
	end
	if info.jailed then
		state.cells[info.jailed] = nil
	end
	if state.minionTarget == p then
		state.minionTarget = nil
	end
	local wasKing = state.king == p
	state.players[p] = nil
	if wasKing then
		kingFell()
	end
	if p.Character then
		local o = p.Character:FindFirstChild("CastleOutfit")
		if o then
			o:Destroy()
		end
	end
	local bp = p:FindFirstChildOfClass("Backpack")
	if bp then
		bp:ClearAllChildren()
	end
	sync(p)
	syncWorld()
end

function G.inCastle(p: Player): boolean
	return state.players[p] ~= nil
end

-- ---------------------------------------------------------------------------
-- подсказки взаимодействия у объектов

local function prompts(kind: string, fn: (Player, ProximityPrompt) -> ())
	for _, pr in Builder.prompts[kind] or {} do
		pr.Triggered:Connect(function(p)
			if state.players[p] then
				fn(p, pr)
			end
		end)
	end
end

local function canPassage(p: Player): boolean
	local info = state.players[p]
	if not info then
		return false
	end
	if info.role == "king" then
		return true
	end
	return state.world.guardsPassage and (info.role == "guard" or info.role == "commander")
end
G.canPassage = canPassage

local function sitOnThrone(p: Player)
	local hum = humOf(p)
	local seat = Builder.throneSeat
	if hum and not seat.Occupant then
		seat.Disabled = false
		seat:Sit(hum)
	end
end

local function wirePrompts()
	prompts("throne", function(p)
		local info = state.players[p]
		if info.jailed then
			return
		end
		if not state.king then
			G.setRole(p, "king")
			sitOnThrone(p)
		elseif state.king == p then
			sitOnThrone(p)
		else
			toast(p, "OnlyKing")
		end
	end)
	Builder.throneSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local seat = Builder.throneSeat
		if not seat.Occupant then
			seat.Disabled = true
		else
			local p = Players:GetPlayerFromCharacter(seat.Occupant.Parent)
			if p ~= state.king then
				seat.Occupant.Sit = false
			end
		end
	end)
	prompts("passage", function(p)
		if canPassage(p) then
			task.spawn(G.setPassage, not state.passage)
		else
			toast(p, "OnlyKing")
		end
	end)
	prompts("lever", function(_p)
		task.spawn(G.setPassage, false)
	end)
	prompts("bread", function(p)
		G.giveItem(p, "bread")
	end)
	prompts("apple", function(p)
		G.giveItem(p, "apple")
	end)
	prompts("spoon", function(p)
		G.giveItem(p, "spoon")
	end)
	prompts("water", function(p)
		G.giveItem(p, "water")
	end)
	prompts("book", function(p)
		G.giveItem(p, "book")
	end)
	prompts("broom", function(p)
		G.giveItem(p, "broom")
	end)
	prompts("sword", function(p)
		if G.giveItem(p, "sword") then
			playSound(rootOf(p), SOUND.unsheath, 0.6)
		end
	end)
	prompts("cuffs", function(p)
		G.giveItem(p, "cuffs")
	end)
	prompts("scepter", function(p)
		G.giveItem(p, "scepter")
	end)
	prompts("cook", function(p)
		local info = state.players[p]
		if info.role ~= "cook" and info.role ~= "king" and info.role ~= "queen" then
			toast(p, "NotForRole")
			return
		end
		local dishes = { "meat", "soup", "cake", "juice" }
		if G.giveItem(p, dishes[math.random(1, #dishes)]) and info.role == "cook" and cooldown(p, "cookPay", 15) then
			CurrencyService.add(p, 3)
		end
	end)
	prompts("rest", function(p)
		local hum = humOf(p)
		if hum then
			hum.Health = math.min(hum.MaxHealth, hum.Health + 30)
		end
	end)
	prompts("roles", function(p)
		send(p, { type = "open", panel = "roles" })
	end)
	prompts("shop", function(p)
		send(p, { type = "open", panel = "shop" })
	end)
	prompts("slots", function(p)
		send(p, { type = "open", panel = "slots" })
	end)
	prompts("coin", function(p)
		send(p, { type = "open", panel = "coin" })
	end)
	-- ворота тюрьмы: проходит только стража, король и военачальник
	prompts("prisongate", function(p)
		local info = state.players[p]
		if info.jailed then
			toast(p, "JailedNo")
			return
		end
		if info.role ~= "king" and info.role ~= "commander" and info.role ~= "guard" then
			toast(p, "NotForRole")
			return
		end
		local r = rootOf(p)
		if not r then
			return
		end
		local inside = Builder.points.prisonInside
		local outside = Builder.points.prisonOutside
		local isInside = (r.Position - inside.Position).Magnitude < (r.Position - outside.Position).Magnitude
		playSound(r, SOUND.stone, 0.6)
		teleport(p, if isInside then outside else inside)
	end)
	prompts("work", function(p)
		if cooldown(p, "work", 3) then
			G.work(p)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- запросы клиента

local handlers = {}

handlers.Enter = function(p)
	return G.enter(p)
end

handlers.Leave = function(p)
	G.leave(p)
	return { ok = true }
end

handlers.Profile = function(p)
	local prof = G.profiles[p]
	return { ok = true, lang = prof and prof.lang, settings = prof and prof.settings }
end

handlers.SetLang = function(p, lang)
	local prof = G.profiles[p]
	if prof and (lang == "en" or lang == "ru") then
		prof.lang = lang
		prof.dirty = true
	end
	return { ok = true }
end

handlers.SaveSettings = function(p, settings)
	local prof = G.profiles[p]
	if prof and type(settings) == "table" then
		local clean = {}
		for k, v in settings do
			if type(k) == "string" and #k < 24 and (type(v) == "number" or type(v) == "boolean") then
				clean[k] = v
			end
		end
		prof.settings = clean
		prof.dirty = true
	end
	return { ok = true }
end

handlers.TakeRole = function(p, role)
	local info = state.players[p]
	if not info or type(role) ~= "string" or not Rules.ROLES[role] then
		return { ok = false }
	end
	if info.jailed then
		return { ok = false, error = "jailed" }
	end
	if info.role == role then
		return { ok = true }
	end
	local c = counts()
	if not Rules.canTake(role, c) then
		return { ok = false, error = if Rules.APPOINTED[role] then "appointed" else "taken" }
	end
	G.setRole(p, role)
	return { ok = true }
end

handlers.Use = function(p, slot)
	local info = state.players[p]
	if not info or type(slot) ~= "number" then
		return { ok = false }
	end
	local item = info.inv[slot]
	if not item then
		return { ok = false }
	end
	local def = Rules.ITEMS[item]
	if def.kind == "food" or def.kind == "drink" then
		local ok, err = Rules.consume(info, item, info.role == "king")
		if not ok then
			if err == "full" then
				toast(p, "Full")
			end
			return { ok = false, error = err }
		end
		table.remove(info.inv, slot)
		rebuildTools(p)
		playSound(p.Character and p.Character:FindFirstChild("Head"), SOUND.eat, 0.6)
		sync(p)
		return { ok = true, ate = true }
	end
	local hum = humOf(p)
	if not hum or not p.Character then
		return { ok = false }
	end
	local current = p.Character:FindFirstChildOfClass("Tool")
	if current and current:GetAttribute("Slot") == slot then
		hum:UnequipTools()
		return { ok = true, equipped = false }
	end
	local bp = p:FindFirstChildOfClass("Backpack")
	for _, t in (if bp then bp:GetChildren() else {}) do
		if t:IsA("Tool") and t:GetAttribute("Slot") == slot then
			hum:EquipTool(t)
			return { ok = true, equipped = true }
		end
	end
	return { ok = false }
end

handlers.Drop = function(p, slot)
	local info = state.players[p]
	if not info or type(slot) ~= "number" or not info.inv[slot] then
		return { ok = false }
	end
	table.remove(info.inv, slot)
	rebuildTools(p)
	sync(p)
	return { ok = true }
end

local rng = Random.new()
local function rand(a, b)
	return rng:NextInteger(a, b)
end

local function validBet(bet)
	return type(bet) == "number" and table.find(Rules.BETS, bet) ~= nil
end

handlers.Slots = function(p, bet)
	if not state.players[p] or not validBet(bet) then
		return { ok = false }
	end
	local gold = CurrencyService.get(p)
	if not gold or gold < bet then
		return { ok = false, error = "gold" }
	end
	if not cooldown(p, "slots", 1.2) then
		return { ok = false, error = "rate" }
	end
	local symbols, win = Rules.slots(bet, rand)
	CurrencyService.add(p, win - bet)
	return { ok = true, symbols = symbols, win = win }
end

handlers.Coin = function(p, bet)
	if not state.players[p] or not validBet(bet) then
		return { ok = false }
	end
	local gold = CurrencyService.get(p)
	if not gold or gold < bet then
		return { ok = false, error = "gold" }
	end
	if not cooldown(p, "coin", 1.2) then
		return { ok = false, error = "rate" }
	end
	local won, pay = Rules.coinFlip(bet, rand)
	CurrencyService.add(p, pay - bet)
	return { ok = true, won = won, win = pay }
end

handlers.Buy = function(p, id)
	local info = state.players[p]
	local item = type(id) == "string" and Rules.SHOP_BY_ID[id]
	if not info or not item then
		return { ok = false }
	end
	local prof = G.profiles[p]
	if not prof or not prof.loaded then
		return { ok = false, error = "load" }
	end
	if info.owned[id] then
		return { ok = true }
	end
	if not CurrencyService.add(p, -item.price) then
		return { ok = false, error = "gold" }
	end
	info.owned[id] = true
	info.worn[id] = true
	markDirty(p)
	dress(p)
	sync(p)
	return { ok = true }
end

handlers.Wear = function(p, id, on)
	local info = state.players[p]
	if not info or type(id) ~= "string" or not info.owned[id] then
		return { ok = false }
	end
	info.worn[id] = if on then true else nil
	if on and (id == "cape_red" or id == "cape_blue") then
		info.worn[if id == "cape_red" then "cape_blue" else "cape_red"] = nil
	end
	markDirty(p)
	dress(p)
	sync(p)
	return { ok = true }
end

-- король
local function isKing(p: Player)
	return state.king == p and state.players[p] ~= nil
end

handlers.KingSummon = function(p)
	if not isKing(p) then
		return { ok = false, error = "king" }
	end
	local now = os.time()
	local ok, why = Rules.canSummon(Npc.aliveCount(), state.lastSummon, now)
	if not ok then
		return { ok = false, error = why, left = if state.lastSummon then Rules.MINION_COOLDOWN - (now - state.lastSummon) else 0 }
	end
	state.lastSummon = now
	summon(p)
	toast(p, "Summoned")
	return { ok = true }
end

handlers.KingOrder = function(p, userId)
	if not isKing(p) then
		return { ok = false }
	end
	local target = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	if target and (target == p or not state.players[target]) then
		target = nil
	end
	state.minionTarget = target
	return { ok = true }
end

handlers.KingAppoint = function(p, userId, role)
	if not isKing(p) or type(userId) ~= "number" then
		return { ok = false }
	end
	local target = Players:GetPlayerByUserId(userId)
	if not target or target == p or not state.players[target] then
		return { ok = false }
	end
	if role == "queen" or role == "commander" or role == "guard" then
		if role == "guard" and not Rules.canTake("guard", counts()) then
			return { ok = false, error = "taken" }
		end
		G.setRole(target, role)
	elseif role == "dismiss" then
		G.setRole(target, "peasant")
	elseif role == "jail" then
		G.jail(target)
	elseif role == "free" then
		G.free(target)
	else
		return { ok = false }
	end
	return { ok = true }
end

handlers.KingPassage = function(p, open)
	if not canPassage(p) then
		return { ok = false }
	end
	task.spawn(G.setPassage, open == true)
	return { ok = true }
end

handlers.KingGuardsPassage = function(p, on)
	if not isKing(p) then
		return { ok = false }
	end
	state.world.guardsPassage = on == true
	syncWorld()
	return { ok = true }
end

handlers.Abdicate = function(p)
	if not isKing(p) then
		return { ok = false }
	end
	G.setRole(p, "peasant")
	return { ok = true }
end

G.handlers = handlers

-- ---------------------------------------------------------------------------

function G.init(projectStore)
	store = projectStore
	event = Remotes.event("Castle")
	Builder.build()
	npcFolder = Instance.new("Folder")
	npcFolder.Name = "CastleNpcs"
	npcFolder.Parent = workspace
	decor = Instance.new("Folder")
	decor.Name = "CastleDecor"
	decor.Parent = workspace
	G.npcFolder = npcFolder
	G.setSeason("summer")
	G.setClock(9)
	state.gates = false
	G.setGates(true)
	wirePrompts()
	for _, cf in Builder.points.dummies or {} do
		table.insert(dummies, Npc.buildDummy(cf, decor))
	end
	Npc.buildPriest(Builder.points.priest, decor)
	-- статуи создателей у трона, по умолчанию во дворе статуя владельца
	task.spawn(function()
		for _, s in { { "Saren45hil", Builder.points.statueLeft }, { "Nataliaavira13", Builder.points.statueRight } } do
			local m = Statue.spawn(s[1], "stand", false, s[2], decor, { scale = 1.5 })
			if m then
				local hand = m:FindFirstChild("RightHand") or m:FindFirstChild("Right Arm")
				if hand and hand:IsA("BasePart") then
					local sc = Instance.new("Part")
					sc.Name = "StoneScepter"
					sc.Anchored = true
					sc.CanCollide = false
					sc.Size = Vector3.new(0.35, 4.5, 0.35)
					sc.Color = Color3.fromRGB(196, 194, 190)
					sc.Material = Enum.Material.Marble
					sc.CFrame = hand.CFrame * CFrame.new(0, 0.3, -0.4)
					sc.Parent = m
				end
			end
		end
		if not kingStatue then
			kingStatue = Statue.spawn("Saren45hil", "stand", false, Builder.points.statue, decor, { scale = 2.2 })
		end
	end)

	Remotes.fn("CastleRequest").OnServerInvoke = function(p: Player, action: any, ...)
		if type(action) ~= "string" or not handlers[action] then
			return { ok = false, error = "unknown" }
		end
		if not cooldown(p, "req" .. action, 0.15) then
			return { ok = false, error = "rate" }
		end
		local ok, res = pcall(handlers[action], p, ...)
		if not ok then
			warn("[Castle] " .. action .. ": " .. tostring(res))
			return { ok = false, error = "server_error" }
		end
		return res
	end

	local function onCharacter(p: Player, char: Model)
		local info = state.players[p]
		if not info then
			return
		end
		info.food, info.drink = Rules.MAX, Rules.MAX
		local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
		task.wait(0.2)
		-- срок не закончился: узник появляется снова в тюрьме
		if info.jailed and Builder.cells[info.jailed] then
			teleport(p, Builder.cells[info.jailed].inside)
		end
		dress(p)
		rebuildTools(p)
		sync(p)
		if hum then
			hum.Died:Connect(function()
				local i = state.players[p]
				if not i then
					return
				end
				table.clear(i.inv)
				i.backpackItem = false
				if state.king == p then
					i.role = "peasant"
					kingFell()
				end
				if state.minionTarget == p then
					state.minionTarget = nil
				end
				sync(p)
			end)
		end
	end

	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(function(char)
			onCharacter(p, char)
		end)
		task.spawn(loadProfile, p)
		sync(p)
	end)
	for _, p in Players:GetPlayers() do
		p.CharacterAdded:Connect(function(char)
			onCharacter(p, char)
		end)
		task.spawn(loadProfile, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		G.leave(p)
		saveProfile(p)
		G.profiles[p] = nil
		lastUse[p] = nil
	end)
	game:BindToClose(function()
		for p in G.profiles do
			task.spawn(saveProfile, p)
		end
		task.wait(2)
	end)

	-- голод и жажда, зарплата, сохранение профилей
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(1)
			tick += 1
			for p, info in state.players do
				local hum = humOf(p)
				if hum and hum.Health > 0 then
					if state.world.needs then
						local dmg = Rules.tick(info, 1, info.role == "king")
						if dmg > 0 then
							hum:TakeDamage(dmg)
							if cooldown(p, "starve", 30) then
								toast(p, "Starving")
							end
						end
					end
					sync(p)
					-- срок вышел — на свободу; сбежавшего узника возвращаем
					if info.jailed then
						if (info.jailUntil or 0) <= os.time() then
							G.free(p)
						else
							local r = rootOf(p)
							if r and (r.Position.X > -47 or r.Position.X < -113 or r.Position.Z < -17 or r.Position.Z > 113 or r.Position.Y > 0 or r.Position.Y < -25) then
								teleport(p, Builder.cells[info.jailed].inside)
							end
						end
					end
				end
				if tick % 60 == 0 and not info.jailed then
					local pay = ({ king = 15, queen = 12, commander = 10, guard = 8, cook = 7, servant = 7, librarian = 7, peasant = 5 })[info.role] or 5
					CurrencyService.add(p, pay)
				end
			end
			if tick % 20 == 0 then
				for p, prof in G.profiles do
					if prof.dirty then
						task.spawn(saveProfile, p)
					end
				end
			end
			-- сутки длятся 24 минуты
			Lighting.ClockTime = (state.clockBase + (os.clock() - state.clockAt) / 60) % 24
		end
	end)

	-- стража: поведение и цель
	task.spawn(function()
		while true do
			task.wait(0.3)
			local target = state.minionTarget
			if target and (not state.players[target] or not humOf(target) or (humOf(target) :: Humanoid).Health <= 0) then
				state.minionTarget = nil
				target = nil
			end
			if #Npc.minions > 0 then
				Npc.stepMinions(state.king, target and target.Character, function(_model, hum)
					hum:TakeDamage(15)
				end)
			end
			if os.clock() % 3 < 0.31 then
				workspace:SetAttribute("CastleMinions", Npc.aliveCount())
			end
		end
	end)
	syncWorld()
end

return G
