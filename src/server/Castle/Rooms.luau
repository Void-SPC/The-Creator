--!nonstrict
-- Обстановка комнат по их назначению. Мебель ставится в «слоты» вдоль стен: по два на
-- каждый 32-studs участок стены, в стороне от середины, где двери и окна. Центр комнаты
-- свободен для ковра и стола, поэтому предметы не налезают друг на друга и на проходы

local Props = require(script.Parent.Props)

local Rooms = {}

local rgb = Props.rgb
local P, C = Props.P, Props.C

-- Стили: обои, пол, низ стены. Пол везде каменный, дерево только в отделке
Rooms.STYLE = {
	hall = { paper = rgb(92, 40, 42), floor = rgb(150, 140, 126), mat = Enum.Material.Marble, rug = rgb(120, 22, 30) },
	grand_hall = { paper = rgb(110, 96, 74), floor = rgb(196, 188, 176), mat = Enum.Material.Marble, rug = rgb(120, 22, 30) },
	throne = { paper = rgb(120, 30, 36), floor = rgb(206, 198, 186), mat = Enum.Material.Marble, rug = rgb(140, 20, 28) },
	bedroom = { paper = rgb(52, 74, 62), floor = rgb(128, 120, 110), mat = Enum.Material.Slate, rug = rgb(110, 40, 40) },
	guest_suite = { paper = rgb(66, 58, 90), floor = rgb(128, 120, 110), mat = Enum.Material.Slate, rug = rgb(60, 50, 100) },
	study = { paper = rgb(60, 48, 36), floor = rgb(120, 112, 102), mat = Enum.Material.Slate, rug = rgb(90, 30, 30) },
	sitting = { paper = rgb(110, 84, 54), floor = rgb(150, 140, 126), mat = Enum.Material.Marble, rug = rgb(40, 60, 90) },
	lounge = { paper = rgb(70, 34, 50), floor = rgb(150, 140, 126), mat = Enum.Material.Marble, rug = rgb(90, 30, 60) },
	music = { paper = rgb(44, 58, 84), floor = rgb(176, 168, 156), mat = Enum.Material.Marble, rug = rgb(120, 22, 30) },
	reading = { paper = rgb(56, 70, 50), floor = rgb(120, 112, 102), mat = Enum.Material.Slate, rug = rgb(40, 70, 50) },
	trophy = { paper = rgb(80, 30, 30), floor = rgb(110, 104, 98), mat = Enum.Material.Slate, rug = rgb(60, 40, 30) },
	gallery = { paper = rgb(36, 50, 70), floor = rgb(196, 188, 176), mat = Enum.Material.Marble, rug = rgb(120, 22, 30) },
	nursery = { paper = rgb(150, 170, 186), floor = rgb(176, 168, 156), mat = Enum.Material.Marble, rug = rgb(200, 150, 170) },
	wardrobe = { paper = rgb(100, 70, 90), floor = rgb(150, 140, 126), mat = Enum.Material.Marble, rug = rgb(110, 50, 80) },
	bath = { paper = rgb(170, 190, 196), floor = rgb(220, 218, 212), mat = Enum.Material.Marble, rug = rgb(70, 110, 140) },
	kitchen = { paper = rgb(168, 150, 120), floor = rgb(120, 110, 98), mat = Enum.Material.Cobblestone, rug = nil },
	dining = { paper = rgb(100, 28, 32), floor = rgb(150, 140, 126), mat = Enum.Material.Marble, rug = rgb(120, 22, 30) },
	servants = { paper = rgb(140, 128, 108), floor = rgb(110, 104, 98), mat = Enum.Material.Slate, rug = rgb(100, 80, 60) },
	barracks = { paper = rgb(96, 90, 82), floor = rgb(100, 96, 90), mat = Enum.Material.Slate, rug = nil },
	training = { paper = rgb(110, 104, 96), floor = rgb(120, 114, 106), mat = Enum.Material.Slate, rug = nil },
	chapel = { paper = rgb(200, 190, 170), floor = rgb(206, 198, 186), mat = Enum.Material.Marble, rug = rgb(120, 22, 30) },
	chapel_small = { paper = rgb(200, 190, 170), floor = rgb(206, 198, 186), mat = Enum.Material.Marble, rug = rgb(120, 22, 30) },
	shop = { paper = rgb(126, 100, 62), floor = rgb(150, 140, 126), mat = Enum.Material.Marble, rug = rgb(60, 80, 40) },
	casino = { paper = rgb(60, 20, 50), floor = rgb(40, 34, 40), mat = Enum.Material.Marble, rug = rgb(110, 20, 60) },
	stairs = { paper = rgb(92, 40, 42), floor = rgb(150, 140, 126), mat = Enum.Material.Marble, rug = rgb(120, 22, 30) },
	stairs_down = { paper = rgb(80, 74, 66), floor = rgb(120, 114, 106), mat = Enum.Material.Slate, rug = nil },
	landing = { paper = rgb(92, 40, 42), floor = rgb(150, 140, 126), mat = Enum.Material.Marble, rug = rgb(120, 22, 30) },
	observatory = { paper = rgb(30, 34, 60), floor = rgb(120, 112, 102), mat = Enum.Material.Slate, rug = rgb(30, 40, 80) },
	treasury = { paper = rgb(110, 84, 30), floor = rgb(196, 188, 176), mat = Enum.Material.Marble, rug = rgb(120, 22, 30) },
	council = { paper = rgb(40, 46, 66), floor = rgb(150, 140, 126), mat = Enum.Material.Marble, rug = rgb(120, 22, 30) },
	map_room = { paper = rgb(90, 80, 56), floor = rgb(150, 140, 126), mat = Enum.Material.Marble, rug = rgb(60, 50, 30) },
	royal_dining = { paper = rgb(100, 28, 32), floor = rgb(196, 188, 176), mat = Enum.Material.Marble, rug = rgb(120, 22, 30) },
	king = { paper = rgb(110, 22, 30), floor = rgb(206, 198, 186), mat = Enum.Material.Marble, rug = rgb(150, 20, 28) },
	queen = { paper = rgb(84, 46, 100), floor = rgb(206, 198, 186), mat = Enum.Material.Marble, rug = rgb(110, 50, 130) },
	storeroom = { paper = rgb(90, 86, 80), floor = rgb(96, 92, 88), mat = Enum.Material.Cobblestone, rug = nil },
	guardroom = { paper = rgb(90, 86, 80), floor = rgb(96, 92, 88), mat = Enum.Material.Cobblestone, rug = nil },
	prison_guard = { paper = rgb(90, 86, 80), floor = rgb(96, 92, 88), mat = Enum.Material.Cobblestone, rug = nil },
	cellar = { paper = rgb(84, 70, 60), floor = rgb(96, 88, 80), mat = Enum.Material.Cobblestone, rug = nil },
	storage = { paper = rgb(90, 86, 80), floor = rgb(96, 92, 88), mat = Enum.Material.Cobblestone, rug = nil },
}
Rooms.STYLE.default = Rooms.STYLE.hall

function Rooms.style(kind: string)
	return Rooms.STYLE[kind] or Rooms.STYLE.default
end

-- Слоты у стен: два на каждый участок, на расстоянии 9.5 от середины участка
local function slots(room)
	local list = {}
	for si, seg in room.segs do
		for _, off in { -9, 9 } do
			local p = seg.pos + seg.tangent * off
			table.insert(list, { cf = CFrame.lookAt(p, p + seg.inward), seg = seg, used = false, room = room, index = si * 2 + (if off > 0 then 1 else 0) })
		end
	end
	-- порядок перемешан, но одинаковый при каждом запуске
	table.sort(list, function(a, b)
		return (a.index * 7919) % 101 < (b.index * 7919) % 101
	end)
	return list
end

-- Участки стен без дверей и окон (для каминов, алтарей, больших картин)
local function solidWalls(room)
	local list = {}
	for _, seg in room.segs do
		if not seg.opening then
			table.insert(list, seg)
		end
	end
	return list
end

-- прямоугольник на полу (XZ), занятый предметом шириной w и глубиной d, центр cf
local function rectOf(cf: CFrame, w: number, d: number)
	local lv, rv = cf.LookVector, cf.RightVector
	local ex = math.abs(rv.X) * w / 2 + math.abs(lv.X) * d / 2
	local ez = math.abs(rv.Z) * w / 2 + math.abs(lv.Z) * d / 2
	return { cf.X - ex, cf.Z - ez, cf.X + ex, cf.Z + ez }
end

local function hits(occ, r)
	for _, o in occ do
		if r[1] + 0.15 < o[3] and o[1] + 0.15 < r[3] and r[2] + 0.15 < o[4] and o[2] + 0.15 < r[4] then
			return true
		end
	end
	return false
end

-- занять место в центре комнаты (столы, диваны), чтобы мебель у стен туда не заходила
local function occupy(room, cf: CFrame, w: number, d: number)
	room.occ = room.occ or {}
	table.insert(room.occ, rectOf(cf, w, d))
end

-- первый свободный слот, куда помещается предмет w × d (спиной к стене)
local function take(list, w: number?, d: number?)
	local ww, dd = w or 6, d or 3
	for _, s in list do
		if not s.used then
			local room = s.room
			room.occ = room.occ or {}
			local r = rectOf(s.cf * CFrame.new(0, 0, -(dd / 2 + 0.35)), ww, dd)
			if not hits(room.occ, r) then
				s.used = true
				table.insert(room.occ, r)
				return s
			end
		end
	end
	return nil
end

-- поставить предмет глубиной d в слот (спиной к стене)
local function at(slot, depth: number, extra: CFrame?)
	return slot.cf * CFrame.new(0, 0, -(depth / 2 + 0.35)) * (extra or CFrame.new())
end

local function onWall(slot, y: number)
	return slot.cf * CFrame.new(0, y, -0.3)
end

local function center(room): CFrame
	return CFrame.new((room.x0 + room.x1) / 2, room.y, (room.z0 + room.z1) / 2)
end

local function size(room)
	return room.x1 - room.x0, room.z1 - room.z0
end

-- картина над низкой мебелью
local function paintingAbove(parent, slot, seed)
	Props.painting(parent, onWall(slot, 8.5), 5, 4, seed)
end

-- свет комнаты: люстра или лампа в центре каждой клетки (не больше четырёх)
local function lights(parent, room, chandelier: boolean?)
	local n = 0
	for _, c in room.cells do
		n += 1
		if n > 4 then
			break
		end
		local pos = Vector3.new(c.x, room.y + room.h - 4, c.z)
		if chandelier then
			Props.chandelier(parent, pos, 3, 3)
		else
			Props.ceilingLamp(parent, pos + Vector3.new(0, 0.5, 0), 3)
		end
	end
end

-- бра на двух участках стены по сторонам от проёма
local function sconces(parent, room, count: number)
	local n = 0
	for _, seg in room.segs do
		if n >= count then
			break
		end
		for _, off in { -6.8, 6.8 } do
			local p = seg.pos + seg.tangent * off + Vector3.new(0, 8, 0)
			Props.sconce(parent, CFrame.lookAt(p, p + seg.inward), n < 2)
			n += 1
		end
	end
end

local function rugCenter(parent, room, st, w, d)
	if st.rug then
		local rw, rd = size(room)
		Props.rug(parent, center(room), math.min(w or rw - 12, rw - 12), math.min(d or rd - 12, rd - 12), st.rug)
	end
end

-- ---------------------------------------------------------------------------

local D = {}

D.bedroom = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	local s = slots(room)
	rugCenter(parent, room, st, 14, 10)
	local slot = take(s, 5.8, 9)
	if slot then
		local _, blanket = Props.bed(parent, at(slot, 8.5), Color3.fromHSV((room.id * 0.13) % 1, 0.45, 0.5))
		ctx.prompt(blanket, "rest", 1.5)
	end
	slot = take(s, 5.2, 2.8)
	if slot then
		Props.wardrobe(parent, at(slot, 2.4))
	end
	slot = take(s, 5.6, 2.2)
	if slot then
		Props.dresser(parent, at(slot, 1.8), 5, room.id)
		paintingAbove(parent, slot, room.id)
	end
	slot = take(s, 5.4, 5.6)
	if slot then
		Props.desk(parent, at(slot, 2.6))
	end
	slot = take(s, 9, 3)
	if slot then
		Props.armchair(parent, at(slot, 2.8), rgb(110, 40, 40))
		Props.nightstand(parent, at(slot, 1.6, CFrame.new(3.2, 0, 0)))
	end
	slot = take(s, 2.2, 2.2)
	if slot then
		Props.plant(parent, at(slot, 1.8))
		paintingAbove(parent, slot, room.id + 3)
	end
	local walls = solidWalls(room)
	if walls[1] then
		local p = walls[1].pos
		Props.fireplace(parent, CFrame.lookAt(p, p + walls[1].inward) * CFrame.new(0, 0, -1.7), room.h)
	end
	lights(parent, room)
	sconces(parent, room, 2)
end
D.guest_suite = function(parent, room, ctx)
	local c = center(room)
	occupy(room, c * CFrame.new(0, 0, 2), 9, 7)
	Props.sofa(parent, c * CFrame.new(0, 0, 4), rgb(70, 60, 110))
	Props.coffeeTable(parent, c)
	D.bedroom(parent, room, ctx)
end

D.study = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	local s = slots(room)
	rugCenter(parent, room, st, 12, 10)
	occupy(room, center(room) * CFrame.new(0, 0, 0), 6, 6)
	Props.desk(parent, center(room) * CFrame.new(0, 0, 1))
	for k = 1, 3 do
		local slot = take(s, 6.8, 2.4)
		if slot then
			Props.bookshelf(parent, at(slot, 2), 6, 12, room.id * 10 + k)
		end
	end
	local slot = take(s, 2.6, 2)
	if slot then
		Props.grandfatherClock(parent, at(slot, 1.6))
	end
	slot = take(s, 2.8, 2.8)
	if slot then
		Props.globe(parent, at(slot, 2.4))
		paintingAbove(parent, slot, room.id)
	end
	slot = take(s, 3.4, 3)
	if slot then
		Props.armchair(parent, at(slot, 2.8), rgb(60, 40, 30))
	end
	slot = take(s, 2.2, 2.2)
	if slot then
		Props.plant(parent, at(slot, 1.8))
	end
	local book = P(parent, "BookProp", Vector3.new(1.2, 0.3, 0.9), center(room) * CFrame.new(1.2, 3.52, 1.2), rgb(110, 30, 30), Enum.Material.Fabric)
	ctx.prompt(book, "book")
	lights(parent, room)
	sconces(parent, room, 2)
end
D.map_room = function(parent, room, ctx)
	occupy(room, center(room), 9, 6)
	Props.mapTable(parent, center(room))
	local s = slots(room)
	for k = 1, 3 do
		local slot = take(s, 6.8, 2.4)
		if slot then
			Props.bookshelf(parent, at(slot, 2), 6, 12, room.id * 10 + k)
		end
	end
	local slot = take(s, 2.8, 2.8)
	if slot then
		Props.globe(parent, at(slot, 2.4))
	end
	slot = take(s, 5.6, 2.2)
	if slot then
		Props.dresser(parent, at(slot, 1.8), 5, room.id)
		paintingAbove(parent, slot, room.id)
	end
	lights(parent, room, true)
	sconces(parent, room, 2)
	local _ = ctx
end
D.observatory = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st, 12, 12)
	occupy(room, center(room) * CFrame.new(0, 0, 3), 4, 4)
	Props.telescope(parent, center(room) * CFrame.new(0, 0, 3))
	local s = slots(room)
	local slot = take(s, 5.4, 5.6)
	if slot then
		Props.desk(parent, at(slot, 2.6))
	end
	slot = take(s, 2.8, 2.8)
	if slot then
		Props.globe(parent, at(slot, 2.4))
		paintingAbove(parent, slot, 2)
	end
	for k = 1, 2 do
		slot = take(s, 6.8, 2.4)
		if slot then
			Props.bookshelf(parent, at(slot, 2), 6, 12, room.id + k)
		end
	end
	lights(parent, room)
	sconces(parent, room, 2)
	local _ = ctx
end

local function sittingArea(parent, room, color)
	local c = center(room)
	occupy(room, c * CFrame.new(0, 0, 2), 14, 11)
	Props.sofa(parent, c * CFrame.new(0, 0, 4.5), color)
	Props.coffeeTable(parent, c * CFrame.new(0, 0, 0.5))
	Props.armchair(parent, c * CFrame.new(-5, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), color)
	Props.armchair(parent, c * CFrame.new(5, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), color)
end

D.sitting = function(parent, room, ctx, withArmor)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st, 16, 14)
	sittingArea(parent, room, rgb(120, 90, 50))
	local s = slots(room)
	local walls = solidWalls(room)
	if walls[1] then
		local p = walls[1].pos
		Props.fireplace(parent, CFrame.lookAt(p, p + walls[1].inward) * CFrame.new(0, 0, -1.7), room.h)
	end
	local slot = take(s, 2.6, 2)
	if slot then
		Props.grandfatherClock(parent, at(slot, 1.6))
	end
	slot = take(s, 5.6, 2.2)
	if slot then
		Props.dresser(parent, at(slot, 1.8), 5, room.id)
		paintingAbove(parent, slot, room.id)
	end
	for _ = 1, 2 do
		slot = take(s, 3, 3)
		if slot then
			Props.plant(parent, at(slot, 1.8), true)
			paintingAbove(parent, slot, room.id + 1)
		end
	end
	slot = take(s, 6.8, 2.4)
	if slot then
		Props.bookshelf(parent, at(slot, 2), 6, 12, room.id)
	end
	if withArmor then
		for _ = 1, 2 do
			slot = take(s, 3, 2.8)
			if slot then
				Props.armor(parent, at(slot, 2.6))
			end
		end
	end
	lights(parent, room, true)
	sconces(parent, room, 2)
	local _ = ctx
end
D.lounge = function(parent, room, ctx)
	D.sitting(parent, room, ctx, true)
end

D.music = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st)
	local c = center(room)
	occupy(room, c * CFrame.new(0, 0, 2), 16, 22)
	Props.piano(parent, c * CFrame.new(0, 0, 8))
	for row = 0, 1 do
		for k = -2, 2 do
			Props.chair(parent, c * CFrame.new(k * 3.2, 0, -4 - row * 4) * CFrame.Angles(0, math.pi, 0), rgb(40, 50, 90))
		end
	end
	local s = slots(room)
	for k = 1, 4 do
		local slot = take(s, 6.8, 3)
		if slot then
			if k % 2 == 0 then
				Props.plant(parent, at(slot, 1.8), true)
			else
				Props.dresser(parent, at(slot, 1.8), 5, room.id + k)
			end
			paintingAbove(parent, slot, room.id + k)
		end
	end
	lights(parent, room, true)
	sconces(parent, room, 4)
	local _ = ctx
end

D.reading = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st, 12, 12)
	local c = center(room)
	Props.armchair(parent, c * CFrame.new(-3, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), rgb(40, 70, 50))
	Props.armchair(parent, c * CFrame.new(3, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), rgb(40, 70, 50))
	Props.coffeeTable(parent, c * CFrame.Angles(0, math.pi / 2, 0))
	local s = slots(room)
	for k = 1, 5 do
		local slot = take(s, 6.8, 2.4)
		if slot then
			Props.bookshelf(parent, at(slot, 2), 6, 13, room.id * 7 + k)
		end
	end
	local book = P(parent, "BookProp", Vector3.new(1.2, 0.3, 0.9), c * CFrame.new(0.8, 1.86, 0.4), rgb(40, 60, 110), Enum.Material.Fabric)
	ctx.prompt(book, "book")
	lights(parent, room)
	sconces(parent, room, 2)
end

D.trophy = function(parent, room, ctx)
	local s = slots(room)
	for k = 1, 6 do
		local slot = take(s, 7.2, 2.8)
		if slot then
			if k % 3 == 0 then
				Props.weaponRack(parent, at(slot, 1.8))
			else
				Props.armor(parent, at(slot, 2.6))
				Props.banner(parent, onWall(slot, 15), 7, Color3.fromHSV((k * 0.17) % 1, 0.6, 0.45))
			end
		end
	end
	Props.chest(parent, center(room), true)
	lights(parent, room, true)
	sconces(parent, room, 2)
	local _ = ctx
end

D.gallery = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st)
	local c = center(room)
	local w = size(room)
	for k = -1, 1, 2 do
		Props.bench(parent, c * CFrame.new(k * w / 6, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), 6)
	end
	for i, seg in room.segs do
		for _, off in { -9.5, 9.5 } do
			local p = seg.pos + seg.tangent * off
			Props.painting(parent, CFrame.lookAt(p, p + seg.inward) * CFrame.new(0, 8, -0.3), 7, 6, i * 3 + (if off > 0 then 1 else 0))
			Props.plant(parent, CFrame.lookAt(p, p + seg.inward) * CFrame.new(0, 0, -1.6))
		end
	end
	lights(parent, room, true)
	local _ = ctx
end

D.nursery = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st, 12, 12)
	local s = slots(room)
	for k = 1, 2 do
		local slot = take(s, 5.8, 9)
		if slot then
			local _, blanket = Props.bed(parent, at(slot, 8.5), Color3.fromHSV(k * 0.3, 0.3, 0.85))
			ctx.prompt(blanket, "rest", 1.5)
		end
	end
	local slot = take(s, 5.2, 2.8)
	if slot then
		Props.wardrobe(parent, at(slot, 2.4), rgb(200, 190, 170))
	end
	slot = take(s, 3.8, 2.4)
	if slot then
		Props.chest(parent, at(slot, 2))
		paintingAbove(parent, slot, 4)
	end
	-- кубики в центре
	local c = center(room)
	occupy(room, c, 4, 3)
	for k = 0, 5 do
		Props.P(parent, "ToyBlock", Vector3.new(1, 1, 1), c * CFrame.new(-1.5 + (k % 3), 0.5 + math.floor(k / 3), (k % 2) * 0.3) * CFrame.Angles(0, k * 0.3, 0), Color3.fromHSV(k / 6, 0.7, 0.9), Enum.Material.SmoothPlastic)
	end
	lights(parent, room)
	sconces(parent, room, 2)
end

D.wardrobe = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st, 10, 10)
	local s = slots(room)
	for k = 1, 5 do
		local slot = take(s, 5.6, 2.8)
		if slot then
			if k == 3 then
				Props.dresser(parent, at(slot, 1.8), 5, 2)
			else
				Props.wardrobe(parent, at(slot, 2.4), Color3.fromHSV(0.07, 0.45, 0.35 + k * 0.03))
			end
		end
	end
	-- вешалка с платьями
	local c = center(room)
	occupy(room, c * CFrame.new(0, 0, -2), 9, 9)
	P(parent, "Rail", Vector3.new(8, 0.25, 0.25), c * CFrame.new(0, 6.5, 0), Props.GOLD, Enum.Material.Metal)
	for _, x in { -3.8, 3.8 } do
		P(parent, "RailPost", Vector3.new(0.3, 6.5, 0.3), c * CFrame.new(x, 3.25, 0), Props.GOLD, Enum.Material.Metal)
	end
	for k = 0, 5 do
		P(parent, "Gown", Vector3.new(0.6, 4, 2), c * CFrame.new(-3 + k * 1.2, 4.2, 0), Color3.fromHSV(k * 0.15, 0.5, 0.6), Enum.Material.Fabric)
	end
	local chest = Props.chest(parent, c * CFrame.new(0, 0, -5))
	ctx.prompt(chest:FindFirstChild("Box"), "shop", 0, 10)
	lights(parent, room, true)
	sconces(parent, room, 2)
end

D.bath = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st, 8, 6)
	local s = slots(room)
	local slot = take(s, 6.8, 3.8)
	if slot then
		Props.bathtub(parent, at(slot, 6.4, CFrame.Angles(0, math.pi / 2, 0)))
	end
	slot = take(s, 3.8, 2.2)
	if slot then
		Props.washstand(parent, at(slot, 1.8))
		local basin = slot.cf
		local _ = basin
	end
	slot = take(s, 3, 3)
	if slot then
		Props.plant(parent, at(slot, 1.8), true)
	end
	slot = take(s, 5.6, 2.2)
	if slot then
		local m = Props.dresser(parent, at(slot, 1.8), 5, 2)
		for k = 0, 2 do
			P(m, "Towel", Vector3.new(1.6, 0.3, 1.2), at(slot, 1.8, CFrame.new(-1 + k, 3.5, 0)), rgb(240, 240, 236), Enum.Material.Fabric)
		end
	end
	lights(parent, room)
	sconces(parent, room, 2)
	local _ = ctx
end

D.kitchen = function(parent, room, ctx)
	local s = slots(room)
	local c = center(room)
	local stoves = 0
	for _, seg in solidWalls(room) do
		if stoves >= 2 then
			break
		end
		local p = seg.pos
		local _, mouth = Props.stove(parent, CFrame.lookAt(p, p + seg.inward) * CFrame.new(0, 0, -1.9))
		ctx.prompt(mouth, "cook", 2)
		stoves += 1
	end
	occupy(room, c, 22, 6)
	local _, top = Props.prepTable(parent, c * CFrame.new(-6, 0, 0))
	local bread = P(parent, "BreadLoaves", Vector3.new(2.2, 0.8, 1.2), c * CFrame.new(-8.2, top + 0.4, 0.6), rgb(196, 140, 70), Enum.Material.Sand)
	ctx.prompt(bread, "bread")
	Props.prepTable(parent, c * CFrame.new(6, 0, 0))
	local basket = C(parent, "AppleBasket", 0.9, 1.8, c * CFrame.new(7.8, top + 0.45, 0.6), rgb(150, 110, 60), Enum.Material.Fabric)
	for k = 0, 4 do
		Props.S(parent, "Apple", 0.55, c * CFrame.new(7.4 + (k % 3) * 0.4, top + 1, 0.3 + math.floor(k / 3) * 0.5), rgb(190, 40, 40), Enum.Material.SmoothPlastic, { CanCollide = false })
	end
	ctx.prompt(basket, "apple")
	local k = 0
	for _ = 1, 8 do
		local slot = take(s, 6.2, 3.6)
		if not slot then
			break
		end
		k += 1
		if k == 1 then
			local m = Props.dresser(parent, at(slot, 1.8), 5, 1)
			ctx.prompt(m:FindFirstChild("Body"), "spoon")
		elseif k == 2 then
			local m = Props.washtub(parent, at(slot, 3.2))
			ctx.prompt(m:FindFirstChild("Tub"), "water")
		elseif k % 3 == 0 then
			Props.barrel(parent, at(slot, 2.8))
			Props.barrel(parent, at(slot, 2.8, CFrame.new(3, 0, 0)))
			Props.shelfJars(parent, onWall(slot, 0), 6)
		elseif k % 3 == 1 then
			Props.sack(parent, at(slot, 2))
			Props.sack(parent, at(slot, 2, CFrame.new(2.2, 0, 0)))
			Props.panRack(parent, onWall(slot, 0))
		else
			Props.crate(parent, at(slot, 2.6))
			Props.shelfJars(parent, onWall(slot, 0), 6)
		end
	end
	lights(parent, room)
end

D.dining = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st)
	local c = center(room)
	local w, d = size(room)
	local long = math.max(w, d) - 18
	local rot = if w > d then CFrame.Angles(0, math.pi / 2, 0) else CFrame.new()
	occupy(room, c * rot, 10, long + 1)
	Props.feastTable(parent, c * rot, long, true)
	local s = slots(room)
	local walls = solidWalls(room)
	if walls[1] then
		local p = walls[1].pos
		Props.fireplace(parent, CFrame.lookAt(p, p + walls[1].inward) * CFrame.new(0, 0, -1.7), room.h)
	end
	for k = 1, 6 do
		local slot = if k % 2 == 0 then take(s, 3, 2.8) else take(s, 6.6, 2.2)
		if slot then
			if k % 2 == 0 then
				Props.armor(parent, at(slot, 2.6))
			else
				Props.dresser(parent, at(slot, 1.8), 6, k)
				paintingAbove(parent, slot, room.id + k)
			end
		end
	end
	lights(parent, room, true)
	sconces(parent, room, 4)
	local _ = ctx
end
D.royal_dining = D.dining

D.servants = function(parent, room, ctx)
	local s = slots(room)
	for k = 1, 4 do
		local slot = take(s, 5.8, 9)
		if slot then
			local _, blanket = Props.bed(parent, at(slot, 8.5), rgb(120, 110, 90))
			ctx.prompt(blanket, "rest", 1.5)
		end
	end
	local slot = take(s, 6.8, 2.2)
	if slot then
		local m = Props.weaponRack(parent, at(slot, 1.8))
		for _, d in m:GetChildren() do
			if d.Name == "Blade" then
				d.Color = rgb(150, 110, 60)
				d.Material = Enum.Material.Wood
			end
		end
		ctx.prompt(m:FindFirstChild("Back"), "broom")
	end
	slot = take(s, 3.6, 3.6)
	if slot then
		Props.washtub(parent, at(slot, 3.2))
	end
	slot = take(s, 3.8, 2.4)
	if slot then
		Props.chest(parent, at(slot, 2))
	end
	local c = center(room)
	occupy(room, c, 7, 7)
	Props.table(parent, c, 6, 3)
	Props.chair(parent, c * CFrame.new(-2, 0, -2.4) * CFrame.Angles(0, math.pi, 0))
	Props.chair(parent, c * CFrame.new(2, 0, 2.4))
	Props.candle(parent, (c * CFrame.new(0, 3.35, 0)).Position)
	lights(parent, room)
end

D.barracks = function(parent, room, ctx)
	occupy(room, center(room), 9, 6)
	Props.mapTable(parent, center(room))
	local s = slots(room)
	local k = 0
	for _ = 1, 10 do
		local nextK = k + 1
		local slot = if nextK == 1 then take(s, 6.8, 2.2) elseif nextK == 2 then take(s, 3.8, 2.4) elseif nextK % 3 == 0 then take(s, 3, 2.8) else take(s, 3.8, 7.6)
		if not slot then
			break
		end
		k += 1
		if k == 1 then
			local m = Props.weaponRack(parent, at(slot, 1.8))
			ctx.prompt(m:FindFirstChild("Back"), "sword")
		elseif k == 2 then
			local m = Props.chest(parent, at(slot, 2))
			ctx.prompt(m:FindFirstChild("Box"), "cuffs")
			P(parent, "ShacklesHook", Vector3.new(2, 0.3, 0.3), onWall(slot, 6), Props.IRON, Enum.Material.Metal)
		elseif k % 3 == 0 then
			Props.armor(parent, at(slot, 2.6))
			Props.banner(parent, onWall(slot, 15), 6)
		else
			Props.bunk(parent, at(slot, 7.2))
		end
	end
	lights(parent, room)
	sconces(parent, room, 2)
end

D.training = function(parent, room, ctx)
	local c = center(room)
	P(parent, "Mat", Vector3.new(18, 0.2, 18), c * CFrame.new(0, 0.1, 0), rgb(110, 96, 70), Enum.Material.Fabric)
	occupy(room, c, 16, 6)
	ctx.points.dummies = ctx.points.dummies or {}
	table.insert(ctx.points.dummies, c * CFrame.new(-5, 3, 0))
	table.insert(ctx.points.dummies, c * CFrame.new(5, 3, 0))
	local s = slots(room)
	for k = 1, 6 do
		local slot = take(s, 7.2, 2.2)
		if slot then
			if k == 1 then
				local m = Props.weaponRack(parent, at(slot, 1.8))
				ctx.prompt(m:FindFirstChild("Back"), "sword")
			elseif k % 2 == 0 then
				Props.bench(parent, at(slot, 1.8), 6)
			else
				-- мишень для стрельбы
				local cf = at(slot, 1)
				P(parent, "TargetStand", Vector3.new(0.4, 5, 0.4), cf * CFrame.new(0, 2.5, 0.3), Props.WOOD, Enum.Material.Wood)
				for r = 0, 3 do
					C(parent, "Target", 0.2 + r * 0.02, 4 - r, cf * CFrame.new(0, 5, -r * 0.06) * CFrame.Angles(math.pi / 2, 0, 0), if r % 2 == 0 then rgb(230, 225, 210) else rgb(170, 30, 30), Enum.Material.Fabric)
				end
			end
		end
	end
	lights(parent, room)
end

D.chapel = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	local c = center(room)
	local w, d = size(room)
	local walls = solidWalls(room)
	local altarSeg = walls[1]
	local forward = if altarSeg then altarSeg.inward else Vector3.new(0, 0, -1)
	if altarSeg then
		local p = altarSeg.pos
		Props.altar(parent, CFrame.lookAt(p, p + altarSeg.inward) * CFrame.new(0, 0, -3))
		Props.stainedGlass(parent, CFrame.lookAt(p, p + altarSeg.inward) * CFrame.new(0, 10, -0.3), 6, 8)
	end
	local base = CFrame.lookAt(c.Position, c.Position + forward)
	Props.runner(parent, base, 3, math.min(w, d) - 6, st.rug)
	local rows = math.floor((math.min(w, d) - 14) / 3.6)
	for r = 0, rows - 1 do
		for _, sx in { -1, 1 } do
			Props.pew(parent, base * CFrame.new(sx * 5.5, 0, -2 + r * 3.6), 7)
		end
	end
	local s = slots(room)
	for _ = 1, 4 do
		local slot = take(s, 1.4, 1.4)
		if slot then
			Props.candelabra(parent, at(slot, 1).Position)
			Props.painting(parent, onWall(slot, 9), 4, 6, 1)
		end
	end
	lights(parent, room, true)
	local _ = ctx
end
D.chapel_small = D.chapel

D.shop = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st, 10, 8)
	local c = center(room)
	occupy(room, c * CFrame.new(0, 0, 3), 11, 3)
	local counter = Props.counter(parent, c * CFrame.new(0, 0, 3), 10)
	ctx.prompt(counter:FindFirstChild("Body"), "shop", 0, 12)
	local s = slots(room)
	for k = 1, 6 do
		local slot = take(s, 6.2, 3)
		if slot then
			if k % 2 == 1 then
				Props.shelfJars(parent, onWall(slot, -2), 6)
				Props.crate(parent, at(slot, 2.2), 2.2)
			else
				Props.wardrobe(parent, at(slot, 2.4), rgb(110, 80, 50))
			end
		end
	end
	lights(parent, room)
	sconces(parent, room, 2)
end

D.casino = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st)
	occupy(room, center(room), 13, 13)
	local felt = Props.feltTable(parent, center(room))
	ctx.prompt(felt:FindFirstChild("Felt"), "coin")
	local s = slots(room)
	for k = 1, 4 do
		local slot = take(s, 3.6, 2.8)
		if slot then
			local m = Props.slotMachine(parent, at(slot, 2.4))
			ctx.prompt(m:FindFirstChild("Cabinet"), "slots")
		end
	end
	lights(parent, room, true)
end

D.treasury = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st)
	local c = center(room)
	occupy(room, c, 16, 16)
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2
		local p = c * CFrame.new(math.cos(a) * 6, 0, math.sin(a) * 6)
		P(parent, "Pedestal", Vector3.new(2, 3.4, 2), p * CFrame.new(0, 1.7, 0), rgb(220, 214, 204), Enum.Material.Marble)
		if k % 2 == 0 then
			C(parent, "CrownBand", 0.6, 1.4, p * CFrame.new(0, 3.7, 0), Props.GOLD, Enum.Material.Metal)
			Props.S(parent, "Jewel", 0.4, p * CFrame.new(0, 4.2, 0), rgb(200, 30, 50), Enum.Material.Neon)
		else
			for g = 0, 3 do
				P(parent, "GoldBar", Vector3.new(1, 0.4, 0.5), p * CFrame.new(0, 3.6 + g * 0.4, (g % 2) * 0.2 - 0.1), Props.GOLD, Enum.Material.Metal)
			end
		end
	end
	Props.chest(parent, c, true)
	local s = slots(room)
	for k = 1, 8 do
		local slot = take(s, 3.8, 2.8)
		if slot then
			if k % 3 == 0 then
				Props.armor(parent, at(slot, 2.6))
			else
				Props.chest(parent, at(slot, 2), k % 2 == 0)
			end
		end
	end
	lights(parent, room, true)
	local _ = ctx
end

D.council = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st)
	local c = center(room)
	occupy(room, c, 22, 22)
	C(parent, "RoundTable", 0.5, 16, c * CFrame.new(0, 3.2, 0), Props.WOOD, Enum.Material.Wood)
	C(parent, "TableBase", 3, 3, c * CFrame.new(0, 1.5, 0), Props.WOOD_DARK, Enum.Material.Wood)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		local cp = (c * CFrame.new(math.cos(a) * 9.5, 0, math.sin(a) * 9.5)).Position
		Props.chair(parent, CFrame.lookAt(cp, Vector3.new(c.Position.X, cp.Y, c.Position.Z)), rgb(40, 50, 90))
	end
	for k = 0, 4 do
		Props.candle(parent, (c * CFrame.new(math.cos(k) * 4, 3.45, math.sin(k) * 4)).Position)
	end
	local walls = solidWalls(room)
	if walls[1] then
		local p = walls[1].pos
		Props.fireplace(parent, CFrame.lookAt(p, p + walls[1].inward) * CFrame.new(0, 0, -1.7), room.h)
	end
	local s = slots(room)
	for k = 1, 6 do
		local slot = if k % 2 == 0 then take(s, 3, 2.8) else take(s, 6.8, 2.4)
		if slot then
			Props.banner(parent, onWall(slot, 15), 8, Color3.fromHSV(k * 0.15, 0.6, 0.4))
			if k % 2 == 0 then
				Props.armor(parent, at(slot, 2.6))
			else
				Props.bookshelf(parent, at(slot, 2), 6, 10, k)
			end
		end
	end
	lights(parent, room, true)
	local _ = ctx
end

local function royal(parent, room, ctx, color, isKing)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st)
	local s = slots(room)
	local slot = take(s, 7.8, 10)
	if slot then
		local _, blanket = Props.bed(parent, at(slot, 9.5), color, true)
		ctx.prompt(blanket, "rest", 1.5)
	end
	local walls = solidWalls(room)
	if walls[1] then
		local p = walls[1].pos
		Props.fireplace(parent, CFrame.lookAt(p, p + walls[1].inward) * CFrame.new(0, 0, -1.7), room.h)
	end
	sittingArea(parent, room, color)
	local dims = { { 5.2, 2.8 }, { 6.6, 2.2 }, { 5.4, 5.6 }, { 1.8, 1.8 }, { 3, 2.8 }, { 3, 3 }, { 3, 3 }, { 3, 3 } }
	for k = 1, 8 do
		slot = take(s, dims[k][1], dims[k][2])
		if not slot then
			break
		end
		if k == 1 then
			Props.wardrobe(parent, at(slot, 2.4), Props.WOOD_DARK)
		elseif k == 2 then
			Props.dresser(parent, at(slot, 1.8), 6, 2)
			paintingAbove(parent, slot, room.id)
		elseif k == 3 then
			Props.desk(parent, at(slot, 2.6))
		elseif k == 4 and isKing then
			local stand = P(parent, "ScepterStand", Vector3.new(1.6, 4, 1.6), at(slot, 1.6, CFrame.new(0, 2, 0)), rgb(220, 214, 204), Enum.Material.Marble)
			P(parent, "Scepter", Vector3.new(0.3, 3, 0.3), at(slot, 1.6, CFrame.new(0, 5.5, 0)), Props.GOLD, Enum.Material.Metal, { CanCollide = false })
			Props.S(parent, "Gem", 0.6, at(slot, 1.6, CFrame.new(0, 7.2, 0)), rgb(200, 30, 50), Enum.Material.Neon, { CanCollide = false })
			ctx.prompt(stand, "scepter")
		elseif k == 5 then
			Props.armor(parent, at(slot, 2.6))
		else
			Props.plant(parent, at(slot, 1.8), true)
			paintingAbove(parent, slot, room.id + k)
		end
	end
	lights(parent, room, true)
	sconces(parent, room, 4)
end
D.king = function(parent, room, ctx)
	royal(parent, room, ctx, rgb(140, 18, 28), true)
end
D.queen = function(parent, room, ctx)
	royal(parent, room, ctx, rgb(100, 40, 120), false)
	local c = center(room)
	Props.piano(parent, c * CFrame.new(-8, 0, -8) * CFrame.Angles(0, math.pi / 4, 0))
end

D.landing = function(parent, room, ctx)
	-- в клетке есть проём лестницы у восточной стены: обставляем только западную стену
	for _, seg in room.segs do
		if seg.inward.X > 0.5 then
			local cf = CFrame.lookAt(seg.pos, seg.pos + seg.inward)
			Props.bench(parent, cf * CFrame.new(0, 0, -1.3), 7)
			Props.painting(parent, cf * CFrame.new(0, 8.5, -0.3), 7, 5, room.id)
			Props.plant(parent, cf * CFrame.new(-8, 0, -1.4), true)
			Props.plant(parent, cf * CFrame.new(8, 0, -1.4), true)
		end
	end
	lights(parent, room)
	local _ = ctx
end

D.storeroom = function(parent, room, ctx)
	local s = slots(room)
	local k = 0
	for _ = 1, 16 do
		local slot = take(s, 6.2, 3)
		if not slot then
			break
		end
		k += 1
		if k % 3 == 0 then
			Props.barrel(parent, at(slot, 2.8))
			Props.barrel(parent, at(slot, 2.8, CFrame.new(3, 0, 0)))
		elseif k % 3 == 1 then
			Props.crate(parent, at(slot, 2.6))
			Props.crate(parent, at(slot, 2.6, CFrame.new(0, 2.6, 0)), 2.2)
			Props.crate(parent, at(slot, 2.6, CFrame.new(2.9, 0, 0)))
		else
			Props.sack(parent, at(slot, 2))
			Props.sack(parent, at(slot, 2, CFrame.new(2.2, 0, 0)))
			Props.shelfJars(parent, onWall(slot, 0), 6)
		end
	end
	for _, c in room.cells do
		Props.ceilingLamp(parent, Vector3.new(c.x, room.y + room.h - 3.5, c.z), 2.5)
	end
	local _ = ctx
end
D.storage = D.storeroom

D.cellar = function(parent, room, ctx)
	local s = slots(room)
	for _ = 1, 20 do
		local slot = take(s, 5.4, 3.4)
		if not slot then
			break
		end
		-- стеллаж с лежащими бочками в два яруса и бутылками сбоку
		local cf = at(slot, 3)
		local rack = Props.model(parent, "WineRack")
		P(rack, "Shelf", Vector3.new(5, 0.4, 3), cf * CFrame.new(0, 3.2, 0), Props.WOOD_DARK, Enum.Material.Wood)
		P(rack, "Top", Vector3.new(5, 0.4, 3), cf * CFrame.new(0, 6.6, 0), Props.WOOD_DARK, Enum.Material.Wood)
		for _, x in { -2.3, 2.3 } do
			P(rack, "Post", Vector3.new(0.4, 6.8, 3), cf * CFrame.new(x, 3.4, 0), Props.WOOD_DARK, Enum.Material.Wood)
		end
		Props.barrel(rack, cf * CFrame.new(0, -0.1, 0), true)
		Props.barrel(rack, cf * CFrame.new(0, 3.3, 0), true)
		for k = 0, 2 do
			C(rack, "Bottle", 1.1, 0.32, cf * CFrame.new(-1.5 + k * 1.5, 7.35, 0), rgb(40, 70, 40), Enum.Material.Glass, { CanCollide = false })
		end
	end
	local c = center(room)
	occupy(room, c, 7, 4)
	Props.table(parent, c, 6, 3)
	for k = 0, 4 do
		C(parent, "Bottle", 1.2, 0.35, c * CFrame.new(-2 + k, 4, 0), rgb(40, 70, 40), Enum.Material.Glass)
	end
	for _, cell in room.cells do
		Props.ceilingLamp(parent, Vector3.new(cell.x, room.y + room.h - 3.5, cell.z), 2.5)
	end
	local _ = ctx
end

D.guardroom = function(parent, room, ctx)
	local c = center(room)
	occupy(room, c, 10, 5)
	Props.table(parent, c, 6, 4)
	for _, s in { -1, 1 } do
		Props.chair(parent, c * CFrame.new(s * 4, 0, 0) * CFrame.Angles(0, s * math.pi / 2, 0))
	end
	Props.candle(parent, (c * CFrame.new(0, 3.35, 0)).Position)
	P(parent, "Keys", Vector3.new(0.8, 0.1, 0.5), c * CFrame.new(1, 3.4, 0.5), Props.GOLD, Enum.Material.Metal)
	local s = slots(room)
	for k = 1, 4 do
		local slot = take(s, 6.8, 3)
		if slot then
			if k == 1 then
				local m = Props.weaponRack(parent, at(slot, 1.8))
				ctx.prompt(m:FindFirstChild("Back"), "sword")
			elseif k == 2 then
				local m = Props.chest(parent, at(slot, 2))
				ctx.prompt(m:FindFirstChild("Box"), "cuffs")
			else
				Props.barrel(parent, at(slot, 2.8))
			end
		end
	end
	for _, cell in room.cells do
		Props.ceilingLamp(parent, Vector3.new(cell.x, room.y + room.h - 3.5, cell.z), 2.5)
	end
end
D.prison_guard = function(parent, room, ctx)
	for _, cell in room.cells do
		Props.ceilingLamp(parent, Vector3.new(cell.x, room.y + room.h - 3.5, cell.z), 2.5)
	end
	local _ = ctx
	local _ = parent
end

D.grand_hall = function(parent, room, ctx)
	local c = center(room)
	local w, d = size(room)
	local st = Rooms.style(room.kind)
	Props.rug(parent, c, w - 30, d - 20, st.rug)
	-- два ряда колонн
	for _, sx in { -1, 1 } do
		for k = -2, 2 do
			Props.column(parent, c * CFrame.new(sx * (w / 2 - 12), 0, k * (d / 5)), room.h, 1.6)
		end
	end
	for k = -1, 1 do
		Props.chandelier(parent, Vector3.new(c.X + k * 26, room.y + room.h - 9, c.Z), 7, 8)
	end
	local s = slots(room)
	for k = 1, 10 do
		local slot = take(s, 7.2, 3)
		if slot then
			if k % 2 == 0 then
				Props.armor(parent, at(slot, 2.6))
			else
				Props.plant(parent, at(slot, 1.8), true)
			end
			Props.banner(parent, onWall(slot, room.h - 4), 12, if k % 3 == 0 then rgb(30, 50, 110) else rgb(120, 22, 30))
		end
	end
	-- доска ролей у входа
	local board = P(parent, "RoleBoard", Vector3.new(8, 6, 0.4), c * CFrame.new(-14, 5, -d / 2 + 9) * CFrame.Angles(0, math.pi, 0), Props.WOOD, Enum.Material.WoodPlanks)
	for _, x in { -3.6, 3.6 } do
		P(parent, "BoardLeg", Vector3.new(0.4, 8, 0.4), c * CFrame.new(-14 + x, 4, -d / 2 + 9), Props.WOOD_DARK, Enum.Material.Wood)
	end
	for k = 0, 5 do
		P(parent, "Notice", Vector3.new(1.6, 2, 0.05), c * CFrame.new(-16.5 + (k % 3) * 2.4, 5.8 - math.floor(k / 3) * 2.4, -d / 2 + 8.75), rgb(240, 230, 200), Enum.Material.SmoothPlastic)
	end
	ctx.prompt(board, "roles", 0, 12)
	Props.bench(parent, c * CFrame.new(14, 0, -d / 2 + 9), 8)
	Props.grandfatherClock(parent, c * CFrame.new(w / 2 - 2.3, 0, d / 2 - 2.3) * CFrame.Angles(0, math.pi * 0.75, 0))
end

-- клетка коридора: дорожка, бра, картины, столики, доспехи
function Rooms.hallCell(parent, cell, room, ctx, alongX: boolean)
	local cf = CFrame.new(cell.x, room.y, cell.z) * (if alongX then CFrame.Angles(0, math.pi / 2, 0) else CFrame.new())
	Props.runner(parent, cf, 6, 32, Rooms.STYLE.hall.rug)
	Props.ceilingLamp(parent, Vector3.new(cell.x, room.y + room.h - 3, cell.z), 2.5)
	local _ = ctx
end

function Rooms.hallWalls(parent, room, seed)
	-- по сторонам коридора: у каждого участка стены картина с бра или доспехи
	for i, seg in room.segs do
		for _, off in { -9.5, 9.5 } do
			local p = seg.pos + seg.tangent * off
			local cf = CFrame.lookAt(p, p + seg.inward)
			local k = (i * 2 + (if off > 0 then 1 else 0) + seed) % 5
			if k == 0 then
				Props.armor(parent, cf * CFrame.new(0, 0, -1.7))
			elseif k == 1 then
				Props.plant(parent, cf * CFrame.new(0, 0, -1.2), true)
				Props.painting(parent, cf * CFrame.new(0, 8.5, -0.3), 5, 4, i)
			elseif k == 2 then
				-- консольный столик с вазой
				P(parent, "Console", Vector3.new(4, 0.3, 1.4), cf * CFrame.new(0, 3, -1), Props.WOOD, Enum.Material.Wood)
				for _, x in { -1.7, 1.7 } do
					P(parent, "ConsoleLeg", Vector3.new(0.25, 2.85, 0.25), cf * CFrame.new(x, 1.43, -1), Props.WOOD_DARK, Enum.Material.Wood)
				end
				C(parent, "Vase", 1.4, 0.8, cf * CFrame.new(0, 3.85, -1), Color3.fromHSV((i * 0.17) % 1, 0.45, 0.6), Enum.Material.Glass)
				Props.painting(parent, cf * CFrame.new(0, 8.5, -0.3), 5, 4, i + 1)
			elseif k == 3 then
				Props.painting(parent, cf * CFrame.new(0, 8, -0.3), 4, 6, i + 2)
				Props.bench(parent, cf * CFrame.new(0, 0, -1.2), 5)
			else
				Props.grandfatherClock(parent, cf * CFrame.new(0, 0, -1))
			end
			if (i + seed) % 2 == 0 then
				local sp = seg.pos + seg.tangent * (off * 0.55) + Vector3.new(0, 8, 0)
				Props.sconce(parent, CFrame.lookAt(sp, sp + seg.inward), false)
			end
		end
	end
end

function Rooms.decorate(parent: Instance, room, ctx)
	local fn = D[room.kind]
	if fn then
		fn(parent, room, ctx)
	end
end

Rooms.slots = slots
return Rooms
