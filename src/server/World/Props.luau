--!nonstrict
-- Модели лабиринта. Правила сборки: ни одна деталь не входит в другую с совпадающей
-- гранью (иначе мерцает), всё, что стоит у стены, отстоит от неё на 0.05.
-- cf предмета у стены — точка на полу у стены, LookVector смотрит в комнату

local CollectionService = game:GetService("CollectionService")
local M = require(game:GetService("ReplicatedStorage").Workshop.Shared.Materials)

local Props = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
Props.rgb = rgb

Props.WOOD = rgb(112, 78, 52)
Props.WOOD_DARK = rgb(64, 42, 30)
Props.WOOD_LIGHT = rgb(150, 112, 76)
Props.BRASS = rgb(190, 156, 88)
Props.IRON = rgb(58, 58, 62)
Props.STEEL = rgb(118, 124, 128)
Props.CLOTH = rgb(222, 216, 204)

-- множитель яркости ламп для комнаты, которая сейчас строится
Props.LIGHT = 1

local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball

local function P(parent, name, size: Vector3, cf: CFrame, color, mat, extra)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if extra then
		for k, v in extra do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end
Props.P = P

local function nc(extra)
	local t = { CanCollide = false, CanQuery = false, CastShadow = false }
	if extra then
		for k, v in extra do
			t[k] = v
		end
	end
	return t
end
Props.nc = nc

-- цилиндр вдоль локальной оси Y: длина len, диаметр d
local function C(parent, name, len: number, d: number, cf: CFrame, color, mat, extra)
	local p = P(parent, name, Vector3.new(len, d, d), cf * CFrame.Angles(0, 0, math.pi / 2), color, mat, extra)
	p.Shape = CYL
	return p
end
Props.C = C

local function S(parent, name, d: number, cf: CFrame, color, mat, extra)
	local p = P(parent, name, Vector3.new(d, d, d), cf, color, mat, extra)
	p.Shape = BALL
	return p
end
Props.S = S

-- стержень между двумя точками
local function rod(parent, name, a: Vector3, b: Vector3, thick: number, color, mat, extra)
	local len = (b - a).Magnitude
	return P(parent, name, Vector3.new(thick, thick, len), CFrame.lookAt((a + b) / 2, b), color, mat, extra)
end
Props.rod = rod

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end
Props.model = model

local function light(part, range, brightness, color, shadows)
	local f = Props.LIGHT
	local l = Instance.new("PointLight")
	l.Range = range
	l.Brightness = brightness * math.max(f, 0)
	l.Color = color or rgb(255, 212, 158)
	l.Shadows = shadows ~= false
	l.Enabled = f > 0.01
	l:SetAttribute("Base", brightness)
	l.Parent = part
	return l
end
Props.light = light

function Props.prompt(part: Instance, kind: string, hold: number?, dist: number?)
	local pr = Instance.new("ProximityPrompt")
	pr.Name = kind
	pr.ActionText = ""
	pr.ObjectText = ""
	pr.HoldDuration = hold or 0
	pr.MaxActivationDistance = dist or 8
	pr.RequiresLineOfSight = false
	pr:SetAttribute("Kind", kind)
	pr.Parent = part
	return pr
end

-- ---------------------------------------------------------------------------
-- стены

-- Стена вдоль локальной оси X кадра cf (середина стены на полу), от y0 высотой height,
-- с проёмами holes = { { x, w, y = низ проёма, h = верх проёма } }
function Props.wall(parent, cf: CFrame, length: number, y0: number, height: number, thick: number, holes, color, mat, name: string?)
	local list = table.clone(holes or {})
	table.sort(list, function(a, b)
		return a.x < b.x
	end)
	local x = -length / 2
	local y1 = y0 + height
	local function seg(x0, x1, ya, yb)
		if x1 - x0 > 0.05 and yb - ya > 0.05 then
			P(parent, name or "Wall", Vector3.new(x1 - x0, yb - ya, thick), cf * CFrame.new((x0 + x1) / 2, (ya + yb) / 2, 0), color, mat)
		end
	end
	for _, h in list do
		local hx0, hx1 = math.max(x, h.x - h.w / 2), math.min(length / 2, h.x + h.w / 2)
		if hx1 > hx0 then
			seg(x, hx0, y0, y1)
			seg(hx0, hx1, y0, math.max(y0, h.y or y0))
			seg(hx0, hx1, math.min(y1, h.h), y1)
			x = hx1
		end
	end
	seg(x, length / 2, y0, y1)
end

-- ---------------------------------------------------------------------------
-- двери

-- Двери трёх размеров: служебная железная, обычная филёнчатая, парадная двустворчатая.
-- cf — середина проёма на полу, LookVector — в следующий зал. Возвращает модель и створки
Props.DOORS = { small = { w = 4, h = 8 }, normal = { w = 5, h = 9 }, grand = { w = 8, h = 12 } }
function Props.door(parent, cf: CFrame, plate: string?, locked: boolean?, size: string?)
	local m = model(parent, "Door")
	local kind = size or "normal"
	local w, h = Props.DOORS[kind].w, Props.DOORS[kind].h
	local metal = kind == "small"
	local trim = if metal then rgb(70, 74, 76) else Props.WOOD_DARK
	local tmat = if metal then M.Metal else M.Wood
	-- наличник заходит в проём на 0.1, чтобы его грани не совпадали с краями проёма
	for _, s in { -1, 1 } do
		P(m, "Casing", Vector3.new(0.7, h - 0.1, 1.5), cf * CFrame.new(s * (w / 2 + 0.25), (h - 0.1) / 2, 0), trim, tmat)
	end
	P(m, "Head", Vector3.new(w + 1.2, 0.7, 1.5), cf * CFrame.new(0, h + 0.25, 0), trim, tmat)
	P(m, "Cornice", Vector3.new(w + 1.8, 0.3, 1.7), cf * CFrame.new(0, h + 0.75, 0), trim, tmat)
	local wood = if metal then rgb(96, 104, 106) elseif kind == "grand" then rgb(84, 52, 34) else Props.WOOD
	local leaves = {}
	local specs = if kind == "grand" then { { -1, (w - 0.3) / 2 - 0.04 }, { 1, (w - 0.3) / 2 - 0.04 } } else { { -1, w - 0.3 } }
	for _, sp in specs do
		local side, lw = sp[1], sp[2]
		local leaf = model(m, "Leaf")
		local hinge = side * (w / 2 - 0.15)
		local cx = hinge - side * lw / 2
		P(leaf, "Slab", Vector3.new(lw, h - 0.25, 0.3), cf * CFrame.new(cx, (h - 0.25) / 2 + 0.02, 0), wood, if metal then M.Metal else M.WoodPlanks)
		for _, face in { -1, 1 } do
			if metal then
				P(leaf, "Plate", Vector3.new(lw - 0.8, 1.4, 0.06), cf * CFrame.new(cx, h - 2, face * 0.18), rgb(60, 64, 66), M.DiamondPlate, nc())
				P(leaf, "Bar", Vector3.new(lw - 1, 0.25, 0.25), cf * CFrame.new(cx, 4, face * 0.3), rgb(150, 150, 156), M.Metal, nc())
			else
				for _, y in { h * 0.27, h * 0.7 } do
					P(leaf, "Panel", Vector3.new(lw - 1.2, h * 0.3, 0.06), cf * CFrame.new(cx, y, face * 0.18), wood:Lerp(rgb(0, 0, 0), 0.2), M.Wood, nc())
				end
				S(leaf, "Knob", 0.45, cf * CFrame.new(cx - side * (lw / 2 - 0.5), 4.2, face * 0.44), Props.BRASS, M.Metal, nc())
				P(leaf, "Rose", Vector3.new(0.5, 0.9, 0.06), cf * CFrame.new(cx - side * (lw / 2 - 0.5), 4.1, face * 0.2), Props.BRASS, M.Metal, nc())
			end
		end
		leaf.WorldPivot = cf * CFrame.new(hinge, 0, 0)
		leaf:SetAttribute("Dir", -side)
		table.insert(leaves, leaf)
	end
	if plate then
		-- латунная табличка над дверью со стороны входа
		local p = P(m, "Plate", Vector3.new(1.8, 0.5, 0.08), cf * CFrame.new(0, h + 0.25, 0.8), Props.BRASS, M.Metal, nc())
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 90
		gui.LightInfluence = 1
		gui.Parent = p
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.Antique
		t.TextScaled = true
		t.TextColor3 = rgb(36, 26, 14)
		t.Text = plate
		t.Parent = gui
	end
	if locked then
		local lock = model(m, "Padlock")
		local lx = w / 2 - 0.9
		P(lock, "Hasp", Vector3.new(0.9, 0.3, 0.1), cf * CFrame.new(lx, 5.3, 0.25), Props.IRON, M.Metal, nc())
		P(lock, "Body", Vector3.new(0.8, 0.9, 0.35), cf * CFrame.new(lx, 4.75, 0.42), rgb(150, 136, 100), M.Metal, nc())
		P(lock, "Shackle", Vector3.new(0.5, 0.45, 0.12), cf * CFrame.new(lx, 5.42, 0.42), rgb(130, 130, 136), M.Metal, nc())
	end
	CollectionService:AddTag(m, "LabDoor")
	return m, leaves
end

-- ---------------------------------------------------------------------------
-- укрытия

-- Железный шкафчик: стальной корпус с прорезями, ручка, ножки. Внутри пусто — туда
-- помещается игрок. Возвращает модель и невидимую «полость» с кнопкой
function Props.locker(parent, cf: CFrame, color: Color3?)
	local m = model(parent, "Locker")
	local steel = color or rgb(84, 96, 92)
	local w, d, h = 3.6, 2.8, 8.4
	local base = cf * CFrame.new(0, 0, -0.05 - d / 2)
	-- полость (невидимая, без столкновений) — для кнопки и укрытия
	local cavity = P(m, "Cavity", Vector3.new(w - 0.4, h - 1, d - 0.4), base * CFrame.new(0, 0.6 + (h - 1) / 2, 0), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = true, CastShadow = false })
	P(m, "Back", Vector3.new(w, h, 0.15), base * CFrame.new(0, h / 2 + 0.4, d / 2 - 0.075), steel, M.Metal)
	for _, s in { -1, 1 } do
		P(m, "Side", Vector3.new(0.15, h, d - 0.15), base * CFrame.new(s * (w / 2 - 0.075), h / 2 + 0.4, -0.075), steel, M.Metal)
	end
	P(m, "Top", Vector3.new(w, 0.15, d - 0.15), base * CFrame.new(0, h + 0.475, -0.075), steel, M.Metal)
	P(m, "Floor", Vector3.new(w - 0.3, 0.15, d - 0.3), base * CFrame.new(0, 0.475, 0), steel, M.Metal)
	-- дверца: лист, три ряда прорезей, ручка, табличка
	local door = P(m, "DoorPlate", Vector3.new(w - 0.3, h - 0.25, 0.1), base * CFrame.new(0, h / 2 + 0.4, -d / 2 + 0.05), steel:Lerp(rgb(255, 255, 255), 0.06), M.Metal)
	local _ = door
	for k = 0, 4 do
		P(m, "Vent", Vector3.new(w - 1.4, 0.12, 0.05), base * CFrame.new(0, h - 0.6 - k * 0.35, -d / 2 - 0.03), rgb(18, 18, 18), M.SmoothPlastic, nc())
		P(m, "Vent", Vector3.new(w - 1.4, 0.12, 0.05), base * CFrame.new(0, 1.6 + k * 0.35, -d / 2 - 0.03), rgb(18, 18, 18), M.SmoothPlastic, nc())
	end
	P(m, "Handle", Vector3.new(0.18, 1.2, 0.25), base * CFrame.new(w / 2 - 0.55, h / 2 + 0.2, -d / 2 - 0.12), rgb(170, 170, 176), M.Metal, nc())
	P(m, "Tag", Vector3.new(0.8, 0.4, 0.04), base * CFrame.new(0, h - 2.6, -d / 2 - 0.02), rgb(210, 200, 170), M.SmoothPlastic, nc())
	for _, s in { -1, 1 } do
		for _, e in { -1, 1 } do
			P(m, "Leg", Vector3.new(0.25, 0.4, 0.25), base * CFrame.new(s * (w / 2 - 0.3), 0.2, e * (d / 2 - 0.3)), rgb(30, 30, 30), M.Metal)
		end
	end
	Props.prompt(cavity, "hide", 0.25, 6)
	CollectionService:AddTag(cavity, "HideSpot")
	return m, cavity
end

-- Ниша за решёткой у пола (в тесных комнатах): игрок заползает внутрь
function Props.vent(parent, cf: CFrame)
	local m = model(parent, "VentHide")
	local w, h, d = 4, 4.2, 3
	local base = cf * CFrame.new(0, 0, -0.05 - d / 2)
	local cavity = P(m, "Cavity", Vector3.new(w - 0.4, h - 0.4, d - 0.4), base * CFrame.new(0, h / 2, 0), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = true, CastShadow = false })
	local duct = rgb(96, 98, 100)
	P(m, "Back", Vector3.new(w, h, 0.15), base * CFrame.new(0, h / 2, d / 2 - 0.075), duct, M.Metal)
	for _, s in { -1, 1 } do
		P(m, "Side", Vector3.new(0.15, h, d - 0.15), base * CFrame.new(s * (w / 2 - 0.075), h / 2, -0.075), duct, M.Metal)
	end
	P(m, "Top", Vector3.new(w, 0.15, d - 0.15), base * CFrame.new(0, h + 0.075, -0.075), duct, M.Metal)
	for k = -3, 3 do
		P(m, "Grate", Vector3.new(0.12, h - 0.4, 0.12), base * CFrame.new(k * 0.55, h / 2, -d / 2 + 0.06), rgb(40, 40, 42), M.Metal, nc())
	end
	for _, y in { 0.4, h - 0.4 } do
		P(m, "GrateBar", Vector3.new(w - 0.3, 0.15, 0.15), base * CFrame.new(0, y, -d / 2 + 0.06), rgb(40, 40, 42), M.Metal, nc())
	end
	Props.prompt(cavity, "hide", 0.4, 6)
	CollectionService:AddTag(cavity, "HideSpot")
	return m, cavity
end

-- ---------------------------------------------------------------------------
-- мебель с ящиками: ящики выезжают, внутри может лежать находка

-- корпус без передней стенки и ящики внутри. rows — число ящиков сверху вниз
local function drawerCase(m, cf: CFrame, w: number, d: number, h: number, rows: number, wood: Color3, legs: number, noTop: boolean?)
	local base = cf * CFrame.new(0, 0, -0.05 - d / 2)
	local t = 0.15
	P(m, "Back", Vector3.new(w, h, t), base * CFrame.new(0, legs + h / 2, d / 2 - t / 2), wood, M.Wood)
	for _, s in { -1, 1 } do
		P(m, "Side", Vector3.new(t, h, d - t), base * CFrame.new(s * (w / 2 - t / 2), legs + h / 2, -t / 2), wood, M.Wood)
	end
	if not noTop then
		P(m, "Top", Vector3.new(w + 0.2, 0.2, d + 0.05), base * CFrame.new(0, legs + h + 0.1, -0.025), wood:Lerp(rgb(0, 0, 0), 0.15), M.Wood)
	end
	P(m, "Bottom", Vector3.new(w - 2 * t, t, d - t), base * CFrame.new(0, legs + t / 2, -t / 2), wood, M.Wood)
	if legs > 0 then
		for _, s in { -1, 1 } do
			for _, e in { -1, 1 } do
				P(m, "Leg", Vector3.new(0.3, legs, 0.3), base * CFrame.new(s * (w / 2 - 0.25), legs / 2, e * (d / 2 - 0.25)), wood:Lerp(rgb(0, 0, 0), 0.25), M.Wood)
			end
		end
	end
	local drawers = {}
	local innerW, innerD = w - 2 * t - 0.1, d - t - 0.15
	local rowH = (h - t) / rows
	for r = 1, rows do
		local dm = model(m, "Drawer")
		local y = legs + h - (r - 0.5) * rowH
		local front = base * CFrame.new(0, y, -d / 2 + 0.06)
		P(dm, "Front", Vector3.new(w - 2 * t - 0.06, rowH - 0.12, 0.12), front, wood:Lerp(rgb(255, 255, 255), 0.08), M.Wood)
		P(dm, "Pull", Vector3.new(0.9, 0.16, 0.16), front * CFrame.new(0, 0, -0.14), Props.BRASS, M.Metal, nc())
		local boxY = y - rowH / 2 + 0.12
		P(dm, "BoxBottom", Vector3.new(innerW - 0.1, 0.08, innerD - 0.2), base * CFrame.new(0, boxY, 0.05), Props.WOOD_LIGHT, M.Wood, nc())
		for _, s in { -1, 1 } do
			P(dm, "BoxSide", Vector3.new(0.08, rowH * 0.45, innerD - 0.3), base * CFrame.new(s * (innerW / 2 - 0.1), boxY + 0.04 + rowH * 0.225, 0.05), Props.WOOD_LIGHT, M.Wood, nc())
		end
		dm.WorldPivot = front
		-- место для находки внутри ящика (в открытом положении)
		table.insert(drawers, { model = dm, open = base * CFrame.new(0, boxY + 0.1, 0.05 - 1.5), depth = innerD })
	end
	return drawers
end

-- кнопка «Обыскать» на передней части; drawers нужны игре для анимации
local function searchable(m, cf, w, d, h, legs)
	local hit = P(m, "Search", Vector3.new(w, h, 0.4), cf * CFrame.new(0, legs + h / 2, -d - 0.2), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = true, CastShadow = false })
	Props.prompt(hit, "search", 0.6, 7)
	CollectionService:AddTag(m, "Searchable")
	return hit
end

function Props.dresser(parent, cf: CFrame, wood: Color3?)
	local m = model(parent, "Dresser")
	local w, d, h = 4.8, 2, 3.4
	local drawers = drawerCase(m, cf, w, d, h, 3, wood or Props.WOOD, 0.35)
	local hit = searchable(m, cf, w, d, h, 0.35)
	return m, hit, drawers, cf * CFrame.new(1.4, 0.35 + h + 0.2, -1.05)
end

function Props.nightstand(parent, cf: CFrame, wood: Color3?)
	local m = model(parent, "Nightstand")
	local w, d, h = 2.2, 1.8, 2.2
	local drawers = drawerCase(m, cf, w, d, h, 1, wood or Props.WOOD, 0.4)
	local hit = searchable(m, cf, w, d, h, 0.4)
	return m, hit, drawers, cf * CFrame.new(0, 0.4 + h + 0.2, -0.95)
end

function Props.cabinet(parent, cf: CFrame)
	local m = model(parent, "FilingCabinet")
	local w, d, h = 2.4, 2.4, 4.6
	local drawers = drawerCase(m, cf, w, d, h, 3, rgb(110, 116, 112), 0)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and p.Material == M.Wood then
			p.Material = M.Metal
		end
	end
	local hit = searchable(m, cf, w, d, h, 0)
	return m, hit, drawers
end

-- письменный стол с двумя ящиками справа
function Props.desk(parent, cf: CFrame)
	local m = model(parent, "Desk")
	local w, d = 5.4, 2.6
	local base = cf * CFrame.new(0, 0, -0.05 - d / 2)
	P(m, "Top", Vector3.new(w, 0.25, d), base * CFrame.new(0, 3.08, 0), Props.WOOD, M.Wood)
	for _, e in { -1, 1 } do
		P(m, "LegL", Vector3.new(0.3, 2.95, 0.3), base * CFrame.new(-w / 2 + 0.3, 1.48, e * (d / 2 - 0.3)), Props.WOOD_DARK, M.Wood)
	end
	P(m, "Modesty", Vector3.new(w - 2.3, 1.4, 0.12), base * CFrame.new(-0.85, 2.2, d / 2 - 0.2), Props.WOOD_DARK, M.Wood)
	local case = model(m, "Pedestal")
	local drawers = drawerCase(case, cf * CFrame.new(w / 2 - 1.05, 0, 0), 2, d, 2.95, 2, Props.WOOD, 0, true)
	local hit = searchable(m, cf * CFrame.new(w / 2 - 1.05, 0, 0), 2, d, 2.95, 0)
	P(m, "Papers", Vector3.new(1.2, 0.04, 1.6), base * CFrame.new(-1.2, 3.23, 0) * CFrame.Angles(0, 0.25, 0), rgb(226, 220, 204), M.SmoothPlastic, nc())
	return m, hit, drawers, base * CFrame.new(0.2, 3.3, 0.1)
end

-- ---------------------------------------------------------------------------
-- прочая мебель

function Props.bed(parent, cf: CFrame, blanket: Color3, wood: Color3?)
	local m = model(parent, "Bed")
	local w, len = 5, 8.4
	local base = cf * CFrame.new(0, 0, -0.05 - len / 2)
	local frame = wood or Props.WOOD_DARK
	P(m, "Frame", Vector3.new(w - 0.1, 1, len - 0.6), base * CFrame.new(0, 0.9, -0.1), frame, M.Wood)
	for _, s in { -1, 1 } do
		P(m, "PostHead", Vector3.new(0.4, 4.2, 0.4), base * CFrame.new(s * (w / 2 - 0.2), 2.1, len / 2 - 0.2), frame, M.Wood)
		P(m, "PostFoot", Vector3.new(0.4, 2.4, 0.4), base * CFrame.new(s * (w / 2 - 0.2), 1.2, -len / 2 + 0.2), frame, M.Wood)
	end
	P(m, "Headboard", Vector3.new(w - 0.4, 2.8, 0.25), base * CFrame.new(0, 2.6, len / 2 - 0.2), frame, M.Wood)
	P(m, "Footboard", Vector3.new(w - 0.4, 1.2, 0.2), base * CFrame.new(0, 1.7, -len / 2 + 0.2), frame, M.Wood)
	P(m, "Mattress", Vector3.new(w - 0.5, 0.7, len - 1), base * CFrame.new(0, 1.75, 0), Props.CLOTH, M.SmoothPlastic)
	P(m, "Blanket", Vector3.new(w - 0.3, 0.22, len * 0.6), base * CFrame.new(0, 2.21, -len * 0.18), blanket, M.Fabric)
	P(m, "Fold", Vector3.new(w - 0.36, 0.26, 0.8), base * CFrame.new(0, 2.25, len * 0.13), Props.CLOTH, M.SmoothPlastic, nc())
	for _, x in { -1.1, 1.1 } do
		P(m, "Pillow", Vector3.new(1.8, 0.5, 1.2), base * CFrame.new(x, 2.35, len / 2 - 1.2), rgb(240, 236, 228), M.SmoothPlastic, nc())
	end
	return m
end

function Props.chair(parent, cf: CFrame, color: Color3?)
	-- cf — центр стула на полу, LookVector — куда смотрит сидящий
	local m = model(parent, "Chair")
	local wood = color or Props.WOOD
	P(m, "Seat", Vector3.new(1.8, 0.2, 1.8), cf * CFrame.new(0, 1.8, 0), wood, M.Wood)
	P(m, "Cushion", Vector3.new(1.6, 0.15, 1.6), cf * CFrame.new(0, 1.98, 0), rgb(120, 40, 40), M.Fabric, nc())
	for _, x in { -0.75, 0.75 } do
		for _, z in { -0.75, 0.75 } do
			P(m, "Leg", Vector3.new(0.18, 1.7, 0.18), cf * CFrame.new(x, 0.85, z), Props.WOOD_DARK, M.Wood, nc())
		end
		P(m, "BackPost", Vector3.new(0.18, 2.2, 0.18), cf * CFrame.new(x, 3, 0.81), Props.WOOD_DARK, M.Wood, nc())
	end
	P(m, "BackRail", Vector3.new(1.5, 0.5, 0.12), cf * CFrame.new(0, 3.6, 0.81), wood, M.Wood, nc())
	return m
end

function Props.armchair(parent, cf: CFrame, color: Color3)
	local m = model(parent, "Armchair")
	P(m, "Base", Vector3.new(3, 1.4, 2.8), cf * CFrame.new(0, 0.9, 0), color, M.Fabric)
	P(m, "Back", Vector3.new(3, 2.2, 0.6), cf * CFrame.new(0, 2.7, 1.1), color, M.Fabric)
	for _, s in { -1, 1 } do
		P(m, "Arm", Vector3.new(0.5, 0.9, 2.1), cf * CFrame.new(s * 1.25, 2.05, -0.25), color:Lerp(rgb(0, 0, 0), 0.1), M.Fabric)
	end
	for _, x in { -1.2, 1.2 } do
		for _, z in { -1.1, 1.1 } do
			P(m, "Foot", Vector3.new(0.25, 0.2, 0.25), cf * CFrame.new(x, 0.1, z), Props.WOOD_DARK, M.Wood, nc())
		end
	end
	return m
end

function Props.sofa(parent, cf: CFrame, color: Color3)
	-- cf у стены, сидящие смотрят в комнату
	local m = model(parent, "Sofa")
	local w, d = 7, 2.8
	local base = cf * CFrame.new(0, 0, -0.05 - d / 2)
	P(m, "Base", Vector3.new(w, 1.4, d), base * CFrame.new(0, 0.9, 0), color, M.Fabric)
	P(m, "Back", Vector3.new(w, 2.2, 0.6), base * CFrame.new(0, 2.7, d / 2 - 0.3), color, M.Fabric)
	for _, s in { -1, 1 } do
		P(m, "Arm", Vector3.new(0.5, 0.9, d - 0.6), base * CFrame.new(s * (w / 2 - 0.25), 2.05, -0.3), color:Lerp(rgb(0, 0, 0), 0.1), M.Fabric)
	end
	for k = -1, 1 do
		P(m, "Cushion", Vector3.new(w / 3 - 0.7, 0.3, d - 0.9), base * CFrame.new(k * (w / 3 - 0.15), 1.76, -0.3), color:Lerp(rgb(255, 255, 255), 0.06), M.Fabric, nc())
	end
	return m
end

function Props.table(parent, cf: CFrame, w: number, d: number, cloth: Color3?)
	local m = model(parent, "Table")
	P(m, "Top", Vector3.new(w, 0.25, d), cf * CFrame.new(0, 3.08, 0), Props.WOOD, M.Wood)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			P(m, "Leg", Vector3.new(0.3, 2.95, 0.3), cf * CFrame.new(sx * (w / 2 - 0.4), 1.48, sz * (d / 2 - 0.4)), Props.WOOD_DARK, M.Wood)
		end
	end
	if cloth then
		P(m, "Cloth", Vector3.new(w - 0.6, 0.04, d + 0.3), cf * CFrame.new(0, 3.23, 0), cloth, M.Fabric, nc())
	end
	return m, cf * CFrame.new(0, 3.25, 0)
end

function Props.coffeeTable(parent, cf: CFrame)
	local m = model(parent, "CoffeeTable")
	P(m, "Top", Vector3.new(4, 0.2, 2.4), cf * CFrame.new(0, 1.6, 0), Props.WOOD_DARK, M.Wood)
	P(m, "Shelf", Vector3.new(3.4, 0.12, 1.8), cf * CFrame.new(0, 0.5, 0), Props.WOOD_DARK, M.Wood, nc())
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			P(m, "Leg", Vector3.new(0.22, 1.5, 0.22), cf * CFrame.new(sx * 1.75, 0.75, sz * 0.95), Props.WOOD_DARK, M.Wood)
		end
	end
	return m, cf * CFrame.new(0, 1.72, 0)
end

-- книжный шкаф: полки с книгами блоками по несколько корешков
function Props.bookshelf(parent, cf: CFrame, w: number, h: number, seed: number)
	local m = model(parent, "Bookshelf")
	local d = 1.8
	local base = cf * CFrame.new(0, 0, -0.05 - d / 2)
	local wood = Props.WOOD_DARK
	P(m, "Back", Vector3.new(w, h, 0.15), base * CFrame.new(0, h / 2, d / 2 - 0.075), wood, M.Wood)
	for _, s in { -1, 1 } do
		P(m, "Side", Vector3.new(0.25, h, d - 0.15), base * CFrame.new(s * (w / 2 - 0.125), h / 2, -0.075), wood, M.Wood)
	end
	P(m, "Crown", Vector3.new(w + 0.3, 0.35, d + 0.1), base * CFrame.new(0, h + 0.175, -0.05), wood, M.Wood)
	local rows = math.floor(h / 2.2)
	for r = 0, rows - 1 do
		local y = 0.3 + r * 2.2
		P(m, "Board", Vector3.new(w - 0.5, 0.16, d - 0.25), base * CFrame.new(0, y, -0.05), Props.WOOD, M.Wood)
		local x = -w / 2 + 0.35
		local k = 0
		while x < w / 2 - 1 do
			k += 1
			local bw = 0.6 + ((seed * 13 + r * 7 + k * 5) % 7) * 0.12
			local bh = 1.2 + ((seed * 3 + r * 11 + k * 7) % 5) * 0.12
			if (seed + r + k) % 6 ~= 0 then
				local hue = ({ 0.0, 0.03, 0.08, 0.33, 0.58, 0.7 })[((seed + r * 2 + k) % 6) + 1]
				P(m, "Books", Vector3.new(bw, bh, d - 0.5), base * CFrame.new(x + bw / 2, y + 0.08 + bh / 2, 0.05), Color3.fromHSV(hue, 0.5, 0.32), M.SmoothPlastic, nc())
			end
			x += bw + 0.04
		end
	end
	P(m, "Board", Vector3.new(w - 0.5, 0.16, d - 0.25), base * CFrame.new(0, 0.3 + rows * 2.2, -0.05), Props.WOOD, M.Wood)
	return m
end

-- кухня
function Props.counter(parent, cf: CFrame, w: number)
	local m = model(parent, "Counter")
	local d = 2.4
	local base = cf * CFrame.new(0, 0, -0.05 - d / 2)
	P(m, "Body", Vector3.new(w, 3, d - 0.1), base * CFrame.new(0, 1.5, 0.05), rgb(200, 196, 186), M.Wood)
	P(m, "Top", Vector3.new(w + 0.1, 0.2, d + 0.1), base * CFrame.new(0, 3.1, 0), rgb(70, 70, 74), M.Granite)
	local n = math.max(1, math.floor(w / 2.4))
	for k = 0, n - 1 do
		local x = -w / 2 + (k + 0.5) * w / n
		P(m, "Door", Vector3.new(w / n - 0.2, 2.4, 0.06), base * CFrame.new(x, 1.5, -d / 2 + 0.02), rgb(180, 176, 166), M.Wood, nc())
		P(m, "Knob", Vector3.new(0.5, 0.12, 0.12), base * CFrame.new(x, 2.4, -d / 2 - 0.06), Props.STEEL, M.Metal, nc())
	end
	return m, base * CFrame.new(0, 3.3, 0)
end

function Props.stove(parent, cf: CFrame)
	local m = model(parent, "Stove")
	local base = cf * CFrame.new(0, 0, -0.05 - 1.2)
	P(m, "Body", Vector3.new(3, 3, 2.4), base * CFrame.new(0, 1.5, 0), rgb(220, 220, 214), M.Metal)
	P(m, "OvenDoor", Vector3.new(2.4, 1.6, 0.08), base * CFrame.new(0, 1.3, -1.22), rgb(40, 40, 40), M.Glass, nc())
	P(m, "Handle", Vector3.new(2, 0.12, 0.12), base * CFrame.new(0, 2.25, -1.32), Props.STEEL, M.Metal, nc())
	for _, x in { -0.7, 0.7 } do
		for _, z in { -0.5, 0.5 } do
			C(m, "Burner", 0.06, 0.8, base * CFrame.new(x, 3.03, z), rgb(30, 30, 30), M.Metal, nc())
		end
	end
	P(m, "Backsplash", Vector3.new(3, 0.8, 0.2), base * CFrame.new(0, 3.4, 1.1), rgb(220, 220, 214), M.Metal)
	return m
end

function Props.fridge(parent, cf: CFrame)
	local m = model(parent, "Fridge")
	local base = cf * CFrame.new(0, 0, -0.05 - 1.3)
	P(m, "Body", Vector3.new(3, 7, 2.6), base * CFrame.new(0, 3.5, 0), rgb(214, 212, 204), M.Metal)
	P(m, "Seam", Vector3.new(2.9, 0.08, 0.05), base * CFrame.new(0, 4.8, -1.32), rgb(120, 120, 120), M.SmoothPlastic, nc())
	for _, y in { 3, 6 } do
		P(m, "Handle", Vector3.new(0.15, 1.2, 0.15), base * CFrame.new(1.15, y, -1.4), Props.STEEL, M.Metal, nc())
	end
	return m
end

function Props.washer(parent, cf: CFrame)
	local m = model(parent, "Washer")
	local base = cf * CFrame.new(0, 0, -0.05 - 1.3)
	P(m, "Body", Vector3.new(2.8, 3.2, 2.6), base * CFrame.new(0, 1.6, 0), rgb(226, 226, 222), M.Metal)
	C(m, "Porthole", 0.1, 1.8, base * CFrame.new(0, 1.5, -1.32) * CFrame.Angles(math.pi / 2, 0, 0), rgb(60, 70, 80), M.Glass, nc())
	C(m, "Ring", 0.08, 2.1, base * CFrame.new(0, 1.5, -1.31) * CFrame.Angles(math.pi / 2, 0, 0), Props.STEEL, M.Metal, nc())
	P(m, "Panel", Vector3.new(2.6, 0.5, 0.06), base * CFrame.new(0, 2.9, -1.32), rgb(60, 60, 64), M.SmoothPlastic, nc())
	return m
end

function Props.crate(parent, cf: CFrame, s: number?)
	local size = s or 3
	local m = model(parent, "Crate")
	P(m, "Box", Vector3.new(size, size, size), cf * CFrame.new(0, size / 2, 0), rgb(128, 96, 60), M.WoodPlanks)
	for _, y in { 0.2, size - 0.2 } do
		P(m, "Band", Vector3.new(size + 0.06, 0.25, size + 0.06), cf * CFrame.new(0, y, 0), rgb(84, 62, 40), M.Wood, nc())
	end
	return m
end

-- стеллаж с коробками
function Props.rack(parent, cf: CFrame, w: number, seed: number)
	local m = model(parent, "Rack")
	local d, h = 2.2, 8
	local base = cf * CFrame.new(0, 0, -0.05 - d / 2)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			P(m, "Post", Vector3.new(0.25, h, 0.25), base * CFrame.new(sx * (w / 2 - 0.125), h / 2, sz * (d / 2 - 0.125)), rgb(150, 90, 40), M.Metal)
		end
	end
	for k = 0, 3 do
		local y = 0.4 + k * 2.4
		P(m, "Shelf", Vector3.new(w - 0.5, 0.12, d - 0.1), base * CFrame.new(0, y, 0), rgb(110, 110, 112), M.DiamondPlate)
		if k < 3 then
			for b = 0, 1 do
				if (seed + k + b) % 3 ~= 0 then
					local bs = 1.3 + ((seed + k * 2 + b) % 3) * 0.2
					P(m, "Box", Vector3.new(bs, bs * 0.8, bs), base * CFrame.new((b - 0.5) * (w / 2), y + 0.06 + bs * 0.4, 0), rgb(160, 126, 84), M.Cardboard, nc())
				end
			end
		end
	end
	return m
end

-- скамья у стены (cf у стены, сидящие смотрят в комнату)
function Props.bench(parent, cf: CFrame, w: number)
	local m = model(parent, "Bench")
	local base = cf * CFrame.new(0, 0, -0.05 - 0.9)
	P(m, "Seat", Vector3.new(w, 0.3, 1.8), base * CFrame.new(0, 1.75, 0), Props.WOOD, M.Wood)
	P(m, "Back", Vector3.new(w, 1.6, 0.25), base * CFrame.new(0, 2.8, 0.76), Props.WOOD, M.Wood)
	for _, s in { -1, 1 } do
		P(m, "Leg", Vector3.new(0.3, 1.6, 1.5), base * CFrame.new(s * (w / 2 - 0.4), 0.8, 0), Props.IRON, M.Metal)
	end
	return m
end

function Props.pillar(parent, cf: CFrame, h: number, color: Color3?)
	local m = model(parent, "Pillar")
	local c = color or rgb(150, 140, 126)
	P(m, "Shaft", Vector3.new(2.2, h - 1.6, 2.2), cf * CFrame.new(0, h / 2, 0), c, M.Limestone)
	P(m, "Base", Vector3.new(3, 0.8, 3), cf * CFrame.new(0, 0.4, 0), c:Lerp(rgb(0, 0, 0), 0.2), M.Limestone)
	P(m, "Cap", Vector3.new(3, 0.8, 3), cf * CFrame.new(0, h - 0.4, 0), c:Lerp(rgb(0, 0, 0), 0.2), M.Limestone)
	return m
end

function Props.plantPot(parent, cf: CFrame)
	local m = model(parent, "PlantPot")
	C(m, "Pot", 1.6, 1.6, cf * CFrame.new(0, 0.8, 0), rgb(140, 76, 54), M.Brick)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		P(m, "Leaf", Vector3.new(0.45, 2.4, 0.1), cf * CFrame.new(math.cos(a) * 0.45, 2.7, math.sin(a) * 0.45) * CFrame.Angles(math.sin(a) * 0.45, 0, math.cos(a) * 0.45), rgb(52, 92, 50), M.Grass, nc())
	end
	return m
end

function Props.piano(parent, cf: CFrame)
	local m = model(parent, "Piano")
	local base = cf * CFrame.new(0, 0, -0.05 - 1.1)
	P(m, "Body", Vector3.new(5.4, 4.4, 2.2), base * CFrame.new(0, 2.2, 0), rgb(20, 18, 18), M.Wood)
	P(m, "KeyBed", Vector3.new(5, 0.3, 1), base * CFrame.new(0, 2.6, -1.6), rgb(20, 18, 18), M.Wood)
	P(m, "Keys", Vector3.new(4.6, 0.08, 0.8), base * CFrame.new(0, 2.79, -1.6), rgb(240, 236, 226), M.SmoothPlastic, nc())
	for _, x in { -2.2, 2.2 } do
		P(m, "Cheek", Vector3.new(0.3, 2.45, 1), base * CFrame.new(x, 1.225, -1.6), rgb(20, 18, 18), M.Wood)
	end
	return m
end

function Props.rug(parent, cf: CFrame, w: number, d: number, color: Color3)
	local m = model(parent, "Rug")
	P(m, "Rug", Vector3.new(w, 0.05, d), cf * CFrame.new(0, 0.03, 0), color, M.Carpet, nc())
	P(m, "Border", Vector3.new(w - 1, 0.06, d - 1), cf * CFrame.new(0, 0.035, 0), color:Lerp(rgb(0, 0, 0), 0.25), M.Carpet, nc())
	P(m, "Field", Vector3.new(w - 1.6, 0.07, d - 1.6), cf * CFrame.new(0, 0.04, 0), color, M.Carpet, nc())
	return m
end

-- картина на стене: cf на стене, LookVector в комнату. Сюжет — простые пятна
function Props.painting(parent, cf: CFrame, w: number, h: number, seed: number)
	local m = model(parent, "Painting")
	local base = cf * CFrame.new(0, 0, -0.12)
	P(m, "Frame", Vector3.new(w + 0.5, h + 0.5, 0.15), base, Props.BRASS:Lerp(rgb(0, 0, 0), 0.35), M.Wood, nc())
	local hue = (seed * 0.137) % 1
	P(m, "Canvas", Vector3.new(w, h, 0.04), base * CFrame.new(0, 0, -0.09), Color3.fromHSV(hue, 0.3, 0.28), M.SmoothPlastic, nc())
	if seed % 3 == 0 then
		-- портрет: тёмный силуэт с бледным лицом
		P(m, "Figure", Vector3.new(w * 0.4, h * 0.5, 0.03), base * CFrame.new(0, -h * 0.2, -0.12), rgb(20, 18, 20), M.SmoothPlastic, nc())
		S(m, "Face", math.min(w, h) * 0.22, base * CFrame.new(0, h * 0.15, -0.13), rgb(200, 190, 170), M.SmoothPlastic, nc())
	else
		P(m, "Hill", Vector3.new(w, h * 0.35, 0.03), base * CFrame.new(0, -h * 0.32, -0.12), Color3.fromHSV((hue + 0.3) % 1, 0.35, 0.22), M.SmoothPlastic, nc())
		S(m, "Moon", math.min(w, h) * 0.18, base * CFrame.new(w * 0.25, h * 0.25, -0.13), rgb(210, 200, 170), M.SmoothPlastic, nc({ Shape = BALL }))
	end
	return m
end

-- окно в пустоту: рама с переплётом и тёмное стекло ровно в проёме стены.
-- cf — центр проёма на середине стены, LookVector в комнату
Props.WINDOW = { w = 4, h = 5, y = 4.5 }
function Props.window(parent, cf: CFrame, thick: number)
	local m = model(parent, "Window")
	local w, h = Props.WINDOW.w, Props.WINDOW.h
	local frame = Props.WOOD_DARK
	local glass = P(m, "Glass", Vector3.new(w - 0.12, h - 0.12, 0.1), cf, rgb(6, 8, 12), M.Glass, { Transparency = 0.1, Reflectance = 0.15 })
	CollectionService:AddTag(glass, "VoidWindow")
	for _, s in { -1, 1 } do
		-- рама заходит в проём на 0.05, чтобы её грани не совпадали с краями проёма
		P(m, "Jamb", Vector3.new(0.3, h, thick + 0.3), cf * CFrame.new(s * (w / 2 + 0.1), 0, 0), frame, M.Wood)
	end
	P(m, "Lintel", Vector3.new(w + 0.6, 0.3, thick + 0.2), cf * CFrame.new(0, h / 2 + 0.12, 0), frame, M.Wood)
	P(m, "Sill", Vector3.new(w + 1, 0.3, thick + 0.7), cf * CFrame.new(0, -h / 2 - 0.12, -0.3), frame, M.Wood)
	P(m, "Mullion", Vector3.new(0.15, h, 0.2), cf * CFrame.new(0, 0, -0.16), frame, M.Wood, nc())
	P(m, "Transom", Vector3.new(w, 0.15, 0.16), cf * CFrame.new(0, h / 6, -0.16), frame, M.Wood, nc())
	return m
end

-- свет -----------------------------------------------------------------------

-- бра на стене: cf на стене, LookVector в комнату
function Props.sconce(parent, cf: CFrame)
	local m = model(parent, "Sconce")
	P(m, "Plate", Vector3.new(0.6, 1, 0.1), cf * CFrame.new(0, 0, -0.06), Props.BRASS, M.Metal, nc())
	P(m, "Arm", Vector3.new(0.15, 0.15, 0.7), cf * CFrame.new(0, -0.1, -0.45), Props.BRASS, M.Metal, nc())
	local shade = C(m, "Shade", 0.8, 0.9, cf * CFrame.new(0, 0.3, -0.85), rgb(250, 214, 160), M.Neon, nc({ Transparency = 0.3 }))
	light(shade, 14, 0.7, nil, false)
	CollectionService:AddTag(shade, "LabLight")
	return m, shade
end

-- плафон под потолком. pos — точка на потолке
function Props.ceilingLamp(parent, pos: Vector3)
	local m = model(parent, "CeilingLamp")
	C(m, "Rod", 1.2, 0.12, CFrame.new(pos - Vector3.new(0, 0.6, 0)), Props.IRON, M.Metal, nc())
	C(m, "Cap", 0.25, 0.9, CFrame.new(pos - Vector3.new(0, 1.3, 0)), Props.BRASS, M.Metal, nc())
	local bulb = C(m, "Globe", 1, 1.5, CFrame.new(pos - Vector3.new(0, 1.92, 0)), rgb(255, 230, 186), M.Neon, nc({ Transparency = 0.15 }))
	light(bulb, 24, 1.1)
	CollectionService:AddTag(bulb, "LabLight")
	return m, bulb
end

-- люстра с рожками. pos — точка на потолке
function Props.chandelier(parent, pos: Vector3, drop: number)
	local m = model(parent, "Chandelier")
	C(m, "Chain", drop, 0.15, CFrame.new(pos - Vector3.new(0, drop / 2, 0)), Props.IRON, M.Metal, nc())
	local hub = pos - Vector3.new(0, drop + 0.4, 0)
	C(m, "Hub", 0.8, 0.9, CFrame.new(hub), Props.BRASS, M.Metal, nc())
	local glow
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local tip = hub + Vector3.new(math.cos(a) * 1.8, 0.3, math.sin(a) * 1.8)
		rod(m, "Arm", hub, tip, 0.12, Props.BRASS, M.Metal, nc())
		C(m, "Candle", 0.6, 0.25, CFrame.new(tip + Vector3.new(0, 0.3, 0)), rgb(240, 232, 210), M.SmoothPlastic, nc())
		local fl = S(m, "Flame", 0.22, CFrame.new(tip + Vector3.new(0, 0.7, 0)), rgb(255, 190, 100), M.Neon, nc())
		glow = glow or fl
	end
	local core = S(m, "Glow", 0.3, CFrame.new(hub), rgb(255, 210, 150), M.Neon, nc({ Transparency = 1 }))
	light(core, 32, 1.3)
	CollectionService:AddTag(core, "LabLight")
	return m, core
end

-- настольная лампа (на тумбе или столе). cf — точка на поверхности
function Props.tableLamp(parent, cf: CFrame)
	local m = model(parent, "TableLamp")
	C(m, "Base", 0.15, 0.7, cf * CFrame.new(0, 0.08, 0), Props.BRASS, M.Metal, nc())
	C(m, "Stem", 1, 0.12, cf * CFrame.new(0, 0.65, 0), Props.BRASS, M.Metal, nc())
	local shade = C(m, "Shade", 0.8, 1.1, cf * CFrame.new(0, 1.45, 0), rgb(240, 214, 168), M.Neon, nc({ Transparency = 0.3 }))
	light(shade, 10, 0.6, nil, false)
	CollectionService:AddTag(shade, "LabLight")
	return m, shade
end

-- аварийная красная лампа
function Props.emergencyLamp(parent, pos: Vector3)
	local m = model(parent, "EmergencyLamp")
	P(m, "Base", Vector3.new(1, 0.2, 0.6), CFrame.new(pos), Props.IRON, M.Metal, nc())
	local glow = P(m, "Glow", Vector3.new(0.8, 0.4, 0.4), CFrame.new(pos - Vector3.new(0, 0.3, 0)), rgb(200, 30, 24), M.Neon, nc())
	local l = Instance.new("PointLight")
	l.Range = 18
	l.Brightness = 0.6
	l.Color = rgb(255, 40, 30)
	l.Shadows = false
	l.Parent = glow
	return m
end

-- трубы под потолком
function Props.pipes(parent, a: Vector3, b: Vector3, count: number)
	local m = model(parent, "Pipes")
	for k = 0, count - 1 do
		local off = Vector3.new(0, -k * 0.7, 0)
		local p = rod(m, "Pipe", a + off, b + off, 0.5, if k % 2 == 0 then rgb(96, 88, 76) else rgb(120, 70, 50), M.Metal, nc())
		p.Shape = Enum.PartType.Block
	end
	return m
end

-- ---------------------------------------------------------------------------
-- предмет на виду (ключ, деталь); всё остальное лежит в ящиках

function Props.pickup(parent, cf: CFrame, item: string)
	local m = model(parent, "Pickup")
	local root
	if item == "key" then
		root = P(m, "Key", Vector3.new(1.3, 0.12, 0.35), cf * CFrame.new(0, 0.07, 0), Props.BRASS, M.Metal)
		C(m, "Bow", 0.12, 0.7, cf * CFrame.new(-0.85, 0.07, 0), Props.BRASS, M.Metal, nc())
		P(m, "Bit", Vector3.new(0.25, 0.1, 0.35), cf * CFrame.new(0.55, 0.07, 0.25), Props.BRASS, M.Metal, nc())
		local l = Instance.new("PointLight")
		l.Range = 5
		l.Brightness = 0.5
		l.Color = rgb(255, 220, 140)
		l.Parent = root
	elseif item == "fuse" then
		root = C(m, "Fuse", 1.4, 0.7, cf * CFrame.new(0, 0.75, 0), rgb(60, 110, 170), M.Glass)
		for _, y in { 0.1, 1.4 } do
			C(m, "Cap", 0.2, 0.8, cf * CFrame.new(0, y, 0), Props.BRASS, M.Metal, nc())
		end
		local l = Instance.new("PointLight")
		l.Range = 7
		l.Brightness = 0.7
		l.Color = rgb(120, 180, 255)
		l.Parent = root
	elseif item == "battery" then
		root = C(m, "Battery", 1, 0.5, cf * CFrame.new(0, 0.5, 0), rgb(40, 130, 60), M.Metal)
		C(m, "Tip", 0.12, 0.25, cf * CFrame.new(0, 1.06, 0), rgb(200, 200, 200), M.Metal, nc())
	elseif item == "plant" then
		root = C(m, "Sprout", 0.6, 0.8, cf * CFrame.new(0, 0.3, 0), rgb(140, 76, 54), M.Brick)
		S(m, "Leaves", 0.9, cf * CFrame.new(0, 0.95, 0), rgb(80, 170, 90), M.Grass, nc())
	elseif item == "meat" then
		root = P(m, "Meat", Vector3.new(1.3, 0.6, 0.9), cf * CFrame.new(0, 0.3, 0), rgb(150, 40, 40), M.SmoothPlastic)
		C(m, "Bone", 1.9, 0.2, cf * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(230, 224, 204), M.SmoothPlastic, nc())
		P(m, "Fat", Vector3.new(1.34, 0.12, 0.94), cf * CFrame.new(0, 0.5, 0), rgb(220, 190, 170), M.SmoothPlastic, nc())
	elseif item == "hammer" then
		root = P(m, "Handle", Vector3.new(0.2, 0.2, 1.6), cf * CFrame.new(0, 0.12, 0), Props.WOOD, M.Wood)
		P(m, "Head", Vector3.new(0.9, 0.4, 0.4), cf * CFrame.new(0, 0.22, -0.8), rgb(90, 92, 96), M.Metal, nc())
	elseif item == "lockpick" then
		root = P(m, "Pick", Vector3.new(1.2, 0.08, 0.15), cf * CFrame.new(0, 0.05, 0), rgb(170, 170, 176), M.Metal)
		P(m, "Grip", Vector3.new(0.4, 0.12, 0.3), cf * CFrame.new(-0.6, 0.07, 0), rgb(40, 40, 40), M.SmoothPlastic, nc())
	else
		-- стопка монет
		root = C(m, "Coins", 0.3, 0.9, cf * CFrame.new(0, 0.15, 0), rgb(226, 186, 70), M.Metal)
		C(m, "Coin", 0.12, 0.9, cf * CFrame.new(0.3, 0.36, 0.1), rgb(226, 186, 70), M.Metal, nc())
	end
	root:SetAttribute("Item", item)
	Props.prompt(root, "pick", 0, 7)
	return m, root
end

-- генератор для зала Слепого
function Props.generator(parent, cf: CFrame)
	local m = model(parent, "Generator")
	local body = P(m, "Body", Vector3.new(5, 4, 3.4), cf * CFrame.new(0, 2.2, 0), rgb(82, 90, 86), M.DiamondPlate)
	P(m, "Skid", Vector3.new(5.6, 0.4, 3.8), cf * CFrame.new(0, 0.2, 0), rgb(40, 40, 40), M.Metal)
	P(m, "Panel", Vector3.new(2.6, 1.8, 0.1), cf * CFrame.new(-0.8, 2.6, -1.76), rgb(30, 32, 30), M.Metal, nc())
	for k = 0, 2 do
		C(m, "Gauge", 0.1, 0.5, cf * CFrame.new(-1.6 + k * 0.8, 3, -1.82) * CFrame.Angles(math.pi / 2, 0, 0), rgb(230, 226, 210), M.SmoothPlastic, nc())
	end
	local lamp = S(m, "StatusLamp", 0.6, cf * CFrame.new(1.7, 4.5, -1.2), rgb(220, 40, 30), M.Neon, nc())
	local l = Instance.new("PointLight")
	l.Range = 10
	l.Brightness = 1
	l.Color = rgb(255, 60, 40)
	l.Parent = lamp
	C(m, "Exhaust", 2.6, 0.6, cf * CFrame.new(1.8, 5.4, 0.9), rgb(60, 60, 64), M.Metal)
	P(m, "Socket", Vector3.new(0.9, 0.9, 0.2), cf * CFrame.new(1.4, 2.4, -1.78), rgb(20, 20, 20), M.Metal, nc())
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Rate = 0
	sparks.Speed = NumberRange.new(6, 12)
	sparks.Lifetime = NumberRange.new(0.2, 0.5)
	sparks.Size = NumberSequence.new(0.2, 0)
	sparks.Color = ColorSequence.new(rgb(255, 210, 120))
	sparks.LightEmission = 1
	sparks.Parent = body
	Props.prompt(body, "repair", 3, 8)
	return m, body, lamp
end
-- ---------------------------------------------------------------------------
-- музей: постаменты, статуи, витрины, странные экспонаты

local MARBLE = rgb(214, 210, 200)
Props.MARBLE = MARBLE

-- постамент; возвращает кадр верхней грани
function Props.plinth(parent, cf: CFrame, w: number, h: number, color: Color3?)
	local m = model(parent, "Plinth")
	local c = color or rgb(150, 146, 138)
	P(m, "Foot", Vector3.new(w + 0.4, 0.4, w + 0.4), cf * CFrame.new(0, 0.2, 0), c:Lerp(rgb(0, 0, 0), 0.2), M.Marble)
	P(m, "Shaft", Vector3.new(w, h - 0.8, w), cf * CFrame.new(0, h / 2, 0), c, M.Marble)
	P(m, "Cap", Vector3.new(w + 0.3, 0.4, w + 0.3), cf * CFrame.new(0, h - 0.2, 0), c:Lerp(rgb(0, 0, 0), 0.2), M.Marble)
	return m, cf * CFrame.new(0, h, 0)
end

-- странный экспонат размером около s (все детали без столкновений). top — где стоит
local ODD = { "wrench", "gear", "teapot", "skull", "crown", "mask", "clock", "boot", "bottle", "gem", "bulb", "bigkey" }
Props.ODD = ODD
function Props.oddity(parent, top: CFrame, item: string, s: number?)
	local k = s or 1
	local m = model(parent, "Exhibit_" .. item)
	local steel = rgb(150, 154, 158)
	local function b(name, sx, sy, sz, ocf, color, mat)
		return P(m, name, Vector3.new(sx * k, sy * k, sz * k), top * CFrame.new(ocf.Position * k) * ocf.Rotation, color, mat, nc())
	end
	local function c(name, len, d, ocf, color, mat)
		return C(m, name, len * k, d * k, top * CFrame.new(ocf.Position * k) * ocf.Rotation, color, mat, nc())
	end
	local function ball(name, d, ocf, color, mat)
		return S(m, name, d * k, top * CFrame.new(ocf.Position * k), color, mat, nc())
	end
	if item == "wrench" then
		b("Handle", 0.3, 0.14, 1.5, CFrame.new(0, 0.12, 0), steel, M.Metal)
		for _, e in { -1, 1 } do
			b("Jaw", 0.2, 0.2, 0.45, CFrame.new(0.22, 0.12, e * 0.9), steel, M.Metal)
			b("Jaw", 0.2, 0.2, 0.45, CFrame.new(-0.22, 0.12, e * 0.9), steel, M.Metal)
		end
	elseif item == "gear" then
		c("Wheel", 0.2, 1.1, CFrame.new(0, 0.75, 0) * CFrame.Angles(math.pi / 2, 0, 0), rgb(150, 110, 60), M.Metal)
		for t = 0, 7 do
			b("Tooth", 0.22, 0.26, 0.2, CFrame.new(0, 0.75, 0) * CFrame.Angles(0, 0, t * math.pi / 4) * CFrame.new(0, 0.62, 0), rgb(150, 110, 60), M.Metal)
		end
		c("Stand", 0.2, 0.2, CFrame.new(0, 0.1, 0), Props.IRON, M.Metal)
	elseif item == "teapot" then
		ball("Body", 0.9, CFrame.new(0, 0.5, 0), rgb(200, 210, 220), M.SmoothPlastic)
		c("Lid", 0.12, 0.4, CFrame.new(0, 0.95, 0), rgb(60, 90, 150), M.SmoothPlastic)
		b("Spout", 0.14, 0.14, 0.5, CFrame.new(0, 0.6, -0.6) * CFrame.Angles(0.5, 0, 0), rgb(200, 210, 220), M.SmoothPlastic)
		b("Handle", 0.1, 0.5, 0.1, CFrame.new(0, 0.5, 0.55), rgb(200, 210, 220), M.SmoothPlastic)
	elseif item == "skull" then
		ball("Cranium", 0.9, CFrame.new(0, 0.6, 0), rgb(222, 214, 190), M.SmoothPlastic)
		b("Jaw", 0.55, 0.3, 0.5, CFrame.new(0, 0.2, -0.15), rgb(222, 214, 190), M.SmoothPlastic)
		for _, x in { -0.2, 0.2 } do
			ball("Socket", 0.24, CFrame.new(x, 0.62, -0.38), rgb(20, 16, 14), M.SmoothPlastic)
		end
	elseif item == "crown" then
		c("Band", 0.3, 0.9, CFrame.new(0, 0.25, 0), Props.BRASS, M.Metal)
		for t = 0, 4 do
			local a = t / 5 * math.pi * 2
			b("Point", 0.14, 0.45, 0.14, CFrame.new(math.cos(a) * 0.38, 0.6, math.sin(a) * 0.38), Props.BRASS, M.Metal)
			ball("Jewel", 0.14, CFrame.new(math.cos(a) * 0.38, 0.88, math.sin(a) * 0.38), rgb(190, 30, 50), M.Neon)
		end
	elseif item == "mask" then
		c("Face", 0.1, 1, CFrame.new(0, 0.75, 0) * CFrame.Angles(math.pi / 2, 0, 0), rgb(226, 220, 204), M.SmoothPlastic)
		for _, x in { -0.2, 0.2 } do
			b("Eye", 0.2, 0.1, 0.05, CFrame.new(x, 0.85, -0.07), rgb(0, 0, 0), M.SmoothPlastic)
		end
		b("Mouth", 0.36, 0.06, 0.05, CFrame.new(0, 0.5, -0.07), rgb(0, 0, 0), M.SmoothPlastic)
		c("Stand", 0.25, 0.14, CFrame.new(0, 0.12, 0), Props.IRON, M.Metal)
	elseif item == "clock" then
		c("Case", 0.25, 1, CFrame.new(0, 0.6, 0) * CFrame.Angles(math.pi / 2, 0, 0), Props.WOOD_DARK, M.Wood)
		c("Dial", 0.05, 0.8, CFrame.new(0, 0.6, -0.14) * CFrame.Angles(math.pi / 2, 0, 0), rgb(236, 230, 210), M.SmoothPlastic)
		b("Hand", 0.05, 0.34, 0.03, CFrame.new(0, 0.74, -0.18), rgb(20, 20, 20), M.SmoothPlastic)
		b("Hand", 0.24, 0.05, 0.03, CFrame.new(0.13, 0.6, -0.2), rgb(20, 20, 20), M.SmoothPlastic)
	elseif item == "boot" then
		b("Shaft", 0.4, 0.8, 0.45, CFrame.new(0, 0.55, 0.15), rgb(70, 46, 30), M.Leather)
		b("Foot", 0.45, 0.3, 0.9, CFrame.new(0, 0.23, -0.1), rgb(70, 46, 30), M.Leather)
		b("Sole", 0.5, 0.08, 1, CFrame.new(0, 0.04, -0.1), rgb(20, 18, 16), M.SmoothPlastic)
	elseif item == "bottle" then
		c("Body", 0.8, 0.45, CFrame.new(0, 0.4, 0), rgb(40, 90, 60), M.Glass)
		c("Neck", 0.4, 0.18, CFrame.new(0, 1, 0), rgb(40, 90, 60), M.Glass)
		c("Cork", 0.12, 0.2, CFrame.new(0, 1.25, 0), rgb(150, 110, 70), M.Wood)
	elseif item == "gem" then
		b("Gem", 0.6, 0.6, 0.6, CFrame.new(0, 0.6, 0) * CFrame.Angles(0.6, 0.8, 0.3), rgb(70, 150, 220), M.Glass)
		b("Pad", 0.9, 0.1, 0.9, CFrame.new(0, 0.05, 0), rgb(90, 20, 30), M.Fabric)
	elseif item == "bulb" then
		ball("Glass", 0.7, CFrame.new(0, 0.75, 0), rgb(240, 236, 210), M.Glass)
		c("Base", 0.35, 0.34, CFrame.new(0, 0.28, 0), steel, M.Metal)
	else
		b("Shank", 0.14, 0.14, 1.2, CFrame.new(0, 0.1, 0), Props.BRASS, M.Metal)
		c("Bow", 0.14, 0.6, CFrame.new(0, 0.1, 0.8), Props.BRASS, M.Metal)
		b("Bit", 0.4, 0.1, 0.2, CFrame.new(0.2, 0.1, -0.45), Props.BRASS, M.Metal)
	end
	return m
end

-- витрина на тумбе: стеклянный колпак, латунные рёбра, внутри экспонат
function Props.displayCase(parent, cf: CFrame, item: string)
	local m = model(parent, "DisplayCase")
	P(m, "Base", Vector3.new(2.6, 2.4, 2.6), cf * CFrame.new(0, 1.2, 0), Props.WOOD_DARK, M.Wood)
	P(m, "Lip", Vector3.new(2.9, 0.2, 2.9), cf * CFrame.new(0, 2.5, 0), Props.BRASS, M.Metal)
	P(m, "Glass", Vector3.new(2.4, 2.6, 2.4), cf * CFrame.new(0, 3.9, 0), rgb(200, 220, 226), M.Glass, { Transparency = 0.8 })
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			P(m, "Edge", Vector3.new(0.12, 2.5, 0.12), cf * CFrame.new(sx * 1.2, 3.9, sz * 1.2), Props.BRASS, M.Metal, nc())
		end
	end
	P(m, "Roof", Vector3.new(2.6, 0.12, 2.6), cf * CFrame.new(0, 5.26, 0), Props.BRASS, M.Metal, nc())
	P(m, "Pad", Vector3.new(1.6, 0.1, 1.6), cf * CFrame.new(0, 2.67, 0), rgb(90, 20, 30), M.Fabric, nc())
	Props.oddity(m, cf * CFrame.new(0, 2.72, 0), item, 1)
	return m
end

-- настенная витрина с полками мелочей (cf у стены)
function Props.wallCase(parent, cf: CFrame, w: number, seed: number)
	local m = model(parent, "WallCase")
	local d = 1.3
	local base = cf * CFrame.new(0, 0, -0.05 - d / 2)
	P(m, "Cabinet", Vector3.new(w, 2.2, d), base * CFrame.new(0, 1.1, 0), Props.WOOD_DARK, M.Wood)
	P(m, "Back", Vector3.new(w, 4.6, 0.15), base * CFrame.new(0, 4.5, d / 2 - 0.075), Props.WOOD_DARK, M.Wood)
	for _, s in { -1, 1 } do
		P(m, "Side", Vector3.new(0.15, 4.6, d - 0.15), base * CFrame.new(s * (w / 2 - 0.075), 4.5, -0.075), Props.WOOD_DARK, M.Wood)
	end
	P(m, "Top", Vector3.new(w + 0.2, 0.2, d + 0.1), base * CFrame.new(0, 6.9, -0.05), Props.WOOD_DARK, M.Wood)
	P(m, "Glass", Vector3.new(w - 0.3, 4.6, 0.06), base * CFrame.new(0, 4.5, -d / 2 + 0.03), rgb(200, 220, 226), M.Glass, { Transparency = 0.8 })
	P(m, "Shelf", Vector3.new(w - 0.3, 0.1, d - 0.3), base * CFrame.new(0, 4.4, -0.03), Props.WOOD, M.Wood, nc())
	local n = math.max(2, math.floor(w / 2))
	for k = 0, n - 1 do
		local x = -w / 2 + (k + 0.5) * w / n
		Props.oddity(m, base * CFrame.new(x, 2.2, 0), ODD[(seed + k * 5) % #ODD + 1], 0.7)
		Props.oddity(m, base * CFrame.new(x, 4.45, 0), ODD[(seed + k * 7 + 3) % #ODD + 1], 0.7)
	end
	return m
end

-- статуя на постаменте: bust, figure, abstract, obelisk, broken
function Props.statue(parent, cf: CFrame, kind: string, seed: number?)
	local m = model(parent, "Statue")
	local _, top = Props.plinth(m, cf, 2.6, 2.6)
	local c = MARBLE
	local function b(name, sx, sy, sz, ocf)
		return P(m, name, Vector3.new(sx, sy, sz), top * ocf, c, M.Marble, nc())
	end
	if kind == "bust" then
		b("Chest", 1.8, 1.1, 1, CFrame.new(0, 0.55, 0))
		C(m, "Neck", 0.5, 0.5, top * CFrame.new(0, 1.3, 0), c, M.Marble, nc())
		S(m, "Head", 1.2, top * CFrame.new(0, 2, 0), c, M.Marble, nc())
		b("Nose", 0.16, 0.3, 0.2, CFrame.new(0, 1.95, -0.62))
	elseif kind == "abstract" then
		b("Cube", 1.6, 1.6, 1.6, CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0.5, 0))
		b("Cube", 1.1, 1.1, 1.1, CFrame.new(0.1, 2.1, 0) * CFrame.Angles(0.4, 1, 0.3))
		S(m, "Orb", 0.9, top * CFrame.new(-0.1, 3.2, 0.1), c, M.Marble, nc())
	elseif kind == "obelisk" then
		b("Tier", 1.6, 1.6, 1.6, CFrame.new(0, 0.8, 0))
		b("Tier", 1.2, 2, 1.2, CFrame.new(0, 2.6, 0))
		b("Tier", 0.8, 1.6, 0.8, CFrame.new(0, 4.4, 0))
		b("Tip", 0.4, 0.5, 0.4, CFrame.new(0, 5.45, 0) * CFrame.Angles(0, math.pi / 4, 0))
	else
		for _, x in { -0.35, 0.35 } do
			b("Leg", 0.5, 2.2, 0.5, CFrame.new(x, 1.1, 0))
		end
		b("Torso", 1.4, 1.8, 0.8, CFrame.new(0, 3.1, 0))
		Props.rod(m, "Arm", (top * CFrame.new(-0.85, 3.8, 0)).Position, (top * CFrame.new(-1.1, 2.3, -0.3)).Position, 0.34, c, M.Marble, nc())
		if kind ~= "broken" then
			Props.rod(m, "Arm", (top * CFrame.new(0.85, 3.8, 0)).Position, (top * CFrame.new(1.3, 4.9, -0.4)).Position, 0.34, c, M.Marble, nc())
			S(m, "Head", 0.9, top * CFrame.new(0, 4.5, 0), c, M.Marble, nc())
		else
			C(m, "NeckStump", 0.2, 0.4, top * CFrame.new(0, 4.1, 0), c:Lerp(rgb(0, 0, 0), 0.3), M.Marble, nc())
		end
	end
	local _ = seed
	return m
end

-- ваза на тумбе
function Props.vase(parent, cf: CFrame, seed: number)
	local m = model(parent, "Vase")
	local _, top = Props.plinth(m, cf, 1.8, 2.2)
	local col = Color3.fromHSV(({ 0.58, 0.02, 0.1, 0.45, 0.75 })[seed % 5 + 1], 0.45, 0.6)
	C(m, "FootRing", 0.3, 0.8, top * CFrame.new(0, 0.15, 0), col, M.SmoothPlastic, nc())
	S(m, "Belly", 1.4, top * CFrame.new(0, 0.95, 0), col, M.SmoothPlastic, nc())
	C(m, "Neck", 0.7, 0.55, top * CFrame.new(0, 1.85, 0), col, M.SmoothPlastic, nc())
	C(m, "Rim", 0.12, 0.85, top * CFrame.new(0, 2.25, 0), col:Lerp(rgb(255, 255, 255), 0.3), M.SmoothPlastic, nc())
	C(m, "Stripe", 0.1, 1.44, top * CFrame.new(0, 0.95, 0), rgb(236, 226, 200), M.SmoothPlastic, nc())
	return m
end

-- доспех на стойке у стены
function Props.armor(parent, cf: CFrame)
	local m = model(parent, "Armor")
	local base = cf * CFrame.new(0, 0, -0.05 - 1.2)
	local steel = rgb(140, 146, 152)
	C(m, "Base", 0.3, 2.2, base * CFrame.new(0, 0.15, 0), Props.WOOD_DARK, M.Wood)
	P(m, "Torso", Vector3.new(1.8, 2, 1), base * CFrame.new(0, 4, 0), steel, M.Metal)
	for _, x in { -0.45, 0.45 } do
		P(m, "Leg", Vector3.new(0.6, 2.7, 0.6), base * CFrame.new(x, 1.65, 0), steel, M.Metal, nc())
		S(m, "Pauldron", 0.9, base * CFrame.new(x * 2.6, 4.8, 0), steel, M.Metal, nc())
		P(m, "Arm", Vector3.new(0.45, 1.9, 0.45), base * CFrame.new(x * 2.6, 3.6, 0), steel, M.Metal, nc())
	end
	S(m, "Helmet", 1.1, base * CFrame.new(0, 5.7, 0), steel, M.Metal, nc())
	P(m, "Visor", Vector3.new(0.7, 0.14, 0.1), base * CFrame.new(0, 5.75, -0.52), rgb(10, 10, 10), M.SmoothPlastic, nc())
	C(m, "Plume", 0.9, 0.2, base * CFrame.new(0, 6.5, 0.1), rgb(150, 30, 34), M.Fabric, nc())
	C(m, "Spear", 7.5, 0.14, base * CFrame.new(1.5, 3.75, -0.2), Props.WOOD, M.Wood, nc())
	P(m, "SpearTip", Vector3.new(0.3, 0.8, 0.1), base * CFrame.new(1.5, 7.9, -0.2), steel, M.Metal, nc())
	return m
end

-- ограждение: две стойки и бархатный канат
function Props.rope(parent, a: Vector3, b: Vector3)
	local m = model(parent, "Rope")
	for _, p in { a, b } do
		C(m, "Post", 3, 0.22, CFrame.new(p + Vector3.new(0, 1.5, 0)), Props.BRASS, M.Metal, nc())
		C(m, "Foot", 0.12, 1, CFrame.new(p + Vector3.new(0, 0.06, 0)), Props.BRASS, M.Metal, nc())
		S(m, "Knob", 0.4, CFrame.new(p + Vector3.new(0, 3.1, 0)), Props.BRASS, M.Metal, nc())
	end
	local mid = (a + b) / 2 + Vector3.new(0, 2.3, 0)
	Props.rod(m, "Velvet", a + Vector3.new(0, 2.8, 0), mid, 0.16, rgb(120, 20, 30), M.Fabric, nc())
	Props.rod(m, "Velvet", mid, b + Vector3.new(0, 2.8, 0), 0.16, rgb(120, 20, 30), M.Fabric, nc())
	return m
end

-- скелет ископаемого на подиуме. cf — центр, длина вдоль LookVector
function Props.fossil(parent, cf: CFrame, len: number)
	local m = model(parent, "Fossil")
	local bone = rgb(206, 196, 170)
	P(m, "Podium", Vector3.new(8, 0.8, len + 2), cf * CFrame.new(0, 0.4, 0), Props.WOOD_DARK, M.Wood)
	local function pt(x, y, z)
		return (cf * CFrame.new(x, y, z)).Position
	end
	local function bn(a, b, t)
		Props.rod(m, "Bone", a, b, t, bone, M.SmoothPlastic, nc())
	end
	local h = 6.5
	bn(pt(0, h, -len * 0.3), pt(0, h + 0.4, len * 0.15), 0.5)
	bn(pt(0, h + 0.4, len * 0.15), pt(0, h - 2.5, len * 0.5), 0.35)
	bn(pt(0, h, -len * 0.3), pt(0, h + 2.2, -len * 0.42), 0.45)
	P(m, "Skull", Vector3.new(1.4, 1.5, 2.6), cf * CFrame.new(0, h + 2.4, -len * 0.42 - 1.2), bone, M.SmoothPlastic, nc())
	P(m, "Jaw", Vector3.new(1.1, 0.4, 2.2), cf * CFrame.new(0, h + 1.5, -len * 0.42 - 1.3) * CFrame.Angles(0.2, 0, 0), bone, M.SmoothPlastic, nc())
	for k = 0, 6 do
		local z = -len * 0.25 + k * len * 0.055
		for _, s in { -1, 1 } do
			bn(pt(0, h + 0.2, z), pt(s * 1.5, h - 1.2, z), 0.18)
			bn(pt(s * 1.5, h - 1.2, z), pt(s * 0.9, h - 2.8, z), 0.16)
		end
	end
	for _, z in { -len * 0.24, len * 0.1 } do
		for _, s in { -1, 1 } do
			bn(pt(s * 0.9, h - 0.2, z), pt(s * 1.6, h - 3.4, z - 0.6), 0.4)
			bn(pt(s * 1.6, h - 3.4, z - 0.6), pt(s * 1.5, 0.9, z + 0.3), 0.34)
		end
	end
	for _, z in { -len * 0.2, len * 0.1 } do
		C(m, "Support", h - 1, 0.18, cf * CFrame.new(0, 0.8 + (h - 1) / 2, z), Props.BRASS, M.Metal, nc())
	end
	return m
end

-- столик кафе с двумя стульями
function Props.cafeTable(parent, cf: CFrame)
	local m = model(parent, "CafeTable")
	C(m, "Top", 0.2, 3.2, cf * CFrame.new(0, 3, 0), rgb(220, 214, 200), M.Marble)
	C(m, "Stem", 2.8, 0.3, cf * CFrame.new(0, 1.5, 0), Props.IRON, M.Metal)
	C(m, "Foot", 0.15, 1.6, cf * CFrame.new(0, 0.08, 0), Props.IRON, M.Metal, nc())
	Props.chair(m, cf * CFrame.new(-2.7, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0))
	Props.chair(m, cf * CFrame.new(2.7, 0, 0) * CFrame.Angles(0, math.pi / 2, 0))
	C(m, "Cup", 0.3, 0.35, cf * CFrame.new(0.5, 3.25, 0.3), rgb(240, 240, 236), M.SmoothPlastic, nc())
	return m, cf * CFrame.new(-0.4, 3.12, -0.2)
end

-- туалеты: ряд кабинок с унитазами. cf — середина ряда у стены
function Props.toilet(parent, cf: CFrame)
	local white = rgb(236, 236, 232)
	P(parent, "Tank", Vector3.new(1.5, 1.4, 0.6), cf * CFrame.new(0, 2.5, -0.4), white, M.SmoothPlastic)
	P(parent, "TankLid", Vector3.new(1.6, 0.14, 0.7), cf * CFrame.new(0, 3.27, -0.4), white, M.SmoothPlastic, nc())
	C(parent, "Flush", 0.1, 0.25, cf * CFrame.new(0, 3.38, -0.4), Props.STEEL, M.Metal, nc())
	C(parent, "Pedestal", 1, 1, cf * CFrame.new(0, 0.5, -1.2), white, M.SmoothPlastic)
	C(parent, "Bowl", 0.7, 1.5, cf * CFrame.new(0, 1.25, -1.35), white, M.SmoothPlastic)
	C(parent, "BowlFront", 0.66, 1.3, cf * CFrame.new(0, 1.23, -1.75), white, M.SmoothPlastic, nc())
	C(parent, "Seat", 0.1, 1.7, cf * CFrame.new(0, 1.66, -1.5), rgb(250, 250, 248), M.SmoothPlastic, nc())
	C(parent, "Water", 0.04, 1, cf * CFrame.new(0, 1.74, -1.5), rgb(90, 130, 150), M.Glass, nc())
	C(parent, "Pipe", 0.6, 0.18, cf * CFrame.new(0, 1.8, -0.75) * CFrame.Angles(math.pi / 2, 0, 0), white, M.SmoothPlastic, nc())
end

function Props.stallRow(parent, cf: CFrame, n: number)
	local m = model(parent, "Stalls")
	local sw, d, h = 4.6, 5.4, 7.2
	local panel = rgb(120, 136, 128)
	local total = n * sw
	local base = cf * CFrame.new(0, 0, -0.05)
	for k = 0, n do
		local x = -total / 2 + k * sw
		P(m, "Partition", Vector3.new(0.15, h - 0.9, d), base * CFrame.new(x, 0.9 + (h - 0.9) / 2, -d / 2), panel, M.Metal)
		P(m, "Post", Vector3.new(0.25, h + 0.3, 0.25), base * CFrame.new(x, (h + 0.3) / 2, -d - 0.13), rgb(170, 170, 176), M.Metal)
	end
	P(m, "TopRail", Vector3.new(total + 0.2, 0.2, 0.2), base * CFrame.new(0, h + 0.4, -d - 0.13), rgb(170, 170, 176), M.Metal, nc())
	for k = 0, n - 1 do
		local x = -total / 2 + (k + 0.5) * sw
		Props.toilet(m, base * CFrame.new(x, 0, 0))
		-- дверца распахнута внутрь и прижата к перегородке: в кабинку можно зайти
		P(m, "StallDoor", Vector3.new(0.12, h - 1.3, sw - 1), base * CFrame.new(x + sw / 2 - 0.32, 0.9 + (h - 1.3) / 2, -d + (sw - 1) / 2 + 0.1), panel:Lerp(rgb(255, 255, 255), 0.08), M.Metal)
		C(m, "Latch", 0.3, 0.14, base * CFrame.new(x + sw / 2 - 0.45, 3.6, -d + 0.5) * CFrame.Angles(0, 0, math.pi / 2), rgb(170, 170, 176), M.Metal, nc())
		C(m, "PaperRoll", 0.5, 0.5, base * CFrame.new(x - sw / 2 + 0.4, 2.4, -2.6) * CFrame.Angles(0, 0, math.pi / 2), rgb(240, 240, 236), M.SmoothPlastic, nc())
	end
	return m
end

-- столешница с круглыми раковинами и длинным зеркалом
function Props.sinkRow(parent, cf: CFrame, n: number)
	local m = model(parent, "Sinks")
	local w, d = n * 3.2, 2
	local base = cf * CFrame.new(0, 0, -0.05 - d / 2)
	P(m, "Counter", Vector3.new(w, 0.3, d), base * CFrame.new(0, 3, 0), rgb(60, 62, 66), M.Granite)
	P(m, "Apron", Vector3.new(w - 0.4, 2.8, 0.2), base * CFrame.new(0, 1.45, -0.5), rgb(200, 200, 194), M.SmoothPlastic)
	for k = 0, n - 1 do
		local x = -w / 2 + (k + 0.5) * 3.2
		C(m, "Basin", 0.22, 1.7, base * CFrame.new(x, 3.26, -0.1), rgb(240, 240, 236), M.SmoothPlastic, nc())
		C(m, "Drain", 0.04, 1.2, base * CFrame.new(x, 3.38, -0.1), rgb(150, 170, 180), M.Glass, nc())
		C(m, "Tap", 0.7, 0.14, base * CFrame.new(x, 3.5, 0.7), Props.STEEL, M.Metal, nc())
		P(m, "Spout", Vector3.new(0.12, 0.12, 0.6), base * CFrame.new(x, 3.8, 0.45), Props.STEEL, M.Metal, nc())
	end
	P(m, "Mirror", Vector3.new(w - 0.4, 3, 0.1), cf * CFrame.new(0, 6, 0.2), rgb(170, 186, 196), M.Glass, { Reflectance = 0.3 })
	P(m, "MirrorFrame", Vector3.new(w, 3.4, 0.06), cf * CFrame.new(0, 6, 0.27), Props.STEEL, M.Metal, nc())
	return m
end

-- зеркало на стойке (зал Колосса): поворачивается вокруг стойки
function Props.mirrorStand(parent, cf: CFrame)
	local m = model(parent, "MirrorStand")
	C(m, "Foot", 0.4, 3, cf * CFrame.new(0, 0.2, 0), Props.IRON, M.Metal)
	C(m, "Pole", 3.4, 0.4, cf * CFrame.new(0, 2.1, 0), Props.BRASS, M.Metal)
	local head = model(m, "Head")
	local glass = P(head, "Mirror", Vector3.new(3.6, 4.4, 0.16), cf * CFrame.new(0, 5.6, 0), rgb(190, 206, 214), M.Glass, { Reflectance = 0.55 })
	P(head, "Frame", Vector3.new(4, 4.8, 0.1), cf * CFrame.new(0, 5.6, 0), Props.BRASS, M.Metal, nc())
	C(head, "Yoke", 0.5, 0.5, cf * CFrame.new(0, 3.55, 0), Props.BRASS, M.Metal, nc())
	head.WorldPivot = cf
	return m, head, glass
end

-- улица: дерево и фонарь
function Props.tree(parent, cf: CFrame, h: number, seed: number)
	local m = model(parent, "Tree")
	C(m, "Trunk", h, 1.4 + (seed % 3) * 0.3, cf * CFrame.new(0, h / 2, 0), rgb(54, 40, 30), M.Wood)
	local leaf = rgb(22, 44, 30):Lerp(rgb(34, 60, 36), (seed % 4) / 4)
	S(m, "Crown", 11 + seed % 4, cf * CFrame.new(0, h + 2, 0), leaf, M.Grass, nc())
	S(m, "Crown", 8, cf * CFrame.new(3, h - 1, 2), leaf, M.Grass, nc())
	S(m, "Crown", 7, cf * CFrame.new(-3, h, -2), leaf, M.Grass, nc())
	return m
end

function Props.lampPost(parent, cf: CFrame)
	local m = model(parent, "LampPost")
	C(m, "Pole", 11, 0.4, cf * CFrame.new(0, 5.5, 0), Props.IRON, M.Metal)
	C(m, "Foot", 0.8, 1, cf * CFrame.new(0, 0.4, 0), Props.IRON, M.Metal, nc())
	local glow = P(m, "Lantern", Vector3.new(1, 1.4, 1), cf * CFrame.new(0, 11.7, 0), rgb(255, 214, 150), M.Neon, nc())
	P(m, "Cap", Vector3.new(1.4, 0.2, 1.4), cf * CFrame.new(0, 12.5, 0), Props.IRON, M.Metal, nc())
	local l = Instance.new("PointLight")
	l.Range = 34
	l.Brightness = 1.4
	l.Color = rgb(255, 206, 150)
	l.Parent = glow
	return m
end


return Props
