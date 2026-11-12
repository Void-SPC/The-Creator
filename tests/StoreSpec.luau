local Core = game:GetService("ServerScriptService").Workshop.Core
local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local ProjectStore = require(Core.ProjectStore)
local Util = require(Shared.Util)
local Ops = require(Shared.Ops)
local Prefabs = require(Shared.Prefabs)
local Demo = require(Shared.Demo)

-- DataStore в памяти с управляемыми сбоями
local function memoryAdapter()
	local a = { data = {}, failReads = false, failWrites = false, writes = 0 }
	a.get = function(key)
		if a.failReads then
			error("DataStore request failed")
		end
		return Util.deepCopy(a.data[key])
	end
	a.update = function(key, fn)
		if a.failWrites then
			error("DataStore request failed")
		end
		local nv = fn(Util.deepCopy(a.data[key]))
		if nv ~= nil then
			a.writes += 1
			a.data[key] = Util.deepCopy(nv)
		end
		return Util.deepCopy(nv)
	end
	return a
end

local function rng()
	local n = 0
	return {
		NextInteger = function(_, lo, hi)
			n += 7
			return lo + (n % (hi - lo + 1))
		end,
	}
end

return function(T)
	T.suite("ProjectStore")
	local clock = 1000
	local function store(adapter, job)
		return ProjectStore.new(adapter, { jobId = job or "A", now = function()
			return clock
		end, random = rng() })
	end

	T.test("save is confirmed only after the write", function()
		local ad = memoryAdapter()
		local s = store(ad)
		local ok, p, rev = s:createProject(1, "Комната", nil)
		T.ok(ok, tostring(p))
		ad.failWrites = true
		local ok2, err = s:saveDraft(1, p, rev)
		T.ok(not ok2, "failed write is not reported as saved")
		T.ok(string.find(err, "write_failed", 1, true) ~= nil)
		ad.failWrites = false
		local ok3, rev3 = s:saveDraft(1, p, rev)
		T.ok(ok3)
		T.eq(rev3, rev + 1)
	end)

	T.test("load error never overwrites the map", function()
		local ad = memoryAdapter()
		local s = store(ad)
		local _, p = s:createProject(1, "Особняк", "demo")
		local before = Util.deepCopy(ad.data)
		ad.failReads = true
		ad.failWrites = true
		local ok = s:openDraft(1, p.id)
		T.ok(not ok)
		local okList = s:listProjects(1)
		T.ok(not okList, "list fails instead of returning empty")
		ad.failReads = false
		ad.failWrites = false
		T.ok(Util.deepEqual(ad.data, before), "nothing was written")
		-- повреждённые данные тоже не открываются как пустая карта
		ad.data[string.format("u%d:draft:%s", 1, p.id)].data.format = 99
		local ok2, err2 = s:openDraft(1, p.id)
		T.ok(not ok2)
		T.ok(string.find(err2, "cannot_open", 1, true) ~= nil)
	end)

	T.test("reconnect opens last confirmed version", function()
		local ad = memoryAdapter()
		local s = store(ad, "A")
		local _, p, rev = s:createProject(1, "Комната", nil)
		local part = Prefabs.shape(p, "Block", { 0, 0, 0 })
		Ops.apply(p, { op = "add", obj = part })
		local _, rev2 = s:saveDraft(1, p, rev)
		-- правка, которая не успела сохраниться (обрыв связи)
		Ops.apply(p, { op = "set", id = part.id, path = { "pos" }, value = { 50, 2, 0 } })
		s:releaseLock(1, p.id)
		local s2 = store(ad, "B")
		local ok, p2, rev3, readOnly = s2:openDraft(1, p.id)
		T.ok(ok)
		T.ok(not readOnly)
		T.eq(rev3, rev2)
		T.eq(p2.map.objects[part.id].pos[1], 0, "unsaved edit is not there, confirmed one is")
	end)

	T.test("second server sees lock until timeout", function()
		local ad = memoryAdapter()
		local s = store(ad, "A")
		local _, p, rev = s:createProject(1, "Комната", nil)
		local s2 = store(ad, "B")
		local ok, _, _, readOnly = s2:openDraft(1, p.id)
		T.ok(ok)
		T.ok(readOnly, "draft is read-only while another server holds it")
		local okSave, err = s2:saveDraft(1, p, rev)
		T.ok(not okSave)
		T.eq(err, "locked")
		clock += 500
		ok, _, _, readOnly = s2:openDraft(1, p.id)
		T.ok(ok)
		T.ok(not readOnly, "stale lock is taken over")
		-- старый сервер больше не может перезаписать
		local okOld, errOld = s:saveDraft(1, p, rev)
		T.ok(not okOld)
		T.eq(errOld, "locked")
	end)

	T.test("published version does not change with the draft", function()
		local ad = memoryAdapter()
		local s = store(ad)
		local _, p, rev = s:createProject(7, "Шум за дверью", "demo")
		local ok, code, v = s:publish(7, p, Util.deepCopy(p))
		T.ok(ok, tostring(code))
		T.eq(v, 1)
		T.eq(#code, 6)
		-- автор продолжает править черновик
		local lamp = Demo.idOf(p, "HallLamp") :: string
		Ops.apply(p, { op = "remove", id = lamp })
		p.meta.publishCode = code
		s:saveDraft(7, p, rev)
		-- второй игрок запускает карту по коду
		local other = store(ad, "C")
		local ok2, data, ver = other:loadPublished(string.lower(code))
		T.ok(ok2, tostring(data))
		T.eq(ver, 1)
		T.ok(data.map.objects[lamp] ~= nil, "lamp is still in published version")
		-- следующая публикация выпускает версию 2 с тем же кодом
		local ok3, code3, v3 = s:publish(7, p, Util.deepCopy(p))
		T.ok(ok3)
		T.eq(code3, code)
		T.eq(v3, 2)
		local _, data2 = other:loadPublished(code)
		T.eq(data2.map.objects[lamp], nil)
		local _, data1 = other:loadPublished(code, 1)
		T.ok(data1.map.objects[lamp] ~= nil, "old version stays available")
		local okCat, entries = other:catalog()
		T.ok(okCat)
		T.eq(entries[1].code, code)
	end)

	T.test("cannot publish over another author's code", function()
		local ad = memoryAdapter()
		local s = store(ad)
		local _, p = s:createProject(1, "Моя", nil)
		local _, code = s:publish(1, p, Util.deepCopy(p))
		local _, q = s:createProject(2, "Чужая", nil)
		q.meta.publishCode = code
		local ok, err = s:publish(2, q, Util.deepCopy(q))
		T.ok(not ok)
		T.eq(err, "not_owner")
	end)

	T.test("library models", function()
		local ad = memoryAdapter()
		local s = store(ad)
		local ok, id = s:saveLibraryModel(1, { name = "Шкаф", object = {}, savedAt = 1 })
		T.ok(ok)
		local _, list = s:listLibrary(1)
		T.eq(list[1].id, id)
		local okG, asset = s:getLibraryModel(1, id)
		T.ok(okG)
		T.eq(asset.name, "Шкаф")
	end)
end
