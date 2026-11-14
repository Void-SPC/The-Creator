--!nonstrict
-- Простые модели лабиринта-отеля: стены с проёмами, двери с номером, шкафы, кровати,
-- комоды, столы, лампы, картины, растения, лифт, генераторы. Все размеры в studs

local CollectionService = game:GetService("CollectionService")
local M = require(game:GetService("ReplicatedStorage").Workshop.Shared.Materials)

local Props = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
Props.rgb = rgb

Props.WOOD = rgb(110, 76, 50)
Props.WOOD_DARK = rgb(70, 46, 32)
Props.BRASS = rgb(196, 160, 90)
Props.IRON = rgb(60, 60, 64)

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

-- без столкновений (мелкие детали)
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

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end
Props.model = model

local function light(part, range, brightness, color)
	local l = Instance.new("PointLight")
	l.Range = range
	l.Brightness = brightness
	l.Color = color or rgb(255, 214, 160)
	l.Shadows = true
	l.Parent = part
	return l
end
Props.light = light

-- кнопка взаимодействия; подпись ставит клиент по атрибуту Kind
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

-- Стена вдоль оси X локального кадра cf (cf — середина стены на полу, LookVector в комнату)
-- с проёмами holes = { { x = центр, w = ширина, h = высота } }
function Props.wall(parent, cf: CFrame, length: number, height: number, thick: number, holes, color, mat)
	table.sort(holes, function(a, b)
		return a.x < b.x
	end)
	local x = -length / 2
	local function seg(x0, x1, y0, y1)
		if x1 - x0 > 0.05 and y1 - y0 > 0.05 then
			P(parent, "Wall", Vector3.new(x1 - x0, y1 - y0, thick), cf * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0), color, mat)
		end
	end
	for _, h in holes do
		seg(x, h.x - h.w / 2, 0, height)
		seg(h.x - h.w / 2, h.x + h.w / 2, h.h, height)
		x = h.x + h.w / 2
	end
	seg(x, length / 2, 0, height)
end

-- Дверь: рама, створка на петлях, табличка с номером. cf — середина проёма на полу,
-- LookVector — в следующую комнату. Возвращает модель, створку и кнопку
function Props.door(parent, cf: CFrame, number: number?, locked: boolean?)
	local m = model(parent, "Door")
	local w, h = 5, 9
	local frame = Props.WOOD_DARK
	P(m, "Jamb", Vector3.new(0.6, h + 0.6, 1.2), cf * CFrame.new(-w / 2 - 0.3, (h + 0.6) / 2, 0), frame, M.Wood)
	P(m, "Jamb", Vector3.new(0.6, h + 0.6, 1.2), cf * CFrame.new(w / 2 + 0.3, (h + 0.6) / 2, 0), frame, M.Wood)
	P(m, "Head", Vector3.new(w + 1.2, 0.6, 1.2), cf * CFrame.new(0, h + 0.3, 0), frame, M.Wood)
	local leaf = model(m, "Leaf")
	local slab = P(leaf, "Slab", Vector3.new(w - 0.1, h - 0.05, 0.3), cf * CFrame.new(0, h / 2, 0), Props.WOOD, M.WoodPlanks)
	for _, y in { 2.6, 6.4 } do
		P(leaf, "Panel", Vector3.new(w - 1.4, 2.6, 0.1), cf * CFrame.new(0, y, 0.18), Props.WOOD_DARK, M.Wood, nc())
		P(leaf, "Panel", Vector3.new(w - 1.4, 2.6, 0.1), cf * CFrame.new(0, y, -0.18), Props.WOOD_DARK, M.Wood, nc())
	end
	local knob = P(leaf, "Knob", Vector3.new(0.35, 0.35, 0.9), cf * CFrame.new(w / 2 - 0.6, 4.3, 0), Props.BRASS, M.Metal, nc({ Shape = Enum.PartType.Ball }))
	local _ = knob
	leaf.WorldPivot = cf * CFrame.new(-w / 2, 0, 0)
	if number then
		-- латунная табличка с номером со стороны входа
		local plate = P(m, "NumberPlate", Vector3.new(2.2, 1, 0.1), cf * CFrame.new(0, h + 1.4, 0.65), Props.BRASS, M.Metal, nc())
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.Parent = plate
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.Antique
		t.TextScaled = true
		t.TextColor3 = rgb(40, 28, 16)
		t.Text = string.format("%04d", number)
		t.Parent = gui
	end
	local lock
	if locked then
		lock = model(m, "Padlock")
		P(lock, "Body", Vector3.new(0.9, 1, 0.4), cf * CFrame.new(w / 2 - 0.7, 3.4, 0.5), rgb(150, 140, 120), M.Metal, nc())
		P(lock, "Shackle", Vector3.new(0.6, 0.6, 0.15), cf * CFrame.new(w / 2 - 0.7, 4.1, 0.5), rgb(120, 120, 126), M.Metal, nc())
	end
	-- кнопка открытия по середине проёма
	local trig = P(m, "Trigger", Vector3.new(1, 1, 1), cf * CFrame.new(0, 4, 0), rgb(0, 0, 0), M.SmoothPlastic, nc({ Transparency = 1 }))
	local pr = Props.prompt(trig, "door", 0.5, 9)
	CollectionService:AddTag(m, "LabDoor")
	return m, leaf, pr, slab
end

-- Шкаф для пряток. cf — у стены, LookVector в комнату
function Props.closet(parent, cf: CFrame)
	local m = model(parent, "Closet")
	local w, d, h = 4.4, 3, 8.6
	local body = P(m, "Body", Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, -d / 2), Props.WOOD_DARK, M.Wood, { CanCollide = false })
	-- стенки с полостью внутри, чтобы игрок помещался
	P(m, "Back", Vector3.new(w, h, 0.3), cf * CFrame.new(0, h / 2, -0.15), Props.WOOD_DARK, M.Wood)
	for _, s in { -1, 1 } do
		P(m, "Side", Vector3.new(0.3, h, d), cf * CFrame.new(s * (w / 2 - 0.15), h / 2, -d / 2), Props.WOOD_DARK, M.Wood)
		P(m, "DoorLeaf", Vector3.new(w / 2 - 0.2, h - 0.8, 0.2), cf * CFrame.new(s * (w / 4), h / 2, -d + 0.1), Props.WOOD, M.Wood)
		P(m, "Handle", Vector3.new(0.15, 0.8, 0.15), cf * CFrame.new(s * 0.35, h / 2, -d - 0.05), Props.BRASS, M.Metal, nc())
	end
	P(m, "Top", Vector3.new(w + 0.3, 0.4, d + 0.15), cf * CFrame.new(0, h + 0.2, -d / 2 - 0.075), Props.WOOD_DARK, M.Wood)
	P(m, "Base", Vector3.new(w, 0.5, d), cf * CFrame.new(0, 0.25, -d / 2), Props.WOOD_DARK, M.Wood)
	-- щель между дверцами светится изнутри чуть-чуть
	P(m, "Gap", Vector3.new(0.1, h - 1.2, 0.05), cf * CFrame.new(0, h / 2, -d - 0.01), rgb(10, 8, 6), M.SmoothPlastic, nc())
	body.Transparency = 1
	Props.prompt(body, "hide", 0.3, 7)
	CollectionService:AddTag(body, "Closet")
	return m, body
end

-- Комод с ящиком для обыска
function Props.dresser(parent, cf: CFrame)
	local m = model(parent, "Dresser")
	local body = P(m, "Body", Vector3.new(4.6, 3.2, 1.8), cf * CFrame.new(0, 1.7, -0.9), Props.WOOD, M.Wood)
	P(m, "Top", Vector3.new(4.9, 0.2, 2), cf * CFrame.new(0, 3.4, -1), Props.WOOD_DARK, M.Wood)
	for k = 0, 1 do
		P(m, "Drawer", Vector3.new(4, 1.1, 0.1), cf * CFrame.new(0, 1.1 + k * 1.3, -1.85), Props.WOOD_DARK, M.Wood, nc())
		P(m, "Pull", Vector3.new(0.6, 0.15, 0.15), cf * CFrame.new(0, 1.1 + k * 1.3, -1.95), Props.BRASS, M.Metal, nc())
	end
	Props.prompt(body, "search", 0.6, 7)
	return m, body
end

function Props.bed(parent, cf: CFrame, color: Color3)
	local m = model(parent, "Bed")
	P(m, "Frame", Vector3.new(5, 1.4, 8), cf * CFrame.new(0, 0.9, -4), Props.WOOD_DARK, M.Wood)
	P(m, "Mattress", Vector3.new(4.6, 0.7, 7.6), cf * CFrame.new(0, 1.9, -4), rgb(220, 214, 200), M.SmoothPlastic)
	P(m, "Blanket", Vector3.new(4.8, 0.3, 5), cf * CFrame.new(0, 2.35, -5.2), color, M.Fabric)
	P(m, "Pillow", Vector3.new(3.2, 0.6, 1.4), cf * CFrame.new(0, 2.5, -1.1), rgb(236, 232, 224), M.SmoothPlastic, nc())
	P(m, "Headboard", Vector3.new(5, 3.6, 0.4), cf * CFrame.new(0, 1.8, -0.2), Props.WOOD_DARK, M.Wood)
	return m
end

function Props.table(parent, cf: CFrame, w: number, d: number)
	local m = model(parent, "Table")
	P(m, "Top", Vector3.new(w, 0.3, d), cf * CFrame.new(0, 3, 0), Props.WOOD, M.Wood)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			P(m, "Leg", Vector3.new(0.3, 2.85, 0.3), cf * CFrame.new(sx * (w / 2 - 0.4), 1.43, sz * (d / 2 - 0.4)), Props.WOOD_DARK, M.Wood)
		end
	end
	return m
end

function Props.chair(parent, cf: CFrame)
	local m = model(parent, "Chair")
	P(m, "Seat", Vector3.new(1.8, 0.25, 1.8), cf * CFrame.new(0, 1.8, 0), Props.WOOD, M.Wood)
	P(m, "Back", Vector3.new(1.8, 2.2, 0.2), cf * CFrame.new(0, 3, 0.8), Props.WOOD, M.Wood)
	for _, sx in { -0.75, 0.75 } do
		for _, sz in { -0.75, 0.75 } do
			P(m, "Leg", Vector3.new(0.2, 1.7, 0.2), cf * CFrame.new(sx, 0.85, sz), Props.WOOD_DARK, M.Wood, nc())
		end
	end
	return m
end

-- Настольная или напольная лампа с абажуром; возвращает абажур со светом
function Props.lamp(parent, pos: Vector3, tall: boolean?)
	local m = model(parent, "Lamp")
	local h = if tall then 6 else 1.8
	P(m, "Base", Vector3.new(1, 0.2, 1), CFrame.new(pos + Vector3.new(0, 0.1, 0)), Props.BRASS, M.Metal, nc())
	P(m, "Stem", Vector3.new(0.2, h, 0.2), CFrame.new(pos + Vector3.new(0, h / 2, 0)), Props.BRASS, M.Metal, nc())
	local shade = P(m, "Shade", Vector3.new(1.6, 1.2, 1.6), CFrame.new(pos + Vector3.new(0, h + 0.5, 0)), rgb(240, 214, 160), M.Neon, nc({ Transparency = 0.2 }))
	light(shade, 18, 1.1)
	CollectionService:AddTag(shade, "LabLight")
	return m, shade
end

-- Люстра на потолке. pos — точка крепления под потолком
function Props.ceilingLight(parent, pos: Vector3)
	local m = model(parent, "CeilingLight")
	P(m, "Rod", Vector3.new(0.15, 1.6, 0.15), CFrame.new(pos - Vector3.new(0, 0.8, 0)), Props.IRON, M.Metal, nc())
	local bulb = P(m, "Bulb", Vector3.new(1.6, 0.8, 1.6), CFrame.new(pos - Vector3.new(0, 1.9, 0)), rgb(255, 226, 180), M.Neon, nc())
	P(m, "Rim", Vector3.new(2.2, 0.2, 2.2), CFrame.new(pos - Vector3.new(0, 1.5, 0)), Props.BRASS, M.Metal, nc())
	light(bulb, 26, 1.2)
	CollectionService:AddTag(bulb, "LabLight")
	return m, bulb
end

function Props.painting(parent, cf: CFrame, w: number, h: number, seed: number)
	local m = model(parent, "Painting")
	P(m, "Frame", Vector3.new(w + 0.5, h + 0.5, 0.2), cf, Props.BRASS:Lerp(rgb(0, 0, 0), 0.3), M.Wood, nc())
	local hue = (seed * 0.137) % 1
	P(m, "Canvas", Vector3.new(w, h, 0.05), cf * CFrame.new(0, 0, -0.12), Color3.fromHSV(hue, 0.35, 0.35), M.SmoothPlastic, nc())
	P(m, "Shape", Vector3.new(w * 0.4, h * 0.4, 0.05), cf * CFrame.new(((seed % 3) - 1) * w * 0.2, 0, -0.15), Color3.fromHSV((hue + 0.5) % 1, 0.3, 0.5), M.SmoothPlastic, nc())
	return m
end

function Props.plantPot(parent, cf: CFrame)
	local m = model(parent, "PlantPot")
	P(m, "Pot", Vector3.new(1.6, 1.6, 1.6), cf * CFrame.new(0, 0.8, 0), rgb(150, 80, 56), M.Brick)
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		P(m, "Leaf", Vector3.new(0.5, 2.6, 0.12), cf * CFrame.new(math.cos(a) * 0.5, 2.6, math.sin(a) * 0.5) * CFrame.Angles(math.sin(a) * 0.4, 0, math.cos(a) * 0.4), rgb(60, 120, 60), M.Grass, nc())
	end
	return m
end

function Props.shelf(parent, cf: CFrame, seed: number)
	local m = model(parent, "Shelf")
	P(m, "Back", Vector3.new(6, 8, 0.3), cf * CFrame.new(0, 4, -0.15), Props.WOOD_DARK, M.Wood)
	for _, s in { -1, 1 } do
		P(m, "Side", Vector3.new(0.3, 8, 1.8), cf * CFrame.new(s * 2.85, 4, -0.9), Props.WOOD_DARK, M.Wood)
	end
	for r = 0, 3 do
		P(m, "Board", Vector3.new(5.4, 0.2, 1.6), cf * CFrame.new(0, 0.3 + r * 2.4, -0.9), Props.WOOD, M.Wood)
		if r < 3 then
			for b = 0, 2 do
				P(m, "Books", Vector3.new(1.5, 1.6, 1.2), cf * CFrame.new(-1.8 + b * 1.8, 1.2 + r * 2.4, -0.9), Color3.fromHSV(((seed + r * 3 + b) * 0.21) % 1, 0.45, 0.4), M.SmoothPlastic, nc())
			end
		end
	end
	return m
end

function Props.desk(parent, cf: CFrame)
	local m = model(parent, "Desk")
	P(m, "Top", Vector3.new(5, 0.3, 2.6), cf * CFrame.new(0, 3, -1.3), Props.WOOD, M.Wood)
	for _, s in { -1, 1 } do
		P(m, "Pedestal", Vector3.new(1.4, 2.85, 2.4), cf * CFrame.new(s * 1.7, 1.43, -1.3), Props.WOOD_DARK, M.Wood)
	end
	P(m, "Papers", Vector3.new(1.2, 0.05, 1.6), cf * CFrame.new(-0.8, 3.18, -1.2) * CFrame.Angles(0, 0.3, 0), rgb(230, 226, 210), M.SmoothPlastic, nc())
	return m
end

function Props.bench(parent, cf: CFrame, w: number)
	local m = model(parent, "Bench")
	P(m, "Seat", Vector3.new(w, 0.4, 1.8), cf * CFrame.new(0, 1.8, -0.9), Props.WOOD, M.Wood)
	for _, s in { -1, 1 } do
		P(m, "Leg", Vector3.new(0.4, 1.6, 1.6), cf * CFrame.new(s * (w / 2 - 0.4), 0.8, -0.9), Props.IRON, M.Metal)
	end
	return m
end

function Props.pillar(parent, cf: CFrame, h: number)
	local m = model(parent, "Pillar")
	P(m, "Shaft", Vector3.new(2.4, h, 2.4), cf * CFrame.new(0, h / 2, 0), rgb(150, 140, 126), M.Limestone)
	P(m, "Base", Vector3.new(3.2, 0.8, 3.2), cf * CFrame.new(0, 0.4, 0), rgb(120, 112, 100), M.Limestone)
	P(m, "Cap", Vector3.new(3.2, 0.8, 3.2), cf * CFrame.new(0, h - 0.4, 0), rgb(120, 112, 100), M.Limestone)
	return m
end

function Props.crate(parent, cf: CFrame, s: number?)
	local size = s or 3
	local m = model(parent, "Crate")
	P(m, "Box", Vector3.new(size, size, size), cf * CFrame.new(0, size / 2, 0), rgb(130, 98, 62), M.WoodPlanks)
	return m
end

-- Предмет на полу или столе (батарейка, ключ, растение, деталь)
function Props.pickup(parent, cf: CFrame, item: string)
	local m = model(parent, "Pickup")
	local root
	if item == "battery" then
		root = P(m, "Battery", Vector3.new(0.5, 1, 0.5), cf * CFrame.new(0, 0.5, 0), rgb(40, 140, 60), M.Metal)
		P(m, "Tip", Vector3.new(0.25, 0.15, 0.25), cf * CFrame.new(0, 1.07, 0), rgb(200, 200, 200), M.Metal, nc())
	elseif item == "key" then
		root = P(m, "Key", Vector3.new(1.4, 0.15, 0.45), cf * CFrame.new(0, 0.1, 0), Props.BRASS, M.Metal)
		P(m, "Bow", Vector3.new(0.6, 0.16, 0.6), cf * CFrame.new(-0.8, 0.1, 0), Props.BRASS, M.Metal, nc())
		light(root, 6, 0.6, rgb(255, 220, 140))
	elseif item == "fuse" then
		root = P(m, "Fuse", Vector3.new(0.8, 1.6, 0.8), cf * CFrame.new(0, 0.8, 0), rgb(60, 110, 170), M.Glass)
		P(m, "Cap", Vector3.new(0.9, 0.3, 0.9), cf * CFrame.new(0, 1.7, 0), Props.BRASS, M.Metal, nc())
		light(root, 8, 0.8, rgb(120, 180, 255))
	elseif item == "plant" then
		root = P(m, "Sprout", Vector3.new(0.8, 0.8, 0.8), cf * CFrame.new(0, 0.4, 0), rgb(150, 80, 56), M.Brick)
		P(m, "Leaves", Vector3.new(1, 1, 1), cf * CFrame.new(0, 1.2, 0), rgb(80, 170, 80), M.Grass, nc({ Shape = Enum.PartType.Ball }))
	else
		root = P(m, "Coins", Vector3.new(1, 0.3, 1), cf * CFrame.new(0, 0.15, 0), rgb(230, 190, 70), M.Metal, { Shape = Enum.PartType.Cylinder })
		root.CFrame = cf * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.pi / 2)
	end
	root:SetAttribute("Item", item)
	Props.prompt(root, "pick", 0, 7)
	return m, root
end

-- Генератор для зала Слепого
function Props.generator(parent, cf: CFrame)
	local m = model(parent, "Generator")
	local body = P(m, "Body", Vector3.new(5, 4, 3.4), cf * CFrame.new(0, 2, 0), rgb(90, 96, 92), M.DiamondPlate)
	P(m, "Panel", Vector3.new(3, 2, 0.2), cf * CFrame.new(0, 2.4, -1.8), rgb(40, 42, 40), M.Metal, nc())
	local lamp = P(m, "StatusLamp", Vector3.new(0.6, 0.6, 0.6), cf * CFrame.new(1.8, 4.3, -1.2), rgb(220, 40, 30), M.Neon, nc({ Shape = Enum.PartType.Ball }))
	light(lamp, 10, 1, rgb(255, 60, 40))
	for _, s in { -1, 1 } do
		P(m, "Pipe", Vector3.new(0.5, 3, 0.5), cf * CFrame.new(s * 2, 5.5, 0.8), rgb(70, 70, 74), M.Metal)
	end
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

return Props
