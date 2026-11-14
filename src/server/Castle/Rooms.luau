--!nonstrict
-- Обстановка комнат по их назначению. Мебель ставится зеркальными парами вдоль стен:
-- каждая стена симметрична относительно своей середины (дверь, окно, камин, кровать).
-- Занятые места запоминаются, поэтому предметы не налезают друг на друга и на проходы

local MAT = require(game:GetService("ReplicatedStorage").Workshop.Shared.Materials)
local Props = require(script.Parent.Props)

local Rooms = {}

local rgb = Props.rgb
local P, C = Props.P, Props.C

-- Стили: обои, пол, низ стены. Пол везде каменный, дерево только в отделке
Rooms.STYLE = {
	hall = { paper = rgb(156, 146, 130), wall = MAT.Limestone, plinth = true, floor = rgb(150, 140, 126), mat = MAT.Slate, rug = rgb(120, 22, 30) },
	grand_hall = { paper = rgb(186, 176, 158), wall = MAT.Limestone, plinth = true, floor = rgb(196, 188, 176), mat = MAT.Marble, rug = rgb(120, 22, 30) },
	throne = { paper = rgb(176, 166, 150), wall = MAT.Limestone, plinth = true, floor = rgb(206, 198, 186), mat = MAT.Marble, rug = rgb(140, 20, 28) },
	bedroom = { paper = rgb(52, 74, 62), wall = MAT.Plaster, floor = rgb(128, 120, 110), mat = MAT.Slate, rug = rgb(110, 40, 40) },
	guest_suite = { paper = rgb(66, 58, 90), wall = MAT.Plaster, floor = rgb(128, 120, 110), mat = MAT.Slate, rug = rgb(60, 50, 100) },
	study = { paper = rgb(104, 70, 46), wall = MAT.WoodPlanks, floor = rgb(120, 112, 102), mat = MAT.Granite, rug = rgb(90, 30, 30) },
	sitting = { paper = rgb(110, 84, 54), wall = MAT.Plaster, floor = rgb(150, 140, 126), mat = MAT.Granite, rug = rgb(40, 60, 90) },
	lounge = { paper = rgb(70, 34, 50), wall = MAT.Plaster, floor = rgb(150, 140, 126), mat = MAT.Granite, rug = rgb(90, 30, 60) },
	music = { paper = rgb(44, 58, 84), wall = MAT.Plaster, floor = rgb(176, 168, 156), mat = MAT.Marble, rug = rgb(120, 22, 30) },
	reading = { paper = rgb(96, 64, 42), wall = MAT.WoodPlanks, floor = rgb(120, 112, 102), mat = MAT.Slate, rug = rgb(40, 70, 50) },
	trophy = { paper = rgb(150, 140, 124), wall = MAT.Limestone, plinth = true, floor = rgb(110, 104, 98), mat = MAT.Slate, rug = rgb(60, 40, 30) },
	gallery = { paper = rgb(36, 50, 70), wall = MAT.Plaster, floor = rgb(196, 188, 176), mat = MAT.Marble, rug = rgb(120, 22, 30) },
	nursery = { paper = rgb(150, 170, 186), wall = MAT.Plaster, floor = rgb(176, 168, 156), mat = MAT.Marble, rug = rgb(200, 150, 170) },
	wardrobe = { paper = rgb(100, 70, 90), wall = MAT.Plaster, floor = rgb(150, 140, 126), mat = MAT.Marble, rug = rgb(110, 50, 80) },
	bath = { paper = rgb(196, 214, 218), wall = MAT.CeramicTiles, floor = rgb(220, 218, 212), mat = MAT.CeramicTiles, rug = rgb(70, 110, 140) },
	kitchen = { paper = rgb(140, 120, 100), wall = MAT.Brick, plinth = true, floor = rgb(120, 110, 98), mat = MAT.Cobblestone, rug = nil },
	dining = { paper = rgb(150, 138, 120), wall = MAT.Limestone, plinth = true, floor = rgb(150, 140, 126), mat = MAT.Slate, rug = rgb(120, 22, 30) },
	servants = { paper = rgb(140, 128, 108), wall = MAT.Plaster, floor = rgb(110, 104, 98), mat = MAT.Slate, rug = rgb(100, 80, 60) },
	barracks = { paper = rgb(130, 124, 114), wall = MAT.Cobblestone, plinth = true, floor = rgb(100, 96, 90), mat = MAT.Cobblestone, rug = nil },
	training = { paper = rgb(176, 166, 148), wall = MAT.Limestone, plinth = true, floor = rgb(120, 114, 106), mat = MAT.Pavement, rug = nil },
	chapel = { paper = rgb(214, 204, 184), wall = MAT.Limestone, plinth = true, floor = rgb(206, 198, 186), mat = MAT.Marble, rug = rgb(120, 22, 30) },
	chapel_small = { paper = rgb(214, 204, 184), wall = MAT.Limestone, plinth = true, floor = rgb(206, 198, 186), mat = MAT.Marble, rug = rgb(120, 22, 30) },
	shop = { paper = rgb(120, 84, 54), wall = MAT.WoodPlanks, floor = rgb(150, 140, 126), mat = MAT.Limestone, rug = rgb(60, 80, 40) },
	casino = { paper = rgb(60, 20, 50), wall = MAT.Plaster, floor = rgb(40, 34, 40), mat = MAT.Marble, rug = rgb(110, 20, 60) },
	stairs = { paper = rgb(156, 146, 130), wall = MAT.Limestone, plinth = true, floor = rgb(150, 140, 126), mat = MAT.Slate, rug = rgb(120, 22, 30) },
	stairs_down = { paper = rgb(80, 74, 66), wall = MAT.Cobblestone, floor = rgb(120, 114, 106), mat = MAT.Slate, rug = nil },
	landing = { paper = rgb(156, 146, 130), wall = MAT.Limestone, plinth = true, floor = rgb(150, 140, 126), mat = MAT.Slate, rug = rgb(120, 22, 30) },
	observatory = { paper = rgb(30, 34, 60), wall = MAT.Plaster, floor = rgb(120, 112, 102), mat = MAT.Slate, rug = rgb(30, 40, 80) },
	treasury = { paper = rgb(200, 186, 150), wall = MAT.Marble, floor = rgb(196, 188, 176), mat = MAT.Marble, rug = rgb(120, 22, 30) },
	council = { paper = rgb(160, 150, 134), wall = MAT.Limestone, plinth = true, floor = rgb(150, 140, 126), mat = MAT.Marble, rug = rgb(120, 22, 30) },
	map_room = { paper = rgb(110, 76, 50), wall = MAT.WoodPlanks, floor = rgb(150, 140, 126), mat = MAT.Granite, rug = rgb(60, 50, 30) },
	royal_dining = { paper = rgb(100, 28, 32), wall = MAT.Plaster, floor = rgb(196, 188, 176), mat = MAT.Marble, rug = rgb(120, 22, 30) },
	king = { paper = rgb(110, 22, 30), wall = MAT.Plaster, floor = rgb(206, 198, 186), mat = MAT.Marble, rug = rgb(150, 20, 28) },
	queen = { paper = rgb(84, 46, 100), wall = MAT.Plaster, floor = rgb(206, 198, 186), mat = MAT.Marble, rug = rgb(110, 50, 130) },
	storeroom = { paper = rgb(90, 86, 80), floor = rgb(96, 92, 88), mat = MAT.Cobblestone, rug = nil },
	guardroom = { paper = rgb(90, 86, 80), floor = rgb(96, 92, 88), mat = MAT.Cobblestone, rug = nil },
	prison_guard = { paper = rgb(90, 86, 80), floor = rgb(96, 92, 88), mat = MAT.Cobblestone, rug = nil },
	cellar = { paper = rgb(84, 70, 60), floor = rgb(96, 88, 80), mat = MAT.Cobblestone, rug = nil },
	storage = { paper = rgb(90, 86, 80), floor = rgb(96, 92, 88), mat = MAT.Cobblestone, rug = nil },
}
Rooms.STYLE.default = Rooms.STYLE.hall

function Rooms.style(kind: string)
	return Rooms.STYLE[kind] or Rooms.STYLE.default
end

-- ---------------------------------------------------------------------------
-- Расстановка. Каждый 32-studs участок стены — одна композиция, симметричная
-- относительно его середины: посередине дверь, окно или главный предмет (камин,
-- кровать, алтарь), по бокам — одинаковая пара предметов на ±9 studs. Всё, что
-- ставится в пару, ставится зеркально в оба места

local PAIR_OFF = 9

-- пары мест у стен в постоянном порядке (сначала глухие стены, потом с проёмами)
local function slots(room)
	local list = {}
	for si, seg in room.segs do
		local base = CFrame.lookAt(seg.pos, seg.pos + seg.inward)
		table.insert(list, {
			seg = seg,
			room = room,
			index = si,
			used = false,
			L = { cf = base * CFrame.new(-PAIR_OFF, 0, 0), side = -1, seg = seg, room = room },
			R = { cf = base * CFrame.new(PAIR_OFF, 0, 0), side = 1, seg = seg, room = room },
		})
	end
	table.sort(list, function(a, b)
		local sa, sb = if a.seg.opening then 1 else 0, if b.seg.opening then 1 else 0
		if sa ~= sb then
			return sa < sb
		end
		return (a.index * 7919) % 101 < (b.index * 7919) % 101
	end)
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

-- занять место в середине комнаты (столы, диваны), чтобы мебель у стен туда не заходила
local function occupy(room, cf: CFrame, w: number, d: number)
	room.occ = room.occ or {}
	table.insert(room.occ, rectOf(cf, w, d))
end

-- свободная пара мест, куда с обеих сторон помещается предмет w × d (спиной к стене)
local function take(list, w: number, d: number, openingOnly: boolean?)
	for _, pair in list do
		if not pair.used and (not openingOnly or pair.seg.opening) then
			local room = pair.room
			room.occ = room.occ or {}
			local rl = rectOf(pair.L.cf * CFrame.new(0, 0, -(d / 2 + 0.35)), w, d)
			local rr = rectOf(pair.R.cf * CFrame.new(0, 0, -(d / 2 + 0.35)), w, d)
			if not hits(room.occ, rl) and not hits(room.occ, rr) then
				pair.used = true
				table.insert(room.occ, rl)
				table.insert(room.occ, rr)
				return pair
			end
		end
	end
	return nil
end

-- оба места пары (или пусто, если пары нет)
local function sides(pair)
	if not pair then
		return {}
	end
	return { pair.L, pair.R }
end

-- середина глухого участка стены для главного предмета (камин, кровать, алтарь)
local function middle(room, list, w: number, d: number)
	for _, pair in list do
		if not pair.seg.opening and not pair.mid then
			local cf = CFrame.lookAt(pair.seg.pos, pair.seg.pos + pair.seg.inward)
			room.occ = room.occ or {}
			local r = rectOf(cf * CFrame.new(0, 0, -(d / 2 + 0.35)), w, d)
			if not hits(room.occ, r) then
				pair.mid = true
				table.insert(room.occ, r)
				return { cf = cf, side = 0, seg = pair.seg, room = room }
			end
		end
	end
	return nil
end

-- место предмета глубиной depth спиной к стене; ox, oy, oz и yaw зеркалятся у правого места
local function at(slot, depth: number, ox: number?, oy: number?, oz: number?, yaw: number?)
	local m = if slot.side == 1 then -1 else 1
	return slot.cf * CFrame.new((ox or 0) * m, oy or 0, -(depth / 2 + 0.35) + (oz or 0)) * CFrame.Angles(0, (yaw or 0) * m, 0)
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

-- камин посередине глухой стены
local function fireplace(parent, room, list)
	local fp = middle(room, list, 8.4, 4)
	if fp then
		Props.fireplace(parent, fp.cf * CFrame.new(0, 0, -1.7), room.h)
	end
	return fp
end

-- свет комнаты: люстра или фонарь в центре каждой клетки (не больше четырёх).
-- Цепь доходит до потолка (низ потолка — y + h - 0.25)
local function lights(parent, room, chandelier: boolean?)
	local n = 0
	for _, c in room.cells do
		n += 1
		if n > 4 then
			break
		end
		if chandelier then
			Props.chandelier(parent, Vector3.new(c.x, room.y + room.h - 4, c.z), 3, 4)
		else
			Props.ceilingLamp(parent, Vector3.new(c.x, room.y + room.h - 3.5, c.z), 3)
		end
	end
end

-- бра у углов участков стены (±13 от середины): дальше от пар мебели, симметрично.
-- Светит только первое, остальные — украшение (меньше источников света)
local function sconces(parent, room, count: number)
	local n = 0
	for _, seg in room.segs do
		if n >= count then
			break
		end
		for _, off in { -13, 13 } do
			local p = seg.pos + seg.tangent * off + Vector3.new(0, 8.5, 0)
			Props.sconce(parent, CFrame.lookAt(p, p + seg.inward), n < 1)
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

-- оставшиеся пустые пары заполняются, чтобы стены не были голыми
local function fill(parent, list, kind: string?)
	local k = 0
	for _, pair in list do
		if not pair.used then
			k += 1
			local p2 = take({ pair }, 3, 3)
			if p2 then
				for _, slot in sides(p2) do
					if kind == "stone" then
						Props.barrel(parent, at(slot, 2.8))
					else
						Props.plant(parent, at(slot, 1.8), true)
						paintingAbove(parent, slot, pair.index + k)
					end
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------

local D = {}

-- кровать изголовьем к середине глухой стены, по бокам тумбочки
local function bedOnWall(parent, room, list, ctx, color, royal: boolean?)
	local w, d = if royal then 8 else 6, if royal then 9.8 else 8.8
	local spot = middle(room, list, w + 5, d)
	if spot then
		local _, blanket = Props.bed(parent, spot.cf * CFrame.new(0, 0, -(d / 2 + 0.2)), color, royal)
		ctx.prompt(blanket, "rest", 1.5)
		for _, sx in { -1, 1 } do
			Props.nightstand(parent, spot.cf * CFrame.new(sx * (w / 2 + 1.3), 0, -1.2))
		end
		return true
	end
	-- глухой стены нет: две кровати парой
	for _, slot in sides(take(list, 6, 9)) do
		local _, blanket = Props.bed(parent, at(slot, 8.5), color, royal)
		ctx.prompt(blanket, "rest", 1.5)
	end
	return false
end

D.bedroom = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	local s = slots(room)
	rugCenter(parent, room, st, 14, 10)
	bedOnWall(parent, room, s, ctx, Color3.fromHSV((room.id * 0.13) % 1, 0.45, 0.5))
	fireplace(parent, room, s)
	for _, slot in sides(take(s, 5.2, 2.8)) do
		Props.wardrobe(parent, at(slot, 2.4))
	end
	for _, slot in sides(take(s, 5.6, 2.2)) do
		Props.dresser(parent, at(slot, 1.8), 5, room.id)
		paintingAbove(parent, slot, room.id)
	end
	for _, slot in sides(take(s, 3.4, 3)) do
		Props.armchair(parent, at(slot, 2.8), rgb(110, 40, 40))
	end
	fill(parent, s)
	lights(parent, room)
	sconces(parent, room, 2)
end

local function sittingArea(parent, room, color)
	local c = center(room)
	occupy(room, c * CFrame.new(0, 0, 2), 14, 11)
	Props.sofa(parent, c * CFrame.new(0, 0, 4.5), color)
	Props.coffeeTable(parent, c * CFrame.new(0, 0, 0.5))
	Props.armchair(parent, c * CFrame.new(-5, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), color)
	Props.armchair(parent, c * CFrame.new(5, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), color)
end

D.guest_suite = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	local s = slots(room)
	rugCenter(parent, room, st)
	sittingArea(parent, room, rgb(70, 60, 110))
	bedOnWall(parent, room, s, ctx, rgb(70, 60, 110))
	fireplace(parent, room, s)
	for _, slot in sides(take(s, 5.2, 2.8)) do
		Props.wardrobe(parent, at(slot, 2.4))
	end
	for _, slot in sides(take(s, 5.6, 2.2)) do
		Props.dresser(parent, at(slot, 1.8), 5, room.id)
		paintingAbove(parent, slot, room.id)
	end
	for _, slot in sides(take(s, 6.8, 2.4)) do
		Props.bookshelf(parent, at(slot, 2), 6, 12, room.id)
	end
	fill(parent, s)
	lights(parent, room, true)
	sconces(parent, room, 2)
end

D.study = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	local s = slots(room)
	rugCenter(parent, room, st, 12, 10)
	occupy(room, center(room), 6, 6)
	Props.desk(parent, center(room) * CFrame.new(0, 0, 1))
	local book = P(parent, "BookProp", Vector3.new(1.2, 0.3, 0.9), center(room) * CFrame.new(0, 3.52, 1.2), rgb(110, 30, 30), MAT.Leather)
	ctx.prompt(book, "book")
	fireplace(parent, room, s)
	for _ = 1, 2 do
		for _, slot in sides(take(s, 6.8, 2.4)) do
			Props.bookshelf(parent, at(slot, 2), 6, 12, room.id * 10 + slot.side)
		end
	end
	for _, slot in sides(take(s, 2.8, 2.8)) do
		Props.globe(parent, at(slot, 2.4))
		paintingAbove(parent, slot, room.id)
	end
	fill(parent, s)
	lights(parent, room)
	sconces(parent, room, 2)
end

D.map_room = function(parent, room, ctx)
	occupy(room, center(room), 9, 6)
	Props.mapTable(parent, center(room))
	local s = slots(room)
	fireplace(parent, room, s)
	for _ = 1, 2 do
		for _, slot in sides(take(s, 6.8, 2.4)) do
			Props.bookshelf(parent, at(slot, 2), 6, 12, room.id * 10 + slot.side)
		end
	end
	for _, slot in sides(take(s, 2.8, 2.8)) do
		Props.globe(parent, at(slot, 2.4))
	end
	fill(parent, s)
	lights(parent, room, true)
	sconces(parent, room, 2)
	local _ = ctx
end

D.observatory = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st, 12, 12)
	occupy(room, center(room), 5, 7)
	Props.telescope(parent, center(room))
	local s = slots(room)
	for _, slot in sides(take(s, 2.8, 2.8)) do
		Props.globe(parent, at(slot, 2.4))
		paintingAbove(parent, slot, 2)
	end
	for _, slot in sides(take(s, 6.8, 2.4)) do
		Props.bookshelf(parent, at(slot, 2), 6, 12, room.id + slot.side)
	end
	for _, slot in sides(take(s, 5.4, 3)) do
		Props.dresser(parent, at(slot, 1.8), 5, room.id)
	end
	fill(parent, s)
	lights(parent, room)
	sconces(parent, room, 2)
	local _ = ctx
end

D.sitting = function(parent, room, ctx, withArmor)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st, 16, 14)
	sittingArea(parent, room, rgb(120, 90, 50))
	local s = slots(room)
	fireplace(parent, room, s)
	for _, slot in sides(take(s, 5.6, 2.2)) do
		Props.dresser(parent, at(slot, 1.8), 5, room.id)
		paintingAbove(parent, slot, room.id)
	end
	for _, slot in sides(take(s, 6.8, 2.4)) do
		Props.bookshelf(parent, at(slot, 2), 6, 12, room.id + slot.side)
	end
	for _, slot in sides(take(s, 2.6, 2)) do
		Props.grandfatherClock(parent, at(slot, 1.6))
	end
	if withArmor then
		for _, slot in sides(take(s, 3, 2.8)) do
			Props.armor(parent, at(slot, 2.6))
		end
	end
	fill(parent, s)
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
	fireplace(parent, room, s)
	for _, slot in sides(take(s, 5.6, 2.4)) do
		Props.dresser(parent, at(slot, 1.8), 5, room.id)
		paintingAbove(parent, slot, room.id)
	end
	for _, slot in sides(take(s, 6.8, 2.4)) do
		Props.bookshelf(parent, at(slot, 2), 6, 12, room.id + slot.side)
	end
	fill(parent, s)
	lights(parent, room, true)
	sconces(parent, room, 4)
	local _ = ctx
end

D.reading = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st, 12, 12)
	local c = center(room)
	occupy(room, c, 10, 5)
	Props.armchair(parent, c * CFrame.new(-3, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), rgb(40, 70, 50))
	Props.armchair(parent, c * CFrame.new(3, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), rgb(40, 70, 50))
	Props.coffeeTable(parent, c * CFrame.Angles(0, math.pi / 2, 0))
	local book = P(parent, "BookProp", Vector3.new(1.2, 0.3, 0.9), c * CFrame.new(0.8, 1.86, 0.4), rgb(40, 60, 110), MAT.Leather)
	ctx.prompt(book, "book")
	local s = slots(room)
	for _ = 1, 4 do
		for _, slot in sides(take(s, 6.8, 2.4)) do
			Props.bookshelf(parent, at(slot, 2), 6, 13, room.id * 7 + slot.side)
		end
	end
	fill(parent, s)
	lights(parent, room)
	sconces(parent, room, 2)
end

D.trophy = function(parent, room, ctx)
	local s = slots(room)
	local k = 0
	for _ = 1, 4 do
		k += 1
		local pair = take(s, 7.2, 2.8)
		for _, slot in sides(pair) do
			if k % 2 == 0 then
				Props.weaponRack(parent, at(slot, 1.8))
			else
				Props.armor(parent, at(slot, 2.6))
			end
			Props.banner(parent, onWall(slot, 15), 7, if k % 2 == 0 then rgb(30, 46, 110) else rgb(130, 20, 28))
		end
	end
	occupy(room, center(room), 5, 4)
	Props.chest(parent, center(room), true)
	fill(parent, s)
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
		for _, off in { -PAIR_OFF, PAIR_OFF } do
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
	for _, slot in sides(take(s, 6, 9)) do
		local _, blanket = Props.bed(parent, at(slot, 8.5), Color3.fromHSV(0.6, 0.3, 0.85))
		ctx.prompt(blanket, "rest", 1.5)
	end
	for _, slot in sides(take(s, 5.2, 2.8)) do
		Props.wardrobe(parent, at(slot, 2.4), rgb(200, 190, 170))
	end
	for _, slot in sides(take(s, 3.8, 2.4)) do
		Props.chest(parent, at(slot, 2))
		paintingAbove(parent, slot, 4)
	end
	-- кубики в центре
	local c = center(room)
	occupy(room, c, 4, 3)
	for k = 0, 5 do
		Props.P(parent, "ToyBlock", Vector3.new(1, 1, 1), c * CFrame.new(-1.5 + (k % 3), 0.5 + math.floor(k / 3), 0), Color3.fromHSV(k / 6, 0.7, 0.9), MAT.SmoothPlastic)
	end
	fill(parent, s)
	lights(parent, room)
	sconces(parent, room, 2)
end

D.wardrobe = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st, 10, 10)
	local s = slots(room)
	for _ = 1, 3 do
		for _, slot in sides(take(s, 5.6, 2.8)) do
			Props.wardrobe(parent, at(slot, 2.4), Color3.fromHSV(0.07, 0.45, 0.38))
		end
	end
	for _, slot in sides(take(s, 5.6, 2.2)) do
		Props.dresser(parent, at(slot, 1.8), 5, 2)
	end
	-- вешалка с платьями
	local c = center(room)
	occupy(room, c, 9, 12)
	P(parent, "Rail", Vector3.new(8, 0.25, 0.25), c * CFrame.new(0, 6.5, 1), Props.GOLD, MAT.Metal)
	for _, x in { -3.8, 3.8 } do
		P(parent, "RailPost", Vector3.new(0.3, 6.5, 0.3), c * CFrame.new(x, 3.25, 1), Props.GOLD, MAT.Metal)
	end
	for k = 0, 5 do
		P(parent, "Gown", Vector3.new(0.6, 4, 2), c * CFrame.new(-3 + k * 1.2, 4.2, 1), Color3.fromHSV(k * 0.15, 0.5, 0.6), MAT.SmoothPlastic)
	end
	local chest = Props.chest(parent, c * CFrame.new(0, 0, -4))
	ctx.prompt(chest:FindFirstChild("Box"), "shop", 0, 10)
	fill(parent, s)
	lights(parent, room, true)
	sconces(parent, room, 2)
end

D.bath = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st, 8, 6)
	local s = slots(room)
	-- ванна вдоль середины глухой стены
	local spot = middle(room, s, 7.2, 4)
	if spot then
		Props.bathtub(parent, spot.cf * CFrame.new(0, 0, -2.2) * CFrame.Angles(0, math.pi / 2, 0))
	else
		for _, slot in sides(take(s, 6.8, 4)) do
			Props.bathtub(parent, at(slot, 3.6, 0, 0, 0, math.pi / 2))
		end
	end
	for _, slot in sides(take(s, 3.8, 2.2)) do
		Props.washstand(parent, at(slot, 1.8))
	end
	for _, slot in sides(take(s, 5.6, 2.2)) do
		local m = Props.dresser(parent, at(slot, 1.8), 5, 2)
		for k = 0, 2 do
			P(m, "Towel", Vector3.new(1.4, 0.3, 1.2), at(slot, 1.8, -1.6 + k * 1.6, 3.5, 0), rgb(240, 240, 236), MAT.SmoothPlastic)
		end
	end
	fill(parent, s)
	lights(parent, room)
	sconces(parent, room, 2)
	local _ = ctx
end

D.kitchen = function(parent, room, ctx)
	local s = slots(room)
	local c = center(room)
	-- печи посередине двух глухих стен
	for _ = 1, 2 do
		local spot = middle(room, s, 8, 4)
		if spot then
			local _, mouth = Props.stove(parent, spot.cf * CFrame.new(0, 0, -1.9))
			ctx.prompt(mouth, "cook", 2)
		end
	end
	occupy(room, c, 22, 6)
	local _, top = Props.prepTable(parent, c * CFrame.new(-6, 0, 0))
	local bread = P(parent, "BreadLoaves", Vector3.new(2.2, 0.8, 1.2), c * CFrame.new(-6, top + 0.4, 0), rgb(196, 140, 70), MAT.Sand)
	ctx.prompt(bread, "bread")
	Props.prepTable(parent, c * CFrame.new(6, 0, 0))
	local basket = C(parent, "AppleBasket", 0.9, 1.8, c * CFrame.new(6, top + 0.45, 0), rgb(150, 110, 60), MAT.Wood)
	for k = 0, 4 do
		Props.S(parent, "Apple", 0.55, c * CFrame.new(5.6 + (k % 3) * 0.4, top + 1, -0.3 + math.floor(k / 3) * 0.5), rgb(190, 40, 40), MAT.SmoothPlastic, { CanCollide = false })
	end
	ctx.prompt(basket, "apple")
	for _, slot in sides(take(s, 5.6, 2.4)) do
		local m = Props.dresser(parent, at(slot, 1.8), 5, 1)
		ctx.prompt(m:FindFirstChild("Body"), "spoon")
		Props.panRack(parent, onWall(slot, 0))
	end
	for _, slot in sides(take(s, 3.6, 3.6)) do
		local m = Props.washtub(parent, at(slot, 3.2))
		ctx.prompt(m:FindFirstChild("Tub"), "water")
	end
	for _, slot in sides(take(s, 6.2, 3.2)) do
		Props.barrel(parent, at(slot, 2.8, -1.5))
		Props.barrel(parent, at(slot, 2.8, 1.5))
		Props.shelfJars(parent, onWall(slot, 0), 6)
	end
	for _, slot in sides(take(s, 5, 2.4)) do
		Props.sack(parent, at(slot, 2, -1.2))
		Props.sack(parent, at(slot, 2, 1.2))
		Props.shelfJars(parent, onWall(slot, 0), 5)
	end
	fill(parent, s, "stone")
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
	fireplace(parent, room, s)
	for _, slot in sides(take(s, 6.6, 2.2)) do
		Props.dresser(parent, at(slot, 1.8), 6, room.id)
		paintingAbove(parent, slot, room.id)
	end
	for _ = 1, 2 do
		for _, slot in sides(take(s, 3, 2.8)) do
			Props.armor(parent, at(slot, 2.6))
			Props.banner(parent, onWall(slot, 14), 7, rgb(130, 20, 28))
		end
	end
	fill(parent, s)
	lights(parent, room, true)
	sconces(parent, room, 4)
	local _ = ctx
end
D.royal_dining = D.dining

D.servants = function(parent, room, ctx)
	local s = slots(room)
	for _ = 1, 2 do
		for _, slot in sides(take(s, 6, 9)) do
			local _, blanket = Props.bed(parent, at(slot, 8.5), rgb(120, 110, 90))
			ctx.prompt(blanket, "rest", 1.5)
		end
	end
	for _, slot in sides(take(s, 6.8, 2.2)) do
		local m = Props.weaponRack(parent, at(slot, 1.8))
		for _, d in m:GetChildren() do
			if d.Name == "Blade" then
				d.Color = rgb(150, 110, 60)
				d.Material = MAT.Wood
			end
		end
		ctx.prompt(m:FindFirstChild("Back"), "broom")
	end
	for _, slot in sides(take(s, 3.8, 2.4)) do
		Props.chest(parent, at(slot, 2))
	end
	local c = center(room)
	occupy(room, c, 7, 7)
	Props.table(parent, c, 6, 3)
	Props.chair(parent, c * CFrame.new(-2, 0, -2.4) * CFrame.Angles(0, math.pi, 0))
	Props.chair(parent, c * CFrame.new(2, 0, -2.4) * CFrame.Angles(0, math.pi, 0))
	Props.chair(parent, c * CFrame.new(-2, 0, 2.4))
	Props.chair(parent, c * CFrame.new(2, 0, 2.4))
	Props.candle(parent, (c * CFrame.new(0, 3.35, 0)).Position)
	fill(parent, s)
	lights(parent, room)
end

D.barracks = function(parent, room, ctx)
	occupy(room, center(room), 9, 6)
	Props.mapTable(parent, center(room))
	local s = slots(room)
	for _, slot in sides(take(s, 6.8, 2.2)) do
		local m = Props.weaponRack(parent, at(slot, 1.8))
		ctx.prompt(m:FindFirstChild("Back"), "sword")
	end
	for _, slot in sides(take(s, 3.8, 2.4)) do
		local m = Props.chest(parent, at(slot, 2))
		ctx.prompt(m:FindFirstChild("Box"), "cuffs")
		P(parent, "ShacklesHook", Vector3.new(2, 0.3, 0.3), onWall(slot, 6), Props.IRON, MAT.Metal)
	end
	for _ = 1, 4 do
		for _, slot in sides(take(s, 3.8, 7.6)) do
			Props.bunk(parent, at(slot, 7.2))
		end
	end
	for _ = 1, 2 do
		for _, slot in sides(take(s, 3, 2.8)) do
			Props.armor(parent, at(slot, 2.6))
			Props.banner(parent, onWall(slot, 15), 6)
		end
	end
	fill(parent, s)
	lights(parent, room)
	sconces(parent, room, 2)
end

D.training = function(parent, room, ctx)
	local c = center(room)
	P(parent, "Mat", Vector3.new(18, 0.2, 18), c * CFrame.new(0, 0.1, 0), rgb(110, 96, 70), MAT.Leather)
	occupy(room, c, 16, 6)
	ctx.points.dummies = ctx.points.dummies or {}
	table.insert(ctx.points.dummies, c * CFrame.new(-5, 3, 0))
	table.insert(ctx.points.dummies, c * CFrame.new(5, 3, 0))
	local s = slots(room)
	for _, slot in sides(take(s, 7.2, 2.2)) do
		local m = Props.weaponRack(parent, at(slot, 1.8))
		ctx.prompt(m:FindFirstChild("Back"), "sword")
	end
	for _ = 1, 2 do
		for _, slot in sides(take(s, 6.4, 2.2)) do
			-- мишень для стрельбы
			local cf = at(slot, 1)
			P(parent, "TargetStand", Vector3.new(0.4, 5, 0.4), cf * CFrame.new(0, 2.5, 0.3), Props.WOOD, MAT.Wood)
			for r = 0, 3 do
				C(parent, "Target", 0.2 + r * 0.02, 4 - r, cf * CFrame.new(0, 5, -r * 0.06) * CFrame.Angles(math.pi / 2, 0, 0), if r % 2 == 0 then rgb(230, 225, 210) else rgb(170, 30, 30), MAT.SmoothPlastic)
			end
		end
	end
	for _ = 1, 2 do
		for _, slot in sides(take(s, 6.4, 2.2)) do
			Props.bench(parent, at(slot, 1.8), 6)
		end
	end
	fill(parent, s)
	lights(parent, room)
end

D.chapel = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	local c = center(room)
	local w, d = size(room)
	local s = slots(room)
	local spot = middle(room, s, 10, 6)
	local forward = if spot then spot.seg.inward else Vector3.new(0, 0, -1)
	if spot then
		Props.altar(parent, spot.cf * CFrame.new(0, 0, -3))
		Props.stainedGlass(parent, spot.cf * CFrame.new(0, 10, -0.3), 6, 8)
	end
	local base = CFrame.lookAt(c.Position, c.Position + forward)
	Props.runner(parent, base, 3, math.min(w, d) - 6, st.rug)
	local rows = math.floor((math.min(w, d) - 14) / 3.6)
	occupy(room, base * CFrame.new(0, 0, -2 + (rows - 1) * 1.8), 18, rows * 3.6)
	for r = 0, rows - 1 do
		for _, sx in { -1, 1 } do
			Props.pew(parent, base * CFrame.new(sx * 5.5, 0, -2 + r * 3.6), 7)
		end
	end
	for _ = 1, 4 do
		for _, slot in sides(take(s, 1.6, 1.6)) do
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
	for _, slot in sides(take(s, 5.2, 2.8)) do
		Props.wardrobe(parent, at(slot, 2.4), rgb(110, 80, 50))
	end
	for _ = 1, 2 do
		for _, slot in sides(take(s, 6.2, 3)) do
			Props.shelfJars(parent, onWall(slot, -2), 6)
			Props.crate(parent, at(slot, 2.2, -1.6), 2.2)
			Props.crate(parent, at(slot, 2.2, 1.6), 2.2)
		end
	end
	fill(parent, s)
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
	for _ = 1, 4 do
		for _, slot in sides(take(s, 3.6, 2.8)) do
			local m = Props.slotMachine(parent, at(slot, 2.4))
			ctx.prompt(m:FindFirstChild("Cabinet"), "slots")
		end
	end
	fill(parent, s)
	lights(parent, room, true)
	sconces(parent, room, 2)
end

D.treasury = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st)
	local c = center(room)
	occupy(room, c, 16, 16)
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2
		local p = c * CFrame.new(math.cos(a) * 6, 0, math.sin(a) * 6)
		P(parent, "Pedestal", Vector3.new(2, 3.4, 2), p * CFrame.new(0, 1.7, 0), rgb(220, 214, 204), MAT.Marble)
		if k % 2 == 0 then
			C(parent, "CrownBand", 0.6, 1.4, p * CFrame.new(0, 3.7, 0), Props.GOLD, MAT.Metal)
			Props.S(parent, "Jewel", 0.4, p * CFrame.new(0, 4.2, 0), rgb(200, 30, 50), MAT.Neon)
		else
			for g = 0, 3 do
				P(parent, "GoldBar", Vector3.new(1, 0.4, 0.5), p * CFrame.new(0, 3.6 + g * 0.4, (g % 2) * 0.2 - 0.1), Props.GOLD, MAT.Metal)
			end
		end
	end
	Props.chest(parent, c, true)
	local s = slots(room)
	for _ = 1, 3 do
		for _, slot in sides(take(s, 3.8, 2.4)) do
			Props.chest(parent, at(slot, 2), true)
		end
	end
	for _ = 1, 2 do
		for _, slot in sides(take(s, 3, 2.8)) do
			Props.armor(parent, at(slot, 2.6))
		end
	end
	fill(parent, s)
	lights(parent, room, true)
	local _ = ctx
end

D.council = function(parent, room, ctx)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st)
	local c = center(room)
	occupy(room, c, 22, 22)
	C(parent, "RoundTable", 0.5, 16, c * CFrame.new(0, 3.2, 0), Props.WOOD, MAT.Wood)
	C(parent, "TableBase", 3, 3, c * CFrame.new(0, 1.5, 0), Props.WOOD_DARK, MAT.Wood)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		local cp = (c * CFrame.new(math.cos(a) * 9.5, 0, math.sin(a) * 9.5)).Position
		Props.chair(parent, CFrame.lookAt(cp, Vector3.new(c.Position.X, cp.Y, c.Position.Z)), rgb(40, 50, 90))
	end
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		Props.candle(parent, (c * CFrame.new(math.cos(a) * 4, 3.45, math.sin(a) * 4)).Position)
	end
	local s = slots(room)
	fireplace(parent, room, s)
	for _ = 1, 2 do
		for _, slot in sides(take(s, 6.8, 2.4)) do
			Props.bookshelf(parent, at(slot, 2), 6, 10, room.id + slot.side)
		end
	end
	for _ = 1, 2 do
		for _, slot in sides(take(s, 3, 2.8)) do
			Props.armor(parent, at(slot, 2.6))
			Props.banner(parent, onWall(slot, 15), 8, rgb(30, 46, 110))
		end
	end
	fill(parent, s)
	lights(parent, room, true)
	local _ = ctx
end

local function royal(parent, room, ctx, color, isKing)
	local st = Rooms.style(room.kind)
	rugCenter(parent, room, st)
	local s = slots(room)
	sittingArea(parent, room, color)
	bedOnWall(parent, room, s, ctx, color, true)
	fireplace(parent, room, s)
	-- подставка со скипетром (у короля) или туалетный столик с зеркалом (у королевы) —
	-- посередине ещё одной глухой стены, если она есть
	local spot = middle(room, s, 3, 3)
	if spot then
		local cf = spot.cf * CFrame.new(0, 0, -1.8)
		if isKing then
			local stand = P(parent, "ScepterStand", Vector3.new(1.6, 4, 1.6), cf * CFrame.new(0, 2, 0), rgb(220, 214, 204), MAT.Marble)
			P(parent, "Scepter", Vector3.new(0.3, 3, 0.3), cf * CFrame.new(0, 5.5, 0), Props.GOLD, MAT.Metal, { CanCollide = false })
			Props.S(parent, "Gem", 0.6, cf * CFrame.new(0, 7.2, 0), rgb(200, 30, 50), MAT.Neon, { CanCollide = false })
			ctx.prompt(stand, "scepter")
		else
			Props.dresser(parent, spot.cf * CFrame.new(0, 0, -1.25), 3, 7)
			P(parent, "Mirror", Vector3.new(2.4, 3.2, 0.15), spot.cf * CFrame.new(0, 6.2, -0.3), rgb(200, 210, 220), MAT.Glass, { Reflectance = 0.4 })
		end
	elseif isKing then
		local cf = center(room) * CFrame.new(0, 0, -9)
		occupy(room, cf, 2, 2)
		local stand = P(parent, "ScepterStand", Vector3.new(1.6, 4, 1.6), cf * CFrame.new(0, 2, 0), rgb(220, 214, 204), MAT.Marble)
		P(parent, "Scepter", Vector3.new(0.3, 3, 0.3), cf * CFrame.new(0, 5.5, 0), Props.GOLD, MAT.Metal, { CanCollide = false })
		Props.S(parent, "Gem", 0.6, cf * CFrame.new(0, 7.2, 0), rgb(200, 30, 50), MAT.Neon, { CanCollide = false })
		ctx.prompt(stand, "scepter")
	end
	for _, slot in sides(take(s, 5.2, 2.8)) do
		Props.wardrobe(parent, at(slot, 2.4), Props.WOOD_DARK)
	end
	for _, slot in sides(take(s, 6.6, 2.2)) do
		Props.dresser(parent, at(slot, 1.8), 6, 2)
		paintingAbove(parent, slot, room.id)
	end
	for _ = 1, 2 do
		for _, slot in sides(take(s, 3, 2.8)) do
			Props.armor(parent, at(slot, 2.6))
			Props.banner(parent, onWall(slot, 14), 8, color)
		end
	end
	fill(parent, s)
	lights(parent, room, true)
	sconces(parent, room, 4)
end
D.king = function(parent, room, ctx)
	royal(parent, room, ctx, rgb(140, 18, 28), true)
end
D.queen = function(parent, room, ctx)
	royal(parent, room, ctx, rgb(100, 40, 120), false)
end

D.landing = function(parent, room, ctx)
	-- в клетке есть проём лестницы у восточной стены: обставляем только западную стену
	for _, seg in room.segs do
		if seg.inward.X > 0.5 then
			local cf = CFrame.lookAt(seg.pos, seg.pos + seg.inward)
			Props.bench(parent, cf * CFrame.new(0, 0, -1.3), 7)
			Props.painting(parent, cf * CFrame.new(0, 8.5, -0.3), 7, 5, room.id)
			Props.plant(parent, cf * CFrame.new(-PAIR_OFF, 0, -1.4), true)
			Props.plant(parent, cf * CFrame.new(PAIR_OFF, 0, -1.4), true)
		end
	end
	lights(parent, room)
	local _ = ctx
end

D.storeroom = function(parent, room, ctx)
	local s = slots(room)
	local k = 0
	for _ = 1, 8 do
		k += 1
		local pair = take(s, 6.2, 3)
		if not pair then
			break
		end
		for _, slot in sides(pair) do
			if k % 3 == 0 then
				Props.barrel(parent, at(slot, 2.8, -1.5))
				Props.barrel(parent, at(slot, 2.8, 1.5))
			elseif k % 3 == 1 then
				Props.crate(parent, at(slot, 2.6, -1.45))
				Props.crate(parent, at(slot, 2.6, -1.45, 2.6), 2.2)
				Props.crate(parent, at(slot, 2.6, 1.45))
			else
				Props.sack(parent, at(slot, 2, -1.1))
				Props.sack(parent, at(slot, 2, 1.1))
				Props.shelfJars(parent, onWall(slot, 0), 6)
			end
		end
	end
	for _, c in room.cells do
		Props.ceilingLamp(parent, Vector3.new(c.x, room.y + room.h - 3.5, c.z), 3)
	end
	local _ = ctx
end
D.storage = D.storeroom

D.cellar = function(parent, room, ctx)
	local s = slots(room)
	for _ = 1, 10 do
		local pair = take(s, 5.4, 3.4)
		if not pair then
			break
		end
		for _, slot in sides(pair) do
			-- стеллаж с лежащими бочками в два яруса и бутылками сверху
			local cf = at(slot, 3)
			local rack = Props.model(parent, "WineRack")
			P(rack, "Shelf", Vector3.new(5, 0.4, 3), cf * CFrame.new(0, 3.2, 0), Props.WOOD_DARK, MAT.Wood)
			P(rack, "Top", Vector3.new(5, 0.4, 3), cf * CFrame.new(0, 6.6, 0), Props.WOOD_DARK, MAT.Wood)
			for _, x in { -2.3, 2.3 } do
				P(rack, "Post", Vector3.new(0.4, 6.8, 3), cf * CFrame.new(x, 3.4, 0), Props.WOOD_DARK, MAT.Wood)
			end
			Props.barrel(rack, cf * CFrame.new(0, -0.1, 0), true)
			Props.barrel(rack, cf * CFrame.new(0, 3.3, 0), true)
			for k = 0, 2 do
				C(rack, "Bottle", 1.1, 0.32, cf * CFrame.new(-1.5 + k * 1.5, 7.35, 0), rgb(40, 70, 40), MAT.Glass, { CanCollide = false })
			end
		end
	end
	local c = center(room)
	occupy(room, c, 7, 4)
	Props.table(parent, c, 6, 3)
	for k = 0, 4 do
		C(parent, "Bottle", 1.2, 0.35, c * CFrame.new(-2 + k, 4, 0), rgb(40, 70, 40), MAT.Glass)
	end
	for _, cell in room.cells do
		Props.ceilingLamp(parent, Vector3.new(cell.x, room.y + room.h - 3.5, cell.z), 3)
	end
	local _ = ctx
end

D.guardroom = function(parent, room, ctx)
	local c = center(room)
	occupy(room, c, 10, 5)
	Props.table(parent, c, 6, 4)
	for _, sx in { -1, 1 } do
		Props.chair(parent, c * CFrame.new(sx * 4, 0, 0) * CFrame.Angles(0, sx * math.pi / 2, 0))
	end
	Props.candle(parent, (c * CFrame.new(0, 3.35, 0)).Position)
	P(parent, "Keys", Vector3.new(0.8, 0.1, 0.5), c * CFrame.new(1, 3.4, 0.5), Props.GOLD, MAT.Metal)
	local s = slots(room)
	for _, slot in sides(take(s, 6.8, 2.2)) do
		local m = Props.weaponRack(parent, at(slot, 1.8))
		ctx.prompt(m:FindFirstChild("Back"), "sword")
	end
	for _, slot in sides(take(s, 3.8, 2.4)) do
		local m = Props.chest(parent, at(slot, 2))
		ctx.prompt(m:FindFirstChild("Box"), "cuffs")
	end
	fill(parent, s, "stone")
	for _, cell in room.cells do
		Props.ceilingLamp(parent, Vector3.new(cell.x, room.y + room.h - 3.5, cell.z), 3)
	end
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
		Props.chandelier(parent, Vector3.new(c.X + k * 26, room.y + room.h - 9, c.Z), 7, 9)
	end
	local s = slots(room)
	local k = 0
	for _ = 1, 8 do
		k += 1
		for _, slot in sides(take(s, 7.2, 3)) do
			if k % 2 == 0 then
				Props.armor(parent, at(slot, 2.6))
			else
				Props.plant(parent, at(slot, 1.8), true)
			end
			Props.banner(parent, onWall(slot, room.h - 4), 12, if k % 2 == 0 then rgb(30, 50, 110) else rgb(120, 22, 30))
		end
	end
	-- у входа по обе стороны: доски ролей (нажать — выбрать роль)
	for _, sx in { -1, 1 } do
		local bx = sx * 14
		local board = P(parent, "RoleBoard", Vector3.new(8, 6, 0.4), c * CFrame.new(bx, 5, -d / 2 + 9) * CFrame.Angles(0, math.pi, 0), Props.WOOD, MAT.WoodPlanks)
		for _, x in { -3.6, 3.6 } do
			P(parent, "BoardLeg", Vector3.new(0.4, 8, 0.4), c * CFrame.new(bx + x, 4, -d / 2 + 9), Props.WOOD_DARK, MAT.Wood)
		end
		for n = 0, 5 do
			P(parent, "Notice", Vector3.new(1.6, 2, 0.05), c * CFrame.new(bx - 2.4 + (n % 3) * 2.4, 5.8 - math.floor(n / 3) * 2.4, -d / 2 + 8.75), rgb(240, 230, 200), MAT.SmoothPlastic)
		end
		ctx.prompt(board, "roles", 0, 12)
		Props.grandfatherClock(parent, c * CFrame.new(sx * (w / 2 - 2.3), 0, d / 2 - 2.3) * CFrame.Angles(0, sx * math.pi * 0.75, 0))
	end
end

-- ---------------------------------------------------------------------------
-- Коридоры: каменные стены, дорожка, железные фонари, доспехи и гобелены.
-- Обе стены одной клетки обставлены одинаково — коридор симметричен

function Rooms.hallCell(parent, cell, room, ctx, nb)
	-- дорожка тянется к каждой соседней клетке коридора, на перекрёстках куски сходятся
	local pieces = 0
	for _, d in { { "px", 1, 0 }, { "nx", -1, 0 }, { "pz", 0, 1 }, { "nz", 0, -1 } } do
		if nb[d[1]] then
			pieces += 1
			local dir = Vector3.new(d[2], 0, d[3])
			local from = Vector3.new(cell.x, room.y, cell.z) - dir * 3
			local to = Vector3.new(cell.x, room.y, cell.z) + dir * 16
			local mid = (from + to) / 2
			local cf = CFrame.lookAt(mid, mid + dir) * CFrame.new(0, (if d[2] ~= 0 then 0.005 else 0.01), 0)
			Props.runner(parent, cf, 6, 19, Rooms.STYLE.hall.rug)
		end
	end
	if pieces == 0 then
		Props.runner(parent, CFrame.new(cell.x, room.y, cell.z), 6, 30, Rooms.STYLE.hall.rug)
	end
	-- фонарь в каждой клетке, светит каждый второй (меньше источников света)
	local lamp = Props.ceilingLamp(parent, Vector3.new(cell.x, room.y + room.h - 3.5, cell.z), 3)
	if (cell.i + cell.j) % 2 == 1 then
		for _, d in lamp:GetDescendants() do
			if d:IsA("PointLight") then
				d:Destroy()
			elseif d.Name == "Bulb" then
				d:SetAttribute("Interact", nil)
			end
		end
	end
	local _ = ctx
end

function Rooms.hallWalls(parent, room, seed)
	for _, seg in room.segs do
		-- клетка, к которой относится участок: у противоположных стен она одна и та же
		local cp = seg.pos + seg.inward * 15
		local ci, cj = math.floor(cp.X / 32 + 0.5), math.floor(cp.Z / 32 + 0.5)
		local k = (ci * 3 + cj * 5 + seed) % 4
		local base = CFrame.lookAt(seg.pos, seg.pos + seg.inward)
		-- середина участка: гобелен, если там нет двери
		if not seg.opening then
			Props.banner(parent, base * CFrame.new(0, 14, -0.25), 9, if k % 2 == 0 then rgb(120, 22, 30) else rgb(30, 46, 110))
		end
		for _, sx in { -1, 1 } do
			local cf = base * CFrame.new(sx * PAIR_OFF, 0, 0)
			if k == 0 then
				Props.armor(parent, cf * CFrame.new(0, 0, -1.7))
			elseif k == 1 then
				Props.plant(parent, cf * CFrame.new(0, 0, -1.2), true)
				Props.painting(parent, cf * CFrame.new(0, 8.5, -0.3), 5, 4, ci + cj)
			elseif k == 2 then
				-- каменная консоль с вазой
				P(parent, "Console", Vector3.new(4, 0.4, 1.4), cf * CFrame.new(0, 3, -1), rgb(170, 162, 150), MAT.Limestone)
				P(parent, "ConsoleBase", Vector3.new(3, 2.8, 0.9), cf * CFrame.new(0, 1.4, -0.9), rgb(150, 142, 130), MAT.Limestone)
				C(parent, "Vase", 1.4, 0.8, cf * CFrame.new(0, 3.9, -1), Color3.fromHSV(((ci + cj) * 0.17) % 1, 0.45, 0.6), MAT.Glass)
				Props.painting(parent, cf * CFrame.new(0, 8.5, -0.3), 5, 4, ci + cj + 1)
			else
				Props.bench(parent, cf * CFrame.new(0, 0, -1.2), 5)
				Props.painting(parent, cf * CFrame.new(0, 8, -0.3), 4, 6, ci + cj + 2)
			end
			-- факел-бра у угла участка, без собственного света
			local sp = seg.pos + seg.tangent * (sx * 13) + Vector3.new(0, 8.5, 0)
			Props.sconce(parent, CFrame.lookAt(sp, sp + seg.inward), false)
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
