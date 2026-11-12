--!strict
-- Каталог готовых моделей. Всё собирается из тех же фигур, что и в «Создателе моделей»,
-- поэтому любую готовую модель можно открыть и изменить теми же инструментами

local Format = require(script.Parent.Format)
local Ids = require(script.Parent.Ids)
local Anim = require(script.Parent.Anim)
local Closet = require(script.Parent.Closet)
local MathX = require(script.Parent.MathX)

local Prefabs = {}

local WOOD = { 124, 92, 70 }
local DARK_WOOD = { 86, 66, 54 }
local WALL = { 214, 205, 186 }
local FLOOR = { 105, 64, 40 }
local ORANGE = { 218, 133, 65 }
local WHITE = { 245, 245, 245 }
local BLACK = { 17, 17, 17 }
local SKIN = { 234, 184, 146 }

local function looseP(project, name, shape, size, pos, color, material)
	local p = Format.newPart(Ids.alloc(project, "o"), shape)
	p.name = name
	p.size = size
	p.pos = pos
	p.color = color
	p.material = material or "SmoothPlastic"
	return p
end

local function addPart(m, name, shape, size, pos, color, material, parent, pivot, rot)
	local pid = "p" .. tostring(m.model.nextPart)
	m.model.nextPart += 1
	m.model.parts[pid] = {
		id = pid,
		name = name,
		shape = shape,
		size = size,
		pos = pos,
		rot = rot or { 0, 0, 0 },
		color = color,
		material = material or "SmoothPlastic",
		texture = nil,
		transparency = 0,
		pivot = pivot or { 0, 0, 0 },
		parent = parent,
	}
	return pid
end

local function newModel(project, name, latinBase)
	local m = Format.newModel(Ids.alloc(project, "o"))
	m.name = name
	m.latin = Ids.suggestLatin(project, latinBase)
	return m
end

local function offsetAll(objs, origin)
	for _, o in objs do
		o.pos = MathX.add(o.pos, origin)
	end
	return objs
end

local function latin(project, objs, base)
	for _, o in objs do
		if not o.latin then
			o.latin = Ids.suggestLatin(project, base)
			-- имя должно быть занято сразу, иначе соседние детали получат одинаковые
			project.map.objects[o.id] = o
		end
	end
	for _, o in objs do
		project.map.objects[o.id] = nil
	end
end

-- Комната: пол, потолок и четыре стены; в передней стене проём под дверь
function Prefabs.room(project, w: number?, d: number?, h: number?)
	w, d, h = w or 20, d or 20, h or 10
	local W, D, H = w :: number, d :: number, h :: number
	local gap, gapH = 5, 8
	local side = (W - gap) / 2
	local objs = {
		looseP(project, "Пол", "Block", { W, 1, D }, { 0, 0.5, 0 }, FLOOR, "WoodPlanks"),
		looseP(project, "Потолок", "Block", { W, 1, D }, { 0, H + 1.5, 0 }, WALL, "SmoothPlastic"),
		looseP(project, "Стена сзади", "Block", { W, H, 1 }, { 0, H / 2 + 1, D / 2 - 0.5 }, WALL, "Concrete"),
		looseP(project, "Стена слева", "Block", { 1, H, D - 2 }, { -W / 2 + 0.5, H / 2 + 1, 0 }, WALL, "Concrete"),
		looseP(project, "Стена справа", "Block", { 1, H, D - 2 }, { W / 2 - 0.5, H / 2 + 1, 0 }, WALL, "Concrete"),
		looseP(project, "Стена у двери", "Block", { side, H, 1 }, { -(gap + side) / 2, H / 2 + 1, -D / 2 + 0.5 }, WALL, "Concrete"),
		looseP(project, "Стена у двери", "Block", { side, H, 1 }, { (gap + side) / 2, H / 2 + 1, -D / 2 + 0.5 }, WALL, "Concrete"),
		looseP(project, "Над проёмом", "Block", { gap, H - gapH, 1 }, { 0, gapH + (H - gapH) / 2 + 1, -D / 2 + 0.5 }, WALL, "Concrete"),
	}
	latin(project, objs, "Wall")
	return objs
end

function Prefabs.corridor(project)
	local objs = {
		looseP(project, "Пол коридора", "Block", { 8, 1, 24 }, { 0, 0.5, 0 }, FLOOR, "WoodPlanks"),
		looseP(project, "Потолок коридора", "Block", { 8, 1, 24 }, { 0, 11.5, 0 }, WALL),
		looseP(project, "Стена коридора", "Block", { 1, 10, 24 }, { -4.5, 6, 0 }, WALL, "Concrete"),
		looseP(project, "Стена коридора", "Block", { 1, 10, 24 }, { 4.5, 6, 0 }, WALL, "Concrete"),
	}
	latin(project, objs, "Corridor")
	return objs
end

function Prefabs.floorAbove(project)
	local objs = Prefabs.room(project, 20, 20, 10)
	for _, o in objs do
		o.pos = MathX.add(o.pos, { 0, 12, 0 })
	end
	return objs
end

function Prefabs.wall(project)
	local p = looseP(project, "Стена", "Block", { 12, 10, 1 }, { 0, 5, 0 }, WALL, "Concrete")
	p.latin = Ids.suggestLatin(project, "Wall")
	return { p }
end

function Prefabs.stairs(project)
	local m = newModel(project, "Лестница", "Stairs")
	for i = 1, 10 do
		addPart(m, "Ступень " .. i, "Block", { 4, 1.2, 1.4 }, { 0, (i - 1) * 1.2 + 0.6, (i - 1) * 1.4 }, DARK_WOOD, "Wood")
	end
	return { m }
end

function Prefabs.door(project)
	local p = looseP(project, "Дверь", "Block", { 4.8, 7.8, 0.4 }, { 0, 4.9, 0 }, DARK_WOOD, "Wood")
	p.latin = Ids.suggestLatin(project, "Door")
	p.role = { type = "door", open = false, openAngle = 95, openTime = 0.6, hinge = { -2.4, 0, 0 }, locked = false }
	return { p }
end

function Prefabs.lamp(project)
	local p = looseP(project, "Лампа", "Ball", { 1.2, 1.2, 1.2 }, { 0, 9, 0 }, { 255, 230, 180 }, "Neon")
	p.latin = Ids.suggestLatin(project, "Lamp")
	p.physics.canCollide = false
	p.role = { type = "light", on = true, brightness = 3, range = 24, color = { 255, 214, 170 } }
	return { p }
end

function Prefabs.closet(project)
	local m = newModel(project, "Шкаф", "Closet")
	addPart(m, "Задняя стенка", "Block", { 4, 7, 0.3 }, { 0, 3.5, 1.35 }, DARK_WOOD, "Wood")
	addPart(m, "Бок", "Block", { 0.3, 7, 3 }, { -1.85, 3.5, 0 }, DARK_WOOD, "Wood")
	addPart(m, "Бок", "Block", { 0.3, 7, 3 }, { 1.85, 3.5, 0 }, DARK_WOOD, "Wood")
	addPart(m, "Крыша", "Block", { 4, 0.3, 3 }, { 0, 7.15, 0 }, DARK_WOOD, "Wood")
	addPart(m, "Дно", "Block", { 4, 0.3, 3 }, { 0, 0.15, 0 }, DARK_WOOD, "Wood")
	local dl = addPart(m, "Дверца", "Block", { 1.75, 6.6, 0.2 }, { -0.9, 3.6, -1.4 }, WOOD, "Wood", nil, { -0.875, 0, 0 })
	local dr = addPart(m, "Дверца", "Block", { 1.75, 6.6, 0.2 }, { 0.9, 3.6, -1.4 }, WOOD, "Wood", nil, { 0.875, 0, 0 })
	m.model.parts[dl].transparency = 0.35
	m.model.parts[dr].transparency = 0.35
	m.role = Closet.newRole(3)
	-- клип модели: дверцы приоткрываются, его можно запускать из логики
	local open = Format.newClip(Ids.alloc(project, "c"), "Дверцы")
	open.length = 0.5
	Anim.setKey(open, dl, 0, { 0, 0, 0 }, { 0, 0, 0 })
	Anim.setKey(open, dl, 0.25, { 0, 0, 0 }, { 0, 70, 0 })
	Anim.setKey(open, dl, 0.5, { 0, 0, 0 }, { 0, 0, 0 })
	Anim.setKey(open, dr, 0, { 0, 0, 0 }, { 0, 0, 0 })
	Anim.setKey(open, dr, 0.25, { 0, 0, 0 }, { 0, -70, 0 })
	Anim.setKey(open, dr, 0.5, { 0, 0, 0 }, { 0, 0, 0 })
	m.model.clips[open.id] = open
	return { m }
end

function Prefabs.bookshelf(project)
	local m = newModel(project, "Книжный шкаф", "Bookshelf")
	addPart(m, "Каркас", "Block", { 6, 8, 0.3 }, { 0, 4, 0.85 }, DARK_WOOD, "Wood")
	addPart(m, "Бок", "Block", { 0.3, 8, 2 }, { -2.85, 4, 0 }, DARK_WOOD, "Wood")
	addPart(m, "Бок", "Block", { 0.3, 8, 2 }, { 2.85, 4, 0 }, DARK_WOOD, "Wood")
	local colors = { { 196, 40, 28 }, { 13, 105, 172 }, { 75, 151, 75 }, { 245, 205, 48 }, { 107, 50, 124 } }
	for shelf = 0, 3 do
		addPart(m, "Полка", "Block", { 5.4, 0.25, 1.8 }, { 0, 0.15 + shelf * 2.4, 0 }, WOOD, "Wood")
		if shelf < 3 then
			for b = 0, 6 do
				local h = 1.2 + (b % 3) * 0.25
				addPart(m, "Книга", "Block", { 0.55, h, 1.3 }, { -2.2 + b * 0.72, 0.3 + shelf * 2.4 + h / 2, 0.1 }, colors[(b + shelf) % 5 + 1])
			end
		end
	end
	return { m }
end

function Prefabs.table(project)
	local m = newModel(project, "Стол", "Table")
	addPart(m, "Столешница", "Block", { 6, 0.4, 3.5 }, { 0, 3.2, 0 }, WOOD, "Wood")
	for _, xz in { { -2.7, -1.5 }, { 2.7, -1.5 }, { -2.7, 1.5 }, { 2.7, 1.5 } } do
		addPart(m, "Ножка", "Block", { 0.4, 3, 0.4 }, { xz[1], 1.5, xz[2] }, DARK_WOOD, "Wood")
	end
	return { m }
end

function Prefabs.chair(project)
	local m = newModel(project, "Стул", "Chair")
	addPart(m, "Сиденье", "Block", { 2, 0.3, 2 }, { 0, 2, 0 }, WOOD, "Wood")
	addPart(m, "Спинка", "Block", { 2, 2.4, 0.3 }, { 0, 3.3, 0.85 }, WOOD, "Wood")
	for _, xz in { { -0.8, -0.8 }, { 0.8, -0.8 }, { -0.8, 0.8 }, { 0.8, 0.8 } } do
		addPart(m, "Ножка", "Block", { 0.3, 2, 0.3 }, { xz[1], 1, xz[2] }, DARK_WOOD, "Wood")
	end
	return { m }
end

function Prefabs.bed(project)
	local m = newModel(project, "Кровать", "Bed")
	addPart(m, "Рама", "Block", { 5, 1, 8 }, { 0, 1, 0 }, DARK_WOOD, "Wood")
	addPart(m, "Матрас", "Block", { 4.6, 0.8, 7.6 }, { 0, 1.9, 0 }, WHITE, "Fabric")
	addPart(m, "Подушка", "Block", { 3, 0.5, 1.4 }, { 0, 2.5, 3 }, { 175, 221, 255 }, "Fabric")
	addPart(m, "Изголовье", "Block", { 5, 3, 0.4 }, { 0, 2.5, 4.1 }, DARK_WOOD, "Wood")
	return { m }
end

function Prefabs.sign(project)
	local p = looseP(project, "Табличка", "Block", { 4, 2, 0.2 }, { 0, 5, 0 }, WOOD, "Wood")
	p.latin = Ids.suggestLatin(project, "Sign")
	p.label = { text = "Надпись", mode = "surface", face = "Front", size = 24, wrap = true, color = BLACK, visible = true }
	return { p }
end

function Prefabs.spawn(project)
	local p = looseP(project, "Старт игрока", "Block", { 4, 0.4, 4 }, { 0, 1.2, 0 }, { 75, 151, 75 }, "Neon")
	p.latin = Ids.suggestLatin(project, "Spawn")
	p.transparency = 0.5
	p.physics.canCollide = false
	p.role = { type = "spawn" }
	return { p }
end

function Prefabs.zone(project)
	local p = looseP(project, "Зона", "Block", { 10, 8, 10 }, { 0, 5, 0 }, { 13, 105, 172 }, "Neon")
	p.latin = Ids.suggestLatin(project, "Zone")
	p.transparency = 0.8
	p.physics.canCollide = false
	p.role = { type = "zone" }
	return { p }
end

function Prefabs.waypoint(project)
	local p = looseP(project, "Точка", "Ball", { 1.2, 1.2, 1.2 }, { 0, 1.6, 0 }, { 75, 200, 75 }, "Neon")
	p.latin = Ids.suggestLatin(project, "Point")
	p.transparency = 0.3
	p.physics.canCollide = false
	p.role = { type = "waypoint" }
	return { p }
end

-- Человекоподобные NPC: «Новый» (сегменты рук и ног) и «Ретро» (цельные блоки)
local function humanoidClips(project, m, parts)
	local wave = Format.newClip(Ids.alloc(project, "c"), "Приветствие")
	wave.length = 1.6
	Anim.setKey(wave, parts.rArm, 0, { 0, 0, 0 }, { 0, 0, 0 })
	Anim.setKey(wave, parts.rArm, 0.4, { 0, 0, 0 }, { 0, 0, 160 })
	Anim.setKey(wave, parts.rArm, 0.8, { 0, 0, 0 }, { 0, 0, 130 })
	Anim.setKey(wave, parts.rArm, 1.2, { 0, 0, 0 }, { 0, 0, 160 })
	Anim.setKey(wave, parts.rArm, 1.6, { 0, 0, 0 }, { 0, 0, 0 })
	Anim.setKey(wave, parts.head, 0, { 0, 0, 0 }, { 0, 0, 0 })
	Anim.setKey(wave, parts.head, 0.8, { 0, 0, 0 }, { -10, 0, 8 })
	Anim.setKey(wave, parts.head, 1.6, { 0, 0, 0 }, { 0, 0, 0 })
	m.model.clips[wave.id] = wave

	local walk = Format.newClip(Ids.alloc(project, "c"), "Ходьба")
	walk.length = 1
	walk.loop = true
	for _, t in { 0, 0.5, 1 } do
		local s = if t == 0.5 then -1 else 1
		Anim.setKey(walk, parts.lLeg, t, { 0, 0, 0 }, { 30 * s, 0, 0 })
		Anim.setKey(walk, parts.rLeg, t, { 0, 0, 0 }, { -30 * s, 0, 0 })
		Anim.setKey(walk, parts.lArm, t, { 0, 0, 0 }, { -25 * s, 0, 0 })
		Anim.setKey(walk, parts.rArm, t, { 0, 0, 0 }, { 25 * s, 0, 0 })
	end
	m.model.clips[walk.id] = walk
end

function Prefabs.npcNew(project)
	local m = newModel(project, "NPC", "Npc")
	m.model.body = "new"
	local shirt, pants = { 13, 105, 172 }, { 27, 42, 53 }
	local lower = addPart(m, "Низ туловища", "Block", { 2, 0.8, 1 }, { 0, 2.6, 0 }, pants)
	local upper = addPart(m, "Верх туловища", "Block", { 2, 1.6, 1 }, { 0, 3.8, 0 }, shirt, nil, lower, { 0, -0.8, 0 })
	local head = addPart(m, "Голова", "Block", { 1.2, 1.2, 1.2 }, { 0, 5.2, 0 }, SKIN, nil, upper, { 0, -0.6, 0 })
	local lua = addPart(m, "Левое плечо", "Block", { 0.9, 1.2, 0.9 }, { -1.45, 4, 0 }, shirt, nil, upper, { 0, 0.5, 0 })
	addPart(m, "Левое предплечье", "Block", { 0.85, 1.2, 0.85 }, { -1.45, 2.8, 0 }, SKIN, nil, lua, { 0, 0.6, 0 })
	local rua = addPart(m, "Правое плечо", "Block", { 0.9, 1.2, 0.9 }, { 1.45, 4, 0 }, shirt, nil, upper, { 0, 0.5, 0 })
	addPart(m, "Правое предплечье", "Block", { 0.85, 1.2, 0.85 }, { 1.45, 2.8, 0 }, SKIN, nil, rua, { 0, 0.6, 0 })
	local lul = addPart(m, "Левое бедро", "Block", { 0.95, 1.1, 0.95 }, { -0.5, 1.65, 0 }, pants, nil, lower, { 0, 0.55, 0 })
	addPart(m, "Левая голень", "Block", { 0.9, 1.1, 0.9 }, { -0.5, 0.55, 0 }, pants, nil, lul, { 0, 0.55, 0 })
	local rul = addPart(m, "Правое бедро", "Block", { 0.95, 1.1, 0.95 }, { 0.5, 1.65, 0 }, pants, nil, lower, { 0, 0.55, 0 })
	addPart(m, "Правая голень", "Block", { 0.9, 1.1, 0.9 }, { 0.5, 0.55, 0 }, pants, nil, rul, { 0, 0.55, 0 })
	addPart(m, "Глаз", "Ball", { 0.2, 0.2, 0.2 }, { -0.25, 5.35, -0.6 }, BLACK, nil, head)
	addPart(m, "Глаз", "Ball", { 0.2, 0.2, 0.2 }, { 0.25, 5.35, -0.6 }, BLACK, nil, head)
	humanoidClips(project, m, { head = head, lArm = lua, rArm = rua, lLeg = lul, rLeg = rul })
	m.role = Prefabs.npcRole()
	return { m }
end

function Prefabs.npcRetro(project)
	local m = newModel(project, "NPC", "Npc")
	m.model.body = "retro"
	local torso = addPart(m, "Туловище", "Block", { 2, 2, 1 }, { 0, 3, 0 }, { 13, 105, 172 })
	local head = addPart(m, "Голова", "Block", { 1.2, 1.2, 1.2 }, { 0, 4.6, 0 }, { 245, 205, 48 }, nil, torso, { 0, -0.6, 0 })
	local la = addPart(m, "Левая рука", "Block", { 1, 2, 1 }, { -1.5, 3, 0 }, { 245, 205, 48 }, nil, torso, { 0, 0.8, 0 })
	local ra = addPart(m, "Правая рука", "Block", { 1, 2, 1 }, { 1.5, 3, 0 }, { 245, 205, 48 }, nil, torso, { 0, 0.8, 0 })
	local ll = addPart(m, "Левая нога", "Block", { 1, 2, 1 }, { -0.5, 1, 0 }, { 75, 151, 75 }, nil, torso, { 0, 0.9, 0 })
	local rl = addPart(m, "Правая нога", "Block", { 1, 2, 1 }, { 0.5, 1, 0 }, { 75, 151, 75 }, nil, torso, { 0, 0.9, 0 })
	addPart(m, "Глаз", "Ball", { 0.2, 0.2, 0.2 }, { -0.25, 4.75, -0.6 }, BLACK, nil, head)
	addPart(m, "Глаз", "Ball", { 0.2, 0.2, 0.2 }, { 0.25, 4.75, -0.6 }, BLACK, nil, head)
	humanoidClips(project, m, { head = head, lArm = la, rArm = ra, lLeg = ll, rLeg = rl })
	m.role = Prefabs.npcRole()
	return { m }
end

function Prefabs.npcRole()
	return {
		type = "npc",
		trigger = "interact",
		zone = nil,
		greetingClip = "Приветствие",
		lines = {
			{ text = "Привет! Добро пожаловать в мой дом.", delay = 0, duration = 3 },
		},
		anchor = nil,
		textSize = 22,
	}
end

-- Лисик: тело, голова с ушами, лапы и хвост из двух частей
function Prefabs.fox(project)
	local m = newModel(project, "Лисик", "Fox")
	local body = addPart(m, "Тело", "Block", { 2, 1.6, 3.2 }, { 0, 2, 0 }, ORANGE, "Fabric")
	local head = addPart(m, "Голова", "Block", { 1.6, 1.4, 1.4 }, { 0, 2.9, -2 }, ORANGE, "Fabric", body, { 0, -0.4, 0.6 })
	addPart(m, "Мордочка", "Block", { 0.8, 0.6, 0.8 }, { 0, 2.6, -3 }, WHITE, "Fabric", head)
	addPart(m, "Нос", "Ball", { 0.3, 0.3, 0.3 }, { 0, 2.75, -3.42 }, BLACK, nil, head)
	addPart(m, "Глаз", "Ball", { 0.25, 0.25, 0.25 }, { -0.4, 3.1, -2.71 }, BLACK, nil, head)
	addPart(m, "Глаз", "Ball", { 0.25, 0.25, 0.25 }, { 0.4, 3.1, -2.71 }, BLACK, nil, head)
	local earL = addPart(m, "Левое ухо", "Wedge", { 0.45, 0.8, 0.5 }, { -0.5, 4, -1.9 }, ORANGE, "Fabric", head, { 0, -0.4, 0 })
	local earR = addPart(m, "Правое ухо", "Wedge", { 0.45, 0.8, 0.5 }, { 0.5, 4, -1.9 }, ORANGE, "Fabric", head, { 0, -0.4, 0 })
	local legs = {}
	for i, xz in { { -0.6, -1.2 }, { 0.6, -1.2 }, { -0.6, 1.2 }, { 0.6, 1.2 } } do
		local names = { "Передняя левая лапа", "Передняя правая лапа", "Задняя левая лапа", "Задняя правая лапа" }
		legs[i] = addPart(m, names[i], "Block", { 0.5, 1.4, 0.5 }, { xz[1], 0.7, xz[2] }, DARK_WOOD, "Fabric", body, { 0, 0.7, 0 })
	end
	local tail1 = addPart(m, "Хвост", "Block", { 0.7, 0.7, 1.4 }, { 0, 2.3, 2.3 }, ORANGE, "Fabric", body, { 0, 0, -0.7 })
	local tail2 = addPart(m, "Кончик хвоста", "Block", { 0.55, 0.55, 0.9 }, { 0, 2.3, 3.4 }, WHITE, "Fabric", tail1, { 0, 0, -0.45 })

	local function clip(name: string, length: number, loop: boolean)
		local c = Format.newClip(Ids.alloc(project, "c"), name)
		c.length = length
		c.loop = loop
		m.model.clips[c.id] = c
		return c
	end
	local Z = { 0, 0, 0 }

	local function gait(c, swing: number, bob: number)
		local half = c.length / 2
		for _, t in { 0, half, c.length } do
			local s = if t == half then -1 else 1
			Anim.setKey(c, legs[1], t, Z, { swing * s, 0, 0 })
			Anim.setKey(c, legs[4], t, Z, { swing * s, 0, 0 })
			Anim.setKey(c, legs[2], t, Z, { -swing * s, 0, 0 })
			Anim.setKey(c, legs[3], t, Z, { -swing * s, 0, 0 })
			Anim.setKey(c, tail1, t, Z, { 10, 12 * s, 0 })
			Anim.setKey(c, body, t, { 0, if t == half then bob else 0, 0 }, Z)
		end
	end
	gait(clip("Ходьба", 0.8, true), 25, 0.08)
	gait(clip("Бег", 0.45, true), 45, 0.25)

	local appear = clip("Появление", 1.4, false)
	Anim.setKey(appear, body, 0, { 0, -1.2, 1.5 }, { -15, 0, 0 })
	Anim.setKey(appear, body, 0.7, { 0, 0, 0 }, Z)
	Anim.setKey(appear, head, 0, Z, Z)
	Anim.setKey(appear, head, 0.8, Z, { 0, 35, 0 })
	Anim.setKey(appear, head, 1.4, Z, { 0, -15, 0 })
	Anim.setKey(appear, earL, 0, Z, { 40, 0, 0 })
	Anim.setKey(appear, earR, 0, Z, { 40, 0, 0 })
	Anim.setKey(appear, earL, 0.9, Z, Z)
	Anim.setKey(appear, earR, 1.1, Z, Z)
	Anim.addMarker(appear, Ids.alloc(project, "k"), 0.7, "Шорох")

	local jump = clip("Прыжок", 0.7, false)
	Anim.setKey(jump, body, 0, Z, Z)
	Anim.setKey(jump, body, 0.35, { 0, 1.6, 0 }, { -10, 0, 0 })
	Anim.setKey(jump, body, 0.7, Z, Z)
	for _, leg in legs do
		Anim.setKey(jump, leg, 0, Z, Z)
		Anim.setKey(jump, leg, 0.35, Z, { -40, 0, 0 })
		Anim.setKey(jump, leg, 0.7, Z, Z)
	end

	local attack = clip("Атака", 0.6, false)
	Anim.setKey(attack, head, 0, Z, Z)
	Anim.setKey(attack, head, 0.25, { 0, 0, -0.9 }, { 15, 0, 0 })
	Anim.setKey(attack, head, 0.6, Z, Z)
	Anim.addMarker(attack, Ids.alloc(project, "k"), 0.25, "Удар")

	local scream = clip("Скример", 1.5, false)
	Anim.setKey(scream, head, 0, Z, Z)
	Anim.setKey(scream, head, 0.3, { 0, 0.3, -1.2 }, { -30, 0, 0 })
	Anim.setKey(scream, head, 1.1, { 0, 0.3, -1.2 }, { -25, 0, 6 })
	Anim.setKey(scream, head, 1.5, Z, Z)
	Anim.setKey(scream, earL, 0, Z, Z)
	Anim.setKey(scream, earL, 0.3, Z, { -50, 0, -20 })
	Anim.setKey(scream, earL, 1.5, Z, Z)
	Anim.setKey(scream, earR, 0, Z, Z)
	Anim.setKey(scream, earR, 0.3, Z, { -50, 0, 20 })
	Anim.setKey(scream, earR, 1.5, Z, Z)
	Anim.setKey(scream, tail2, 0, Z, Z)
	Anim.setKey(scream, tail2, 0.3, Z, { -40, 0, 0 })
	Anim.setKey(scream, tail2, 1.5, Z, Z)
	Anim.addMarker(scream, Ids.alloc(project, "k"), 0.5, "Погасить")

	m.role = { type = "creature", speed = 14, idleClip = nil }
	return { m }
end

local BUILDERS = {
	room = Prefabs.room,
	corridor = Prefabs.corridor,
	floorAbove = Prefabs.floorAbove,
	wall = Prefabs.wall,
	stairs = Prefabs.stairs,
	door = Prefabs.door,
	lamp = Prefabs.lamp,
	closet = Prefabs.closet,
	bookshelf = Prefabs.bookshelf,
	table = Prefabs.table,
	chair = Prefabs.chair,
	bed = Prefabs.bed,
	sign = Prefabs.sign,
	spawn = Prefabs.spawn,
	zone = Prefabs.zone,
	waypoint = Prefabs.waypoint,
	npcNew = Prefabs.npcNew,
	npcRetro = Prefabs.npcRetro,
	fox = Prefabs.fox,
}

-- Строит объекты готовой модели в точке origin. Объекты ещё не добавлены в проект
function Prefabs.build(project, prefabId: string, origin)
	local b = BUILDERS[prefabId]
	if not b then
		return nil
	end
	return offsetAll(b(project), origin or { 0, 0, 0 })
end

function Prefabs.shape(project, shape: string, origin)
	local p = Format.newPart(Ids.alloc(project, "o"), shape)
	p.name = "Деталь"
	p.pos = MathX.add({ 0, 2, 0 }, origin or { 0, 0, 0 })
	p.latin = Ids.suggestLatin(project, "Part")
	return p
end

return Prefabs
