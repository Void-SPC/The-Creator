-- Сквозной сценарий из ТЗ на уровне ядра (без Roblox):
-- комната -> шкаф из фигур -> склейка -> назначение шкафа и две анимации -> лампа ->
-- реакция на открытие двери -> сохранение -> публикация -> запуск по коду вторым игроком

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Core = game:GetService("ServerScriptService").Workshop.Core
local Util = require(Shared.Util)
local Ops = require(Shared.Ops)
local Model = require(Shared.Model)
local Prefabs = require(Shared.Prefabs)
local Closet = require(Shared.Closet)
local Anim = require(Shared.Anim)
local Logic = require(Shared.Logic)
local Format = require(Shared.Format)
local MathX = require(Shared.MathX)
local ProjectStore = require(Core.ProjectStore)

local function memoryAdapter()
	local a = { data = {} }
	a.get = function(key)
		return Util.deepCopy(a.data[key])
	end
	a.update = function(key, fn)
		local nv = fn(Util.deepCopy(a.data[key]))
		if nv ~= nil then
			a.data[key] = Util.deepCopy(nv)
		end
		return Util.deepCopy(nv)
	end
	return a
end

local function rng()
	local n = 0
	return { NextInteger = function(_, lo, hi)
		n += 13
		return lo + (n % (hi - lo + 1))
	end }
end

return function(T)
	T.suite("Scenario")
	T.test("tablet author flow end to end", function()
		local clock = 5000
		local ad = memoryAdapter()
		local author = ProjectStore.new(ad, { jobId = "server-A", now = function()
			return clock
		end, random = rng() })
		local ok, p, rev = author:createProject(42, "Одна комната", nil)
		T.ok(ok)

		-- клиент и сервер применяют одни и те же правки
		local server = Util.deepCopy(p)
		local history = Ops.newHistory()
		local function edit(op)
			local okC, inv = Ops.apply(p, op)
			assert(okC, tostring(inv))
			Ops.record(history, inv, op)
			local okS, err = Ops.apply(server, op)
			assert(okS, "server rejected: " .. tostring(err))
		end
		local function addAll(objs)
			local ops = {}
			for _, o in objs do
				table.insert(ops, { op = "add", obj = o })
			end
			edit({ op = "batch", ops = ops })
		end

		-- 1. комната
		addAll(Prefabs.room(p, 20, 20, 10))
		local spawn = Prefabs.build(p, "spawn", { 0, 0, -6 })
		addAll(spawn)
		local door = Prefabs.build(p, "door", { 0, 0, -9.5 })[1]
		door.latin = "FrontDoor"
		addAll({ door })

		-- 2. шкаф из фигур: задняя стенка, бока, крыша
		local parts = {}
		for _, spec in { { { 4, 7, 0.3 }, { 6, 4.5, 8.35 } }, { { 0.3, 7, 3 }, { 4.15, 4.5, 7 } }, { { 0.3, 7, 3 }, { 7.85, 4.5, 7 } }, { { 4, 0.3, 3 }, { 6, 8.15, 7 } } } do
			local part = Prefabs.shape(p, "Block", { 0, 0, 0 })
			part.size = spec[1]
			part.pos = spec[2]
			part.material = "Wood"
			addAll({ part })
			table.insert(parts, part.id)
		end
		-- отмена и повтор работают на любом шаге
		T.ok(Ops.apply(p, Ops.popUndo(history)))
		Ops.apply(server, { op = "remove", id = parts[4] })
		T.ok(Ops.apply(p, Ops.popRedo(history)))
		Ops.apply(server, { op = "add", obj = p.map.objects[parts[4]] })

		local glueOp, closet = Model.glue(p, parts, "Шкаф")
		T.ok(glueOp)
		edit(glueOp)
		edit({ op = "set", id = closet.id, path = { "latin" }, value = "Closet01" })
		-- 3. назначить как шкаф: точки и два независимых клипа
		edit({ op = "set", id = closet.id, path = { "role" }, value = Closet.newRole(3) })
		local role = p.map.objects[closet.id].role
		T.eq(role.enterClip.name, "EnterCloset")
		T.eq(role.exitClip.name, "ExitCloset")
		-- автор правит клип входа: добавляет промежуточный ключ (пригнуться у дверцы)
		local enter = Util.deepCopy(role.enterClip)
		Anim.setKey(enter, "PlayerRoot", 0.45, { 0, -0.5, -1.5 }, { 0, 180, 0 })
		edit({ op = "set", id = closet.id, path = { "role", "enterClip" }, value = enter })
		-- сохранить шкаф в «Мои модели»
		local okLib = author:saveLibraryModel(42, Model.toAsset(p.map.objects[closet.id], "Мой шкаф"))
		T.ok(okLib)

		-- 4. лампа и реакция на открытие двери
		local lamp = Prefabs.build(p, "lamp", { 0, 0, 0 })[1]
		lamp.latin = "HallLamp"
		addAll({ lamp })
		local source = "on DoorOpened(FrontDoor) do\n  Wait(0.5)\n  SetLight(HallLamp, false)\nend\n"
		local tree, perr = Logic.Parser.parse(source, Logic.nameResolver(p))
		T.eq(perr, nil)
		edit({ op = "setProject", path = { "logic", "blocks" }, value = tree })
		local _, errs = Logic.compile(p)
		T.eq(#errs, 0)

		-- 5. проверка и сохранение (подтверждённая запись)
		T.eq(Format.validateProject(server), nil)
		T.ok(Util.deepEqual(server.map, p.map), "client and server copies match")
		local okSave, rev2 = author:saveDraft(42, server, rev)
		T.ok(okSave)
		T.eq(rev2, rev + 1)

		-- 6. публикация
		local okPub, code, version = author:publish(42, server, Util.deepCopy(server))
		T.ok(okPub, tostring(code))
		T.eq(version, 1)

		-- 7. второй игрок на другом сервере запускает карту по коду
		local other = ProjectStore.new(ad, { jobId = "server-B", now = function()
			return clock
		end, random = rng() })
		local okLoad, data = other:loadPublished(code)
		T.ok(okLoad)
		local compiled = Logic.compile(data)
		local t = 0
		local lights = {}
		local rt = Logic.Interpreter.new(compiled, {
			now = function()
				return t
			end,
			action = function(name, args)
				if name == "SetLight" then
					lights[args[1].ref] = args[2]
				end
			end,
			condition = function()
				return false
			end,
			onError = function(e)
				error(e.message)
			end,
		})
		T.eq(rt.dispatch("DoorOpened", { { ref = door.id } }), 1)
		t = 1
		rt.update()
		T.eq(lights[lamp.id], false, "lamp went dark")

		-- 8. шкаф на опубликованной карте после поворота: точки едут вместе с ним
		local pubCloset = data.map.objects[closet.id]
		local entry0 = Closet.worldPose(pubCloset.pos, pubCloset.rot, pubCloset.role.entry)
		local rotated = Closet.worldPose(pubCloset.pos, { 0, 90, 0 }, pubCloset.role.entry)
		local d0 = MathX.len(MathX.sub(entry0.p, pubCloset.pos))
		local d1 = MathX.len(MathX.sub(rotated.p, pubCloset.pos))
		T.near(d0, d1, 1e-3, "entry stays at the same distance from the closet")
		local c = Closet.new()
		local lens = { enter = pubCloset.role.enterClip.length, exit = pubCloset.role.exitClip.length }
		local okEnter, _, token = Closet.request(c, 7, 0, lens)
		T.ok(okEnter)
		T.ok(not Closet.request(c, 7, 0.01, lens), "double tap ignored")
		T.ok(Closet.complete(c, token, 1))
		local okExit, action = Closet.request(c, 7, 2, lens)
		T.ok(okExit)
		T.eq(action, "exit")
	end)
end
