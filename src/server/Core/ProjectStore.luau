--!nonstrict
-- Хранилище проектов поверх адаптера DataStore
--
-- Правила:
--  * ошибка чтения никогда не превращается в пустую карту и не приводит к записи;
--  * «Сохранено» означает подтверждённую запись (UpdateAsync вернул новую ревизию);
--  * черновик пишет только сервер, который держит блокировку сессии;
--  * публикация — неизменяемый снимок с номером версии, правка черновика её не меняет
--
-- Адаптер: { get = function(key) -> value, update = function(key, fn) -> newValue }
-- Обе функции могут бросать ошибку (сбой DataStore); fn может вернуть nil для отмены

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Util = require(Shared.Util)
local Format = require(Shared.Format)
local Demo = require(Shared.Demo)
local Prefabs = require(Shared.Prefabs)

local ProjectStore = {}
ProjectStore.__index = ProjectStore

local CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
local CATALOG_SIZE = 100
local MAX_PROJECTS = 30

local function draftKey(userId: number, projectId: string)
	return string.format("u%d:draft:%s", userId, projectId)
end
local function indexKey(userId: number)
	return string.format("u%d:index", userId)
end
local function libKey(userId: number)
	return string.format("u%d:lib", userId)
end
local function pubKey(code: string)
	return "pub:" .. code
end
local function pubVersionKey(code: string, v: number)
	return string.format("pubv:%s:%d", code, v)
end

function ProjectStore.new(adapter, opts)
	local self = setmetatable({}, ProjectStore)
	self.adapter = adapter
	self.jobId = (opts and opts.jobId) or "local"
	self.now = (opts and opts.now) or os.time
	self.lockTimeout = (opts and opts.lockTimeout) or 120
	self.random = (opts and opts.random) or Random.new()
	return self
end

function ProjectStore:_get(key: string)
	local ok, res = pcall(self.adapter.get, key)
	if not ok then
		return false, "read_failed: " .. tostring(res)
	end
	return true, res
end

function ProjectStore:_update(key: string, fn)
	local abortReason = nil
	local ok, res = pcall(self.adapter.update, key, function(old)
		local okFn, newValue, reason = pcall(fn, old)
		if not okFn then
			abortReason = "update_fn: " .. tostring(newValue)
			return nil
		end
		if newValue == nil then
			abortReason = reason or "aborted"
		end
		return newValue
	end)
	if not ok then
		return false, "write_failed: " .. tostring(res)
	end
	if abortReason then
		return false, abortReason
	end
	return true, res
end

function ProjectStore:_newProjectId(): string
	return string.format("p%x%04x", self.now(), self.random:NextInteger(0, 0xffff))
end

-- Список карт автора. При ошибке чтения возвращает false, а не пустой список
function ProjectStore:listProjects(userId: number)
	local ok, index = self:_get(indexKey(userId))
	if not ok then
		return false, index
	end
	local out = {}
	for pid, entry in (index and index.projects) or {} do
		local e = Util.deepCopy(entry)
		e.id = pid
		table.insert(out, e)
	end
	table.sort(out, function(a, b)
		return (a.updatedAt or 0) > (b.updatedAt or 0)
	end)
	return true, out
end

function ProjectStore:createProject(userId: number, name: string, template: string?)
	local pid = self:_newProjectId()
	local project
	if template == "demo" then
		project = Demo.build(pid, userId)
		project.meta.name = name
	else
		project = Format.newProject(pid, name, userId)
		-- новая карта сразу с платформой: на неё удобно ставить блоки, в игре это пол
		for _, o in Prefabs.baseplate(project) do
			project.map.objects[o.id] = o
		end
	end
	local e = Format.validateProject(project)
	if e then
		return false, "invalid: " .. e
	end
	-- сначала индекс (с проверкой лимита), потом черновик
	local ok, err = self:_update(indexKey(userId), function(index)
		index = index or { projects = {} }
		if Util.count(index.projects) >= MAX_PROJECTS then
			return nil, "too_many_projects"
		end
		index.projects[pid] = { name = name, updatedAt = self.now(), publishCode = nil }
		return index
	end)
	if not ok then
		return false, err
	end
	local now = self.now()
	ok, err = self:_update(draftKey(userId, pid), function(old)
		if old ~= nil then
			return nil, "exists"
		end
		return { rev = 1, savedAt = now, lock = { job = self.jobId, at = now }, data = project }
	end)
	if not ok then
		return false, err
	end
	return true, project, 1
end

-- Открытие черновика с захватом блокировки сессии
-- Возвращает ok, project, rev, readOnly
function ProjectStore:openDraft(userId: number, projectId: string)
	local now = self.now()
	local result, rev, readOnly = nil, 0, false
	local ok, err = self:_update(draftKey(userId, projectId), function(old)
		if old == nil then
			return nil, "not_found"
		end
		local okM, data = Format.migrate(Util.deepCopy(old.data))
		if not okM then
			return nil, "cannot_open: " .. tostring(data)
		end
		result = data
		rev = old.rev
		local lock = old.lock
		if lock and lock.job ~= self.jobId and now - lock.at < self.lockTimeout then
			readOnly = true
			return nil, "locked"
		end
		old.lock = { job = self.jobId, at = now }
		return old
	end)
	if not ok then
		if err == "locked" then
			return true, result, rev, true
		end
		return false, err
	end
	return true, result, rev, readOnly
end

-- Запись черновика. baseRev — ревизия, на которой основаны правки
function ProjectStore:saveDraft(userId: number, project, baseRev: number)
	local e = Format.validateProject(project)
	if e then
		return false, "invalid: " .. e
	end
	local now = self.now()
	local snapshot = Util.deepCopy(project)
	local newRev = 0
	local ok, err = self:_update(draftKey(userId, project.id), function(old)
		if old == nil then
			return nil, "not_found"
		end
		if old.rev ~= baseRev then
			return nil, "conflict"
		end
		local lock = old.lock
		if lock and lock.job ~= self.jobId and now - lock.at < self.lockTimeout then
			return nil, "locked"
		end
		newRev = old.rev + 1
		return { rev = newRev, savedAt = now, lock = { job = self.jobId, at = now }, data = snapshot }
	end)
	if not ok then
		return false, err
	end
	-- индекс обновляем после подтверждённой записи черновика; его сбой не отменяет сохранение
	self:_update(indexKey(userId), function(index)
		if not index or not index.projects[project.id] then
			return nil
		end
		index.projects[project.id].name = project.meta.name
		index.projects[project.id].updatedAt = now
		return index
	end)
	return true, newRev
end

function ProjectStore:releaseLock(userId: number, projectId: string)
	return self:_update(draftKey(userId, projectId), function(old)
		if old == nil or not old.lock or old.lock.job ~= self.jobId then
			return nil, "not_owner"
		end
		old.lock = nil
		return old
	end)
end

function ProjectStore:_newCode(): string
	local chars = {}
	for i = 1, 6 do
		local k = self.random:NextInteger(1, #CODE_ALPHABET)
		chars[i] = string.sub(CODE_ALPHABET, k, k)
	end
	return table.concat(chars)
end

-- Публикация: snapshot уже проверен и отфильтрован вызывающим кодом
-- Возвращает ok, code, version
function ProjectStore:publish(userId: number, project, snapshot)
	local e = Format.validateProject(snapshot)
	if e then
		return false, "invalid: " .. e
	end
	local code = project.meta.publishCode
	local now = self.now()
	if not code then
		for _ = 1, 8 do
			local candidate = self:_newCode()
			local ok = self:_update(pubKey(candidate), function(old)
				if old ~= nil then
					return nil, "taken"
				end
				return { projectId = project.id, ownerId = userId, name = project.meta.name, latest = 0, createdAt = now }
			end)
			if ok then
				code = candidate
				break
			end
		end
		if not code then
			return false, "no_code"
		end
	end
	local okPtr, ptr = self:_get(pubKey(code :: string))
	if not okPtr then
		return false, ptr
	end
	if not ptr or ptr.ownerId ~= userId or ptr.projectId ~= project.id then
		return false, "not_owner"
	end
	local version = (ptr.latest or 0) + 1
	local frozen = Util.deepCopy(snapshot)
	frozen.meta.publishCode = code
	frozen.meta.publishedVersion = version
	-- сначала неизменяемая версия, потом указатель на неё
	local ok, err = self:_update(pubVersionKey(code :: string, version), function(old)
		if old ~= nil then
			return nil, "version_exists"
		end
		return { version = version, publishedAt = now, data = frozen }
	end)
	if not ok then
		return false, err
	end
	ok, err = self:_update(pubKey(code :: string), function(old)
		if not old or old.ownerId ~= userId then
			return nil, "not_owner"
		end
		if (old.latest or 0) >= version then
			return nil, "stale"
		end
		old.latest = version
		old.name = project.meta.name
		old.updatedAt = now
		old.unlisted = false
		return old
	end)
	if not ok then
		return false, err
	end
	self:_update(indexKey(userId), function(index)
		if not index or not index.projects[project.id] then
			return nil
		end
		index.projects[project.id].publishCode = code
		index.projects[project.id].publishedVersion = version
		return index
	end)
	self:_update("catalog", function(cat)
		cat = cat or { entries = {} }
		for i = #cat.entries, 1, -1 do
			if cat.entries[i].code == code then
				table.remove(cat.entries, i)
			end
		end
		table.insert(cat.entries, 1, { code = code, name = project.meta.name, ownerId = userId, version = version, at = now })
		while #cat.entries > CATALOG_SIZE do
			table.remove(cat.entries)
		end
		return cat
	end)
	return true, code, version
end

-- Загрузка опубликованной карты по коду (последняя или указанная версия)
function ProjectStore:loadPublished(code: string, version: number?)
	code = string.upper(Util.trim(code))
	if not string.match(code, "^[A-Z0-9]+$") or #code ~= 6 then
		return false, "bad_code"
	end
	local ok, ptr = self:_get(pubKey(code))
	if not ok then
		return false, ptr
	end
	if not ptr or (ptr.latest or 0) < 1 or ptr.unlisted then
		return false, "not_found"
	end
	local v = version or ptr.latest
	local okV, rec = self:_get(pubVersionKey(code, v))
	if not okV then
		return false, rec
	end
	if not rec then
		return false, "not_found"
	end
	local okM, data = Format.migrate(Util.deepCopy(rec.data))
	if not okM then
		return false, "cannot_open"
	end
	return true, data, v, ptr
end

function ProjectStore:catalog()
	local ok, cat = self:_get("catalog")
	if not ok then
		return false, cat
	end
	return true, (cat and cat.entries) or {}
end

-- Снятие с публикации (админ-панель или автор)
function ProjectStore:unlist(code: string)
	local ok, err = self:_update(pubKey(code), function(old)
		if not old then
			return nil, "not_found"
		end
		old.unlisted = true
		return old
	end)
	if not ok then
		return false, err
	end
	self:_update("catalog", function(cat)
		if not cat then
			return nil
		end
		for i = #cat.entries, 1, -1 do
			if cat.entries[i].code == code then
				table.remove(cat.entries, i)
			end
		end
		return cat
	end)
	return true
end

-- «Витрина»: опубликованная карта, которую видят все вместо меню создателя
function ProjectStore:getShowcase()
	local ok, rec = self:_get("showcase")
	if not ok then
		return false, rec
	end
	if rec and rec.enabled and type(rec.code) == "string" then
		return true, rec
	end
	return true, nil
end

function ProjectStore:setShowcase(code: string?, userId: number)
	if code then
		local okP, data = self:loadPublished(code)
		if not okP then
			return false, data
		end
		code = data.meta.publishCode
		local name = data.meta.name
		return self:_update("showcase", function()
			return { enabled = true, code = code, name = name, setBy = userId, at = self.now() }
		end)
	end
	return self:_update("showcase", function()
		return { enabled = false, setBy = userId, at = self.now() }
	end)
end

-- «Мои модели»
function ProjectStore:saveLibraryModel(userId: number, asset)
	if Util.approxSize(asset) > 200000 then
		return false, "too_large"
	end
	local assetId = string.format("m%x%04x", self.now(), self.random:NextInteger(0, 0xffff))
	local ok, err = self:_update(libKey(userId), function(lib)
		lib = lib or { models = {} }
		if Util.count(lib.models) >= 60 then
			return nil, "library_full"
		end
		lib.models[assetId] = asset
		return lib
	end)
	if not ok then
		return false, err
	end
	return true, assetId
end

function ProjectStore:listLibrary(userId: number)
	local ok, lib = self:_get(libKey(userId))
	if not ok then
		return false, lib
	end
	local out = {}
	for id, a in (lib and lib.models) or {} do
		table.insert(out, { id = id, name = a.name, savedAt = a.savedAt })
	end
	table.sort(out, function(a, b)
		return (a.savedAt or 0) > (b.savedAt or 0)
	end)
	return true, out
end

function ProjectStore:getLibraryModel(userId: number, assetId: string)
	local ok, lib = self:_get(libKey(userId))
	if not ok then
		return false, lib
	end
	local a = lib and lib.models[assetId]
	if not a then
		return false, "not_found"
	end
	return true, a
end

return ProjectStore
