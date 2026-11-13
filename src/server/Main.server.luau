--!nonstrict
-- Точка входа сервера мастерской

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Remotes = require(Shared.Roblox.Remotes)
local Logic = require(Shared.Logic)
local Model = require(Shared.Model)
local Format = require(Shared.Format)

local Config = require(script.Parent.Config)
local Adapter = require(script.Parent.DataStoreAdapter)
local ProjectStore = require(script.Parent.Core.ProjectStore)
local EditorService = require(script.Parent.EditorService)
local PlayService = require(script.Parent.PlayService)
local FilterService = require(script.Parent.FilterService)
local AdminService = require(script.Parent.AdminService)
local Access = require(script.Parent.Access)

local adapter = Adapter.create()
local store = ProjectStore.new(adapter, { jobId = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false) })

-- Лобби: небольшая площадка, где стоят персонажи авторов во время редактирования
local function buildLobby()
	if workspace:FindFirstChild("WsLobby") then
		return
	end
	local m = Instance.new("Model")
	m.Name = "WsLobby"
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(60, 1, 60)
	floor.Position = Config.LOBBY_ORIGIN
	floor.Color = Color3.fromRGB(46, 50, 58)
	floor.Material = Enum.Material.SmoothPlastic
	floor.Parent = m
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Config.LOBBY_ORIGIN + Vector3.new(0, 1, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = m
	m.Parent = workspace
end
buildLobby()

EditorService.init(store)
PlayService.init(store)

-- ---------------------------------------------------------------------------
-- Запросы клиента

local rate: { [Player]: { t: number, n: number } } = {}
Players.PlayerRemoving:Connect(function(p)
	rate[p] = nil
	AdminService.forget(p)
	Access.forget(p)
end)

local function compileErrors(project)
	local _, errors = Logic.compile(project)
	return errors
end

local handlers: { [string]: (Player, ...any) -> any } = {}

handlers.ListProjects = function(player)
	return EditorService.listProjects(player)
end

handlers.CreateProject = function(player, name, template)
	return EditorService.createProject(player, name, template)
end

handlers.OpenProject = function(player, projectId)
	return EditorService.openProject(player, projectId)
end

handlers.CloseProject = function(player)
	PlayService.leave(player)
	return EditorService.closeProject(player)
end

handlers.SaveNow = function(player)
	return EditorService.saveNow(player)
end

handlers.CheckLogic = function(player)
	local s = EditorService.get(player)
	if not s then
		return { ok = false, error = "no_session" }
	end
	return { ok = true, errors = compileErrors(s.project), broken = Logic.brokenBindings(s.project) }
end

handlers.StartTest = function(player)
	local s = EditorService.get(player)
	if not s then
		return { ok = false, error = "no_session" }
	end
	task.spawn(EditorService.save, s)
	return PlayService.startTest(player, s.project)
end

handlers.StopPlay = function(player)
	return PlayService.leave(player)
end

handlers.Publish = function(player)
	local s = EditorService.get(player)
	if not s then
		return { ok = false, error = "no_session" }
	end
	if s.readOnly then
		return { ok = false, error = "readonly" }
	end
	local ok, snap = FilterService.prepareSnapshot(s.project, player.UserId)
	if not ok then
		return { ok = false, error = snap.kind, errors = snap.errors, message = snap.message }
	end
	local okP, code, version = store:publish(player.UserId, s.project, snap)
	if not okP then
		return { ok = false, error = code }
	end
	EditorService.setPublishInfo(player, code, version)
	return { ok = true, code = code, version = version }
end

handlers.JoinByCode = function(player, code)
	EditorService.closeProject(player)
	return PlayService.join(player, code)
end

handlers.ListCatalog = function(_player)
	local ok, entries = store:catalog()
	if not ok then
		return { ok = false, error = "load_failed" }
	end
	return { ok = true, entries = entries }
end

handlers.SaveLibraryModel = function(player, objectId, name)
	local s = EditorService.get(player)
	if not s or type(objectId) ~= "string" then
		return { ok = false }
	end
	local obj = s.project.map.objects[objectId]
	if not obj or obj.kind ~= "model" then
		return { ok = false, error = "not_model" }
	end
	local asset = Model.toAsset(obj, if type(name) == "string" and #name <= 120 then name else obj.name)
	local ok, id = store:saveLibraryModel(player.UserId, asset)
	return { ok = ok, id = id }
end

handlers.ListLibrary = function(player)
	local ok, list = store:listLibrary(player.UserId)
	return { ok = ok, models = if ok then list else nil }
end

handlers.GetLibraryModel = function(player, assetId)
	if type(assetId) ~= "string" then
		return { ok = false }
	end
	local ok, asset = store:getLibraryModel(player.UserId, assetId)
	if ok then
		local probe = table.clone(asset.object or {})
		probe.id = "o_check"
		if Format.validateObject(probe) ~= nil then
			return { ok = false, error = "invalid" }
		end
	end
	return { ok = ok, asset = if ok then asset else nil }
end

handlers.FilterPreview = function(player, text)
	if type(text) ~= "string" or #text > 2400 then
		return { ok = false }
	end
	local ok, res = FilterService.filter(text, player.UserId)
	return { ok = ok, text = if ok then res else nil }
end

handlers.AdminStatus = function(player)
	return { ok = true, admin = AdminService.isAdmin(player) }
end

handlers.AdminAction = function(player, action, arg)
	-- каждое действие панели проверяется здесь, а не на клиенте
	if not AdminService.isAdmin(player) then
		return { ok = false, error = "forbidden" }
	end
	if action == "ListSessions" then
		return { ok = true, sessions = PlayService.list() }
	elseif action == "EndSession" and type(arg) == "string" then
		return { ok = PlayService.endSession(arg) }
	elseif action == "Kick" and type(arg) == "number" then
		return { ok = PlayService.kick(arg) }
	elseif action == "Unlist" and type(arg) == "string" then
		return { ok = store:unlist(string.upper(arg)) }
	end
	return { ok = false, error = "unknown" }
end

-- ---------------------------------------------------------------------------
-- «Витрина»: все игроки попадают сразу в выбранную карту, меню создателя видят
-- только создатели (владелец игры и пользователи из Config.CREATOR_USERNAMES)

local showcase: { code: string, name: string }? = nil
local playEvent = Remotes.event("Play")

local function sendMode(player: Player)
	playEvent:FireClient(player, {
		type = "mode",
		creator = Access.isCreator(player),
		showcase = if showcase then { code = showcase.code, name = showcase.name } else nil,
	})
end

local function enterShowcase(player: Player)
	if not showcase or not player.Parent then
		return
	end
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	task.wait(0.5)
	local current = PlayService.sessionOf(player)
	if current and current.code == showcase.code then
		return
	end
	EditorService.closeProject(player)
	local res = PlayService.join(player, showcase.code)
	if not res.ok then
		warn("[Creator] showcase join failed: " .. tostring(res.error))
	end
end

local function applyShowcase(rec)
	local changed = (rec and rec.code) ~= (showcase and showcase.code)
	showcase = if rec then { code = rec.code, name = rec.name } else nil
	if not changed then
		return
	end
	for _, player in Players:GetPlayers() do
		sendMode(player)
		if showcase and not Access.isCreator(player) then
			task.spawn(enterShowcase, player)
		end
	end
end

task.spawn(function()
	while true do
		local ok, rec = store:getShowcase()
		if ok then
			applyShowcase(rec)
		end
		task.wait(30)
	end
end)

Players.PlayerAdded:Connect(function(player)
	task.wait(1)
	sendMode(player)
	if showcase then
		enterShowcase(player)
	end
end)

-- В режиме «Витрина» эти запросы доступны только создателям
local CREATOR_ONLY = {
	ListProjects = true, CreateProject = true, OpenProject = true, CloseProject = true, SaveNow = true,
	CheckLogic = true, StartTest = true, Publish = true, JoinByCode = true, ListCatalog = true,
	SaveLibraryModel = true, ListLibrary = true, GetLibraryModel = true, FilterPreview = true, StopPlay = true,
}

handlers.Status = function(player)
	return {
		ok = true,
		creator = Access.isCreator(player),
		showcase = if showcase then { code = showcase.code, name = showcase.name } else nil,
	}
end

handlers.SetShowcase = function(player, code)
	if not Access.isCreator(player) then
		return { ok = false, error = "forbidden" }
	end
	if code ~= nil and type(code) ~= "string" then
		return { ok = false, error = "bad_code" }
	end
	local ok, err = store:setShowcase(code, player.UserId)
	if not ok then
		return { ok = false, error = err }
	end
	local okR, rec = store:getShowcase()
	if okR then
		applyShowcase(rec)
	end
	return { ok = true, showcase = showcase }
end

-- создатель из витрины открывает меню создателя
handlers.OpenCreatorMenu = function(player)
	if not Access.isCreator(player) then
		return { ok = false, error = "forbidden" }
	end
	return PlayService.leave(player)
end

-- игрок в витрине вернулся в лобби (например, сессию завершили): снова в карту
handlers.RejoinShowcase = function(player)
	if showcase then
		task.spawn(enterShowcase, player)
	end
	return { ok = showcase ~= nil }
end

Remotes.fn("Request").OnServerInvoke = function(player: Player, action: any, ...: any)
	if type(action) ~= "string" or not handlers[action] then
		return { ok = false, error = "unknown" }
	end
	if showcase and CREATOR_ONLY[action] and not Access.isCreator(player) then
		return { ok = false, error = "showcase" }
	end
	local now = os.clock()
	local r = rate[player]
	if not r or now - r.t > 1 then
		r = { t = now, n = 0 }
		rate[player] = r
	end
	r.n += 1
	if r.n > Config.REQUESTS_PER_SECOND then
		return { ok = false, error = "rate" }
	end
	local ok, res = pcall(handlers[action], player, ...)
	if not ok then
		warn("[Workshop] " .. action .. " failed: " .. tostring(res))
		return { ok = false, error = "server_error" }
	end
	return res
end
