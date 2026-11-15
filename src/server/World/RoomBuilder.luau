--!nonstrict
-- Сборка комнаты по описанию из RoomPlan. Кадр комнаты: вход в origin, комната уходит
-- вперёд (-Z). Стены: каркас толщиной 1 по границе, поверх — обои (0.1) и панели
-- (0.12) со стороны комнаты, поэтому соседние комнаты не мерцают на общей стене.
-- Мебель расставлена по планировкам; проходы ко всем возможным дверям свободны

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local M = require(Shared.Materials)
local Plan = require(Shared.RoomPlan)
local Props = require(script.Parent.Props)

local P, C, nc, rgb = Props.P, Props.C, Props.nc, Props.rgb

local Builder = {}

local F = 0.9 -- от середины стены до места мебели (панели и поручень заканчиваются на 0.84)
local SKIN = 0.1
local PANEL = 0.12
local DOOR_HOLE = { w = 5, h = 9 }

-- ---------------------------------------------------------------------------
-- оформление по глубине

local PAPER = {
	classic = { rgb(112, 38, 42), rgb(42, 68, 56), rgb(38, 50, 82), rgb(188, 176, 150), rgb(76, 46, 74), rgb(150, 120, 70) },
	old = { rgb(74, 40, 40), rgb(44, 56, 50), rgb(40, 44, 60), rgb(110, 104, 92), rgb(60, 46, 58) },
	ruin = { rgb(62, 70, 58), rgb(70, 68, 60) },
}
local FLOOR = {
	classic = { { rgb(206, 200, 190), M.Marble }, { rgb(124, 86, 54), M.WoodPlanks }, { rgb(170, 160, 146), M.Marble }, { rgb(96, 64, 44), M.WoodPlanks } },
	old = { { rgb(128, 124, 116), M.Marble }, { rgb(78, 56, 40), M.WoodPlanks }, { rgb(100, 96, 90), M.Slate } },
	ruin = { { rgb(84, 88, 76), M.Slate } },
}

function Builder.style(d, rand)
	local zone = d.zone or "classic"
	local papers, floors = PAPER[zone] or PAPER.classic, FLOOR[zone] or FLOOR.classic
	local fl = floors[math.floor(rand() * #floors) + 1]
	local st = {
		paper = papers[math.floor(rand() * #papers) + 1],
		paperMat = M.Plaster,
		panel = if zone == "classic" then (if rand() < 0.5 then Props.WOOD_DARK else rgb(170, 164, 152)) else rgb(72, 66, 58),
		panelMat = M.Wood,
		floor = fl[1],
		floorMat = fl[2],
		ceil = if zone == "classic" then rgb(214, 208, 194) elseif zone == "old" then rgb(140, 134, 124) else rgb(84, 86, 78),
		ceilMat = M.SmoothPlastic,
		struct = rgb(110, 104, 96),
		wainscot = true,
	}
	if st.panel ~= Props.WOOD_DARK and zone == "classic" then
		st.panelMat = M.Marble
	end
	local k = d.kind
	if k == "restroom" then
		st.paper = if zone == "classic" then rgb(206, 210, 204) else rgb(140, 148, 142)
		st.paperMat = M.CeramicTiles
		st.floor = if zone == "classic" then rgb(186, 188, 184) else rgb(110, 114, 110)
		st.floorMat = M.CeramicTiles
		st.wainscot = false
	elseif k == "archive" then
		st.paper = Props.WOOD:Lerp(rgb(0, 0, 0), if zone == "classic" then 0.25 else 0.5)
		st.paperMat = M.WoodPlanks
		st.floor = rgb(84, 58, 40)
		st.floorMat = M.WoodPlanks
	elseif k == "storage" or k == "tech" or k == "lifthall" then
		st.paper = rgb(98, 98, 94)
		st.paperMat = M.Concrete
		st.floor = rgb(80, 80, 78)
		st.floorMat = M.Concrete
		st.ceil = rgb(90, 90, 88)
		st.wainscot = false
	elseif k == "arena" then
		st.paper = rgb(72, 70, 68)
		st.paperMat = M.Slate
		st.floor = rgb(92, 90, 86)
		st.floorMat = M.Marble
		st.ceil = rgb(50, 50, 50)
		st.wainscot = false
	elseif k == "voidhall" then
		st.paper = rgb(86, 82, 76)
		st.floor = rgb(70, 66, 60)
		st.floorMat = M.Slate
	elseif k == "fossil" then
		st.floor = rgb(176, 160, 130)
		st.floorMat = M.Sand
	elseif k == "final" then
		st.paperMat = M.Slate
		st.wainscot = false
	end
	if k == "tech" then
		st.paper = rgb(96, 100, 102)
		st.paperMat = M.DiamondPlate
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
	if not d.noCeiling then
		P(m, "Ceiling", Vector3.new(w, 1, l), at(origin, 0, top + 0.5, -l / 2), st.ceil, st.ceilMat)
	end
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
	-- проломы во всю высоту стены (аномальный коридор)
	for _, g in d.gaps or {} do
		table.insert(sides[g.side], { zRoom = g.z, w = g.w, y = ybase, h = top })
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
	local eh = d.entry or DOOR_HOLE
	local entrance = if d.kind == "start" then {} else { { x = 0, w = eh.w, y = 0, h = eh.h } }
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
	for _, side in (if d.noCeiling then {} else { -1, 1 }) do
		P(m, "Crown", Vector3.new(0.3, 0.4, l - 1.8), at(origin, side * (w / 2 - 0.75), top - 0.2, -l / 2), st.ceil:Lerp(rgb(0, 0, 0), 0.15), M.SmoothPlastic, nc())
	end
	for _, z in (if d.noCeiling then {} else { -0.75, -l + 0.75 }) do
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
	-- шкафчики стоят не в каждом зале: сколько их, решает план
	if ctx.hides <= 0 then
		return
	end
	ctx.hides -= 1
	local _, cavity = Props.locker(ctx.m, cf)
	table.insert(ctx.info.hideSpots, cavity)
end
local function vent(ctx, cf)
	if ctx.hides <= 0 then
		return
	end
	ctx.hides -= 1
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
-- планировки залов музея

local L = {}

local STATUES = { "figure", "bust", "obelisk", "abstract", "broken" }
local function statue(c, x, z, k: number, yaw: number?)
	Props.statue(c.m, spot(c.d, c.origin, x, z, yaw), STATUES[(c.d.door + k) % #STATUES + 1], c.d.door)
end
local function case(c, x, z, k: number, item: string?)
	Props.displayCase(c.m, spot(c.d, c.origin, x, z), item or Props.ODD[(c.d.door * 3 + k * 5) % #Props.ODD + 1])
end
local function wallCase(c, side: number, z: number, w: number?)
	Props.wallCase(c.m, (if side < 0 then slotL else slotR)(c.d, c.origin, z), w or 6, c.d.door + math.floor(z))
end
local function bench(c, side: number, z: number, w: number)
	Props.bench(c.m, (if side < 0 then slotL else slotR)(c.d, c.origin, z), w)
end
local function ropeAround(c, x0, x1, z0, z1)
	local function p(x, z)
		return at(c.origin, x, 0, z).Position
	end
	Props.rope(c.m, p(x0, z0), p(x1, z0))
	Props.rope(c.m, p(x0, z1), p(x1, z1))
	Props.rope(c.m, p(x0, z0), p(x0, z1))
	Props.rope(c.m, p(x1, z0), p(x1, z1))
end

L.start = function(c)
	local d, o = c.d, c.origin
	-- закрывшиеся входные двери за спиной
	local back = slotBack(d, o, 0)
	local dm = Props.model(c.m, "EntranceDoors")
	for _, s in { -1, 1 } do
		P(dm, "Leaf", Vector3.new(4.3, 12.4, 0.3), back * CFrame.new(s * 2.2, 6.2, -0.2), rgb(52, 34, 24), M.WoodPlanks, nc())
		P(dm, "Panel", Vector3.new(3, 4.4, 0.06), back * CFrame.new(s * 2.2, 3.4, -0.38), rgb(40, 26, 18), M.Wood, nc())
		P(dm, "Panel", Vector3.new(3, 4.4, 0.06), back * CFrame.new(s * 2.2, 8.8, -0.38), rgb(40, 26, 18), M.Wood, nc())
		C(dm, "Ring", 0.1, 0.8, back * CFrame.new(s * 0.6, 5.6, -0.42) * CFrame.Angles(math.pi / 2, 0, 0), Props.BRASS, M.Metal, nc())
		P(dm, "Post", Vector3.new(0.8, 13.2, 0.5), back * CFrame.new(s * 4.8, 6.6, -0.3), rgb(150, 144, 134), M.Marble, nc())
	end
	P(dm, "Lintel", Vector3.new(10.8, 0.9, 0.7), back * CFrame.new(0, 13.1, -0.42), rgb(150, 144, 134), M.Marble, nc())
	Props.counter(c.m, slotL(d, o, -14), 10)
	bench(c, 1, -12, 8)
	Props.statue(c.m, spot(d, o, -9, -22), "bust", 1)
	Props.statue(c.m, spot(d, o, 9, -22), "bust", 2)
	Props.plantPot(c.m, spot(d, o, -12, -27.5))
	Props.plantPot(c.m, spot(d, o, 12, -27.5))
	Props.rug(c.m, spot(d, o, 0, -16), 10, 22, rgb(110, 28, 34))
	chandelier(c, 0, -15, 3)
end

L.corridor = function(c)
	hide(c, slotL(c.d, c.origin, -12))
	bench(c, 1, -11, 6)
	wallCase(c, -1, -20)
	painting(c, 1, -11, 8, 3, 2.4)
	painting(c, 1, -22, 7, 3.6, 3)
	ceil(c, 0, -10)
	ceil(c, 0, -28)
end

L.longhall = function(c)
	local d, o = c.d, c.origin
	hide(c, slotL(d, o, -14))
	hide(c, slotR(d, o, -44))
	wallCase(c, 1, -14)
	wallCase(c, -1, -28)
	wallCase(c, 1, -34)
	bench(c, -1, -46, 6)
	painting(c, -1, -20.5, 7, 3, 2.6)
	painting(c, 1, -24, 7, 3, 2.6)
	painting(c, -1, -54, 7, 3.6, 3)
	for _, z in { -8, -24, -40, -56 } do
		ceil(c, 0, z)
	end
end

L.shorthall = function(c)
	hide(c, slotL(c.d, c.origin, -11))
	Props.vase(c.m, spot(c.d, c.origin, 3.8, -11), c.d.door)
	painting(c, 1, -11, 8.5, 3, 2.4)
	ceil(c, 0, -11)
end

L.gallery = function(c)
	local d, o = c.d, c.origin
	for _, s in { -1, 1 } do
		for k, z in { -8, -16, -24 } do
			painting(c, s, z, 7.5, 5, 4)
			local _ = k
		end
		statue(c, s * 11, -30, if s < 0 then 0 else 2)
		hide(c, slotBack(d, o, s * 9))
	end
	for _, z in { -14, -26 } do
		Props.bench(c.m, spot(d, o, 0.05, z, -math.pi / 2), 6)
		Props.bench(c.m, spot(d, o, -0.05, z, math.pi / 2), 6)
	end
	chandelier(c, 0, -12, 3)
	chandelier(c, 0, -30, 3)
end

L.sculpture = function(c)
	local d, o = c.d, c.origin
	statue(c, -9, -11, 0)
	statue(c, 9, -11, 1)
	statue(c, 0, -18, 2)
	statue(c, -9, -26, 3)
	statue(c, 9, -26, 4)
	bench(c, -1, -18, 6)
	bench(c, 1, -18, 6)
	hide(c, slotBack(d, o, -13))
	hide(c, slotBack(d, o, 13))
	chandelier(c, 0, -18, 4)
	ceil(c, -10, -33)
	ceil(c, 10, -33)
end

L.cases = function(c)
	local d, o = c.d, c.origin
	case(c, -8, -9, 1)
	case(c, 8, -9, 2)
	case(c, 0, -16, 3)
	case(c, -8, -23, 4)
	case(c, 8, -23, 5)
	wallCase(c, -1, -14)
	wallCase(c, 1, -14)
	hide(c, slotBack(d, o, -10))
	hide(c, slotBack(d, o, 10))
	ceil(c, 0, -9)
	ceil(c, 0, -24)
end

L.fossil = function(c)
	local d, o = c.d, c.origin
	Props.fossil(c.m, spot(d, o, 0, -28), 24)
	ropeAround(c, -5.5, 5.5, -13.5, -42.5)
	for _, s in { -1, 1 } do
		bench(c, s, -22, 7)
		bench(c, s, -36, 7)
		case(c, s * 14, -9, if s < 0 then 1 else 2, if s < 0 then "skull" else "gem")
		case(c, s * 14, -46, if s < 0 then 3 else 4)
		hide(c, slotBack(d, o, s * 15))
		ceil(c, s * 14, -28)
	end
	hide(c, slotL(d, o, -29))
	chandelier(c, 0, -9, 5)
	chandelier(c, 0, -47, 5)
end

L.armory = function(c)
	local d, o = c.d, c.origin
	for _, z in { -8, -14, -20 } do
		Props.armor(c.m, slotL(d, o, z))
		Props.armor(c.m, slotR(d, o, z))
	end
	local _, top = Props.table(c.m, spot(d, o, 0, -16), 4, 10, rgb(90, 20, 26))
	for k = -1, 1 do
		P(c.m, "Blade", Vector3.new(0.25, 0.06, 3.2), top * CFrame.new(k * 1.1, 0.06, k * 1.4) * CFrame.Angles(0, 0.3 * k, 0), rgb(170, 174, 180), M.Metal, nc())
		P(c.m, "Hilt", Vector3.new(0.9, 0.1, 0.2), top * CFrame.new(k * 1.1, 0.07, k * 1.4) * CFrame.Angles(0, 0.3 * k, 0) * CFrame.new(0, 0, 1.3), Props.BRASS, M.Metal, nc())
	end
	Props.wallCase(c.m, slotFront(d, o, -9), 6, d.door)
	Props.wallCase(c.m, slotFront(d, o, 9), 6, d.door + 4)
	hide(c, slotBack(d, o, -9))
	hide(c, slotBack(d, o, 9))
	ceil(c, 0, -9)
	ceil(c, 0, -25)
end

L.ceramics = function(c)
	local d, o = c.d, c.origin
	for k, p in { { -7, -9 }, { 7, -9 }, { 0, -15 }, { -7, -21 }, { 7, -21 } } do
		Props.vase(c.m, spot(d, o, p[1], p[2]), d.door + k)
	end
	wallCase(c, -1, -15)
	wallCase(c, 1, -15)
	hide(c, slotBack(d, o, -9))
	hide(c, slotBack(d, o, 9))
	Props.rug(c.m, spot(d, o, 0, -15), 8, 16, rgb(40, 60, 90))
	ceil(c, 0, -15)
end

L.archive = function(c)
	local d, o = c.d, c.origin
	for _, s in { -1, 1 } do
		local slot = if s < 0 then slotL else slotR
		for k, z in { -7, -13.4, -19.8 } do
			Props.bookshelf(c.m, slot(d, o, z), 6, 12, d.door + k * 3 + s)
		end
		search(c, "cabinet", slotBack(d, o, s * 7))
		hide(c, slotBack(d, o, s * 13))
		ceil(c, s * 8, -14)
		ceil(c, s * 8, -30)
	end
	for k, z in { -12, -18.4, -24.8 } do
		Props.bookshelf(c.m, spot(d, o, 0, z, -math.pi / 2) * CFrame.new(0, 0, 0.05), 6, 10, d.door + k)
		Props.bookshelf(c.m, spot(d, o, 0, z, math.pi / 2) * CFrame.new(0, 0, 0.05), 6, 10, d.door + k + 5)
	end
	local top = search(c, "desk", slotL(d, o, -27.6))
	if top then
		tableLamp(c, top * CFrame.new(-1.6, 0, 0))
	end
end

L.storage = function(c)
	local d, o = c.d, c.origin
	for _, s in { -1, 1 } do
		local slot = if s < 0 then slotL else slotR
		Props.rack(c.m, slot(d, o, -7), 6, d.door + s)
		Props.rack(c.m, slot(d, o, -14), 6, d.door + s * 2)
		search(c, "cabinet", slot(d, o, -20))
		hide(c, slotBack(d, o, s * 10))
	end
	-- экспонат, который так и не выставили
	Props.statue(c.m, spot(d, o, 0, -11), "broken", 1)
	Props.crate(c.m, spot(d, o, -5.5, -18, 0.3), 3)
	Props.crate(c.m, spot(d, o, -5.5, -18, 0.3) * CFrame.new(0, 3, 0), 2.4)
	Props.crate(c.m, spot(d, o, 5.5, -18, -0.2), 3)
	Props.crate(c.m, spot(d, o, 0, -25, 0.5), 3)
	ceil(c, 0, -9)
	ceil(c, 0, -24)
end

L.tech = function(c)
	local d, o = c.d, c.origin
	vent(c, slotL(d, o, -10))
	vent(c, slotR(d, o, -22))
	search(c, "cabinet", slotR(d, o, -10))
	P(c.m, "FuseBox", Vector3.new(2.2, 3, 0.5), slotL(d, o, -21) * CFrame.new(0, 5, -0.3), rgb(110, 114, 116), M.Metal)
	C(c.m, "Valve", 0.2, 1.2, slotR(d, o, -29) * CFrame.new(0, 4.5, -0.4) * CFrame.Angles(math.pi / 2, 0, 0), rgb(150, 40, 34), M.Metal, nc())
	for _, s in { -1, 1 } do
		Props.pipes(c.m, at(o, s * 4.6, d.h - 0.6, -1).Position, at(o, s * 4.6, d.h - 0.6, -d.l + 1).Position, 2)
	end
	ceil(c, 0, -8)
	ceil(c, 0, -24)
end

local function stairsLayout(c)
	local d, o = c.d, c.origin
	hide(c, slotL(d, o, -6))
	bench(c, 1, -6, 5)
	painting(c, -1, -34, 7, 3, 2.4)
	painting(c, 1, -34, 7, 3, 2.4)
	ceil(c, 0, -6)
	ceil(c, 0, -20)
	ceil(c, 0, -34)
end
L.stairsup = stairsLayout
L.stairsdown = stairsLayout

L.restroom = function(c)
	local d, o = c.d, c.origin
	Props.stallRow(c.m, slotL(d, o, -11), 3)
	Props.sinkRow(c.m, slotR(d, o, -11), 3)
	hide(c, slotFront(d, o, 8))
	search(c, "cabinet", slotFront(d, o, -8))
	C(c.m, "Bin", 2, 1.4, spot(d, o, 9.6, -20.5) * CFrame.new(0, 1, 0), rgb(120, 124, 126), M.Metal)
	ceil(c, 0, -8)
	ceil(c, 0, -19)
end

L.cafe = function(c)
	local d, o = c.d, c.origin
	local _, top = Props.counter(c.m, slotL(d, o, -10), 10)
	table.insert(c.info.tops, top)
	Props.fridge(c.m, slotL(d, o, -18.5))
	for _, p in { { 5, -8 }, { 10, -16 }, { 4, -23 }, { -5, -23 } } do
		local _, t = Props.cafeTable(c.m, spot(d, o, p[1], p[2]))
		table.insert(c.info.tops, t)
	end
	hide(c, slotBack(d, o, 11))
	ceil(c, 0, -9)
	ceil(c, 0, -23)
end

L.rotunda = function(c)
	local d, o = c.d, c.origin
	for k = 0, 7 do
		local a = math.rad(22.5 + k * 45)
		Props.pillar(c.m, spot(d, o, math.cos(a) * 14, -23 + math.sin(a) * 14), d.h)
	end
	Props.statue(c.m, spot(d, o, 0, -23), "obelisk", d.door)
	for _, s in { -1, 1 } do
		bench(c, s, -14, 7)
		bench(c, s, -27, 7)
		case(c, s * 16, -36, if s < 0 then 1 else 2)
		hide(c, slotBack(d, o, s * 16))
	end
	hide(c, slotL(d, o, -20.5))
	chandelier(c, 0, -23, 6)
end

-- вещи, которым в музее не место
L.oddities = function(c)
	local d, o = c.d, c.origin
	case(c, -8, -9, 1, "wrench")
	case(c, 8, -9, 2, "boot")
	case(c, 0, -15, 3, "teapot")
	case(c, -8, -21, 4, "bulb")
	case(c, 8, -21, 5, "gear")
	wallCase(c, -1, -15)
	wallCase(c, 1, -15)
	hide(c, slotBack(d, o, -10))
	hide(c, slotBack(d, o, 10))
	ceil(c, 0, -15)
end

-- пустой зал: один постамент, на котором ничего нет
L.blank = function(c)
	Props.plinth(c.m, spot(c.d, c.origin, 0, -15), 3, 3)
	hide(c, slotBack(c.d, c.origin, 10))
	ceil(c, 0, -15)
end

L.figures = function(c)
	bench(c, -1, -12, 7)
	bench(c, 1, -12, 7)
	chandelier(c, 0, -20, 3)
	ceil(c, -10, -32)
	ceil(c, 10, -32)
end

-- очень длинный коридор без потолка: в стенах проломы, за ними только тьма
L.voidhall = function(c)
	local d, o = c.d, c.origin
	d.noCeiling = true
	d.gaps = { { side = -1, z = -40, w = 16 }, { side = 1, z = -80, w = 16 }, { side = -1, z = -118, w = 16 }, { side = 1, z = -152, w = 16 } }
	hide(c, slotL(d, o, -66))
	hide(c, slotR(d, o, -102))
	for k, g in d.gaps do
		local gp = P(c.m, "VoidGap", Vector3.new(1, d.h, g.w), at(o, g.side * (d.w / 2 + 1.5), d.h / 2, g.z), rgb(0, 0, 0), M.SmoothPlastic, nc({ Transparency = 1 }))
		gp:SetAttribute("Dir", o.RightVector * g.side)
		gp:SetAttribute("Width", g.w)
		game:GetService("CollectionService"):AddTag(gp, "VoidGap")
		-- обломки стены у пролома
		for j = -1, 1, 2 do
			P(c.m, "Rubble", Vector3.new(1.6, 1, 1.2), at(o, g.side * (d.w / 2 - 1.6), 0.5, g.z + j * (g.w / 2 + 0.2 + k * 0.1)) * CFrame.Angles(0, k + j, 0), rgb(96, 90, 84), M.Slate, nc())
		end
	end
	for k, z in { -18, -52, -96, -134, -168 } do
		local slot = if k % 2 == 1 then slotL else slotR
		local _, shade = Props.sconce(c.m, slot(d, o, z) * CFrame.new(0, 8, F - 0.6))
		table.insert(c.info.lights, shade)
	end
	-- чёрная оболочка далеко вокруг: в проломах и над головой только тьма
	local shell = Props.model(c.m, "VoidShell")
	local black = rgb(0, 0, 0)
	for _, s in { -1, 1 } do
		P(shell, "Dark", Vector3.new(2, 240, d.l + 80), at(o, s * 80, 0, -d.l / 2), black, M.SmoothPlastic, nc())
	end
	P(shell, "Dark", Vector3.new(164, 2, d.l + 80), at(o, 0, 110, -d.l / 2), black, M.SmoothPlastic, nc())
end

-- ---------------------------------------------------------------------------

function Builder.build(parent: Instance, d, origin: CFrame, prevInfo, rand)
	rand = rand or Plan.rng(d.door * 31 + 7)
	local st = Builder.style(d, rand)
	local m = Props.model(parent, string.format("Room_%03d", d.door))
	local info = { desc = d, model = m, origin = origin, hideSpots = {}, searchables = {}, tops = {}, lights = {} }
	Props.LIGHT = d.light or 1
	d.exitHole = d.exitHole or Props.DOORS[d.exitSize or "normal"]
	d.entry = d.entry or Props.DOORS[d.entrySize or "normal"]
	info.top = math.max(0, d.dy) + d.h
	local ctx = { d = d, origin = origin, m = m, info = info, hides = d.hides or 0 }
	local layout = L[d.kind]
	if layout then
		layout(ctx)
	end
	local sh = shell(m, d, origin, st, Builder.prevWallFor(prevInfo, origin))
	for k, v in sh do
		info[k] = v
	end
	info.style = st
	-- путь для Тьмы и точки для существ
	info.path = {
		at(origin, 0, 5, -2).Position,
		at(origin, 0, floorAt(d, -d.l / 2) + 5, -d.l / 2).Position,
		(info.exitCF * CFrame.new(0, 5, 2.5)).Position,
	}
	info.center = at(origin, 0, info.top / 2, -d.l / 2)
	info.size = Vector3.new(d.w, info.top - info.ybase, d.l)
	-- аномалия: весь зал одного цвета (кроме стекла и ламп)
	if d.mono then
		local col = Color3.fromHSV(rand(), 0.25, 0.3 + rand() * 0.4)
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and (p.Transparency or 0) < 0.5 and p.Material ~= M.Glass and p.Material ~= M.Neon then
				p.Color = col
				p.Material = M.SmoothPlastic
			end
		end
	end
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
