--!nonstrict
-- Постройка «The Castle». Замок стоит на парящем каменном острове посреди пустоты.
-- Главное здание 224 × 224 studs: подземный ярус и три этажа, на каждом сетка 7 × 7
-- клеток по 32 studs (план — CastleLayout). Стены, двери, окна, полы и потолки строятся
-- по плану, комнаты обставляются модулем Rooms. Отдельно строятся тронный зал с тайным
-- ходом, огромная подземная библиотека, тюрьма с работами, двор и крепостная стена

local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Layout = require(Shared.CastleLayout)
local Props = require(script.Parent.Props)
local Rooms = require(script.Parent.Rooms)

local B = {}

local rgb = Props.rgb
local P, C, S = Props.P, Props.C, Props.S
local M = require(game:GetService("ReplicatedStorage").Workshop.Shared.Materials)

local CELL, N, H = Layout.C, Layout.N, Layout.H
local HALF = Layout.HALF -- 112
local ISLAND = 176
local LV = Layout.LEVELS
local ROOF = LV.F2 + H -- 54

local FACADE = rgb(150, 144, 134)
local FACADE_DARK = rgb(108, 103, 97)
local CEIL = rgb(214, 204, 188)
local ROCK = rgb(92, 84, 76)

local root: Folder
local prompts = {}
B.prompts = prompts
B.points = {}

-- Кнопка взаимодействия; kind — смысл (CastleGame вешает действие по kind)
local function prompt(at: Instance?, kind: string, holdTime: number?, dist: number?)
	if not at then
		return nil
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = kind
	p.ActionText = ""
	p.ObjectText = ""
	p.HoldDuration = holdTime or 0
	p.MaxActivationDistance = dist or 9
	p.RequiresLineOfSight = false
	p:SetAttribute("Kind", kind)
	p.Parent = at
	local reg = B.activeRegistry or prompts
	reg[kind] = reg[kind] or {}
	table.insert(reg[kind], p)
	return p
end
B.prompt = prompt

local function box(parent, name, x0, y0, z0, x1, y1, z1, color, mat, extra)
	if math.abs(x1 - x0) < 0.01 or math.abs(y1 - y0) < 0.01 or math.abs(z1 - z0) < 0.01 then
		return nil
	end
	return P(parent, name, Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, mat or M.Slate, extra)
end
B.box = box
local roomSign

-- плита с прямоугольными дырами { x0, x1, z0, z1 } (не пересекающимися)
local function slab(parent, name, x0, x1, z0, z1, y0, y1, holes, color, mat, extra)
	if not holes or #holes == 0 then
		return box(parent, name, x0, y0, z0, x1, y1, z1, color, mat, extra)
	end
	local xs = { x0, x1 }
	for _, h in holes do
		table.insert(xs, math.clamp(h[1], x0, x1))
		table.insert(xs, math.clamp(h[2], x0, x1))
	end
	table.sort(xs)
	for k = 1, #xs - 1 do
		local a, b = xs[k], xs[k + 1]
		if b - a > 0.01 then
			local mid = (a + b) / 2
			local zs = { { z0, z1 } }
			for _, h in holes do
				if mid > h[1] and mid < h[2] then
					local nz = {}
					for _, seg in zs do
						if h[4] <= seg[1] or h[3] >= seg[2] then
							table.insert(nz, seg)
						else
							if h[3] > seg[1] then
								table.insert(nz, { seg[1], h[3] })
							end
							if h[4] < seg[2] then
								table.insert(nz, { h[4], seg[2] })
							end
						end
					end
					zs = nz
				end
			end
			for _, seg in zs do
				box(parent, name, a, y0, seg[1], b, y1, seg[2], color, mat, extra)
			end
		end
	end
	return nil
end
B.slab = slab

-- Стена в плоскости: axis "x" — плоскость X = plane (стена тянется вдоль Z), "z" — наоборот.
-- holes: { c, w, bottom, top } — проёмы вдоль стены
local function rect(parent, name, axis, plane, thick, a0, a1, y0, y1, holes, color, mat, extra)
	local function piece(a, b, ya, yb)
		if b - a < 0.01 or yb - ya < 0.01 then
			return
		end
		if axis == "x" then
			box(parent, name, plane - thick / 2, ya, a, plane + thick / 2, yb, b, color, mat, extra)
		else
			box(parent, name, a, ya, plane - thick / 2, b, yb, plane + thick / 2, color, mat, extra)
		end
	end
	local hs = {}
	for _, h in holes or {} do
		table.insert(hs, h)
	end
	table.sort(hs, function(p, q)
		return p[1] < q[1]
	end)
	local a = a0
	for _, h in hs do
		local h0, h1 = math.max(a0, h[1] - h[2] / 2), math.min(a1, h[1] + h[2] / 2)
		piece(a, h0, y0, y1)
		piece(h0, h1, y0, math.min(y1, h[3]))
		piece(h0, h1, math.max(y0, h[4]), y1)
		a = h1
	end
	piece(a, a1, y0, y1)
end
B.rect = rect

-- Факел на стене. cf — точка на стене, LookVector от стены
local function torch(parent, cf: CFrame)
	local m = Props.model(parent, "Torch")
	P(m, "Bracket", Vector3.new(0.5, 0.5, 1.2), cf * CFrame.new(0, 0, -0.6), Props.IRON, M.Metal, { CanCollide = false })
	local stick = P(m, "Stick", Vector3.new(0.35, 2, 0.35), cf * CFrame.new(0, 0.5, -1.2) * CFrame.Angles(math.rad(-20), 0, 0), Props.WOOD_DARK, M.Wood, { CanCollide = false })
	local head = P(m, "Flame", Vector3.new(0.5, 0.5, 0.5), stick.CFrame * CFrame.new(0, 1.1, 0), rgb(255, 150, 60), M.Neon, { CanCollide = false })
	local fire = Instance.new("Fire")
	fire.Size = 2.5
	fire.Heat = 6
	fire.Color = rgb(255, 140, 50)
	fire.SecondaryColor = rgb(255, 60, 20)
	fire.Parent = head
	Props.light(head, 20, 1.5, rgb(255, 160, 80))
	return m
end
B.torch = torch

-- ---------------------------------------------------------------------------
-- клетки и план

local function cellCenter(i, j)
	return (i - 3) * CELL, (j - 3) * CELL
end

local plans = {}
local function roomAt(level, i, j)
	if i < 0 or i > 6 or j < 0 or j > 6 then
		return "out", false
	end
	local id = plans[level].grid[i][j]
	if id == "void" then
		-- пустая клетка над залом двойной высоты принадлежит залу снизу
		local gid = plans.G.grid[i][j]
		return plans.G.rooms[gid], true
	end
	return plans[level].rooms[id], false
end

-- полоса лестницы внутри клетки: на первом этаже вдоль западной стены (подъём на север),
-- на втором — вдоль восточной (подъём на юг); спуски — у наружной стены
local function stairStrip(level, cx, cz, kind)
	local west = (level == "G" and kind == "stairs") or (kind == "stairs_down" and cx < 0)
	-- у наружной стены (толщина 2) полоса отодвинута, чтобы ступени не входили в стену
	local inset = if math.abs(cx) > 90 then 1.5 else 0
	if west then
		return cx - 15.5 + inset, cx - 9.5 + inset, true
	end
	return cx + 9.5 - inset, cx + 15.5 - inset, false
end

local function buildFlight(parent, x0, x1, zTop, zDir, yTop, yBottom, steps, color)
	-- ступени от верхнего края (zTop, yTop) по направлению zDir, каждая 1.5 в длину
	local rise = (yTop - yBottom) / steps
	for k = 0, steps - 1 do
		local za = zTop + zDir * k * 1.5
		local zb = za + zDir * 1.5
		local top = yTop - k * rise
		box(parent, "Step", x0, yBottom, math.min(za, zb), x1, top, math.max(za, zb), color, M.Marble)
		box(parent, "StepCarpet", x0 + 0.8, top, math.min(za, zb) + 0.05, x1 - 0.8, top + 0.08, math.max(za, zb) - 0.05, rgb(120, 22, 30), M.Carpet, { CanCollide = false })
	end
end

-- ---------------------------------------------------------------------------
-- остров в пустоте

local function island(parent)
	local m = Props.model(parent, "Island")
	local ground = rgb(120, 116, 110)
	local grotto = { 147, 157, 93, 99 }
	slab(m, "Ground", -ISLAND, ISLAND, -ISLAND, -HALF, -2, 0, nil, ground, M.Cobblestone)
	slab(m, "Ground", -ISLAND, ISLAND, HALF, ISLAND, -2, 0, nil, ground, M.Cobblestone)
	slab(m, "Ground", -ISLAND, -HALF, -HALF, HALF, -2, 0, nil, ground, M.Cobblestone)
	slab(m, "Ground", HALF, ISLAND, -HALF, HALF, -2, 0, { grotto }, ground, M.Cobblestone)
	-- скальная «юбка» по краю и толща под двором
	for _, s in { { -ISLAND, ISLAND, -ISLAND, -ISLAND + 6 }, { -ISLAND, ISLAND, ISLAND - 6, ISLAND }, { -ISLAND, -ISLAND + 6, -ISLAND, ISLAND }, { ISLAND - 6, ISLAND, -ISLAND, ISLAND } } do
		box(m, "Cliff", s[1], -26, s[3], s[2], -2, s[4], ROCK, M.Rock)
	end
	slab(m, "Bedrock", -ISLAND, ISLAND, -ISLAND, ISLAND, -60, -26, { { -HALF, HALF, -HALF, HALF } }, ROCK, M.Rock)
	box(m, "Bedrock", -HALF, -60, -HALF, HALF, -56, HALF, ROCK, M.Rock)
	-- низ острова: сужающиеся каменные пласты, как парящая скала
	local layers = { { 330, -60, -74 }, { 280, -74, -90 }, { 220, -90, -108 }, { 160, -108, -126 }, { 104, -126, -144 }, { 56, -144, -160 }, { 20, -160, -172 } }
	for k, l in ipairs(layers) do
		local w = l[1]
		P(m, "Underside", Vector3.new(w, l[2] - l[3], w * 0.92), CFrame.new(math.sin(k) * 6, (l[2] + l[3]) / 2, math.cos(k) * 6) * CFrame.Angles(0, k * 0.4, 0), ROCK:Lerp(rgb(60, 54, 50), k / 8), M.Rock)
		for q = 0, 5 do
			local a = q / 6 * math.pi * 2 + k
			local r = w * 0.42
			P(m, "Crag", Vector3.new(w * 0.22, (l[2] - l[3]) * 1.4, w * 0.18), CFrame.new(math.cos(a) * r, l[3] + 2, math.sin(a) * r) * CFrame.Angles(0.3, a, 0.2), ROCK:Lerp(rgb(70, 64, 58), (q % 3) / 3), M.Rock)
		end
	end
	-- корни и мох по краям
	for q = 0, 23 do
		local a = q / 24 * math.pi * 2
		local r = ISLAND - 2
		local x, z = math.clamp(math.cos(a) * r * 1.4, -r, r), math.clamp(math.sin(a) * r * 1.4, -r, r)
		P(m, "Root", Vector3.new(0.8, 10 + (q % 4) * 4, 0.8), CFrame.new(x, -31 - (q % 4) * 2, z) * CFrame.Angles(0.1 * (q % 3), 0, 0.1), rgb(70, 52, 36), M.Wood, { CanCollide = false })
	end
	return m
end

-- ---------------------------------------------------------------------------
-- стены, двери, окна, отделка

local function faceDecor(parent, axis, plane, normal, a0, a1, y0, y1, style, holes, opts)
	-- plane — поверхность стены, normal (+1/-1) — куда смотрит комната
	if style.bare then
		return
	end
	local function layer(thick, ya, yb, color, mat, name)
		if yb <= ya then
			return
		end
		rect(parent, name, axis, plane + normal * thick / 2, thick, a0, a1, ya, yb, holes, color, mat, { CanCollide = false, CanQuery = false })
	end
	local paperFrom = y0
	if opts.wainscot and style.plinth then
		-- каменный цоколь с карнизом: коридоры, залы, кухня, казармы
		layer(0.35, y0, y0 + 2.6, rgb(118, 110, 100), M.Cobblestone, "Plinth")
		layer(0.5, y0 + 2.6, y0 + 3, rgb(150, 142, 130), M.Limestone, "PlinthCap")
		paperFrom = y0 + 3
	elseif opts.wainscot then
		layer(0.25, y0, y0 + 4.4, Props.WOOD_DARK, M.Wood, "Wainscot")
		layer(0.42, y0 + 4.4, y0 + 4.8, Props.WOOD, M.Wood, "ChairRail")
		paperFrom = y0 + 4.8
	end
	layer(0.1, paperFrom, y1, style.paper, style.wall or M.Plaster, "Wallpaper")
	if opts.cornice then
		layer(0.6, y1 - 1.2, y1, CEIL:Lerp(rgb(0, 0, 0), 0.12), M.SmoothPlastic, "Cornice")
	end
end

local function styleOf(room)
	if not room or room == "out" then
		return { bare = true }
	end
	local st = Rooms.style(room.kind)
	if room.level == "U" then
		return { bare = true, floor = st.floor, mat = st.mat }
	end
	return st
end

local doorsAt = {}
local extraOpenings = {}

local function edgeKey(level, i, j, axis)
	return level .. ":" .. i .. "," .. j .. axis
end

-- Табличка над дверью: дубовая доска в железной раме, надпись на языке игрока
-- (клиент подставляет перевод по атрибуту RoomSign)
local ROOM_EN = {
	dining = "Dining hall", royal_dining = "Royal dining hall", kitchen = "Kitchen", servants = "Servants' quarters",
	shop = "Shop", casino = "Casino", barracks = "Barracks", training = "Training hall", chapel = "Chapel",
	chapel_small = "Chapel", stairs = "Stairs", stairs_down = "Stairs down", bedroom = "Bedroom", guest_suite = "Guest suite",
	study = "Study", sitting = "Sitting room", lounge = "Lounge", music = "Music room", reading = "Reading room",
	trophy = "Trophy room", gallery = "Gallery", nursery = "Nursery", wardrobe = "Wardrobe", bath = "Bath",
	observatory = "Observatory", treasury = "Treasury", council = "Council chamber", map_room = "Map room",
	king = "King's chambers", queen = "Queen's chambers", landing = "Landing", grand_hall = "Grand hall", throne = "Throne room",
}
B.ROOM_EN = ROOM_EN
roomSign = function(parent, pos: Vector3, facing: Vector3, kind: string)
	local m = Props.model(parent, "RoomSign")
	local cf = CFrame.lookAt(pos, pos + facing)
	local board = P(m, "Board", Vector3.new(7, 1.5, 0.25), cf, rgb(96, 64, 40), M.WoodPlanks, { CanCollide = false })
	P(m, "Frame", Vector3.new(7.4, 1.9, 0.15), cf * CFrame.new(0, 0, 0.12), Props.IRON, M.Metal, { CanCollide = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.6
	gui.Parent = board
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.Fantasy
	t.TextScaled = true
	t.TextColor3 = rgb(236, 208, 140)
	t.Text = ROOM_EN[kind] or kind
	t:SetAttribute("RoomSign", kind)
	t.Parent = gui
	return m
end

-- Все стены одного яруса
local function buildWalls(parent, level, decor)
	local y = LV[level]
	local y0, y1 = y - 1, y + H - 1
	local function interior(i, j, axis)
		local a, voidA = roomAt(level, i, j)
		local ni, nj = if axis == "x" then i + 1 else i, if axis == "z" then j + 1 else j
		local b, voidB = roomAt(level, ni, nj)
		if a == b then
			return
		end
		local cx, cz = cellCenter(i, j)
		local plane = if axis == "x" then cx + CELL / 2 else cz + CELL / 2
		local along = if axis == "x" then cz else cx
		local holes = {}
		local door = doorsAt[edgeKey(level, i, j, axis)]
		local extra = extraOpenings[edgeKey(level, i, j, axis)]
		local dw, dh = 0, 0
		if door then
			dw, dh = if door.wide then 10 else 6, if door.wide then 14 else 10
			table.insert(holes, { along, dw, y - 2, y + dh })
		elseif extra then
			dw, dh = extra.w, extra.h
			table.insert(holes, { along, dw, y - 2, y + dh })
		end
		rect(parent, "Wall", axis, plane, 1, along - CELL / 2, along + CELL / 2, y0, y1, holes, rgb(160, 152, 140), if level == "U" then M.Cobblestone else M.Slate)
		local dHoles = {}
		if door or extra then
			table.insert(dHoles, { along, dw + 1.8, y - 2, y + dh + 1.2 })
		end
		local tallA = type(a) == "table" and a.tall and not voidA
		local tallB = type(b) == "table" and b.tall and not voidB
		faceDecor(decor, axis, plane - 0.5, -1, along - CELL / 2, along + CELL / 2, if voidA then y0 else y, y1, styleOf(a), dHoles, { wainscot = not voidA, cornice = not tallA })
		faceDecor(decor, axis, plane + 0.5, 1, along - CELL / 2, along + CELL / 2, if voidB then y0 else y, y1, styleOf(b), dHoles, { wainscot = not voidB, cornice = not tallB })
		if door then
			local pos = if axis == "x" then Vector3.new(plane, y, along) else Vector3.new(along, y, plane)
			local n = if axis == "x" then Vector3.xAxis else Vector3.zAxis
			Props.door(decor, CFrame.lookAt(pos, pos + n), dw, dh, nil, door.wide)
			-- табличка с названием комнаты над дверью со стороны коридора
			local ta, tb = type(a) == "table" and not voidA, type(b) == "table" and not voidB
			if ta and tb and (a.kind == "hall") ~= (b.kind == "hall") and dh + 3.6 < H - 1.3 then
				local room = if a.kind == "hall" then b else a
				local side = if a.kind == "hall" then -1 else 1
				roomSign(decor, pos + n * side * 0.75 + Vector3.new(0, dh + 2.6, 0), n * side, room.kind)
			end
		end
	end
	local function exterior(i, j, dir: Vector3)
		local a, voidA = roomAt(level, i, j)
		local cx, cz = cellCenter(i, j)
		local axis = if dir.X ~= 0 then "x" else "z"
		local sign = if axis == "x" then dir.X else dir.Z
		local edge = if axis == "x" then cx + sign * CELL / 2 else cz + sign * CELL / 2
		local plane = edge - sign * 1
		local along = if axis == "x" then cz else cx
		local holes = {}
		local windowAt = nil
		local extra = extraOpenings[edgeKey(level, i, j, axis .. (if sign > 0 then "+" else "-"))]
		if extra then
			table.insert(holes, { along, extra.w, y - 2, y + extra.h })
		elseif level ~= "U" and type(a) == "table" and a.kind ~= "stairs" and a.kind ~= "stairs_down" then
			windowAt = y + 8
			table.insert(holes, { along, 5, y + 4, y + 12 })
		end
		rect(parent, "OuterWall", axis, plane, 2, along - CELL / 2, along + CELL / 2, y0, y1, holes, FACADE, M.Slate)
		local dHoles = {}
		if windowAt then
			table.insert(dHoles, { along, 7, y + 3.4, y + 12.8 })
		elseif extra then
			table.insert(dHoles, { along, extra.w + 1.8, y - 2, y + extra.h + 1.2 })
		end
		local st = styleOf(a)
		local tallA = type(a) == "table" and a.tall and not voidA
		faceDecor(decor, axis, plane - sign * 1, -sign, along - CELL / 2, along + CELL / 2, if voidA then y0 else y, y1, st, dHoles, { wainscot = not voidA, cornice = not tallA })
		local out = if axis == "x" then Vector3.new(sign, 0, 0) else Vector3.new(0, 0, sign)
		if windowAt then
			local pos = if axis == "x" then Vector3.new(plane, windowAt, along) else Vector3.new(along, windowAt, plane)
			Props.window(decor, CFrame.lookAt(pos, pos + out), 5, 8, 2)
			if not st.bare then
				Props.curtains(decor, CFrame.lookAt(pos - out * 1.1, pos - out * 2), 5, 8, st.rug or rgb(120, 22, 30))
			end
		end
		if extra and extra.door then
			local pos = if axis == "x" then Vector3.new(plane, y, along) else Vector3.new(along, y, plane)
			Props.door(decor, CFrame.lookAt(pos, pos + out), extra.w, extra.h, Props.WOOD_DARK, true)
		end
	end
	for i = 0, 6 do
		for j = 0, 6 do
			if i < 6 then
				interior(i, j, "x")
			end
			if j < 6 then
				interior(i, j, "z")
			end
			if i == 0 then
				exterior(i, j, Vector3.new(-1, 0, 0))
			end
			if i == 6 then
				exterior(i, j, Vector3.new(1, 0, 0))
			end
			if j == 0 then
				exterior(i, j, Vector3.new(0, 0, -1))
			end
			if j == 6 then
				exterior(i, j, Vector3.new(0, 0, 1))
			end
		end
	end
end

-- Описание комнаты для обстановки: границы, клетки и участки стен со слотами
local function roomInfo(level, room)
	local y = LV[level]
	local info = { kind = room.kind, id = room.id, level = level, y = y, h = if room.tall then 2 * H - 1 else H - 1, cells = {}, segs = {} }
	local cells = room.cells or {}
	if #cells == 0 then
		for i = room.i0, room.i1 do
			for j = room.j0, room.j1 do
				table.insert(cells, { i, j })
			end
		end
	end
	local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
	for _, c in cells do
		local cx, cz = cellCenter(c[1], c[2])
		table.insert(info.cells, { x = cx, z = cz, i = c[1], j = c[2] })
		x0, x1 = math.min(x0, cx - CELL / 2 + 0.5), math.max(x1, cx + CELL / 2 - 0.5)
		z0, z1 = math.min(z0, cz - CELL / 2 + 0.5), math.max(z1, cz + CELL / 2 - 0.5)
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local ni, nj = c[1] + d[1], c[2] + d[2]
			local other = roomAt(level, ni, nj)
			if other ~= room then
				local outside = other == "out"
				local inset = if outside then 2 else 0.5
				local n = Vector3.new(-d[1], 0, -d[2])
				local pos = Vector3.new(cx + d[1] * (CELL / 2 - inset), y, cz + d[2] * (CELL / 2 - inset))
				local axis = if d[1] ~= 0 then "x" else "z"
				local ei, ej = c[1], c[2]
				if d[1] < 0 or d[2] < 0 then
					ei, ej = ni, nj
				end
				local opening = nil
				if outside then
					if extraOpenings[edgeKey(level, c[1], c[2], axis .. (if d[1] + d[2] > 0 then "+" else "-"))] then
						opening = "door"
					elseif level ~= "U" then
						opening = "window"
					end
				elseif doorsAt[edgeKey(level, ei, ej, axis)] or extraOpenings[edgeKey(level, ei, ej, axis)] then
					opening = "door"
				end
				table.insert(info.segs, { pos = pos, inward = n, tangent = Vector3.new(n.Z, 0, -n.X), opening = opening })
			end
		end
	end
	info.x0, info.x1, info.z0, info.z1 = x0, x1, z0, z1
	return info
end

-- Полы, потолки, лестницы и обстановка одного яруса
local function buildLevel(parent, level, ctx)
	local y = LV[level]
	local plan = plans[level]
	local floors = Props.model(parent, "Floors")
	local decor = Props.model(parent, "Decor")
	buildWalls(parent, level, decor)
	for i = 0, 6 do
		for j = 0, 6 do
			local room, void = roomAt(level, i, j)
			local cx, cz = cellCenter(i, j)
			local holes = {}
			-- дыра над лестницей с нижнего яруса
			local below, belowLevel = nil, nil
			if level == "F1" then
				below, belowLevel = plans.G.rooms[plans.G.grid[i][j]], "G"
			elseif level == "F2" then
				local id = plans.F1.grid[i][j]
				below, belowLevel = (if id ~= "void" then plans.F1.rooms[id] else nil), "F1"
			end
			if below and below.kind == "stairs" then
				local sx0, sx1 = stairStrip(belowLevel, cx, cz, "stairs")
				table.insert(holes, { sx0, sx1, cz - 13.5, cz + 13.5 })
			end
			if room and not void and room.kind == "stairs_down" and not ctx.noBasement then
				local sx0, sx1 = stairStrip(level, cx, cz, "stairs_down")
				table.insert(holes, { sx0, sx1, cz - 13.5, cz + 13.5 })
			end
			if type(room) == "table" and not void and not room.special then
				local st = styleOf(room)
				slab(floors, "Floor", cx - CELL / 2, cx + CELL / 2, cz - CELL / 2, cz + CELL / 2, y - 1, y, holes, st.floor or rgb(110, 104, 98), st.mat or M.Slate)
				-- потолок: светлая штукатурка (или камень в подвале), балки или кессоны
				local ceilY = y + (if room.tall then 2 * H else H) - 1
				local ceilHoles = {}
				local aboveDown = level == "U" and plans.G.rooms[plans.G.grid[i][j]].kind == "stairs_down"
				if room.kind == "stairs" and ctx.topLevel ~= level then
					local sx0, sx1 = stairStrip(level, cx, cz, "stairs")
					table.insert(ceilHoles, { sx0, sx1, cz - 13.5, cz + 13.5 })
				elseif aboveDown then
					local sx0, sx1 = stairStrip("G", cx, cz, "stairs_down")
					table.insert(ceilHoles, { sx0, sx1, cz - 13.5, cz + 13.5 })
				end
				slab(floors, "Ceiling", cx - CELL / 2, cx + CELL / 2, cz - CELL / 2, cz + CELL / 2, ceilY - 0.25, ceilY, ceilHoles, if level == "U" then rgb(90, 86, 80) else CEIL, if level == "U" then M.Cobblestone else M.SmoothPlastic, { CanCollide = false })
				local k = room.kind
				if aboveDown then
					local _ = 0
				elseif level == "U" or k == "kitchen" or k == "barracks" or k == "servants" or k == "training" or k == "hall" or k == "dining" then
					-- тёмные деревянные балки поперёк потолка
					for b = -1, 1 do
						box(floors, "Beam", cx - CELL / 2, ceilY - 1.4, cz + b * 10 - 0.6, cx + CELL / 2, ceilY - 0.25, cz + b * 10 + 0.6, if level == "U" then rgb(80, 76, 70) else Props.WOOD_DARK, if level == "U" then M.Slate else M.Wood, { CanCollide = false })
					end
				end
			end
			-- лестницы
			local skipFlight = type(room) == "table" and ((room.kind == "stairs_down" and ctx.noBasement) or (room.kind == "stairs" and ctx.topLevel == level))
			if type(room) == "table" and not void and not skipFlight and (room.kind == "stairs" or room.kind == "stairs_down") then
				local sx0, sx1, west = stairStrip(level, cx, cz, room.kind)
				local col = rgb(196, 188, 176)
				local inner = if west then sx1 else sx0
				local ang = math.atan2(H, 27)
				if room.kind == "stairs" then
					if west then
						buildFlight(decor, sx0, sx1, cz + 13.5, -1, y + H, y, 18, col)
					else
						buildFlight(decor, sx0, sx1, cz - 13.5, 1, y + H, y, 18, col)
					end
					local tilt = if west then -ang else ang
					P(decor, "StairRail", Vector3.new(0.5, 0.35, 32.4), CFrame.new(inner, y + H / 2 + 3.4, cz) * CFrame.Angles(tilt, 0, 0), Props.WOOD_DARK, M.Wood)
				else
					buildFlight(decor, sx0, sx1, cz + 13.5, -1, y, y - H, 18, col)
					P(decor, "StairRail", Vector3.new(0.5, 0.35, 32.4), CFrame.new(inner, y - H / 2 + 3.4, cz) * CFrame.Angles(ang, 0, 0), Props.WOOD_DARK, M.Wood)
					Props.railing(decor, Vector3.new(inner, y, cz - 13.5), Vector3.new(inner, y, cz + 10))
					Props.railing(decor, Vector3.new(sx0, y, cz - 13.7), Vector3.new(sx1, y, cz - 13.7))
				end
			end
			if below and below.kind == "stairs" then
				local sx0, sx1, west = stairStrip(belowLevel, cx, cz, "stairs")
				local inner = if west then sx1 else sx0
				if west then
					Props.railing(decor, Vector3.new(inner, y, cz - 13.5), Vector3.new(inner, y, cz + 10))
					Props.railing(decor, Vector3.new(sx0, y, cz - 13.7), Vector3.new(sx1, y, cz - 13.7))
				else
					Props.railing(decor, Vector3.new(inner, y, cz - 10), Vector3.new(inner, y, cz + 13.5))
					Props.railing(decor, Vector3.new(sx0, y, cz + 13.7), Vector3.new(sx1, y, cz + 13.7))
				end
			end
		end
	end
	-- обстановка комнат
	for id, room in plan.rooms do
		local info = roomInfo(level, room)
		if room.kind == "hall" then
			for _, c in info.cells do
				local nb = {
					px = c.i < 6 and plan.grid[c.i + 1][c.j] == id,
					nx = c.i > 0 and plan.grid[c.i - 1][c.j] == id,
					pz = c.j < 6 and plan.grid[c.i][c.j + 1] == id,
					nz = c.j > 0 and plan.grid[c.i][c.j - 1] == id,
				}
				-- дорожка заходит и в двери соседних комнат, где они есть
				Rooms.hallCell(decor, c, info, ctx, nb)
			end
			Rooms.hallWalls(decor, info, id)
		elseif room.kind == "stairs" or room.kind == "stairs_down" or room.kind == "prison_guard" then
			local c = info.cells[1]
			local sx0 = stairStrip(level, c.x, c.z, if room.kind == "prison_guard" then "stairs_down" else room.kind)
			Props.ceilingLamp(decor, Vector3.new(c.x + (if sx0 < c.x then 5 else -5), y + H - 3.5, c.z), 2.5)
			if room.kind == "prison_guard" then
				B.points.dungeon = CFrame.new(c.x + 5, y + 3, c.z + 6)
			end
		elseif not room.special then
			Rooms.decorate(decor, info, ctx)
		end
		room.info = info
	end
end

-- ---------------------------------------------------------------------------
-- тронный зал (G, клетки 2..4 × 4..6), тайный ход и сточный туннель

local function throneRoom(parent)
	local m = Props.model(parent, "ThroneRoom")
	local x0, x1, z0, z1 = -48, 48, 16, 112
	local hx0, hx1, hz0, hz1 = -5, 5, 95, 105
	local tx, tz = 0, 100
	slab(m, "Floor", x0, x1, z0, z1, -1, 0, { { hx0, hx1, hz0, hz1 } }, rgb(206, 198, 186), M.Marble)
	for gx = -4, 3 do
		for gz = 0, 7 do
			if (gx + gz) % 2 == 0 then
				box(m, "Tile", gx * 6, 0, 20 + gz * 6, gx * 6 + 6, 0.05, 26 + gz * 6, rgb(60, 56, 54), M.Marble, { CanCollide = false })
			end
		end
	end
	local ceilY = 2 * H - 1
	box(m, "Ceiling", x0, ceilY - 0.3, z0, x1, ceilY, z1, rgb(110, 30, 36), M.SmoothPlastic, { CanCollide = false })
	for k = 0, 5 do
		box(m, "Rib", x0, ceilY - 1.6, z0 + 8 + k * 16 - 0.7, x1, ceilY - 0.3, z0 + 8 + k * 16 + 0.7, Props.GOLD, M.Metal, { CanCollide = false })
	end
	Props.runner(m, CFrame.new(0, 0, 51), 8, 70, rgb(140, 20, 28))
	for _, sx in { -1, 1 } do
		for k = 0, 4 do
			Props.column(m, CFrame.new(sx * 30, 0, 24 + k * 14), ceilY, 2)
			Props.banner(m, CFrame.new(sx * 47.3, 28, 24 + k * 14) * CFrame.Angles(0, if sx > 0 then math.pi / 2 else -math.pi / 2, 0), 16, if k % 2 == 0 then rgb(130, 20, 28) else rgb(30, 46, 110))
		end
		for k = 0, 3 do
			Props.sconce(m, CFrame.new(sx * 47.4, 10, 31 + k * 24) * CFrame.Angles(0, if sx > 0 then math.pi / 2 else -math.pi / 2, 0), k % 2 == 0)
		end
	end
	for k = 0, 2 do
		Props.chandelier(m, Vector3.new(0, ceilY - 9, 34 + k * 26), 8, 9.3)
	end
	-- помост в две ступени с дырой под люк
	slab(m, "Dais", -20, 20, 86, 111, 0, 1.5, { { hx0, hx1, hz0, hz1 } }, rgb(150, 26, 34), M.Carpet)
	slab(m, "DaisStep", -17, 17, 90, 111, 1.5, 3, { { hx0, hx1, hz0, hz1 } }, rgb(206, 198, 186), M.Marble)
	for _, sx in { -1, 1 } do
		P(m, "DaisTrim", Vector3.new(0.4, 0.3, 25), CFrame.new(sx * 20, 1.6, 98.5), Props.GOLD, M.Metal, { CanCollide = false })
	end
	-- за троном огромный гобелен и витражи
	Props.banner(m, CFrame.new(0, 33, 109.8), 22, rgb(140, 20, 28))
	for _, x in { -18, 18 } do
		Props.stainedGlass(m, CFrame.new(x, 21, 109.8), 7, 14)
	end
	local hatch = box(m, "Hatch", hx0, -1, hz0, hx1, 3.02, hz1, rgb(206, 198, 186), M.Marble)
	B.hatch = hatch
	-- трон
	local throne = Instance.new("Model")
	throne.Name = "Throne"
	local seat = Instance.new("Seat")
	seat.Name = "ThroneSeat"
	seat.Anchored = true
	seat.Size = Vector3.new(4, 1, 4)
	seat.CFrame = CFrame.new(tx, 4.5, tz)
	seat.Color = rgb(150, 20, 30)
	seat.Material = M.Leather
	seat.Disabled = true
	seat.Parent = throne
	P(throne, "ThroneBase", Vector3.new(5.4, 1.5, 5.4), CFrame.new(tx, 3.75, tz), Props.GOLD, M.Metal)
	P(throne, "ThroneBack", Vector3.new(5.4, 11, 1), CFrame.new(tx, 10, tz + 2.6), Props.GOLD, M.Metal)
	P(throne, "ThroneCushion", Vector3.new(4.2, 7.5, 0.4), CFrame.new(tx, 9.2, tz + 2), rgb(150, 20, 30), M.SmoothPlastic)
	for _, x in { -2.8, 2.8 } do
		P(throne, "Arm", Vector3.new(0.8, 2.5, 4.6), CFrame.new(tx + x, 5.6, tz), Props.GOLD, M.Metal)
		S(throne, "ArmKnob", 1, CFrame.new(tx + x, 7, tz - 2.3), Props.GOLD, M.Metal)
		C(throne, "Finial", 2.4, 0.6, CFrame.new(tx + x, 16.6, tz + 2.6), Props.GOLD, M.Metal)
	end
	S(throne, "Crest", 2.4, CFrame.new(tx, 16.4, tz + 2.6), Props.GOLD, M.Neon)
	for k = 0, 4 do
		S(throne, "Gem", 0.5, CFrame.new(tx - 1.6 + k * 0.8, 14.5, tz + 2.05), if k % 2 == 0 then rgb(200, 30, 50) else rgb(40, 90, 220), M.Neon)
	end
	throne.PrimaryPart = seat
	throne.Parent = m
	prompt(seat, "throne", 1, 10)
	prompt(throne:FindFirstChild("ThroneBack"), "passage", 1.5, 10)
	B.throne = throne
	B.throneSeat = seat
	B.throneHome = throne:GetPivot()
	B.throneSlide = Vector3.new(14, 0, 0)
	B.points.statueLeft = CFrame.new(-15, 2.5, 76)
	B.points.statueRight = CFrame.new(15, 2.5, 76)
	for _, x in { -15, 15 } do
		box(m, "StatueBase", x - 3.5, 0, 72.5, x + 3.5, 2, 79.5, rgb(220, 214, 204), M.Marble)
		box(m, "StatueBaseTrim", x - 3.8, 1.8, 72.2, x + 3.8, 2.5, 79.8, Props.GOLD, M.Metal)
		box(m, "StatueBasePlinth", x - 4, 0, 72, x + 4, 0.5, 80, rgb(120, 112, 104), M.Granite)
	end
	B.points.throneRoom = CFrame.new(0, 3, 30)

	-- винтовая лестница в шахте под люком, вниз до сточного туннеля
	local sh = Props.model(parent, "SecretStair")
	local uy = LV.U
	local wc = rgb(90, 86, 80)
	box(sh, "ShaftWall", -5.5, uy - 1, 94.5, -5, -1, 105.5, wc, M.Cobblestone)
	box(sh, "ShaftWall", -5, uy - 1, 94.5, 5, -1, 95, wc, M.Cobblestone)
	box(sh, "ShaftWall", -5, uy - 1, 105, 5, -1, 105.5, wc, M.Cobblestone)
	-- восточная стенка с проходом в туннель внизу
	box(sh, "ShaftWall", 5, uy + 9, 94.5, 5.5, -1, 105.5, wc, M.Cobblestone)
	box(sh, "ShaftWall", 5, uy - 1, 94.5, 5.5, uy + 9, 97.5, wc, M.Cobblestone)
	box(sh, "ShaftWall", 5, uy - 1, 102.5, 5.5, uy + 9, 105.5, wc, M.Cobblestone)
	C(sh, "Newel", 3 - uy, 1.8, CFrame.new(tx, (3 + uy) / 2, tz), rgb(120, 114, 106), M.Slate)
	local steps = 28
	for k = 0, steps - 1 do
		local a = k * math.rad(22.5)
		local top = 3 - (k + 1) * (3 - uy) / steps
		P(sh, "SpiralStep", Vector3.new(4.1, 1.6, 2.6), CFrame.new(tx, top - 0.8, tz) * CFrame.Angles(0, a, 0) * CFrame.new(2.95, 0, 0), rgb(150, 144, 134), M.Slate)
		P(sh, "StepNosing", Vector3.new(4.1, 0.15, 0.3), CFrame.new(tx, top + 0.02, tz) * CFrame.Angles(0, a, 0) * CFrame.new(2.95, 0, -1.2), rgb(120, 22, 30), M.Carpet, { CanCollide = false })
		if k % 7 == 3 then
			local tp = (CFrame.new(tx, top + 5, tz) * CFrame.Angles(0, a + 0.4, 0) * CFrame.new(4.9, 0, 0)).Position
			torch(sh, CFrame.lookAt(tp, Vector3.new(tx, tp.Y, tz)))
		end
	end
	local lever = Props.model(sh, "Lever")
	-- рычаг закреплён на восточной стенке шахты со стороны туннеля, рядом с проходом
	P(lever, "Plate", Vector3.new(0.3, 1.8, 1.2), CFrame.new(5.65, uy + 4, 104), Props.IRON, M.Metal)
	P(lever, "Pivot", Vector3.new(0.4, 0.4, 0.4), CFrame.new(5.95, uy + 4, 104), Props.IRON, M.Metal)
	local handle = P(lever, "Handle", Vector3.new(0.25, 2, 0.25), CFrame.new(6.0, uy + 4, 104) * CFrame.Angles(0, 0, math.rad(-25)) * CFrame.new(0, 0.95, 0), rgb(150, 150, 156), M.Metal)
	S(lever, "Grip", 0.6, (CFrame.new(6.0, uy + 4, 104) * CFrame.Angles(0, 0, math.rad(-25)) * CFrame.new(0, 2, 0)), rgb(120, 22, 30), M.SmoothPlastic)
	prompt(handle, "lever", 0.5)
	B.points.tunnel = CFrame.new(20, uy + 3, 96)
	-- перила вокруг люка: появляются, только когда ход открыт
	B.hatchRails = {}
	for _, r in { { -5, -5, 95, 105 }, { -5, 5, 105, 105 }, { -5, 5, 95, 95 } } do
		local rail = Props.railing(m, Vector3.new(r[1], 3, r[3]), Vector3.new(r[2], 3, r[4]), Props.GOLD)
		for _, d in rail:GetDescendants() do
			if d:IsA("BasePart") then
				d:SetAttribute("BaseTransparency", d.Transparency)
				d.Transparency = 1
				d.CanCollide = false
				table.insert(B.hatchRails, d)
			end
		end
	end
	-- свет внизу шахты
	local glow = P(sh, "ShaftLight", Vector3.new(1, 1, 1), CFrame.new(-3.5, uy + 8, 100), rgb(255, 190, 110), M.Neon, { CanCollide = false })
	Props.light(glow, 18, 1.4)
end

-- Сточный туннель (U, клетки 3..6 × 6) и выход в грот на краю острова
local function sewer(parent)
	local m = Props.model(parent, "Sewer")
	local uy = LV.U
	local x0, x1, z0, z1 = -15.5, HALF - 2, 80.5, 110
	box(m, "Floor", x0, uy - 1, z0, x1, uy, 93, rgb(86, 82, 76), M.Cobblestone)
	box(m, "Floor", x0, uy - 1, 99, x1, uy, z1, rgb(86, 82, 76), M.Cobblestone)
	box(m, "Floor", x0, uy - 1, 93, 8, uy, 99, rgb(86, 82, 76), M.Cobblestone)
	box(m, "Channel", 8, uy - 2.5, 93, x1, uy - 1, 99, rgb(60, 56, 52), M.Slate)
	box(m, "Water", 8, uy - 1.6, 93.1, x1, uy - 1.2, 98.9, rgb(70, 82, 60), M.Glass, { Transparency = 0.3, CanCollide = false })
	-- мостки над каналом
	for x = 20, x1 - 10, 24 do
		box(m, "Plank", x - 2, uy - 0.2, 93, x + 2, uy, 99, Props.WOOD, M.WoodPlanks)
	end
	-- арки-рёбра через каждые 8 studs, решётки, трубы, факелы
	for x = 12, x1 - 4, 8 do
		box(m, "Rib", x - 0.8, uy, z0, x + 0.8, -1.5, z0 + 1.5, rgb(110, 104, 96), M.Slate)
		box(m, "Rib", x - 0.8, uy, z1 - 1.5, x + 0.8, -1.5, z1, rgb(110, 104, 96), M.Slate)
		box(m, "Rib", x - 0.8, -3.2, z0, x + 0.8, -1.5, z1, rgb(110, 104, 96), M.Slate, { CanCollide = false })
		if (x - x0) % 24 < 8 then
			torch(m, CFrame.new(x + 4, uy + 7, z0 + 0.1) * CFrame.Angles(0, math.pi, 0))
		end
		P(m, "Pipe", Vector3.new(8, 1.2, 1.2), CFrame.new(x - 4, uy + 12, z1 - 1.2), rgb(110, 80, 50), M.Metal, { CanCollide = false, Shape = Enum.PartType.Cylinder })
	end
	for k = 0, 8 do
		Props.barrel(m, CFrame.new(x0 + 26 + k * 10, uy, z0 + 3.5), k % 3 == 0)
	end
	-- туннель под двором и лестница наверх, в грот
	local t = Props.model(parent, "EscapeTunnel")
	local wc = rgb(90, 86, 80)
	box(t, "Floor", HALF, uy - 1, 93, 130, uy, 99, rgb(86, 82, 76), M.Cobblestone)
	box(t, "Wall", HALF, uy - 1, 92, 158, -2, 93, wc, M.Cobblestone)
	box(t, "Wall", HALF, uy - 1, 99, 158, -2, 100, wc, M.Cobblestone)
	box(t, "Ceiling", HALF, uy + 10, 93, 145, uy + 11, 99, rgb(80, 76, 70), M.Cobblestone)
	for k = 0, 17 do
		local xa = 130 + k * 1.5
		box(t, "Step", xa, uy - 1, 93, xa + 1.5, uy + (k + 1), 99, rgb(110, 104, 96), M.Slate)
	end
	torch(t, CFrame.new(121, uy + 6, 93.1))
	torch(t, CFrame.new(133, uy + 7, 93.1))
	torch(t, CFrame.new(150, uy + 15, 93.1))
	torch(t, CFrame.new(140, uy + 9, 98.9) * CFrame.Angles(0, math.pi, 0))
	-- грот: камни вокруг выхода, арка, плющ
	local g = Props.model(parent, "Grotto")
	for k = 0, 4 do
		for _, z in { 89.5, 102.5 } do
			S(g, "Rock", 5 + (k % 3) * 1.2, CFrame.new(145 + k * 3.2, 1.5 + (k % 2), z), ROCK:Lerp(rgb(130, 124, 116), (k % 4) / 5), M.Rock)
		end
	end
	P(g, "Arch", Vector3.new(12, 3, 16), CFrame.new(150, 8.5, 96), ROCK, M.Rock)
	for k = 0, 5 do
		P(g, "Ivy", Vector3.new(0.3, 4, 1.2), CFrame.new(156.2, 5, 91.5 + k * 1.8), rgb(60, 100, 50), M.Grass, { CanCollide = false })
	end
	B.points.tunnelExit = CFrame.new(163, 3, 96)
	local lanternPost = P(g, "Lantern", Vector3.new(1, 1.4, 1), CFrame.new(159, 5, 91), rgb(255, 200, 120), M.Neon, { CanCollide = false })
	Props.light(lanternPost, 24, 1.6)
end

-- ---------------------------------------------------------------------------
-- огромная библиотека под главным залом (U, клетки 2..6 × 0..4, три яруса)

local function library(parent)
	local m = Props.model(parent, "Library")
	local x0, x1, z0, z1 = -47.5, HALF - 2, -HALF + 2, 47.5
	local fy = -54
	local G1, G2 = -36, LV.U
	local W = 12
	box(m, "Floor", x0, fy - 1, z0, x1, fy, z1, rgb(70, 64, 60), M.Slate)
	for gx = 0, 9 do
		for gz = 0, 9 do
			if (gx + gz) % 2 == 0 then
				box(m, "FloorTile", x0 + W + gx * 11.4, fy, z0 + W + gz * 11.4, x0 + W + gx * 11.4 + 11.4, fy + 0.04, z0 + W + gz * 11.4 + 11.4, rgb(96, 88, 80), M.Marble, { CanCollide = false })
			end
		end
	end
	-- стены от пола до верхней галереи (выше — стены подземного яруса)
	local wc, wm = rgb(84, 74, 66), M.Slate
	box(m, "Wall", x0 - 1, fy - 1, z0 - 1, x0, G2, z1 + 1, wc, wm)
	box(m, "Wall", x1, fy - 1, z0 - 1, x1 + 1, G2, z1 + 1, wc, wm)
	box(m, "Wall", x0, fy - 1, z0 - 1, x1, G2, z0, wc, wm)
	box(m, "Wall", x0, fy - 1, z1, x1, G2, z1 + 1, wc, wm)
	-- галереи: кольцо шириной 12 на двух уровнях, с проёмами под лестницы
	local flight1 = { x0 + 1, x0 + 7, -10, 17 } -- с верхней галереи на среднюю (запад)
	local flight2 = { x1 - 7, x1 - 1, -10, 17 } -- со средней на пол (восток)
	local inner = { x0 + W, x1 - W, z0 + W, z1 - W }
	for _, gy in { G1, G2 } do
		local holes = { inner, if gy == G2 then flight1 else flight2 }
		slab(m, "Gallery", x0, x1, z0, z1, gy - 1, gy, holes, rgb(96, 70, 50), M.Slate)
		Props.railing(m, Vector3.new(inner[1], gy, inner[3]), Vector3.new(inner[2], gy, inner[3]))
		Props.railing(m, Vector3.new(inner[1], gy, inner[4]), Vector3.new(inner[2], gy, inner[4]))
		Props.railing(m, Vector3.new(inner[1], gy, inner[3]), Vector3.new(inner[1], gy, inner[4]))
		Props.railing(m, Vector3.new(inner[2], gy, inner[3]), Vector3.new(inner[2], gy, inner[4]))
		local fl = if gy == G2 then flight1 else flight2
		Props.railing(m, Vector3.new(fl[2], gy, fl[3]), Vector3.new(fl[2], gy, fl[4] - 3))
	end
	for k = 0, 17 do
		box(m, "Step", flight1[1], G1, 17 - (k + 1) * 1.5, flight1[2], G2 - k, 17 - k * 1.5, rgb(110, 84, 60), M.Slate)
		box(m, "Step", flight2[1], fy, 17 - (k + 1) * 1.5, flight2[2], G1 - k, 17 - k * 1.5, rgb(110, 84, 60), M.Slate)
	end
	-- колонны по внутреннему краю галерей
	local dx = (inner[2] - inner[1]) / 5
	local dz = (inner[4] - inner[3]) / 5
	for k = 0, 5 do
		for _, z in { inner[3], inner[4] } do
			Props.column(m, CFrame.new(inner[1] + k * dx, fy, z), G2 - fy - 1, 1.3, rgb(120, 108, 96))
		end
	end
	for k = 1, 4 do
		for _, x in { inner[1], inner[2] } do
			Props.column(m, CFrame.new(x, fy, inner[3] + k * dz), G2 - fy - 1, 1.3, rgb(120, 108, 96))
		end
	end
	-- шкафы вдоль стен на всех трёх уровнях
	local seed = 1
	local function run(a0, a1, place)
		local a = a0
		while a + 8 <= a1 do
			place(a + 4)
			a += 8.4
		end
	end
	local function wallShelves(level)
		run(z0 + 1, z1 - 1, function(z)
			local blocked = level ~= fy and z > flight1[3] - 2 and z < flight1[4] + 2 and false
			if not blocked then
				Props.bookshelf(m, CFrame.new(x0 + 1.1, level, z) * CFrame.Angles(0, -math.pi / 2, 0), 8, 14, seed, true)
			end
			seed += 1
		end)
		run(z0 + 1, z1 - 1, function(z)
			local blocked = level == G2 and z > -48 and z < -16
			if not blocked then
				Props.bookshelf(m, CFrame.new(x1 - 1.1, level, z) * CFrame.Angles(0, math.pi / 2, 0), 8, 14, seed, true)
			end
			seed += 1
		end)
		run(x0 + 3, x1 - 3, function(x)
			Props.bookshelf(m, CFrame.new(x, level, z0 + 1.1) * CFrame.Angles(0, math.pi, 0), 8, 14, seed, true)
			seed += 1
		end)
		run(x0 + 3, x1 - 3, function(x)
			local blocked = level == G2 and x > 22 and x < 42 -- дверь в погреб
			if not blocked then
				Props.bookshelf(m, CFrame.new(x, level, z1 - 1.1), 8, 14, seed, true)
			end
			seed += 1
		end)
	end
	wallShelves(fy)
	wallShelves(G1)
	wallShelves(G2)
	-- нижний зал: ряды двусторонних стеллажей на западе, читальный зал на востоке
	local midZ = (inner[3] + inner[4]) / 2
	for row = 0, 4 do
		local x = inner[1] + 8 + row * 9
		for k = 0, 9 do
			local z = inner[3] + 6 + k * 8.6
			if math.abs(z - midZ) > 7 and z < inner[4] - 6 then
				Props.bookshelf(m, CFrame.new(x - 1.05, fy, z) * CFrame.Angles(0, math.pi / 2, 0), 8, 12, seed, true)
				Props.bookshelf(m, CFrame.new(x + 1.05, fy, z) * CFrame.Angles(0, -math.pi / 2, 0), 8, 12, seed + 50, true)
				seed += 1
			end
		end
		P(m, "Ladder", Vector3.new(0.3, 12, 2), CFrame.new(x - 2.4, fy + 6, midZ + 9) * CFrame.Angles(0, 0, math.rad(-10)), Props.WOOD, M.Wood)
	end
	local cxm = (inner[1] + inner[2]) / 2
	local readX = cxm + 30
	Props.rug(m, CFrame.new(readX, fy, midZ), 30, 64, rgb(40, 60, 46))
	for row = -1, 1 do
		for col = 0, 1 do
			local cf = CFrame.new(readX - 7 + col * 14, fy, midZ + row * 20)
			Props.table(m, cf, 8, 4)
			for _, s in { -1, 1 } do
				for _, ox in { -2.2, 2.2 } do
					Props.chair(m, cf * CFrame.new(ox, 0, s * 3.4) * CFrame.Angles(0, if s > 0 then 0 else math.pi, 0), rgb(40, 70, 50))
				end
			end
			for _, ox in { -2, 2 } do
				C(m, "LampFoot", 0.2, 0.6, cf * CFrame.new(ox, 3.45, 0), Props.GOLD, M.Metal, { CanCollide = false })
				C(m, "LampStem", 1, 0.12, cf * CFrame.new(ox, 4, 0), Props.GOLD, M.Metal, { CanCollide = false })
				local shade = P(m, "LampShade", Vector3.new(1.6, 0.5, 0.7), cf * CFrame.new(ox, 4.6, 0), rgb(40, 140, 80), M.Glass, { CanCollide = false, Transparency = 0.15 })
				if ox < 0 then
					Props.light(shade, 12, 0.9, rgb(255, 230, 170))
				end
			end
			local book = P(m, "OpenBook", Vector3.new(2, 0.2, 1.4), cf * CFrame.new(0, 3.45, 0), rgb(245, 236, 210), M.SmoothPlastic)
			prompt(book, "book")
		end
	end
	Props.globe(m, CFrame.new(readX + 10, fy, inner[3] + 6))
	Props.grandfatherClock(m, CFrame.new(inner[2] - 3, fy, inner[4] - 3) * CFrame.Angles(0, math.pi * 0.75, 0))
	-- люстры и парящий жрец над круглой площадкой
	local px = cxm + 4
	for _, ox in { -30, 30 } do
		for _, oz in { -30, 30 } do
			Props.chandelier(m, Vector3.new(cxm + ox, -22, midZ + oz), 7, 21.2)
		end
	end
	-- напольные лампы в проходах между стеллажами и вдоль галерей
	for row = 0, 4 do
		for _, z in { inner[3] + 3, midZ, inner[4] - 3 } do
			local x = inner[1] + 3.5 + row * 9
			C(m, "LampPost", 7, 0.3, CFrame.new(x, fy + 3.5, z), Props.GOLD, M.Metal)
			local bulb = S(m, "LampGlobe", 1.1, CFrame.new(x, fy + 7.4, z), rgb(255, 226, 170), M.Neon, { CanCollide = false })
			Props.light(bulb, 22, 1.3)
		end
	end
	for _, gy in { G1, G2 } do
		for k = 0, 4 do
			local x = inner[1] + (k + 0.5) * dx
			for _, z in { inner[3], inner[4] } do
				-- шар стоит на латунной чашке прямо на поручне
				C(m, "RailLampCup", 0.3, 0.7, CFrame.new(x, gy + 3.62, z), Props.GOLD, M.Metal, { CanCollide = false })
				local lamp = S(m, "RailLamp", 0.9, CFrame.new(x, gy + 4.15, z), rgb(255, 220, 160), M.Neon, { CanCollide = false })
				if k % 2 == 0 then
					Props.light(lamp, 20, 1.1)
				end
			end
		end
	end
	Props.chandelier(m, Vector3.new(px, -10, midZ), 10, 9.2)
	C(m, "Dais", 1, 18, CFrame.new(px, fy + 0.5, midZ), rgb(150, 140, 126), M.Marble)
	C(m, "DaisRing", 1.1, 14, CFrame.new(px, fy + 0.55, midZ), rgb(120, 22, 30), M.Carpet)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		Props.candelabra(m, Vector3.new(px + math.cos(a) * 7.5, fy + 1, midZ + math.sin(a) * 7.5))
	end
	B.points.priest = CFrame.new(px, fy + 12, midZ)
	B.points.library = CFrame.new(px, fy + 3, midZ + 14)
	for _, gy in { fy, G1, G2 } do
		for z = z0 + 24, z1 - 20, 40 do
			Props.sconce(m, CFrame.new(x0 + 2.3, gy + 15.5, z) * CFrame.Angles(0, -math.pi / 2, 0), true)
		end
	end
end

-- ---------------------------------------------------------------------------
-- тюрьма (U, клетки 0..1 × 3..6): камеры по краям, двор для работ, ворота с решёткой

local function prison(parent)
	local m = Props.model(parent, "Prison")
	local uy = LV.U
	local x0, x1, z0, z1 = -HALF + 2, -48 - 0.5, -16 + 0.5, HALF - 2
	box(m, "Floor", x0, uy - 1, z0, x1, uy, z1, rgb(80, 76, 70), M.Cobblestone)
	box(m, "Ceiling", x0, -1.4, z0, x1, -1, z1, rgb(70, 66, 62), M.Cobblestone, { CanCollide = false })
	B.cells = {}
	local cellDepth, cellW = 11, 9
	local n = math.floor((z1 - z0 - 14) / cellW)
	for side = 0, 1 do
		local wx = if side == 0 then x0 else x1
		local dir = if side == 0 then 1 else -1
		local front = wx + dir * cellDepth
		for k = 0, n - 1 do
			local za = z0 + 14 + k * cellW
			local zb = za + cellW
			box(m, "CellWall", math.min(wx, front), uy, za - 0.4, math.max(wx, front), uy + 12, za + 0.4, rgb(96, 90, 84), M.Slate)
			-- решётка с проходом посередине: узники свободно ходят по тюрьме, но не выходят из неё
			for b = 0, 7 do
				if b < 3 or b > 5 then
					P(m, "Bar", Vector3.new(0.35, 12, 0.35), CFrame.new(front, uy + 6, za + 0.8 + b * 1.05), Props.IRON, M.Metal)
				end
			end
			box(m, "BarTop", front - 0.3, uy + 11.5, za, front + 0.3, uy + 12, zb, Props.IRON, M.Metal)
			Props.bunk(m, CFrame.new(wx + dir * 2.2, uy, za + cellW / 2))
			Props.bucket(m, CFrame.new(wx + dir * 6.5, uy, zb - 1.2))
			P(m, "Chain", Vector3.new(0.2, 4, 0.2), CFrame.new(wx + dir * 0.4, uy + 8, za + cellW / 2 + 3), Props.IRON, M.Metal, { CanCollide = false })
			table.insert(B.cells, { inside = CFrame.new(wx + dir * (cellDepth - 3), uy + 3, za + cellW / 2) })
		end
		box(m, "CellWall", math.min(wx, front), uy, z0 + 14 + n * cellW - 0.4, math.max(wx, front), uy + 12, z0 + 14 + n * cellW + 0.4, rgb(96, 90, 84), M.Slate)
		box(m, "CellBlockTop", math.min(wx, front), uy + 12, z0 + 13.6, math.max(wx, front), uy + 12.6, z0 + 14.4 + n * cellW, rgb(96, 90, 84), M.Slate)
	end
	-- двор для работ: камень, точильные круги, стирка
	local yx0, yx1 = x0 + cellDepth + 2, x1 - cellDepth - 2
	local ymid = (yx0 + yx1) / 2
	B.points.prisonYard = CFrame.new(ymid, uy + 3, z0 + 10)
	local stations = { Props.rockPile, Props.grindstone, Props.washtub }
	local k = 0
	for z = z0 + 24, z1 - 14, 16 do
		for _, x in { yx0 + 5, yx1 - 5 } do
			k += 1
			local st = stations[k % 3 + 1](m, CFrame.new(x, uy, z))
			prompt(st:FindFirstChildWhichIsA("BasePart"), "work", 2, 10)
		end
	end
	for z = z0 + 32, z1 - 14, 32 do
		Props.crate(m, CFrame.new(ymid - 2, uy, z))
		Props.sack(m, CFrame.new(ymid + 2, uy, z + 1))
	end
	box(m, "Overseer", ymid - 5, uy, z1 - 9, ymid + 5, uy + 4, z1 - 1, Props.WOOD, M.WoodPlanks)
	Props.railing(m, Vector3.new(ymid - 5, uy + 4, z1 - 9), Vector3.new(ymid + 5, uy + 4, z1 - 9))
	for z = z0 + 18, z1 - 8, 24 do
		torch(m, CFrame.new(x0 + cellDepth + 0.25, uy + 9, z) * CFrame.Angles(0, math.pi / 2, 0))
		torch(m, CFrame.new(x1 - cellDepth - 0.25, uy + 9, z) * CFrame.Angles(0, -math.pi / 2, 0))
	end
	for _, z in { z0 + 40, z1 - 40 } do
		Props.ceilingLamp(m, Vector3.new(ymid, uy + 13, z), 3)
	end
	-- ворота: решётка в проёме между караульной и тюрьмой
	local gx, gz = -96, -16
	local gate = Props.model(m, "PrisonGate")
	for b = -3, 3 do
		P(gate, "GateBar", Vector3.new(0.4, 10, 0.4), CFrame.new(gx + b * 1.15, uy + 5, gz), Props.IRON, M.Metal)
	end
	for _, y in { uy + 1, uy + 5, uy + 9.6 } do
		P(gate, "GateRail", Vector3.new(8, 0.4, 0.4), CFrame.new(gx, y, gz), Props.IRON, M.Metal)
	end
	local lock = P(gate, "Lock", Vector3.new(1, 1.2, 0.8), CFrame.new(gx + 3, uy + 4.5, gz - 0.5), Props.GOLD, M.Metal)
	P(gate, "GateBlock", Vector3.new(8, 10, 1), CFrame.new(gx, uy + 5, gz), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CastShadow = false })
	prompt(lock, "prisongate", 0.8, 10)
	B.points.prisonInside = CFrame.new(gx, uy + 3, gz + 6)
	B.points.prisonOutside = CFrame.new(gx, uy + 3, gz - 6)
end

-- ---------------------------------------------------------------------------
-- двор, крепостная стена, ворота, смотровая терраса

local function courtyard(parent)
	local m = Props.model(parent, "Courtyard")
	local W = 6
	local WH = 24
	local inner = ISLAND - W
	rect(m, "CurtainWall", "z", -ISLAND + W / 2, W, -ISLAND, ISLAND, -2, WH, { { 0, 14, -3, 18 } }, FACADE_DARK, M.Slate)
	rect(m, "CurtainWall", "z", ISLAND - W / 2, W, -ISLAND, ISLAND, -2, WH, nil, FACADE_DARK, M.Slate)
	rect(m, "CurtainWall", "x", -ISLAND + W / 2, W, -ISLAND + W, ISLAND - W, -2, WH, nil, FACADE_DARK, M.Slate)
	rect(m, "CurtainWall", "x", ISLAND - W / 2, W, -ISLAND + W, ISLAND - W, -2, WH, nil, FACADE_DARK, M.Slate)
	for a = -ISLAND + 3, ISLAND - 3, 5 do
		if math.abs(a) > 17 then
			box(m, "Merlon", a - 1.2, WH, -ISLAND, a + 1.2, WH + 3.5, -ISLAND + 1.5, FACADE_DARK, M.Slate)
		end
		box(m, "Merlon", a - 1.2, WH, ISLAND - 1.5, a + 1.2, WH + 3.5, ISLAND, FACADE_DARK, M.Slate)
		box(m, "Merlon", -ISLAND, WH, a - 1.2, -ISLAND + 1.5, WH + 3.5, a + 1.2, FACADE_DARK, M.Slate)
		box(m, "Merlon", ISLAND - 1.5, WH, a - 1.2, ISLAND, WH + 3.5, a + 1.2, FACADE_DARK, M.Slate)
	end
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local x, z = c[1] * (ISLAND - 4), c[2] * (ISLAND - 4)
		C(m, "WallTower", 48, 22, CFrame.new(x, 22, z), FACADE, M.Slate)
		C(m, "WallTowerTop", 3, 25, CFrame.new(x, 47.5, z), FACADE_DARK, M.Slate)
		for k = 0, 6 do
			local roof = C(m, "WallTowerRoof", 2.6, 26 - k * 3.6, CFrame.new(x, 50 + k * 2.6, z), rgb(66, 48, 58), M.RoofShingles)
			roof:SetAttribute("Roof", true)
		end
		S(m, "Finial", 1.6, CFrame.new(x, 68.5, z), Props.GOLD, M.Metal)
	end
	-- надвратная башня и подъёмная решётка
	local gz0, gz1 = -ISLAND - 4, -ISLAND + W + 4
	box(m, "Gatehouse", -16, 18, gz0, 16, 42, gz1, FACADE, M.Slate)
	for _, x in { -11.5, 11.5 } do
		box(m, "GateTower", x - 4.5, -2, gz0, x + 4.5, 42, gz1, FACADE, M.Slate)
	end
	for a = -15, 15, 5 do
		box(m, "Merlon", a - 1.2, 42, gz0, a + 1.2, 45.5, gz0 + 1.5, FACADE_DARK, M.Slate)
	end
	Props.banner(m, CFrame.new(0, 38, gz0 - 0.1) * CFrame.Angles(0, math.pi, 0), 12, rgb(130, 20, 28))
	local gateBody = box(m, "Portcullis", -7, 0, -ISLAND + 2.4, 7, 18, -ISLAND + 3.6, rgb(45, 42, 40), M.DiamondPlate, { Transparency = 0.15 })
	B.gate = gateBody
	B.gateLift = 19
	for _, x in { -9.5, 9.5 } do
		torch(m, CFrame.new(x, 12, gz0) * CFrame.Angles(0, math.pi, 0))
	end
	-- смотровая терраса над пустотой за воротами
	box(m, "Terrace", -26, -2, -ISLAND - 30, 26, 0, gz0, rgb(130, 126, 118), M.Slate)
	P(m, "TerraceRock", Vector3.new(50, 26, 24), CFrame.new(0, -16, -ISLAND - 17) * CFrame.Angles(0.25, 0, 0), ROCK, M.Rock)
	Props.railing(m, Vector3.new(-26, 0, -ISLAND - 29.7), Vector3.new(26, 0, -ISLAND - 29.7), FACADE_DARK)
	Props.railing(m, Vector3.new(-25.7, 0, -ISLAND - 30), Vector3.new(-25.7, 0, gz0), FACADE_DARK)
	Props.railing(m, Vector3.new(25.7, 0, -ISLAND - 30), Vector3.new(25.7, 0, gz0), FACADE_DARK)
	-- невидимые стенки по краю террасы: за перила не перепрыгнуть
	for _, w in { { -27, -26, -ISLAND - 31, gz0 }, { 26, 27, -ISLAND - 31, gz0 }, { -27, 27, -ISLAND - 31, -ISLAND - 30 } } do
		box(m, "Barrier", w[1], 0, w[3], w[2], 16, w[4], rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CastShadow = false })
	end
	-- симметрично: две подзорные трубы по краям, скамья посередине смотрит в небо
	for _, x in { -18, 18 } do
		Props.telescope(m, CFrame.new(x, 0, -ISLAND - 25))
		Props.lamppost(m, CFrame.new(x + (if x < 0 then -4 else 4), 0, gz0 - 3))
	end
	Props.bench(m, CFrame.new(0, 0, -ISLAND - 25), 8)
	B.points.outside = CFrame.new(0, 3, -ISLAND - 16)

	-- парадный двор: фонтан со статуей короля, дорожки, скамьи, фонари, клумбы
	local fz = -140
	box(m, "Path", -4, 0, -inner, 4, 0.08, fz - 18, rgb(170, 162, 150), M.Slate, { CanCollide = false })
	box(m, "Path", -4, 0, fz + 18, 4, 0.08, -HALF - 12, rgb(170, 162, 150), M.Slate, { CanCollide = false })
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		P(m, "RingPath", Vector3.new(7.5, 0.08, 3), CFrame.new(math.cos(a) * 16.5, 0.04, fz + math.sin(a) * 16.5) * CFrame.Angles(0, -a + math.pi / 2, 0), rgb(170, 162, 150), M.Slate, { CanCollide = false })
	end
	local basin = C(m, "Fountain", 2.4, 28, CFrame.new(0, 1.2, fz), rgb(196, 190, 180), M.Marble)
	C(m, "FountainLip", 0.6, 28.6, CFrame.new(0, 2.5, fz), rgb(176, 170, 160), M.Marble)
	C(m, "FountainWater", 0.4, 25.6, CFrame.new(0, 2.3, fz), rgb(70, 130, 170), M.Glass, { Transparency = 0.35, CanCollide = false })
	box(m, "StatuePlinth", -5, 0, fz - 5, 5, 8, fz + 5, rgb(196, 190, 180), M.Marble)
	box(m, "PlinthCap", -5.6, 7.4, fz - 5.6, 5.6, 8, fz + 5.6, rgb(176, 170, 160), M.Marble)
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local jet = S(m, "Spout", 1, CFrame.new(math.cos(a) * 6.5, 2.6, fz + math.sin(a) * 6.5), Props.GOLD, M.Metal)
		local spray = Instance.new("ParticleEmitter")
		spray.Rate = 25
		spray.Speed = NumberRange.new(9, 12)
		spray.SpreadAngle = Vector2.new(8, 8)
		spray.Lifetime = NumberRange.new(1, 1.3)
		spray.Acceleration = Vector3.new(0, -32, 0)
		spray.Size = NumberSequence.new(0.35)
		spray.Color = ColorSequence.new(rgb(190, 220, 255))
		spray.Transparency = NumberSequence.new(0.3)
		spray.EmissionDirection = Enum.NormalId.Top
		spray.Parent = jet
	end
	prompt(basin, "water", 0, 18)
	B.points.statue = CFrame.new(0, 8, fz)
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local p = Vector3.new(math.cos(a) * 24, 0, fz + math.sin(a) * 24)
		Props.bench(m, CFrame.lookAt(p, Vector3.new(0, 0, fz)), 8)
	end
	for _, p in { { -10, -165 }, { 10, -165 }, { -10, -126 }, { 10, -126 }, { -44, -140 }, { 44, -140 }, { -140, -60 }, { 140, -60 }, { -140, 60 }, { 140, 60 }, { -40, 145 }, { 40, 145 } } do
		Props.lamppost(m, CFrame.new(p[1], 0, p[2]))
	end
	for _, p in { { -80, -152 }, { 80, -152 }, { -80, -126 }, { 80, -126 } } do
		Props.flowerbed(m, CFrame.new(p[1], 0, p[2]), 20, 8, p[1] + p[2])
	end
	Props.well(m, CFrame.new(-135, 0, -145))
	-- живые изгороди и беседка в западном саду
	for _, z in { -90, -50, 50, 90 } do
		Props.hedge(m, CFrame.new(-144, 0, z), 40)
	end
	local gp = CFrame.new(-144, 0, 0)
	C(m, "GazeboFloor", 1, 22, gp * CFrame.new(0, 0.5, 0), rgb(196, 190, 180), M.Marble)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		Props.column(m, gp * CFrame.new(math.cos(a) * 9, 1, math.sin(a) * 9), 11, 0.7)
	end
	for k = 0, 4 do
		C(m, "GazeboRoof", 1.2, 24 - k * 5, gp * CFrame.new(0, 12.6 + k * 1.2, 0), rgb(66, 48, 58), M.RoofShingles)
	end
	S(m, "GazeboFinial", 1.4, gp * CFrame.new(0, 19, 0), Props.GOLD, M.Metal)
	Props.bench(m, gp * CFrame.new(0, 1, 4), 8)
	Props.bench(m, gp * CFrame.new(0, 1, -4) * CFrame.Angles(0, math.pi, 0), 8)
	-- восточный двор: мишени и стойка с оружием
	for k = 0, 3 do
		local cf = CFrame.new(150, 0, -80 + k * 20) * CFrame.Angles(0, -math.pi / 2, 0)
		P(m, "TargetStand", Vector3.new(0.4, 5, 0.4), cf * CFrame.new(0, 2.5, 0.3), Props.WOOD, M.Wood)
		for r = 0, 3 do
			C(m, "Target", 0.2 + r * 0.02, 4 - r, cf * CFrame.new(0, 5, -r * 0.06) * CFrame.Angles(math.pi / 2, 0, 0), if r % 2 == 0 then rgb(230, 225, 210) else rgb(170, 30, 30), M.SmoothPlastic)
		end
	end
	Props.weaponRack(m, CFrame.new(167, 0, -10) * CFrame.Angles(0, math.pi / 2, 0))
	-- задний двор: старое кладбище с оградой
	for k = 0, 9 do
		local x, z = -110 + (k % 5) * 9, 140 + math.floor(k / 5) * 12
		P(m, "Gravestone", Vector3.new(2.6, 3.6, 0.6), CFrame.new(x, 1.8, z) * CFrame.Angles(0, 0, math.rad((k % 3 - 1) * 4)), rgb(130, 126, 120), M.Slate)
		C(m, "GraveTop", 0.6, 2.6, CFrame.new(x, 3.6, z) * CFrame.Angles(math.pi / 2, 0, 0), rgb(130, 126, 120), M.Slate)
		P(m, "GraveMound", Vector3.new(2.6, 0.6, 5), CFrame.new(x, 0.3, z - 3), rgb(80, 70, 50), M.Ground)
	end
	for x = -120, -66, 3 do
		P(m, "Fence", Vector3.new(0.2, 4, 0.2), CFrame.new(x, 2, 128), Props.IRON, M.Metal)
	end
	P(m, "FenceRail", Vector3.new(54, 0.2, 0.2), CFrame.new(-93, 3.6, 128), Props.IRON, M.Metal)
	-- деревья (вид меняется со временем года)
	B.trees = {}
	for _, t in { { -60, -128 }, { 60, -128 }, { -60, -162 }, { 60, -162 }, { -120, -162 }, { 120, -162 }, { -160, -120 }, { 160, -120 }, { -160, 30 }, { -160, -30 }, { 140, 30 }, { 160, 140 }, { 130, 158 }, { 100, 160 }, { 60, 130 }, { 0, 150 }, { -30, 160 }, { -150, 150 }, { 150, -150 }, { -150, -150 } } do
		table.insert(B.trees, Vector3.new(t[1], 0, t[2]))
	end
	-- факелы на внутренней стороне стены
	for a = -ISLAND + 30, ISLAND - 30, 48 do
		torch(m, CFrame.new(a, 12, inner) * CFrame.Angles(0, math.pi, 0))
		torch(m, CFrame.new(-inner, 12, a) * CFrame.Angles(0, math.pi / 2, 0))
		torch(m, CFrame.new(inner, 12, a) * CFrame.Angles(0, -math.pi / 2, 0))
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 6)
	spawn.CFrame = CFrame.new(0, 0.5, -160)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = m
	B.points.yard = CFrame.new(0, 3, -160)
	B.yard = { x0 = -inner, x1 = inner, z0 = -inner, z1 = -HALF - 14 }
end

-- ---------------------------------------------------------------------------
-- фасад главного здания, башни и крыши

local function exterior(parent)
	local m = Props.model(parent, "Exterior")
	local E = HALF
	for _, y in { -1, LV.F1 - 1, LV.F2 - 1 } do
		local h = if y == -1 then 2 else 1
		box(m, "Band", -E - 0.8, y, -E - 0.8, E + 0.8, y + h, -E, FACADE_DARK, M.Slate)
		box(m, "Band", -E - 0.8, y, E, E + 0.8, y + h, E + 0.8, FACADE_DARK, M.Slate)
		box(m, "Band", -E - 0.8, y, -E, -E, y + h, E, FACADE_DARK, M.Slate)
		box(m, "Band", E, y, -E, E + 0.8, y + h, E, FACADE_DARK, M.Slate)
	end
	for k = 1, N - 1 do
		local a = -E + k * CELL
		box(m, "Pilaster", a - 1.2, -1, -E - 1, a + 1.2, ROOF, -E, FACADE_DARK, M.Slate)
		box(m, "Pilaster", a - 1.2, -1, E, a + 1.2, ROOF, E + 1, FACADE_DARK, M.Slate)
		box(m, "Pilaster", -E - 1, -1, a - 1.2, -E, ROOF, a + 1.2, FACADE_DARK, M.Slate)
		box(m, "Pilaster", E, -1, a - 1.2, E + 1, ROOF, a + 1.2, FACADE_DARK, M.Slate)
	end
	box(m, "Roof", -E, ROOF - 1, -E, E, ROOF, E, rgb(90, 86, 80), M.Slate)
	box(m, "Parapet", -E - 1, ROOF, -E - 1, E + 1, ROOF + 2, -E, FACADE, M.Slate)
	box(m, "Parapet", -E - 1, ROOF, E, E + 1, ROOF + 2, E + 1, FACADE, M.Slate)
	box(m, "Parapet", -E - 1, ROOF, -E, -E, ROOF + 2, E, FACADE, M.Slate)
	box(m, "Parapet", E, ROOF, -E, E + 1, ROOF + 2, E, FACADE, M.Slate)
	for a = -E + 2, E - 2, 5 do
		box(m, "Merlon", a - 1.2, ROOF + 2, -E - 1, a + 1.2, ROOF + 5, -E + 0.5, FACADE, M.Slate)
		box(m, "Merlon", a - 1.2, ROOF + 2, E - 0.5, a + 1.2, ROOF + 5, E + 1, FACADE, M.Slate)
		box(m, "Merlon", -E - 1, ROOF + 2, a - 1.2, -E + 0.5, ROOF + 5, a + 1.2, FACADE, M.Slate)
		box(m, "Merlon", E - 0.5, ROOF + 2, a - 1.2, E + 1, ROOF + 5, a + 1.2, FACADE, M.Slate)
	end
	-- скатные крыши над крыльями
	for _, wx in { -80, 80 } do
		for k = 0, 9 do
			local w = 44 - k * 4.4
			local roof = box(m, "WingRoof", wx - w / 2, ROOF + k * 2.2, -E + 8, wx + w / 2, ROOF + 2.2 + k * 2.2, E - 8, rgb(66, 48, 58), M.RoofShingles)
			if roof then
				roof:SetAttribute("Roof", true)
			end
		end
	end
	for _, c in { { -40, -60 }, { 40, -60 }, { -40, 20 }, { 40, 20 } } do
		box(m, "Chimney", c[1] - 3, ROOF, c[2] - 3, c[1] + 3, ROOF + 16, c[2] + 3, rgb(120, 70, 56), M.Brick)
		box(m, "ChimneyCap", c[1] - 3.6, ROOF + 16, c[2] - 3.6, c[1] + 3.6, ROOF + 17, c[2] + 3.6, FACADE_DARK, M.Slate)
	end
	-- угловые башни
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		-- башня вынесена за угол, чтобы не заходить внутрь комнат; угол заполнен кладкой
		local x, z = c[1] * (E + 9), c[2] * (E + 9)
		box(m, "TowerJoin", math.min(c[1] * E, c[1] * (E + 11)), -1, math.min(c[2] * E, c[2] * (E + 11)), math.max(c[1] * E, c[1] * (E + 11)), ROOF + 28, math.max(c[2] * E, c[2] * (E + 11)), FACADE, M.Cobblestone)
		C(m, "Tower", ROOF + 30, 30, CFrame.new(x, (ROOF + 30) / 2 - 1, z), FACADE, M.Cobblestone)
		C(m, "TowerBand", 2, 32, CFrame.new(x, ROOF + 29, z), FACADE_DARK, M.Slate)
		for k = 0, 9 do
			local a = k / 10 * math.pi * 2
			P(m, "TowerMerlon", Vector3.new(3, 3.5, 2), CFrame.new(x, ROOF + 31.7, z) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 15), FACADE, M.Slate)
		end
		for k = 0, 9 do
			local roof = C(m, "TowerRoof", 3.2, 30 - k * 3, CFrame.new(x, ROOF + 32 + k * 3.2, z), rgb(66, 48, 58), M.RoofShingles)
			roof:SetAttribute("Roof", true)
		end
		S(m, "Finial", 1.8, CFrame.new(x, ROOF + 66, z), Props.GOLD, M.Metal)
		local out = Vector3.new(c[1], 0, c[2]).Unit
		for _, y in { 10, 28, 46, 66 } do
			local wp = Vector3.new(x, y, z) + out * 14.6
			Props.window(m, CFrame.lookAt(wp, wp + out), 3, 6, 1)
		end
	end
	-- главная башня над тронным залом
	local tz = 64
	box(m, "Keep", -24, ROOF - 1, tz - 24, 24, ROOF + 56, tz + 24, FACADE, M.Slate)
	for a = -22, 22, 5 do
		box(m, "KeepMerlon", a - 1.2, ROOF + 56, tz - 25, a + 1.2, ROOF + 60, tz - 23.5, FACADE, M.Slate)
		box(m, "KeepMerlon", a - 1.2, ROOF + 56, tz + 23.5, a + 1.2, ROOF + 60, tz + 25, FACADE, M.Slate)
	end
	for k = 0, 11 do
		local w = 44 - k * 3.6
		local r = box(m, "KeepRoof", -w / 2, ROOF + 56 + k * 3, tz - w / 2, w / 2, ROOF + 59 + k * 3, tz + w / 2, rgb(66, 48, 58), M.RoofShingles)
		if r then
			r:SetAttribute("Roof", true)
		end
	end
	P(m, "Spire", Vector3.new(0.6, 14, 0.6), CFrame.new(0, ROOF + 99, tz), Props.GOLD, M.Metal)
	for _, y in { ROOF + 12, ROOF + 32 } do
		for _, x in { -12, 0, 12 } do
			Props.window(m, CFrame.lookAt(Vector3.new(x, y, tz - 24), Vector3.new(x, y, tz - 30)), 4, 9, 1)
		end
	end
	-- портик главного входа
	for _, x in { -12, 12 } do
		Props.column(m, CFrame.new(x, 0, -E - 9), 22, 1.6)
	end
	box(m, "Portico", -16, 22, -E - 12, 16, 24, -E, FACADE, M.Slate)
	box(m, "Pediment", -14, 24, -E - 11, 14, 27, -E - 1, FACADE_DARK, M.Slate)
	box(m, "Steps", -16, -0.6, -E - 12, 16, 0.3, -E, rgb(170, 162, 150), M.Slate)
	Props.banner(m, CFrame.new(0, 22, -E - 12.2) * CFrame.Angles(0, math.pi, 0), 8, rgb(130, 20, 28))
	for _, x in { -18, 18 } do
		Props.lamppost(m, CFrame.new(x, 0, -E - 14))
	end
end

-- Дверь: створки поворачиваются на петлях (видно всем, створки твёрдые)
local TweenService = game:GetService("TweenService")
function B.toggleDoor(trigger: Instance)
	local door = trigger.Parent
	if not door or door:GetAttribute("Busy") then
		return
	end
	door:SetAttribute("Busy", true)
	local open = not door:GetAttribute("Open")
	door:SetAttribute("Open", open)
	local leaves = {}
	for _, l in door:GetChildren() do
		if l:IsA("Model") and l.Name == "Leaf" then
			local base = l:GetAttribute("Base")
			if typeof(base) ~= "CFrame" then
				base = l:GetPivot()
				l:SetAttribute("Base", base)
			end
			table.insert(leaves, { model = l, base = base, dir = l:GetAttribute("Dir") or 1 })
		end
	end
	local v = Instance.new("NumberValue")
	v.Value = if open then 0 else 1
	v.Changed:Connect(function(a)
		for _, lf in leaves do
			lf.model:PivotTo(lf.base * CFrame.Angles(0, math.rad(88) * a * lf.dir, 0))
		end
	end)
	local t = TweenService:Create(v, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = if open then 1 else 0 })
	t:Play()
	t.Completed:Connect(function()
		v:Destroy()
		door:SetAttribute("Busy", nil)
	end)
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/swoosh.wav"
	s.PlaybackSpeed = if open then 0.55 else 0.45
	s.Volume = 0.5
	s.RollOffMaxDistance = 50
	s.Parent = trigger
	s:Play()
	game:GetService("Debris"):AddItem(s, 3)
end

-- Открыть закрытые двери рядом с точкой (стража и боты проходят сквозь двери так же, как игроки)
local CollectionService = game:GetService("CollectionService")
function B.openDoorsNear(pos: Vector3, radius: number)
	for _, door in CollectionService:GetTagged("CastleDoor") do
		if not door:GetAttribute("Open") and not door:GetAttribute("Busy") then
			local t = door:FindFirstChild("DoorTrigger")
			if t and t:IsA("BasePart") and (t.Position - pos).Magnitude < radius then
				B.toggleDoor(t)
			end
		end
	end
end

-- Кнопки для всех отмеченных деталей мебели. allow — список разрешённых видов (для режима «Маньяк»)
function B.attachInteractions(rootInst: Instance, allow: { [string]: boolean }?)
	for _, d in rootInst:GetDescendants() do
		if d:IsA("BasePart") then
			local kind = d:GetAttribute("Interact")
			if kind and not d:FindFirstChildOfClass("ProximityPrompt") and (not allow or allow[kind]) then
				prompt(d, kind, d:GetAttribute("InteractHold"), d:GetAttribute("InteractDist"))
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Карта режима «Маньяк»: копия первого и второго этажей замка в темноте, далеко от острова.
-- Кровь, скелеты, паутина, тусклый мигающий свет, генераторы, доски, проломы, выход

B.MANIAC_ALLOW = { hide = true, repair = true, barricade = true, door = true, sit = false, lamp = false }
B.maniacPrompts = {}

local function maniacThrone(parent)
	local m = Props.model(parent, "RuinedThrone")
	local x0, x1, z0, z1 = -48, 48, 16, 112
	box(m, "Floor", x0, -1, z0, x1, 0, z1, rgb(70, 64, 60), M.Slate)
	box(m, "Ceiling", x0, 2 * H - 1.3, z0, x1, 2 * H - 1, z1, rgb(40, 34, 32), M.Slate, { CanCollide = false })
	for _, sx in { -1, 1 } do
		for k = 0, 4 do
			local cf = CFrame.new(sx * 30, 0, 24 + k * 14)
			if k % 2 == 0 then
				Props.column(m, cf, 2 * H - 1, 2, rgb(150, 140, 130))
			else
				-- сломанная колонна: обломок лежит на полу
				Props.column(m, cf, 9, 2, rgb(140, 130, 120))
				C(m, "Fallen", 14, 3.6, cf * CFrame.new(sx * -6, 1.8, 3) * CFrame.Angles(math.rad(90), 0.4 * sx, 0), rgb(140, 130, 120), M.Marble)
			end
		end
	end
	-- опрокинутый трон
	P(m, "ThroneBase", Vector3.new(5.4, 1.5, 5.4), CFrame.new(3, 0.75, 98) * CFrame.Angles(0, 0.4, 0), rgb(150, 120, 60), M.CorrodedMetal)
	P(m, "ThroneBack", Vector3.new(5.4, 11, 1), CFrame.new(-2, 1, 94) * CFrame.Angles(math.rad(-85), 0.3, 0), rgb(150, 120, 60), M.CorrodedMetal)
	for k = 0, 3 do
		Props.blood(m, Vector3.new(-12 + k * 9, 0, 70 + (k % 2) * 16), 4 + k, k)
	end
	Props.skeleton(m, CFrame.new(-20, 0, 105) * CFrame.Angles(0, math.pi, 0))
	Props.skeleton(m, CFrame.new(22, 0, 104) * CFrame.Angles(0, math.pi, 0))
	for k = 0, 2 do
		Props.chandelier(m, Vector3.new(0, 2 * H - 10, 34 + k * 26), 7, 9)
	end
end

local function horrorDress(map, level, rnd)
	local plan = plans[level]
	for _, room in plan.rooms do
		local info = room.info
		if info and not room.special then
			local cx, cz = (info.x0 + info.x1) / 2, (info.z0 + info.z1) / 2
			for k = 1, rnd:NextInteger(1, 3) do
				local p = Vector3.new(cx + rnd:NextNumber(-9, 9), info.y, cz + rnd:NextNumber(-9, 9))
				Props.blood(map, p, rnd:NextNumber(2, 5), rnd:NextInteger(1, 1000) + k)
			end
			local segs = info.segs
			if #segs > 0 then
				local seg = segs[rnd:NextInteger(1, #segs)]
				local p = seg.pos + seg.tangent * rnd:NextNumber(-4, 4) + Vector3.new(0, rnd:NextNumber(4, 8), 0)
				Props.bloodWall(map, CFrame.lookAt(p, p + seg.inward) * CFrame.new(0, 0, -0.45), rnd:NextInteger(1, 1000))
			end
			-- скелет у глухой стены
			if rnd:NextNumber() < 0.35 then
				for _, seg in segs do
					if not seg.opening then
						local p = seg.pos + seg.tangent * 13
						Props.skeleton(map, CFrame.lookAt(p, p + seg.inward) * CFrame.new(0, 0, -1.2))
						break
					end
				end
			end
			-- паутина по углам
			for _, c in { { info.x0, info.z0, 0.785 }, { info.x1, info.z1, 3.93 } } do
				Props.cobweb(map, Vector3.new(c[1] + (if c[1] < cx then 1.2 else -1.2), info.y + info.h - 1.6, c[2] + (if c[2] < cz then 1.2 else -1.2)), c[3])
			end
		end
	end
end

function B.buildManiac(offset: Vector3)
	local old = workspace:FindFirstChild("ManiacMap")
	if old then
		old:Destroy()
	end
	table.clear(B.maniacPrompts)
	B.activeRegistry = B.maniacPrompts
	local map = Instance.new("Model")
	map.Name = "ManiacMap"
	local pts = {}
	local allow = B.MANIAC_ALLOW
	local ctx = {
		prompt = function(part, kind, hold, dist)
			if allow[kind] then
				return prompt(part, kind, hold, dist)
			end
			return nil
		end,
		points = pts,
		noBasement = true,
		topLevel = "F1",
	}
	for _, level in { "G", "F1" } do
		local f = Instance.new("Folder")
		f.Name = "Level_" .. level
		f.Parent = map
		buildLevel(f, level, ctx)
		task.wait()
	end
	maniacThrone(map)
	local rnd = Random.new(13)
	horrorDress(map, "G", rnd)
	horrorDress(map, "F1", rnd)
	-- генераторы в коридорах обоих этажей, в стороне от дорожки
	local gens = {}
	for _, spot in { { "G", 0, 3 }, { "G", 6, 3 }, { "G", 3, 2 }, { "F1", 0, 3 }, { "F1", 6, 3 }, { "F1", 3, 3 } } do
		local cx, cz = cellCenter(spot[2], spot[3])
		local cf = CFrame.new(cx + 7, LV[spot[1]], cz) * CFrame.Angles(0, math.pi / 2, 0)
		local gm, body, lamp = Props.generator(map, cf)
		table.insert(gens, { model = gm, body = body, lamp = lamp, level = spot[1] })
	end
	-- доски в проёмах и проломы, через которые маньяку не пройти. Створки дверей в этих
	-- проёмах убираются, чтобы доски и завалы не стояли внутри двери
	local doorTriggers = {}
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "DoorTrigger" then
			table.insert(doorTriggers, d)
		end
	end
	local function stripDoorAt(pos: Vector3)
		for _, t in doorTriggers do
			local dp = t.Position
			if t.Parent and math.abs(dp.X - pos.X) < 1.5 and math.abs(dp.Z - pos.Z) < 1.5 and math.abs(dp.Y - pos.Y) < 12 then
				local door = t.Parent
				for _, c in door:GetChildren() do
					if (c:IsA("Model") and c.Name == "Leaf") or c == t then
						c:Destroy()
					end
				end
			end
		end
	end
	local barricades, safe = {}, {}
	local k = 0
	for _, level in { "G", "F1" } do
		for _, d in plans[level].doors do
			local ra, rb = plans[level].rooms[d.a], plans[level].rooms[d.b]
			local cx, cz = cellCenter(d.i, d.j)
			local plane = if d.axis == "x" then cx + CELL / 2 else cz + CELL / 2
			local along = if d.axis == "x" then cz else cx
			local pos = if d.axis == "x" then Vector3.new(plane, LV[level], along) else Vector3.new(along, LV[level], plane)
			local n = if d.axis == "x" then Vector3.xAxis else Vector3.zAxis
			local w = if d.wide then 10 else 6
			local h = if d.wide then 14 else 10
			local isHallDoor = ra.kind == "hall" or rb.kind == "hall"
			if not d.wide and ra.kind ~= "stairs" and rb.kind ~= "stairs" then
				k += 1
				if isHallDoor and k % 3 == 0 then
					stripDoorAt(pos)
					Props.rubble(map, CFrame.lookAt(pos, pos + n), w, h)
					table.insert(safe, pos)
				elseif k % 4 == 1 then
					stripDoorAt(pos)
					local _, block = Props.barricade(map, CFrame.lookAt(pos, pos + n), w, h)
					table.insert(barricades, block)
				end
			end
		end
	end
	-- выход: решётка в парадной двери и площадка снаружи
	local ex = Props.model(map, "Exit")
	local gate = box(ex, "ExitGate", -6, 0, -113, 6, 15, -111.5, rgb(40, 38, 36), M.DiamondPlate, { Transparency = 0.2 })
	box(ex, "ExitFloor", -14, -1, -142, 14, 0, -112, rgb(80, 76, 70), M.Cobblestone)
	Props.railing(ex, Vector3.new(-14, 0, -142), Vector3.new(14, 0, -142), FACADE_DARK)
	Props.railing(ex, Vector3.new(-14, 0, -142), Vector3.new(-14, 0, -113), FACADE_DARK)
	Props.railing(ex, Vector3.new(14, 0, -142), Vector3.new(14, 0, -113), FACADE_DARK)
	-- невидимые стенки: с площадки нельзя спрыгнуть в пустоту
	for _, w in { { -15, -14, -143, -112 }, { 14, 15, -143, -112 }, { -15, 15, -143, -142 } } do
		box(ex, "Barrier", w[1], 0, w[3], w[2], 14, w[4], rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CastShadow = false })
	end
	for _, x in { -12, 12 } do
		torch(ex, CFrame.new(x, 8, -112.2) * CFrame.Angles(0, math.pi, 0))
	end
	-- комната ожидания
	local lb = Props.model(map, "Lobby")
	local lz = -200
	box(lb, "Floor", -16, -1, lz - 16, 16, 0, lz + 16, rgb(70, 60, 54), M.WoodPlanks)
	box(lb, "Roof", -16, 14, lz - 16, 16, 15, lz + 16, rgb(40, 34, 30), M.Slate)
	for _, w in { { -17, -16, lz - 16, lz + 16 }, { 16, 17, lz - 16, lz + 16 }, { -16, 16, lz - 17, lz - 16 }, { -16, 16, lz + 16, lz + 17 } } do
		box(lb, "Wall", w[1], -1, w[3], w[2], 15, w[4], rgb(90, 80, 72), M.Brick)
	end
	for kk = 0, 5 do
		Props.candelabra(lb, Vector3.new(-12 + kk * 4.8, 0, lz + 13))
		Props.bench(lb, CFrame.new(-10 + (kk % 3) * 10, 0, lz - 6 + math.floor(kk / 3) * 7), 8)
	end
	Props.skeleton(lb, CFrame.new(13, 0, lz - 13) * CFrame.Angles(0, -math.pi * 0.75, 0))
	local lampPart = P(lb, "LobbyLight", Vector3.new(1, 1, 1), CFrame.new(0, 12, lz), rgb(255, 150, 90), M.Neon, { CanCollide = false })
	Props.light(lampPart, 40, 1.4, rgb(255, 140, 90))
	-- тусклый, мигающий, красноватый свет
	for _, d in map:GetDescendants() do
		if d:IsA("PointLight") then
			if rnd:NextNumber() < 0.5 and not d.Parent:IsDescendantOf(lb) and d.Parent.Name ~= "StatusLamp" then
				d.Enabled = false
			else
				d.Color = d.Color:Lerp(rgb(255, 90, 70), 0.45)
				d.Brightness *= 0.8
				d.Parent:SetAttribute("Flicker", true)
			end
		end
	end
	B.attachInteractions(map, allow)
	map:TranslateBy(offset)
	map.Parent = workspace
	B.activeRegistry = nil
	local function o(v)
		return v + offset
	end
	local spawns = {}
	for kk = 0, 7 do
		table.insert(spawns, CFrame.new(o(Vector3.new(-14 + (kk % 4) * 9, 3, -92 + math.floor(kk / 4) * 10))))
	end
	local genInfo = {}
	for _, g in gens do
		table.insert(genInfo, { model = g.model, body = g.body, lamp = g.lamp })
	end
	B.maniac = {
		map = map,
		offset = offset,
		generators = genInfo,
		barricades = barricades,
		safe = safe,
		gate = gate,
		exitZ = offset.Z - 124,
		exitX = offset.X,
		lobby = CFrame.new(o(Vector3.new(0, 3, lz))),
		survivorSpawns = spawns,
		maniacSpawn = CFrame.new(o(Vector3.new(0, 3, 64))),
		prompts = B.maniacPrompts,
	}
	return B.maniac
end

-- ---------------------------------------------------------------------------

function B.build()
	local old = workspace:FindFirstChild("TheCastle")
	if old then
		old:Destroy()
	end
	table.clear(prompts)
	workspace.Terrain:Clear()
	root = Instance.new("Folder")
	root.Name = "TheCastle"
	B.root = root
	for _, level in Layout.ORDER do
		plans[level] = Layout.build(level)
	end
	B.plans = plans
	table.clear(doorsAt)
	table.clear(extraOpenings)
	for _, level in Layout.ORDER do
		for _, d in plans[level].doors do
			doorsAt[edgeKey(level, d.i, d.j, d.axis)] = d
		end
	end
	-- особые проёмы: парадный вход, ворота тюрьмы, выход сточного туннеля
	extraOpenings[edgeKey("G", 3, 0, "z-")] = { w = 12, h = 15, door = true }
	extraOpenings[edgeKey("U", 0, 2, "z")] = { w = 8, h = 10 }
	extraOpenings[edgeKey("U", 6, 6, "x+")] = { w = 6, h = 9 }

	local ctx = { prompt = prompt, points = B.points }
	island(root)
	courtyard(root)
	exterior(root)
	for _, level in Layout.ORDER do
		local f = Instance.new("Folder")
		f.Name = "Level_" .. level
		f.Parent = root
		buildLevel(f, level, ctx)
		task.wait()
	end
	throneRoom(root)
	sewer(root)
	library(root)
	prison(root)
	B.points.dummies = B.points.dummies or {}
	B.attachInteractions(root)
	root.Parent = workspace

	-- атмосфера: тёплый полумрак в комнатах, как в DOORS
	Lighting.Ambient = rgb(58, 52, 48)
	Lighting.OutdoorAmbient = rgb(118, 116, 120)
	Lighting.Brightness = 2
	Lighting.ExposureCompensation = 0
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	local cc = Lighting:FindFirstChild("CastleColor") or Instance.new("ColorCorrectionEffect")
	cc.Name = "CastleColor"
	cc.TintColor = rgb(255, 244, 232)
	cc.Contrast = 0.1
	cc.Saturation = 0.05
	cc.Parent = Lighting
	local bloom = Lighting:FindFirstChild("CastleBloom") or Instance.new("BloomEffect")
	bloom.Name = "CastleBloom"
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 1.3
	bloom.Parent = Lighting
	B.partCount = Props.count()
	return B
end

return B
