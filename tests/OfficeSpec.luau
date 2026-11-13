-- Монета-джентльмен и Инспектор из игры «Офисы» в каталоге мастерской

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Core = game:GetService("ServerScriptService").Workshop.Core
local Util = require(Shared.Util)
local Ops = require(Shared.Ops)
local Format = require(Shared.Format)
local Prefabs = require(Shared.Prefabs)
local Catalog = require(Shared.Catalog)
local Logic = require(Shared.Logic)
local Anim = require(Shared.Anim)
local Rig = require(Shared.Rig)
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
		n += 11
		return lo + (n % (hi - lo + 1))
	end }
end

local function clipNames(obj)
	local names = {}
	for _, c in obj.model.clips do
		table.insert(names, c.name)
	end
	table.sort(names)
	return table.concat(names, ", ")
end

local PART_KEYS = {
	id = true, name = true, shape = true, size = true, pos = true, rot = true, color = true,
	material = true, texture = true, transparency = true, pivot = true, parent = true,
}

return function(T)
	T.suite("Office models")

	T.test("catalog lists both models", function()
		local found = {}
		for _, e in Catalog.PREFABS do
			found[e.id] = true
		end
		T.ok(found.officeInspector and found.officeCoin and found.officeCoinMoustache)
	end)

	T.test("original parts, joints and clips are carried over", function()
		local p = Format.newProject("p", "Карта", 1)
		local insp = Prefabs.build(p, "officeInspector", { 0, 1, 0 })[1]
		local coin = Prefabs.build(p, "officeCoin", { 4, 1, 0 })[1]
		local coin2 = Prefabs.build(p, "officeCoinMoustache", { 8, 1, 0 })[1]
		for _, o in { insp, coin, coin2 } do
			T.eq(Format.validateObject(o), nil, o.name)
		end
		local n, joints, ellipsoids = 0, 0, 0
		for _, part in insp.model.parts do
			n += 1
			if part.parent then
				joints += 1
			end
			if part.shape == "Ellipsoid" then
				ellipsoids += 1
			end
		end
		T.eq(n, 34, "inspector parts: 14 body + 9 per side + reader")
		T.eq(joints, 33, "every part except pelvis hangs on a joint")
		T.ok(ellipsoids > 20, "limbs keep the sphere-mesh look")
		T.eq(insp.model.parts.EyePupil.material, "Neon")
		T.eq(insp.model.parts.Head.parent, "Neck")
		T.eq(clipNames(insp), "Захват, Ожидание, Требование карты, Ходьба")
		T.eq(clipNames(coin), "Ожидание, Требование оплаты")
		T.eq(coin.model.parts.Coin.material, "Metal")
		T.ok(coin.model.parts.Eye ~= nil and coin2.model.parts.Eye == nil, "two looks")
		T.ok(coin2.model.parts["Moustache-1"] ~= nil)
		-- клипы ссылаются только на существующие детали
		for _, o in { insp, coin, coin2 } do
			for _, c in o.model.clips do
				T.eq(#Anim.validate(c, o.model.parts), 0, o.name .. " / " .. c.name)
			end
		end
	end)

	T.test("no Office mechanics in the models", function()
		local p = Format.newProject("p", "Карта", 1)
		local insp = Prefabs.build(p, "officeInspector", { 0, 1, 0 })[1]
		local coin = Prefabs.build(p, "officeCoin", { 4, 1, 0 })[1]
		-- монета — обычный объект; Инспектор — NPC, который сам ни на что не реагирует
		T.eq(coin.role, nil)
		T.eq(insp.role.type, "npc")
		T.eq(insp.role.trigger, "logic")
		T.eq(#insp.role.lines, 0)
		T.eq(insp.role.zone, nil)
		for _, o in { insp, coin } do
			for _, part in o.model.parts do
				for k in part do
					T.ok(PART_KEYS[k], "unexpected field " .. tostring(k))
				end
			end
		end
		-- в карте без логики касание и приближение ничего не запускают
		for _, o in { insp, coin } do
			T.ok(Ops.apply(p, { op = "add", obj = o }))
		end
		local tree = Logic.compile(p)
		local calls = 0
		local rt = Logic.Interpreter.new(tree, {
			now = function()
				return 0
			end,
			action = function()
				calls += 1
			end,
			condition = function()
				return false
			end,
			onError = function() end,
		})
		T.eq(rt.dispatch("Interacted", { { ref = coin.id } }), 0)
		T.eq(rt.dispatch("Interacted", { { ref = insp.id } }), 0)
		T.eq(rt.dispatch("ZoneEntered", { { ref = insp.id } }), 0)
		T.eq(calls, 0)
	end)

	T.test("each inserted copy has its own settings", function()
		local p = Format.newProject("p", "Карта", 1)
		local a = Prefabs.build(p, "officeCoin", { 0, 1, 0 })[1]
		T.ok(Ops.apply(p, { op = "add", obj = a }))
		local b = Prefabs.build(p, "officeCoin", { 6, 1, 0 })[1]
		T.ok(Ops.apply(p, { op = "add", obj = b }))
		T.ok(a.id ~= b.id and a.latin ~= b.latin)
		T.ok(Ops.apply(p, { op = "set", id = a.id, path = { "model", "parts", "Coin", "color" }, value = { 255, 0, 0 } }))
		T.ok(Ops.apply(p, { op = "set", id = a.id, path = { "model", "clips", "c1", "loop" }, value = false }))
		T.eq(p.map.objects[b.id].model.parts.Coin.color[1], 206, "other copy keeps original color")
		T.eq(p.map.objects[b.id].model.clips.c1.loop, true, "other copy keeps its clip settings")
	end)

	T.test("clips move the model parts", function()
		local p = Format.newProject("p", "Карта", 1)
		local insp = Prefabs.build(p, "officeInspector", { 0, 0, 0 })[1]
		local demand
		for _, c in insp.model.clips do
			if c.name == "Требование карты" then
				demand = c
			end
		end
		local rest = Rig.pose(insp.model, nil, MathX.tfIdentity())
		local posed = Rig.pose(insp.model, Anim.sample(demand, 1), MathX.tfIdentity())
		-- правая рука со считывателем вытянута вперёд
		T.ok(posed.Reader.p[3] < rest.Reader.p[3] - 1, "reader moves forward")
		T.ok(MathX.len(MathX.sub(posed.Reader.p, rest.Reader.p)) > 1.5)
	end)

	T.test("author binds one clip to each model, saves and reopens", function()
		local clock = 100
		local ad = memoryAdapter()
		local store = ProjectStore.new(ad, { jobId = "A", now = function()
			return clock
		end, random = rng() })
		local ok, p, rev = store:createProject(9, "Офис", nil)
		T.ok(ok)
		-- вставка из каталога, как делает редактор
		local coin = Prefabs.build(p, "officeCoin", { 0, 1, 0 })[1]
		T.ok(Ops.apply(p, { op = "add", obj = coin }))
		local insp = Prefabs.build(p, "officeInspector", { 6, 1, 0 })[1]
		T.ok(Ops.apply(p, { op = "add", obj = insp }))
		-- дерево блоков, которое собирает вкладка «Логика»
		local tree = {
			handlers = {
				{
					kind = "handler", event = "Interacted", bid = "b1",
					args = { { kind = "ref", ref = coin.id } },
					body = { { kind = "call", name = "PlayClip", bid = "b2", args = {
						{ kind = "ref", ref = coin.id }, { kind = "str", value = "Требование оплаты" }, { kind = "bool", value = false },
					} } },
				},
				{
					kind = "handler", event = "ZoneEntered", bid = "b3",
					args = { { kind = "ref", ref = coin.id } },
					body = {},
				},
				{
					kind = "handler", event = "MapStarted", bid = "b4", args = {},
					body = { { kind = "call", name = "PlayClip", bid = "b5", args = {
						{ kind = "ref", ref = insp.id }, { kind = "str", value = "Захват" },
					} } },
				},
			},
		}
		table.remove(tree.handlers, 2) -- случайно добавленный пустой блок автор удалил
		T.ok(Ops.apply(p, { op = "setProject", path = { "logic", "blocks" }, value = tree }))
		local _, errs = Logic.compile(p)
		T.eq(#errs, 0, T.show(errs))
		local okSave = store:saveDraft(9, p, rev)
		T.ok(okSave)
		store:releaseLock(9, p.id)

		-- перезаход: другой сервер открывает последнюю подтверждённую версию
		local other = ProjectStore.new(ad, { jobId = "B", now = function()
			return clock
		end, random = rng() })
		local okOpen, reopened = other:openDraft(9, p.id)
		T.ok(okOpen)
		local compiled, errs2 = Logic.compile(reopened)
		T.eq(#errs2, 0)
		local played = {}
		local rt = Logic.Interpreter.new(compiled, {
			now = function()
				return 0
			end,
			action = function(name, args)
				if name == "PlayClip" then
					table.insert(played, args[1].ref .. ":" .. args[2])
				end
			end,
			condition = function()
				return false
			end,
			onError = function(e)
				error(e.message)
			end,
		})
		rt.dispatch("MapStarted", {})
		rt.dispatch("Interacted", { { ref = coin.id } })
		T.eq(played[1], insp.id .. ":Захват")
		T.eq(played[2], coin.id .. ":Требование оплаты")
		-- у открытой заново карты эти клипы есть у моделей и проигрываются
		local function clipOf(obj, name)
			for _, c in obj.model.clips do
				if c.name == name then
					return c
				end
			end
			return nil
		end
		local grab = clipOf(reopened.map.objects[insp.id], "Захват")
		T.ok(grab and not grab.loop)
		T.ok(next(Anim.sample(grab, 0.8)) ~= nil)
		T.ok(clipOf(reopened.map.objects[coin.id], "Требование оплаты") ~= nil)
	end)
end
