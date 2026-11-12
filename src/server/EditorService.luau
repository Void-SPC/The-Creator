--!nonstrict
-- Сессии редактора: открытие карт, проверка правок, автосохранение
-- Сервер держит авторитетную копию черновика. Клиент применяет правку сразу у себя
-- и отправляет её сюда; при отказе сервер присылает свою копию

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Util = require(Shared.Util)
local Ops = require(Shared.Ops)
local Logic = require(Shared.Logic)
local Format = require(Shared.Format)
local Remotes = require(Shared.Roblox.Remotes)
local Config = require(script.Parent.Config)

local EditorService = {}

type Session = {
	player: Player,
	userId: number,
	project: any,
	rev: number,
	edits: number, -- счётчик правок
	savedEdits: number, -- правки, вошедшие в последнюю подтверждённую запись
	saving: boolean,
	readOnly: boolean,
	lastSaveAttempt: number,
	opWindowStart: number,
	opCount: number,
	closed: boolean,
}

local store: any
local sessions: { [Player]: Session } = {}
local saveStatus: RemoteEvent
local editAck: RemoteEvent

local function status(s: Session, state: string, info: any?)
	if s.player.Parent then
		saveStatus:FireClient(s.player, state, info)
	end
end

local function isDirty(s: Session): boolean
	return s.edits ~= s.savedEdits
end

-- Сохраняет черновик. Возвращает true, если запись подтверждена
local function save(s: Session): boolean
	if s.saving or s.readOnly or not isDirty(s) then
		return not isDirty(s)
	end
	s.saving = true
	s.lastSaveAttempt = os.clock()
	status(s, "saving")
	local editsAtSnapshot = s.edits
	local snapshot = Util.deepCopy(s.project)
	local ok, res = store:saveDraft(s.userId, snapshot, s.rev)
	s.saving = false
	if ok then
		s.rev = res
		s.savedEdits = editsAtSnapshot
		status(s, if isDirty(s) then "dirty" else "saved", { rev = s.rev })
		return not isDirty(s)
	end
	if res == "conflict" or res == "locked" then
		-- карту перехватил другой сервер: больше не пишем, чтобы не затереть его версию
		s.readOnly = true
		status(s, "readonly")
	else
		warn("[Workshop] save failed: " .. tostring(res))
		status(s, "failed")
	end
	return false
end
EditorService.save = save

local function close(player: Player)
	local s = sessions[player]
	if not s then
		return
	end
	s.closed = true
	if isDirty(s) and not s.readOnly then
		for _ = 1, 3 do
			if save(s) then
				break
			end
			task.wait(1)
		end
	end
	if not s.readOnly then
		store:releaseLock(s.userId, s.project.id)
	end
	sessions[player] = nil
end
EditorService.close = close

local function open(player: Player, ok: boolean, project, rev, readOnly)
	if not ok then
		return { ok = false, error = project }
	end
	if sessions[player] then
		close(player)
	end
	Logic.refreshText(project)
	local s: Session = {
		player = player,
		userId = player.UserId,
		project = project,
		rev = rev,
		edits = 0,
		savedEdits = 0,
		saving = false,
		readOnly = readOnly == true,
		lastSaveAttempt = 0,
		opWindowStart = 0,
		opCount = 0,
		closed = false,
	}
	sessions[player] = s
	task.defer(status, s, if s.readOnly then "readonly" else "saved", { rev = rev })
	return { ok = true, project = project, readOnly = s.readOnly, rev = rev }
end

function EditorService.get(player: Player): Session?
	return sessions[player]
end

function EditorService.init(projectStore)
	store = projectStore
	saveStatus = Remotes.event("SaveStatus")
	editAck = Remotes.event("EditAck")

	Remotes.event("EditOps").OnServerEvent:Connect(function(player: Player, seq: any, op: any)
		local s = sessions[player]
		if type(seq) ~= "number" then
			return
		end
		if not s then
			editAck:FireClient(player, seq, false, "no_session")
			return
		end
		if s.readOnly then
			editAck:FireClient(player, seq, false, "readonly", s.project)
			return
		end
		local now = os.clock()
		if now - s.opWindowStart > 1 then
			s.opWindowStart = now
			s.opCount = 0
		end
		s.opCount += 1
		if s.opCount > Config.EDIT_OPS_PER_SECOND then
			editAck:FireClient(player, seq, false, "rate", s.project)
			return
		end
		if Util.approxSize(op) > 300000 then
			editAck:FireClient(player, seq, false, "too_large", s.project)
			return
		end
		local ok, res = Ops.apply(s.project, op, { validate = true })
		if ok and Format.validateProject(s.project) ~= nil then
			Ops.apply(s.project, res, { validate = false })
			ok, res = false, "project_invalid"
		end
		if not ok then
			editAck:FireClient(player, seq, false, res, s.project)
			return
		end
		s.edits += 1
		editAck:FireClient(player, seq, true)
		status(s, "dirty")
	end)

	-- автосохранение
	task.spawn(function()
		while true do
			task.wait(2)
			local now = os.clock()
			for _, s in sessions do
				if not s.closed and isDirty(s) and not s.saving and not s.readOnly then
					local interval = Config.AUTOSAVE_SECONDS
					if now - s.lastSaveAttempt >= interval then
						task.spawn(save, s)
					end
				end
			end
		end
	end)

	-- карта в режиме просмотра периодически пробует получить блокировку
	task.spawn(function()
		while true do
			task.wait(Config.READONLY_RETRY_SECONDS)
			for player, s in sessions do
				if s.readOnly and not s.closed then
					local ok, project, rev, readOnly = store:openDraft(s.userId, s.project.id)
					if ok and not readOnly then
						s.readOnly = false
						if rev ~= s.rev then
							-- другой сервер успел сохранить новее: открываем подтверждённую версию
							s.project = project
							s.rev = rev
							s.edits, s.savedEdits = 0, 0
							editAck:FireClient(player, -1, false, "resync", project)
						end
						status(s, if isDirty(s) then "dirty" else "saved", { rev = s.rev })
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(close)
	game:BindToClose(function()
		local pending = 0
		for player in sessions do
			pending += 1
			task.spawn(function()
				close(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
end

-- Запросы клиента (вызываются из Main через Request)
function EditorService.listProjects(player: Player)
	local ok, list = store:listProjects(player.UserId)
	if not ok then
		return { ok = false, error = "load_failed" }
	end
	return { ok = true, projects = list }
end

function EditorService.createProject(player: Player, name: any, template: any)
	if type(name) ~= "string" then
		return { ok = false, error = "bad_name" }
	end
	name = Util.trim(name)
	if name == "" or utf8.len(name) == nil or (utf8.len(name) :: number) > 60 then
		return { ok = false, error = "bad_name" }
	end
	local tpl = if template == "demo" then "demo" else nil
	local ok, project, rev = store:createProject(player.UserId, name, tpl)
	return open(player, ok, project, rev, false)
end

function EditorService.openProject(player: Player, projectId: any)
	if type(projectId) ~= "string" or #projectId > 40 then
		return { ok = false, error = "bad_id" }
	end
	local current = sessions[player]
	if current and current.project.id == projectId then
		return { ok = true, project = current.project, readOnly = current.readOnly, rev = current.rev }
	end
	local ok, project, rev, readOnly = store:openDraft(player.UserId, projectId)
	return open(player, ok, project, rev, readOnly)
end

function EditorService.closeProject(player: Player)
	close(player)
	return { ok = true }
end

function EditorService.saveNow(player: Player)
	local s = sessions[player]
	if not s then
		return { ok = false }
	end
	return { ok = save(s) }
end

-- Обновление метаданных сервером (код публикации)
function EditorService.setPublishInfo(player: Player, code: string, version: number)
	local s = sessions[player]
	if not s then
		return
	end
	s.project.meta.publishCode = code
	s.project.meta.publishedVersion = version
	s.edits += 1
	task.spawn(save, s)
end

return EditorService
