local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Format = require(Shared.Format)
local Ops = require(Shared.Ops)
local Model = require(Shared.Model)
local Prefabs = require(Shared.Prefabs)
local MathX = require(Shared.MathX)
local Util = require(Shared.Util)

return function(T)
	T.suite("Model")
	local function addAll(p, objs)
		for _, o in objs do
			assert(Ops.apply(p, { op = "add", obj = o }))
		end
	end
	T.test("glue keeps world positions and makes a model", function()
		local p = Format.newProject("p", "Карта", 1)
		local a = Prefabs.shape(p, "Block", { 0, 0, 0 })
		addAll(p, { a })
		local b = Prefabs.shape(p, "Ball", { 6, 0, 0 })
		b.rot = { 0, 30, 0 }
		addAll(p, { b })
		local op, m = Model.glue(p, { a.id, b.id }, "Шкаф")
		T.ok(op, tostring(m))
		T.ok(Ops.apply(p, op))
		T.eq(p.map.objects[a.id], nil)
		local model = p.map.objects[m.id]
		T.eq(model.kind, "model")
		local found = 0
		for pid, part in model.model.parts do
			local w = Model.partWorld(model, pid)
			if part.shape == "Ball" then
				T.vnear(w.p, { 6, 2, 0 })
				local _, rot = MathX.decompose(w)
				T.near(rot[2], 30)
				found += 1
			else
				T.vnear(w.p, { 0, 2, 0 })
				found += 1
			end
		end
		T.eq(found, 2)
		T.eq(Format.validateObject(model), nil)
	end)
	T.test("moving the model moves all parts", function()
		local p = Format.newProject("p", "Карта", 1)
		local objs = Prefabs.build(p, "closet", { 0, 0, 0 })
		addAll(p, objs)
		local closet = objs[1]
		T.ok(Ops.apply(p, { op = "set", id = closet.id, path = { "pos" }, value = { 10, 0, 0 } }))
		for pid in closet.model.parts do
			local w = Model.partWorld(p.map.objects[closet.id], pid)
			T.ok(w.p[1] > 7, "part moved with model")
		end
	end)
	T.test("duplicate gives new ids and remaps internal refs", function()
		local p = Format.newProject("p", "Карта", 1)
		local zone = Prefabs.build(p, "zone", { 0, 0, 0 })[1]
		local npc = Prefabs.build(p, "npcNew", { 0, 0, 0 })[1]
		local lamp = Prefabs.build(p, "lamp", { 0, 0, 0 })[1]
		npc.role.trigger = "roomEnter"
		npc.role.zone = { ref = zone.id }
		npc.role.anchor = { ref = lamp.id }
		addAll(p, { zone, npc, lamp })
		local op, copies, mapping = Model.duplicate(p, { zone.id, npc.id })
		T.ok(Ops.apply(p, op))
		T.eq(#copies, 2)
		local npcCopy = p.map.objects[mapping[npc.id]]
		T.ok(npcCopy.id ~= npc.id)
		T.eq(npcCopy.role.zone.ref, mapping[zone.id], "ref inside group goes to copy")
		T.eq(npcCopy.role.anchor.ref, lamp.id, "ref outside group stays")
		T.ok(npcCopy.latin ~= npc.latin)
	end)
	T.test("asset roundtrip keeps parts, joints and clips", function()
		local p = Format.newProject("p", "Карта", 1)
		local fox = Prefabs.build(p, "fox", { 0, 0, 0 })[1]
		addAll(p, { fox })
		local asset = Model.toAsset(fox, "Лисик")
		local p2 = Format.newProject("p2", "Другая", 1)
		local copy = Model.fromAsset(p2, asset, { 5, 0, 5 })
		T.ok(Ops.apply(p2, { op = "add", obj = copy }))
		local nParts, nJoints, nClips = 0, 0, 0
		for _, part in copy.model.parts do
			nParts += 1
			if part.parent then
				nJoints += 1
			end
		end
		for _ in copy.model.clips do
			nClips += 1
		end
		T.ok(nParts >= 12)
		T.ok(nJoints >= 10)
		T.eq(nClips, 6)
	end)
	T.test("paste works after the original is deleted", function()
		local p = Format.newProject("p", "Карта", 1)
		local zone = Prefabs.build(p, "zone", { 0, 0, 0 })[1]
		local npc = Prefabs.build(p, "npcNew", { 2, 1, 0 })[1]
		npc.role.trigger = "roomEnter"
		npc.role.zone = { ref = zone.id }
		addAll(p, { zone, npc })
		local clipboard = { Util.deepCopy(zone), Util.deepCopy(npc) }
		T.ok(Ops.apply(p, { op = "batch", ops = { { op = "remove", id = zone.id }, { op = "remove", id = npc.id } } }))
		local op, copies = Model.paste(p, clipboard, { 20, 0, 30 })
		T.ok(Ops.apply(p, op))
		T.eq(copies[1].pos[1], 20)
		T.eq(copies[1].pos[3], 30)
		T.eq(copies[2].pos[1], 22, "group keeps its shape")
		T.eq(copies[2].role.zone.ref, copies[1].id, "refs inside the group follow the copies")
	end)

	T.test("cannot glue objects with roles", function()
		local p = Format.newProject("p", "Карта", 1)
		local lamp = Prefabs.build(p, "lamp", { 0, 0, 0 })[1]
		addAll(p, { lamp })
		local op, err = Model.glue(p, { lamp.id })
		T.eq(op, nil)
		T.eq(err, "has role")
	end)
end
