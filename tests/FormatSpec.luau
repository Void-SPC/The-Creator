local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Format = require(Shared.Format)
local Demo = require(Shared.Demo)
local Prefabs = require(Shared.Prefabs)
local Catalog = require(Shared.Catalog)

return function(T)
	T.suite("Format")
	T.test("new project is valid", function()
		local p = Format.newProject("p1", "Карта", 1)
		T.eq(Format.validateProject(p), nil)
	end)
	T.test("demo project is valid", function()
		local p = Demo.build("p2", 1)
		T.eq(Format.validateProject(p), nil)
	end)
	T.test("every prefab is valid", function()
		local p = Format.newProject("p3", "Карта", 1)
		for _, entry in Catalog.PREFABS do
			local objs = Prefabs.build(p, entry.id, { 0, 0, 0 })
			T.ok(objs and #objs > 0, entry.id)
			for _, o in objs do
				local e = Format.validateObject(o)
				T.eq(e, nil, entry.id)
			end
		end
	end)
	T.test("v1 data migrates", function()
		local old = {
			format = 1,
			name = "Старая карта",
			objects = { { id = "o_1", kind = "part", name = "Пол" } },
			settings = { fov = 80 },
			script = { handlers = {} },
		}
		local ok, p = Format.migrate(old)
		T.ok(ok, tostring(p))
		T.eq(p.format, Format.VERSION)
		T.eq(p.meta.name, "Старая карта")
		T.ok(p.map.objects.o_1)
		T.eq(p.settings.camera.fov, 80)
	end)
	T.test("future and broken versions are rejected without changes", function()
		local ok = Format.migrate({ format = 99 })
		T.ok(not ok)
		ok = Format.migrate({})
		T.ok(not ok)
	end)
	T.test("invalid values are rejected", function()
		local o = Format.newPart("o_1")
		o.size = { 0, 1, 1 }
		T.ok(Format.validateObject(o) ~= nil)
		o = Format.newPart("o_1")
		o.material = "Lava"
		T.ok(Format.validateObject(o) ~= nil)
		o = Format.newPart("o_1")
		o.latin = "Шкаф"
		T.ok(Format.validateObject(o) ~= nil, "latin must be latin")
		o = Format.newPart("o_1")
		o.texture = "rbxassetid://12a"
		T.ok(Format.validateObject(o) ~= nil, "bad texture id")
		o.texture = "spawn"
		T.eq(Format.validateObject(o), nil)
		o.texture = "rbxassetid://6372755229"
		o.textureTile = 8
		T.eq(Format.validateObject(o), nil, "own image by id")
		o.texture = "http://evil.example/x.png"
		T.ok(Format.validateObject(o) ~= nil, "only roblox asset ids")
		o.texture = nil
		o.material = "Asphalt"
		T.eq(Format.validateObject(o), nil, "all roblox materials")
	end)
end
