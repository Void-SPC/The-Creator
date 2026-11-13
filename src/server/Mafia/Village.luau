--!nonstrict
-- Деревня для «Мафии»: настоящий рельеф Roblox (песок, трава, снег, вода), 13 домиков
-- по кругу дверями к центру, стол для обсуждения, деревья и оформление сезона
-- Стили: summer (песок и море), spring (трава, деревья, озеро), autumn (непроходимый лес),
-- winter (снег). Темы: winter — newyear | plain, autumn — halloween | plain,
-- spring — april | plain (в обычной весне четыре статуи держат купол), summer — plain

local Lighting = game:GetService("Lighting")

local Statue = require(script.Parent.Parent.Statue)

local Village = {}

Village.ORIGIN = Vector3.new(0, 0, 9000)
Village.HOUSES = 13
Village.RING = 64
Village.STATUE_USER = "Nataliaavira13"

local V = Village.ORIGIN
local terrain = workspace.Terrain

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function part(parent: Instance, props): BasePart
	local cls = props.Class or "Part"
	local p = Instance.new(cls)
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

local function rnd(seed: number)
	local s = seed
	return function(a: number, b: number): number
		s = (s * 1103515245 + 12345) % 2147483648
		return a + (b - a) * ((s // 65536) % 10000) / 10000
	end
end

-- ---------------------------------------------------------------------------
-- деревья

local function deciduous(parent, pos: Vector3, h: number, leaf: Color3, r)
	local m = Instance.new("Model")
	m.Name = "Tree"
	part(m, { Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1.4, 1.4), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(95, 68, 45), Material = Enum.Material.Wood })
	for i = 1, 4 do
		local d = r(5, 8)
		local off = Vector3.new(r(-2.2, 2.2), h + r(-1, 2.2), r(-2.2, 2.2))
		part(m, { Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), CFrame = CFrame.new(pos + off), Color = leaf:Lerp(rgb(0, 0, 0), r(0, 0.18)), Material = Enum.Material.LeafyGrass, CanCollide = i == 1 })
	end
	m.Parent = parent
	return m
end

local function pine(parent, pos: Vector3, h: number, snowy: boolean, r)
	local m = Instance.new("Model")
	m.Name = "Pine"
	part(m, { Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h * 0.35, 1.1, 1.1), CFrame = CFrame.new(pos + Vector3.new(0, h * 0.175, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(85, 60, 40), Material = Enum.Material.Wood })
	local tiers = 5
	for i = 0, tiers - 1 do
		local w = (1 - i / tiers) * h * 0.55 + 1
		local y = h * 0.25 + i * h * 0.15
		part(m, { Name = "Needles", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h * 0.16, w, w), CFrame = CFrame.new(pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(35, 85, 50), Material = Enum.Material.Grass, CanCollide = i == 0 })
		if snowy then
			part(m, { Name = "Snow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, w * 0.8, w * 0.8), CFrame = CFrame.new(pos + Vector3.new(0, y + h * 0.08, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(245, 248, 255), Material = Enum.Material.Snow, CanCollide = false })
		end
	end
	m.Parent = parent
	return m
end

local function palm(parent, pos: Vector3, h: number, r)
	local m = Instance.new("Model")
	m.Name = "Palm"
	local lean = r(-0.25, 0.25)
	local top = pos
	local seg = h / 5
	for i = 1, 5 do
		local a = lean * i / 5
		local cf = CFrame.new(top) * CFrame.Angles(a, 0, a * 0.6) * CFrame.new(0, seg / 2, 0)
		part(m, { Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(seg + 0.2, 1.1 - i * 0.08, 1.1 - i * 0.08), CFrame = cf * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(150, 115, 75), Material = Enum.Material.Wood })
		top = (cf * CFrame.new(0, seg / 2, 0)).Position
	end
	for k = 0, 6 do
		local yaw = k / 7 * math.pi * 2
		local leaf = CFrame.new(top) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-0.45, 0, 0) * CFrame.new(0, 0, -3.2)
		part(m, { Name = "Leaf", Size = Vector3.new(1.6, 0.2, 6.5), CFrame = leaf, Color = rgb(60, 140, 60), Material = Enum.Material.LeafyGrass, CanCollide = false })
	end
	for k = 0, 2 do
		part(m, { Name = "Coconut", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = CFrame.new(top + Vector3.new(math.cos(k * 2.1) * 0.7, -0.6, math.sin(k * 2.1) * 0.7)), Color = rgb(90, 60, 35), CanCollide = false })
	end
	m.Parent = parent
	return m
end

local function pumpkin(parent, cf: CFrame, s: number)
	local m = Instance.new("Model")
	m.Name = "Pumpkin"
	part(m, { Name = "Body", Size = Vector3.new(2.2, 1.6, 2.2) * s, CFrame = cf, Color = rgb(230, 120, 25), Material = Enum.Material.SmoothPlastic, Sphere = true })
	part(m, { Name = "Stem", Size = Vector3.new(0.25, 0.6, 0.25) * s, CFrame = cf * CFrame.new(0, 0.95 * s, 0), Color = rgb(70, 110, 40) })
	for _, x in { -0.45, 0.45 } do
		part(m, { Name = "Eye", Size = Vector3.new(0.35, 0.35, 0.1) * s, CFrame = cf * CFrame.new(x * s, 0.2 * s, -1.05 * s), Color = rgb(255, 210, 80), Material = Enum.Material.Neon, CanCollide = false })
	end
	part(m, { Name = "Mouth", Size = Vector3.new(1, 0.22, 0.1) * s, CFrame = cf * CFrame.new(0, -0.3 * s, -1.05 * s), Color = rgb(255, 210, 80), Material = Enum.Material.Neon, CanCollide = false })
	local l = Instance.new("PointLight")
	l.Color = rgb(255, 160, 60)
	l.Range = 10
	l.Brightness = 1.5
	l.Parent = m:FindFirstChild("Body")
	m.Parent = parent
end

-- ---------------------------------------------------------------------------
-- стили

local STYLES = {
	summer = {
		ground = Enum.Material.Sand, groundColor = rgb(232, 214, 160), path = Enum.Material.Sandstone,
		wall = rgb(245, 236, 215), wallMat = Enum.Material.WoodPlanks, roof = rgb(205, 175, 95), roofMat = Enum.Material.Fabric,
		clock = 14, ambient = rgb(140, 130, 120), weather = "Clear",
	},
	spring = {
		ground = Enum.Material.Grass, groundColor = rgb(92, 160, 70), path = Enum.Material.Cobblestone,
		wall = rgb(240, 236, 228), wallMat = Enum.Material.Plaster, roof = rgb(175, 80, 60), roofMat = Enum.Material.ClayRoofTiles,
		clock = 13, ambient = rgb(120, 130, 120), weather = "Clear",
	},
	autumn = {
		ground = Enum.Material.Grass, groundColor = rgb(160, 120, 55), path = Enum.Material.Ground,
		wall = rgb(120, 85, 58), wallMat = Enum.Material.WoodPlanks, roof = rgb(75, 62, 60), roofMat = Enum.Material.RoofShingles,
		clock = 16.5, ambient = rgb(130, 110, 95), weather = "Clear",
	},
	winter = {
		ground = Enum.Material.Snow, groundColor = rgb(240, 244, 250), path = Enum.Material.Pavement,
		wall = rgb(150, 105, 72), wallMat = Enum.Material.WoodPlanks, roof = rgb(245, 248, 255), roofMat = Enum.Material.Snow,
		clock = 12, ambient = rgb(140, 145, 160), weather = "Snow",
	},
}
Village.STYLES = STYLES

-- ---------------------------------------------------------------------------
-- дом: стены, окна, двускатная крыша, дверь к центру, номер, кровать, фонарь

local function house(parent, cf: CFrame, index: number, st, theme: string, r)
	local m = Instance.new("Model")
	m.Name = "House" .. index
	local wall = st.wall
	if theme == "april" then
		wall = Color3.fromHSV((index * 0.137) % 1, 0.45, 1)
	end
	local W, D, H = 14, 12, 8
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	part(m, { Name = "Floor", Size = Vector3.new(W, 0.6, D), CFrame = at(0, 0.3, 0), Color = rgb(120, 86, 60), Material = Enum.Material.WoodPlanks })
	part(m, { Name = "Wall", Size = Vector3.new(W, H, 0.6), CFrame = at(0, H / 2, D / 2), Color = wall, Material = st.wallMat })
	part(m, { Name = "Wall", Size = Vector3.new(0.6, H, D), CFrame = at(-W / 2, H / 2, 0), Color = wall, Material = st.wallMat })
	part(m, { Name = "Wall", Size = Vector3.new(0.6, H, D), CFrame = at(W / 2, H / 2, 0), Color = wall, Material = st.wallMat })
	-- передняя стена с проёмом под дверь
	part(m, { Name = "Wall", Size = Vector3.new(5.3, H, 0.6), CFrame = at(-4.35, H / 2, -D / 2), Color = wall, Material = st.wallMat })
	part(m, { Name = "Wall", Size = Vector3.new(5.3, H, 0.6), CFrame = at(4.35, H / 2, -D / 2), Color = wall, Material = st.wallMat })
	part(m, { Name = "Wall", Size = Vector3.new(3.4, 1.5, 0.6), CFrame = at(0, H - 0.75, -D / 2), Color = wall, Material = st.wallMat })
	-- угловые брусья
	for _, x in { -W / 2, W / 2 } do
		for _, z in { -D / 2, D / 2 } do
			part(m, { Name = "Beam", Size = Vector3.new(0.9, H, 0.9), CFrame = at(x, H / 2, z), Color = rgb(90, 64, 44), Material = Enum.Material.Wood })
		end
	end
	-- окна: рама и стекло, ночью светятся изнутри
	local function window(x, y, z, yaw)
		local wcf = at(x, y, z) * CFrame.Angles(0, yaw, 0)
		part(m, { Name = "Frame", Size = Vector3.new(2.6, 2.4, 0.25), CFrame = wcf, Color = rgb(70, 50, 35), Material = Enum.Material.Wood, CanCollide = false })
		local g = part(m, { Name = "Window", Size = Vector3.new(2.1, 1.9, 0.3), CFrame = wcf, Color = rgb(255, 214, 140), Material = Enum.Material.Glass, Transparency = 0.25, CanCollide = false })
		g:SetAttribute("NightGlow", true)
		part(m, { Name = "Mullion", Size = Vector3.new(0.12, 1.9, 0.34), CFrame = wcf, Color = rgb(70, 50, 35), CanCollide = false })
	end
	window(-4.35, 4.6, -D / 2 - 0.3, 0)
	window(4.35, 4.6, -D / 2 - 0.3, 0)
	window(-W / 2 - 0.3, 4.6, 0, math.pi / 2)
	window(W / 2 + 0.3, 4.6, 0, math.pi / 2)
	-- двускатная крыша из клиньев: конёк вдоль дома
	local RH = 4.6
	for _, s in { -1, 1 } do
		local roof = part(m, {
			Class = "WedgePart", Name = "Roof", Size = Vector3.new(W + 1.6, RH, D / 2 + 1),
			CFrame = at(0, H + RH / 2, s * (D / 4 + 0.5)) * CFrame.Angles(0, if s > 0 then math.pi else 0, 0),
			Color = st.roof, Material = st.roofMat,
		})
		roof:SetAttribute("Roof", true)
	end
	local chimney = part(m, { Name = "Chimney", Size = Vector3.new(1.4, 4, 1.4), CFrame = at(W / 2 - 3, H + RH - 0.5, D / 4), Color = rgb(140, 70, 55), Material = Enum.Material.Brick })
	chimney:SetAttribute("Roof", true)
	-- дверь на петлях, открывается кнопкой
	local door = part(m, { Name = "Door", Size = Vector3.new(3.2, 6.4, 0.3), CFrame = at(0, 3.5, -D / 2), Color = rgb(110, 70, 45), Material = Enum.Material.Wood })
	part(m, { Name = "Handle", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3), CFrame = at(1.1, 3.4, -D / 2 - 0.25), Color = rgb(200, 170, 80), Material = Enum.Material.Metal, CanCollide = false })
	-- номер дома (имена игроков скрыты)
	local plate = part(m, { Name = "Plate", Size = Vector3.new(1.6, 1, 0.15), CFrame = at(0, H - 0.75, -D / 2 - 0.4), Color = rgb(40, 40, 46), CanCollide = false })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.PixelsPerStud = 60
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = tostring(index)
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = rgb(240, 225, 190)
	t.Parent = sg
	sg.Parent = plate
	-- фонарь у двери и свет в доме
	local lamp = part(m, { Name = "Lantern", Size = Vector3.new(0.6, 0.9, 0.6), CFrame = at(2.4, 5.6, -D / 2 - 0.5), Color = rgb(255, 210, 140), Material = Enum.Material.Neon, CanCollide = false })
	local ll = Instance.new("PointLight")
	ll.Range = 14
	ll.Brightness = 1.4
	ll.Color = rgb(255, 200, 130)
	ll.Parent = lamp
	local inside = part(m, { Name = "Inside", Size = Vector3.new(0.2, 0.2, 0.2), CFrame = at(0, H - 1, 0), Transparency = 1, CanCollide = false })
	local il = Instance.new("PointLight")
	il.Range = 16
	il.Brightness = 1.2
	il.Color = rgb(255, 210, 150)
	il.Parent = inside
	-- кровать и тумбочка
	part(m, { Name = "Bed", Size = Vector3.new(4, 1, 6.5), CFrame = at(-4, 1.1, 2), Color = rgb(90, 60, 40), Material = Enum.Material.Wood })
	part(m, { Name = "Mattress", Size = Vector3.new(3.7, 0.6, 6.2), CFrame = at(-4, 1.9, 2), Color = rgb(235, 235, 240), Material = Enum.Material.Fabric })
	part(m, { Name = "Blanket", Size = Vector3.new(3.8, 0.3, 4), CFrame = at(-4, 2.25, 1), Color = Color3.fromHSV((index * 0.21) % 1, 0.5, 0.8), Material = Enum.Material.Fabric })
	part(m, { Name = "Table", Size = Vector3.new(3, 0.3, 2), CFrame = at(4, 2.8, 3.5), Color = rgb(110, 80, 55), Material = Enum.Material.Wood })
	-- украшения тем
	if theme == "newyear" then
		for k = 0, 10 do
			local x = -W / 2 - 0.4 + k * (W + 0.8) / 10
			local bulb = part(m, { Name = "Garland", Shape = Enum.PartType.Ball, Size = Vector3.new(0.45, 0.45, 0.45), CFrame = at(x, H + 0.1, -D / 2 - 1.05), Color = ({ rgb(255, 60, 60), rgb(60, 220, 90), rgb(70, 140, 255), rgb(255, 210, 60) })[k % 4 + 1], Material = Enum.Material.Neon, CanCollide = false })
			bulb:SetAttribute("Roof", true)
		end
	elseif theme == "halloween" then
		pumpkin(m, at(-2.5, 1.2, -D / 2 - 1.6), 0.9)
	elseif theme == "april" then
		for k = 0, 2 do
			local b = part(m, { Name = "Balloon", Size = Vector3.new(1.4, 1.8, 1.4), CFrame = at(-2 + k * 2, H + 6 + k * 0.6, -D / 2 - 1.2), Color = Color3.fromHSV(r(0, 1), 0.8, 1), Material = Enum.Material.SmoothPlastic, Sphere = true, CanCollide = false })
			b:SetAttribute("Roof", true)
			part(m, { Name = "String", Size = Vector3.new(0.05, 5.5, 0.05), CFrame = at(-2 + k * 2, H + 2.5 + k * 0.3, -D / 2 - 1.2), Color = rgb(250, 250, 250), CanCollide = false })
		end
	end
	m.Parent = parent
	return {
		model = m,
		door = door,
		doorClosed = door.CFrame,
		hinge = at(-1.6, 3.5, -D / 2),
		inside = at(0, 3, -1) * CFrame.Angles(0, math.pi, 0),
		porch = at(0, 3, -D / 2 - 4),
	}
end

-- ---------------------------------------------------------------------------
-- рельеф

local function clear()
	terrain:FillBlock(CFrame.new(V + Vector3.new(0, 30, 0)), Vector3.new(620, 140, 620), Enum.Material.Air)
end

local function ground(st, style: string, theme: string)
	terrain:SetMaterialColor(Enum.Material.Grass, st.groundColor)
	terrain:SetMaterialColor(Enum.Material.Sand, rgb(232, 214, 160))
	if style == "summer" then
		-- море вокруг песчаного острова
		terrain:FillBlock(CFrame.new(V + Vector3.new(0, -9, 0)), Vector3.new(600, 16, 600), Enum.Material.Water)
		terrain:FillCylinder(CFrame.new(V + Vector3.new(0, -6, 0)), 12, 168, Enum.Material.Sand)
		terrain:FillCylinder(CFrame.new(V + Vector3.new(0, -4, 0)), 8, 150, Enum.Material.Sand)
	else
		terrain:FillCylinder(CFrame.new(V + Vector3.new(0, -5, 0)), 10, 290, st.ground)
		if style == "spring" then
			terrain:FillCylinder(CFrame.new(V + Vector3.new(0, -0.6, 0)), 1.2, 175, Enum.Material.LeafyGrass)
			terrain:FillCylinder(CFrame.new(V + Vector3.new(0, -0.5, 0)), 1.2, 120, Enum.Material.Grass)
			-- озеро за деревней
			local lake = V + Vector3.new(118, 0, -88)
			terrain:FillCylinder(CFrame.new(lake + Vector3.new(0, -0.4, 0)), 1.2, 34, Enum.Material.Sand)
			terrain:FillCylinder(CFrame.new(lake + Vector3.new(0, 0, 0)), 9, 30, Enum.Material.Air)
			terrain:FillCylinder(CFrame.new(lake + Vector3.new(0, -2.8, 0)), 3.6, 30, Enum.Material.Water)
		elseif style == "winter" then
			-- замёрзший пруд
			local pond = V + Vector3.new(-100, 0, 70)
			terrain:FillCylinder(CFrame.new(pond + Vector3.new(0, -0.3, 0)), 1, 22, Enum.Material.Ice)
		elseif style == "autumn" then
			terrain:FillCylinder(CFrame.new(V + Vector3.new(0, -0.5, 0)), 1.2, 260, Enum.Material.Ground)
			terrain:FillCylinder(CFrame.new(V + Vector3.new(0, -0.45, 0)), 1.2, 95, Enum.Material.Grass)
			terrain:SetMaterialColor(Enum.Material.Ground, rgb(120, 85, 50))
		end
	end
	-- дорожки от центра к домам
	for i = 0, Village.HOUSES - 1 do
		local a = i / Village.HOUSES * math.pi * 2
		local dir = Vector3.new(math.sin(a), 0, math.cos(a))
		local mid = V + dir * (Village.RING / 2 + 6)
		terrain:FillBlock(CFrame.lookAt(mid + Vector3.new(0, -0.35, 0), mid + dir + Vector3.new(0, -0.35, 0)), Vector3.new(4, 1, Village.RING - 20), st.path)
	end
	terrain:FillCylinder(CFrame.new(V + Vector3.new(0, -0.35, 0)), 1, 17, st.path)
	local _ = theme
end

-- невидимая стена по кругу, чтобы не уйти с карты
local function barrier(parent, radius: number, height: number)
	local n = 36
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local p = V + Vector3.new(math.sin(a) * radius, height / 2, math.cos(a) * radius)
		local w = 2 * math.pi * radius / n + 2
		part(parent, { Name = "Barrier", Size = Vector3.new(w, height, 2), CFrame = CFrame.lookAt(p, Vector3.new(V.X, p.Y, V.Z)), Transparency = 1, CanQuery = false })
	end
end

-- ---------------------------------------------------------------------------
-- сборка

-- Возвращает описание мира для игры: дома, места у стола, лобби, небо для призраков
function Village.build(style: string, theme: string)
	local st = STYLES[style] or STYLES.spring
	local old = workspace:FindFirstChild("MafiaVillage")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "MafiaVillage"
	folder.Parent = workspace
	local r = rnd(1234)
	clear()
	ground(st, style, theme)

	-- центр: круглый стол и 13 табуретов
	local center = Instance.new("Model")
	center.Name = "Center"
	part(center, { Name = "Table", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 14, 14), CFrame = CFrame.new(V + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(115, 80, 52), Material = Enum.Material.WoodPlanks })
	part(center, { Name = "Leg", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 2.4, 2.4), CFrame = CFrame.new(V + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(90, 64, 44), Material = Enum.Material.Wood })
	local candle = part(center, { Name = "Candle", Size = Vector3.new(0.6, 1.2, 0.6), CFrame = CFrame.new(V + Vector3.new(0, 4.1, 0)), Color = rgb(255, 200, 120), Material = Enum.Material.Neon })
	local cl = Instance.new("PointLight")
	cl.Range = 22
	cl.Brightness = 2
	cl.Color = rgb(255, 190, 120)
	cl.Parent = candle
	local seats = {}
	for i = 0, Village.HOUSES - 1 do
		local a = i / Village.HOUSES * math.pi * 2
		local p = V + Vector3.new(math.sin(a) * 10, 0, math.cos(a) * 10)
		part(center, { Name = "Stool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 2.2, 2.2), CFrame = CFrame.new(p + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(125, 90, 60), Material = Enum.Material.Wood })
		seats[i + 1] = CFrame.lookAt(p + Vector3.new(0, 4, 0) + (p - V).Unit * 1.6, Vector3.new(V.X, p.Y + 4, V.Z))
	end
	center.Parent = folder

	-- дома по кругу, дверью к центру
	local houses = {}
	for i = 0, Village.HOUSES - 1 do
		local a = i / Village.HOUSES * math.pi * 2
		local p = V + Vector3.new(math.sin(a) * Village.RING, 0, math.cos(a) * Village.RING)
		local cf = CFrame.lookAt(p, Vector3.new(V.X, 0, V.Z))
		houses[i + 1] = house(folder, cf, i + 1, st, theme, r)
	end

	-- деревья и украшения
	local deco = Instance.new("Folder")
	deco.Name = "Nature"
	deco.Parent = folder
	local function ringPos(radius: number, a: number)
		return V + Vector3.new(math.sin(a) * radius, 0, math.cos(a) * radius)
	end
	if style == "summer" then
		for i = 0, 33 do
			local a = i / 34 * math.pi * 2 + r(-0.05, 0.05)
			palm(deco, ringPos(r(96, 138), a), r(14, 20), r)
		end
		-- лодка у берега и зонтики
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2 + 0.3
			local p = ringPos(118, a)
			part(deco, { Name = "Umbrella", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 7, 7), CFrame = CFrame.new(p + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = ({ rgb(230, 70, 70), rgb(70, 150, 230), rgb(250, 210, 60) })[i % 3 + 1], Material = Enum.Material.Fabric })
			part(deco, { Name = "Pole", Size = Vector3.new(0.25, 5, 0.25), CFrame = CFrame.new(p + Vector3.new(0, 2.5, 0)), Color = rgb(240, 240, 240) })
			part(deco, { Name = "Towel", Size = Vector3.new(2.4, 0.1, 5), CFrame = CFrame.new(p + Vector3.new(2.5, 0.1, 0)) * CFrame.Angles(0, a, 0), Color = Color3.fromHSV(i / 6, 0.5, 0.95), Material = Enum.Material.Fabric, CanCollide = false })
		end
		barrier(folder, 175, 60)
	elseif style == "spring" then
		for i = 0, 23 do
			local a = i / 24 * math.pi * 2 + r(-0.1, 0.1)
			deciduous(deco, ringPos(r(90, 160), a), r(9, 13), rgb(70, 150, 60), r)
		end
		-- цветы
		for _ = 1, 140 do
			local a = r(0, math.pi * 2)
			local p = ringPos(r(22, 150), a)
			if (p - V).Magnitude < 52 or (p - V).Magnitude > 78 then
				part(deco, { Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = CFrame.new(p + Vector3.new(0, 0.5, 0)), Color = Color3.fromHSV(r(0, 1), 0.65, 1), CanCollide = false })
			end
		end
		if theme == "april" then
			local c = part(folder, { Name = "Confetti", Size = Vector3.new(60, 1, 60), CFrame = CFrame.new(V + Vector3.new(0, 40, 0)), Transparency = 1, CanCollide = false, CanQuery = false })
			local e = Instance.new("ParticleEmitter")
			e.Rate = 40
			e.Speed = NumberRange.new(4, 8)
			e.EmissionDirection = Enum.NormalId.Bottom
			e.Lifetime = NumberRange.new(6, 9)
			e.Size = NumberSequence.new(0.35)
			e.Rotation = NumberRange.new(0, 360)
			e.RotSpeed = NumberRange.new(-180, 180)
			e.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(255, 80, 80)), ColorSequenceKeypoint.new(0.33, rgb(80, 220, 120)), ColorSequenceKeypoint.new(0.66, rgb(80, 140, 255)), ColorSequenceKeypoint.new(1, rgb(255, 220, 60)) })
			e.Parent = c
			barrier(folder, 175, 60)
		end
	elseif style == "autumn" then
		-- густой лес, через который не пройти
		local leaves = { rgb(210, 110, 40), rgb(190, 60, 40), rgb(225, 170, 50), rgb(150, 90, 40) }
		local n = 0
		for ring = 0, 4 do
			local radius = 100 + ring * 14
			local count = 34 + ring * 6
			for i = 0, count - 1 do
				n += 1
				local a = (i + ring * 0.5) / count * math.pi * 2 + r(-0.03, 0.03)
				deciduous(deco, ringPos(radius + r(-3, 3), a), r(11, 16), leaves[n % 4 + 1], r)
			end
		end
		barrier(folder, 98, 60)
		if theme == "halloween" then
			for i = 0, 11 do
				local a = i / 12 * math.pi * 2 + 0.13
				pumpkin(deco, CFrame.lookAt(ringPos(30, a) + Vector3.new(0, 1, 0), V + Vector3.new(0, 1, 0)), 1.3)
			end
		end
	elseif style == "winter" then
		for i = 0, 29 do
			local a = i / 30 * math.pi * 2 + r(-0.08, 0.08)
			pine(deco, ringPos(r(92, 150), a), r(14, 22), true, r)
		end
		if theme == "newyear" then
			-- нарядная ёлка у центра
			local treePos = V + Vector3.new(0, 0, -24)
			local t = pine(deco, treePos, 26, true, r)
			for k = 0, 40 do
				local h = 5 + k * 0.45
				local w = (1 - (h - 4) / 22) * 8
				local a = k * 2.4
				local ball = part(t, { Name = "Ornament", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), CFrame = CFrame.new(treePos + Vector3.new(math.sin(a) * w, h, math.cos(a) * w)), Color = ({ rgb(255, 60, 60), rgb(255, 215, 60), rgb(70, 140, 255), rgb(240, 240, 255) })[k % 4 + 1], Material = Enum.Material.Neon, CanCollide = false })
				local _ = ball
			end
			local star = part(t, { Name = "Star", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), CFrame = CFrame.new(treePos + Vector3.new(0, 27.5, 0)), Color = rgb(255, 220, 80), Material = Enum.Material.Neon, CanCollide = false })
			local sl = Instance.new("PointLight")
			sl.Range = 30
			sl.Brightness = 2
			sl.Color = rgb(255, 220, 120)
			sl.Parent = star
			for k = 0, 5 do
				local a = k / 6 * math.pi * 2
				local g = treePos + Vector3.new(math.sin(a) * 5, 0.8, math.cos(a) * 5)
				part(deco, { Name = "Gift", Size = Vector3.new(1.6, 1.4, 1.6), CFrame = CFrame.new(g) * CFrame.Angles(0, a, 0), Color = Color3.fromHSV(k / 6, 0.7, 0.9) })
				part(deco, { Name = "Ribbon", Size = Vector3.new(1.7, 1.45, 0.3), CFrame = CFrame.new(g) * CFrame.Angles(0, a, 0), Color = rgb(250, 230, 120), CanCollide = false })
			end
		end
		barrier(folder, 160, 60)
	end

	-- статуи Натальи: в три раза больше обычного роста
	local statues = Instance.new("Folder")
	statues.Name = "Statues"
	statues.Parent = folder
	local domeMode = style == "spring" and theme == "plain"
	local lobbyCF
	local function pedestal(cf: CFrame)
		local stone = rgb(200, 198, 194)
		part(statues, { Name = "Step", Size = Vector3.new(16, 1.2, 16), CFrame = cf * CFrame.new(0, 0.6, 0), Color = stone, Material = Enum.Material.Marble })
		part(statues, { Name = "Step", Size = Vector3.new(12.5, 1.2, 12.5), CFrame = cf * CFrame.new(0, 1.8, 0), Color = stone, Material = Enum.Material.Marble })
		part(statues, { Name = "Plinth", Size = Vector3.new(9, 3, 9), CFrame = cf * CFrame.new(0, 3.9, 0), Color = stone, Material = Enum.Material.Marble })
		part(statues, { Name = "Cornice", Size = Vector3.new(10, 0.6, 10), CFrame = cf * CFrame.new(0, 5.7, 0), Color = stone, Material = Enum.Material.Marble })
		return cf * CFrame.new(0, 6, 0)
	end
	local beamAnchor
	if domeMode then
		-- четыре статуи по сторонам света, сферы светятся и лучами держат купол
		local apex = part(folder, { Name = "DomeApex", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(V + Vector3.new(0, 95, 0)), Transparency = 1, CanCollide = false, CanQuery = false })
		beamAnchor = Instance.new("Attachment")
		beamAnchor.Parent = apex
		local dome = part(folder, { Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(212, 212, 212), CFrame = CFrame.new(V), Color = rgb(150, 200, 255), Material = Enum.Material.ForceField, Transparency = 0.2, CanCollide = false, CanQuery = false, CastShadow = false })
		local _ = dome
		barrier(folder, 102, 110)
		local colors = { rgb(60, 130, 255), rgb(150, 70, 230), rgb(60, 220, 110), Color3.new(0, 0, 0) }
		for k = 0, 3 do
			local a = k * math.pi / 2
			local p = V + Vector3.new(math.sin(a) * 86, 0, math.cos(a) * 86)
			local face = CFrame.lookAt(p, p + (p - V))
			local top = pedestal(face)
			local color = colors[k + 1]
			task.spawn(function()
				local model = Statue.spawn(Village.STATUE_USER, "admire", true, top, statues, { scale = 3, orbColor = color })
				local orb = model and model:FindFirstChild("Orb")
				if orb and beamAnchor then
					local a0 = Instance.new("Attachment")
					a0.Parent = orb
					local beam = Instance.new("Beam")
					beam.Attachment0 = a0
					beam.Attachment1 = beamAnchor
					beam.Color = ColorSequence.new(if color == Color3.new(0, 0, 0) then rgb(90, 40, 140) else color)
					beam.LightEmission = 1
					beam.Width0 = 2
					beam.Width1 = 0.6
					beam.FaceCamera = true
					beam.Transparency = NumberSequence.new(0.15)
					beam.Parent = orb
				end
			end)
			if k == 0 then
				lobbyCF = face * CFrame.new(0, 0, -30)
			end
		end
	else
		-- одна статуя у центра, не мешая столу
		local p = V + Vector3.new(0, 0, if style == "winter" and theme == "newyear" then 30 else -30)
		local face = CFrame.lookAt(p, Vector3.new(V.X, 0, V.Z))
		local top = pedestal(face)
		task.spawn(function()
			Statue.spawn(Village.STATUE_USER, "admire", true, top, statues, { scale = 3 })
		end)
		lobbyCF = CFrame.lookAt(V + Vector3.new(0, 0, (p - V).Z * -0.1), p)
	end

	-- лобби: стеклянная комната перед статуей, где все ждут начала
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	local function lobbyPart(props)
		props.Parent = nil
		local pp = part(lobby, props)
		pp:SetAttribute("Lobby", true)
		return pp
	end
	lobbyPart({ Name = "Floor", Size = Vector3.new(34, 0.6, 26), CFrame = lobbyCF * CFrame.new(0, 0.3, 0), Color = rgb(225, 225, 230), Material = Enum.Material.Marble })
	for _, s in { { 0, 13, 34, 0.6 }, { 0, -13, 34, 0.6 }, { 17, 0, 0.6, 26 }, { -17, 0, 0.6, 26 } } do
		lobbyPart({ Name = "Glass", Size = Vector3.new(s[3], 12, s[4]), CFrame = lobbyCF * CFrame.new(s[1], 6, s[2]), Color = rgb(200, 230, 255), Material = Enum.Material.Glass, Transparency = 0.6 })
	end
	lobbyPart({ Name = "Roof", Size = Vector3.new(34, 0.6, 26), CFrame = lobbyCF * CFrame.new(0, 12.3, 0), Color = rgb(200, 230, 255), Material = Enum.Material.Glass, Transparency = 0.7 })
	lobby.Parent = folder

	-- освещение сезона
	Lighting.ClockTime = st.clock
	Lighting.Ambient = st.ambient
	Lighting.FogEnd = if style == "autumn" then 420 else 2000
	Lighting.FogColor = if theme == "halloween" then rgb(60, 40, 80) else rgb(190, 200, 210)
	if theme == "halloween" then
		Lighting.Ambient = rgb(90, 70, 110)
	end

	return {
		folder = folder,
		houses = houses,
		seats = seats,
		lobby = lobbyCF * CFrame.new(0, 3, 0),
		lobbyModel = lobby,
		sky = CFrame.new(V + Vector3.new(0, 150, 0)),
		center = V,
		weather = st.weather,
		style = style,
		theme = theme,
	}
end

-- дверь дома: открыть или закрыть
function Village.setDoor(h, open: boolean)
	local hinge = h.hinge
	local rel = hinge:ToObjectSpace(h.doorClosed)
	h.door.CFrame = if open then hinge * CFrame.Angles(0, math.rad(-100), 0) * rel else h.doorClosed
	h.door.CanCollide = not open
end

return Village
