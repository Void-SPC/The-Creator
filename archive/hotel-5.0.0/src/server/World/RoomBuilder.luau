--!nonstrict
-- Сборка комнаты по описанию из RoomPlan. Кадр комнаты: вход в origin, комната уходит
-- вперёд (-Z). Стены: каркас толщиной 1 по границе, поверх — обои (0.1) и панели
-- (0.12) со стороны комнаты, поэтому соседние комнаты не мерцают на общей стене.
-- Мебель расставлена по планировкам; проходы ко всем возможным дверям свободны

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local M = require(Shared.Materials)
local Plan = require(Shared.RoomPlan)
local Props = require(script.Parent.Props)

local P, nc, rgb = Props.P, Props.nc, Props.rgb

local Builder = {}

local F = 0.9 -- от середины стены до места мебели (панели и поручень заканчиваются на 0.84)
local SKIN = 0.1
local PANEL = 0.12
local DOOR_HOLE = { w = 5, h = 9 }

-- ---------------------------------------------------------------------------
-- оформление по глубине

local PAPER = {
	hotel = { rgb(176, 156, 120), rgb(104, 46, 44), rgb(58, 84, 80), rgb(146, 116, 66), rgb(150, 110, 104), rgb(92, 92, 70) },
	faded = { rgb(132, 128, 118), rgb(98, 106, 112), rgb(120, 108, 96), rgb(108, 116, 104) },
	decay = { rgb(74, 68, 58), rgb(66, 58, 52), rgb(80, 76, 66) },
	deep = { rgb(70, 72, 74), rgb(58, 60, 62) },
}
local CARPET = {
	hotel = { rgb(108, 30, 30), rgb(40, 64, 48), rgb(82, 58, 40), rgb(38, 44, 72) },
	faded = { rgb(92, 70, 66), rgb(70, 76, 72), rgb(84, 80, 74) },
	decay = { rgb(56, 50, 44), rgb(48, 44, 40) },
	deep = { rgb(50, 50, 52) },
}

function Builder.style(d, rand)
	local zone = d.zone or "hotel"
	local papers, carpets = PAPER[zone], CARPET[zone]
	local st = {
		paper = papers[math.floor(rand() * #papers) + 1],
		paperMat = M.Plaster,
		panel = if zone == "hotel" then Props.WOOD_DARK elseif zone == "faded" then rgb(96, 90, 82) else rgb(60, 56, 50),
		panelMat = M.Wood,
		floor = carpets[math.floor(rand() * #carpets) + 1],
		floorMat = M.Carpet,
		ceil = if zone == "hotel" then rgb(190, 182, 166) elseif zone == "faded" then rgb(150, 146, 138) else rgb(96, 94, 90),
		ceilMat = M.SmoothPlastic,
		struct = rgb(110, 104, 96),
		wainscot = true,
	}
	if zone == "decay" or zone == "deep" then
		st.paperMat = if rand() < 0.5 then M.Concrete else M.Plaster
		st.floorMat = if rand() < 0.5 then M.Concrete else M.WoodPlanks
		st.floor = rgb(70, 64, 58)
	end
	local k = d.kind
	if k == "bathroom" or k == "kitchen" or k == "laundry" then
		st.paper = if zone == "hotel" then rgb(206, 206, 196) else rgb(150, 154, 146)
		st.paperMat = M.CeramicTiles
		st.floor = rgb(190, 188, 180):Lerp(rgb(60, 60, 60), if zone == "hotel" then 0 else 0.4)
		st.floorMat = M.CeramicTiles
		st.wainscot = false
	elseif k == "library" or k == "office" then
		st.paper = Props.WOOD:Lerp(rgb(0, 0, 0), if zone == "hotel" then 0.2 else 0.5)
		st.paperMat = M.WoodPlanks
		st.floor = rgb(84, 58, 40)
		st.floorMat = M.WoodPlanks
	elseif k == "storage" or k == "crawl" then
		st.paper = rgb(96, 94, 90)
		st.paperMat = M.Concrete
		st.floor = rgb(80, 80, 78)
		st.floorMat = M.Concrete
		st.wainscot = false
	elseif k == "gallery" or k == "pillarhall" then
		st.floorMat = M.Marble
		st.floor = rgb(170, 164, 154):Lerp(rgb(40, 40, 40), if zone == "hotel" then 0 else 0.45)
	end
	if k == "crawl" then
		st.paper = rgb(100, 102, 104)
		st.paperMat = M.DiamondPlate
		st.ceil = rgb(80, 80, 82)
		st.ceilMat = M.Metal
	end
	return st
end

-- ---------------------------------------------------------------------------
-- каркас, обои, полы, потолок

local function at(origin: CFrame, x: number, y: number, z: number)
	return origin * CFrame.new(x, y, z)
end
Builder.at = at

-- высота пола в точке z (для лестниц)
local function floorAt(d, z: number): number
	if d.dy == 0 then
		return 0
	end
	if z > -12 then
		return 0
	elseif z < -28 then
		return d.dy
	end
	return d.dy * (-12 - z) / 16
end
Builder.floorAt = floorAt

-- обои и панели на внутренней стороне стены. cf — середина стены (каркаса),
-- LookVector — в комнату
-- lens = { обои, панели, поручень }: у дальней и входной стены слои короче на толщину
-- слоёв боковых стен, поэтому в углах ничего не налезает
local function dress(m, cf: CFrame, lens, y0: number, height: number, holes, st)
	local skinCF = cf * CFrame.new(0, 0, -(0.5 + SKIN / 2))
	Props.wall(m, skinCF, lens[1], y0, height, SKIN, holes, st.paper, st.paperMat, "Paper")
	if st.wainscot then
		local pcf = cf * CFrame.new(0, 0, -(0.5 + SKIN + PANEL / 2))
		Props.wall(m, pcf, lens[2], y0, 3.4, PANEL, holes, st.panel, st.panelMat, "Panel")
		local rcf = cf * CFrame.new(0, 0, -(0.5 + SKIN + PANEL + 0.06))
		Props.wall(m, rcf, lens[3], y0 + 3.4, 0.25, 0.12, holes, st.panel:Lerp(rgb(0, 0, 0), 0.2), M.Wood, "Rail")
	else
		local bcf = cf * CFrame.new(0, 0, -(0.5 + SKIN + 0.06))
		Props.wall(m, bcf, lens[2], y0, 0.5, 0.12, holes, rgb(60, 56, 52), M.Wood, "Baseboard")
	end
end

-- Каркас, обои и пол/потолок. Возвращает кадр выхода и данные для соседей
local function shell(m, d, origin: CFrame, st, prevWall)
	local w, l, h = d.w, d.l, d.h
	local ybase = math.min(0, d.dy)
	local top = math.max(0, d.dy) + h
	local H = top - ybase
	-- пол (у лестниц — нижняя площадка, пандус и верхняя площадка)
	if d.dy == 0 then
		P(m, "Floor", Vector3.new(w, 1, l), at(origin, 0, -0.5, -l / 2), st.floor, st.floorMat)
	else
		-- площадки не заходят под стены с проёмами (там верх стены служит порогом)
		local z0 = if d.dy < 0 then -0.5 else 0
		P(m, "Floor", Vector3.new(w, 1, 12 + z0), at(origin, 0, -0.5, (z0 - 12) / 2), st.floor, st.floorMat)
		local z1 = if d.dy > 0 then -l + 0.5 else -l
		P(m, "Floor", Vector3.new(w, 1, -28 - z1), at(origin, 0, d.dy - 0.5, (-28 + z1) / 2), st.floor, st.floorMat)
		-- невидимый пандус (по нему идут без прыжков) и видимые ступени
		local rise = d.dy
		local len = math.sqrt(16 * 16 + rise * rise)
		local ang = math.atan2(rise, 16)
		local ramp = P(m, "Ramp", Vector3.new(w - 2, 0.6, len), at(origin, 0, rise / 2 - 0.3, -20) * CFrame.Angles(ang, 0, 0), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CastShadow = false })
		local _ = ramp
		local steps = 16
		local bottom = math.min(0, rise)
		for k = 0, steps - 1 do
			local z0 = -12 - k
			local topY = rise * (k + 1) / steps
			local sh = topY - bottom
			if rise < 0 then
				-- вниз: ступень k стоит на уровне следующей ступени
				topY = rise * k / steps
				sh = topY - bottom
			end
			if sh > 0.05 then
				P(m, "Step", Vector3.new(w - 1.6, sh, 1), at(origin, 0, bottom + sh / 2 - 0.001, z0 - 0.5), st.floor:Lerp(rgb(0, 0, 0), 0.15), st.floorMat, nc())
			end
		end
		-- перила вдоль ступеней
		for _, sx in { -1, 1 } do
			local a = at(origin, sx * (w / 2 - F - 0.4), 3.2, -12).Position
			local b = at(origin, sx * (w / 2 - F - 0.4), d.dy + 3.2, -28).Position
			Props.rod(m, "Handrail", a, b, 0.25, Props.WOOD_DARK, M.Wood, nc())
		end
	end
	P(m, "Ceiling", Vector3.new(w, 1, l), at(origin, 0, top + 0.5, -l / 2), st.ceil, st.ceilMat)
	-- проёмы: настоящий выход, ложные двери, окна
	local exits = { d.exit }
	for _, e in d.decoys do
		table.insert(exits, e)
	end
	local front, sides = {}, { [-1] = {}, [1] = {} }
	for _, e in exits do
		local hw, hh = DOOR_HOLE.w, DOOR_HOLE.h
		if e == d.exit and d.exitHole then
			hw, hh = d.exitHole.w, d.exitHole.h
		end
		local hole = { w = hw, y = e.y or 0, h = (e.y or 0) + hh }
		if e.turn == 0 then
			hole.x = e.x
			table.insert(front, hole)
		else
			-- вдоль боковой стены: x стены = -z комнаты (левая) или z (правая)
			hole.zRoom = e.z
			table.insert(sides[e.turn], hole)
		end
	end
	-- окна: в свободных местах боковых стен, которые задаёт планировка
	local windows = {}
	if d.windows and d.windowZ then
		for _, wz in d.windowZ do
			for _, side in { -1, 1 } do
				local free = true
				for _, h in sides[side] do
					if math.abs(h.zRoom - wz) < 6 then
						free = false
					end
				end
				if free then
					local y = floorAt(d, wz)
					table.insert(sides[side], { zRoom = wz, w = Props.WINDOW.w, y = y + Props.WINDOW.y, h = y + Props.WINDOW.y + Props.WINDOW.h, window = true })
					table.insert(windows, { side = side, z = wz, y = y + Props.WINDOW.y + Props.WINDOW.h / 2 })
				end
			end
		end
	end
	-- дальняя стена (углы перекрывает она)
	local fcf = at(origin, 0, 0, -l) * CFrame.Angles(0, math.pi, 0)
	local fh = {}
	for _, h in front do
		table.insert(fh, { x = -h.x, w = h.w, y = h.y, h = h.h })
	end
	Props.wall(m, fcf, w + 1, ybase, H, 1, fh, st.struct, M.Concrete, "Struct")
	-- обои дальней стены начинаются от её пола (у лестниц он выше или ниже входа)
	dress(m, fcf, { w - 1.2, w - 1.44, w - 1.68 }, d.dy, top - d.dy, fh, st)
	-- боковые стены
	for _, side in { -1, 1 } do
		local cf = at(origin, side * w / 2, 0, -l / 2) * CFrame.Angles(0, if side < 0 then -math.pi / 2 else math.pi / 2, 0)
		local hs = {}
		for _, h in sides[side] do
			-- ось стены: у левой (смотрит в +X) локальный x = z комнаты + l/2 со знаком
			local x = if side < 0 then (h.zRoom + l / 2) else -(h.zRoom + l / 2)
			table.insert(hs, { x = x, w = h.w, y = h.y, h = h.h })
		end
		Props.wall(m, cf, l - 1, ybase, H, 1, hs, st.struct, M.Concrete, "Struct")
		dress(m, cf, { l - 1, l - 1.2, l - 1.44 }, ybase, H, hs, st)
	end
	-- стена входа: только там, где нет стены прошлой комнаты, и выше неё
	local bcf = at(origin, 0, 0, 0)
	local entrance = if d.kind == "start" then {} else { { x = 0, w = DOOR_HOLE.w, y = 0, h = DOOR_HOLE.h } }
	if prevWall then
		local c0, c1, ctop, cbot = prevWall.x0, prevWall.x1, prevWall.top, prevWall.bottom
		local half = w / 2 + 0.5
		-- слева и справа от общей части
		if c0 > -half then
			local len = c0 + half
			Props.wall(m, bcf * CFrame.new(-half + len / 2, 0, 0), len, ybase, H, 1, {}, st.struct, M.Concrete, "Struct")
		end
		if c1 < half then
			local len = half - c1
			Props.wall(m, bcf * CFrame.new(c1 + len / 2, 0, 0), len, ybase, H, 1, {}, st.struct, M.Concrete, "Struct")
		end
		local mid0, mid1 = math.max(c0, -half), math.min(c1, half)
		if mid1 > mid0 then
			if top > ctop + 0.05 then
				Props.wall(m, bcf * CFrame.new((mid0 + mid1) / 2, 0, 0), mid1 - mid0, ctop, top - ctop, 1, {}, st.struct, M.Concrete, "Struct")
			end
			if ybase < cbot - 0.05 then
				Props.wall(m, bcf * CFrame.new((mid0 + mid1) / 2, 0, 0), mid1 - mid0, ybase, cbot - ybase, 1, {}, st.struct, M.Concrete, "Struct")
			end
		end
	else
		Props.wall(m, bcf, w + 1, ybase, H, 1, entrance, st.struct, M.Concrete, "Struct")
	end
	dress(m, bcf, { w - 1.2, w - 1.44, w - 1.68 }, 0, top, entrance, st)
	-- карниз под потолком по периметру
	for _, side in { -1, 1 } do
		P(m, "Crown", Vector3.new(0.3, 0.4, l - 1.8), at(origin, side * (w / 2 - 0.75), top - 0.2, -l / 2), st.ceil:Lerp(rgb(0, 0, 0), 0.15), M.SmoothPlastic, nc())
	end
	for _, z in { -0.75, -l + 0.75 } do
		P(m, "Crown", Vector3.new(w - 1.2, 0.4, 0.3), at(origin, 0, top - 0.2, z), st.ceil:Lerp(rgb(0, 0, 0), 0.15), M.SmoothPlastic, nc())
	end
	-- кадры дверей и окон
	local function exitCF(e)
		return origin * CFrame.new(e.x, e.y or 0, e.z) * CFrame.Angles(0, -e.turn * math.pi / 2, 0)
	end
	local info = {
		exitCF = exitCF(d.exit),
		decoyCFs = {},
		windows = windows,
		ybase = ybase,
		top = top,
	}
	for _, e in d.decoys do
		table.insert(info.decoyCFs, exitCF(e))
	end
	-- стена с настоящим выходом — для стены входа следующей комнаты
	local e = d.exit
	local a, b
	if e.turn == 0 then
		a, b = at(origin, -w / 2 - 0.5, 0, -l), at(origin, w / 2 + 0.5, 0, -l)
	else
		a, b = at(origin, e.turn * w / 2, 0, 0.5), at(origin, e.turn * w / 2, 0, -l - 0.5)
	end
	info.exitWall = { a = a.Position, b = b.Position, top = origin.Y + top, bottom = origin.Y + ybase }
	return info
end

-- общая стена прошлой комнаты в координатах новой
function Builder.prevWallFor(prevInfo, origin: CFrame)
	if not prevInfo or not prevInfo.exitWall then
		return nil
	end
	local ew = prevInfo.exitWall
	local xa = origin:PointToObjectSpace(ew.a).X
	local xb = origin:PointToObjectSpace(ew.b).X
	return { x0 = math.min(xa, xb), x1 = math.max(xa, xb), top = ew.top - origin.Y, bottom = ew.bottom - origin.Y }
end

-- ---------------------------------------------------------------------------
-- места у стен

local function slotL(d, origin, z)
	return origin * CFrame.new(-d.w / 2 + F, floorAt(d, z), z) * CFrame.Angles(0, -math.pi / 2, 0)
end
local function slotR(d, origin, z)
	return origin * CFrame.new(d.w / 2 - F, floorAt(d, z), z) * CFrame.Angles(0, math.pi / 2, 0)
end
local function slotFront(d, origin, x)
	return origin * CFrame.new(x, floorAt(d, -d.l), -d.l + F) * CFrame.Angles(0, math.pi, 0)
end
local function slotBack(d, origin, x)
	return origin * CFrame.new(x, 0, -F)
end
local function spot(d, origin, x, z, yaw)
	return origin * CFrame.new(x, floorAt(d, z), z) * CFrame.Angles(0, yaw or 0, 0)
end
Builder.slotL, Builder.slotR, Builder.slotFront, Builder.slotBack, Builder.spot = slotL, slotR, slotFront, slotBack, spot

-- ---------------------------------------------------------------------------
-- помощники планировок

local function hide(ctx, cf)
	local _, cavity = Props.locker(ctx.m, cf)
	table.insert(ctx.info.hideSpots, cavity)
end
local function vent(ctx, cf)
	local _, cavity = Props.vent(ctx.m, cf)
	table.insert(ctx.info.hideSpots, cavity)
end
local function search(ctx, kind: string, cf)
	local m, hit, drawers, top
	if kind == "nightstand" then
		m, hit, drawers, top = Props.nightstand(ctx.m, cf)
	elseif kind == "cabinet" then
		m, hit, drawers = Props.cabinet(ctx.m, cf)
	elseif kind == "desk" then
		m, hit, drawers, top = Props.desk(ctx.m, cf)
	else
		m, hit, drawers, top = Props.dresser(ctx.m, cf)
	end
	table.insert(ctx.info.searchables, { model = m, hit = hit, drawers = drawers })
	if top then
		table.insert(ctx.info.tops, top)
	end
	return top
end
local function lamp(ctx, pos: Vector3)
	local _, bulb = Props.ceilingLamp(ctx.m, pos)
	table.insert(ctx.info.lights, bulb)
end
local function ceil(ctx, x, z)
	lamp(ctx, at(ctx.origin, x, ctx.info.top, z).Position)
end
local function chandelier(ctx, x, z, drop)
	local _, core = Props.chandelier(ctx.m, at(ctx.origin, x, ctx.info.top, z).Position, drop or 2)
	table.insert(ctx.info.lights, core)
end
local function tableLamp(ctx, cf)
	local _, shade = Props.tableLamp(ctx.m, cf)
	table.insert(ctx.info.lights, shade)
end
local function painting(ctx, side, z, y, w, h)
	local cf = if side < 0 then slotL(ctx.d, ctx.origin, z) elseif side > 0 then slotR(ctx.d, ctx.origin, z) else slotFront(ctx.d, ctx.origin, z)
	-- картина висит на обоях (их лицевая сторона в 0.6 от середины стены)
	Props.painting(ctx.m, cf * CFrame.new(0, y, F - 0.6), w, h, ctx.d.door + math.floor(z))
end

-- ---------------------------------------------------------------------------
-- планировки

local L = {}

L.start = function(c)
	local d, o = c.d, c.origin
	Props.table(c.m, spot(d, o, 0, -10), 10, 2.6, rgb(90, 20, 24))
	tableLamp(c, spot(d, o, -3.5, -10) * CFrame.new(0, 3.25, 0))
	for _, s in { -1, 1 } do
		hide(c, slotBack(d, o, s * 9))
		Props.sofa(c.m, (if s < 0 then slotL else slotR)(d, o, -16), rgb(90, 30, 34))
		Props.plantPot(c.m, spot(d, o, s * 12, -26))
	end
	search(c, "dresser", slotFront(d, o, -9))
	search(c, "dresser", slotFront(d, o, 9))
	Props.rug(c.m, spot(d, o, 0, -16), 12, 14, rgb(100, 26, 30))
	chandelier(c, 0, -15, 3)
	d.windowZ = { -6 }
end

L.corridor = function(c)
	local d, o = c.d, c.origin
	hide(c, slotL(d, o, -12))
	search(c, "nightstand", slotR(d, o, -12))
	hide(c, slotR(d, o, -24))
	painting(c, 1, -12, 6.5, 2.6, 2)
	painting(c, -1, -24, 6.5, 3.6, 2.6)
	ceil(c, 0, -10)
	ceil(c, 0, -26)
	d.windowZ = { -18 }
end

L.longhall = function(c)
	local d, o = c.d, c.origin
	hide(c, slotL(d, o, -14))
	search(c, "nightstand", slotR(d, o, -14))
	search(c, "nightstand", slotL(d, o, -30))
	hide(c, slotR(d, o, -30))
	hide(c, slotL(d, o, -46))
	search(c, "nightstand", slotR(d, o, -46))
	for _, z in { -8, -24, -40, -56 } do
		ceil(c, 0, z)
	end
	painting(c, 1, -14, 6.5, 2.6, 2)
	painting(c, -1, -30, 6.5, 2.6, 2)
	d.windowZ = { -22, -38 }
end

L.shorthall = function(c)
	local d, o = c.d, c.origin
	hide(c, slotL(d, o, -10))
	search(c, "nightstand", slotR(d, o, -10))
	painting(c, 1, -10, 6.5, 2.6, 2)
	ceil(c, 0, -10)
end

L.crawl = function(c)
	local d, o = c.d, c.origin
	vent(c, slotL(d, o, -10))
	search(c, "cabinet", slotR(d, o, -10))
	vent(c, slotR(d, o, -21))
	Props.pipes(c.m, at(o, -d.w / 2 + 1.2, d.h - 0.6, -1).Position, at(o, -d.w / 2 + 1.2, d.h - 0.6, -d.l + 1).Position, 2)
	ceil(c, 0, -8)
	ceil(c, 0, -22)
end

local function stairsLayout(c)
	local d, o = c.d, c.origin
	hide(c, slotL(d, o, -6))
	search(c, "nightstand", slotR(d, o, -6))
	hide(c, slotR(d, o, -34))
	ceil(c, 0, -6)
	ceil(c, 0, -20)
	ceil(c, 0, -34)
	painting(c, -1, -34, d.dy + 6.5, 3, 2.4)
end
L.stairsup = stairsLayout
L.stairsdown = stairsLayout

L.bedroom = function(c)
	local d, o = c.d, c.origin
	Props.bed(c.m, slotBack(d, o, 7), Color3.fromHSV((d.door * 0.17) % 1, 0.35, 0.4))
	local top = search(c, "nightstand", slotBack(d, o, 11))
	if top then
		tableLamp(c, top * CFrame.new(-0.4, 0, 0))
	end
	hide(c, slotL(d, o, -5))
	search(c, "dresser", slotL(d, o, -12))
	search(c, "desk", slotR(d, o, -13))
	Props.chair(c.m, slotR(d, o, -13) * CFrame.new(0, 0, -4.2) * CFrame.Angles(0, math.pi, 0))
	Props.rug(c.m, spot(d, o, -2, -14), 9, 7, rgb(90, 40, 40))
	for _, x in { -11.4, 11.4 } do
		Props.plantPot(c.m, spot(d, o, x, -d.l + 1.6))
	end
	ceil(c, 0, -14)
	d.windowZ = { -21 }
end

L.suite = function(c)
	local d, o = c.d, c.origin
	hide(c, slotBack(d, o, -10))
	hide(c, slotBack(d, o, 10))
	Props.sofa(c.m, slotL(d, o, -12), rgb(70, 50, 80))
	local _, ttop = Props.coffeeTable(c.m, slotL(d, o, -12) * CFrame.new(0, 0, -5))
	table.insert(c.info.tops, ttop)
	Props.bookshelf(c.m, slotR(d, o, -8), 6, 10, d.door)
	search(c, "dresser", slotR(d, o, -16))
	local top = search(c, "nightstand", slotR(d, o, -20.5))
	if top then
		tableLamp(c, top)
	end
	Props.bed(c.m, slotR(d, o, -25), rgb(90, 50, 60))
	search(c, "desk", slotL(d, o, -24))
	Props.chair(c.m, slotL(d, o, -24) * CFrame.new(0, 0, -4.2) * CFrame.Angles(0, math.pi, 0))
	Props.rug(c.m, spot(d, o, 0, -18), 12, 10, rgb(70, 40, 50))
	chandelier(c, 0, -20, 3)
	ceil(c, 0, -8)
	ceil(c, 0, -32)
	d.windowZ = { -18 }
end

L.office = function(c)
	local d, o = c.d, c.origin
	search(c, "cabinet", slotBack(d, o, -9))
	search(c, "cabinet", slotBack(d, o, 9))
	for _, s in { -1, 1 } do
		local slot = if s < 0 then slotL else slotR
		Props.bookshelf(c.m, slot(d, o, -7), 6, 8, d.door + s)
		hide(c, slot(d, o, -14))
		search(c, "cabinet", slot(d, o, -20))
		local top = search(c, "desk", spot(d, o, s * 5, -9))
		Props.chair(c.m, spot(d, o, s * 5, -12.9, math.pi))
		if top and s > 0 then
			tableLamp(c, top * CFrame.new(-1.6, 0, 0))
		end
	end
	ceil(c, -6, -13)
	ceil(c, 6, -13)
	d.windowZ = { -23.6 }
end

L.library = function(c)
	local d, o = c.d, c.origin
	hide(c, slotBack(d, o, -10))
	hide(c, slotBack(d, o, 10))
	-- полки у стен
	for _, s in { -1, 1 } do
		local slot = if s < 0 then slotL else slotR
		for k, z in { -6, -12.4, -18.8 } do
			Props.bookshelf(c.m, slot(d, o, z), 6, 12, d.door + k * 3 + s)
		end
	end
	-- два ряда двусторонних стеллажей посередине
	for _, x in { -8, 8 } do
		for k, z in { -10, -16.4, -22.8 } do
			Props.bookshelf(c.m, spot(d, o, x, z, -math.pi / 2) * CFrame.new(0, 0, 0.05), 6, 10, d.door + k)
			Props.bookshelf(c.m, spot(d, o, x, z, math.pi / 2) * CFrame.new(0, 0, 0.05), 6, 10, d.door + k + 5)
		end
	end
	Props.bookshelf(c.m, slotFront(d, o, 0), 6, 12, d.door + 9)
	local _, ttop = Props.table(c.m, spot(d, o, 0, -30), 6, 3)
	table.insert(c.info.tops, ttop)
	tableLamp(c, ttop * CFrame.new(-2, 0, 0))
	for _, x in { -1.5, 1.5 } do
		Props.chair(c.m, spot(d, o, x, -32.4, math.pi))
	end
	search(c, "desk", slotL(d, o, -26))
	chandelier(c, 0, -12, 3)
	chandelier(c, 0, -26, 3)
end

L.lounge = function(c)
	local d, o = c.d, c.origin
	hide(c, slotBack(d, o, -10))
	hide(c, slotBack(d, o, 10))
	Props.piano(c.m, slotFront(d, o, -9))
	Props.bookshelf(c.m, slotFront(d, o, 9), 6, 9, d.door)
	Props.sofa(c.m, slotL(d, o, -10), rgb(60, 70, 50))
	Props.sofa(c.m, slotR(d, o, -10), rgb(60, 70, 50))
	local _, ttop = Props.coffeeTable(c.m, spot(d, o, 0, -12))
	table.insert(c.info.tops, ttop)
	Props.armchair(c.m, spot(d, o, -4.4, -12, -math.pi / 2), rgb(80, 40, 40))
	Props.armchair(c.m, spot(d, o, 4.4, -12, math.pi / 2), rgb(80, 40, 40))
	search(c, "dresser", slotL(d, o, -17))
	search(c, "dresser", slotR(d, o, -17))
	Props.rug(c.m, spot(d, o, 0, -12), 14, 9, rgb(80, 30, 40))
	chandelier(c, 0, -14, 3)
	d.windowZ = { -3.5 }
end

L.dining = function(c)
	local d, o = c.d, c.origin
	hide(c, slotBack(d, o, -9))
	hide(c, slotBack(d, o, 9))
	local _, ttop = Props.table(c.m, spot(d, o, 0, -17), 4, 16, rgb(220, 214, 196))
	table.insert(c.info.tops, ttop * CFrame.new(0, 0, 5))
	for _, z in { -11, -14, -17, -20, -23 } do
		Props.chair(c.m, spot(d, o, -3.1, z, -math.pi / 2))
		Props.chair(c.m, spot(d, o, 3.1, z, math.pi / 2))
	end
	Props.chair(c.m, spot(d, o, 0, -7.6, 0))
	Props.chair(c.m, spot(d, o, 0, -26.4, math.pi))
	for _, s in { -1, 1 } do
		local slot = if s < 0 then slotL else slotR
		search(c, "dresser", slot(d, o, -10))
		search(c, "dresser", slot(d, o, -22))
		Props.plantPot(c.m, spot(d, o, s * 12, -d.l + 1.6))
	end
	chandelier(c, 0, -11, 3)
	chandelier(c, 0, -23, 3)
	d.windowZ = { -16 }
end

L.kitchen = function(c)
	local d, o = c.d, c.origin
	hide(c, slotBack(d, o, -8))
	hide(c, slotBack(d, o, 7))
	local _, t1 = Props.counter(c.m, slotL(d, o, -9), 10)
	table.insert(c.info.tops, t1)
	Props.stove(c.m, slotL(d, o, -17))
	Props.fridge(c.m, slotR(d, o, -6))
	local _, t2 = Props.counter(c.m, slotR(d, o, -13), 8)
	table.insert(c.info.tops, t2)
	local _, t3 = Props.table(c.m, spot(d, o, 0, -16), 6, 3)
	table.insert(c.info.tops, t3)
	search(c, "cabinet", slotFront(d, o, -9))
	Props.rack(c.m, slotFront(d, o, 9), 6, d.door)
	ceil(c, 0, -8)
	ceil(c, 0, -20)
end

L.storage = function(c)
	local d, o = c.d, c.origin
	hide(c, slotBack(d, o, -9.4))
	hide(c, slotBack(d, o, 9.4))
	for _, s in { -1, 1 } do
		local slot = if s < 0 then slotL else slotR
		Props.rack(c.m, slot(d, o, -6), 6, d.door + s)
		Props.rack(c.m, slot(d, o, -13), 6, d.door + s * 2)
		search(c, "cabinet", slot(d, o, -20))
	end
	Props.crate(c.m, spot(d, o, -6, -18, 0.3), 3)
	Props.crate(c.m, spot(d, o, -6, -18, 0.3) * CFrame.new(0, 3, 0), 2.4)
	Props.crate(c.m, spot(d, o, 6, -18, -0.2), 3)
	Props.crate(c.m, spot(d, o, 0, -25, 0.5), 3)
	Props.crate(c.m, slotFront(d, o, 0) * CFrame.new(0, 0, -1.6), 3)
	ceil(c, -7, -10)
	ceil(c, 7, -10)
	ceil(c, 0, -24)
end

L.pillarhall = function(c)
	local d, o = c.d, c.origin
	for _, x in { -10, 10 } do
		for _, z in { -10, -22, -34 } do
			Props.pillar(c.m, spot(d, o, x, z), d.h)
		end
	end
	search(c, "dresser", slotBack(d, o, -12))
	search(c, "dresser", slotBack(d, o, 12))
	for _, s in { -1, 1 } do
		local slot = if s < 0 then slotL else slotR
		Props.bench(c.m, slot(d, o, -10), 7)
		hide(c, slot(d, o, -16))
		Props.bench(c.m, slot(d, o, -22), 7)
		hide(c, slot(d, o, -28))
	end
	Props.rug(c.m, spot(d, o, 0, -23), 7, 34, rgb(90, 24, 28))
	chandelier(c, 0, -16, 4)
	chandelier(c, 0, -30, 4)
	d.windowZ = { -3.5, -33 }
end

L.bathroom = function(c)
	local d, o = c.d, c.origin
	for _, z in { -5, -10, -15 } do
		Props.stall(c.m, slotL(d, o, z))
	end
	for _, z in { -6, -10, -14 } do
		Props.sink(c.m, slotR(d, o, z))
	end
	hide(c, slotBack(d, o, 8))
	search(c, "cabinet", slotFront(d, o, -8))
	ceil(c, 0, -8)
	ceil(c, 0, -16)
end

L.laundry = function(c)
	local d, o = c.d, c.origin
	for _, s in { -1, 1 } do
		local slot = if s < 0 then slotL else slotR
		for _, z in { -5.5, -8.7, -11.9 } do
			Props.washer(c.m, slot(d, o, z))
		end
		search(c, "cabinet", slotFront(d, o, s * 9))
	end
	hide(c, slotBack(d, o, -8))
	hide(c, slotBack(d, o, 8))
	local _, ttop = Props.table(c.m, spot(d, o, 0, -12), 5, 3)
	table.insert(c.info.tops, ttop)
	ceil(c, 0, -7)
	ceil(c, 0, -18)
end

-- почти пустая комната: стул посередине смотрит на вход
L.empty = function(c)
	local d, o = c.d, c.origin
	Props.chair(c.m, spot(d, o, 0, -15, math.pi))
	hide(c, slotBack(d, o, 10))
	Props.painting(c.m, slotFront(d, o, 0) * CFrame.new(0, 11.5, F - 0.6), 3, 2, 3)
	ceil(c, 0, -15)
end

L.gallery = function(c)
	local d, o = c.d, c.origin
	for _, s in { -1, 1 } do
		for _, z in { -6, -12, -18, -24 } do
			painting(c, s, z, 7, 4, 3.4)
		end
		search(c, "cabinet", slotFront(d, o, s * 11))
	end
	hide(c, slotBack(d, o, -9))
	hide(c, slotBack(d, o, 9))
	for _, z in { -12, -24 } do
		-- две скамьи спинка к спинке
		Props.bench(c.m, spot(d, o, 0.05, z, -math.pi / 2), 5)
		Props.bench(c.m, spot(d, o, -0.05, z, math.pi / 2), 5)
	end
	-- статуя без лица на постаменте
	local base = spot(d, o, 0, -18)
	P(c.m, "Plinth", Vector3.new(2.4, 3, 2.4), base * CFrame.new(0, 1.5, 0), rgb(170, 164, 152), M.Marble)
	P(c.m, "Torso", Vector3.new(1.4, 2.4, 0.9), base * CFrame.new(0, 4.2, 0), rgb(200, 196, 186), M.Marble)
	Props.S(c.m, "Head", 1.1, base * CFrame.new(0, 6, 0), rgb(200, 196, 186), M.Marble)
	ceil(c, 0, -10)
	ceil(c, 0, -26)
end

-- ---------------------------------------------------------------------------

function Builder.build(parent: Instance, d, origin: CFrame, prevInfo, rand)
	rand = rand or Plan.rng(d.door * 31 + 7)
	local st = Builder.style(d, rand)
	local m = Props.model(parent, string.format("Room_%03d", d.door))
	local info = { desc = d, model = m, origin = origin, hideSpots = {}, searchables = {}, tops = {}, lights = {} }
	Props.LIGHT = if d.blackout then 0 else (d.light or 1)
	-- окна задаёт планировка, поэтому сначала планировка, потом стены
	local layout = L[d.kind] or L.corridor
	local sh
	-- верх комнаты нужен лампам до сборки стен
	info.top = math.max(0, d.dy) + d.h
	local ctx = { d = d, origin = origin, m = m, info = info }
	layout(ctx)
	sh = shell(m, d, origin, st, Builder.prevWallFor(prevInfo, origin))
	for k, v in sh do
		info[k] = v
	end
	-- окна в пустоту
	for _, wdw in info.windows do
		local cf = origin * CFrame.new(wdw.side * d.w / 2, wdw.y, wdw.z) * CFrame.Angles(0, if wdw.side < 0 then -math.pi / 2 else math.pi / 2, 0)
		Props.window(m, cf, 1.2)
	end
	-- путь для Гула и точки для существ
	info.path = {
		at(origin, 0, 4, -2).Position,
		at(origin, 0, floorAt(d, -d.l / 2) + 4, -d.l / 2).Position,
		(info.exitCF * CFrame.new(0, 4, 2.5)).Position,
	}
	info.watcherSpawn = at(origin, (if d.door % 2 == 0 then 1 else -1) * (d.w / 2 - 3), floorAt(d, -d.l + 3), -d.l + 3)
	info.center = at(origin, 0, info.top / 2, -d.l / 2)
	info.size = Vector3.new(d.w, info.top - info.ybase, d.l)
	Props.LIGHT = 1
	return info
end

-- Игрок внутри комнаты
function Builder.contains(info, pos: Vector3): boolean
	local lp = info.origin:PointToObjectSpace(pos)
	local d = info.desc
	return math.abs(lp.X) <= d.w / 2 + 0.5 and lp.Z <= 0.5 and lp.Z >= -d.l - 0.5 and lp.Y > (info.ybase or 0) - 3 and lp.Y < (info.top or d.h) + 2
end

Builder.shell = shell
Builder.dress = dress
Builder.F = F

return Builder
