--!nonstrict
-- Особые места музея: улица перед входом (лобби), Монетчик, зал с фигурками и тебЯ,
-- зал кодового замка, арена Колосса с зеркалами, лифт и лестница обслуживания,
-- заброшенный зал в конце локации

local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local M = require(Shared.Materials)
local Rules = require(Shared.Rules)
local Props = require(script.Parent.Props)
local Builder = require(script.Parent.RoomBuilder)

local P, C, S, nc, rgb = Props.P, Props.C, Props.S, Props.nc, Props.rgb
local at = Builder.at

local Special = {}

local function ghost(extra)
	local t = { Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false }
	for k, v in extra or {} do
		t[k] = v
	end
	return t
end

-- каркас особого зала: стены, пол, потолок, общие поля
local function begin(parent, d, origin: CFrame, rand, prev, tweak)
	local m = Props.model(parent, string.format("Room_%03d", d.door))
	local info = { desc = d, model = m, origin = origin, hideSpots = {}, searchables = {}, tops = {}, lights = {} }
	d.decoys = d.decoys or {}
	d.exitHole = d.exitHole or Props.DOORS[d.exitSize or "normal"]
	d.entry = d.entry or Props.DOORS[d.entrySize or "normal"]
	info.top = math.max(0, d.dy) + d.h
	Props.LIGHT = d.light or 1
	local st = Builder.style(d, rand)
	if tweak then
		tweak(st)
	end
	local sh = Builder.shell(m, d, origin, st, Builder.prevWallFor(prev, origin))
	for k, v in sh do
		info[k] = v
	end
	info.style = st
	info.center = at(origin, 0, info.top / 2, -d.l / 2)
	info.size = Vector3.new(d.w, info.top - info.ybase, d.l)
	info.path = { at(origin, 0, 5, -2).Position, at(origin, 0, d.dy + 5, -d.l / 2).Position, (info.exitCF * CFrame.new(0, 5, 2.5)).Position }
	return m, info, st
end

local function lamp(info, m, pos: Vector3)
	local _, bulb = Props.ceilingLamp(m, pos)
	table.insert(info.lights, bulb)
end

local function chandelier(info, m, pos: Vector3, drop: number)
	local _, core = Props.chandelier(m, pos, drop)
	table.insert(info.lights, core)
end

local function surfaceText(part: BasePart, face: Enum.NormalId, text: string, key: string?, color: Color3?, pps: number?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps or 30
	gui.Parent = part
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.Antique
	t.TextScaled = true
	t.TextColor3 = color or rgb(226, 210, 170)
	t.Text = text
	if key then
		t:SetAttribute("LangKey", key)
	end
	t.Parent = gui
	return t
end

-- ---------------------------------------------------------------------------
-- Лобби: ночная улица перед большим музеем. Вход — приоткрытые двери во тьму

function Special.lobby(parent)
	local m = Props.model(parent, "Lobby")
	local stone = rgb(150, 146, 138)
	local cobble = rgb(110, 106, 100)
	local rnd = Random.new(7)
	-- земля и тропинка — рельеф Roblox: трава с шевелящимися травинками, плавные
	-- повороты тропы без швов. Если рельеф недоступен, земля из обычной детали
	local terrain = nil
	pcall(function()
		local t = workspace.Terrain
		t:FillBlock(CFrame.new(20, -4, -170), Vector3.new(420, 8, 640), Enum.Material.Grass)
		pcall(function()
			(t :: any).Decoration = true
		end)
		terrain = t
	end)
	if not terrain then
		P(m, "Ground", Vector3.new(420, 1, 640), CFrame.new(20, -0.5, -170), rgb(34, 52, 36), M.Grass)
		P(m, "Path", Vector3.new(14, 0.2, 86), CFrame.new(0, 0.1, -11), cobble, M.Cobblestone)
	end
	-- крыльцо с пологими ступенями (по ним идут без прыжка)
	P(m, "Porch", Vector3.new(46, 1.6, 22), CFrame.new(0, 0.8, -71), stone, M.Marble)
	for k = 0, 3 do
		P(m, "Stair", Vector3.new(40, 0.4 * (k + 1), 1.5), CFrame.new(0, 0.2 * (k + 1), -54.75 - k * 1.5), stone:Lerp(rgb(0, 0, 0), 0.1), M.Marble, nc())
	end
	local rampLen = math.sqrt(6 * 6 + 1.6 * 1.6)
	P(m, "StairRamp", Vector3.new(40, 0.4, rampLen), CFrame.new(0, 0.6, -57) * CFrame.Angles(math.atan2(1.6, 6), 0, 0), stone, M.Marble, { Transparency = 1, CastShadow = false })
	-- большой фасад с проёмом, колоннами и фронтоном, за ним — корпус музея
	Props.wall(m, CFrame.new(0, 1.6, -76), 130, 0, 44, 4, { { x = 0, w = 10, y = 0, h = 14 } }, rgb(128, 124, 116), M.Limestone, "Facade")
	P(m, "FacadeBase", Vector3.new(130, 1.6, 4), CFrame.new(0, 0.8, -76.01), rgb(100, 96, 90), M.Limestone)
	P(m, "MuseumBody", Vector3.new(126, 42, 60), CFrame.new(0, 22.6, -120), rgb(112, 108, 100), M.Limestone)
	P(m, "MuseumRoof", Vector3.new(132, 2, 76), CFrame.new(0, 44.6, -114), rgb(70, 66, 62), M.Slate)
	for _, sx in { -1, 1 } do
		P(m, "MuseumSide", Vector3.new(2, 42, 12), CFrame.new(sx * 62, 22.6, -84), rgb(112, 108, 100), M.Limestone)
		-- боковые крылья
		P(m, "Wing", Vector3.new(30, 28, 50), CFrame.new(sx * 80, 14, -112), rgb(120, 116, 108), M.Limestone)
		P(m, "WingRoof", Vector3.new(32, 1.6, 52), CFrame.new(sx * 80, 28.8, -112), rgb(70, 66, 62), M.Slate)
		for k = 0, 2 do
			P(m, "WingWindow", Vector3.new(5, 9, 0.2), CFrame.new(sx * (70 + k * 10), 13, -86.9), rgb(8, 10, 14), M.Glass, nc({ Reflectance = 0.2 }))
		end
	end
	P(m, "Dome", Vector3.new(30, 30, 30), CFrame.new(0, 46, -122), rgb(96, 110, 104), M.Slate, { Shape = Enum.PartType.Ball })
	for _, x in { -20, -13, -6, 6, 13, 20 } do
		C(m, "Column", 26, 3, CFrame.new(x, 14.6, -63), rgb(200, 196, 186), M.Marble)
		P(m, "ColumnBase", Vector3.new(3.8, 0.8, 3.8), CFrame.new(x, 2, -63), stone, M.Marble)
		P(m, "ColumnCap", Vector3.new(3.8, 0.8, 3.8), CFrame.new(x, 27.2, -63), stone, M.Marble)
	end
	P(m, "Entablature", Vector3.new(48, 3.4, 16), CFrame.new(0, 29.3, -68), stone, M.Marble)
	for k = 0, 4 do
		P(m, "Pediment", Vector3.new(46 - k * 9, 1.6, 15), CFrame.new(0, 31.8 + k * 1.6, -68), rgb(170, 166, 158), M.Marble, nc())
	end
	local sign = P(m, "Sign", Vector3.new(22, 2.4, 0.3), CFrame.new(0, 29.3, -59.84), rgb(60, 56, 52), M.Slate, nc())
	surfaceText(sign, Enum.NormalId.Back, "MUSEUM", "MuseumSign", rgb(214, 190, 130), 20)
	-- приоткрытые двери, за ними тьма; войти — кнопкой у порога
	local floorIn = P(m, "Threshold", Vector3.new(12, 1.6, 8), CFrame.new(0, 0.8, -86), rgb(20, 20, 20), M.Slate)
	local _ = floorIn
	for _, s in { -1, 1 } do
		P(m, "DoorLeaf", Vector3.new(5, 13.8, 0.4), CFrame.new(s * 5, 8.5, -74) * CFrame.Angles(0, s * math.rad(62), 0) * CFrame.new(-s * 2.5, 0, 0), rgb(52, 34, 24), M.WoodPlanks)
		P(m, "DarkSide", Vector3.new(1, 16, 9), CFrame.new(s * 6.5, 9.6, -82.5), rgb(0, 0, 0), M.SmoothPlastic)
	end
	P(m, "Dark", Vector3.new(14, 16, 1), CFrame.new(0, 9.6, -87.5), rgb(0, 0, 0), M.SmoothPlastic)
	P(m, "DarkTop", Vector3.new(14, 1, 10), CFrame.new(0, 17.5, -83), rgb(0, 0, 0), M.SmoothPlastic, nc())
	local zone = P(m, "EnterZone", Vector3.new(9, 12, 6), CFrame.new(0, 7.6, -82), rgb(0, 0, 0), M.SmoothPlastic, ghost())
	local enter = P(m, "EnterDoor", Vector3.new(8, 8, 1), CFrame.new(0, 6, -76.5), rgb(0, 0, 0), M.SmoothPlastic, ghost())
	local enterPrompt = Props.prompt(enter, "enter", 0.6, 10)
	-- тёмные окна фасада
	for _, x in { -52, -38, 38, 52 } do
		P(m, "Window", Vector3.new(6, 12, 0.2), CFrame.new(x, 16, -73.88), rgb(8, 10, 14), M.Glass, nc({ Reflectance = 0.2 }))
		P(m, "WindowSill", Vector3.new(7.4, 0.6, 1), CFrame.new(x, 9.7, -73.6), stone, M.Marble, nc())
		P(m, "WindowHead", Vector3.new(7.4, 0.8, 0.8), CFrame.new(x, 22.4, -73.7), stone, M.Marble, nc())
	end
	-- клумбы у крыльца
	for _, sx in { -1, 1 } do
		P(m, "FlowerBed", Vector3.new(12, 0.8, 5), CFrame.new(sx * 16, 0.4, -50), stone, M.Marble)
		P(m, "Soil", Vector3.new(11, 0.2, 4), CFrame.new(sx * 16, 0.85, -50), rgb(60, 40, 28), M.Ground, nc())
		for k = 0, 6 do
			S(m, "Flower", 0.7, CFrame.new(sx * 16 - 4.5 + k * 1.5, 1.3, -50 + (k % 2) - 0.5), ({ rgb(190, 60, 70), rgb(220, 200, 90), rgb(200, 120, 180) })[k % 3 + 1], M.SmoothPlastic, nc())
		end
	end

	-- длинная извилистая тропа через деревья ко второму входу ----------------------
	local trail = { { 7, 8 }, { 22, 14 }, { 36, 6 }, { 44, -10 }, { 60, -18 }, { 76, -8 }, { 92, -16 }, { 100, -34 }, { 112, -46 }, { 129, -50 } }
	local function nearTrail(x: number, z: number, r: number): boolean
		for i = 1, #trail - 1 do
			local a, b = trail[i], trail[i + 1]
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local t = math.clamp(((x - a[1]) * dx + (z - a[2]) * dz) / (dx * dx + dz * dz), 0, 1)
			local px, pz = a[1] + dx * t - x, a[2] + dz * t - z
			if px * px + pz * pz < r * r then
				return true
			end
		end
		return false
	end
	for i = 1, #trail - 1 do
		local a = Vector3.new(trail[i][1], 0, trail[i][2])
		local b = Vector3.new(trail[i + 1][1], 0, trail[i + 1][2])
		local len = (b - a).Magnitude
		if terrain then
			-- камень тропы утоплен в землю; на поворотах — круглые площадки
			terrain:FillBlock(CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -2, 0), Vector3.new(6, 4, len + 2), Enum.Material.Cobblestone)
			terrain:FillCylinder(CFrame.new(a + Vector3.new(0, -2, 0)), 4, 3.6, Enum.Material.Cobblestone)
		else
			P(m, "Trail", Vector3.new(6, 0.2, len), CFrame.lookAt((a + b) / 2 + Vector3.new(0, 0.1, 0), b + Vector3.new(0, 0.1, 0)), cobble:Lerp(rgb(80, 70, 56), 0.3), M.Cobblestone, nc())
		end
		-- бордюрные камни вдоль тропы
		local dir = (b - a).Unit
		local side = Vector3.new(-dir.Z, 0, dir.X)
		for k = 1, math.floor(len / 4) do
			local pnt = a + dir * (k * 4 - 1)
			for _, sg in { -1, 1 } do
				P(m, "Curb", Vector3.new(0.7, 0.35, 1.2), CFrame.lookAt(pnt + side * sg * 3.4 + Vector3.new(0, 0.12, 0), pnt + side * sg * 3.4 + dir + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, (k % 3) * 0.08, 0), rgb(120, 116, 108):Lerp(rgb(90, 88, 84), (k % 2) * 0.5), M.Slate, nc())
			end
		end
		if i % 2 == 0 then
			Props.lampPost(m, CFrame.new(a + side * 4.8))
		end
	end
	if terrain then
		local last = trail[#trail]
		terrain:FillCylinder(CFrame.new(last[1], -2, last[2]), 4, 3.6, Enum.Material.Cobblestone)
		-- главная дорожка и площадка у крыльца тоже из камня
		terrain:FillBlock(CFrame.new(0, -2, -11), Vector3.new(14, 4, 86), Enum.Material.Pavement)
	end

	-- бесконечный фасад: одно и то же крыло повторяется и уходит вдаль --------------
	local FX = 134
	local endless = Props.model(m, "EndlessWing")
	local wallC, trim = rgb(118, 114, 108), rgb(150, 146, 138)
	local MOD = 12
	for k = 0, 40 do
		local z = 60 - k * MOD
		local cz = z - MOD / 2
		local isDoor = math.abs(cz - (-50)) < MOD / 2
		local front = FX - 2
		if isDoor then
			Props.wall(endless, CFrame.new(FX, 0, cz) * CFrame.Angles(0, math.pi / 2, 0), MOD, 0, 30, 4, { { x = 0, w = 6, y = 0, h = 9 } }, wallC, M.Limestone, "EndlessWall")
		else
			P(endless, "EndlessWall", Vector3.new(4, 30, MOD), CFrame.new(FX, 15, cz), wallC, M.Limestone)
			P(endless, "EndlessWindow", Vector3.new(0.2, 10, 5), CFrame.new(front - 0.08, 13, cz), rgb(10, 12, 16), M.Glass, nc({ Reflectance = 0.15 }))
			P(endless, "EndlessSill", Vector3.new(1, 0.5, 6), CFrame.new(front - 0.4, 7.8, cz), trim, M.Marble, nc())
		end
		C(endless, "EndlessColumn", 28, 2.4, CFrame.new(front - 1.4, 14, z), rgb(196, 192, 182), M.Marble)
		P(endless, "EndlessCornice", Vector3.new(3, 1.4, MOD), CFrame.new(front - 0.5, 30.4, cz), trim, M.Marble, nc())
		P(endless, "EndlessRoof", Vector3.new(16, 1.4, MOD), CFrame.new(FX + 6, 31.2, cz), rgb(70, 66, 62), M.Slate, nc())
	end
	-- заколоченная дверь и вывеска «скоро»
	P(endless, "EndlessDoor", Vector3.new(0.4, 9, 6), CFrame.new(FX + 1.5, 4.5, -50), rgb(30, 22, 18), M.WoodPlanks, nc())
	for k = -1, 1 do
		P(endless, "Board", Vector3.new(0.3, 0.9, 8), CFrame.new(FX - 2.3, 4.6 + k * 2.4, -50) * CFrame.Angles(k * 0.25, 0, 0), rgb(96, 70, 44), M.WoodPlanks, nc())
	end
	local soon = P(endless, "SoonSign", Vector3.new(0.3, 4, 16), CFrame.new(FX - 2.3, 13, -50), rgb(40, 30, 24), M.Wood, nc())
	surfaceText(soon, Enum.NormalId.Left, "", "EndlessSoon", rgb(226, 200, 140), 20)

	-- доска достижений у дорожки
	local board = P(m, "AchBoard", Vector3.new(0.4, 5, 7), CFrame.new(-11.5, 3.6, 16), rgb(56, 40, 28), M.Wood)
	for _, dz in { -3, 3 } do
		P(m, "AchPost", Vector3.new(0.5, 6.2, 0.5), CFrame.new(-11.5, 3.1, 16 + dz), rgb(46, 32, 22), M.Wood, nc())
	end
	surfaceText(board, Enum.NormalId.Right, "", "Achievements", rgb(230, 196, 120), 30)
	local achPrompt = Props.prompt(board, "ach", 0, 9)

	-- фонари вдоль главной дорожки, скамейки
	for _, z in { 24, 4, -16, -40 } do
		Props.lampPost(m, CFrame.new(-9.5, 0, z))
		Props.lampPost(m, CFrame.new(9.5, 0, z))
	end
	Props.bench(m, CFrame.new(-8.5, 0, -6) * CFrame.Angles(0, -math.pi / 2, 0), 7)
	Props.bench(m, CFrame.new(8.5, 0, -26) * CFrame.Angles(0, math.pi / 2, 0), 7)

	-- деревья разных размеров, кусты и трава — вразброс, но не на дорожках -------------
	local function free(x: number, z: number, r: number): boolean
		if math.abs(x) < 12 + r and z > -60 and z < 40 then
			return false -- главная дорожка
		end
		if z < -44 - r and math.abs(x) < 98 then
			return false -- крыльцо и корпус
		end
		if x > FX - 8 - r then
			return false -- бесконечное крыло
		end
		if nearTrail(x, z, 5 + r) then
			return false
		end
		if math.abs(x + 11.5) < 3 + r and math.abs(z - 16) < 6 + r then
			return false -- доска
		end
		return true
	end
	local k = 0
	local tries = 0
	while k < 120 and tries < 2000 do
		tries += 1
		local x, z = rnd:NextNumber(-104, 128), rnd:NextNumber(-126, 58)
		if free(x, z, 3) then
			k += 1
			Props.tree(m, CFrame.new(x, 0, z) * CFrame.Angles(0, rnd:NextNumber(0, 6.28), 0), rnd:NextInteger(8, 24), k)
		end
	end
	local bushes = 0
	tries = 0
	while bushes < 70 and tries < 2000 do
		tries += 1
		local x, z = rnd:NextNumber(-100, 126), rnd:NextNumber(-120, 56)
		if free(x, z, 1) then
			bushes += 1
			local g = rgb(30, 64, 34):Lerp(rgb(48, 84, 40), rnd:NextNumber())
			local s1 = rnd:NextNumber(2.4, 4.2)
			S(m, "Bush", s1, CFrame.new(x, s1 * 0.3, z), g, M.Grass, nc())
			S(m, "Bush", s1 * 0.7, CFrame.new(x + s1 * 0.4, s1 * 0.22, z - s1 * 0.2), g, M.Grass, nc())
		end
	end
	-- округа за оградой: тёмные дома, деревья, всё уходит дальше ----------------------
	for i, h in { { -150, 40, 26 }, { -160, -10, 34 }, { -146, -70, 22 }, { -40, 110, 30 }, { 30, 118, 24 }, { 90, 106, 36 } } do
		P(m, "FarHouse", Vector3.new(24, h[3], 20), CFrame.new(h[1], h[3] / 2, h[2]), rgb(52, 50, 54), M.Concrete, nc())
		P(m, "FarRoof", Vector3.new(26, 2, 22), CFrame.new(h[1], h[3] + 1, h[2]), rgb(36, 34, 38), M.Slate, nc())
		P(m, "FarWindow", Vector3.new(3, 4, 0.2), CFrame.new(h[1] + 4, h[3] * 0.6, h[2] + (if h[2] > 0 then -10.05 else 10.05)), rgb(255, 196, 120), M.Neon, nc({ Transparency = if i % 2 == 0 then 0.2 else 0.7 }))
	end
	for i = 1, 30 do
		local a = rnd:NextNumber(0, math.pi * 2)
		local r = rnd:NextNumber(130, 175)
		local x, z = math.cos(a) * r + 10, math.sin(a) * r - 30
		if x < FX - 10 then
			Props.tree(m, CFrame.new(x, 0, z), rnd:NextInteger(14, 26), 200 + i)
		end
	end
	-- невидимая ограда вокруг улицы
	for _, w in { { 10, 62, 244, 2 }, { -110, -20, 2, 166 }, { -86, -102, 50, 2 }, { 96, -130, 72, 2 }, { 131, 60, 2, 6 } } do
		P(m, "Fence", Vector3.new(w[3], 60, w[4]), CFrame.new(w[1], 30, w[2]), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CastShadow = false })
	end
	return { model = m, zone = zone, enter = enterPrompt, ach = achPrompt, spawn = CFrame.new(0, 3.2, 28) }
end

-- ---------------------------------------------------------------------------
-- Монетчик: золотая монета с усами. Стоит перед дверью; рядом в стене его норка

function Special.coinKeeper(parent, cf: CFrame, price: number, holeCF: CFrame)
	-- небольшая золотая монета на тонких ножках: без глаз, с пышными усами и тростью,
	-- которую он никогда не выпускает; держится строго и почти не двигается
	local m = Props.model(parent, "CoinKeeper")
	local gold, dark = rgb(222, 180, 66), rgb(160, 120, 36)
	local face = cf * CFrame.new(0, 2.75, 0)
	local flatR = CFrame.Angles(math.pi / 2, 0, 0)
	C(m, "Rim", 0.4, 2.9, face * flatR, dark, M.Metal)
	C(m, "Face", 0.56, 2.5, face * flatR, gold, M.Metal, nc())
	for k = 0, 15 do
		P(m, "Mill", Vector3.new(0.2, 0.24, 0.34), face * CFrame.Angles(0, 0, k * math.pi / 8) * CFrame.new(0, 1.46, 0), dark, M.Metal, nc())
	end
	-- выпуклый профиль носа и усы — единственное «лицо»
	P(m, "Nose", Vector3.new(0.3, 0.6, 0.2), face * CFrame.new(0, 0.2, -0.36), dark, M.Metal, nc())
	for _, x in { -1, 1 } do
		local a = (face * CFrame.new(x * 0.12, -0.2, -0.36)).Position
		local b = (face * CFrame.new(x * 0.8, -0.38, -0.38)).Position
		local c = (face * CFrame.new(x * 1.2, -0.05, -0.38)).Position
		Props.rod(m, "Moustache", a, b, 0.26, rgb(36, 24, 14), M.SmoothPlastic, nc())
		Props.rod(m, "Moustache", b, c, 0.18, rgb(36, 24, 14), M.SmoothPlastic, nc())
		S(m, "Curl", 0.24, CFrame.new(c), rgb(36, 24, 14), M.SmoothPlastic, nc())
		local hip = (face * CFrame.new(x * 0.55, -1.3, 0)).Position
		local foot = (face * CFrame.new(x * 0.6, -2.45, 0)).Position
		Props.rod(m, "Leg", hip, foot, 0.16, dark, M.Metal, nc())
		P(m, "Shoe", Vector3.new(0.42, 0.24, 0.7), CFrame.new(foot) * cf.Rotation * CFrame.new(0, -0.05, -0.15), rgb(28, 20, 14), M.SmoothPlastic, nc())
	end
	-- левая рука упёрта в бок, правая держит трость
	local shL = (face * CFrame.new(-1.45, -0.1, 0)).Position
	local elL = (face * CFrame.new(-1.95, -0.55, -0.1)).Position
	local hdL = (face * CFrame.new(-1.45, -0.95, -0.1)).Position
	Props.rod(m, "Arm", shL, elL, 0.15, dark, M.Metal, nc())
	Props.rod(m, "Arm", elL, hdL, 0.15, dark, M.Metal, nc())
	S(m, "Hand", 0.3, CFrame.new(hdL), gold, M.Metal, nc())
	local shR = (face * CFrame.new(1.45, -0.1, 0)).Position
	local hdR = (face * CFrame.new(1.95, -0.7, -0.5)).Position
	Props.rod(m, "Arm", shR, hdR, 0.15, dark, M.Metal, nc())
	S(m, "Hand", 0.3, CFrame.new(hdR), gold, M.Metal, nc())
	local caneTop = hdR + Vector3.new(0, 0.12, 0)
	local caneFoot = (cf * CFrame.new(2.15, 0.02, -0.65)).Position
	Props.rod(m, "Cane", caneTop, caneFoot, 0.12, rgb(20, 16, 14), M.Wood, nc())
	S(m, "CaneKnob", 0.26, CFrame.new(caneTop + Vector3.new(0, 0.12, 0)), gold, M.Metal, nc())
	C(m, "CaneTip", 0.12, 0.16, CFrame.new(caneFoot + Vector3.new(0, 0.03, 0)), rgb(200, 200, 200), M.Metal, nc())
	local glow = Instance.new("PointLight")
	glow.Range = 12
	glow.Brightness = 0.7
	glow.Color = rgb(255, 200, 90)
	glow.Parent = m:FindFirstChild("Face")
	local talk = P(m, "Talk", Vector3.new(2, 2, 2), face * CFrame.new(0, 0, -1), rgb(0, 0, 0), M.SmoothPlastic, ghost())
	local pr = Props.prompt(talk, "talk", 0, 10)
	pr:SetAttribute("Price", price)
	m.WorldPivot = cf
	CollectionService:AddTag(m, "CoinKeeper")
	-- невидимая стенка: мимо него не пройти (не часть самой монеты, чтобы не ездила)
	local block = P(parent, "CoinBlock", Vector3.new(9, 12, 1.2), cf * CFrame.new(0, 6, 0.9), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CastShadow = false })
	-- норка в стене по его размеру
	local hole = Props.model(parent, "CoinHole")
	-- норка по его росту: человеку туда не пролезть
	P(hole, "Dark", Vector3.new(3.6, 4.4, 0.3), holeCF * CFrame.new(0, 2.2, 0.75), rgb(0, 0, 0), M.SmoothPlastic, nc())
	for _, s in { -1, 1 } do
		P(hole, "Jamb", Vector3.new(0.5, 4.6, 0.5), holeCF * CFrame.new(s * 2.05, 2.3, 0.9), rgb(120, 114, 104), M.Limestone, nc())
	end
	P(hole, "Arch", Vector3.new(5, 0.6, 0.6), holeCF * CFrame.new(0, 4.9, 0.9), rgb(120, 114, 104), M.Limestone, nc())
	P(hole, "Step", Vector3.new(3.8, 0.2, 0.5), holeCF * CFrame.new(0, 0.11, 0.95), rgb(100, 94, 86), M.Limestone, nc())
	return m, pr, block, hole
end

-- ---------------------------------------------------------------------------
-- Зал с фигурками: постаменты по цветам и фигурки, раскиданные по залу

local FIG_COLORS = { rgb(190, 40, 40), rgb(50, 90, 200), rgb(50, 150, 70), rgb(226, 190, 60), rgb(130, 60, 170), rgb(226, 120, 40), rgb(230, 230, 224), rgb(30, 30, 34) }

function Special.figures(info, rand)
	local d, o, m = info.desc, info.origin, info.model
	local n = 4 + math.floor(rand() * 5)
	local puzzle = { sockets = {}, figs = {}, n = n, placed = 0 }
	for k = 1, n do
		local x = (k - (n + 1) / 2) * 4.4
		local pm, top = Props.plinth(m, at(o, x, 0, -30), 1.6, 2.6)
		P(pm, "Mark", Vector3.new(1.3, 0.08, 1.3), top * CFrame.new(0, 0.04, 0), FIG_COLORS[k], M.SmoothPlastic, nc())
		local socket = P(pm, "Socket", Vector3.new(1.6, 1.6, 1.6), top * CFrame.new(0, 0.9, 0), rgb(0, 0, 0), M.SmoothPlastic, ghost({ CanQuery = true }))
		Props.prompt(socket, "place", 0, 7)
		puzzle.sockets[k] = { part = socket, color = k, top = top * CFrame.new(0, 0.08, 0), filled = false }
	end
	local spots = { { -16, -6 }, { 16, -6 }, { -16, -22 }, { 16, -22 }, { -12, -36 }, { 12, -36 }, { -7, -8 }, { 7, -8 } }
	for i = #spots, 2, -1 do
		local j = math.floor(rand() * i) + 1
		spots[i], spots[j] = spots[j], spots[i]
	end
	for k = 1, n do
		local cf = at(o, spots[k][1], 0, spots[k][2])
		local fm = Props.model(m, "Figurine")
		local col = FIG_COLORS[k]
		local root = C(fm, "Fig", 0.3, 1, cf * CFrame.new(0, 0.15, 0), col, M.SmoothPlastic, { CanCollide = false })
		C(fm, "Body", 0.9, 0.6, cf * CFrame.new(0, 0.75, 0), col, M.SmoothPlastic, nc())
		S(fm, "Head", 0.6, cf * CFrame.new(0, 1.45, 0), col, M.SmoothPlastic, nc())
		if k % 2 == 0 then
			P(fm, "Hat", Vector3.new(0.8, 0.12, 0.8), cf * CFrame.new(0, 1.8, 0), col:Lerp(rgb(0, 0, 0), 0.3), M.SmoothPlastic, nc())
		end
		fm.PrimaryPart = root
		Props.prompt(root, "take", 0, 7)
		puzzle.figs[k] = { model = fm, part = root, color = k, home = cf * CFrame.new(0, 0.15, 0) }
	end
	-- круглое основание, на котором стоит статуя
	C(m, "MimicBase", 0.4, 4.4, at(o, 0, 0.2, -20), rgb(150, 146, 138), M.Marble, nc())
	puzzle.mimicCF = at(o, 0, 0.4, -20) * CFrame.Angles(0, math.pi, 0)
	local _ = d
	info.puzzle = puzzle
	return puzzle
end

-- ---------------------------------------------------------------------------
-- Зал кодового замка: вход, два больших крыла налево и направо, запертая дверь по центру

local CODE_RGB = { red = rgb(190, 40, 40), blue = rgb(50, 90, 200), green = rgb(50, 150, 70), yellow = rgb(226, 190, 60) }

local function countShelf(m, cf: CFrame, color: Color3, count: number)
	local sm = Props.model(m, "CountShelf")
	local base = cf * CFrame.new(0, 0, -0.05)
	P(sm, "Shelf", Vector3.new(7, 0.3, 1.3), base * CFrame.new(0, 3.6, -0.65), Props.WOOD_DARK, M.Wood)
	for _, s in { -1, 1 } do
		P(sm, "Bracket", Vector3.new(0.3, 1.2, 1), base * CFrame.new(s * 2.8, 2.85, -0.5), Props.BRASS, M.Metal, nc())
	end
	P(sm, "Banner", Vector3.new(4.6, 3, 0.1), base * CFrame.new(0, 9, -0.05 + 0.3), color, M.Fabric, nc())
	P(sm, "BannerRod", Vector3.new(5.2, 0.2, 0.2), base * CFrame.new(0, 10.6, 0.15), Props.BRASS, M.Metal, nc())
	for k = 1, count do
		local x = (k - (count + 1) / 2) * 1.05
		local top = base * CFrame.new(x, 3.75, -0.65)
		C(sm, "Jar", 0.7, 0.6, top * CFrame.new(0, 0.35, 0), color:Lerp(rgb(255, 255, 255), 0.25), M.SmoothPlastic, nc())
		C(sm, "JarNeck", 0.25, 0.34, top * CFrame.new(0, 0.82, 0), color, M.SmoothPlastic, nc())
	end
	return sm
end

function Special.codeHall(parent, d, origin: CFrame, rand, prev)
	local m, info = begin(parent, d, origin, rand, prev, function(st)
		st.paper = rgb(52, 44, 66)
		st.floor = rgb(196, 190, 180)
		st.floorMat = M.Marble
	end)
	for _, s in { -1, 1 } do
		P(m, "Partition", Vector3.new(1.2, d.h, 27.33), at(origin, s * 14, d.h / 2, -29.665), info.style.paper:Lerp(rgb(0, 0, 0), 0.15), M.Plaster)
		chandelier(info, m, at(origin, s * 26, d.h, -22).Position, 3)
		local _, cavity = Props.locker(m, Builder.slotBack(d, origin, s * 30))
		table.insert(info.hideSpots, cavity)
		Props.statue(m, at(origin, s * 20, 0, -8), if s < 0 then "figure" else "bust", 1)
		Props.bench(m, Builder.spot(d, origin, s * 14.65, -30, if s < 0 then math.pi / 2 else -math.pi / 2), 7)
	end
	chandelier(info, m, at(origin, 0, d.h, -22).Position, 4)
	Props.rug(m, at(origin, 0, 0, -22), 9, 34, rgb(100, 26, 32))
	local code = Rules.code(rand)
	local slots = { Builder.slotL(d, origin, -12), Builder.slotL(d, origin, -32), Builder.slotR(d, origin, -12), Builder.slotR(d, origin, -32) }
	for i, name in Rules.COLORS do
		countShelf(m, slots[i], CODE_RGB[name], code.digits[i])
	end
	-- замок справа от двери: четыре цветных окошка по порядку
	local pcf = Builder.slotFront(d, origin, -8) * CFrame.new(0, 5, 0.1)
	local panel = P(m, "CodePanel", Vector3.new(3.2, 3.6, 0.3), pcf, rgb(36, 36, 40), M.Metal)
	for i, c in code.order do
		P(m, "CodeSlot", Vector3.new(0.5, 0.7, 0.08), pcf * CFrame.new(0.9 - (i - 1) * 0.6, 0.9, -0.17), CODE_RGB[Rules.COLORS[c]], M.Neon, nc())
	end
	for r = 0, 2 do
		for col = 0, 2 do
			P(m, "KeyCap", Vector3.new(0.4, 0.4, 0.08), pcf * CFrame.new(0.5 - col * 0.5, 0 - r * 0.5, -0.17), rgb(90, 90, 96), M.SmoothPlastic, nc())
		end
	end
	Props.prompt(panel, "code", 0, 8)
	-- второй щиток слева от двери: порядок экспонатов
	local ocf = Builder.slotFront(d, origin, 8) * CFrame.new(0, 5, 0.1)
	local orderPanel = P(m, "OrderPanel", Vector3.new(3.2, 3.6, 0.3), ocf, rgb(36, 36, 40), M.Metal)
	for r = 0, 1 do
		for col = 0, 3 do
			P(m, "OrderCap", Vector3.new(0.5, 0.9, 0.08), ocf * CFrame.new(1.05 - col * 0.7, 0.7 - r * 1.3, -0.17), Props.BRASS, M.Metal, nc())
		end
	end
	Props.prompt(orderPanel, "order", 0, 8)
	-- восемь экспонатов с римскими номерами: по четыре в каждом крыле
	local items = table.clone(Props.ODD)
	for i = #items, 2, -1 do
		local j = math.floor(rand() * i) + 1
		items[i], items[j] = items[j], items[i]
	end
	local spots = { { -22, -16 }, { -31, -18 }, { -22, -37 }, { -31, -38 }, { 22, -16 }, { 31, -18 }, { 22, -37 }, { 31, -38 } }
	local exhibits = {}
	for k = 1, 8 do
		local cf = at(origin, spots[k][1], 0, spots[k][2])
		local cm = Props.displayCase(m, cf, items[k])
		for _, face in { -1, 1 } do
			local plate = P(cm, "RomanPlate", Vector3.new(1.3, 0.7, 0.08), cf * CFrame.new(0, 1.5, face * 1.34), Props.BRASS, M.Metal, nc())
			surfaceText(plate, if face < 0 then Enum.NormalId.Front else Enum.NormalId.Back, Rules.ROMAN[code.roman[k]], nil, rgb(36, 26, 14), 60)
		end
		exhibits[k] = items[k]
	end
	-- ключ: одно из четырёх мест, каждый раз другое
	local keySpots = {}
	for _, sx in { -1, 1 } do
		local _, top = Props.plinth(m, at(origin, sx * 26, 0, -26), 2, 3)
		P(m, "Cushion", Vector3.new(1.5, 0.2, 1.5), top * CFrame.new(0, 0.1, 0), rgb(100, 20, 30), M.Fabric, nc())
		table.insert(keySpots, top * CFrame.new(0, 0.2, 0))
		table.insert(keySpots, at(origin, sx * 35.5, 0, -4))
	end
	local _, key = Props.pickup(m, keySpots[math.floor(rand() * #keySpots) + 1], "key")
	key:SetAttribute("KeyFor", d.door + 1)
	info.exhibits = exhibits
	info.orderPanel = orderPanel
	info.locks = { code = false, order = false }
	info.code = code
	info.codePanel = panel
	info.sealed = true
	Props.LIGHT = 1
	return info
end

-- ---------------------------------------------------------------------------
-- Арена Колосса по чертежу: внизу — пол зала, по бокам — галереи второго этажа
-- (вход ведёт прямо на них), в дальнем конце две лестницы вниз. На галереях четыре
-- зеркала, луч приходит из круглого окна в дальней стене. Посередине — большая люстра
-- на лебёдке, в неё нужно поставить зеркальце, тогда луч падает вниз, в круг света.
-- Под левой галереей — холодильная камера с мясом. Выход — дверь с часовым механизмом

local ARENA_GALLERY = 27.2 -- внутренний край галерей

function Special.arena(parent, d, origin: CFrame, rand, prev)
	local m, info = begin(parent, d, origin, rand, prev)
	local A = Rules.ARENA
	local fy = d.dy
	local function L(x: number, y: number, z: number): CFrame
		return at(origin, x, y, z)
	end
	Props.LIGHT = 1.5
	local stone, stoneDark = rgb(150, 144, 136), rgb(104, 100, 94)
	local arena = { mirrors = {}, origin = origin, y = A.y, fy = fy, solved = false, lit = false, meat = nil }
	arena.floorY = L(0, fy, 0).Position.Y
	arena.zone = L(A.lens.x, fy, A.lens.z)

	-- галереи второго этажа (на уровне входа) --------------------------------
	local G0, G1 = ARENA_GALLERY, A.bounds.x
	local gw = G1 - G0
	for _, sx in { -1, 1 } do
		local cx = sx * (G0 + G1) / 2
		P(m, "Gallery", Vector3.new(gw, 1, 103.2 - 12), L(cx, -0.5, -(12 + 103.2) / 2), stone, M.Marble)
		-- под галереей у лестницы входа — сплошная кладка
		P(m, "GalleryBase", Vector3.new(gw, -fy - 1, 16), L(cx, (fy - 1) / 2, -20), stoneDark, M.Slate)
		-- карниз по краю
		P(m, "GalleryEdge", Vector3.new(0.5, 1.4, 103 - 28.4), L(sx * (G0 + 0.24), -0.9, -(28.4 + 103) / 2), stoneDark, M.Marble, nc())
	end
	-- колонны под галереями
	local columns = { [-1] = { -36, -48, -92 }, [1] = { -36, -50, -64, -78, -92 } }
	for sx, zs in columns do
		for _, z in zs do
			Props.pillar(m, L(sx * (G0 + 1.6), fy, z), -fy - 1, rgb(170, 160, 146))
		end
	end
	-- лестницы с галерей вниз в дальнем конце (под ними — невидимый пандус)
	local SZ0, SZ1 = -80, -100
	for _, sx in { -1, 1 } do
		local x0, x1 = sx * (G0 - 6.2), sx * G0
		local cx = (x0 + x1) / 2
		local len = math.abs(SZ1 - SZ0)
		local n = 14
		for k = 0, n - 1 do
			local zTop = SZ0 - k * len / n
			local hgt = -fy * (n - k) / n
			P(m, "Step", Vector3.new(6.1, hgt, len / n), L(cx, fy + hgt / 2, zTop - len / n / 2), stoneDark, M.Marble, nc())
		end
		local slope = math.sqrt(len * len + fy * fy)
		P(m, "Ramp", Vector3.new(6, 0.6, slope), L(cx, fy / 2 - 0.3, (SZ0 + SZ1) / 2) * CFrame.Angles(math.atan2(fy, len), 0, 0), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CastShadow = false })
		Props.rod(m, "Handrail", L(sx * (G0 - 6.3), 3.2, SZ0).Position, L(sx * (G0 - 6.3), fy + 3.2, SZ1).Position, 0.25, Props.WOOD_DARK, M.Wood, nc())
		-- верхняя площадка: с галереи шагаешь на неё, дальше вниз по ступеням
		P(m, "StairLanding", Vector3.new(6.1, 1, 4), L(cx, -0.5, SZ0 + 2), stone, M.Marble)
		P(m, "StairBase", Vector3.new(6.1, -fy - 1, 4), L(cx, (fy - 1) / 2, SZ0 + 2), stoneDark, M.Slate)
		P(m, "LandingRail", Vector3.new(6.1, 0.3, 0.3), L(cx, 3.4, SZ0 + 3.85), Props.WOOD_DARK, M.Wood, nc())
		for _, dx in { -2.9, 0, 2.9 } do
			P(m, "Baluster", Vector3.new(0.3, 3.2, 0.3), L(cx + dx, 1.6, SZ0 + 3.85), stone, M.Marble, nc())
		end
		P(m, "LandingRail", Vector3.new(0.34, 0.36, 3.9), L(sx * (G0 - 6.0), 3.41, SZ0 + 1.95), Props.WOOD_DARK, M.Wood, nc())
		for _, dz in { 0.6, 2, 3.4 } do
			P(m, "Baluster", Vector3.new(0.3, 3.2, 0.3), L(sx * (G0 - 6.0), 1.6, SZ0 + dz), stone, M.Marble, nc())
		end
	end
	-- перила галерей с проходом к лестнице
	for _, sx in { -1, 1 } do
		local x = sx * (G0 + 0.25)
		local runs = { { -12.5, SZ0 + 4.2 }, { SZ0 - 0.2, -103 } }
		for _, r in runs do
			local a, b = r[1], r[2]
			Props.rod(m, "Rail", L(x, 3.4, a).Position, L(x, 3.4, b).Position, 0.3, Props.WOOD_DARK, M.Wood, nc())
			local cnt = math.max(1, math.floor(math.abs(b - a) / 3))
			for k = 0, cnt do
				local z = a + (b - a) * k / cnt
				P(m, "Baluster", Vector3.new(0.3, 3.2, 0.3), L(x, 1.6, z), stone, M.Marble, nc())
			end
		end
	end

	-- свет: зал хорошо освещён, зверя видно издалека --------------------------
	for _, x in { -14, 14 } do
		for _, z in { -38, -94 } do
			chandelier(info, m, L(x, d.h, z).Position, 8)
		end
	end
	for _, z in { -30, -56, -84 } do
		for _, sx in { -1, 1 } do
			local slot = if sx < 0 then Builder.slotL else Builder.slotR
			local _, shade = Props.sconce(m, slot(d, origin, z) * CFrame.new(0, 6, Builder.F - 0.6))
			table.insert(info.lights, shade)
		end
	end

	-- окно-источник: круглое окно в дальней стене над левой галереей ------------
	local src = L(A.source.x, A.y, -103.3)
	C(m, "SunWindow", 0.2, 6, src * CFrame.Angles(math.pi / 2, 0, 0), rgb(255, 244, 200), M.Neon, nc())
	C(m, "SunFrame", 0.16, 6.8, L(A.source.x, A.y, -103.38) * CFrame.Angles(math.pi / 2, 0, 0), Props.BRASS, M.Metal, nc())
	local sl = Instance.new("PointLight")
	sl.Range = 24
	sl.Brightness = 1.2
	sl.Color = rgb(255, 236, 190)
	sl.Parent = m:FindFirstChild("SunWindow")

	-- зеркала на галереях: поворачиваются плавно, держи кнопку -------------------
	local sol = Rules.beamSolution()
	for k, mp in A.mirrors do
		local base = L(mp.x, 0, mp.z)
		P(m, "MirrorBase", Vector3.new(3.2, 1, 3.2), base * CFrame.new(0, 0.5, 0), stoneDark, M.Marble)
		local cf = base * CFrame.new(0, 1, 0)
		local sm, head, glass = Props.mirrorStand(m, cf)
		-- случайный угол, заведомо далеко от нужного
		local angle = sol[k] + math.rad(40 + rand() * 280)
		arena.mirrors[k] = { model = sm, head = head, glass = glass, cf = cf, angle = angle }
		local l = Props.prompt(glass, "turnl", 30, 9)
		local r = Props.prompt(glass, "turnr", 30, 9)
		l.UIOffset = Vector2.new(0, 40)
		r.UIOffset = Vector2.new(0, -40)
		l.KeyboardKeyCode = Enum.KeyCode.Q
		r.KeyboardKeyCode = Enum.KeyCode.E
	end

	-- большая люстра на лебёдке -------------------------------------------------
	local ch = Props.model(m, "BigChandelier")
	local hub = L(A.lens.x, A.y + 3.2, A.lens.z)
	C(ch, "Hub", 2.2, 1.4, hub, Props.BRASS, M.Metal)
	C(ch, "Crown", 0.6, 3, hub * CFrame.new(0, 1.3, 0), Props.BRASS, M.Metal, nc())
	for ring = 1, 2 do
		local rad, y = if ring == 1 then 4.6 else 2.8, if ring == 1 then -0.6 else 0.7
		local cnt = if ring == 1 then 14 else 9
		for k = 0, cnt - 1 do
			local a0, a1 = k / cnt * math.pi * 2, (k + 1) / cnt * math.pi * 2
			local p0 = (hub * CFrame.new(math.cos(a0) * rad, y, math.sin(a0) * rad)).Position
			local p1 = (hub * CFrame.new(math.cos(a1) * rad, y, math.sin(a1) * rad)).Position
			Props.rod(ch, "Ring", p0, p1, 0.22, Props.BRASS, M.Metal, nc())
			C(ch, "Candle", 0.8, 0.3, CFrame.new(p0 + Vector3.new(0, 0.5, 0)), rgb(240, 232, 210), M.SmoothPlastic, nc())
			S(ch, "Flame", 0.26, CFrame.new(p0 + Vector3.new(0, 1.05, 0)), rgb(255, 196, 110), M.Neon, nc())
			if ring == 1 and k % 2 == 0 then
				S(ch, "Drop", 0.45, CFrame.new(p0 - Vector3.new(0, 0.9, 0)), rgb(220, 236, 244), M.Glass, nc({ Transparency = 0.3 }))
			end
		end
		for k = 0, 3 do
			local a = k / 4 * math.pi * 2 + 0.4
			Props.rod(ch, "Arm", hub.Position, (hub * CFrame.new(math.cos(a) * rad, y, math.sin(a) * rad)).Position, 0.2, Props.BRASS, M.Metal, nc())
		end
	end
	local glow = S(ch, "Glow", 0.4, hub * CFrame.new(0, -0.6, 0), rgb(255, 214, 150), M.Neon, nc({ Transparency = 1 }))
	local gl = Instance.new("PointLight")
	gl.Range = 40
	gl.Brightness = 1.6
	gl.Color = rgb(255, 214, 160)
	gl.Parent = glow
	-- держатель для зеркальца под люстрой
	P(ch, "LensFork", Vector3.new(0.3, 2.2, 0.3), hub * CFrame.new(0, -2.2, 0), Props.BRASS, M.Metal, nc())
	local slot = C(ch, "LensSlot", 0.14, 2.2, hub * CFrame.new(0, -3.2, 0) * CFrame.Angles(0, 0, math.rad(45)), Props.BRASS, M.Metal, nc({ Transparency = 0.5 }))
	local slotPrompt = Props.prompt(slot, "place", 0.5, 9)
	slotPrompt.Enabled = false
	ch.WorldPivot = hub
	-- цепь до потолка и трос через блок к лебёдке на левой галерее
	local chain = C(m, "ChandelierChain", d.h - A.y - 4.6, 0.3, CFrame.new(), Props.IRON, M.Metal, nc())
	local winch = L(-(G1 - 1.6), 0, A.lens.z)
	C(m, "Pulley", 0.6, 1.6, L(A.lens.x, d.h - 0.8, A.lens.z) * CFrame.Angles(0, 0, math.pi / 2), Props.IRON, M.Metal, nc())
	C(m, "WallPulley", 0.6, 1.6, L(-(G1 - 0.8), d.h - 0.8, A.lens.z) * CFrame.Angles(0, 0, math.pi / 2), Props.IRON, M.Metal, nc())
	Props.rod(m, "Cable", L(A.lens.x, d.h - 0.4, A.lens.z).Position, L(-(G1 - 0.8), d.h - 0.4, A.lens.z).Position, 0.16, Props.IRON, M.Metal, nc())
	Props.rod(m, "Cable", L(-(G1 - 1.6), d.h - 0.8, A.lens.z).Position, L(-(G1 - 1.6), 2.6, A.lens.z).Position, 0.16, Props.IRON, M.Metal, nc())
	-- лебёдка: барабан с ручкой, тормозной штырь высоко на стене, рычаг сброса
	local drum = C(m, "WinchDrum", 2.4, 1.8, winch * CFrame.new(0, 2.2, 0) * CFrame.Angles(math.pi / 2, 0, 0), stoneDark:Lerp(Props.IRON, 0.6), M.Metal)
	for _, z in { -1.4, 1.4 } do
		P(m, "WinchFrame", Vector3.new(1.4, 2.6, 0.3), winch * CFrame.new(0, 1.3, z), Props.IRON, M.Metal, nc())
	end
	P(m, "Crank", Vector3.new(0.25, 1.4, 0.25), winch * CFrame.new(0.6, 2.5, 1.7), Props.IRON, M.Metal, nc())
	Props.prompt(drum, "crank", 1, 8)
	P(m, "BrakePlate", Vector3.new(0.3, 2.2, 2.2), L(-(G1 - 0.15), 10.5, A.lens.z), Props.IRON, M.Metal)
	local pin = P(m, "BrakePin", Vector3.new(1.6, 0.4, 0.4), L(-(G1 - 1), 10.5, A.lens.z), rgb(170, 60, 40), M.Metal)
	Props.prompt(pin, "knock", 0.6, 16)
	local lever = P(m, "ReleaseLever", Vector3.new(0.3, 2.4, 0.3), winch * CFrame.new(0.4, 1.4, -2.6) * CFrame.Angles(0, 0, math.rad(25)), rgb(170, 40, 30), M.Metal)
	P(m, "LeverBase", Vector3.new(1, 0.4, 1), winch * CFrame.new(0, 0.2, -2.6), Props.IRON, M.Metal, nc())
	Props.prompt(lever, "release", 0.4, 8)
	arena.chand = { model = ch, hubUp = hub, chain = chain, slot = slot, slotPrompt = slotPrompt, up = true, busy = false, lens = nil }
	arena.drum, arena.pin, arena.lever = drum, pin, lever
	arena.ceilingY = L(0, d.h, 0).Position.Y

	-- холодильная камера под левой галереей --------------------------------------
	local CX0, CX1, CZ0, CZ1 = -(G1 - 0.05), -(G0 + 0.6), -62, -76
	local ch2 = (CZ0 + CZ1) / 2
	local cold = Props.model(m, "ColdRoom")
	local ice = rgb(196, 214, 224)
	local hole = { { x = 0, w = Props.DOORS.small.w, y = 0, h = Props.DOORS.small.h } }
	Props.wall(cold, L(CX1, fy, ch2) * CFrame.Angles(0, math.pi / 2, 0), math.abs(CZ1 - CZ0), 0, -fy - 1, 0.6, hole, rgb(170, 180, 186), M.DiamondPlate, "ColdWall")
	for _, z in { CZ0, CZ1 } do
		P(cold, "ColdWall", Vector3.new(math.abs(CX1 - CX0) - 0.3, -fy - 1, 0.6), L((CX0 + CX1) / 2 - 0.15, fy / 2 - 0.5, z), rgb(170, 180, 186), M.DiamondPlate)
	end
	P(cold, "Frost", Vector3.new(math.abs(CX1 - CX0) - 0.9, 0.1, math.abs(CZ1 - CZ0) - 0.6), L((CX0 + CX1) / 2 - 0.3, fy + 0.05, ch2), ice, M.Ice, nc())
	local coldLamp = P(cold, "ColdLamp", Vector3.new(3, 0.3, 0.8), L((CX0 + CX1) / 2, -1.65, ch2), rgb(200, 230, 255), M.Neon, nc())
	local cl = Instance.new("PointLight")
	cl.Range = 16
	cl.Brightness = 1
	cl.Color = rgb(150, 200, 255)
	cl.Parent = coldLamp
	-- полки и крюки: 18 кусков мяса
	local meatSpots = {}
	for _, z in { CZ0 - 1.2, CZ1 + 1.2 } do
		for _, y in { 0.8, 3.2, 5.6 } do
			P(cold, "Shelf", Vector3.new(8.6, 0.2, 1.6), L((CX0 + CX1) / 2 - 0.4, fy + y, z), rgb(150, 156, 160), M.Metal, nc())
			for k = -1, 1 do
				table.insert(meatSpots, L((CX0 + CX1) / 2 - 0.4 + k * 2.8, fy + y + 0.1, z))
			end
		end
	end
	for k = -1, 1 do
		local hx = (CX0 + CX1) / 2 - 1 + k * 2.6
		Props.rod(cold, "HookBar", L(hx, -1.3, CZ0 - 3).Position, L(hx, -1.3, CZ1 + 3).Position, 0.14, Props.IRON, M.Metal, nc())
		local hm = P(cold, "HangingMeat", Vector3.new(1, 2.2, 0.8), L(hx, -3.2, ch2 + k), rgb(140, 36, 40), M.SmoothPlastic, nc())
		hm.CanCollide = false
	end
	for i, cf in meatSpots do
		if i <= Rules.COLOSSUS.meat then
			Props.pickup(cold, cf * CFrame.Angles(0, i * 0.7, 0), "meat")
		end
	end
	local doorCF = L(CX1, fy, ch2) * CFrame.Angles(0, -math.pi / 2, 0)
	local coldDoor, leaves = Props.door(cold, doorCF, nil, true, "small")
	local trig = P(cold, "ColdLock", Vector3.new(1, 1, 1), doorCF * CFrame.new(1.4, 3.6, 0.8), rgb(0, 0, 0), M.SmoothPlastic, nc({ Transparency = 1 }))
	Props.prompt(trig, "open", 0, 7)
	P(cold, "ColdSign", Vector3.new(2.6, 0.8, 0.1), L(CX1 + 0.36, fy + 8.1, ch2), rgb(80, 130, 170), M.SmoothPlastic, nc())
	arena.cold = { model = coldDoor, leaves = leaves, trigger = trig, open = false }

	-- статуи и витрины на полу: за ними можно стоять ------------------------------
	for i, sp in { { -14, -46 }, { 14, -46 }, { -14, -88 }, { 14, -88 } } do
		Props.statue(m, L(sp[1], fy, sp[2]) * CFrame.Angles(0, if sp[1] < 0 then math.pi / 2 else -math.pi / 2, 0), ({ "figure", "bust", "obelisk", "broken" })[i], d.door + i)
	end
	for i, sp in { { -20, -66 }, { 20, -60 } } do
		Props.displayCase(m, L(sp[1], fy, sp[2]), Props.ODD[(d.door + i * 3) % #Props.ODD + 1])
	end

	-- остановленные часы над выходом и механизм у двери ----------------------------
	local ex = d.exit.x or 0
	local hh, mm = Rules.clockTime(rand)
	arena.clock = { h = hh, m = mm }
	local clockCF = L(ex, fy + 16, -103.25) * CFrame.Angles(0, math.pi, 0)
	local function dial(parent2, cf: CFrame, r: number, h: number, mi: number)
		C(parent2, "ClockRim", 0.3, r * 2 + 0.5, cf * CFrame.Angles(math.pi / 2, 0, 0), rgb(26, 24, 24), M.Metal)
		C(parent2, "ClockGold", 0.34, r * 2 + 0.1, cf * CFrame.new(0, 0, -0.02) * CFrame.Angles(math.pi / 2, 0, 0), rgb(210, 168, 70), M.Metal, nc())
		C(parent2, "ClockFace", 0.36, r * 2 - 0.3, cf * CFrame.new(0, 0, -0.05) * CFrame.Angles(math.pi / 2, 0, 0), rgb(240, 232, 210), M.SmoothPlastic, nc())
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			P(parent2, "Mark", Vector3.new(if k % 3 == 0 then 0.24 else 0.14, if k % 3 == 0 then r * 0.22 else r * 0.12, 0.06), cf * CFrame.Angles(0, 0, a) * CFrame.new(0, r * 0.8, -0.24), rgb(20, 20, 20), M.SmoothPlastic, nc())
		end
		local hand = function(name, len, w, a, dz)
			return P(parent2, name, Vector3.new(w, len, 0.06), cf * CFrame.Angles(0, 0, a) * CFrame.new(0, len / 2 - 0.1, dz), rgb(16, 16, 16), M.Metal, nc())
		end
		local ha = ((h % 12) + mi / 60) / 12 * math.pi * 2
		local hp = hand("HourHand", r * 0.5, 0.22, ha, -0.3)
		local mp = hand("MinuteHand", r * 0.78, 0.14, mi / 60 * math.pi * 2, -0.34)
		return hp, mp
	end
	local stopped = Props.model(m, "StoppedClock")
	dial(stopped, clockCF, 3, hh, mm)
	-- механизм: циферблат со стрелками и скважиной, две ручки
	local mech = Props.model(m, "ClockLock")
	local mcf = L(ex + 7.5, fy + 5, -103.25) * CFrame.Angles(0, math.pi, 0)
	P(mech, "MechPlate", Vector3.new(4, 5.4, 0.3), mcf, rgb(36, 32, 30), M.Metal)
	local mh, mmh = dial(mech, mcf * CFrame.new(0, 0.6, -0.1), 1.5, 12, 0)
	local keyhole = P(mech, "Keyhole", Vector3.new(0.5, 0.8, 0.1), mcf * CFrame.new(0, -1.6, -0.12), rgb(10, 10, 10), M.Metal, nc())
	Props.prompt(keyhole, "insert", 0.5, 7)
	local kh = P(mech, "HourKnob", Vector3.new(0.6, 0.6, 0.4), mcf * CFrame.new(-1.3, -1.9, -0.3), rgb(210, 168, 70), M.Metal, nc())
	local km = P(mech, "MinuteKnob", Vector3.new(0.6, 0.6, 0.4), mcf * CFrame.new(1.3, -1.9, -0.3), rgb(210, 168, 70), M.Metal, nc())
	Props.prompt(kh, "hour", 0, 7).Enabled = false
	Props.prompt(km, "minute", 0, 7).Enabled = false
	arena.mech = { cf = mcf * CFrame.new(0, 0.6, -0.1), h = 12, m = 0, hourHand = mh, minuteHand = mmh, keyhole = keyhole, hourKnob = kh, minuteKnob = km, inserted = false }

	-- шест, зеркальце и ключ от камеры лежат в случайных местах ----------------------
	local spots = {
		L(-33, 0, -24) * CFrame.Angles(0, math.pi / 2, 0), L(33, 0, -100) * CFrame.Angles(0, math.pi / 2, 0), L(36, 0, -70) * CFrame.Angles(0, math.pi / 2, 0), L(-36, 0, -84) * CFrame.Angles(0, math.pi / 2, 0),
		L(-16, fy, -101), L(24, fy, -34), L(-6, fy, -100), L(6, fy, -74) * CFrame.Angles(0, 0.8, 0), L(-22, fy, -36),
	}
	for i = #spots, 2, -1 do
		local j = 1 + math.floor(rand() * i)
		spots[i], spots[j] = spots[j], spots[i]
	end
	Props.pickup(m, spots[1], "pole")
	Props.pickup(m, spots[2], "lens")
	Props.pickup(m, spots[3], "coldkey")

	-- круг света под люстрой (виден, когда луч доходит) ------------------------------
	arena.spot = C(m, "LightSpot", 0.08, A.zone * 2, arena.zone * CFrame.new(0, 0.05, 0), rgb(255, 236, 170), M.Neon, nc({ Transparency = 1 }))
	-- постамент, с которого сойдёт Колосс
	P(m, "ColossusBase", Vector3.new(10, 0.6, 10), L(16, fy + 0.3, -78), rgb(120, 116, 110), M.Marble, nc())
	arena.spawn = L(16, fy + 0.6, -78) * CFrame.Angles(0, math.pi, 0)
	arena.wander = {}
	for _, p in { { -18, -36 }, { 18, -36 }, { -20, -56 }, { 20, -52 }, { 0, -66 }, { -18, -80 }, { 18, -84 }, { -8, -98 }, { 8, -98 }, { 0, -44 } } do
		table.insert(arena.wander, L(p[1], fy + 3, p[2]).Position)
	end
	arena.beam = Props.model(m, "Beam")
	info.arena = arena
	info.sealed = true
	info.boss = true
	Props.LIGHT = 1
	Special.placeChandelier(info, 0)
	Special.drawBeam(info)
	return info
end

-- люстра: down от 0 (вверху) до 1 (опущена к полу, можно поставить зеркальце)
-- или >1 — упала на пол
function Special.placeChandelier(info, down: number)
	local a = info.arena
	local ch = a.chand
	local lowY = a.floorY + 7.4
	local upY = ch.hubUp.Position.Y
	local y = upY + (lowY - upY) * math.min(down, 1)
	if down > 1 then
		y = a.floorY + 2.6
	end
	local cf = ch.hubUp + Vector3.new(0, y - upY, 0)
	ch.model:PivotTo(cf)
	local top = a.ceilingY - 0.4
	local len = math.max(0.2, top - (y + 2))
	ch.chain.Size = Vector3.new(len, 0.3, 0.3)
	ch.chain.CFrame = CFrame.new(cf.Position.X, y + 2 + len / 2, cf.Position.Z) * CFrame.Angles(0, 0, math.pi / 2)
	ch.chain.Transparency = if down > 1 then 1 else 0
	ch.pos = cf.Position
end

-- стрелки механизма у выхода
function Special.setMechHands(info)
	local mech = info.arena.mech
	local r = 1.5
	local ha = ((mech.h % 12) + mech.m / 60) / 12 * math.pi * 2
	local ma = mech.m / 60 * math.pi * 2
	mech.hourHand.CFrame = mech.cf * CFrame.Angles(0, 0, ha) * CFrame.new(0, r * 0.5 / 2 - 0.1, -0.3)
	mech.minuteHand.CFrame = mech.cf * CFrame.Angles(0, 0, ma) * CFrame.new(0, r * 0.78 / 2 - 0.1, -0.34)
end

-- угол нормали зеркала (в осях зала) → поворот головы стойки
local function mirrorYaw(a: number): number
	return math.atan2(-math.cos(a), -math.sin(a))
end

function Special.turnMirror(info, k: number)
	local mr = info.arena.mirrors[k]
	mr.head:PivotTo(mr.cf * CFrame.Angles(0, mirrorYaw(mr.angle), 0))
end

-- перерисовать луч по углам зеркал; возвращает цепочку и дошёл ли до люстры
function Special.drawBeam(info)
	local a = info.arena
	local A = Rules.ARENA
	local angles = {}
	for k, mr in a.mirrors do
		angles[k] = mr.angle
		if not mr.posed then
			mr.posed = true
			Special.turnMirror(info, k)
		end
	end
	local path, chain, hit = Rules.beam(angles)
	local up = a.chand.up and not a.chand.busy
	if hit and not up then
		-- люстры на месте нет: луч уходит дальше в стену
		hit = false
		table.remove(path)
	end
	a.beam:ClearAllChildren()
	local function pt(q)
		return (a.origin * CFrame.new(q.x, A.y, q.z)).Position
	end
	for i = 1, #path - 1 do
		local p = Props.rod(a.beam, "Ray", pt(path[i]), pt(path[i + 1]), 0.38 + (i % 2) * 0.05, rgb(255, 236, 170), M.Neon, nc({ Transparency = 0.25 }))
		local l = Instance.new("PointLight")
		l.Range = 12
		l.Brightness = 0.7
		l.Color = rgb(255, 230, 170)
		l.Parent = p
	end
	local lit = hit and a.chand.lens ~= nil
	if lit then
		local from = pt(path[#path])
		local to = a.zone.Position + Vector3.new(0, 0.1, 0)
		local p = Props.rod(a.beam, "DownRay", from, to, 1.2, rgb(255, 240, 190), M.Neon, nc({ Transparency = 0.35 }))
		local l = Instance.new("SpotLight")
		l.Face = Enum.NormalId.Front
		l.Range = 30
		l.Angle = 50
		l.Brightness = 4
		l.Color = rgb(255, 236, 180)
		l.Parent = p
	end
	a.spot.Transparency = if lit then 0.35 else 1
	a.chain = chain
	a.lit = lit
	a.solved = lit
	return chain, hit
end

-- ---------------------------------------------------------------------------
-- Лифт, рычаги и лестница обслуживания (спуск около минуты), внизу дверь 100

function Special.liftHall(parent, d, origin: CFrame, rand, prev)
	local m, info = begin(parent, d, origin, rand, prev)
	-- лифт на левой стене: рамка, закрытые створки, кнопка, три лампы-подсказки
	local lcf = Builder.slotL(d, origin, -15) * CFrame.new(0, 0, 0.3)
	P(m, "LiftFrame", Vector3.new(8, 10.4, 0.4), lcf * CFrame.new(0, 5.2, -0.25), rgb(70, 72, 76), M.Metal, nc())
	for _, s in { -1, 1 } do
		P(m, "LiftLeaf", Vector3.new(3.2, 9.4, 0.2), lcf * CFrame.new(s * 1.62, 4.7, -0.5), rgb(150, 154, 158), M.Metal, nc())
	end
	local call = P(m, "CallButton", Vector3.new(0.7, 1.1, 0.3), lcf * CFrame.new(-4.9, 4.4, -0.2), rgb(40, 40, 44), M.Metal, nc({ CanQuery = true }))
	P(m, "CallLight", Vector3.new(0.3, 0.3, 0.08), lcf * CFrame.new(-4.9, 4.6, -0.38), rgb(200, 40, 30), M.Neon, nc())
	Props.prompt(call, "call", 0, 8)
	local bits = {}
	repeat
		bits = { rand() < 0.5, rand() < 0.5, rand() < 0.5 }
	until bits[1] or bits[2] or bits[3]
	for i = 1, 3 do
		P(m, "HintLamp", Vector3.new(0.8, 0.8, 0.2), lcf * CFrame.new(-(i - 2) * 1.6, 11.4, -0.2), if bits[i] then rgb(255, 200, 80) else rgb(40, 36, 30), if bits[i] then M.Neon else M.SmoothPlastic, nc())
	end
	-- щиток с тремя рычагами справа от служебной двери
	local pcf = Builder.slotFront(d, origin, -7) * CFrame.new(0, 4.6, 0.1)
	P(m, "LeverPanel", Vector3.new(5, 3.2, 0.3), pcf, rgb(60, 62, 66), M.Metal)
	info.levers = {}
	for i = 1, 3 do
		local base = pcf * CFrame.new((i - 2) * 1.6, 0, -0.2)
		P(m, "LeverSlot", Vector3.new(0.3, 1.8, 0.08), base, rgb(20, 20, 20), M.SmoothPlastic, nc())
		local lm = Props.model(m, "Lever")
		local handle = P(lm, "Handle", Vector3.new(0.25, 0.25, 1.1), base * CFrame.new(0, 0, -0.5), rgb(170, 170, 176), M.Metal, nc({ CanQuery = true }))
		S(lm, "Grip", 0.5, base * CFrame.new(0, 0, -1.1), rgb(170, 40, 34), M.SmoothPlastic, nc())
		lm.WorldPivot = base
		lm:PivotTo(base * CFrame.Angles(math.rad(-35), 0, 0))
		Props.prompt(handle, "lever", 0, 7)
		info.levers[i] = { model = lm, base = base, handle = handle, on = false, need = bits[i] }
	end
	Props.bench(m, Builder.slotR(d, origin, -12), 7)
	Props.plantPot(m, at(origin, 12.5, 0, -27))
	lamp(info, m, at(origin, 0, d.h, -15).Position)
	-- служебная дверь (без номера), за ней лестница
	local start = info.exitCF
	local gm, leaves = Props.door(m, start, nil, false, "small")
	info.gate = { model = gm, leaves = leaves, opened = false }
	local wallC, stepC = rgb(72, 72, 70), rgb(90, 88, 84)
	local W = 12
	P(m, "Landing", Vector3.new(W, 1, 7.5), start * CFrame.new(0, -0.5, -4.25), stepC, M.Concrete)
	P(m, "LandingCeil", Vector3.new(W + 2, 1, 7.5), start * CFrame.new(0, 12.5, -4.25), wallC, M.Concrete)
	for _, s in { -1, 1 } do
		P(m, "LandingWall", Vector3.new(1, 13, 7.5), start * CFrame.new(s * (W / 2 + 0.5), 6, -4.25), wallC, M.Concrete)
	end
	local sections, run, drop = 14, 60, 30
	local slope = math.sqrt(run * run + drop * drop)
	for k = 0, sections - 1 do
		local top = start * CFrame.new(0, -k * drop, -(8 + k * run))
		local a, b = top.Position, (top * CFrame.new(0, -drop, -run)).Position
		local mid = CFrame.lookAt((a + b) / 2, b, start.UpVector)
		-- невидимый пандус через середины ступеней и видимые ступени
		P(m, "StairRamp", Vector3.new(W, 1, slope), mid * CFrame.new(0, 0, 0), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CastShadow = false })
		for i = 0, 29 do
			P(m, "Tread", Vector3.new(W, 1, 2), top * CFrame.new(0, -i - 0.5, -(i * 2 + 1)), if i % 2 == 0 then stepC else stepC:Lerp(rgb(0, 0, 0), 0.12), M.Concrete, nc())
		end
		for _, s in { -1, 1 } do
			P(m, "StairWall", Vector3.new(1, 15, slope), mid * CFrame.new(s * (W / 2 + 0.5), 6, 0), wallC, M.Concrete)
			P(m, "Handrail", Vector3.new(0.25, 0.25, slope), mid * CFrame.new(s * (W / 2 - 0.5), 3.6, 0), rgb(120, 60, 40), M.Metal, nc())
		end
		P(m, "StairCeil", Vector3.new(W + 2, 1, slope), mid * CFrame.new(0, 13, 0), wallC, M.Concrete)
		local bulb = P(m, "StairLamp", Vector3.new(1.2, 0.4, 0.6), mid * CFrame.new(0, 12.2, 0), rgb(255, 200, 120), M.Neon, nc())
		local l = Instance.new("PointLight")
		l.Range = 30
		l.Brightness = if k % 3 == 2 then 0.25 else 0.8
		l.Color = rgb(255, 196, 130)
		l.Shadows = false
		l.Parent = bulb
	end
	-- внизу короткий коридор и дверь 100
	local bottom = start * CFrame.new(0, -sections * drop, -(8 + sections * run))
	local cl = 30
	P(m, "BottomFloor", Vector3.new(W, 1, cl + 0.5), bottom * CFrame.new(0, -0.5, -cl / 2 + 0.25), stepC, M.Concrete)
	P(m, "BottomCeil", Vector3.new(W + 2, 1, cl + 0.5), bottom * CFrame.new(0, 12.5, -cl / 2 + 0.25), wallC, M.Concrete)
	for _, s in { -1, 1 } do
		P(m, "BottomWall", Vector3.new(1, 13, cl + 0.5), bottom * CFrame.new(s * (W / 2 + 0.5), 6, -cl / 2 + 0.25), wallC, M.Concrete)
	end
	local endCF = bottom * CFrame.new(0, 0, -cl)
	Props.wall(m, endCF * CFrame.Angles(0, math.pi, 0), W + 2, 0, 12, 1, { { x = 0, w = 5, y = 0, h = 9 } }, wallC, M.Concrete, "Struct")
	local bl = P(m, "BottomLamp", Vector3.new(1.2, 0.4, 0.6), bottom * CFrame.new(0, 11.8, -cl / 2), rgb(255, 200, 120), M.Neon, nc())
	local l2 = Instance.new("PointLight")
	l2.Range = 30
	l2.Brightness = 0.6
	l2.Color = rgb(255, 196, 130)
	l2.Parent = bl
	info.exitCF = endCF
	info.exitWall = { a = (endCF * CFrame.new(-W / 2 - 1, 0, 0)).Position, b = (endCF * CFrame.new(W / 2 + 1, 0, 0)).Position, top = endCF.Y + 12, bottom = endCF.Y }
	info.stairs = { top = start, bottom = bottom }
	info.sealed = true
	Props.LIGHT = 1
	return info
end

-- игрок на лестнице или в нижнем коридоре (для проверки «в зале»)
function Special.onStairs(info, pos: Vector3): boolean
	local st = info.stairs
	if not st then
		return false
	end
	local lp = st.top:PointToObjectSpace(pos)
	return math.abs(lp.X) < 8 and lp.Z < 1 and lp.Z > -900 and lp.Y < 14 and lp.Y > -440
end

-- ---------------------------------------------------------------------------
-- Заброшенный зал за дверью 100: мох, корни, упавшие колонны

function Special.final(parent, d, origin: CFrame, rand, prev)
	d.entry = Props.DOORS.normal
	d.exitSize = "grand"
	d.light = 0.5
	local m, info = begin(parent, d, origin, rand, prev, function(st)
		st.paper = rgb(64, 72, 60)
		st.floor = rgb(72, 78, 66)
		st.floorMat = M.Slate
		st.ceil = rgb(60, 64, 56)
	end)
	local moss, vine = rgb(52, 84, 46), rgb(40, 70, 40)
	for k = 1, 22 do
		local x, z = (rand() - 0.5) * (d.w - 6), -3 - rand() * (d.l - 6)
		P(m, "Moss", Vector3.new(3 + rand() * 5, 0.06 + (k % 3) * 0.01, 3 + rand() * 5), at(origin, x, 0.03 + k * 0.002, z) * CFrame.Angles(0, rand() * 3, 0), moss:Lerp(rgb(70, 96, 50), rand()), M.Grass, nc())
	end
	for k = 1, 18 do
		local x, z = (rand() - 0.5) * (d.w - 4), -2 - rand() * (d.l - 4)
		local len = 4 + rand() * 9
		C(m, "Vine", len, 0.2, at(origin, x, d.h - len / 2, z), vine, M.Grass, nc())
		S(m, "Leaf", 0.9, at(origin, x, d.h - len, z), moss, M.Grass, nc())
	end
	for _, p in { { -16, -14, 20 }, { 16, -14, 11 }, { -16, -34, 7 }, { 16, -34, 20 }, { -16, -52, 14 }, { 16, -52, 5 } } do
		Props.pillar(m, at(origin, p[1], 0, p[2]), math.min(p[3], d.h), rgb(120, 122, 110))
	end
	-- упавшая колонна и разбитая статуя
	C(m, "FallenColumn", 14, 2.2, at(origin, 7, 1.1, -42) * CFrame.Angles(0, 0.5, math.pi / 2), rgb(120, 122, 110), M.Limestone)
	Props.statue(m, at(origin, -6, 0, -26), "broken", 1)
	S(m, "StatueHead", 0.9, at(origin, -3.2, 0.45, -24.4), Props.MARBLE, M.Marble, nc())
	for k = 0, 5 do
		Props.rod(m, "Root", at(origin, -4 + k * 1.6, 0.2, -d.l + 1).Position, at(origin, -6 + k * 2.4, 5 + (k % 3) * 2.5, -d.l + 0.95).Position, 0.4, rgb(60, 46, 34), M.Wood, nc())
	end
	P(m, "Puddle", Vector3.new(7, 0.05, 5), at(origin, 8, 0.05, -18), rgb(40, 60, 60), M.Glass, nc({ Transparency = 0.3, Reflectance = 0.3 }))
	for _, p in { { -10, -20 }, { 10, -40 } } do
		local shaft = C(m, "MoonShaft", d.h, 2.4, at(origin, p[1], d.h / 2, p[2]), rgb(150, 190, 170), M.Neon, nc({ Transparency = 0.85 }))
		local l = Instance.new("PointLight")
		l.Range = 30
		l.Brightness = 0.7
		l.Color = rgb(150, 200, 170)
		l.Parent = shaft
	end
	-- дальше пути пока нет: заросшие двери и тьма за ними
	Props.door(m, info.exitCF, nil, true, "grand")
	P(m, "Dark", Vector3.new(11, 14, 0.4), info.exitCF * CFrame.new(0, 7, -1.3), rgb(0, 0, 0), M.SmoothPlastic)
	info.final = true
	Props.LIGHT = 1
	return info
end

return Special
