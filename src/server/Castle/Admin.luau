--!nonstrict
-- Админ-панель замка: выполнение команд из AdminCommands. Доступ только создателям
-- (владелец игры, Saren45hil и Nataliaavira13), проверка здесь, на сервере

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Commands = require(Shared.AdminCommands)
local Rules = require(Shared.CastleRules)
local Remotes = require(Shared.Roblox.Remotes)

local Access = require(script.Parent.Parent.Access)
local CurrencyService = require(script.Parent.Parent.CurrencyService)
local Builder = require(script.Parent.CastleBuilder)
local Npc = require(script.Parent.Npc)
local Seasons = require(script.Parent.Seasons)
local G = require(script.Parent.CastleGame)

local Admin = {}

local hidden: { [Player]: { [Instance]: number } } = {}

local function hum(p: Player): Humanoid?
	return G.humOf(p)
end

local function root(p: Player): BasePart?
	return G.rootOf(p)
end

local function effect(p: Player, class: string, props)
	local r = p.Character and (p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("Torso") or root(p))
	if not r then
		return
	end
	local e = Instance.new(class)
	e.Name = "AdminEffect"
	for k, v in props or {} do
		(e :: any)[k] = v
	end
	e.Parent = if class == "ForceField" or class == "Highlight" then p.Character else r
end

local function clearEffects(p: Player)
	if not p.Character then
		return
	end
	for _, d in p.Character:GetDescendants() do
		if d.Name == "AdminEffect" then
			d:Destroy()
		end
	end
end

local function setVisible(p: Player, visible: boolean)
	local char = p.Character
	if not char then
		return
	end
	if visible then
		for inst, t in hidden[p] or {} do
			if inst.Parent then
				(inst :: any).Transparency = t
			end
		end
		hidden[p] = nil
		local h = hum(p)
		if h then
			h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		end
		return
	end
	local saved = hidden[p] or {}
	for _, d in char:GetDescendants() do
		if (d:IsA("BasePart") or d:IsA("Decal")) and saved[d] == nil then
			saved[d] = (d :: any).Transparency
			;(d :: any).Transparency = 1
		end
	end
	hidden[p] = saved
	local h = hum(p)
	if h then
		h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local function chatSource(p: Player): TextSource?
	local tc = TextChatService:FindFirstChild("TextChannels")
	local general = tc and tc:FindFirstChild("RBXGeneral")
	for _, s in (if general then general:GetChildren() else {}) do
		if s:IsA("TextSource") and s.UserId == p.UserId then
			return s
		end
	end
	return nil
end

local function num(arg, lo, hi, default)
	local n = tonumber(arg)
	if not n then
		return default
	end
	return math.clamp(n, lo, hi)
end

-- команды для всего замка
local WORLD = {
	season = function(_, arg)
		if table.find(Seasons.LIST, arg) then
			G.setSeason(arg)
			return true
		end
	end,
	day = function()
		G.setClock(12)
		return true
	end,
	dusk = function()
		G.setClock(18.2)
		return true
	end,
	night = function()
		G.setClock(23)
		return true
	end,
	weather = function(_, arg)
		if arg == "Clear" or arg == "Rain" or arg == "Snow" or arg == "Fog" or arg == "Storm" then
			G.setWeather(arg)
			return true
		end
	end,
	lightning = function()
		G.state.fxCount = (G.state.fxCount or 0) + 1
		for p in G.state.players do
			Remotes.event("Castle"):FireClient(p, { type = "fx", kind = "lightning" })
		end
		return true
	end,
	announce = function(admin, arg)
		if type(arg) ~= "string" or #arg == 0 or #arg > 200 then
			return false
		end
		local ok, filtered = pcall(function()
			local r = game:GetService("TextService"):FilterStringAsync(arg, admin.UserId)
			return r:GetNonChatStringForBroadcastAsync()
		end)
		if not ok then
			return false
		end
		G.announce(nil, filtered)
		return true
	end,
	fireworks = function()
		for p in G.state.players do
			Remotes.event("Castle"):FireClient(p, { type = "fx", kind = "fireworks" })
		end
		return true
	end,
	confetti = function()
		for p in G.state.players do
			Remotes.event("Castle"):FireClient(p, { type = "fx", kind = "confetti" })
		end
		return true
	end,
	passage_open = function()
		task.spawn(G.setPassage, true)
		return true
	end,
	passage_close = function()
		task.spawn(G.setPassage, false)
		return true
	end,
	gates_open = function()
		G.setGates(true)
		return true
	end,
	gates_close = function()
		G.setGates(false)
		return true
	end,
	free_all = function()
		for _, p in table.clone(G.state.cells) do
			G.free(p, true)
		end
		return true
	end,
	spawn_guards = function(admin, arg)
		G.summon(admin, num(arg, 1, Rules.MINION_MAX, 2))
		return true
	end,
	clear_npcs = function()
		Npc.clearMinions()
		G.state.minionTarget = nil
		G.syncWorld()
		return true
	end,
	pvp_on = function()
		G.setPvp(true)
		return true
	end,
	pvp_off = function()
		G.setPvp(false)
		return true
	end,
	needs_on = function()
		G.setNeeds(true)
		return true
	end,
	needs_off = function()
		G.setNeeds(false)
		return true
	end,
	music = function(_, arg)
		local id = tonumber(arg)
		if not id then
			return false
		end
		workspace:SetAttribute("CastleMusic", "rbxassetid://" .. math.floor(id))
		return true
	end,
	music_stop = function()
		workspace:SetAttribute("CastleMusic", "")
		return true
	end,
	reset_roles = function()
		for p in G.state.players do
			G.setRole(p, "peasant")
		end
		return true
	end,
	heal_all = function()
		for p in G.state.players do
			local h = hum(p)
			if h then
				h.Health = h.MaxHealth
			end
		end
		return true
	end,
	feed_all = function()
		for p, info in G.state.players do
			info.food, info.drink = Rules.MAX, Rules.MAX
			G.sync(p)
		end
		return true
	end,
}

-- команды для одного игрока
local PLAYER = {
	kill = function(_, p)
		local h = hum(p)
		if h then
			h.Health = 0
		end
	end,
	heal = function(_, p)
		local h = hum(p)
		if h then
			h.Health = h.MaxHealth
		end
	end,
	refill = function(_, p)
		local info = G.state.players[p]
		if info then
			info.food, info.drink = Rules.MAX, Rules.MAX
			G.sync(p)
		end
	end,
	starve = function(_, p)
		local info = G.state.players[p]
		if info then
			info.food, info.drink = 10, 10
			G.sync(p)
		end
	end,
	god = function(_, p)
		if p.Character and not p.Character:FindFirstChild("GodShield") then
			local ff = Instance.new("ForceField")
			ff.Name = "GodShield"
			ff.Visible = false
			ff.Parent = p.Character
		end
	end,
	ungod = function(_, p)
		local ff = p.Character and p.Character:FindFirstChild("GodShield")
		if ff then
			ff:Destroy()
		end
	end,
	speed = function(_, p, arg)
		local h = hum(p)
		if h then
			h.WalkSpeed = num(arg, 0, 150, 16)
		end
	end,
	jump = function(_, p, arg)
		local h = hum(p)
		if h then
			h.UseJumpPower = true
			h.JumpPower = num(arg, 0, 250, 50)
		end
	end,
	fly = function(_, p)
		p:SetAttribute("Fly", true)
	end,
	unfly = function(_, p)
		p:SetAttribute("Fly", false)
	end,
	invisible = function(_, p)
		setVisible(p, false)
	end,
	visible = function(_, p)
		setVisible(p, true)
	end,
	hidename = function(_, p)
		local h = hum(p)
		if h then
			h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end,
	showname = function(_, p)
		local h = hum(p)
		if h then
			h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		end
	end,
	freeze = function(_, p)
		local r = root(p)
		if r then
			r.Anchored = true
		end
	end,
	thaw = function(_, p)
		local r = root(p)
		if r then
			r.Anchored = false
		end
	end,
	bring = function(admin, p)
		local r = root(admin)
		if r then
			G.teleport(p, r.CFrame * CFrame.new(0, 0, -4))
		end
	end,
	["goto"] = function(admin, p)
		local r = root(p)
		if r then
			G.teleport(admin, r.CFrame * CFrame.new(0, 0, 4))
		end
	end,
	tp_throne = function(_, p)
		G.teleport(p, Builder.points.throneRoom)
	end,
	tp_yard = function(_, p)
		G.teleport(p, Builder.points.yard)
	end,
	jail = function(_, p)
		G.jail(p)
	end,
	free = function(_, p)
		G.free(p, true)
	end,
	kick = function(admin, p)
		if p ~= admin and not Access.isCreator(p) then
			p:Kick()
		end
	end,
	give_gold = function(_, p, arg)
		CurrencyService.add(p, num(arg, 1, 100000, 100))
	end,
	take_gold = function(_, p, arg)
		local cur = CurrencyService.get(p) or 0
		CurrencyService.add(p, -math.min(cur, num(arg, 1, 100000, 100)))
	end,
	give_item = function(_, p, arg)
		if type(arg) == "string" and Rules.ITEMS[arg] then
			local info = G.state.players[p]
			-- админ может выдать предмет любой роли: проверка роли обходится только здесь
			if info and not Rules.canHold(arg, info.role) then
				local def = Rules.ITEMS[arg]
				local saved = def.roles
				def.roles = nil
				G.giveItem(p, arg)
				def.roles = saved
			else
				G.giveItem(p, arg)
			end
		end
	end,
	clear_items = function(_, p)
		G.clearItems(p)
	end,
	set_role = function(_, p, arg)
		if type(arg) == "string" and Rules.ROLES[arg] then
			G.setRole(p, arg)
		end
	end,
	dethrone = function(_, p)
		if G.state.king == p then
			G.setRole(p, "peasant")
		end
	end,
	size_big = function(_, p)
		pcall(function()
			p.Character:ScaleTo(2)
		end)
	end,
	size_small = function(_, p)
		pcall(function()
			p.Character:ScaleTo(0.5)
		end)
	end,
	size_normal = function(_, p)
		pcall(function()
			p.Character:ScaleTo(1)
		end)
	end,
	sparkles = function(_, p)
		effect(p, "Sparkles", { SparkleColor = Color3.fromRGB(255, 220, 120) })
	end,
	fire = function(_, p)
		effect(p, "Fire", { Size = 4, Heat = 0 })
	end,
	smoke = function(_, p)
		effect(p, "Smoke", { Opacity = 0.3, RiseVelocity = 4 })
	end,
	forcefield = function(_, p)
		effect(p, "ForceField", { Visible = true })
	end,
	clear_effects = function(_, p)
		clearEffects(p)
	end,
	fling = function(_, p)
		local r = root(p)
		if r then
			r.AssemblyLinearVelocity = Vector3.new(math.random(-40, 40), 110, math.random(-40, 40))
		end
	end,
	sit = function(_, p)
		local h = hum(p)
		if h then
			h.Sit = true
		end
	end,
	respawn = function(_, p)
		p:LoadCharacter()
		if G.state.players[p] then
			task.wait(0.5)
			G.teleport(p, Builder.points.yard)
		end
	end,
	glow = function(_, p)
		effect(p, "Highlight", { FillColor = Color3.fromRGB(255, 220, 120), FillTransparency = 0.6, OutlineColor = Color3.fromRGB(255, 240, 200) })
	end,
	mute = function(_, p)
		local info = G.state.players[p]
		if info then
			info.muted = true
		end
		local s = chatSource(p)
		if s then
			s.CanSend = false
		end
	end,
	unmute = function(_, p)
		local info = G.state.players[p]
		if info then
			info.muted = false
		end
		local s = chatSource(p)
		if s then
			s.CanSend = true
		end
	end,
	explode = function(_, p)
		local r = root(p)
		if r then
			local e = Instance.new("Explosion")
			e.Position = r.Position
			e.BlastPressure = 0
			e.DestroyJointRadiusPercent = 0
			e.BlastRadius = 6
			e.Parent = workspace
			r.AssemblyLinearVelocity = Vector3.new(0, 60, 0)
		end
	end,
}

function Admin.isAdmin(p: Player): boolean
	return Access.isCreator(p)
end

function Admin.run(admin: Player, id: any, targetUserId: any, arg: any)
	if not Admin.isAdmin(admin) then
		return { ok = false, error = "forbidden" }
	end
	local cmd = type(id) == "string" and Commands.BY_ID[id]
	if not cmd then
		return { ok = false, error = "unknown" }
	end
	if type(arg) == "string" and #arg > 200 then
		return { ok = false, error = "arg" }
	end
	if type(cmd.arg) == "table" and not table.find(cmd.arg, arg) then
		return { ok = false, error = "arg" }
	end
	if cmd.target == "none" then
		local ok = WORLD[id](admin, arg)
		return { ok = ok ~= false }
	end
	local target = if type(targetUserId) == "number" then Players:GetPlayerByUserId(targetUserId) else nil
	if not target then
		return { ok = false, error = "player" }
	end
	local fn = PLAYER[id]
	if not fn then
		return { ok = false, error = "unknown" }
	end
	fn(admin, target, arg)
	return { ok = true }
end

function Admin.init()
	-- каждая команда списка должна иметь исполнителя
	for _, c in Commands.LIST do
		local fn = if c.target == "none" then WORLD[c.id] else PLAYER[c.id]
		if not fn then
			warn("[Castle] admin command without handler: " .. c.id)
		end
	end
	Remotes.fn("AdminRequest").OnServerInvoke = function(p: Player, action: any, ...)
		if action == "Status" then
			return { ok = true, admin = Admin.isAdmin(p) }
		elseif action == "Run" then
			local ok, res = pcall(Admin.run, p, ...)
			if not ok then
				warn("[Castle] admin: " .. tostring(res))
				return { ok = false, error = "server_error" }
			end
			return res
		end
		return { ok = false, error = "unknown" }
	end
	Players.PlayerRemoving:Connect(function(p)
		hidden[p] = nil
	end)
end

return Admin
