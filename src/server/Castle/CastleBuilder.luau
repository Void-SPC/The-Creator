--!nonstrict
-- Постройка замка «The Castle». Около 160 × 300 studs, стены 60, главная башня 140
-- (примерно 50 метров, если считать человека ростом 5 studs). Всё собирается кодом:
-- камень, тёмное дерево, красный ковёр, факелы, окна, мебель, у которой есть функция

local Lighting = game:GetService("Lighting")

local B = {}

local terrain = workspace.Terrain

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local STONE = rgb(118, 112, 104)
local STONE_DARK = rgb(84, 80, 76)
local WOOD = rgb(92, 62, 40)
local WOOD_DARK = rgb(60, 40, 28)
local CARPET = rgb(140, 24, 32)
local GOLD = rgb(214, 172, 80)

local root: Folder
local prompts = {} -- имя -> список ProximityPrompt (функции подключает CastleGame)
B.prompts = prompts
B.points = {}

local function part(parent: Instance, props): BasePart
	local p = Instance.new(props.Class or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "Class" and k ~= "Sphere" then
			(p :: any)[k] = v
		end
	end
	if props.Sphere then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	end
	p.Parent = parent
	return p
end
B.part = part

local function box(parent, name, x0, y0, z0, x1, y1, z1, color, mat, extra)
	local props = {
		Name = name,
		Size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)),
		CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		Color = color or STONE,
		Material = mat or Enum.Material.Slate,
	}
	if extra then
		for k, v in extra do
			props[k] = v
		end
	end
	return part(parent, props)
end

-- Кнопка взаимодействия; kind — смысл (CastleGame вешает действие по kind)
local function prompt(at: BasePart, kind: string, text: string, holdTime: number?, dist: number?)
	local p = Instance.new("ProximityPrompt")
	p.Name = kind
	p.ActionText = text
	p.ObjectText = ""
	p.HoldDuration = holdTime or 0
	p.MaxActivationDistance = dist or 9
	p.RequiresLineOfSight = false
	p:SetAttribute("Kind", kind)
	p.Parent = at
	prompts[kind] = prompts[kind] or {}
	table.insert(prompts[kind], p)
	return p
end
B.prompt = prompt

-- Стена вдоль X (z фиксирован) с проёмами gaps = { {центрX, ширина, высота} }
local function wallX(parent, z, x0, x1, y0, h, gaps, t, color, mat)
	t = t or 2
	local cuts = {}
	for _, g in gaps or {} do
		table.insert(cuts, { g[1] - g[2] / 2, g[1] + g[2] / 2, g[3] })
	end
	table.sort(cuts, function(a, b)
		return a[1] < b[1]
	end)
	local x = x0
	for _, c in cuts do
		if c[1] > x then
			box(parent, "Wall", x, y0, z - t / 2, c[1], y0 + h, z + t / 2, color, mat)
		end
		if c[3] < h then
			box(parent, "Wall", c[1], y0 + c[3], z - t / 2, c[2], y0 + h, z + t / 2, color, mat)
		end
		x = c[2]
	end
	if x < x1 then
		box(parent, "Wall", x, y0, z - t / 2, x1, y0 + h, z + t / 2, color, mat)
	end
end

local function wallZ(parent, x, z0, z1, y0, h, gaps, t, color, mat)
	t = t or 2
	local cuts = {}
	for _, g in gaps or {} do
		table.insert(cuts, { g[1] - g[2] / 2, g[1] + g[2] / 2, g[3] })
	end
	table.sort(cuts, function(a, b)
		return a[1] < b[1]
	end)
	local z = z0
	for _, c in cuts do
		if c[1] > z then
			box(parent, "Wall", x - t / 2, y0, z, x + t / 2, y0 + h, c[1], color, mat)
		end
		if c[3] < h then
			box(parent, "Wall", x - t / 2, y0 + c[3], c[1], x + t / 2, y0 + h, c[2], color, mat)
		end
		z = c[2]
	end
	if z < z1 then
		box(parent, "Wall", x - t / 2, y0, z, x + t / 2, y0 + h, z1, color, mat)
	end
end

-- Факел: держатель, палка и живой огонь с тёплым светом
local function torch(parent, pos: Vector3, outward: Vector3)
	local m = Instance.new("Model")
	m.Name = "Torch"
	local cf = CFrame.lookAt(pos, pos + outward)
	part(m, { Name = "Bracket", Size = Vector3.new(0.5, 0.5, 1.2), CFrame = cf * CFrame.new(0, 0, -0.6), Color = rgb(40, 38, 36), Material = Enum.Material.Metal, CanCollide = false })
	local stick = part(m, { Name = "Stick", Size = Vector3.new(0.35, 2, 0.35), CFrame = cf * CFrame.new(0, 0.5, -1.2) * CFrame.Angles(math.rad(-20), 0, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, CanCollide = false })
	local head = part(m, { Name = "Flame", Size = Vector3.new(0.5, 0.5, 0.5), CFrame = stick.CFrame * CFrame.new(0, 1.1, 0), Color = rgb(255, 150, 60), Material = Enum.Material.Neon, CanCollide = false })
	local fire = Instance.new("Fire")
	fire.Size = 2.5
	fire.Heat = 6
	fire.Color = rgb(255, 140, 50)
	fire.SecondaryColor = rgb(255, 60, 20)
	fire.Parent = head
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 160, 80)
	light.Range = 20
	light.Brightness = 1.6
	light.Shadows = false
	light.Parent = head
	head:SetAttribute("TorchLight", true)
	m.Parent = parent
end

-- Окно: каменный проём, рама с переплётом, стекло, подоконник
local function window(parent, pos: Vector3, outward: Vector3, w: number?, h: number?)
	w, h = w or 4, h or 7
	local cf = CFrame.lookAt(pos, pos + outward)
	part(parent, { Name = "Sill", Size = Vector3.new(w + 1, 0.5, 2.6), CFrame = cf * CFrame.new(0, -h / 2 - 0.25, 0), Color = STONE_DARK, Material = Enum.Material.Slate })
	part(parent, { Name = "Arch", Size = Vector3.new(w + 1, 0.8, 2.6), CFrame = cf * CFrame.new(0, h / 2 + 0.4, 0), Color = STONE_DARK, Material = Enum.Material.Slate })
	part(parent, { Name = "Glass", Size = Vector3.new(w, h, 0.3), CFrame = cf, Color = rgb(170, 200, 230), Material = Enum.Material.Glass, Transparency = 0.45, CastShadow = false })
	part(parent, { Name = "Mullion", Size = Vector3.new(0.25, h, 0.45), CFrame = cf, Color = WOOD_DARK, Material = Enum.Material.Wood })
	part(parent, { Name = "Transom", Size = Vector3.new(w, 0.25, 0.45), CFrame = cf * CFrame.new(0, h * 0.15, 0), Color = WOOD_DARK, Material = Enum.Material.Wood })
end

local function carpet(parent, x0, z0, x1, z1, y)
	box(parent, "Carpet", x0, y, z0, x1, y + 0.12, z1, CARPET, Enum.Material.Carpet)
	-- золотая кайма
	box(parent, "Trim", x0 - 0.4, y, z0, x0, y + 0.13, z1, GOLD, Enum.Material.Fabric)
	box(parent, "Trim", x1, y, z0, x1 + 0.4, y + 0.13, z1, GOLD, Enum.Material.Fabric)
end

local function pillar(parent, x, z, y0, h, r)
	part(parent, { Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, r * 2, r * 2), CFrame = CFrame.new(x, y0 + h / 2, z) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(150, 144, 136), Material = Enum.Material.Marble })
	part(parent, { Name = "Base", Size = Vector3.new(r * 2.6, 1, r * 2.6), CFrame = CFrame.new(x, y0 + 0.5, z), Color = STONE_DARK, Material = Enum.Material.Slate })
	part(parent, { Name = "Capital", Size = Vector3.new(r * 2.6, 1, r * 2.6), CFrame = CFrame.new(x, y0 + h - 0.5, z), Color = STONE_DARK, Material = Enum.Material.Slate })
end

local function banner(parent, pos: Vector3, outward: Vector3, h: number)
	local cf = CFrame.lookAt(pos, pos + outward)
	part(parent, { Name = "Banner", Size = Vector3.new(4, h, 0.2), CFrame = cf * CFrame.new(0, -h / 2, 0.3), Color = rgb(120, 20, 30), Material = Enum.Material.Fabric, CanCollide = false })
	part(parent, { Name = "Rod", Size = Vector3.new(5, 0.3, 0.3), CFrame = cf * CFrame.new(0, 0, 0.3), Color = GOLD, Material = Enum.Material.Metal, CanCollide = false })
	part(parent, { Name = "Emblem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 2.4, 2.4), CFrame = cf * CFrame.new(0, -h * 0.4, 0.15) * CFrame.Angles(0, math.pi / 2, 0), Color = GOLD, Material = Enum.Material.Metal, CanCollide = false })
end

local function chandelier(parent, pos: Vector3)
	local m = Instance.new("Model")
	m.Name = "Chandelier"
	part(m, { Name = "Chain", Size = Vector3.new(0.2, 6, 0.2), CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)), Color = rgb(40, 38, 36), Material = Enum.Material.Metal, CanCollide = false })
	part(m, { Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 7, 7), CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(50, 46, 40), Material = Enum.Material.Metal, CanCollide = false })
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local c = part(m, { Name = "Candle", Size = Vector3.new(0.3, 0.8, 0.3), CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * 3.3, 0.6, math.sin(a) * 3.3)), Color = rgb(255, 220, 160), Material = Enum.Material.Neon, CanCollide = false })
		local _ = c
	end
	local core = part(m, { Name = "Glow", Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.new(pos), Transparency = 1, CanCollide = false })
	local l = Instance.new("PointLight")
	l.Range = 34
	l.Brightness = 1.8
	l.Color = rgb(255, 200, 140)
	l.Parent = core
	m.Parent = parent
end

local function bed(parent, cf: CFrame, blanket: Color3)
	part(parent, { Name = "BedFrame", Size = Vector3.new(4.5, 1.4, 8), CFrame = cf * CFrame.new(0, 0.7, 0), Color = WOOD, Material = Enum.Material.Wood })
	part(parent, { Name = "Headboard", Size = Vector3.new(4.5, 3.4, 0.5), CFrame = cf * CFrame.new(0, 1.7, 3.8), Color = WOOD_DARK, Material = Enum.Material.Wood })
	part(parent, { Name = "Mattress", Size = Vector3.new(4.1, 0.7, 7.4), CFrame = cf * CFrame.new(0, 1.75, -0.1), Color = rgb(235, 230, 220), Material = Enum.Material.Fabric })
	local b = part(parent, { Name = "Blanket", Size = Vector3.new(4.2, 0.3, 4.6), CFrame = cf * CFrame.new(0, 2.2, -1.3), Color = blanket, Material = Enum.Material.Fabric })
	part(parent, { Name = "Pillow", Size = Vector3.new(3, 0.5, 1.4), CFrame = cf * CFrame.new(0, 2.3, 2.8), Color = rgb(245, 245, 245), Material = Enum.Material.Fabric })
	prompt(b, "rest", "", 1.5)
	return b
end

local function table_(parent, cf: CFrame, w, d)
	part(parent, { Name = "TableTop", Size = Vector3.new(w, 0.5, d), CFrame = cf * CFrame.new(0, 3.2, 0), Color = WOOD, Material = Enum.Material.WoodPlanks })
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(parent, { Name = "Leg", Size = Vector3.new(0.6, 3, 0.6), CFrame = cf * CFrame.new(sx * (w / 2 - 0.6), 1.5, sz * (d / 2 - 0.6)), Color = WOOD_DARK, Material = Enum.Material.Wood })
		end
	end
end

local function bench(parent, cf: CFrame, w)
	part(parent, { Name = "Bench", Size = Vector3.new(w, 0.5, 1.6), CFrame = cf * CFrame.new(0, 1.9, 0), Color = WOOD, Material = Enum.Material.WoodPlanks })
	for _, sx in { -1, 1 } do
		part(parent, { Name = "Leg", Size = Vector3.new(0.5, 1.7, 1.4), CFrame = cf * CFrame.new(sx * (w / 2 - 0.5), 0.85, 0), Color = WOOD_DARK, Material = Enum.Material.Wood })
	end
end

local BOOK_COLORS = { rgb(120, 30, 30), rgb(40, 70, 120), rgb(50, 90, 50), rgb(140, 100, 40), rgb(80, 40, 90), rgb(160, 140, 110) }
local function bookshelf(parent, cf: CFrame, w, h, seed)
	part(parent, { Name = "Shelf", Size = Vector3.new(w, h, 0.4), CFrame = cf * CFrame.new(0, h / 2, 0.9), Color = WOOD_DARK, Material = Enum.Material.Wood })
	for _, sx in { -1, 1 } do
		part(parent, { Name = "Side", Size = Vector3.new(0.4, h, 2.2), CFrame = cf * CFrame.new(sx * w / 2, h / 2, 0), Color = WOOD_DARK, Material = Enum.Material.Wood })
	end
	local rows = math.floor(h / 2.6)
	for r = 0, rows - 1 do
		local y = 0.3 + r * 2.6
		part(parent, { Name = "Board", Size = Vector3.new(w, 0.3, 2.2), CFrame = cf * CFrame.new(0, y, 0), Color = WOOD, Material = Enum.Material.Wood })
		-- книги блоками разной высоты, чтобы полка не выглядела пустой и не тяжелела
		local x = -w / 2 + 0.4
		local k = seed + r * 7
		while x < w / 2 - 1 do
			local bw = 0.9 + (k % 3) * 0.5
			local bh = 1.5 + (k % 4) * 0.2
			part(parent, { Name = "Books", Size = Vector3.new(bw, bh, 1.6), CFrame = cf * CFrame.new(x + bw / 2, y + 0.15 + bh / 2, 0.1), Color = BOOK_COLORS[k % #BOOK_COLORS + 1], Material = Enum.Material.Fabric, CanCollide = false })
			x += bw + 0.08
			k += 1
		end
	end
end

local function stairs(parent, x0, x1, z0, y0, rise, run, steps, dir, color)
	-- dir = +1 вверх по оси Z, -1 вниз по оси Z
	for i = 0, steps - 1 do
		local z = z0 + dir * (i + 0.5) * run
		box(parent, "Step", x0, y0, z - run / 2, x1, y0 + (i + 1) * rise, z + run / 2, color or STONE_DARK, Enum.Material.Slate)
	end
end

-- ---------------------------------------------------------------------------
-- Рельеф: остров с замком, ров с водой по кругу, трава вокруг

local function landscape()
	terrain:FillBlock(CFrame.new(0, 30, 0), Vector3.new(900, 140, 900), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(0, -12, 0), Vector3.new(900, 24, 900), Enum.Material.Grass)
	-- ров шириной 34 вокруг стен
	terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(160 + 68, 14, 300 + 68), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(0, -8.5, 0), Vector3.new(160 + 68, 9, 300 + 68), Enum.Material.Water)
	terrain:FillBlock(CFrame.new(0, -7, 0), Vector3.new(164, 14, 304), Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(0, -12, 0), Vector3.new(160 + 80, 4, 300 + 80), Enum.Material.Mud)
end

-- ---------------------------------------------------------------------------

function B.build()
	local old = workspace:FindFirstChild("TheCastle")
	if old then
		old:Destroy()
	end
	table.clear(prompts)
	root = Instance.new("Folder")
	root.Name = "TheCastle"
	root.Parent = workspace
	B.root = root
	landscape()

	local outer = Instance.new("Model")
	outer.Name = "Walls"
	local inside = Instance.new("Model")
	inside.Name = "Interior"
	local yard = Instance.new("Model")
	yard.Name = "Courtyard"

	-- ---- внешние стены с зубцами и четыре башни
	local WH = 60
	wallX(outer, -150, -80, 80, 0, WH, { { 0, 16, 22 } }, 6)
	wallX(outer, 150, -80, 80, 0, WH, nil, 6)
	wallZ(outer, -80, -150, 150, 0, WH, nil, 6)
	wallZ(outer, 80, -150, 150, 0, WH, nil, 6)
	for x = -78, 78, 6 do
		box(outer, "Merlon", x - 1.5, WH, -153, x + 1.5, WH + 4, -147)
		box(outer, "Merlon", x - 1.5, WH, 147, x + 1.5, WH + 4, 153)
	end
	for z = -146, 146, 6 do
		box(outer, "Merlon", -83, WH, z - 1.5, -77, WH + 4, z + 1.5)
		box(outer, "Merlon", 77, WH, z - 1.5, 83, WH + 4, z + 1.5)
	end
	for _, c in { { -80, -150 }, { 80, -150 }, { -80, 150 }, { 80, 150 } } do
		part(outer, { Name = "Tower", Shape = Enum.PartType.Cylinder, Size = Vector3.new(96, 28, 28), CFrame = CFrame.new(c[1], 48, c[2]) * CFrame.Angles(0, 0, math.pi / 2), Color = STONE, Material = Enum.Material.Slate })
		part(outer, { Name = "TowerTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 32, 32), CFrame = CFrame.new(c[1], 98, c[2]) * CFrame.Angles(0, 0, math.pi / 2), Color = STONE_DARK, Material = Enum.Material.Slate })
		-- конусная крыша башни из колец
		for k = 0, 6 do
			local r = 30 - k * 4.4
			local roof = part(outer, { Name = "TowerRoof", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, r, r), CFrame = CFrame.new(c[1], 101.5 + k * 3, c[2]) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(70, 50, 60), Material = Enum.Material.RoofShingles })
			roof:SetAttribute("Roof", true)
		end
	end
	-- главная башня над тронным залом: 140 studs, около 50 метров
	box(outer, "Keep", -24, 60, 104, 24, 132, 148, STONE, Enum.Material.Slate)
	for k = 0, 7 do
		local w = 52 - k * 6.5
		local roof = box(outer, "KeepRoof", -w / 2, 132 + k * 2.5, 126 - w * 0.45, w / 2, 134.5 + k * 2.5, 126 + w * 0.45, rgb(70, 50, 60), Enum.Material.RoofShingles)
		roof:SetAttribute("Roof", true)
	end
	for _, x in { -20, -8, 8, 20 } do
		window(outer, Vector3.new(x, 100, 103.6), Vector3.new(0, 0, -1), 4, 9)
	end

	-- ---- мост и ворота
	box(outer, "Bridge", -8, -0.6, -186, 8, 0.4, -150, WOOD, Enum.Material.WoodPlanks)
	for z = -184, -152, 4 do
		box(outer, "Rail", -8.4, 0.4, z - 0.25, -7.6, 3.4, z + 0.25, WOOD_DARK, Enum.Material.Wood)
		box(outer, "Rail", 7.6, 0.4, z - 0.25, 8.4, 3.4, z + 0.25, WOOD_DARK, Enum.Material.Wood)
	end
	box(outer, "Handrail", -8.5, 3.2, -186, -7.5, 3.6, -150, WOOD, Enum.Material.Wood)
	box(outer, "Handrail", 7.5, 3.2, -186, 8.5, 3.6, -150, WOOD, Enum.Material.Wood)
	local gate = box(outer, "Portcullis", -8, 0, -151, 8, 22, -149.5, rgb(45, 42, 40), Enum.Material.DiamondPlate, { Transparency = 0.15 })
	gate:SetAttribute("Gate", true)
	B.gate = gate
	torch(outer, Vector3.new(-12, 14, -154), Vector3.new(0, 0, -1))
	torch(outer, Vector3.new(12, 14, -154), Vector3.new(0, 0, -1))
	B.points.outside = CFrame.new(0, 3, -200)

	-- ---- двор: брусчатка, фонтан со статуей короля, скамьи, доска ролей
	terrain:FillBlock(CFrame.new(0, -0.5, -90), Vector3.new(154, 1, 118), Enum.Material.Cobblestone)
	local basin = part(yard, { Name = "Fountain", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 30, 30), CFrame = CFrame.new(0, 1, -90) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(170, 165, 158), Material = Enum.Material.Marble })
	part(yard, { Name = "FountainWater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 27, 27), CFrame = CFrame.new(0, 1.8, -90) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(70, 130, 170), Material = Enum.Material.Glass, Transparency = 0.35, CanCollide = false })
	local plinth = box(yard, "StatuePlinth", -5, 0, -95, 5, 8, -85, rgb(170, 165, 158), Enum.Material.Marble)
	local jets = part(yard, { Name = "Jets", Size = Vector3.new(10, 1, 10), CFrame = CFrame.new(0, 8.5, -90), Transparency = 1, CanCollide = false })
	local spray = Instance.new("ParticleEmitter")
	spray.Rate = 60
	spray.Speed = NumberRange.new(8, 12)
	spray.SpreadAngle = Vector2.new(25, 25)
	spray.Lifetime = NumberRange.new(1, 1.4)
	spray.Acceleration = Vector3.new(0, -30, 0)
	spray.Size = NumberSequence.new(0.35)
	spray.Color = ColorSequence.new(rgb(190, 220, 255))
	spray.Transparency = NumberSequence.new(0.3)
	spray.Parent = jets
	prompt(basin, "water", "", 0, 18)
	B.points.statue = CFrame.new(0, 8, -90)
	local _ = plinth
	for _, x in { -30, 30 } do
		for _, z in { -110, -70 } do
			bench(yard, CFrame.new(x, 0, z) * CFrame.Angles(0, math.pi / 2, 0), 8)
		end
	end
	local board = box(yard, "RoleBoard", -30, 2, -140, -20, 10, -139, WOOD, Enum.Material.WoodPlanks)
	box(yard, "BoardPost", -29.5, 0, -139.8, -28.5, 10, -139, WOOD_DARK, Enum.Material.Wood)
	box(yard, "BoardPost", -21.5, 0, -139.8, -20.5, 10, -139, WOOD_DARK, Enum.Material.Wood)
	prompt(board, "roles", "", 0, 14)
	-- деревья во дворе и по берегу (меняются со временем года)
	B.trees = {}
	for _, t in { { -22, -125 }, { 55, -125 }, { -22, -55 }, { 55, -55 } } do
		table.insert(B.trees, Vector3.new(t[1], 0, t[2]))
	end
	for i = 0, 27 do
		local a = i / 28 * math.pi * 2
		table.insert(B.trees, Vector3.new(math.cos(a) * 170, 0, math.sin(a) * 250))
	end
	-- свечение окон и факелы вдоль стен двора
	for z = -140, -40, 20 do
		torch(yard, Vector3.new(-76.5, 12, z), Vector3.new(1, 0, 0))
		torch(yard, Vector3.new(76.5, 12, z), Vector3.new(-1, 0, 0))
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 6)
	spawn.CFrame = CFrame.new(0, 0.5, -132)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = yard
	B.points.yard = CFrame.new(0, 3, -125)

	-- ---- главное здание: z от -30 до 147, два этажа по 20 и тронный зал высотой 36
	local FH = 20
	local KZ0 = -30
	local function floorWithHole(name, x0, x1, z0, z1, y0, y1, hx0, hx1, hz0, hz1, color, mat)
		-- плита с прямоугольной дырой (для люка и лестниц); пустые куски пропускаются
		local function piece(a0, b0, a1, b1)
			if a1 - a0 > 0.01 and b1 - b0 > 0.01 then
				box(inside, name, a0, y0, b0, a1, y1, b1, color, mat)
			end
		end
		piece(x0, z0, x1, hz0)
		piece(x0, hz1, x1, z1)
		piece(x0, hz0, hx0, hz1)
		piece(hx1, hz0, x1, hz1)
	end
	-- пол первого этажа, с отверстием под люком за троном
	floorWithHole("Floor", -78, 78, KZ0, 147, -0.4, 0.2, -3, 3, 139, 145, rgb(100, 94, 86), Enum.Material.Slate)
	wallX(inside, KZ0, -78, 78, 0, 60, { { 0, 12, 16 } }, 3)
	for _, x in { -60, -40, -20, 20, 40, 60 } do
		window(inside, Vector3.new(x, 10, KZ0 - 1.6), Vector3.new(0, 0, -1))
		window(inside, Vector3.new(x, 30, KZ0 - 1.6), Vector3.new(0, 0, -1))
		window(inside, Vector3.new(x, 50, KZ0 - 1.6), Vector3.new(0, 0, -1), 4, 6)
	end
	torch(inside, Vector3.new(-9, 9, KZ0 - 2), Vector3.new(0, 0, -1))
	torch(inside, Vector3.new(9, 9, KZ0 - 2), Vector3.new(0, 0, -1))
	local roofTop = box(inside, "Roof", -78, 60, KZ0, 78, 61, 147, rgb(70, 50, 60), Enum.Material.RoofShingles)
	roofTop:SetAttribute("Roof", true)

	-- холл z -30..0: высокий, с двумя лестницами вдоль фасада на второй этаж
	carpet(inside, -3, KZ0 + 1, 3, 90, 0.2)
	wallX(inside, 0, -78, 78, 0, FH, { { 0, 12, 16 }, { -45, 8, 10 }, { 45, 8, 10 } }, 2)
	for i = 0, FH - 1 do
		local x = 12 + i * 1.4
		box(inside, "Step", -x - 1.4, 0, -29, -x, i + 1, -22, STONE_DARK, Enum.Material.Slate)
		box(inside, "Step", x, 0, -29, x + 1.4, i + 1, -22, STONE_DARK, Enum.Material.Slate)
	end
	carpet(inside, -40, -27, -12, -24, 0)
	-- перила лестниц
	for i = 0, FH - 1, 2 do
		local x = 12.7 + i * 1.4
		box(inside, "Baluster", -x - 0.2, i + 1, -22.4, -x + 0.2, i + 4, -22, WOOD_DARK, Enum.Material.Wood)
		box(inside, "Baluster", x - 0.2, i + 1, -22.4, x + 0.2, i + 4, -22, WOOD_DARK, Enum.Material.Wood)
	end
	box(inside, "HallCeiling", -12, 40, KZ0, 12, 41, 0, STONE_DARK)
	chandelier(inside, Vector3.new(0, 30, -15))
	banner(inside, Vector3.new(-8, 34, -1.2), Vector3.new(0, 0, -1), 12)
	banner(inside, Vector3.new(8, 34, -1.2), Vector3.new(0, 0, -1), 12)
	-- второй этаж: плиты с проёмами над лестницами, стены и потолки
	floorWithHole("Floor2", -78, -12, KZ0, 90, FH, FH + 1, -40, -12, KZ0, -20, rgb(100, 94, 86), Enum.Material.Slate)
	floorWithHole("Floor2", 12, 78, KZ0, 0, FH, FH + 1, 12, 40, KZ0, -20, rgb(100, 94, 86), Enum.Material.Slate)
	for x = -39, -13, 2 do
		box(inside, "Rail", x - 0.2, FH + 1, -20.4, x + 0.2, FH + 4, -20, WOOD_DARK, Enum.Material.Wood)
		box(inside, "Rail", -x - 0.2, FH + 1, -20.4, -x + 0.2, FH + 4, -20, WOOD_DARK, Enum.Material.Wood)
	end
	box(inside, "Handrail", -40, FH + 3.8, -20.6, -12, FH + 4.3, -19.8, WOOD, Enum.Material.Wood)
	box(inside, "Handrail", 12, FH + 3.8, -20.6, 40, FH + 4.3, -19.8, WOOD, Enum.Material.Wood)
	wallZ(inside, -12, KZ0, 90, FH + 1, FH - 1, nil, 2)
	wallZ(inside, 12, KZ0, 0, FH + 1, FH - 1, nil, 2)
	wallX(inside, 0, 12, 78, FH + 1, FH - 1, nil, 2)
	wallX(inside, 90, -78, -12, FH + 1, FH - 1, nil, 2)
	box(inside, "Ceiling2", -78, 40, KZ0, -12, 41, 90, STONE_DARK)
	box(inside, "Ceiling2", 12, 40, KZ0, 78, 41, 0, STONE_DARK)

	-- центральный коридор z 0..90 с ковром и факелами
	wallZ(inside, -12, 0, 90, 0, FH, { { 20, 8, 10 }, { 65, 8, 10 } }, 2)
	wallZ(inside, 12, 0, 90, 0, FH, { { 20, 8, 10 }, { 65, 8, 10 } }, 2)
	for z = 6, 86, 10 do
		torch(inside, Vector3.new(-10.6, 9, z), Vector3.new(1, 0, 0))
		torch(inside, Vector3.new(10.6, 9, z), Vector3.new(-1, 0, 0))
	end
	box(inside, "CorridorCeiling", -12, FH, 0, 12, FH + 1, 90, STONE_DARK)
	box(inside, "CasinoCeiling", 12, FH, 60, 78, FH + 1, 90, STONE_DARK)
	-- ---- кухня (запад, z 0..45)
	wallX(inside, 45, -78, -12, 0, FH, { { -45, 8, 10 } }, 2)
	for i, x in { -70, -58 } do
		local oven = box(inside, "Oven", x - 4, 0, 40, x + 4, 7, 44, rgb(120, 60, 50), Enum.Material.Brick)
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Parent = box(inside, "OvenFire", x - 2, 1, 39.9, x + 2, 4, 40, rgb(40, 20, 10), Enum.Material.Slate)
		local l = Instance.new("PointLight")
		l.Color = rgb(255, 140, 60)
		l.Range = 18
		l.Parent = oven
		if i == 1 then
			prompt(oven, "cook", "", 2)
		end
	end
	local counter = box(inside, "Counter", -40, 0, 30, -18, 3.4, 34, WOOD, Enum.Material.WoodPlanks)
	prompt(counter, "bread", "")
	local fruit = box(inside, "FruitTable", -40, 0, 10, -28, 3.4, 14, WOOD, Enum.Material.WoodPlanks)
	for k = 0, 6 do
		part(inside, { Name = "Apple", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = CFrame.new(-39 + k * 1.5, 3.8, 12), Color = rgb(190, 40, 40), CanCollide = false })
	end
	prompt(fruit, "apple", "")
	local drawer = box(inside, "Cutlery", -70, 0, 6, -64, 3.4, 9, WOOD_DARK, Enum.Material.Wood)
	prompt(drawer, "spoon", "")
	for k = 0, 4 do
		part(inside, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.2, 2.8, 2.8), CFrame = CFrame.new(-75, 1.6, 12 + k * 4) * CFrame.Angles(0, 0, math.pi / 2), Color = WOOD, Material = Enum.Material.Wood })
	end
	chandelier(inside, Vector3.new(-45, 16, 22))
	window(inside, Vector3.new(-79, 10, 22), Vector3.new(-1, 0, 0))

	-- ---- трапезная (запад, z 45..90)
	wallX(inside, 90, -78, -12, 0, FH, nil, 2)
	table_(inside, CFrame.new(-45, 0, 67), 34, 6)
	bench(inside, CFrame.new(-45, 0, 62.5), 32)
	bench(inside, CFrame.new(-45, 0, 71.5), 32)
	for k = 0, 5 do
		part(inside, { Name = "Plate", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 1.6, 1.6), CFrame = CFrame.new(-60 + k * 6, 3.55, 65.5) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(235, 230, 220), Material = Enum.Material.SmoothPlastic, CanCollide = false })
		part(inside, { Name = "Plate", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 1.6, 1.6), CFrame = CFrame.new(-60 + k * 6, 3.55, 68.5) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(235, 230, 220), Material = Enum.Material.SmoothPlastic, CanCollide = false })
	end
	chandelier(inside, Vector3.new(-55, 16, 67))
	chandelier(inside, Vector3.new(-35, 16, 67))
	window(inside, Vector3.new(-79, 10, 60), Vector3.new(-1, 0, 0))
	window(inside, Vector3.new(-79, 10, 78), Vector3.new(-1, 0, 0))

	-- ---- библиотека (восток, z 0..60, высота 40)
	wallX(inside, 60, 12, 78, 0, 40, { { 45, 8, 10 } }, 2)
	box(inside, "LibraryCeiling", 12, 40, 0, 78, 41, 60, STONE_DARK)
	local seed = 1
	for z = 6, 54, 8 do
		bookshelf(inside, CFrame.new(76, 0, z) * CFrame.Angles(0, math.pi / 2, 0), 7, 16, seed)
		seed += 3
	end
	for x = 22, 70, 8 do
		bookshelf(inside, CFrame.new(x, 0, 2) * CFrame.Angles(0, math.pi, 0), 7, 16, seed)
		seed += 5
	end
	-- галерея второго яруса библиотеки, лестница к ней вдоль галереи
	box(inside, "Gallery", 60, 18, 2, 78, 19, 58, WOOD, Enum.Material.WoodPlanks)
	for z = 4, 56, 4 do
		if z < 26 or z > 36 then
			box(inside, "GalleryRail", 59.6, 19, z - 0.2, 60.2, 22, z + 0.2, WOOD_DARK, Enum.Material.Wood)
		end
	end
	box(inside, "GalleryHandrail", 59.5, 21.8, 2, 60.3, 22.4, 26, WOOD, Enum.Material.Wood)
	box(inside, "GalleryHandrail", 59.5, 21.8, 36, 60.3, 22.4, 58, WOOD, Enum.Material.Wood)
	for i = 0, 17 do
		local z = 56 - i * 1.4
		box(inside, "Step", 53, 0, z - 1.4, 59.4, i + 1, z, WOOD, Enum.Material.WoodPlanks)
	end
	for z = 6, 54, 8 do
		bookshelf(inside, CFrame.new(76, 19, z) * CFrame.Angles(0, math.pi / 2, 0), 7, 16, seed)
		seed += 2
	end
	local readTable = box(inside, "ReadingTable", 28, 0, 26, 40, 3.2, 34, WOOD, Enum.Material.WoodPlanks)
	prompt(readTable, "book", "")
	bench(inside, CFrame.new(34, 0, 23), 10)
	bench(inside, CFrame.new(34, 0, 37), 10)
	B.points.priest = CFrame.new(40, 4, 48)
	chandelier(inside, Vector3.new(36, 34, 20))
	chandelier(inside, Vector3.new(36, 34, 44))
	window(inside, Vector3.new(79, 24, 30), Vector3.new(1, 0, 0), 5, 12)

	-- ---- казино (восток, z 60..90, первый этаж)
	box(inside, "CasinoCarpet", 13, 0.2, 61, 78, 0.32, 89, rgb(70, 20, 70), Enum.Material.Carpet)
	for i = 0, 3 do
		local x = 22 + i * 12
		local slot = box(inside, "SlotMachine", x - 2, 0, 86, x + 2, 7, 89, rgb(150, 30, 40), Enum.Material.SmoothPlastic)
		box(inside, "SlotScreen", x - 1.4, 3.4, 85.8, x + 1.4, 5.6, 86, rgb(255, 210, 90), Enum.Material.Neon)
		prompt(slot, "slots", "")
	end
	local felt = box(inside, "CoinTable", 30, 0, 68, 46, 3.4, 76, rgb(30, 100, 50), Enum.Material.Fabric)
	box(inside, "TableRim", 29.5, 3.3, 67.5, 46.5, 3.6, 76.5, WOOD_DARK, Enum.Material.Wood)
	prompt(felt, "coin", "")
	chandelier(inside, Vector3.new(45, 16, 75))

	-- ---- тронный зал z 90..147, высота 36
	wallX(inside, 90, -40, 40, 0, 37, { { 0, 16, 16 } }, 2)
	floorWithHole("ThroneFloor", -40, 40, 91, 147, 0.2, 0.3, -3, 3, 139, 145, rgb(140, 132, 120), Enum.Material.Marble)
	carpet(inside, -3, 90, 3, 133, 0.32)
	for _, x in { -30, 30 } do
		for z = 98, 140, 10 do
			pillar(inside, x, z, 0, 36, 1.6)
		end
		for z = 100, 140, 14 do
			banner(inside, Vector3.new(x * 1.28, 30, z), Vector3.new(-math.sign(x), 0, 0), 14)
		end
	end
	wallZ(inside, -40, 90, 147, 0, 60, nil, 2)
	wallZ(inside, 40, 90, 147, 0, 60, nil, 2)
	box(inside, "ThroneCeiling", -40, 36, 90, 40, 37, 147, STONE_DARK)
	for z = 100, 140, 20 do
		chandelier(inside, Vector3.new(0, 30, z))
		window(inside, Vector3.new(-41.6, 22, z), Vector3.new(-1, 0, 0), 5, 12)
		window(inside, Vector3.new(41.6, 22, z), Vector3.new(1, 0, 0), 5, 12)
	end
	-- помост с люком под троном
	floorWithHole("Dais", -12, 12, 132, 147, 0, 1.5, -3, 3, 139, 145, rgb(150, 30, 40), Enum.Material.Fabric)
	floorWithHole("DaisStep", -9, 9, 134, 147, 1.5, 3, -3, 3, 139, 145, rgb(140, 132, 120), Enum.Material.Marble)
	local hatch = box(inside, "Hatch", -3, 0, 139, 3, 3.02, 145, rgb(140, 132, 120), Enum.Material.Marble)
	B.hatch = hatch
	local throne = Instance.new("Model")
	throne.Name = "Throne"
	local seat = Instance.new("Seat")
	seat.Name = "ThroneSeat"
	seat.Anchored = true
	seat.Size = Vector3.new(4, 1, 4)
	seat.CFrame = CFrame.new(0, 4.5, 140)
	seat.Color = rgb(150, 20, 30)
	seat.Material = Enum.Material.Fabric
	seat.Disabled = true
	seat.Parent = throne
	part(throne, { Name = "ThroneBase", Size = Vector3.new(5, 1.5, 5), CFrame = CFrame.new(0, 3.75, 140), Color = GOLD, Material = Enum.Material.Metal })
	part(throne, { Name = "ThroneBack", Size = Vector3.new(5, 10, 1), CFrame = CFrame.new(0, 9.5, 142.4), Color = GOLD, Material = Enum.Material.Metal })
	part(throne, { Name = "ThroneCushion", Size = Vector3.new(4, 7, 0.4), CFrame = CFrame.new(0, 9, 141.8), Color = rgb(150, 20, 30), Material = Enum.Material.Fabric })
	for _, x in { -2.6, 2.6 } do
		part(throne, { Name = "Arm", Size = Vector3.new(0.8, 2.5, 4.4), CFrame = CFrame.new(x, 5.6, 140), Color = GOLD, Material = Enum.Material.Metal })
	end
	part(throne, { Name = "Crest", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(0, 15, 142.4), Color = GOLD, Material = Enum.Material.Neon })
	throne.PrimaryPart = seat
	throne.Parent = inside
	prompt(seat, "throne", "", 1, 10)
	prompt(throne:FindFirstChild("ThroneBack") :: BasePart, "passage", "", 1.5, 10)
	B.throne = throne
	B.throneSeat = seat
	B.throneHome = throne:GetPivot()
	B.points.statueLeft = CFrame.new(-18, 1.5, 136)
	B.points.statueRight = CFrame.new(18, 1.5, 136)
	for _, x in { -18, 18 } do
		box(inside, "StatueBase", x - 4, 0, 132, x + 4, 1.5, 140, rgb(170, 165, 158), Enum.Material.Marble)
	end
	B.points.throneRoom = CFrame.new(0, 3, 105)

	-- ---- тайный ход: шахта с лестницей под троном, туннель под стеной и рвом на запад,
	-- рычаг внизу возвращает трон на место, выход в поле за рвом
	local secret = Instance.new("Model")
	secret.Name = "SecretPassage"
	local D = -27
	terrain:FillBlock(CFrame.new(0, D / 2, 142), Vector3.new(6, -D + 1, 6), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(-66, D + 5, 142), Vector3.new(140, 10, 6), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(-132, D / 2, 142), Vector3.new(6, -D + 2, 6), Enum.Material.Air)
	local function shaft(x)
		box(secret, "ShaftWall", x - 4, D, 138, x + 4, 0, 139, STONE_DARK, Enum.Material.Slate)
		box(secret, "ShaftWall", x - 4, D, 145, x + 4, 0, 146, STONE_DARK, Enum.Material.Slate)
		box(secret, "ShaftWall", x + 3, D, 139, x + 4, 0, 145, STONE_DARK, Enum.Material.Slate)
		local t = Instance.new("TrussPart")
		t.Name = "Ladder"
		t.Anchored = true
		t.Size = Vector3.new(2, 30, 2)
		t.CFrame = CFrame.new(x + 1.9, D + 15, 142)
		t.Color = WOOD_DARK
		t.Material = Enum.Material.Wood
		t.Parent = secret
	end
	shaft(0)
	box(secret, "ShaftWall", -4, D, 139, -3, D + 10, 145, STONE_DARK, Enum.Material.Slate)
	box(secret, "ShaftWall", -4, D + 10, 139, -3, 0, 145, STONE_DARK, Enum.Material.Slate)
	shaft(-132)
	box(secret, "ShaftWall", -136, D, 139, -135, 0, 145, STONE_DARK, Enum.Material.Slate)
	box(secret, "TunnelFloor", -136, D - 1, 138, 4, D, 146, STONE_DARK, Enum.Material.Cobblestone)
	box(secret, "TunnelCeiling", -131, D + 10, 138, -4, D + 11, 146, STONE_DARK, Enum.Material.Slate)
	box(secret, "TunnelWall", -132, D, 138, -3, D + 10, 139, STONE_DARK, Enum.Material.Slate)
	box(secret, "TunnelWall", -132, D, 145, -3, D + 10, 146, STONE_DARK, Enum.Material.Slate)
	box(secret, "TunnelWater", -131, D, 140.5, -4, D + 0.3, 143.5, rgb(60, 70, 50), Enum.Material.Glass, { Transparency = 0.4, CanCollide = false })
	for x = -20, -120, -25 do
		torch(secret, Vector3.new(x, D + 6, 144.6), Vector3.new(0, 0, -1))
	end
	local lever = box(secret, "Lever", 2.2, D + 3, 139.2, 2.8, D + 5.5, 139.8, rgb(60, 56, 52), Enum.Material.Metal)
	prompt(lever, "lever", "", 0.5)
	-- выход: каменный колодец с решёткой в поле за рвом
	for _, w in { { -137, -136, 137, 147 }, { -128, -127, 137, 147 }, { -137, -127, 137, 138 }, { -137, -127, 146, 147 } } do
		box(secret, "ExitWell", w[1], -1, w[3], w[2], 2.5, w[4], STONE_DARK, Enum.Material.Cobblestone)
	end
	secret.Parent = inside
	B.points.tunnel = CFrame.new(-20, D + 3, 142)
	B.points.tunnelExit = CFrame.new(-132, 4, 152)

	-- ---- второй этаж: покои прислуги, казарма, магазин; покои короля
	local y2 = FH + 1
	wallX(inside, 30, -78, -12, y2, FH - 1, { { -40, 8, 10 } }, 2)
	wallX(inside, 60, -78, -12, y2, FH - 1, { { -40, 8, 10 } }, 2)
	for i = 0, 3 do
		bed(inside, CFrame.new(-72, y2, -10 + i * 10) * CFrame.Angles(0, -math.pi / 2, 0), Color3.fromHSV(i * 0.17, 0.4, 0.75))
		bed(inside, CFrame.new(-30, y2, -10 + i * 10) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromHSV(0.5 + i * 0.1, 0.4, 0.75))
	end
	local brooms = box(inside, "BroomRack", -56, y2, 27, -50, y2 + 6, 28.8, WOOD_DARK, Enum.Material.Wood)
	prompt(brooms, "broom", "")
	chandelier(inside, Vector3.new(-45, y2 + 15, 5))
	window(inside, Vector3.new(-79, y2 + 9, 10), Vector3.new(-1, 0, 0))
	-- казарма z 30..60: оружие, кандалы, тренировочный манекен
	local rack = box(inside, "WeaponRack", -76, y2, 34, -74, y2 + 7, 46, WOOD_DARK, Enum.Material.Wood)
	for k = 0, 4 do
		part(inside, { Name = "RackSword", Size = Vector3.new(0.3, 5, 0.8), CFrame = CFrame.new(-73.6, y2 + 3.5, 35.5 + k * 2.3), Color = rgb(190, 190, 200), Material = Enum.Material.Metal, CanCollide = false })
	end
	prompt(rack, "sword", "")
	local cuffs = box(inside, "ShacklesHook", -76, y2, 50, -74, y2 + 5, 54, rgb(60, 56, 52), Enum.Material.Metal)
	prompt(cuffs, "cuffs", "")
	B.points.dummy = CFrame.new(-45, y2 + 3, 46)
	chandelier(inside, Vector3.new(-45, y2 + 15, 45))
	window(inside, Vector3.new(-79, y2 + 9, 45), Vector3.new(-1, 0, 0))
	-- магазин z 60..90
	local shopCounter = box(inside, "ShopCounter", -60, y2, 66, -30, y2 + 3.4, 70, WOOD, Enum.Material.WoodPlanks)
	prompt(shopCounter, "shop", "", 0, 12)
	for x = -70, -24, 8 do
		box(inside, "ShopShelf", x, y2, 86, x + 6, y2 + 8, 88, WOOD_DARK, Enum.Material.Wood)
		part(inside, { Name = "Goods", Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(x + 3, y2 + 5, 87), Color = Color3.fromHSV((x + 70) / 60, 0.6, 0.85), Material = Enum.Material.Fabric })
	end
	chandelier(inside, Vector3.new(-45, y2 + 15, 75))
	window(inside, Vector3.new(-79, y2 + 9, 75), Vector3.new(-1, 0, 0))
	-- покои короля
	bed(inside, CFrame.new(70, y2, -10) * CFrame.Angles(0, math.pi / 2, 0), rgb(150, 20, 30))
	carpet(inside, 44, -18, 60, -4, y2)
	local stand = box(inside, "ScepterStand", 50, y2, -28, 52, y2 + 4, -26, GOLD, Enum.Material.Metal)
	part(inside, { Name = "ScepterShow", Size = Vector3.new(0.3, 3, 0.3), CFrame = CFrame.new(51, y2 + 5.5, -27), Color = GOLD, Material = Enum.Material.Metal, CanCollide = false })
	prompt(stand, "scepter", "")
	local wardrobe = box(inside, "Wardrobe", 20, y2, -6, 24, y2 + 9, -1.2, WOOD_DARK, Enum.Material.Wood)
	prompt(wardrobe, "shop", "", 0, 10)
	chandelier(inside, Vector3.new(55, y2 + 15, -12))

	-- ---- темница под двором (вход по лестнице в западной части двора)
	local dungeon = Instance.new("Model")
	dungeon.Name = "Dungeon"
	terrain:FillBlock(CFrame.new(-55, -10.5, -90), Vector3.new(46, 21, 92), Enum.Material.Air)
	box(dungeon, "DungeonFloor", -78, -21, -136, -32, -20, -44, STONE_DARK, Enum.Material.Cobblestone)
	floorWithHole("DungeonCeiling", -78, -32, -136, -44, -1, 0, -46, -38, -70, -44, STONE_DARK, Enum.Material.Slate)
	for _, d in inside:GetChildren() do
		if d.Name == "DungeonCeiling" then
			d.Parent = dungeon
		end
	end
	box(dungeon, "DungeonWall", -79, -21, -137, -78, 0, -43, STONE_DARK, Enum.Material.Slate)
	box(dungeon, "DungeonWall", -32, -21, -137, -31, 0, -43, STONE_DARK, Enum.Material.Slate)
	box(dungeon, "DungeonWall", -79, -21, -137, -31, 0, -136, STONE_DARK, Enum.Material.Slate)
	box(dungeon, "DungeonWall", -79, -21, -44, -46, 0, -43, STONE_DARK, Enum.Material.Slate)
	box(dungeon, "DungeonWall", -38, -21, -44, -31, 0, -43, STONE_DARK, Enum.Material.Slate)
	for i = 0, 19 do
		local z = -44 - i * 1.3
		box(dungeon, "DungeonStep", -46, -20, z - 1.3, -38, -i - 1, z, STONE_DARK, Enum.Material.Slate)
	end
	-- перила вокруг проёма во дворе
	box(yard, "HoleRail", -46.6, 0, -70.6, -46, 3.2, -44, WOOD_DARK, Enum.Material.Wood)
	box(yard, "HoleRail", -38, 0, -70.6, -37.4, 3.2, -44, WOOD_DARK, Enum.Material.Wood)
	box(yard, "HoleRail", -46.6, 0, -71.2, -37.4, 3.2, -70.6, WOOD_DARK, Enum.Material.Wood)
	B.cells = {}
	for i = 0, 4 do
		local z = -135 + i * 13
		box(dungeon, "CellWall", -78, -20, z + 12, -60, -1, z + 13, STONE_DARK, Enum.Material.Slate)
		local bars = Instance.new("Model")
		bars.Name = "CellBars" .. (i + 1)
		for k = 0, 5 do
			part(bars, { Name = "Bar", Size = Vector3.new(0.4, 19, 0.4), CFrame = CFrame.new(-60, -10.5, z + 1 + k * 2), Color = rgb(50, 48, 46), Material = Enum.Material.Metal })
		end
		bars.Parent = dungeon
		local lock = part(dungeon, { Name = "CellLock", Size = Vector3.new(0.6, 1, 0.6), CFrame = CFrame.new(-59.5, -17, z + 6), Color = rgb(80, 70, 50), Material = Enum.Material.Metal })
		prompt(lock, "cell", "", 1)
		lock:SetAttribute("Cell", i + 1)
		table.insert(B.cells, { bars = bars, inside = CFrame.new(-70, -17, z + 6), lock = lock })
		torch(dungeon, Vector3.new(-33, -10, z + 6), Vector3.new(-1, 0, 0))
		part(dungeon, { Name = "Chain", Size = Vector3.new(0.2, 4, 0.2), CFrame = CFrame.new(-77.5, -13, z + 6), Color = rgb(60, 58, 56), Material = Enum.Material.Metal, CanCollide = false })
		part(dungeon, { Name = "Straw", Size = Vector3.new(5, 0.4, 4), CFrame = CFrame.new(-72, -19.8, z + 6), Color = rgb(190, 160, 90), Material = Enum.Material.Grass, CanCollide = false })
	end
	dungeon.Parent = root
	B.points.dungeon = CFrame.new(-45, -17, -100)
	outer.Parent = root
	inside.Parent = root
	yard.Parent = root

	-- атмосфера: тёплый полумрак, как в хоррор-играх, но без страха
	Lighting.Ambient = rgb(52, 46, 42)
	Lighting.OutdoorAmbient = rgb(110, 105, 100)
	Lighting.Brightness = 1.6
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	local cc = Lighting:FindFirstChild("CastleColor") or Instance.new("ColorCorrectionEffect")
	cc.Name = "CastleColor"
	cc.TintColor = rgb(255, 238, 220)
	cc.Contrast = 0.08
	cc.Saturation = 0.05
	cc.Parent = Lighting
	local bloom = Lighting:FindFirstChild("CastleBloom") or Instance.new("BloomEffect")
	bloom.Name = "CastleBloom"
	bloom.Intensity = 0.5
	bloom.Size = 30
	bloom.Threshold = 1.4
	bloom.Parent = Lighting
	return B
end

return B
