--!nonstrict
-- Шаблон «Корпорация»: дорога к небольшому дому-вестибюлю со статуей создателя,
-- большой зал со столами для каждого, второй этаж с деревянными перилами и личными
-- комнатами. При входе игрока ведут к дому (около 15 секунд), несколько игроков идут строем
-- Всё собрано из обычных объектов мастерской, поэтому шаблон можно менять в редакторе

local Format = require(script.Parent.Format)
local Ids = require(script.Parent.Ids)
local Prefabs = require(script.Parent.Prefabs)
local Logic = require(script.Parent.Logic)

local Corp = {}

Corp.SOURCE = [[
-- Вход: игрока ведут по дороге к дому
on PlayerJoined() do
  ShowMessage("Добро пожаловать в корпорацию", 4)
  WalkPlayer(Path1)
end

-- У входа дверь открывается, игрок проходит мимо статуи в зал
on PlayerArrived(Path3) do
  OpenDoor(MainDoor)
  WalkPlayer(Path4)
end

on PlayerArrived(Path5) do
  Wait(4)
  CloseDoor(MainDoor)
end
]]

local WALL = { 222, 216, 204 }

function Corp.build(projectId: string, ownerId: number, ownerName: string?)
	local p = Format.newProject(projectId, "Корпорация", ownerId)
	local function add(objs)
		for _, o in objs do
			p.map.objects[o.id] = o
		end
		return objs[1]
	end
	local function block(name, size, pos, color, material, latin)
		local o = Format.newPart(Ids.alloc(p, "o"), "Block")
		o.name = name
		o.size = size
		o.pos = pos
		o.color = color or WALL
		o.material = material or "Plaster"
		o.frozen = true
		if latin then
			o.latin = latin
		end
		p.map.objects[o.id] = o
		return o
	end
	local function prefab(id, at, rot)
		local o = add(Prefabs.build(p, id, at))
		if rot then
			o.rot = rot
		end
		return o
	end

	-- земля и дорога
	local ground = add(Prefabs.build(p, "baseplate", { 0, 0, -35 }))
	ground.name = "Газон"
	ground.color = { 75, 120, 60 }
	ground.material = "Grass"
	local spawn = prefab("spawn", { 0, 0, -150 })
	spawn.latin = "Start"
	local route = { { 0, -150 }, { -14, -110 }, { 12, -60 }, { 0, -16 }, { 0, -9 } }
	for i = 1, #route - 1 do
		local a, b = route[i], route[i + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		local road = block("Дорожка", { 6, 0.2, len + 3 }, { (a[1] + b[1]) / 2, 1.05, (a[2] + b[2]) / 2 }, { 150, 146, 140 }, "Pavement")
		road.rot = { 0, math.floor(math.deg(math.atan2(dx, dz)) * 1000 + 0.5) / 1000, 0 }
	end
	-- фонари вдоль дороги
	for i, xz in { { -6, -135 }, { 6, -120 }, { -18, -95 }, { 4, -80 }, { 17, -50 }, { -6, -30 } } do
		block("Столб фонаря", { 0.4, 8, 0.4 }, { xz[1], 5, xz[2] }, { 40, 40, 44 }, "Metal")
		local lamp = prefab("lamp", { xz[1], 0.3, xz[2] })
		lamp.name = "Фонарь " .. i
		lamp.latin = "StreetLamp" .. i
		lamp.role.range = 30
	end

	-- точки маршрута входа: Path1 -> Path2 -> Path3 у двери, затем Path4 -> Path5 в зал
	local function point(name, latin, x, z)
		local w = prefab("waypoint", { x, 0, z })
		w.name = name
		w.latin = latin
		return w
	end
	local p1 = point("Дорога 1", "Path1", -14, -110)
	local p2 = point("Дорога 2", "Path2", 12, -60)
	local p3 = point("У входа", "Path3", 0, -16)
	local p4 = point("У статуи", "Path4", -9, 6)
	local p5 = point("Зал", "Path5", 0, 32)
	p1.role.next = { ref = p2.id }
	p2.role.next = { ref = p3.id }
	p4.role.next = { ref = p5.id }

	-- вестибюль 36 × 30, высота 12
	block("Пол вестибюля", { 36, 0.2, 30 }, { 0, 1.1, 5 }, { 120, 84, 60 }, "WoodPlanks")
	block("Потолок вестибюля", { 37, 1, 31 }, { 0, 13.5, 5 }, WALL)
	block("Стена у входа", { 15, 12, 1 }, { -10.5, 7, -10 })
	block("Стена у входа", { 15, 12, 1 }, { 10.5, 7, -10 })
	block("Над входом", { 6, 4, 1 }, { 0, 11, -10 })
	block("Стена вестибюля", { 1, 12, 30 }, { -18.5, 7, 5 })
	block("Стена вестибюля", { 1, 12, 30 }, { 18.5, 7, 5 })
	local door = prefab("door", { 0, 0, -10 })
	door.name = "Главная дверь"
	door.latin = "MainDoor"
	door.size = { 6, 8, 0.4 }
	door.pos = { 0, 5, -10 }
	door.role.hinge = { -3, 0, 0 }
	local sign = prefab("sign", { 0, 6, -10.65 })
	sign.name = "Вывеска"
	sign.latin = "CorpSign"
	sign.size = { 8, 2, 0.2 }
	sign.label.text = "Корпорация"
	sign.label.size = 30
	sign.label.color = { 235, 225, 200 }
	sign.color = { 40, 44, 56 }
	-- статуя создателя по центру, лицом к входу
	local statueObjs = Prefabs.build(p, "statue", { 0, 1, 6 })
	add(statueObjs)
	statueObjs[2].role.username = ownerName or "Nataliaavira13"
	statueObjs[2].name = "Статуя создателя"
	statueObjs[2].latin = "CreatorStatue"
	local vLamp = prefab("lamp", { 0, 3, -3 })
	vLamp.name = "Лампа вестибюля"
	vLamp.latin = "LobbyLamp"

	-- зал 80 × 60, высота 24, проём из вестибюля шириной 10
	block("Пол зала", { 80, 0.2, 60 }, { 0, 1.1, 50 }, { 70, 78, 96 }, "Carpet")
	block("Потолок зала", { 82, 1, 62 }, { 0, 25.5, 50 }, WALL)
	block("Стена между вестибюлем и залом", { 13, 12, 1 }, { -11.5, 7, 20 })
	block("Стена между вестибюлем и залом", { 13, 12, 1 }, { 11.5, 7, 20 })
	block("Над проёмом в зал", { 10, 3, 1 }, { 0, 11.5, 20 })
	block("Фасад зала", { 36, 12, 1 }, { 0, 19, 20 })
	block("Фасад зала", { 22, 24, 1 }, { -29, 13, 20 })
	block("Фасад зала", { 22, 24, 1 }, { 29, 13, 20 })
	block("Стена зала", { 1, 24, 60 }, { -40.5, 13, 50 })
	block("Стена зала", { 1, 24, 60 }, { 40.5, 13, 50 })
	block("Задняя стена зала", { 82, 24, 1 }, { 0, 13, 80.5 })
	-- столы для каждого
	local n = 0
	for _, z in { 34, 46 } do
		for _, x in { -27, -9, 9, 27 } do
			n += 1
			local d = prefab("desk", { x, 1.1, z })
			d.name = "Стол " .. n
			d.latin = "Desk" .. n
			d.frozen = true
		end
	end
	for i, xz in { { -18, 38 }, { 18, 38 }, { -18, 54 }, { 18, 54 } } do
		local l = prefab("lamp", { xz[1], 14, xz[2] })
		l.name = "Люстра " .. i
		l.latin = "HallLamp" .. i
		l.role.range = 40
	end

	-- второй этаж: галерея с перилами и лестница
	block("Пол второго этажа", { 80, 1, 17 }, { 0, 12.5, 71.5 }, { 120, 84, 60 }, "WoodPlanks")
	for _, x in { -30, -10, 10, 28 } do
		block("Колонна", { 1.2, 11, 1.2 }, { x, 6.5, 63.6 }, { 205, 200, 192 }, "Marble")
	end
	local stairs = prefab("stairs", { 34, 1, 49 })
	stairs.frozen = true
	local rail1 = add(Prefabs.railing(p, 72))
	rail1.pos = { -4, 13, 63.3 }
	rail1.frozen = true
	local rail2 = add(Prefabs.railing(p, 4))
	rail2.pos = { 38, 13, 63.3 }
	rail2.frozen = true

	-- личные комнаты: 6 комнат по 12 × 10, каждому игроку своя
	block("Стена галереи", { 4, 12, 0.5 }, { -38, 19, 70 })
	block("Стена галереи", { 4, 12, 0.5 }, { 38, 19, 70 })
	for i = 0, 6 do
		block("Перегородка", { 0.5, 12, 10 }, { -36 + i * 12, 19, 75 })
	end
	for i = 0, 5 do
		local cx = -30 + 12 * i
		block("Стена комнаты", { 4, 12, 0.5 }, { cx - 4, 19, 70 })
		block("Стена комнаты", { 4, 12, 0.5 }, { cx + 4, 19, 70 })
		block("Над дверью", { 4, 5, 0.5 }, { cx, 22.5, 70 })
		local rd = prefab("door", { 0, 0, 0 })
		rd.name = "Дверь комнаты " .. (i + 1)
		rd.latin = "RoomDoor" .. (i + 1)
		rd.size = { 3.8, 7, 0.3 }
		rd.pos = { cx, 16.5, 70 }
		rd.role.hinge = { -1.9, 0, 0 }
		rd.role.openAngle = -95
		rd.role.owned = true
		local bed = prefab("bed", { cx - 3, 13, 75.5 })
		bed.name = "Кровать " .. (i + 1)
		bed.latin = "Bed" .. (i + 1)
		local rl = prefab("lamp", { cx + 3, 14, 76 })
		rl.name = "Лампа комнаты " .. (i + 1)
		rl.latin = "RoomLamp" .. (i + 1)
		rl.role.brightness = 1.5
		rl.role.range = 14
	end

	p.settings.lighting.clockTime = 20
	p.settings.camera.bob = 0.6

	local tree, errors = Logic.Parser.parse(Corp.SOURCE, Logic.nameResolver(p))
	assert(tree and not errors, "corp logic must parse")
	p.logic.mode = "blocks"
	p.logic.blocks = tree
	p.logic.text.source = Corp.SOURCE
	p.logic.text.refs = Logic.collectRefs(tree)
	return p
end

return Corp
