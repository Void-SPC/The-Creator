--!nonstrict
-- Игра «Мафия»: лобби, раздача ролей, ночь и день, голосования, призраки, ведущий, чаты
-- Права проверяются только здесь, на сервере; клиент получает лишь то, что ему можно знать

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Rules = require(Shared.MafiaRules)
local UiText = require(Shared.UiText)
local Remotes = require(Shared.Roblox.Remotes)
local Village = require(script.Parent.Village)
local Access = require(script.Parent.Parent.Access)

local L = UiText.L

local Game = {}

local DURATION = { reveal = 8, dusk = 20, night = 40, morning = 7, day = 120, vote = 40, verdict = 7, ended = 25 }

local state = {
	phase = "idle", -- idle | lobby | reveal | dusk | night | morning | day | vote | verdict | ended
	endsAt = 0,
	players = {} :: { [Player]: any }, -- { role, alive, house, seat }
	host = nil :: Player?,
	settings = { style = "spring", theme = "plain", auto = true, counts = { mafia = 2, doctor = 1, sheriff = 1 } },
	world = nil,
	votes = {},
	mafiaVotes = {},
	heals = {},
	checks = {},
	lastHeal = {},
	round = 0,
	winner = nil,
}
Game.state = state

local event: RemoteEvent
local channels = {}

local function inGame(p: Player): boolean
	return state.players[p] ~= nil
end

local function participants(): { Player }
	local out = {}
	for p in state.players do
		if p ~= state.host then
			table.insert(out, p)
		end
	end
	table.sort(out, function(a, b)
		return a.UserId < b.UserId
	end)
	return out
end

local function aliveMap()
	local alive = {}
	for p, info in state.players do
		if info.role and info.alive then
			alive[p] = true
		end
	end
	return alive
end

local function rolesMap()
	local roles = {}
	for p, info in state.players do
		if info.role then
			roles[p] = info.role
		end
	end
	return roles
end

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

local function announce(text: string, sound: string?)
	sendAll({ type = "announce", text = text, sound = sound })
end

-- Публичный список игроков: имена и кто жив; роли не раскрываются до конца игры
local function publicPlayers()
	local list = {}
	for _, p in participants() do
		local info = state.players[p]
		table.insert(list, {
			userId = p.UserId,
			name = p.DisplayName,
			alive = info.alive ~= false,
			house = info.house,
			role = if state.phase == "ended" then info.role else nil,
		})
	end
	return list
end

-- Личное состояние: своя роль, свои действия; мафии — выбор остальных мафиози
local function sync(p: Player)
	local info = state.players[p]
	if not info then
		return
	end
	local isHost = p == state.host
	local msg = {
		type = "state",
		phase = state.phase,
		endsAt = state.endsAt,
		round = state.round,
		players = publicPlayers(),
		hostId = state.host and state.host.UserId,
		youHost = isHost,
		canStart = isHost or state.host == nil,
		creator = Access.isCreator(p),
		settings = state.settings,
		role = info.role,
		alive = info.alive ~= false,
		house = info.house,
		vote = state.votes[p] and (if state.votes[p] == "skip" then "skip" else state.votes[p].UserId),
		winner = state.winner,
		chat = {},
	}
	-- голоса днём видят все (открытое голосование)
	if state.phase == "vote" then
		local tally = {}
		for voter, target in state.votes do
			local key = if target == "skip" then "skip" else tostring(target.UserId)
			tally[key] = (tally[key] or 0) + 1
			local _ = voter
		end
		msg.tally = tally
	end
	if info.role == "mafia" or isHost then
		local mv = {}
		for voter, target in state.mafiaVotes do
			mv[tostring(voter.UserId)] = target.UserId
		end
		msg.mafiaVotes = mv
		local team = {}
		for q, qi in state.players do
			if qi.role == "mafia" then
				table.insert(team, q.UserId)
			end
		end
		msg.mafiaTeam = team
	end
	if isHost then
		local all = {}
		for q, qi in state.players do
			all[tostring(q.UserId)] = qi.role
		end
		msg.allRoles = all
	end
	if info.role == "sheriff" then
		msg.checks = info.checks or {}
	end
	if info.role == "doctor" then
		msg.lastHeal = state.lastHeal[p] and state.lastHeal[p].UserId
		msg.heal = state.heals[p] and state.heals[p].UserId
	end
	for _, ch in { "general", "mafia", "ghost" } do
		local canSend, canSee = Rules.chat(ch, { role = info.role, alive = info.alive ~= false, host = isHost }, state.phase)
		msg.chat[ch] = { send = canSend, see = canSee }
	end
	send(p, msg)
end

local function syncAll()
	for p in state.players do
		sync(p)
	end
end

-- ---------------------------------------------------------------------------
-- чаты: свой общий канал игры, канал мафии и канал призраков

local function channel(name: string): TextChannel
	if channels[name] then
		return channels[name]
	end
	local folder = TextChatService:FindFirstChild("TextChannels") or TextChatService
	local c = folder:FindFirstChild(name) :: TextChannel?
	if not c then
		local nc = Instance.new("TextChannel")
		nc.Name = name
		nc.Parent = folder
		c = nc
	end
	channels[name] = c
	return c :: TextChannel
end

local NAMES = { general = "MafiaTown", mafia = "MafiaRoom", ghost = "GhostRoom" }

local function sourceOf(c: TextChannel, p: Player): TextSource?
	for _, s in c:GetChildren() do
		if s:IsA("TextSource") and s.UserId == p.UserId then
			return s
		end
	end
	return nil
end

local function applyChat(p: Player)
	local info = state.players[p]
	for key, name in NAMES do
		local c = channel(name)
		local canSend, canSee = false, false
		if info then
			canSend, canSee = Rules.chat(key, { role = info.role, alive = info.alive ~= false, host = p == state.host }, state.phase)
			if state.phase == "lobby" or state.phase == "idle" then
				canSend, canSee = key == "general", key == "general"
			end
		end
		local src = sourceOf(c, p)
		if canSee then
			if not src then
				local ok, res = pcall(function()
					return c:AddUserAsync(p.UserId)
				end)
				src = if ok then res else nil
			end
			if src then
				src.CanSend = canSend
			end
		elseif src then
			src:Destroy()
		end
	end
	-- общий канал Roblox для игроков мафии закрыт, чтобы не было подсказок мимо правил
	local general = TextChatService:FindFirstChild("TextChannels") and TextChatService.TextChannels:FindFirstChild("RBXGeneral")
	if general then
		local src = sourceOf(general, p)
		if src then
			src.CanSend = info == nil
		end
	end
end

local function applyChatAll()
	for p in state.players do
		applyChat(p)
	end
end

-- ---------------------------------------------------------------------------
-- перемещения

local function root(p: Player): BasePart?
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function hideName(p: Player)
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.NameDisplayDistance = 0
	end
end

local function teleport(p: Player, cf: CFrame)
	if p.Character then
		local hrp = root(p)
		if hrp then
			hrp.Anchored = false
			hrp.AssemblyLinearVelocity = Vector3.zero
		end
		p.Character:PivotTo(cf)
	end
end

local function toLobby(p: Player)
	if state.world then
		local i = 0
		for q in state.players do
			i += 1
			if q == p then
				break
			end
		end
		teleport(p, state.world.lobby * CFrame.new(((i - 1) % 5 - 2) * 4, 0, ((i - 1) // 5 - 1) * 4))
	end
end

local function toSeat(p: Player)
	local info = state.players[p]
	if state.world and info and info.seat then
		teleport(p, state.world.seats[info.seat])
	end
end

local function toHouse(p: Player)
	local info = state.players[p]
	if state.world and info and info.house then
		teleport(p, state.world.houses[info.house].inside)
	end
end

local function makeGhost(p: Player)
	if not state.world then
		return
	end
	local char = p.Character
	if char then
		for _, d in char:GetDescendants() do
			if d:IsA("BasePart") then
				d.Transparency = 1
				d.CanCollide = false
			elseif d:IsA("Decal") then
				d.Transparency = 1
			end
		end
		teleport(p, state.world.sky)
		local hrp = root(p)
		if hrp then
			hrp.Anchored = true
		end
	end
end

local function everyone(fn)
	for p, info in state.players do
		if p ~= state.host and info.alive ~= false then
			fn(p)
		end
	end
end

local function setDoors(open: boolean)
	if state.world then
		for _, h in state.world.houses do
			Village.setDoor(h, open)
		end
	end
end

-- ---------------------------------------------------------------------------
-- фазы

local function setPhase(phase: string, duration: number?)
	state.phase = phase
	state.endsAt = workspace:GetServerTimeNow() + (duration or DURATION[phase] or 30)
	applyChatAll()
	syncAll()
	sendAll({ type = "phase", phase = phase, endsAt = state.endsAt, world = state.world and { sky = state.world.sky, center = state.world.center, weather = state.world.weather, style = state.world.style } })
end

local function checkWin(): boolean
	local w = Rules.winner(rolesMap(), aliveMap())
	if w then
		state.winner = w
		setPhase("ended")
		announce(if w == "mafia" then L.MafiaWins else L.TownWins, "win")
		return true
	end
	return false
end

local function kill(p: Player, cause: string)
	local info = state.players[p]
	if not info or info.alive == false then
		return
	end
	info.alive = false
	makeGhost(p)
	send(p, { type = "ghost" })
	announce(string.format(if cause == "vote" then L.ExiledFormat else L.KilledFormat, p.DisplayName), "death")
end

local startNight

local function startDay()
	state.votes = {}
	setDoors(true)
	everyone(toSeat)
	setPhase("day")
end

local function startVote()
	state.votes = {}
	setPhase("vote")
	announce(L.VoteNow, "vote")
end

local function finishVote()
	if state.phase ~= "vote" then
		return
	end
	local alive = aliveMap()
	local votes = {}
	for voter, target in state.votes do
		votes[voter] = target
	end
	local exiled = Rules.dayResult(votes, alive)
	if exiled then
		kill(exiled, "vote")
	else
		announce(L.NobodyExiled)
	end
	if not checkWin() then
		setPhase("verdict")
	end
end

function startNight()
	state.round += 1
	state.mafiaVotes = {}
	state.heals = {}
	state.checks = {}
	setPhase("dusk")
	announce(L.GoHome, "night")
end

local function nightActions()
	-- по домам: кто не дошёл, переносится сам
	everyone(toHouse)
	setDoors(false)
	setPhase("night")
end

local function finishNight()
	local target = Rules.mafiaTarget((function()
		local v = {}
		for voter, t in state.mafiaVotes do
			v[voter] = t
		end
		return v
	end)(), rolesMap(), aliveMap())
	local heals = {}
	for doctor, healed in state.heals do
		table.insert(heals, healed)
		state.lastHeal[doctor] = healed
	end
	local victim, saved = Rules.nightResult(target, heals)
	setPhase("morning")
	if victim then
		kill(victim, "night")
	elseif saved then
		announce(L.DoctorSaved, "save")
	else
		announce(L.QuietNight)
	end
	checkWin()
end

local function advance()
	local p = state.phase
	if p == "reveal" then
		startNight()
	elseif p == "dusk" then
		nightActions()
	elseif p == "night" then
		finishNight()
	elseif p == "morning" then
		startDay()
	elseif p == "day" then
		startVote()
	elseif p == "vote" then
		finishVote()
	elseif p == "verdict" then
		startNight()
	elseif p == "ended" then
		Game.backToLobby()
	end
end
Game.advance = advance

-- ---------------------------------------------------------------------------
-- лобби и старт

local function buildWorld()
	state.world = Village.build(state.settings.style, state.settings.theme)
end

function Game.backToLobby()
	state.winner = nil
	state.round = 0
	for p, info in state.players do
		info.role = nil
		info.alive = true
		info.checks = nil
		if p.Parent then
			p:LoadCharacter()
		end
	end
	state.lastHeal = {}
	if state.world and state.world.lobbyModel then
		state.world.lobbyModel.Parent = state.world.folder
	end
	setPhase("lobby", 3600)
	for p in state.players do
		task.delay(1, function()
			hideName(p)
			toLobby(p)
		end)
	end
end

function Game.join(p: Player)
	if state.players[p] then
		return { ok = true }
	end
	local count = 0
	for _ in state.players do
		count += 1
	end
	if count >= Rules.MAX_PLAYERS + 1 then
		return { ok = false, error = "full" }
	end
	if state.phase == "idle" then
		buildWorld()
		state.phase = "lobby"
		state.endsAt = workspace:GetServerTimeNow() + 3600
	end
	state.players[p] = { role = nil, alive = true }
	if not p.Character then
		p.CharacterAdded:Wait()
	end
	hideName(p)
	p.CharacterAdded:Connect(function()
		task.wait()
		hideName(p)
		local info = state.players[p]
		if not info then
			return
		end
		if state.phase == "lobby" or state.phase == "idle" then
			toLobby(p)
		elseif info.alive == false or info.role == nil then
			makeGhost(p)
		elseif state.phase == "day" or state.phase == "vote" or state.phase == "verdict" or state.phase == "morning" then
			toSeat(p)
		else
			toHouse(p)
		end
	end)
	if state.phase == "lobby" then
		toLobby(p)
	else
		-- игра уже идёт: новичок смотрит сверху и ждёт следующей партии
		state.players[p].alive = false
		makeGhost(p)
	end
	applyChat(p)
	sendAll({ type = "joined", name = p.DisplayName })
	syncAll()
	sendAll({ type = "phase", phase = state.phase, endsAt = state.endsAt, world = { sky = state.world.sky, center = state.world.center, weather = state.world.weather, style = state.world.style } })
	return { ok = true }
end

function Game.leave(p: Player)
	local info = state.players[p]
	if not info then
		return
	end
	state.players[p] = nil
	if state.host == p then
		state.host = nil
		announce(L.HostLeft)
	end
	applyChat(p)
	if info.role and info.alive ~= false and state.phase ~= "lobby" and state.phase ~= "ended" then
		announce(string.format(L.LeftFormat, p.DisplayName))
		checkWin()
	end
	local any = next(state.players) ~= nil
	if not any then
		state.phase = "idle"
		if state.world then
			state.world.folder:Destroy()
			state.world = nil
		end
	else
		syncAll()
	end
end

local function canControl(p: Player): boolean
	return p == state.host or (state.host == nil and state.players[p] ~= nil)
end

local function start(p: Player)
	if state.phase ~= "lobby" or not canControl(p) then
		return { ok = false, error = "forbidden" }
	end
	local ids = participants()
	if #ids < Rules.MIN_PLAYERS then
		return { ok = false, error = "few" }
	end
	local counts = if state.settings.auto then Rules.autoCounts(#ids) else state.settings.counts
	local bad = Rules.checkCounts(#ids, counts)
	if bad then
		return { ok = false, error = bad }
	end
	local rng = Random.new()
	local roles = Rules.assign(ids, counts, function(a, b)
		return rng:NextInteger(a, b)
	end)
	-- дома и места у стола тоже по жребию
	local order = table.clone(ids)
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	for i, q in order do
		local info = state.players[q]
		info.role = roles[q]
		info.alive = true
		info.house = i
		info.seat = i
		info.checks = {}
	end
	if state.host then
		state.players[state.host].role = nil
		state.players[state.host].alive = false
	end
	if state.world and state.world.lobbyModel then
		state.world.lobbyModel.Parent = nil
	end
	for _, q in ids do
		toSeat(q)
	end
	if state.host then
		teleport(state.host, state.world.seats[1] * CFrame.new(0, 0, 4))
	end
	setPhase("reveal")
	announce(L.GameStarts, "start")
	return { ok = true }
end

-- ---------------------------------------------------------------------------
-- запросы клиента

local function playerById(id): Player?
	if type(id) ~= "number" then
		return nil
	end
	local p = Players:GetPlayerByUserId(id)
	if p and state.players[p] and p ~= state.host then
		return p
	end
	return nil
end

local handlers = {}

handlers.Join = function(p)
	return Game.join(p)
end

handlers.Leave = function(p)
	Game.leave(p)
	return { ok = true }
end

handlers.BecomeHost = function(p, on)
	if state.phase ~= "lobby" then
		return { ok = false }
	end
	if on and state.host == nil then
		state.host = p
	elseif not on and state.host == p then
		state.host = nil
	elseif on and state.host and Access.isCreator(p) then
		-- создатель может забрать роль ведущего
		state.host = p
	else
		return { ok = false }
	end
	syncAll()
	return { ok = true }
end

handlers.Settings = function(p, s)
	if state.phase ~= "lobby" or not canControl(p) or type(s) ~= "table" then
		return { ok = false }
	end
	local themes = { summer = { plain = true }, spring = { plain = true, april = true }, autumn = { plain = true, halloween = true }, winter = { plain = true, newyear = true } }
	local style = if themes[s.style] then s.style else state.settings.style
	local theme = if themes[style][s.theme] then s.theme else "plain"
	local rebuild = style ~= state.settings.style or theme ~= state.settings.theme
	state.settings.style = style
	state.settings.theme = theme
	state.settings.auto = s.auto ~= false
	if type(s.counts) == "table" then
		local c = {}
		for _, k in { "mafia", "doctor", "sheriff" } do
			local lim = Rules.LIMITS[k]
			c[k] = math.clamp(math.floor(tonumber(s.counts[k]) or lim[1]), lim[1], lim[2])
		end
		state.settings.counts = c
	end
	if rebuild then
		buildWorld()
		for q in state.players do
			toLobby(q)
		end
		sendAll({ type = "phase", phase = state.phase, endsAt = state.endsAt, world = { sky = state.world.sky, center = state.world.center, weather = state.world.weather, style = state.world.style } })
	end
	syncAll()
	return { ok = true }
end

handlers.Start = function(p)
	return start(p)
end

-- дневной голос
handlers.Vote = function(p, targetId)
	local info = state.players[p]
	if state.phase ~= "vote" or not info or not info.role or info.alive == false then
		return { ok = false }
	end
	if targetId == "skip" then
		state.votes[p] = "skip"
	else
		local t = playerById(targetId)
		if not t or state.players[t].alive == false then
			return { ok = false }
		end
		state.votes[p] = t
	end
	syncAll()
	-- все проголосовали: подводим итог раньше времени
	local need, have = 0, 0
	for q, qi in state.players do
		if qi.role and qi.alive ~= false then
			need += 1
			if state.votes[q] then
				have += 1
			end
		end
	end
	if have >= need then
		task.defer(finishVote)
	end
	return { ok = true }
end

-- ночные действия
handlers.Night = function(p, targetId)
	local info = state.players[p]
	if state.phase ~= "night" or not info or info.alive == false then
		return { ok = false }
	end
	local t = playerById(targetId)
	if not t or state.players[t].alive == false then
		return { ok = false }
	end
	if info.role == "mafia" then
		if state.players[t].role == "mafia" then
			return { ok = false }
		end
		state.mafiaVotes[p] = t
		for q, qi in state.players do
			if qi.role == "mafia" or q == state.host then
				sync(q)
			end
		end
	elseif info.role == "doctor" then
		if state.lastHeal[p] == t then
			return { ok = false, error = "same" }
		end
		state.heals[p] = t
		sync(p)
	elseif info.role == "sheriff" then
		if state.checks[p] or t == p then
			return { ok = false, error = "once" }
		end
		state.checks[p] = t
		local isMafia = state.players[t].role == "mafia"
		info.checks = info.checks or {}
		table.insert(info.checks, { name = t.DisplayName, mafia = isMafia, round = state.round })
		sync(p)
	else
		return { ok = false }
	end
	return { ok = true }
end

-- ведущий
handlers.Host = function(p, action, arg)
	if p ~= state.host and not (state.host == nil and Access.isCreator(p)) then
		return { ok = false, error = "forbidden" }
	end
	if action == "next" then
		advance()
	elseif action == "more" then
		state.endsAt += 30
		syncAll()
		sendAll({ type = "phase", phase = state.phase, endsAt = state.endsAt })
	elseif action == "home" then
		everyone(toHouse)
		sendAll({ type = "sound", sound = "whoosh" })
	elseif action == "table" then
		everyone(toSeat)
	elseif action == "toss" or action == "bring" or action == "sendHome" then
		local t = playerById(arg)
		local hrp = t and root(t)
		if not t or not hrp then
			return { ok = false }
		end
		if action == "toss" then
			-- «пинок»: игрока подбрасывает в сторону его дома
			local info = state.players[t]
			local target = if info.house and state.world then state.world.houses[info.house].porch.Position else hrp.Position
			local dir = target - hrp.Position
			dir = Vector3.new(dir.X, 0, dir.Z)
			dir = if dir.Magnitude > 1 then dir.Unit else Vector3.new(0, 0, 1)
			hrp.AssemblyLinearVelocity = dir * 70 + Vector3.new(0, 55, 0)
			send(t, { type = "sound", sound = "whoosh" })
		elseif action == "bring" then
			local mine = root(p)
			if mine then
				teleport(t, mine.CFrame * CFrame.new(0, 0, -5))
			end
		else
			toHouse(t)
		end
	end
	return { ok = true }
end

-- ---------------------------------------------------------------------------

function Game.init()
	event = Remotes.event("Mafia")
	Remotes.fn("MafiaRequest").OnServerInvoke = function(p: Player, action: any, ...: any)
		local h = type(action) == "string" and handlers[action]
		if not h then
			return { ok = false }
		end
		local ok, res = pcall(h, p, ...)
		if not ok then
			warn("[Mafia] " .. tostring(action) .. ": " .. tostring(res))
			return { ok = false }
		end
		return res
	end
	-- таймер фаз
	task.spawn(function()
		while true do
			task.wait(0.5)
			if state.phase ~= "idle" and state.phase ~= "lobby" and workspace:GetServerTimeNow() >= state.endsAt then
				local ok, err = pcall(advance)
				if not ok then
					warn("[Mafia] phase: " .. tostring(err))
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(Game.leave)
	local _ = HttpService
end

function Game.inGame(p: Player): boolean
	return inGame(p)
end

return Game
