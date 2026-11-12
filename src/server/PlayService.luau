--!nonstrict
-- Запуск карт: тест черновика автором и опубликованные версии по коду

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Remotes = require(Shared.Roblox.Remotes)
local Config = require(script.Parent.Config)
local PlaySession = require(script.Parent.PlaySession)
local FilterService = require(script.Parent.FilterService)

local PlayService = {}

local store: any
local sessions: { [string]: any } = {}
local byPublished: { [string]: any } = {}
local playerSession: { [Player]: any } = {}
local usedSlots: { [number]: boolean } = {}

local function allocSlot(): number
	local i = 1
	while usedSlots[i] do
		i += 1
	end
	usedSlots[i] = true
	return i
end

local function lobbyCF(): CFrame
	return CFrame.new(Config.LOBBY_ORIGIN + Vector3.new(0, 5, 0))
end

local function destroySession(s)
	sessions[s.id] = nil
	if s.code then
		local key = s.code .. ":" .. tostring(s.version)
		if byPublished[key] == s then
			byPublished[key] = nil
		end
	end
	for p, ps in playerSession do
		if ps == s then
			playerSession[p] = nil
		end
	end
	s:destroy()
	usedSlots[s.slot] = nil
end

function PlayService.leave(player: Player)
	local s = playerSession[player]
	if not s then
		return { ok = true }
	end
	playerSession[player] = nil
	s:removePlayer(player)
	if player.Character then
		local hrp = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			hrp.Anchored = false
		end
		player.Character:PivotTo(lobbyCF())
	end
	if s.kind == "test" and s.ownerId == player.UserId then
		destroySession(s)
	elseif s:playerCount() == 0 then
		destroySession(s)
	end
	return { ok = true }
end

local function create(kind: string, project, ownerId: number, code: string?, version: number?)
	local s = PlaySession.new(PlayService, {
		id = "S" .. string.sub(HttpService:GenerateGUID(false), 1, 8),
		kind = kind,
		project = project,
		ownerId = ownerId,
		code = code,
		version = version,
		slot = allocSlot(),
	})
	sessions[s.id] = s
	local ok, err = pcall(function()
		s:start()
	end)
	if not ok then
		warn("[Workshop] session start failed: " .. tostring(err))
		destroySession(s)
		return nil
	end
	return s
end

-- «Тестировать»: снимок черновика с теми же проверками, что и при публикации
function PlayService.startTest(player: Player, project)
	local ok, snap = FilterService.prepareSnapshot(project, player.UserId)
	if not ok then
		return { ok = false, error = snap.kind, errors = snap.errors, message = snap.message }
	end
	PlayService.leave(player)
	local s = create("test", snap, player.UserId, nil, nil)
	if not s then
		return { ok = false, error = "start_failed" }
	end
	playerSession[player] = s
	s:addPlayer(player)
	return { ok = true, sessionId = s.id }
end

function PlayService.join(player: Player, code: any)
	if type(code) ~= "string" or #code > 12 then
		return { ok = false, error = "bad_code" }
	end
	local ok, data, version, ptr = store:loadPublished(code)
	if not ok then
		return { ok = false, error = data }
	end
	PlayService.leave(player)
	local key = data.meta.publishCode .. ":" .. tostring(version)
	local s = byPublished[key]
	if not s or s.destroyed then
		s = create("published", data, ptr.ownerId, data.meta.publishCode, version)
		if not s then
			return { ok = false, error = "start_failed" }
		end
		byPublished[key] = s
	end
	playerSession[player] = s
	s:addPlayer(player)
	return { ok = true, sessionId = s.id, name = data.meta.name, version = version }
end

function PlayService.sessionOf(player: Player)
	return playerSession[player]
end

function PlayService.list()
	local out = {}
	for id, s in sessions do
		local names = {}
		for p in s.players do
			table.insert(names, { userId = p.UserId, name = p.Name })
		end
		table.insert(out, { id = id, kind = s.kind, code = s.code, version = s.version, players = names })
	end
	return out
end

function PlayService.endSession(id: string): boolean
	local s = sessions[id]
	if not s then
		return false
	end
	for p in s.players do
		if p.Character then
			p.Character:PivotTo(lobbyCF())
		end
	end
	destroySession(s)
	return true
end

function PlayService.kick(userId: number): boolean
	local player = Players:GetPlayerByUserId(userId)
	if player and playerSession[player] then
		PlayService.leave(player)
		return true
	end
	return false
end

function PlayService.init(projectStore)
	store = projectStore
	Remotes.event("PlayInput").OnServerEvent:Connect(function(player: Player, msg: any)
		local s = playerSession[player]
		if s then
			s:onInput(player, msg)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		PlayService.leave(player)
	end)
end

return PlayService
