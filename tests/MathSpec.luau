local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local MathX = require(Shared.MathX)
local Rig = require(Shared.Rig)

return function(T)
	T.suite("MathX")
	T.test("euler roundtrip", function()
		for _, e in { { 10, 20, 30 }, { -45, 90 - 1, 5 }, { 0, 180, 0 }, { 30, -120, 60 } } do
			local back = MathX.eulerFromMat(MathX.matFromEuler(e))
			local m1, m2 = MathX.matFromEuler(e), MathX.matFromEuler(back)
			for i = 1, 9 do
				T.near(m1[i], m2[i], 1e-4)
			end
		end
	end)
	T.test("inverse and local space", function()
		local a = MathX.tf({ 5, 1, -3 }, { 0, 90, 0 })
		local b = MathX.tf({ 7, 1, -3 }, { 0, 90, 0 })
		local l = MathX.toLocal(a, b)
		local w = MathX.toWorld(a, l)
		T.vnear(w.p, b.p)
		-- поворот 90 вокруг Y: локальная +X мира становится -Z... проверяем точку
		T.vnear(MathX.apply(a, { 0, 0, -2 }), { 3, 1, -3 })
	end)
	T.test("slerp halfway", function()
		local a = MathX.tf({ 0, 0, 0 }, { 0, 0, 0 })
		local b = MathX.tf({ 2, 0, 0 }, { 0, 90, 0 })
		local h = MathX.tfLerp(a, b, 0.5)
		local _, rot = MathX.decompose(h)
		T.near(rot[2], 45, 1e-3)
		T.vnear(h.p, { 1, 0, 0 })
	end)

	T.suite("Rig")
	local function headModel()
		return {
			parts = {
				body = { id = "body", pos = { 0, 2, 0 }, rot = { 0, 0, 0 }, pivot = { 0, 0, 0 } },
				head = { id = "head", pos = { 0, 4, 0 }, rot = { 0, 0, 0 }, pivot = { 0, -1, 0 }, parent = "body" },
				earL = { id = "earL", pos = { -0.5, 5.5, 0 }, rot = { 0, 0, 0 }, pivot = { 0, -0.5, 0 }, parent = "head" },
				earR = { id = "earR", pos = { 0.5, 5.5, 0 }, rot = { 0, 0, 0 }, pivot = { 0, -0.5, 0 }, parent = "head" },
			},
		}
	end
	T.test("head rotation carries ears", function()
		local m = headModel()
		local base = MathX.tfIdentity()
		local w = Rig.pose(m, { head = { pos = { 0, 0, 0 }, rot = { 0, 0, 90 } } }, base)
		-- голова поворачивается вокруг шеи (0,3,0): ухо в (-0.5, 5.5) уезжает
		T.vnear(w.head.p, { -1, 3, 0 }, 1e-3, "head center")
		T.vnear(w.earL.p, { -2.5, 2.5, 0 }, 1e-3, "left ear follows head")
		local _, rot = MathX.decompose(w.earL)
		T.near(rot[3], 90, 1e-3)
	end)
	T.test("ear rotates on its own", function()
		local m = headModel()
		local w = Rig.pose(m, { earL = { pos = { 0, 0, 0 }, rot = { 30, 0, 0 } } }, MathX.tfIdentity())
		T.vnear(w.earR.p, { 0.5, 5.5, 0 }, 1e-3, "other ear unchanged")
		T.vnear(w.head.p, { 0, 4, 0 }, 1e-3, "head unchanged")
		local _, rot = MathX.decompose(w.earL)
		T.near(rot[1], 30, 1e-3)
	end)
	T.test("solveDelta inverts pose", function()
		local m = headModel()
		local modelTf = MathX.tf({ 10, 0, 3 }, { 0, 45, 0 })
		local sample = { head = { pos = { 0, 0, 0 }, rot = { 0, 20, 10 } } }
		local w = Rig.pose(m, sample, modelTf)
		local desired = MathX.mul(w.earL, MathX.tf({ 0, 0.2, 0 }, { 15, 0, 0 }))
		local dp, dr = Rig.solveDelta(m, w, modelTf, "earL", desired)
		sample.earL = { pos = dp, rot = dr }
		local w2 = Rig.pose(m, sample, modelTf)
		T.vnear(w2.earL.p, desired.p, 1e-3)
		for i = 1, 9 do
			T.near(w2.earL.m[i], desired.m[i], 1e-4)
		end
	end)
	T.test("no cycles in joints", function()
		local m = headModel()
		T.ok(not Rig.setParent(m, "body", "earL"), "cycle must be rejected")
		T.ok(Rig.setParent(m, "earR", "body"))
	end)
	T.test("remove part keeps children attached to grandparent", function()
		local m = headModel()
		Rig.removePart(m, "head")
		T.eq(m.parts.earL.parent, "body")
	end)
end
