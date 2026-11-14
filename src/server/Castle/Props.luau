--!nonstrict
-- Детализированные модели замка, собранные из деталей: двери с филёнками и номерами,
-- окна со шторами, бра, люстры, ковры, картины, комоды, шкафы, кровати, столы, стулья,
-- камины, доспехи, растения, часы, пианино и многое другое.
-- Правило координат: cf — центр основания на полу, LookVector смотрит «лицом» в комнату

local CollectionService = game:GetService("CollectionService")

local Props = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
Props.rgb = rgb

local M = require(game:GetService("ReplicatedStorage").Workshop.Shared.Materials)
local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball

Props.WOOD = rgb(86, 56, 36)
Props.WOOD_DARK = rgb(52, 34, 24)
Props.WOOD_LIGHT = rgb(132, 92, 58)
Props.GOLD = rgb(206, 166, 82)
Props.IRON = rgb(46, 44, 42)
Props.STONE = rgb(148, 142, 132)
Props.STONE_DARK = rgb(96, 92, 88)
Props.CLOTH = rgb(236, 230, 214)

local count = 0
function Props.count()
	return count
end

-- Основная деталь: всё закреплено, без лишних поверхностей
local function P(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, extra)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.SmoothPlastic
	if extra then
		for k, v in extra do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	count += 1
	return p
end
Props.P = P

-- цилиндр стоя (ось Y)
local function C(parent, name, h: number, d: number, cf: CFrame, color, mat, extra)
	local p = P(parent, name, Vector3.new(h, d, d), cf * CFrame.Angles(0, 0, math.pi / 2), color, mat, extra)
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

-- Метка взаимодействия: сборщик потом вешает на деталь кнопку нужного вида
local function mark(part: Instance?, kind: string, hold: number?, dist: number?)
	if part then
		part:SetAttribute("Interact", kind)
		if hold then
			part:SetAttribute("InteractHold", hold)
		end
		if dist then
			part:SetAttribute("InteractDist", dist)
		end
	end
	return part
end
Props.mark = mark

-- Сиденье: настоящий Seat (садиться по кнопке, без случайных посадок на ходу)
local function seat(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat)
	local s = Instance.new("Seat")
	s.Name = name
	s.Anchored = true
	s.Disabled = true
	s.TopSurface = Enum.SurfaceType.Smooth
	s.BottomSurface = Enum.SurfaceType.Smooth
	s.Size = size
	s.CFrame = cf
	s.Color = color
	s.Material = mat or M.SmoothPlastic
	s.Parent = parent
	count += 1
	mark(s, "sit", 0, 7)
	return s
end
Props.seat = seat

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end
Props.model = model

local function light(at: Instance, range: number, brightness: number, color: Color3?)
	local l = Instance.new("PointLight")
	l.Range = range
	l.Brightness = brightness
	l.Color = color or rgb(255, 196, 130)
	l.Shadows = false
	l.Parent = at
	return l
end
Props.light = light

local NOCOL = { CanCollide = false }
local function nc(extra)
	local t = { CanCollide = false, CanQuery = false, CastShadow = false }
	for k, v in extra or {} do
		t[k] = v
	end
	return t
end

-- ---------------------------------------------------------------------------
-- двери, окна, свет

local doorNumber = 0

-- Дверной проём с рамой и одной или двумя створками. cf — центр проёма на полу,
-- LookVector перпендикулярен стене. Створки не мешают проходу: открываются у игрока
function Props.door(parent, cf: CFrame, w: number, h: number, color: Color3?, double: boolean?)
	local m = model(parent, "Door")
	local wood = color or Props.WOOD
	local frame = Props.WOOD_DARK
	P(m, "Jamb", Vector3.new(0.7, h + 0.7, 1.6), cf * CFrame.new(-w / 2 - 0.35, (h + 0.7) / 2, 0), frame, M.Wood)
	P(m, "Jamb", Vector3.new(0.7, h + 0.7, 1.6), cf * CFrame.new(w / 2 + 0.35, (h + 0.7) / 2, 0), frame, M.Wood)
	P(m, "Head", Vector3.new(w + 2.2, 0.8, 1.7), cf * CFrame.new(0, h + 0.4, 0), frame, M.Wood)
	P(m, "Cap", Vector3.new(w + 2.8, 0.3, 1.9), cf * CFrame.new(0, h + 0.95, 0), frame, M.Wood)
	local leaves = if double then { { -w / 2, w / 2, 1 }, { w / 2, w / 2, -1 } } else { { -w / 2, w, 1 } }
	for _, lf in leaves do
		local hingeX, lw, dir = lf[1], lf[2], lf[3]
		local leaf = model(m, "Leaf")
		local base = cf * CFrame.new(hingeX + dir * lw / 2, 0, 0)
		P(leaf, "Slab", Vector3.new(lw - 0.1, h - 0.1, 0.32), base * CFrame.new(0, h / 2, 0), wood, M.Wood, nc())
		-- филёнки с обеих сторон: две высокие и две низкие
		for _, side in { -1, 1 } do
			for _, pz in { { 0.62, 0.42 }, { 0.2, 0.3 } } do
				for _, px in { -0.22, 0.22 } do
					local pw = lw * 0.36
					local ph = h * pz[2]
					P(leaf, "Panel", Vector3.new(pw, ph, 0.08), base * CFrame.new(px * lw, h * pz[1] + (if pz[1] > 0.5 then 0 else 0.4), side * 0.19), wood:Lerp(Props.WOOD_DARK, 0.3), M.Wood, nc())
				end
			end
			S(leaf, "Knob", 0.36, base * CFrame.new(-dir * (lw / 2 - 0.5), h * 0.45, side * 0.3), Props.GOLD, M.Metal, nc())
		end
		for _, hy in { 0.2, 0.8 } do
			P(leaf, "Hinge", Vector3.new(0.15, 0.6, 0.4), base * CFrame.new(-dir * lw / 2, h * hy, 0), Props.IRON, M.Metal, nc())
		end
		leaf.WorldPivot = cf * CFrame.new(hingeX, 0, 0)
		leaf:SetAttribute("Dir", dir)
	end
	-- табличка с номером, как в старом отеле
	doorNumber += 1
	local plate = P(m, "Plate", Vector3.new(1.6, 0.6, 0.06), cf * CFrame.new(0, h + 0.4, -0.88), Props.GOLD, M.Metal, nc())
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(160, 60)
	gui.LightInfluence = 1
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = string.format("%04d", doorNumber)
	t.Font = Enum.Font.Garamond
	t.TextScaled = true
	t.TextColor3 = rgb(40, 28, 16)
	t.Parent = gui
	gui.Parent = plate
	pcall(function()
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	CollectionService:AddTag(m, "CastleDoor")
	return m
end

-- Окно на внешней стене: каменный откос, рама с переплётом, стекло, подоконник,
-- внутри шторы. cf — центр окна, LookVector смотрит наружу
function Props.window(parent, cf: CFrame, w: number, h: number, thick: number)
	local m = model(parent, "Window")
	local stone = Props.STONE_DARK
	P(m, "Sill", Vector3.new(w + 1.4, 0.5, thick + 1.2), cf * CFrame.new(0, -h / 2 - 0.25, 0), stone, M.Slate)
	P(m, "Lintel", Vector3.new(w + 1.4, 0.9, thick + 0.6), cf * CFrame.new(0, h / 2 + 0.45, 0), stone, M.Slate)
	-- полукруглый верх из ступенек
	for k = 1, 3 do
		local ww = w * (1 - k * 0.22)
		P(m, "Arch", Vector3.new(ww, 0.5, thick + 0.2), cf * CFrame.new(0, h / 2 - 0.25 - (3 - k) * 0, 0) * CFrame.new(0, -0.5 * k + 0.5, 0), stone, M.Slate, nc())
	end
	P(m, "Glass", Vector3.new(w, h, 0.15), cf, rgb(150, 182, 206), M.Glass, nc({ Transparency = 0.55 }))
	P(m, "FrameL", Vector3.new(0.35, h, 0.5), cf * CFrame.new(-w / 2, 0, 0), Props.WOOD_DARK, M.Wood)
	P(m, "FrameR", Vector3.new(0.35, h, 0.5), cf * CFrame.new(w / 2, 0, 0), Props.WOOD_DARK, M.Wood)
	P(m, "Mullion", Vector3.new(0.2, h, 0.35), cf, Props.WOOD_DARK, M.Wood, nc())
	for _, y in { -h / 4, h / 4 } do
		P(m, "Transom", Vector3.new(w, 0.2, 0.35), cf * CFrame.new(0, y, 0), Props.WOOD_DARK, M.Wood, nc())
	end
	return m
end

-- Шторы с внутренней стороны окна. cf — центр окна, LookVector в комнату
function Props.curtains(parent, cf: CFrame, w: number, h: number, color: Color3)
	local m = model(parent, "Curtains")
	P(m, "Rod", Vector3.new(w + 3, 0.2, 0.2), cf * CFrame.new(0, h / 2 + 1, -0.4), Props.GOLD, M.Metal, nc())
	for _, s in { -1, 1 } do
		for k = 0, 2 do
			P(m, "Drape", Vector3.new(0.7, h + 1.6, 0.25), cf * CFrame.new(s * (w / 2 + 0.3 + k * 0.45), -0.2, -0.45 - (k % 2) * 0.12), color:Lerp(rgb(0, 0, 0), k * 0.08), M.SmoothPlastic, nc())
		end
		P(m, "Tie", Vector3.new(1.6, 0.25, 0.4), cf * CFrame.new(s * (w / 2 + 0.75), -h * 0.15, -0.6), Props.GOLD, M.Metal, nc())
	end
	P(m, "Valance", Vector3.new(w + 3, 1, 0.3), cf * CFrame.new(0, h / 2 + 0.5, -0.55), color:Lerp(rgb(0, 0, 0), 0.15), M.SmoothPlastic, nc())
	return m
end

-- Бра на стене: подложка, кронштейн, стеклянный плафон и тёплый свет.
-- cf — точка на стене, LookVector от стены
function Props.sconce(parent, cf: CFrame, withLight: boolean?)
	local m = model(parent, "Sconce")
	P(m, "Plate", Vector3.new(0.8, 1.4, 0.12), cf * CFrame.new(0, 0, -0.06), Props.GOLD, M.Metal, nc())
	P(m, "Arm", Vector3.new(0.18, 0.18, 1), cf * CFrame.new(0, -0.2, -0.55), Props.GOLD, M.Metal, nc())
	C(m, "Cup", 0.25, 0.6, cf * CFrame.new(0, 0, -1.05), Props.GOLD, M.Metal, nc())
	local shade = C(m, "Shade", 0.9, 0.75, cf * CFrame.new(0, 0.55, -1.05), rgb(255, 214, 160), M.Neon, nc({ Transparency = 0.25 }))
	if withLight ~= false then
		light(shade, 16, 1.1)
	end
	return m
end

-- Подвесной светильник в духе старого отеля: штанга, абажур-колокол, лампа
function Props.ceilingLamp(parent, pos: Vector3, drop: number?)
	local m = model(parent, "CeilingLamp")
	local d = drop or 3
	P(m, "Rod", Vector3.new(0.15, d, 0.15), CFrame.new(pos + Vector3.new(0, d / 2, 0)), Props.IRON, M.Metal, nc())
	C(m, "Canopy", 0.3, 1, CFrame.new(pos + Vector3.new(0, d - 0.15, 0)), Props.GOLD, M.Metal, nc())
	for k = 0, 2 do
		C(m, "Shade", 0.45, 1.6 + k * 0.7, CFrame.new(pos - Vector3.new(0, k * 0.4, 0)), rgb(70, 40, 30), M.Metal, nc())
	end
local bulb = S(m, "Bulb", 0.7, CFrame.new(pos - Vector3.new(0, 1, 0)), rgb(255, 220, 170), M.Neon, nc({ CanQuery = true }))
	mark(bulb, "lamp", 0, 16)
	light(bulb, 26, 1.4)
	return m
end

-- Люстра со свечами. size — радиус кольца
function Props.chandelier(parent, pos: Vector3, size: number?, drop: number?)
	local r = size or 3
	local d = drop or 4
	local m = model(parent, "Chandelier")
	P(m, "Chain", Vector3.new(0.2, d, 0.2), CFrame.new(pos + Vector3.new(0, d / 2, 0)), Props.IRON, M.Metal, nc())
	C(m, "Hub", 1.2, 1, CFrame.new(pos), Props.GOLD, M.Metal, nc())
	S(m, "Finial", 0.8, CFrame.new(pos - Vector3.new(0, 1, 0)), Props.GOLD, M.Metal, nc())
	for ring = 1, (if r > 4 then 2 else 1) do
		local rr = r * ring / (if r > 4 then 2 else 1)
		local y = -0.2 - (ring - 1) * 1.2
		local n = math.max(6, math.floor(rr * 2.5))
		P(m, "Ring", Vector3.new(0.25, rr * 2, rr * 2), CFrame.new(pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.pi / 2), Props.GOLD, M.Metal, nc({ Shape = CYL }))
		for k = 0, n - 1 do
			local a = k / n * math.pi * 2
			local cp = pos + Vector3.new(math.cos(a) * rr, y + 0.35, math.sin(a) * rr)
			C(m, "Cup", 0.2, 0.45, CFrame.new(cp), Props.GOLD, M.Metal, nc())
			C(m, "Candle", 0.6, 0.22, CFrame.new(cp + Vector3.new(0, 0.4, 0)), rgb(245, 238, 220), M.SmoothPlastic, nc())
			S(m, "Flame", 0.22, CFrame.new(cp + Vector3.new(0, 0.82, 0)), rgb(255, 190, 90), M.Neon, nc())
		end
	end
	local core = S(m, "Glow", 0.4, CFrame.new(pos), rgb(255, 210, 150), M.Neon, nc({ Transparency = 1 }))
	light(core, math.clamp(r * 9, 26, 60), 1.6)
	return m
end

-- Свеча на подсвечнике (без источника света)
function Props.candle(parent, pos: Vector3, h: number?)
	local m = model(parent, "Candle")
	local hh = h or 0.8
	C(m, "Dish", 0.12, 0.7, CFrame.new(pos + Vector3.new(0, 0.06, 0)), Props.GOLD, M.Metal, nc())
	C(m, "Wax", hh, 0.26, CFrame.new(pos + Vector3.new(0, 0.12 + hh / 2, 0)), rgb(245, 238, 220), M.SmoothPlastic, nc())
	S(m, "Flame", 0.24, CFrame.new(pos + Vector3.new(0, 0.3 + hh, 0)), rgb(255, 190, 90), M.Neon, nc())
	return m
end

-- Канделябр на три свечи
function Props.candelabra(parent, pos: Vector3)
	local m = model(parent, "Candelabra")
	C(m, "Foot", 0.2, 1, CFrame.new(pos + Vector3.new(0, 0.1, 0)), Props.GOLD, M.Metal, nc())
	C(m, "Stem", 1.6, 0.18, CFrame.new(pos + Vector3.new(0, 0.9, 0)), Props.GOLD, M.Metal, nc())
	P(m, "Arms", Vector3.new(1.8, 0.14, 0.14), CFrame.new(pos + Vector3.new(0, 1.6, 0)), Props.GOLD, M.Metal, nc())
	for _, x in { -0.9, 0, 0.9 } do
		C(m, "Wax", 0.7, 0.2, CFrame.new(pos + Vector3.new(x, 2.05, 0)), rgb(245, 238, 220), M.SmoothPlastic, nc())
		S(m, "Flame", 0.22, CFrame.new(pos + Vector3.new(x, 2.55, 0)), rgb(255, 190, 90), M.Neon, nc())
	end
	return m
end

-- ---------------------------------------------------------------------------
-- текстиль и стены

-- Ковёр: основа, кайма, поле и медальон в центре
function Props.rug(parent, cf: CFrame, w: number, d: number, color: Color3, accent: Color3?)
	local m = model(parent, "Rug")
	local a = accent or Props.GOLD
	P(m, "Base", Vector3.new(w, 0.1, d), cf * CFrame.new(0, 0.05, 0), color, M.Carpet, nc())
	P(m, "Border", Vector3.new(w - 1, 0.11, d - 1), cf * CFrame.new(0, 0.06, 0), a:Lerp(color, 0.35), M.Carpet, nc())
	P(m, "Field", Vector3.new(w - 1.8, 0.12, d - 1.8), cf * CFrame.new(0, 0.07, 0), color:Lerp(rgb(0, 0, 0), 0.15), M.Carpet, nc())
	local md = math.min(w, d) * 0.4
	C(m, "Medallion", 0.13, md, cf * CFrame.new(0, 0.075, 0), a:Lerp(color, 0.5), M.Carpet, nc())
	C(m, "Center", 0.14, md * 0.45, cf * CFrame.new(0, 0.08, 0), color, M.Carpet, nc())
	return m
end

-- Дорожка вдоль коридора с узором из ромбов
function Props.runner(parent, cf: CFrame, w: number, len: number, color: Color3)
	local m = model(parent, "Runner")
	P(m, "Base", Vector3.new(w, 0.1, len), cf * CFrame.new(0, 0.05, 0), color, M.Carpet, nc())
	for _, s in { -1, 1 } do
		P(m, "Stripe", Vector3.new(0.35, 0.11, len), cf * CFrame.new(s * (w / 2 - 0.5), 0.06, 0), Props.GOLD:Lerp(color, 0.3), M.Carpet, nc())
	end
	local n = math.floor(len / 5)
	for k = 0, n - 1 do
		local z = -len / 2 + 2.5 + k * 5
		P(m, "Diamond", Vector3.new(1.2, 0.11, 1.2), cf * CFrame.new(0, 0.06, z) * CFrame.Angles(0, math.pi / 4, 0), Props.GOLD:Lerp(color, 0.45), M.Carpet, nc())
	end
	return m
end

-- Картина в золочёной раме. cf — центр на стене, LookVector в комнату
function Props.painting(parent, cf: CFrame, w: number, h: number, seed: number)
	local m = model(parent, "Painting")
	local f = 0.35
	local base = cf * CFrame.new(0, 0, -0.12)
	P(m, "Back", Vector3.new(w, h, 0.12), base, Props.WOOD_DARK, M.Wood, nc())
	P(m, "FrameT", Vector3.new(w + f * 2, f, 0.3), base * CFrame.new(0, h / 2 + f / 2, -0.05), Props.GOLD, M.Metal, nc())
	P(m, "FrameB", Vector3.new(w + f * 2, f, 0.3), base * CFrame.new(0, -h / 2 - f / 2, -0.05), Props.GOLD, M.Metal, nc())
	P(m, "FrameL", Vector3.new(f, h, 0.3), base * CFrame.new(-w / 2 - f / 2, 0, -0.05), Props.GOLD, M.Metal, nc())
	P(m, "FrameR", Vector3.new(f, h, 0.3), base * CFrame.new(w / 2 + f / 2, 0, -0.05), Props.GOLD, M.Metal, nc())
	local c = base * CFrame.new(0, 0, -0.08)
	local kind = seed % 3
	if kind == 0 then
		-- пейзаж: небо, холмы, солнце
		local sky = Color3.fromHSV(0.55 + (seed % 5) * 0.02, 0.35, 0.75)
		P(m, "Sky", Vector3.new(w, h * 0.55, 0.04), c * CFrame.new(0, h * 0.225, 0), sky, M.SmoothPlastic, nc())
		P(m, "Land", Vector3.new(w, h * 0.45, 0.04), c * CFrame.new(0, -h * 0.275, 0), rgb(70, 96, 52), M.SmoothPlastic, nc())
		P(m, "Hill", Vector3.new(w * 0.6, h * 0.3, 0.05), c * CFrame.new(-w * 0.15, -h * 0.05, -0.01) * CFrame.Angles(0, 0, math.rad(12)), rgb(58, 82, 44), M.SmoothPlastic, nc())
		P(m, "Castle", Vector3.new(w * 0.12, h * 0.22, 0.05), c * CFrame.new(w * 0.22, h * 0.05, -0.02), rgb(120, 116, 110), M.SmoothPlastic, nc())
		C(m, "Sun", 0.04, math.min(w, h) * 0.18, c * CFrame.new(w * 0.3, h * 0.3, -0.02) * CFrame.Angles(math.pi / 2, 0, 0), rgb(255, 220, 140), M.SmoothPlastic, nc())
	elseif kind == 1 then
		-- портрет на тёмном фоне
		P(m, "Bg", Vector3.new(w, h, 0.04), c, rgb(34, 30, 28), M.SmoothPlastic, nc())
		P(m, "Body", Vector3.new(w * 0.6, h * 0.35, 0.05), c * CFrame.new(0, -h * 0.32, -0.01), Color3.fromHSV((seed % 7) / 7, 0.5, 0.45), M.SmoothPlastic, nc())
		C(m, "Face", 0.04, math.min(w * 0.36, h * 0.3), c * CFrame.new(0, h * 0.08, -0.02) * CFrame.Angles(math.pi / 2, 0, 0), rgb(214, 176, 140), M.SmoothPlastic, nc())
		P(m, "Hair", Vector3.new(w * 0.4, h * 0.1, 0.05), c * CFrame.new(0, h * 0.24, -0.03), rgb(60, 40, 30), M.SmoothPlastic, nc())
	else
		-- натюрморт
		P(m, "Bg", Vector3.new(w, h, 0.04), c, rgb(60, 44, 34), M.SmoothPlastic, nc())
		P(m, "Table", Vector3.new(w, h * 0.25, 0.05), c * CFrame.new(0, -h * 0.375, -0.01), rgb(90, 60, 40), M.SmoothPlastic, nc())
		C(m, "Fruit", 0.04, math.min(w, h) * 0.18, c * CFrame.new(-w * 0.15, -h * 0.15, -0.02) * CFrame.Angles(math.pi / 2, 0, 0), rgb(180, 50, 40), M.SmoothPlastic, nc())
		C(m, "Fruit", 0.04, math.min(w, h) * 0.15, c * CFrame.new(w * 0.05, -h * 0.17, -0.02) * CFrame.Angles(math.pi / 2, 0, 0), rgb(200, 160, 50), M.SmoothPlastic, nc())
		P(m, "Vase", Vector3.new(w * 0.14, h * 0.4, 0.05), c * CFrame.new(w * 0.25, -h * 0.05, -0.02), rgb(60, 90, 130), M.SmoothPlastic, nc())
	end
	return m
end

-- Флаг-гобелен с гербом. cf — точка крепления на стене, LookVector в комнату
function Props.banner(parent, cf: CFrame, h: number, color: Color3?)
	local m = model(parent, "Banner")
	local col = color or rgb(120, 22, 30)
	P(m, "Rod", Vector3.new(5.2, 0.3, 0.3), cf * CFrame.new(0, 0, -0.4), Props.GOLD, M.Metal, nc())
	P(m, "Cloth", Vector3.new(4.4, h, 0.12), cf * CFrame.new(0, -h / 2, -0.35), col, M.SmoothPlastic, nc())
	P(m, "Tip", Vector3.new(3.1, 3.1, 0.12), cf * CFrame.new(0, -h, -0.35) * CFrame.Angles(0, 0, math.pi / 4), col, M.SmoothPlastic, nc())
	P(m, "Trim", Vector3.new(4.4, 0.35, 0.14), cf * CFrame.new(0, -0.4, -0.37), Props.GOLD, M.Metal, nc())
	C(m, "Crest", 0.14, 2.2, cf * CFrame.new(0, -h * 0.4, -0.45) * CFrame.Angles(math.pi / 2, 0, 0), Props.GOLD, M.Metal, nc())
	P(m, "Crown", Vector3.new(1.2, 0.6, 0.14), cf * CFrame.new(0, -h * 0.4, -0.5), col, M.SmoothPlastic, nc())
	return m
end

-- ---------------------------------------------------------------------------
-- мебель

function Props.bookshelf(parent, cf: CFrame, w: number, h: number, seed: number, coarse: boolean?)
	local m = model(parent, "Bookshelf")
	local d = 2
	local wood = Props.WOOD_DARK
	local back = P(m, "Back", Vector3.new(w, h, 0.2), cf * CFrame.new(0, h / 2, d / 2 - 0.1), wood, M.Wood)
	if not coarse then
		mark(back, "book")
	end
	for _, s in { -1, 1 } do
		P(m, "Side", Vector3.new(0.35, h, d), cf * CFrame.new(s * (w / 2 - 0.175), h / 2, 0), wood, M.Wood)
	end
	P(m, "Crown", Vector3.new(w + 0.6, 0.5, d + 0.4), cf * CFrame.new(0, h + 0.25, 0), wood, M.Wood)
	P(m, "Plinth", Vector3.new(w, 0.6, d + 0.1), cf * CFrame.new(0, 0.3, 0), wood, M.Wood)
	local rows = math.floor((h - 0.6) / 2.4)
	local rnd = Random.new(seed)
	for r = 0, rows - 1 do
		local y = 0.6 + r * 2.4
		P(m, "Board", Vector3.new(w - 0.7, 0.18, d - 0.2), cf * CFrame.new(0, y, 0), Props.WOOD, M.Wood)
		local x = -w / 2 + 0.45
		while x < w / 2 - 0.9 do
			local bw = if coarse then rnd:NextNumber(1, 1.9) else rnd:NextNumber(0.25, 0.55)
			local bh = rnd:NextNumber(1.3, 2)
			if rnd:NextNumber() < 0.08 then
				x += 0.8 -- пустое место на полке
			else
				local hue = ({ 0, 0.05, 0.33, 0.6, 0.75, 0.1 })[rnd:NextInteger(1, 6)]
				local tilt = if rnd:NextNumber() < 0.06 then math.rad(14) else 0
				P(m, "Book", Vector3.new(bw, bh, d * 0.7), cf * CFrame.new(x + bw / 2, y + 0.09 + bh / 2, 0.05) * CFrame.Angles(0, 0, tilt), Color3.fromHSV(hue, rnd:NextNumber(0.35, 0.7), rnd:NextNumber(0.25, 0.55)), M.Leather, nc())
				x += bw + 0.03
			end
		end
	end
	P(m, "Board", Vector3.new(w - 0.7, 0.18, d - 0.2), cf * CFrame.new(0, 0.6 + rows * 2.4, 0), Props.WOOD, M.Wood)
	return m
end

-- Комод с тремя ящиками и вещами сверху
function Props.dresser(parent, cf: CFrame, w: number, seed: number)
	local m = model(parent, "Dresser")
	local d, h = 1.8, 3.2
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			C(m, "Foot", 0.5, 0.35, cf * CFrame.new(sx * (w / 2 - 0.3), 0.25, sz * (d / 2 - 0.3)), Props.WOOD_DARK, M.Wood)
		end
	end
mark(P(m, "Body", Vector3.new(w, h - 0.5, d), cf * CFrame.new(0, 0.5 + (h - 0.5) / 2, 0), Props.WOOD, M.Wood), "drawer", 0.8)
	P(m, "Top", Vector3.new(w + 0.3, 0.2, d + 0.2), cf * CFrame.new(0, h + 0.1, 0), Props.WOOD_DARK, M.Wood)
	for k = 0, 2 do
		local y = 0.95 + k * 0.85
		P(m, "Drawer", Vector3.new(w - 0.4, 0.7, 0.1), cf * CFrame.new(0, y, -d / 2 - 0.05), Props.WOOD_LIGHT, M.Wood, nc())
		for _, x in { -w / 4, w / 4 } do
			S(m, "Pull", 0.2, cf * CFrame.new(x, y, -d / 2 - 0.15), Props.GOLD, M.Metal, nc())
		end
	end
	local top = cf * CFrame.new(0, h + 0.2, 0)
	if seed % 3 == 0 then
		Props.candle(m, (top * CFrame.new(-w / 4, 0, 0)).Position)
		C(m, "Vase", 1.2, 0.7, top * CFrame.new(w / 4, 0.6, 0), Color3.fromHSV((seed % 5) / 5, 0.4, 0.6), M.Glass)
	elseif seed % 3 == 1 then
		for k = 0, 2 do
			P(m, "Book", Vector3.new(1.3, 0.25, 1), top * CFrame.new(-w / 5, 0.125 + k * 0.26, 0) * CFrame.Angles(0, k * 0.2, 0), Color3.fromHSV(k * 0.3, 0.5, 0.4), M.Leather, nc())
		end
		S(m, "Globe", 0.8, top * CFrame.new(w / 4, 0.4, 0), rgb(70, 110, 150), M.SmoothPlastic, nc())
	else
		P(m, "Mirror", Vector3.new(w * 0.6, 2.4, 0.15), top * CFrame.new(0, 1.3, d / 2 - 0.2), rgb(190, 205, 215), M.Glass, nc({ Reflectance = 0.4 }))
		P(m, "MirrorFrame", Vector3.new(w * 0.6 + 0.3, 2.7, 0.1), top * CFrame.new(0, 1.3, d / 2 - 0.1), Props.GOLD, M.Metal, nc())
	end
	return m
end

-- Шкаф с двумя дверцами, как в DOORS
function Props.wardrobe(parent, cf: CFrame, color: Color3?)
	local m = model(parent, "Wardrobe")
	local w, h, d = 4.6, 8.6, 2.4
	local wood = color or Props.WOOD
mark(P(m, "Body", Vector3.new(w, h, d), cf * CFrame.new(0, 0.4 + h / 2, 0), wood, M.Wood), "hide", 0.4, 7)
	P(m, "Crown", Vector3.new(w + 0.5, 0.5, d + 0.4), cf * CFrame.new(0, h + 0.65, 0), Props.WOOD_DARK, M.Wood)
	P(m, "Base", Vector3.new(w + 0.3, 0.4, d + 0.2), cf * CFrame.new(0, 0.2, 0), Props.WOOD_DARK, M.Wood)
	for _, s in { -1, 1 } do
		local x = s * w / 4
		P(m, "Door", Vector3.new(w / 2 - 0.2, h - 0.4, 0.1), cf * CFrame.new(x, 0.4 + h / 2, -d / 2 - 0.05), wood:Lerp(Props.WOOD_DARK, 0.2), M.Wood, nc())
		P(m, "PanelHi", Vector3.new(w / 2 - 0.8, h * 0.45, 0.08), cf * CFrame.new(x, 0.4 + h * 0.68, -d / 2 - 0.12), wood:Lerp(Props.WOOD_DARK, 0.4), M.Wood, nc())
		P(m, "PanelLo", Vector3.new(w / 2 - 0.8, h * 0.3, 0.08), cf * CFrame.new(x, 0.4 + h * 0.22, -d / 2 - 0.12), wood:Lerp(Props.WOOD_DARK, 0.4), M.Wood, nc())
		P(m, "Handle", Vector3.new(0.12, 0.8, 0.12), cf * CFrame.new(-s * 0.3, 0.4 + h * 0.5, -d / 2 - 0.2), Props.GOLD, M.Metal, nc())
	end
	return m
end

function Props.nightstand(parent, cf: CFrame)
	local m = model(parent, "Nightstand")
mark(P(m, "Body", Vector3.new(1.8, 2.2, 1.6), cf * CFrame.new(0, 1.3, 0), Props.WOOD, M.Wood), "drawer", 0.8)
	P(m, "Top", Vector3.new(2, 0.15, 1.8), cf * CFrame.new(0, 2.45, 0), Props.WOOD_DARK, M.Wood)
	P(m, "Drawer", Vector3.new(1.5, 0.6, 0.08), cf * CFrame.new(0, 1.9, -0.84), Props.WOOD_LIGHT, M.Wood, nc())
	S(m, "Pull", 0.18, cf * CFrame.new(0, 1.9, -0.92), Props.GOLD, M.Metal, nc())
	for _, sx in { -0.75, 0.75 } do
		for _, sz in { -0.65, 0.65 } do
			P(m, "Leg", Vector3.new(0.2, 0.2, 0.2), cf * CFrame.new(sx, 0.1, sz), Props.WOOD_DARK, M.Wood)
		end
	end
	-- лампа с абажуром
	C(m, "LampBase", 0.2, 0.7, cf * CFrame.new(0, 2.63, 0.1), Props.GOLD, M.Metal, nc())
	C(m, "LampStem", 1, 0.15, cf * CFrame.new(0, 3.2, 0.1), Props.GOLD, M.Metal, nc())
	local shade = C(m, "LampShade", 0.8, 1, cf * CFrame.new(0, 3.9, 0.1), rgb(240, 214, 170), M.Neon, nc({ Transparency = 0.35 }))
	light(shade, 9, 0.6)
	return m
end

-- Кровать: рама, резное изголовье, матрас, одеяло с отворотом, подушки; royal — с балдахином
function Props.bed(parent, cf: CFrame, blanket: Color3, royal: boolean?)
	local m = model(parent, "Bed")
	local w, len = if royal then 7 else 5, if royal then 9.5 else 8.5
	local wood = if royal then Props.WOOD_DARK else Props.WOOD
	-- изголовье у стены (локально +Z), изножье в комнату
	P(m, "Frame", Vector3.new(w, 1.2, len), cf * CFrame.new(0, 1.1, 0), wood, M.Wood)
	for _, s in { -1, 1 } do
		for _, e in { -1, 1 } do
			local postH = if royal then 10 else (if e > 0 then 4.6 else 2.6)
			C(m, "Post", postH, 0.45, cf * CFrame.new(s * (w / 2 - 0.2), postH / 2, e * (len / 2 - 0.2)), wood, M.Wood)
			S(m, "Knob", 0.6, cf * CFrame.new(s * (w / 2 - 0.2), postH + 0.2, e * (len / 2 - 0.2)), if royal then Props.GOLD else wood, if royal then M.Metal else M.Wood)
		end
	end
	P(m, "Headboard", Vector3.new(w - 0.4, 3.2, 0.3), cf * CFrame.new(0, 2.6, len / 2 - 0.2), wood, M.Wood)
	for k = -1, 1 do
		P(m, "HeadPanel", Vector3.new((w - 1.2) / 3 - 0.2, 2, 0.1), cf * CFrame.new(k * (w - 1.2) / 3, 2.7, len / 2 - 0.4), wood:Lerp(rgb(0, 0, 0), 0.2), M.Wood, nc())
	end
	P(m, "Footboard", Vector3.new(w - 0.4, 1.4, 0.25), cf * CFrame.new(0, 1.7, -len / 2 + 0.2), wood, M.Wood)
	P(m, "Mattress", Vector3.new(w - 0.6, 0.8, len - 0.7), cf * CFrame.new(0, 2.1, 0), Props.CLOTH, M.SmoothPlastic)
	local b = P(m, "Blanket", Vector3.new(w - 0.4, 0.3, len * 0.62), cf * CFrame.new(0, 2.6, -len * 0.16), blanket, M.Fabric)
	P(m, "Fold", Vector3.new(w - 0.4, 0.34, 0.9), cf * CFrame.new(0, 2.65, len * 0.13), Props.CLOTH, M.SmoothPlastic, nc())
	for _, x in (if royal then { -1.6, 1.6 } else { -1.1, 1.1 }) do
		P(m, "Pillow", Vector3.new(if royal then 2.6 else 1.8, 0.6, 1.3), cf * CFrame.new(x, 2.8, len / 2 - 1.3) * CFrame.Angles(math.rad(-12), 0, 0), rgb(248, 246, 240), M.SmoothPlastic, nc())
	end
	if royal then
		P(m, "Canopy", Vector3.new(w + 0.3, 0.5, len + 0.3), cf * CFrame.new(0, 10.1, 0), blanket:Lerp(rgb(0, 0, 0), 0.2), M.SmoothPlastic)
		for _, s in { -1, 1 } do
			for _, e in { -1, 1 } do
				P(m, "Curtain", Vector3.new(0.6, 7, 1.2), cf * CFrame.new(s * (w / 2 - 0.1), 6.3, e * (len / 2 - 0.9)), blanket, M.SmoothPlastic, nc())
			end
		end
		P(m, "Valance", Vector3.new(w + 0.4, 1, 0.2), cf * CFrame.new(0, 9.5, -len / 2 - 0.1), Props.GOLD, M.SmoothPlastic, nc())
	end
	return m, b
end

-- Стол с резными ножками; cloth — скатерть
function Props.table(parent, cf: CFrame, w: number, d: number, cloth: Color3?)
	local m = model(parent, "Table")
	local h = 3.2
	P(m, "Top", Vector3.new(w, 0.3, d), cf * CFrame.new(0, h, 0), Props.WOOD, M.Wood)
	P(m, "Apron", Vector3.new(w - 0.6, 0.5, d - 0.6), cf * CFrame.new(0, h - 0.4, 0), Props.WOOD_DARK, M.Wood)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local lp = cf * CFrame.new(sx * (w / 2 - 0.45), 0, sz * (d / 2 - 0.45))
			C(m, "Leg", h - 0.6, 0.4, lp * CFrame.new(0, (h - 0.6) / 2, 0), Props.WOOD_DARK, M.Wood)
			S(m, "Turn", 0.6, lp * CFrame.new(0, h * 0.55, 0), Props.WOOD_DARK, M.Wood, nc())
			C(m, "Foot", 0.3, 0.6, lp * CFrame.new(0, 0.15, 0), Props.WOOD_DARK, M.Wood)
		end
	end
	if cloth then
		P(m, "Cloth", Vector3.new(w + 0.4, 0.06, d + 0.4), cf * CFrame.new(0, h + 0.18, 0), cloth, M.SmoothPlastic, nc())
		for _, s in { -1, 1 } do
			P(m, "Drop", Vector3.new(w + 0.4, 1, 0.06), cf * CFrame.new(0, h - 0.3, s * (d / 2 + 0.2)), cloth, M.SmoothPlastic, nc())
		end
	end
	return m, h + 0.15
end

-- Стул: ножки, сиденье с подушкой, спинка из реек
function Props.chair(parent, cf: CFrame, color: Color3?)
	local m = model(parent, "Chair")
	for _, sx in { -0.75, 0.75 } do
		for _, sz in { -0.75, 0.75 } do
			P(m, "Leg", Vector3.new(0.25, 1.9, 0.25), cf * CFrame.new(sx, 0.95, sz), Props.WOOD_DARK, M.Wood)
		end
	end
	P(m, "SeatBoard", Vector3.new(1.9, 0.25, 1.9), cf * CFrame.new(0, 1.95, 0), Props.WOOD, M.Wood)
	seat(m, "Cushion", Vector3.new(1.6, 0.22, 1.6), cf * CFrame.new(0, 2.17, 0), color or rgb(120, 30, 36), M.Leather)
	for _, sx in { -0.75, 0.75 } do
		P(m, "BackPost", Vector3.new(0.25, 2.4, 0.25), cf * CFrame.new(sx, 3.25, 0.8), Props.WOOD_DARK, M.Wood)
	end
	P(m, "TopRail", Vector3.new(1.9, 0.35, 0.28), cf * CFrame.new(0, 4.4, 0.8), Props.WOOD_DARK, M.Wood)
	for _, x in { -0.35, 0, 0.35 } do
		P(m, "Slat", Vector3.new(0.16, 2, 0.12), cf * CFrame.new(x, 3.2, 0.8), Props.WOOD, M.Wood, nc())
	end
	return m
end

-- Кресло с подлокотниками
function Props.armchair(parent, cf: CFrame, color: Color3)
	local m = model(parent, "Armchair")
	P(m, "Base", Vector3.new(3, 1.2, 2.8), cf * CFrame.new(0, 0.9, 0), color, M.Leather)
	seat(m, "Cushion", Vector3.new(2.2, 0.5, 2.2), cf * CFrame.new(0, 1.75, -0.2), color:Lerp(rgb(255, 255, 255), 0.08), M.Leather)
	P(m, "Back", Vector3.new(3, 3, 0.6), cf * CFrame.new(0, 2.6, 1.1), color, M.Leather)
	for _, s in { -1, 1 } do
		P(m, "Arm", Vector3.new(0.5, 1, 2.8), cf * CFrame.new(s * 1.35, 2, 0), color:Lerp(rgb(0, 0, 0), 0.1), M.Leather)
		S(m, "ArmRoll", 0.6, cf * CFrame.new(s * 1.35, 2.5, -1.3), color, M.Leather, nc())
	end
	for _, sx in { -1.3, 1.3 } do
		for _, sz in { -1.2, 1.2 } do
			C(m, "Foot", 0.3, 0.3, cf * CFrame.new(sx, 0.15, sz), Props.WOOD_DARK, M.Wood)
		end
	end
	return m
end

-- Диван на троих
function Props.sofa(parent, cf: CFrame, color: Color3)
	local m = model(parent, "Sofa")
	local w = 7
	P(m, "Base", Vector3.new(w, 1.2, 2.8), cf * CFrame.new(0, 0.9, 0), color, M.Leather)
	for k = -1, 1 do
		seat(m, "Cushion", Vector3.new(w / 3 - 0.3, 0.5, 2.1), cf * CFrame.new(k * w / 3, 1.75, -0.25), color:Lerp(rgb(255, 255, 255), 0.06), M.Leather)
		P(m, "BackCushion", Vector3.new(w / 3 - 0.3, 2, 0.5), cf * CFrame.new(k * w / 3, 2.7, 0.75), color:Lerp(rgb(255, 255, 255), 0.04), M.Leather, nc())
	end
	P(m, "Back", Vector3.new(w, 3.2, 0.5), cf * CFrame.new(0, 2.4, 1.15), color:Lerp(rgb(0, 0, 0), 0.1), M.Leather)
	for _, s in { -1, 1 } do
		P(m, "Arm", Vector3.new(0.6, 1.4, 2.8), cf * CFrame.new(s * (w / 2 + 0.3), 1.6, 0), color:Lerp(rgb(0, 0, 0), 0.1), M.Leather)
	end
	for _, sx in { -w / 2, w / 2 } do
		for _, sz in { -1.2, 1.2 } do
			C(m, "Foot", 0.3, 0.3, cf * CFrame.new(sx, 0.15, sz), Props.WOOD_DARK, M.Wood)
		end
	end
	return m
end

-- Низкий столик перед диваном
function Props.coffeeTable(parent, cf: CFrame)
	local m = model(parent, "CoffeeTable")
	P(m, "Top", Vector3.new(4, 0.25, 2.2), cf * CFrame.new(0, 1.6, 0), Props.WOOD, M.Wood)
	for _, sx in { -1.7, 1.7 } do
		for _, sz in { -0.85, 0.85 } do
			P(m, "Leg", Vector3.new(0.3, 1.5, 0.3), cf * CFrame.new(sx, 0.75, sz), Props.WOOD_DARK, M.Wood)
		end
	end
	P(m, "Tray", Vector3.new(1.6, 0.1, 1), cf * CFrame.new(-0.6, 1.78, 0), Props.GOLD, M.Metal, nc())
	C(m, "Teapot", 0.7, 0.6, cf * CFrame.new(-0.8, 2.15, 0), rgb(235, 235, 240), M.SmoothPlastic, nc())
	C(m, "Cup", 0.3, 0.35, cf * CFrame.new(-0.2, 1.98, 0.2), rgb(235, 235, 240), M.SmoothPlastic, nc())
	P(m, "Book", Vector3.new(1, 0.2, 1.3), cf * CFrame.new(1.1, 1.82, 0) * CFrame.Angles(0, 0.3, 0), rgb(90, 30, 30), M.Leather, nc())
	return m
end

-- Камин: каменный портал, полка, топка с поленьями и огнём, дымоход до потолка
function Props.fireplace(parent, cf: CFrame, ceiling: number)
	local m = model(parent, "Fireplace")
	local stone = rgb(160, 152, 140)
	P(m, "Breast", Vector3.new(6, ceiling, 2), cf * CFrame.new(0, ceiling / 2, 0.6), stone:Lerp(rgb(0, 0, 0), 0.08), M.Slate)
mark(P(m, "Hearth", Vector3.new(8, 0.4, 2.5), cf * CFrame.new(0, 0.2, -0.9), rgb(110, 104, 98), M.Slate), "warm", 0, 10)
	for _, s in { -1, 1 } do
		P(m, "Pier", Vector3.new(1.2, 4.6, 1.2), cf * CFrame.new(s * 3, 2.3, -0.9), stone, M.Marble)
		P(m, "Corbel", Vector3.new(1.4, 0.6, 1.5), cf * CFrame.new(s * 3, 4.9, -1), stone, M.Marble)
	end
	P(m, "Mantel", Vector3.new(8, 0.5, 1.9), cf * CFrame.new(0, 5.4, -1), stone, M.Marble)
	P(m, "Lintel", Vector3.new(4.8, 0.9, 1.2), cf * CFrame.new(0, 4.25, -0.9), stone, M.Marble)
	local box = P(m, "Firebox", Vector3.new(4.8, 3.8, 0.3), cf * CFrame.new(0, 2.3, -0.25), rgb(26, 20, 18), M.Slate)
	P(m, "Grate", Vector3.new(3.4, 0.2, 1), cf * CFrame.new(0, 0.7, -0.9), Props.IRON, M.Metal, nc())
	for k = -1, 1 do
		C(m, "Log", 2.8, 0.45, cf * CFrame.new(k * 0.6, 1, -0.9) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(math.pi / 2, 0, 0), rgb(80, 52, 34), M.Wood, nc())
	end
	local ember = P(m, "Embers", Vector3.new(2.6, 0.3, 0.8), cf * CFrame.new(0, 0.95, -0.9), rgb(255, 110, 40), M.Neon, nc())
	local fire = Instance.new("Fire")
	fire.Size = 3.5
	fire.Heat = 4
	fire.Color = rgb(255, 140, 50)
	fire.SecondaryColor = rgb(255, 60, 20)
	fire.Parent = ember
	light(ember, 22, 1.6, rgb(255, 150, 70))
	-- на полке подсвечники и часы
	Props.candelabra(m, (cf * CFrame.new(-3, 5.65, -1)).Position)
	Props.candelabra(m, (cf * CFrame.new(3, 5.65, -1)).Position)
	P(m, "Clock", Vector3.new(1.4, 1.4, 0.6), cf * CFrame.new(0, 6.35, -1), Props.GOLD, M.Metal, nc())
	C(m, "Dial", 0.1, 1, cf * CFrame.new(0, 6.4, -1.32) * CFrame.Angles(math.pi / 2, 0, 0), rgb(245, 240, 225), M.SmoothPlastic, nc())
	local _ = box
	return m
end

-- Рыцарские доспехи на постаменте
function Props.armor(parent, cf: CFrame)
	local m = model(parent, "Armor")
	local steel = rgb(176, 178, 186)
	P(m, "Pedestal", Vector3.new(2.6, 0.6, 2.6), cf * CFrame.new(0, 0.3, 0), Props.STONE_DARK, M.Marble)
	for _, s in { -1, 1 } do
		P(m, "Leg", Vector3.new(0.7, 2.8, 0.7), cf * CFrame.new(s * 0.45, 2, 0), steel, M.Metal)
		P(m, "Knee", Vector3.new(0.85, 0.5, 0.85), cf * CFrame.new(s * 0.45, 2, -0.05), steel:Lerp(rgb(0, 0, 0), 0.1), M.Metal)
		P(m, "Boot", Vector3.new(0.8, 0.5, 1.1), cf * CFrame.new(s * 0.45, 0.85, -0.15), steel, M.Metal)
		P(m, "Arm", Vector3.new(0.6, 2.4, 0.6), cf * CFrame.new(s * 1.35, 4.3, 0), steel, M.Metal)
		S(m, "Pauldron", 1.1, cf * CFrame.new(s * 1.3, 5.5, 0), steel, M.Metal)
		P(m, "Gauntlet", Vector3.new(0.65, 0.6, 0.65), cf * CFrame.new(s * 1.35, 2.9, -0.05), steel:Lerp(rgb(0, 0, 0), 0.15), M.Metal)
	end
	P(m, "Torso", Vector3.new(2, 2.6, 1.2), cf * CFrame.new(0, 4.6, 0), steel, M.Metal)
	P(m, "Breast", Vector3.new(1.7, 1.6, 0.25), cf * CFrame.new(0, 4.9, -0.65), steel:Lerp(rgb(255, 255, 255), 0.1), M.Metal)
	P(m, "Belt", Vector3.new(2.1, 0.35, 1.3), cf * CFrame.new(0, 3.4, 0), rgb(70, 50, 34), M.Leather)
	P(m, "Helmet", Vector3.new(1.2, 1.4, 1.3), cf * CFrame.new(0, 6.6, 0), steel, M.Metal)
	P(m, "Visor", Vector3.new(1.05, 0.2, 0.1), cf * CFrame.new(0, 6.65, -0.68), rgb(20, 20, 22), M.Metal, nc())
	P(m, "Plume", Vector3.new(0.2, 1, 1.4), cf * CFrame.new(0, 7.6, 0.2), rgb(150, 20, 30), M.SmoothPlastic, nc())
	P(m, "Sword", Vector3.new(0.2, 4.4, 0.4), cf * CFrame.new(1.6, 2.4, -0.6), rgb(200, 202, 210), M.Metal, nc())
	P(m, "Guard", Vector3.new(1, 0.2, 0.3), cf * CFrame.new(1.6, 4.5, -0.6), Props.GOLD, M.Metal, nc())
	P(m, "Shield", Vector3.new(1.8, 2.4, 0.2), cf * CFrame.new(-1.75, 3.6, -0.5), rgb(120, 22, 30), M.Metal, nc())
	C(m, "Boss", 0.1, 0.8, cf * CFrame.new(-1.75, 3.7, -0.62) * CFrame.Angles(math.pi / 2, 0, 0), Props.GOLD, M.Metal, nc())
	return m
end

-- Растение в кадке
function Props.plant(parent, cf: CFrame, big: boolean?)
	local m = model(parent, "Plant")
	local s = if big then 1.5 else 1
	C(m, "Pot", 1.6 * s, 1.6 * s, cf * CFrame.new(0, 0.8 * s, 0), rgb(150, 82, 56), M.Slate)
	C(m, "Rim", 0.25 * s, 1.9 * s, cf * CFrame.new(0, 1.6 * s, 0), rgb(130, 70, 48), M.Slate)
	C(m, "Soil", 0.1, 1.5 * s, cf * CFrame.new(0, 1.62 * s, 0), rgb(60, 42, 30), M.Ground, nc())
	for k = 0, 6 do
		local a = k / 7 * math.pi * 2
		local len = (2 + (k % 3) * 0.6) * s
		P(m, "Leaf", Vector3.new(0.6 * s, len, 0.1), cf * CFrame.new(0, 1.7 * s, 0) * CFrame.Angles(0, a, math.rad(28 + (k % 2) * 12)) * CFrame.new(0, len / 2, 0), rgb(60, 110 + (k % 3) * 15, 50), M.Grass, nc())
	end
	S(m, "Bush", 1.6 * s, cf * CFrame.new(0, 2.4 * s, 0), rgb(56, 100, 46), M.Grass, nc())
	return m
end

-- Напольные часы с маятником
function Props.grandfatherClock(parent, cf: CFrame)
	local m = model(parent, "Clock")
	P(m, "Base", Vector3.new(2.2, 1.2, 1.6), cf * CFrame.new(0, 0.6, 0), Props.WOOD_DARK, M.Wood)
mark(P(m, "Case", Vector3.new(1.8, 5, 1.4), cf * CFrame.new(0, 3.7, 0), Props.WOOD, M.Wood), "clock")
	P(m, "Window", Vector3.new(1.1, 3.4, 0.1), cf * CFrame.new(0, 3.7, -0.72), rgb(40, 34, 30), M.Glass, nc({ Transparency = 0.3 }))
	P(m, "Pendulum", Vector3.new(0.08, 2.4, 0.05), cf * CFrame.new(0, 3.9, -0.6), Props.GOLD, M.Metal, nc())
	C(m, "Bob", 0.08, 0.6, cf * CFrame.new(0, 2.7, -0.6) * CFrame.Angles(math.pi / 2, 0, 0), Props.GOLD, M.Metal, nc())
	P(m, "Head", Vector3.new(2.2, 2.4, 1.6), cf * CFrame.new(0, 7.4, 0), Props.WOOD_DARK, M.Wood)
	C(m, "Face", 0.1, 1.7, cf * CFrame.new(0, 7.4, -0.82) * CFrame.Angles(math.pi / 2, 0, 0), rgb(240, 232, 210), M.SmoothPlastic, nc())
	P(m, "HandH", Vector3.new(0.08, 0.5, 0.05), cf * CFrame.new(0.1, 7.55, -0.9) * CFrame.Angles(0, 0, math.rad(-35)), rgb(20, 20, 20), M.Metal, nc())
	P(m, "HandM", Vector3.new(0.06, 0.7, 0.05), cf * CFrame.new(-0.05, 7.7, -0.9) * CFrame.Angles(0, 0, math.rad(10)), rgb(20, 20, 20), M.Metal, nc())
	P(m, "Pediment", Vector3.new(2.4, 0.5, 1.8), cf * CFrame.new(0, 8.85, 0), Props.WOOD_DARK, M.Wood)
	S(m, "Finial", 0.5, cf * CFrame.new(0, 9.3, 0), Props.GOLD, M.Metal, nc())
	return m
end

-- Пианино с клавиатурой и банкеткой
function Props.piano(parent, cf: CFrame)
	local m = model(parent, "Piano")
	local black = rgb(22, 20, 22)
mark(P(m, "Body", Vector3.new(6, 4.6, 2), cf * CFrame.new(0, 2.8, 0.4), black, M.SmoothPlastic, { Reflectance = 0.1 }), "piano", 0, 8)
	P(m, "Lid", Vector3.new(6.2, 0.2, 2.2), cf * CFrame.new(0, 5.2, 0.4), black, M.SmoothPlastic)
	P(m, "KeyBed", Vector3.new(5.6, 0.4, 1.2), cf * CFrame.new(0, 3, -1.1), black, M.SmoothPlastic)
	P(m, "WhiteKeys", Vector3.new(5.2, 0.12, 0.9), cf * CFrame.new(0, 3.26, -1.15), rgb(245, 242, 232), M.SmoothPlastic, nc())
	for k = 0, 17 do
		if k % 7 ~= 2 and k % 7 ~= 6 then
			P(m, "BlackKey", Vector3.new(0.14, 0.14, 0.5), cf * CFrame.new(-2.5 + k * 0.29, 3.36, -1.0), black, M.SmoothPlastic, nc())
		end
	end
	P(m, "MusicStand", Vector3.new(2.4, 1.2, 0.1), cf * CFrame.new(0, 4.2, -0.65) * CFrame.Angles(math.rad(-10), 0, 0), black, M.SmoothPlastic, nc())
	P(m, "Sheet", Vector3.new(1.8, 1, 0.05), cf * CFrame.new(0, 4.25, -0.72) * CFrame.Angles(math.rad(-10), 0, 0), rgb(245, 240, 225), M.SmoothPlastic, nc())
	for _, s in { -1, 1 } do
		P(m, "Leg", Vector3.new(0.5, 2.8, 0.5), cf * CFrame.new(s * 2.7, 1.4, -1.3), black, M.SmoothPlastic)
	end
	-- банкетка
	seat(m, "BenchSeat", Vector3.new(3, 0.5, 1.4), cf * CFrame.new(0, 1.8, -3.2), rgb(90, 24, 30), M.Leather)
	for _, sx in { -1.3, 1.3 } do
		P(m, "BenchLeg", Vector3.new(0.25, 1.6, 1.2), cf * CFrame.new(sx, 0.8, -3.2), black, M.SmoothPlastic)
	end
	return m
end

-- Письменный стол с бумагами, чернильницей, пером и стулом
function Props.desk(parent, cf: CFrame)
	local m = model(parent, "Desk")
	local w, d = 5, 2.6
	P(m, "Top", Vector3.new(w, 0.3, d), cf * CFrame.new(0, 3.2, 0), Props.WOOD, M.Wood)
	for _, s in { -1, 1 } do
		P(m, "Pedestal", Vector3.new(1.4, 3.05, d - 0.2), cf * CFrame.new(s * (w / 2 - 0.8), 1.53, 0), Props.WOOD_DARK, M.Wood)
		for k = 0, 2 do
			P(m, "Drawer", Vector3.new(1.2, 0.8, 0.08), cf * CFrame.new(s * (w / 2 - 0.8), 0.6 + k * 0.95, -d / 2 + 0.04), Props.WOOD_LIGHT, M.Wood, nc())
			S(m, "Pull", 0.16, cf * CFrame.new(s * (w / 2 - 0.8), 0.6 + k * 0.95, -d / 2 - 0.05), Props.GOLD, M.Metal, nc())
		end
	end
	P(m, "Blotter", Vector3.new(2.4, 0.04, 1.4), cf * CFrame.new(0, 3.37, 0), rgb(40, 70, 50), M.Leather, nc())
	for k = 0, 2 do
		P(m, "Paper", Vector3.new(0.85, 0.02, 1.1), cf * CFrame.new(-0.4 + k * 0.25, 3.4 + k * 0.01, 0) * CFrame.Angles(0, k * 0.25 - 0.2, 0), rgb(240, 232, 210), M.SmoothPlastic, nc())
	end
	C(m, "Inkwell", 0.4, 0.4, cf * CFrame.new(1.4, 3.55, 0.6), rgb(20, 20, 30), M.Glass, nc())
	P(m, "Quill", Vector3.new(0.06, 1.2, 0.2), cf * CFrame.new(1.45, 3.95, 0.6) * CFrame.Angles(math.rad(20), 0, math.rad(15)), rgb(245, 245, 245), M.SmoothPlastic, nc())
	Props.candle(m, (cf * CFrame.new(-1.9, 3.35, 0.7)).Position)
	for k = 0, 3 do
		P(m, "Book", Vector3.new(0.3, 1.2, 0.9), cf * CFrame.new(-2 + k * 0.32, 3.95, 0.8), Color3.fromHSV(k * 0.21, 0.5, 0.4), M.Leather, nc())
	end
	Props.chair(m, cf * CFrame.new(0, 0, -2.2) * CFrame.Angles(0, math.pi, 0))
	return m
end

-- Глобус на подставке
function Props.globe(parent, cf: CFrame)
	local m = model(parent, "Globe")
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		P(m, "Leg", Vector3.new(0.2, 2.6, 0.2), cf * CFrame.new(math.cos(a) * 0.6, 1.3, math.sin(a) * 0.6) * CFrame.Angles(math.cos(a) * 0.2, 0, -math.sin(a) * 0.2), Props.WOOD_DARK, M.Wood)
	end
	P(m, "Meridian", Vector3.new(0.12, 2.6, 2.6), cf * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, 0, math.rad(23)), Props.GOLD, M.Metal, { Shape = CYL, CanCollide = false })
mark(S(m, "Sphere", 2.2, cf * CFrame.new(0, 3.6, 0), rgb(70, 110, 150), M.SmoothPlastic), "spin")
	for k = 0, 3 do
		S(m, "Land", 0.9, cf * CFrame.new(0, 3.6, 0) * CFrame.Angles(k, k * 1.7, 0) * CFrame.new(0, 0, -0.75), rgb(120, 150, 80), M.SmoothPlastic, nc())
	end
	return m
end

-- Бочка (стоя или лёжа)
function Props.barrel(parent, cf: CFrame, lying: boolean?)
	local m = model(parent, "Barrel")
	local base = if lying then cf * CFrame.new(0, 1.4, 0) * CFrame.Angles(math.pi / 2, 0, 0) else cf * CFrame.new(0, 1.6, 0)
mark(C(m, "Staves", 3.2, 2.6, base, Props.WOOD_LIGHT, M.Wood), "barrel", 0.6)
	C(m, "Belly", 1.6, 2.8, base, Props.WOOD_LIGHT, M.Wood)
	for _, y in { -1.2, 1.2, 0.3, -0.3 } do
		C(m, "Hoop", 0.2, (if math.abs(y) > 1 then 2.7 else 2.9), base * CFrame.new(0, y, 0), Props.IRON, M.Metal, nc())
	end
	return m
end

function Props.crate(parent, cf: CFrame, s: number?)
	local m = model(parent, "Crate")
	local z = s or 2.6
	P(m, "Box", Vector3.new(z, z, z), cf * CFrame.new(0, z / 2, 0), Props.WOOD_LIGHT, M.WoodPlanks)
	for _, a in { 0, math.pi / 2 } do
		P(m, "Brace", Vector3.new(0.25, z * 1.3, z + 0.1), cf * CFrame.new(0, z / 2, 0) * CFrame.Angles(a, 0, math.pi / 4), Props.WOOD, M.Wood, nc())
	end
	return m
end

function Props.sack(parent, cf: CFrame)
	local m = model(parent, "Sack")
mark(S(m, "Bag", 2, cf * CFrame.new(0, 1, 0), rgb(176, 150, 106), M.Cardboard), "sack", 0.6)
	C(m, "Neck", 0.6, 0.8, cf * CFrame.new(0, 2.1, 0), rgb(160, 136, 96), M.Cardboard, nc())
	return m
end

-- Сундук с золотом
function Props.chest(parent, cf: CFrame, open: boolean?)
	local m = model(parent, "Chest")
mark(P(m, "Box", Vector3.new(3.4, 1.8, 2), cf * CFrame.new(0, 0.9, 0), Props.WOOD, M.Wood), "chest", 1)
	for _, x in { -1.3, 0, 1.3 } do
		P(m, "Band", Vector3.new(0.2, 1.85, 2.05), cf * CFrame.new(x, 0.9, 0), Props.IRON, M.Metal, nc())
	end
	if open then
		P(m, "Lid", Vector3.new(3.4, 0.25, 2), cf * CFrame.new(0, 2.6, 1.1) * CFrame.Angles(math.rad(70), 0, 0), Props.WOOD, M.Wood, nc())
		for k = 0, 6 do
			C(m, "Coin", 0.08, 0.5, cf * CFrame.new(-1.2 + k * 0.4, 1.85, (k % 2) * 0.3 - 0.1) * CFrame.Angles(k, 0, 0.2), Props.GOLD, M.Neon, nc())
		end
		P(m, "Gold", Vector3.new(3, 0.3, 1.6), cf * CFrame.new(0, 1.75, 0), Props.GOLD, M.Metal, nc())
	else
		P(m, "Lid", Vector3.new(3.5, 0.5, 2.1), cf * CFrame.new(0, 2.05, 0), Props.WOOD_DARK, M.Wood)
		P(m, "Lock", Vector3.new(0.5, 0.6, 0.15), cf * CFrame.new(0, 1.6, -1.05), Props.GOLD, M.Metal, nc())
	end
	return m
end

-- Стойка с оружием и щитами
function Props.weaponRack(parent, cf: CFrame)
	local m = model(parent, "WeaponRack")
	P(m, "Back", Vector3.new(6, 6, 0.4), cf * CFrame.new(0, 3.4, 0.6), Props.WOOD_DARK, M.Wood)
	P(m, "Base", Vector3.new(6.4, 0.6, 1.8), cf * CFrame.new(0, 0.3, 0), Props.WOOD_DARK, M.Wood)
	P(m, "Rail", Vector3.new(6, 0.3, 0.8), cf * CFrame.new(0, 4.6, 0.2), Props.WOOD, M.Wood)
	for k = 0, 4 do
		local x = -2.4 + k * 1.2
		P(m, "Blade", Vector3.new(0.18, 4.2, 0.4), cf * CFrame.new(x, 2.7, 0.15), rgb(196, 198, 206), M.Metal, nc())
		P(m, "Hilt", Vector3.new(0.7, 0.18, 0.25), cf * CFrame.new(x, 4.9, 0.15), Props.GOLD, M.Metal, nc())
		P(m, "Grip", Vector3.new(0.18, 0.8, 0.18), cf * CFrame.new(x, 5.4, 0.15), rgb(60, 40, 28), M.Leather, nc())
	end
	for _, x in { -2, 2 } do
		C(m, "Shield", 0.2, 2.2, cf * CFrame.new(x, 6.9, 0.35) * CFrame.Angles(math.pi / 2, 0, 0), rgb(120, 22, 30), M.Metal, nc())
		C(m, "Boss", 0.25, 0.7, cf * CFrame.new(x, 6.9, 0.25) * CFrame.Angles(math.pi / 2, 0, 0), Props.GOLD, M.Metal, nc())
	end
	return m
end

-- Скамья в часовне
function Props.pew(parent, cf: CFrame, w: number)
	local m = model(parent, "Pew")
	seat(m, "Seat", Vector3.new(w, 0.3, 1.6), cf * CFrame.new(0, 1.9, 0), Props.WOOD, M.Wood)
	P(m, "Back", Vector3.new(w, 2.4, 0.25), cf * CFrame.new(0, 3.1, 0.75), Props.WOOD, M.Wood)
	P(m, "Rail", Vector3.new(w, 0.25, 0.4), cf * CFrame.new(0, 4.35, 0.75), Props.WOOD_DARK, M.Wood)
	for _, s in { -1, 1 } do
		P(m, "End", Vector3.new(0.3, 4, 1.8), cf * CFrame.new(s * (w / 2 + 0.1), 2, 0.1), Props.WOOD_DARK, M.Wood)
	end
	P(m, "Kneeler", Vector3.new(w, 0.35, 0.6), cf * CFrame.new(0, 0.45, -1.1), rgb(110, 30, 36), M.Leather, nc())
	return m
end

-- Алтарь со свечами
function Props.altar(parent, cf: CFrame)
	local m = model(parent, "Altar")
	P(m, "Step", Vector3.new(9, 0.6, 5), cf * CFrame.new(0, 0.3, 0), Props.STONE, M.Marble)
mark(P(m, "Table", Vector3.new(6, 3.4, 2.4), cf * CFrame.new(0, 2.3, 0.5), rgb(220, 214, 204), M.Marble), "pray", 1.5)
	P(m, "Cloth", Vector3.new(6.3, 0.1, 2.7), cf * CFrame.new(0, 4.05, 0.5), Props.CLOTH, M.SmoothPlastic, nc())
	P(m, "Runner", Vector3.new(1.4, 2, 0.1), cf * CFrame.new(0, 3.1, -0.75), rgb(120, 22, 30), M.SmoothPlastic, nc())
	for _, x in { -2.2, 2.2 } do
		Props.candelabra(m, (cf * CFrame.new(x, 4.1, 0.5)).Position)
	end
	P(m, "Book", Vector3.new(1.4, 0.3, 1), cf * CFrame.new(0, 4.25, 0.4), rgb(110, 30, 30), M.Leather, nc())
	return m
end

-- Витраж: цветные стёкла в свинцовой сетке (на стене, LookVector в комнату)
function Props.stainedGlass(parent, cf: CFrame, w: number, h: number)
	local m = model(parent, "StainedGlass")
	local cols = { rgb(170, 40, 50), rgb(40, 70, 170), rgb(200, 160, 40), rgb(40, 130, 70), rgb(120, 50, 140) }
	local n, k = 4, 0
	for ix = 0, n - 1 do
		for iy = 0, n * 2 - 1 do
			k += 1
			P(m, "Pane", Vector3.new(w / n - 0.12, h / (n * 2) - 0.12, 0.1), cf * CFrame.new(-w / 2 + (ix + 0.5) * w / n, -h / 2 + (iy + 0.5) * h / (n * 2), -0.1), cols[(ix * 3 + iy) % #cols + 1], M.Neon, nc({ Transparency = 0.35 }))
		end
	end
	P(m, "Lead", Vector3.new(w + 0.4, h + 0.4, 0.06), cf * CFrame.new(0, 0, -0.03), rgb(30, 28, 26), M.Metal, nc())
	return m
end

-- Колонна с базой и капителью
function Props.column(parent, cf: CFrame, h: number, r: number, color: Color3?)
	local m = model(parent, "Column")
	local c = color or rgb(196, 190, 180)
	P(m, "Plinth", Vector3.new(r * 2.8, 0.8, r * 2.8), cf * CFrame.new(0, 0.4, 0), c:Lerp(rgb(0, 0, 0), 0.15), M.Marble)
	C(m, "Torus", 0.6, r * 2.5, cf * CFrame.new(0, 1.1, 0), c, M.Marble)
	C(m, "Shaft", h - 2.8, r * 2, cf * CFrame.new(0, 1.4 + (h - 2.8) / 2, 0), c, M.Marble)
	C(m, "Echinus", 0.6, r * 2.5, cf * CFrame.new(0, h - 1.1, 0), c, M.Marble)
	P(m, "Abacus", Vector3.new(r * 2.9, 0.8, r * 2.9), cf * CFrame.new(0, h - 0.4, 0), c:Lerp(rgb(0, 0, 0), 0.15), M.Marble)
	return m
end

-- Перила между двумя точками на высоте y (балясины и поручень)
function Props.railing(parent, a: Vector3, b: Vector3, color: Color3?)
	local m = model(parent, "Railing")
	local c = color or Props.WOOD_DARK
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b)
	P(m, "Handrail", Vector3.new(0.5, 0.35, len), cf * CFrame.new(0, 3.3, 0), c, M.Wood)
	P(m, "BottomRail", Vector3.new(0.4, 0.3, len), cf * CFrame.new(0, 0.3, 0), c, M.Wood)
	local n = math.max(1, math.floor(len / 1.2))
	for k = 0, n do
		local z = -len / 2 + k * len / n
		local post = k % 6 == 0 or k == n
		P(m, if post then "Post" else "Baluster", Vector3.new(if post then 0.6 else 0.25, 3.2, if post then 0.6 else 0.25), cf * CFrame.new(0, 1.75, z), c, M.Wood, if post then nil else NOCOL)
	end
	return m
end

-- ---------------------------------------------------------------------------
-- кухня, магазин, казино, тюрьма, работа

function Props.stove(parent, cf: CFrame)
	local m = model(parent, "Stove")
	P(m, "Body", Vector3.new(7, 4, 3), cf * CFrame.new(0, 2, 0), rgb(120, 62, 48), M.Brick)
	P(m, "Top", Vector3.new(7.4, 0.4, 3.4), cf * CFrame.new(0, 4.2, 0), Props.IRON, M.Metal)
	for _, x in { -2.2, 0, 2.2 } do
		C(m, "Hob", 0.1, 1.4, cf * CFrame.new(x, 4.45, 0), rgb(30, 28, 26), M.Metal, nc())
	end
	local mouth = P(m, "Mouth", Vector3.new(3, 1.8, 0.2), cf * CFrame.new(0, 1.6, -1.5), rgb(30, 18, 12), M.Slate, nc())
	local fire = Instance.new("Fire")
	fire.Size = 2.5
	fire.Heat = 2
	fire.Parent = mouth
	light(mouth, 18, 1.4, rgb(255, 140, 60))
	P(m, "Hood", Vector3.new(7.6, 1.2, 3.6), cf * CFrame.new(0, 9.2, 0.2), rgb(110, 104, 98), M.Slate)
	P(m, "Flue", Vector3.new(3, 5, 2.4), cf * CFrame.new(0, 12.3, 0.4), rgb(110, 104, 98), M.Slate)
	-- котёл и сковороды
	C(m, "Pot", 1.4, 1.8, cf * CFrame.new(-2.2, 5.15, 0), Props.IRON, M.Metal, nc())
	C(m, "Soup", 0.1, 1.5, cf * CFrame.new(-2.2, 5.8, 0), rgb(170, 110, 60), M.SmoothPlastic, nc())
	C(m, "Pan", 0.3, 1.6, cf * CFrame.new(2.2, 4.65, 0), Props.IRON, M.Metal, nc())
	P(m, "PanHandle", Vector3.new(1.6, 0.15, 0.25), cf * CFrame.new(3.6, 4.7, 0), Props.IRON, M.Metal, nc())
	return m, mouth
end

-- Разделочный стол с овощами, ножом и доской
function Props.prepTable(parent, cf: CFrame)
	local m, top = Props.table(parent, cf, 6, 3)
	P(m, "Board", Vector3.new(2, 0.2, 1.4), cf * CFrame.new(-1, top + 0.1, 0), Props.WOOD_LIGHT, M.Wood, nc())
	P(m, "Knife", Vector3.new(1.2, 0.05, 0.15), cf * CFrame.new(-1, top + 0.23, 0.2), rgb(200, 202, 210), M.Metal, nc())
	for k, c in { rgb(220, 110, 40), rgb(110, 160, 60), rgb(200, 40, 40), rgb(230, 210, 120) } do
		S(m, "Veg", 0.5, cf * CFrame.new(0.6 + (k % 2) * 0.6, top + 0.25, -0.4 + math.floor(k / 2) * 0.6), c, M.SmoothPlastic, nc())
	end
	C(m, "Bowl", 0.4, 1.1, cf * CFrame.new(2, top + 0.2, 0), rgb(230, 225, 215), M.SmoothPlastic, nc())
	return m, top
end

-- Полка с банками и посудой (на стене)
function Props.shelfJars(parent, cf: CFrame, w: number)
	local m = model(parent, "Shelves")
	for k = 0, 2 do
		local y = 5 + k * 2
		P(m, "Board", Vector3.new(w, 0.2, 1.2), cf * CFrame.new(0, y, 0.6), Props.WOOD, M.Wood)
		for x = -w / 2 + 0.6, w / 2 - 0.6, 0.9 do
			local h = 0.6 + ((x * 3 + k) % 3) * 0.25
			C(m, "Jar", h, 0.55, cf * CFrame.new(x, y + 0.1 + h / 2, 0.6), Color3.fromHSV(((x + k) * 0.13) % 1, 0.4, 0.7), M.Glass, nc({ Transparency = 0.2 }))
		end
	end
	for _, x in { -w / 2 + 0.3, w / 2 - 0.3 } do
		P(m, "Bracket", Vector3.new(0.2, 4.4, 1.2), cf * CFrame.new(x, 7, 0.6), Props.WOOD_DARK, M.Wood)
	end
	return m
end

-- Вешалка с медной посудой
function Props.panRack(parent, cf: CFrame)
	local m = model(parent, "PanRack")
	P(m, "Bar", Vector3.new(5, 0.3, 0.3), cf * CFrame.new(0, 7.5, 0.4), Props.IRON, M.Metal, nc())
	for k = 0, 4 do
		local x = -2 + k
		P(m, "Hook", Vector3.new(0.08, 0.6, 0.08), cf * CFrame.new(x, 7.1, 0.4), Props.IRON, M.Metal, nc())
		C(m, "Pan", 0.15, 0.9 + (k % 2) * 0.3, cf * CFrame.new(x, 6.3, 0.3) * CFrame.Angles(math.pi / 2, 0, 0), rgb(184, 115, 70), M.Metal, nc())
	end
	return m
end

-- Прилавок магазина с товарами и весами
function Props.counter(parent, cf: CFrame, w: number)
	local m = model(parent, "Counter")
	P(m, "Body", Vector3.new(w, 3.2, 2), cf * CFrame.new(0, 1.6, 0), Props.WOOD, M.Wood)
	P(m, "Top", Vector3.new(w + 0.3, 0.25, 2.3), cf * CFrame.new(0, 3.3, 0), Props.WOOD_DARK, M.Wood)
	for x = -w / 2 + 1, w / 2 - 1, 1.6 do
		P(m, "Panel", Vector3.new(1.3, 2.2, 0.08), cf * CFrame.new(x, 1.6, -1.04), Props.WOOD_LIGHT, M.Wood, nc())
	end
	-- весы
	C(m, "ScaleBase", 0.2, 0.8, cf * CFrame.new(w / 2 - 1.2, 3.52, 0), Props.GOLD, M.Metal, nc())
	P(m, "ScalePost", Vector3.new(0.12, 1.3, 0.12), cf * CFrame.new(w / 2 - 1.2, 4.1, 0), Props.GOLD, M.Metal, nc())
	P(m, "ScaleBeam", Vector3.new(1.6, 0.08, 0.08), cf * CFrame.new(w / 2 - 1.2, 4.75, 0), Props.GOLD, M.Metal, nc())
	for _, s in { -0.75, 0.75 } do
		C(m, "Pan", 0.06, 0.6, cf * CFrame.new(w / 2 - 1.2 + s, 4.3, 0), Props.GOLD, M.Metal, nc())
	end
	-- шляпы и ткани на прилавке
	C(m, "Hat", 0.5, 1.2, cf * CFrame.new(-w / 2 + 1.3, 3.67, 0), rgb(60, 40, 90), M.SmoothPlastic, nc())
	C(m, "HatTop", 0.6, 0.7, cf * CFrame.new(-w / 2 + 1.3, 4.1, 0), rgb(60, 40, 90), M.SmoothPlastic, nc())
	for k = 0, 2 do
		P(m, "Cloth", Vector3.new(1.4, 0.2, 1), cf * CFrame.new(-0.5 + k * 0.1, 3.52 + k * 0.2, 0), Color3.fromHSV(k * 0.3, 0.6, 0.7), M.SmoothPlastic, nc())
	end
	return m
end

-- Игровой автомат
function Props.slotMachine(parent, cf: CFrame)
	local m = model(parent, "SlotMachine")
	local red = rgb(150, 26, 34)
	P(m, "Base", Vector3.new(3, 3, 2.4), cf * CFrame.new(0, 1.5, 0), red, M.SmoothPlastic)
	P(m, "Cabinet", Vector3.new(3, 3.6, 2), cf * CFrame.new(0, 4.8, 0.2), red, M.SmoothPlastic)
	P(m, "Screen", Vector3.new(2.4, 1.4, 0.1), cf * CFrame.new(0, 4.7, -0.82), rgb(250, 240, 210), M.Neon, nc())
	for k = -1, 1 do
		P(m, "Reel", Vector3.new(0.6, 1.1, 0.06), cf * CFrame.new(k * 0.75, 4.7, -0.9), Color3.fromHSV((k + 1) * 0.3, 0.8, 0.9), M.Neon, nc())
	end
	P(m, "Topper", Vector3.new(3.2, 0.9, 2.2), cf * CFrame.new(0, 7, 0.2), Props.GOLD, M.Metal)
	local lamp = P(m, "Lamp", Vector3.new(2.6, 0.4, 0.1), cf * CFrame.new(0, 7, -0.92), rgb(255, 200, 80), M.Neon, nc())
	light(lamp, 8, 0.8, rgb(255, 120, 80))
	P(m, "Lever", Vector3.new(0.2, 1.8, 0.2), cf * CFrame.new(1.7, 4.5, 0), rgb(200, 202, 210), M.Metal, nc())
	S(m, "LeverBall", 0.5, cf * CFrame.new(1.7, 5.5, 0), red, M.SmoothPlastic, nc())
	P(m, "Tray", Vector3.new(2, 0.2, 0.6), cf * CFrame.new(0, 2.9, -1.4), Props.GOLD, M.Metal, nc())
	return m
end

-- Стол для монетки / карт с зелёным сукном
function Props.feltTable(parent, cf: CFrame)
	local m = model(parent, "FeltTable")
	P(m, "Base", Vector3.new(2, 2.6, 2), cf * CFrame.new(0, 1.3, 0), Props.WOOD_DARK, M.Wood)
	C(m, "Rim", 0.4, 7.4, cf * CFrame.new(0, 3, 0), Props.WOOD, M.Wood)
	C(m, "Felt", 0.42, 6.6, cf * CFrame.new(0, 3.02, 0), rgb(26, 96, 56), M.Carpet)
	for k = 0, 5 do
		C(m, "Chip", 0.25, 0.45, cf * CFrame.new(-1 + k * 0.3, 3.3 + (k % 2) * 0.25, 1), Color3.fromHSV(k * 0.17, 0.8, 0.8), M.SmoothPlastic, nc())
	end
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2
		local cp = (cf * CFrame.new(math.cos(a) * 5, 0, math.sin(a) * 5)).Position
		Props.chair(m, CFrame.lookAt(cp, Vector3.new(cf.Position.X, cp.Y, cf.Position.Z)), rgb(26, 70, 46))
	end
	return m
end

-- Рулетка
function Props.roulette(parent, cf: CFrame)
	local m = model(parent, "Roulette")
	P(m, "Table", Vector3.new(8, 3, 4), cf * CFrame.new(0, 1.5, 0), Props.WOOD_DARK, M.Wood)
	P(m, "Felt", Vector3.new(7.6, 0.1, 3.6), cf * CFrame.new(0, 3.05, 0), rgb(26, 96, 56), M.Carpet)
	C(m, "Bowl", 0.5, 3, cf * CFrame.new(-2, 3.3, 0), Props.WOOD, M.Wood)
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		P(m, "Pocket", Vector3.new(0.4, 0.1, 0.4), cf * CFrame.new(-2 + math.cos(a) * 1.1, 3.58, math.sin(a) * 1.1), if k % 2 == 0 then rgb(170, 30, 30) else rgb(20, 20, 20), M.SmoothPlastic, nc())
	end
	C(m, "Spindle", 0.5, 0.4, cf * CFrame.new(-2, 3.8, 0), Props.GOLD, M.Metal, nc())
	for x = 0, 3 do
		for z = 0, 2 do
			P(m, "Number", Vector3.new(0.8, 0.12, 0.8), cf * CFrame.new(0.6 + x * 0.9, 3.1, -1 + z * 0.9), if (x + z) % 2 == 0 then rgb(170, 30, 30) else rgb(20, 20, 20), M.SmoothPlastic, nc())
		end
	end
	return m
end

-- Двухъярусные нары в камере
function Props.bunk(parent, cf: CFrame)
	local m = model(parent, "Bunk")
	for _, sx in { -1.6, 1.6 } do
		for _, sz in { -3.4, 3.4 } do
			P(m, "Post", Vector3.new(0.3, 7, 0.3), cf * CFrame.new(sx, 3.5, sz), Props.IRON, M.Metal)
		end
	end
	for _, y in { 1.6, 5 } do
		P(m, "Frame", Vector3.new(3.4, 0.3, 7.2), cf * CFrame.new(0, y, 0), Props.IRON, M.Metal)
		P(m, "Straw", Vector3.new(3, 0.4, 6.8), cf * CFrame.new(0, y + 0.35, 0), rgb(176, 150, 96), M.Cardboard)
		P(m, "Blanket", Vector3.new(3, 0.12, 3), cf * CFrame.new(0, y + 0.6, -1.5), rgb(90, 84, 70), M.Fabric, nc())
	end
	return m
end

-- Работа для узников: груда камня с киркой
function Props.rockPile(parent, cf: CFrame)
	local m = model(parent, "RockPile")
	for k = 0, 7 do
		local a = k * 0.9
		S(m, "Rock", 1.6 + (k % 3) * 0.7, cf * CFrame.new(math.cos(a) * 1.4, 0.6 + (k % 2) * 0.6, math.sin(a) * 1.4), rgb(110 + k * 4, 106, 100), M.Slate)
	end
	S(m, "Top", 2.4, cf * CFrame.new(0, 1.8, 0), rgb(120, 116, 110), M.Slate)
	P(m, "Handle", Vector3.new(0.2, 3, 0.2), cf * CFrame.new(2.6, 1.4, -1) * CFrame.Angles(0, 0, math.rad(-30)), Props.WOOD, M.Wood, nc())
	P(m, "Pick", Vector3.new(2, 0.25, 0.25), cf * CFrame.new(3.3, 2.7, -1) * CFrame.Angles(0, 0, math.rad(-20)), Props.IRON, M.Metal, nc())
	-- тачка
	P(m, "Cart", Vector3.new(2.4, 1, 3), cf * CFrame.new(-3.4, 1.2, 0), Props.WOOD, M.WoodPlanks)
	C(m, "Wheel", 0.3, 1.2, cf * CFrame.new(-3.4, 0.6, -1.8) * CFrame.Angles(0, 0, math.pi / 2), Props.IRON, M.Metal, nc())
	for k = 0, 2 do
		S(m, "Load", 0.9, cf * CFrame.new(-3.4 + (k - 1) * 0.6, 1.9, (k % 2) * 0.5), rgb(120, 116, 110), M.Slate, nc())
	end
	return m
end

-- Точильный круг
function Props.grindstone(parent, cf: CFrame)
	local m = model(parent, "Grindstone")
	P(m, "Frame", Vector3.new(1, 3, 3), cf * CFrame.new(-1, 1.5, 0), Props.WOOD, M.Wood)
	P(m, "Frame", Vector3.new(1, 3, 3), cf * CFrame.new(1, 1.5, 0), Props.WOOD, M.Wood)
	C(m, "Wheel", 0.8, 3, cf * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(150, 146, 140), M.Slate)
	P(m, "Axle", Vector3.new(3.4, 0.25, 0.25), cf * CFrame.new(0, 3, 0), Props.IRON, M.Metal, nc())
	P(m, "Crank", Vector3.new(0.2, 1, 0.2), cf * CFrame.new(1.8, 2.6, 0), Props.IRON, M.Metal, nc())
	C(m, "Trough", 0.6, 2.2, cf * CFrame.new(0, 0.3, -1.8), Props.WOOD, M.Wood)
	return m
end

-- Корыто для стирки с бельём
function Props.washtub(parent, cf: CFrame)
	local m = model(parent, "Washtub")
	C(m, "Tub", 1.6, 3.2, cf * CFrame.new(0, 0.8, 0), Props.WOOD_LIGHT, M.Wood)
	C(m, "Water", 0.1, 2.8, cf * CFrame.new(0, 1.55, 0), rgb(150, 170, 180), M.Glass, nc({ Transparency = 0.3 }))
	P(m, "Board", Vector3.new(1.2, 2.4, 0.15), cf * CFrame.new(0.6, 1.8, 0) * CFrame.Angles(0, 0, math.rad(-20)), Props.WOOD, M.Wood, nc())
	for k = 0, 2 do
		P(m, "Linen", Vector3.new(1.4, 0.1, 1), cf * CFrame.new(-0.7 + k * 0.2, 1.62, (k - 1) * 0.5) * CFrame.Angles(0, k, 0), rgb(230, 225, 210), M.SmoothPlastic, nc())
	end
	return m
end

-- Ведро
function Props.bucket(parent, cf: CFrame)
	local m = model(parent, "Bucket")
	C(m, "Pail", 1.2, 1.2, cf * CFrame.new(0, 0.6, 0), Props.WOOD_LIGHT, M.Wood)
	C(m, "Hoop", 0.15, 1.25, cf * CFrame.new(0, 0.9, 0), Props.IRON, M.Metal, nc())
	return m
end

-- Ванна на ножках
function Props.bathtub(parent, cf: CFrame)
	local m = model(parent, "Bathtub")
mark(P(m, "Tub", Vector3.new(3.4, 2.2, 6.4), cf * CFrame.new(0, 1.7, 0), rgb(240, 238, 232), M.CeramicTiles), "bath", 1.5)
	P(m, "Rim", Vector3.new(3.6, 0.3, 6.6), cf * CFrame.new(0, 2.9, 0), rgb(240, 238, 232), M.SmoothPlastic)
	P(m, "Water", Vector3.new(2.8, 0.1, 5.8), cf * CFrame.new(0, 2.6, 0), rgb(150, 190, 210), M.Glass, nc({ Transparency = 0.3 }))
	for _, sx in { -1.4, 1.4 } do
		for _, sz in { -2.6, 2.6 } do
			S(m, "ClawFoot", 0.7, cf * CFrame.new(sx, 0.35, sz), Props.GOLD, M.Metal)
		end
	end
	P(m, "Faucet", Vector3.new(0.3, 1.2, 0.3), cf * CFrame.new(0, 3.5, 3), Props.GOLD, M.Metal, nc())
	P(m, "Spout", Vector3.new(0.25, 0.25, 0.8), cf * CFrame.new(0, 4, 2.7), Props.GOLD, M.Metal, nc())
	return m
end

-- Умывальник с зеркалом
function Props.washstand(parent, cf: CFrame)
	local m = model(parent, "Washstand")
	P(m, "Cabinet", Vector3.new(3.4, 3, 1.8), cf * CFrame.new(0, 1.5, 0), Props.WOOD, M.Wood)
	P(m, "Top", Vector3.new(3.6, 0.25, 2), cf * CFrame.new(0, 3.12, 0), rgb(220, 214, 204), M.Marble)
mark(C(m, "Basin", 0.5, 1.6, cf * CFrame.new(0, 3.4, -0.1), rgb(245, 242, 236), M.CeramicTiles), "water")
	C(m, "Pitcher", 1, 0.6, cf * CFrame.new(1.2, 3.75, 0.1), rgb(245, 242, 236), M.SmoothPlastic, nc())
	P(m, "Mirror", Vector3.new(2.6, 3, 0.12), cf * CFrame.new(0, 5.8, 0.85), rgb(190, 205, 215), M.Glass, { Reflectance = 0.45, CanCollide = false })
	P(m, "MirrorFrame", Vector3.new(3, 3.4, 0.1), cf * CFrame.new(0, 5.8, 0.92), Props.GOLD, M.Metal, nc())
	return m
end

-- Телескоп на треноге
function Props.telescope(parent, cf: CFrame)
	local m = model(parent, "Telescope")
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		P(m, "Leg", Vector3.new(0.2, 4, 0.2), cf * CFrame.new(math.cos(a) * 0.9, 2, math.sin(a) * 0.9) * CFrame.Angles(math.cos(a) * 0.25, 0, -math.sin(a) * 0.25), Props.WOOD_DARK, M.Wood)
	end
	mark(C(m, "Tube", 5, 0.8, cf * CFrame.new(0, 4.6, 0) * CFrame.Angles(math.rad(-50), 0, 0) * CFrame.Angles(math.pi / 2, 0, 0), Props.GOLD, M.Metal), "telescope")
	C(m, "Lens", 0.2, 1.1, cf * CFrame.new(0, 6.5, -1.6) * CFrame.Angles(math.rad(-50), 0, 0) * CFrame.Angles(math.pi / 2, 0, 0), Props.IRON, M.Metal, nc())
	return m
end

-- Карта на столе с фигурками
function Props.mapTable(parent, cf: CFrame)
	local m, top = Props.table(parent, cf, 8, 5)
	mark(P(m, "Map", Vector3.new(7, 0.05, 4.2), cf * CFrame.new(0, top + 0.05, 0), rgb(220, 200, 150), M.Cardboard, nc({ CanQuery = true })), "map")
	for k = 0, 4 do
		P(m, "Land", Vector3.new(1.4, 0.06, 1), cf * CFrame.new(-2.5 + k * 1.3, top + 0.08, (k % 2) * 1.2 - 0.6) * CFrame.Angles(0, k, 0), rgb(150, 170, 110), M.SmoothPlastic, nc())
	end
	for k = 0, 5 do
		C(m, "Pin", 0.5, 0.25, cf * CFrame.new(-2.8 + k * 1.1, top + 0.3, (k % 3) - 1), if k % 2 == 0 then rgb(170, 30, 30) else rgb(30, 60, 160), M.SmoothPlastic, nc())
	end
	Props.candle(m, (cf * CFrame.new(3.2, top, 1.8)).Position)
	return m
end

-- Длинный стол трапезной с посудой и канделябрами
function Props.feastTable(parent, cf: CFrame, len: number, chairs: boolean)
	local m, top = Props.table(parent, cf, 5, len, rgb(236, 228, 210))
	local per = math.floor((len - 2) / 3)
	for k = 0, per - 1 do
		local z = -len / 2 + 2 + k * 3
		for _, s in { -1, 1 } do
			C(m, "Plate", 0.1, 1.3, cf * CFrame.new(s * 1.5, top + 0.08, z), rgb(245, 242, 236), M.SmoothPlastic, nc())
			C(m, "Goblet", 0.6, 0.35, cf * CFrame.new(s * 1.1, top + 0.35, z + 0.9), Props.GOLD, M.Metal, nc())
			P(m, "Fork", Vector3.new(0.1, 0.04, 0.9), cf * CFrame.new(s * 1.5 - 0.9, top + 0.05, z), rgb(200, 202, 210), M.Metal, nc())
			if chairs then
				Props.chair(m, cf * CFrame.new(s * 3.6, 0, z) * CFrame.Angles(0, if s > 0 then -math.pi / 2 else math.pi / 2, 0))
			end
		end
		if k % 2 == 1 then
			Props.candelabra(m, (cf * CFrame.new(0, top, z)).Position)
		end
	end
	-- блюда в центре
	C(m, "Platter", 0.15, 2, cf * CFrame.new(0, top + 0.1, -len / 4), rgb(200, 202, 210), M.Metal, nc())
	S(m, "Roast", 1.3, cf * CFrame.new(0, top + 0.6, -len / 4), rgb(150, 80, 40), M.SmoothPlastic, nc())
	C(m, "Fruitbowl", 0.5, 1.8, cf * CFrame.new(0, top + 0.3, len / 4), Props.GOLD, M.Metal, nc())
	for k = 0, 3 do
		S(m, "Fruit", 0.6, cf * CFrame.new(-0.4 + (k % 2) * 0.8, top + 0.7, len / 4 - 0.3 + math.floor(k / 2) * 0.6), Color3.fromHSV(k * 0.08, 0.8, 0.8), M.SmoothPlastic, nc())
	end
	return m, top
end

-- Скамья для улицы / зала
function Props.bench(parent, cf: CFrame, w: number)
	local m = model(parent, "Bench")
	seat(m, "Seat", Vector3.new(w, 0.4, 1.8), cf * CFrame.new(0, 1.9, 0), Props.WOOD, M.Wood)
	P(m, "Back", Vector3.new(w, 1.8, 0.3), cf * CFrame.new(0, 3, 0.8) * CFrame.Angles(math.rad(-8), 0, 0), Props.WOOD, M.Wood)
	for _, s in { -1, 1 } do
		P(m, "Leg", Vector3.new(0.4, 1.8, 1.6), cf * CFrame.new(s * (w / 2 - 0.5), 0.9, 0), Props.IRON, M.Metal)
	end
	return m
end

-- Фонарь на столбе (улица)
function Props.lamppost(parent, cf: CFrame)
	local m = model(parent, "Lamppost")
	C(m, "Foot", 0.6, 1.4, cf * CFrame.new(0, 0.3, 0), Props.IRON, M.Metal)
	C(m, "Pole", 9, 0.4, cf * CFrame.new(0, 5, 0), Props.IRON, M.Metal)
	P(m, "Cage", Vector3.new(1.4, 1.8, 1.4), cf * CFrame.new(0, 10.4, 0), Props.IRON, M.Metal, nc({ Transparency = 0.6 }))
	local glow = P(m, "Glow", Vector3.new(1, 1.3, 1), cf * CFrame.new(0, 10.4, 0), rgb(255, 210, 140), M.Neon, nc())
	P(m, "Cap", Vector3.new(1.8, 0.4, 1.8), cf * CFrame.new(0, 11.5, 0), Props.IRON, M.Metal, nc())
	light(glow, 24, 1.5)
	return m
end

-- Живая изгородь
function Props.hedge(parent, cf: CFrame, len: number)
	local m = model(parent, "Hedge")
	P(m, "Body", Vector3.new(len, 3.4, 2.4), cf * CFrame.new(0, 1.7, 0), rgb(54, 94, 46), M.Grass)
	for x = -len / 2 + 1, len / 2 - 1, 2.4 do
		S(m, "Bump", 2.4, cf * CFrame.new(x, 3.3, 0), rgb(60, 104, 50), M.Grass, nc())
	end
	return m
end

-- Клумба с цветами
function Props.flowerbed(parent, cf: CFrame, w: number, d: number, seed: number)
	local m = model(parent, "Flowerbed")
	P(m, "Edge", Vector3.new(w, 0.8, d), cf * CFrame.new(0, 0.4, 0), rgb(150, 145, 136), M.Slate)
	P(m, "Soil", Vector3.new(w - 0.8, 0.85, d - 0.8), cf * CFrame.new(0, 0.43, 0), rgb(70, 50, 36), M.Ground, nc())
	local rnd = Random.new(seed)
	for _ = 1, math.floor(w * d / 3) do
		local x, z = rnd:NextNumber(-w / 2 + 0.8, w / 2 - 0.8), rnd:NextNumber(-d / 2 + 0.8, d / 2 - 0.8)
		P(m, "Stem", Vector3.new(0.1, 0.9, 0.1), cf * CFrame.new(x, 1.3, z), rgb(60, 110, 50), M.Grass, nc())
		S(m, "Bloom", 0.5, cf * CFrame.new(x, 1.8, z), Color3.fromHSV(rnd:NextNumber(), 0.55, 1), M.SmoothPlastic, nc())
	end
	return m
end

-- Колодец
function Props.well(parent, cf: CFrame)
	local m = model(parent, "Well")
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		P(m, "Stone", Vector3.new(1.4, 2.6, 0.8), cf * CFrame.new(math.cos(a) * 2.4, 1.3, math.sin(a) * 2.4) * CFrame.Angles(0, -a, 0), rgb(140 + (k % 3) * 8, 134, 126), M.Slate)
	end
	C(m, "Water", 0.2, 4, cf * CFrame.new(0, 0.6, 0), rgb(40, 70, 90), M.Glass, nc({ Transparency = 0.2 }))
	for _, s in { -1, 1 } do
		P(m, "Post", Vector3.new(0.5, 5, 0.5), cf * CFrame.new(s * 2.6, 3.5, 0), Props.WOOD, M.Wood)
	end
	P(m, "Beam", Vector3.new(6, 0.4, 0.4), cf * CFrame.new(0, 5.6, 0), Props.WOOD_DARK, M.Wood)
	P(m, "Roof", Vector3.new(6.6, 0.3, 3.6), cf * CFrame.new(0, 6.7, -0.9) * CFrame.Angles(math.rad(-30), 0, 0), rgb(110, 60, 50), M.WoodPlanks)
	P(m, "Roof", Vector3.new(6.6, 0.3, 3.6), cf * CFrame.new(0, 6.7, 0.9) * CFrame.Angles(math.rad(30), 0, 0), rgb(110, 60, 50), M.WoodPlanks)
	P(m, "Rope", Vector3.new(0.1, 3, 0.1), cf * CFrame.new(0, 4, 0), rgb(160, 130, 90), M.Cardboard, nc())
	Props.bucket(m, cf * CFrame.new(0, 1.6, 0))
	return m
end

-- ---------------------------------------------------------------------------
-- режим «Маньяк»: скелеты, кровь, паутина, генераторы, доски, обломки

local BONE = rgb(222, 214, 192)

-- Скелет, сидящий у стены (cf — на полу у стены, LookVector в комнату)
function Props.skeleton(parent, cf: CFrame)
	local m = model(parent, "Skeleton")
	S(m, "Skull", 1.1, cf * CFrame.new(0, 3.3, 0.2) * CFrame.Angles(math.rad(-20), 0.3, 0), BONE, M.SmoothPlastic, nc())
	for _, x in { -0.22, 0.22 } do
		C(m, "EyeHole", 0.05, 0.3, cf * CFrame.new(x, 3.4, -0.26) * CFrame.Angles(math.pi / 2, 0, 0), rgb(20, 16, 14), M.SmoothPlastic, nc())
	end
	P(m, "Jaw", Vector3.new(0.7, 0.25, 0.5), cf * CFrame.new(0, 2.85, -0.05), BONE, M.SmoothPlastic, nc())
	P(m, "Spine", Vector3.new(0.18, 2, 0.18), cf * CFrame.new(0, 2, 0.4) * CFrame.Angles(math.rad(-12), 0, 0), BONE, M.SmoothPlastic, nc())
	for k = 0, 3 do
		C(m, "Rib", 0.12, 1.3 - k * 0.12, cf * CFrame.new(0, 2.5 - k * 0.32, 0.25), BONE, M.SmoothPlastic, nc())
	end
	P(m, "Pelvis", Vector3.new(1.1, 0.4, 0.6), cf * CFrame.new(0, 0.9, 0.3), BONE, M.SmoothPlastic, nc())
	for _, sx in { -1, 1 } do
		P(m, "Femur", Vector3.new(0.18, 0.18, 1.8), cf * CFrame.new(sx * 0.35, 0.8, -0.5), BONE, M.SmoothPlastic, nc())
		P(m, "Shin", Vector3.new(0.16, 1.4, 0.16), cf * CFrame.new(sx * 0.4, 0.75, -1.4) * CFrame.Angles(math.rad(20), 0, 0), BONE, M.SmoothPlastic, nc())
		P(m, "Arm", Vector3.new(0.14, 1.6, 0.14), cf * CFrame.new(sx * 0.75, 1.9, 0.1) * CFrame.Angles(math.rad(-25), 0, sx * math.rad(12)), BONE, M.SmoothPlastic, nc())
	end
	return m
end

-- Лужа или брызги крови (плоский диск на полу)
function Props.blood(parent, pos: Vector3, size: number, seed: number)
	local m = model(parent, "Blood")
	local rnd = Random.new(seed)
	C(m, "Pool", 0.04, size, CFrame.new(pos + Vector3.new(0, 0.03, 0)), rgb(86, 6, 10), M.SmoothPlastic, nc({ Reflectance = 0.15 }))
	for _ = 1, 4 do
		local d = rnd:NextNumber(0.4, size * 0.35)
		local off = Vector3.new(rnd:NextNumber(-1, 1), 0, rnd:NextNumber(-1, 1)).Unit * (size * 0.5 + rnd:NextNumber(0.2, 1.2))
		C(m, "Drop", 0.04, d, CFrame.new(pos + off + Vector3.new(0, 0.035, 0)), rgb(96, 8, 12), M.SmoothPlastic, nc({ Reflectance = 0.15 }))
	end
	return m
end

-- Кровавый след на стене (cf — на стене, LookVector в комнату)
function Props.bloodWall(parent, cf: CFrame, seed: number)
	local m = model(parent, "BloodWall")
	local rnd = Random.new(seed)
	for k = 0, 4 do
		P(m, "Smear", Vector3.new(rnd:NextNumber(0.3, 0.6), rnd:NextNumber(1, 2.6), 0.04), cf * CFrame.new(-0.8 + k * 0.4, -k * 0.15, -0.02) * CFrame.Angles(0, 0, rnd:NextNumber(-0.25, 0.25)), rgb(90, 8, 12), M.SmoothPlastic, nc())
	end
	return m
end

-- Паутина в углу под потолком
function Props.cobweb(parent, pos: Vector3, rot: number)
	local m = model(parent, "Cobweb")
	for k = 0, 3 do
		P(m, "Web", Vector3.new(0.04, 3.2 - k * 0.5, 3.2 - k * 0.5), CFrame.new(pos) * CFrame.Angles(0, rot, 0) * CFrame.Angles(0, 0, math.rad(45)) * CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(k * 20), 0, 0), rgb(220, 220, 220), M.SmoothPlastic, nc({ Transparency = 0.6 }))
	end
	return m
end

-- Генератор: рама, мотор, трубы, циферблаты, рычаг, лампа (красная → зелёная)
function Props.generator(parent, cf: CFrame)
	local m = model(parent, "Generator")
	local metal = rgb(70, 74, 70)
	P(m, "Skid", Vector3.new(5, 0.4, 3.2), cf * CFrame.new(0, 0.2, 0), rgb(50, 46, 40), M.Metal)
	local body = mark(P(m, "Body", Vector3.new(4.2, 3, 2.6), cf * CFrame.new(0, 1.9, 0), metal, M.CorrodedMetal), "repair", 3, 9)
	P(m, "Engine", Vector3.new(2, 1.4, 2), cf * CFrame.new(-0.6, 4.1, 0), rgb(56, 58, 56), M.Metal)
	for k = 0, 3 do
		P(m, "Fin", Vector3.new(2.2, 0.12, 2.2), cf * CFrame.new(-0.6, 3.6 + k * 0.3, 0), rgb(40, 40, 40), M.Metal, nc())
	end
	C(m, "Pipe", 3, 0.5, cf * CFrame.new(1.4, 4.6, 0.8), rgb(120, 80, 50), M.Metal, nc())
	C(m, "Exhaust", 0.6, 0.7, cf * CFrame.new(1.4, 6.2, 0.8), rgb(30, 30, 30), M.Metal, nc())
	for _, x in { -1.2, 0.2 } do
		C(m, "Gauge", 0.1, 0.8, cf * CFrame.new(x, 2.4, -1.35) * CFrame.Angles(math.pi / 2, 0, 0), rgb(235, 230, 210), M.SmoothPlastic, nc())
		P(m, "Needle", Vector3.new(0.05, 0.35, 0.05), cf * CFrame.new(x, 2.5, -1.42) * CFrame.Angles(0, 0, math.rad(30)), rgb(160, 20, 20), M.Metal, nc())
	end
	P(m, "Lever", Vector3.new(0.18, 1.4, 0.18), cf * CFrame.new(1.6, 3.6, -1) * CFrame.Angles(math.rad(-25), 0, 0), rgb(150, 150, 156), M.Metal, nc())
	local lamp = S(m, "StatusLamp", 0.6, cf * CFrame.new(-1.6, 3.7, -1.1), rgb(220, 30, 30), M.Neon, nc())
	local l = light(lamp, 10, 0.9, rgb(255, 60, 60))
	local _ = l
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Rate = 0
	sparks.Speed = NumberRange.new(6, 10)
	sparks.SpreadAngle = Vector2.new(60, 60)
	sparks.Lifetime = NumberRange.new(0.3, 0.6)
	sparks.Acceleration = Vector3.new(0, -30, 0)
	sparks.Size = NumberSequence.new(0.15, 0)
	sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(rgb(255, 200, 90))
	sparks.Parent = body
	-- провода к стене
	for k = 0, 2 do
		C(m, "Cable", 4, 0.15, cf * CFrame.new(-1 + k * 0.5, 0.5, 2.6) * CFrame.Angles(math.pi / 2, 0, 0), rgb(20, 20, 20), M.Rubber, nc())
	end
	return m, body, lamp
end

-- Заколоченный проём: доски крест-накрест с гвоздями
function Props.barricade(parent, cf: CFrame, w: number, h: number)
	local m = model(parent, "Barricade")
	local main
	for k = 0, 4 do
		local plank = P(m, "Plank", Vector3.new(w + 1.4, 0.9, 0.25), cf * CFrame.new(0, 1.5 + k * (h - 2) / 4, -0.4 - (k % 2) * 0.2) * CFrame.Angles(0, 0, math.rad((k % 2 == 0) and 8 or -10)), Props.WOOD_LIGHT:Lerp(rgb(60, 50, 40), (k % 3) * 0.15), M.WoodPlanks)
		main = main or plank
		for _, x in { -w / 2, w / 2 } do
			C(m, "Nail", 0.1, 0.18, plank.CFrame * CFrame.new(x * 0.9, 0, -0.15) * CFrame.Angles(math.pi / 2, 0, 0), Props.IRON, M.Metal, nc())
		end
	end
	-- сплошная преграда во весь проём (доски сами с щелями)
	local block = P(m, "BarricadeBlock", Vector3.new(w, h, 0.6), cf * CFrame.new(0, h / 2, 0), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1 })
	mark(block, "barricade", 4, 8)
	return m, block
end

-- Пролом в стене: обломки по краям; сам проход закрыт только для маньяка
function Props.rubble(parent, cf: CFrame, w: number, h: number)
	local m = model(parent, "Rubble")
	for k = 0, 7 do
		local side = if k % 2 == 0 then -1 else 1
		S(m, "Stone", 0.8 + (k % 3) * 0.4, cf * CFrame.new(side * (w / 2 - 0.4 - (k % 4) * 0.2), 0.4 + (k % 3) * 0.2, -0.8 + (k % 3) * 0.5), rgb(120 + k * 4, 114, 106), M.Slate, nc())
	end
	P(m, "Crack", Vector3.new(0.15, h * 0.6, 0.1), cf * CFrame.new(w / 2 + 0.6, h * 0.6, -0.55) * CFrame.Angles(0, 0, math.rad(15)), rgb(30, 26, 24), M.SmoothPlastic, nc())
	-- знак мелом: здесь безопасно
	P(m, "Chalk", Vector3.new(1.2, 0.1, 0.05), cf * CFrame.new(-w / 2 - 1.2, 5, -0.55) * CFrame.Angles(0, 0, math.rad(45)), rgb(240, 240, 240), M.SmoothPlastic, nc())
	P(m, "Chalk", Vector3.new(1.2, 0.1, 0.05), cf * CFrame.new(-w / 2 - 1.2, 5, -0.55) * CFrame.Angles(0, 0, math.rad(-45)), rgb(240, 240, 240), M.SmoothPlastic, nc())
	local block = P(m, "ManiacBlock", Vector3.new(w, h, 1), cf * CFrame.new(0, h / 2, 0), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CanQuery = false })
	pcall(function()
		block.CollisionGroup = "ManiacBlock"
	end)
	return m
end

return Props
