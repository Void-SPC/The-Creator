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
	P(m, "Ground", Vector3.new(240, 1, 240), CFrame.new(0, -0.5, -20), rgb(34, 52, 36), M.Grass)
	P(m, "Path", Vector3.new(14, 0.2, 86), CFrame.new(0, 0.1, -11), rgb(110, 106, 100), M.Cobblestone)
	P(m, "SidePath", Vector3.new(50, 0.2, 8), CFrame.new(32, 0.1, -30), rgb(110, 106, 100), M.Cobblestone)
	-- крыльцо с пологими ступенями (по ним идут без прыжка)
	P(m, "Porch", Vector3.new(46, 1.6, 22), CFrame.new(0, 0.8, -71), stone, M.Marble)
	for k = 0, 3 do
		P(m, "Stair", Vector3.new(40, 0.4 * (k + 1), 1.5), CFrame.new(0, 0.2 * (k + 1), -54.75 - k * 1.5), stone:Lerp(rgb(0, 0, 0), 0.1), M.Marble, nc())
	end
	local rampLen = math.sqrt(6 * 6 + 1.6 * 1.6)
	P(m, "StairRamp", Vector3.new(40, 0.4, rampLen), CFrame.new(0, 0.6, -57) * CFrame.Angles(math.atan2(1.6, 6), 0, 0), stone, M.Marble, { Transparency = 1, CastShadow = false })
	-- фасад с проёмом, колоннами и фронтоном
	Props.wall(m, CFrame.new(0, 1.6, -76), 130, 0, 44, 4, { { x = 0, w = 10, y = 0, h = 14 } }, rgb(128, 124, 116), M.Limestone, "Facade")
	P(m, "FacadeBase", Vector3.new(130, 1.6, 4), CFrame.new(0, 0.8, -76.01), rgb(100, 96, 90), M.Limestone)
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
	-- приоткрытые двери, за ними тьма
	local floorIn = P(m, "Threshold", Vector3.new(12, 1.6, 8), CFrame.new(0, 0.8, -86), rgb(20, 20, 20), M.Slate)
	local _ = floorIn
	for _, s in { -1, 1 } do
		P(m, "DoorLeaf", Vector3.new(5, 13.8, 0.4), CFrame.new(s * 5, 8.5, -74) * CFrame.Angles(0, s * math.rad(62), 0) * CFrame.new(-s * 2.5, 0, 0), rgb(52, 34, 24), M.WoodPlanks)
		P(m, "DarkSide", Vector3.new(1, 16, 9), CFrame.new(s * 6.5, 9.6, -82.5), rgb(0, 0, 0), M.SmoothPlastic)
	end
	P(m, "Dark", Vector3.new(14, 16, 1), CFrame.new(0, 9.6, -87.5), rgb(0, 0, 0), M.SmoothPlastic)
	P(m, "DarkTop", Vector3.new(14, 1, 10), CFrame.new(0, 17.5, -83), rgb(0, 0, 0), M.SmoothPlastic, nc())
	local zone = P(m, "EnterZone", Vector3.new(9, 12, 6), CFrame.new(0, 7.6, -82), rgb(0, 0, 0), M.SmoothPlastic, ghost())
	-- тёмные окна фасада
	for _, x in { -52, -38, 38, 52 } do
		P(m, "Window", Vector3.new(6, 12, 0.2), CFrame.new(x, 16, -73.88), rgb(8, 10, 14), M.Glass, nc({ Reflectance = 0.2 }))
		P(m, "WindowSill", Vector3.new(7.4, 0.6, 1), CFrame.new(x, 9.7, -73.6), stone, M.Marble, nc())
		P(m, "WindowHead", Vector3.new(7.4, 0.8, 0.8), CFrame.new(x, 22.4, -73.7), stone, M.Marble, nc())
	end
	-- второй вход по тропинке: бесконечный режим (пока закрыт)
	P(m, "Annex", Vector3.new(4, 20, 26), CFrame.new(60, 10, -30), rgb(118, 114, 108), M.Limestone)
	P(m, "AnnexDoor", Vector3.new(0.3, 9, 6), CFrame.new(57.9, 4.6, -30), rgb(30, 22, 18), M.WoodPlanks, nc())
	for k = -1, 1 do
		P(m, "Board", Vector3.new(0.2, 0.9, 8), CFrame.new(57.7, 4.6 + k * 2.4, -30) * CFrame.Angles(k * 0.25, 0, 0), rgb(96, 70, 44), M.WoodPlanks, nc())
	end
	local soon = P(m, "SoonSign", Vector3.new(0.3, 3, 12), CFrame.new(57.8, 12.5, -30), rgb(40, 30, 24), M.Wood, nc())
	surfaceText(soon, Enum.NormalId.Left, "", "EndlessSoon", rgb(226, 200, 140), 20)
	-- деревья кольцом закрывают улицу
	local k = 0
	for a = 0, 35 do
		local ang = math.rad(a * 10)
		for ring = 0, 1 do
			local r = 82 + ring * 16 + (a % 3) * 4
			local x, z = math.sin(ang) * r, -20 + math.cos(ang) * r
			if not (z < -52 and math.abs(x) < 70) and not (x > 50 and math.abs(z + 30) < 18) then
				k += 1
				Props.tree(m, CFrame.new(x, 0, z), 14 + (k % 4) * 3, k)
			end
		end
	end
	for _, p in { { -30, -40 }, { 30, -44 }, { -44, -10 }, { 42, 6 }, { -24, 30 }, { 26, 36 } } do
		k += 1
		Props.tree(m, CFrame.new(p[1], 0, p[2]), 13 + (k % 3) * 3, k)
	end
	for _, z in { 24, 4, -16, -40 } do
		Props.lampPost(m, CFrame.new(-9.5, 0, z))
		Props.lampPost(m, CFrame.new(9.5, 0, z))
	end
	Props.lampPost(m, CFrame.new(40, 0, -35.5))
	Props.bench(m, CFrame.new(-8.5, 0, -6) * CFrame.Angles(0, -math.pi / 2, 0), 7)
	Props.bench(m, CFrame.new(8.5, 0, -26) * CFrame.Angles(0, math.pi / 2, 0), 7)
	-- невидимая ограда за деревьями
	for _, w in { { 0, 70, 220, 2 }, { -108, -20, 2, 220 }, { 108, -20, 2, 220 } } do
		P(m, "Fence", Vector3.new(w[3], 60, w[4]), CFrame.new(w[1], 30, w[2]), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CastShadow = false })
	end
	return { model = m, zone = zone, spawn = CFrame.new(0, 3.2, 28) }
end

-- ---------------------------------------------------------------------------
-- Монетчик: золотая монета с усами. Стоит перед дверью; рядом в стене его норка

function Special.coinKeeper(parent, cf: CFrame, price: number, holeCF: CFrame)
	local m = Props.model(parent, "CoinKeeper")
	local gold, dark = rgb(222, 180, 66), rgb(160, 120, 36)
	local face = cf * CFrame.new(0, 3.4, 0)
	local flatR = CFrame.Angles(math.pi / 2, 0, 0)
	C(m, "Rim", 0.5, 4.6, face * flatR, dark, M.Metal)
	C(m, "Face", 0.7, 3.9, face * flatR, gold, M.Metal, nc())
	for k = 0, 19 do
		P(m, "Mill", Vector3.new(0.25, 0.3, 0.42), face * CFrame.Angles(0, 0, k * math.pi / 10) * CFrame.new(0, 2.32, 0), dark, M.Metal, nc())
	end
	for _, x in { -0.75, 0.75 } do
		C(m, "Eye", 0.12, 0.6, face * CFrame.new(x, 0.6, -0.38) * flatR, rgb(250, 246, 230), M.SmoothPlastic, nc())
		S(m, "Pupil", 0.26, face * CFrame.new(x, 0.55, -0.46), rgb(20, 14, 8), M.SmoothPlastic, nc())
		P(m, "Brow", Vector3.new(0.9, 0.16, 0.12), face * CFrame.new(x, 1.1, -0.4) * CFrame.Angles(0, 0, if x < 0 then -0.3 else 0.3), dark, M.Metal, nc())
		-- усы: от носа в сторону и вверх завитком
		local a = (face * CFrame.new(x * 0.2, -0.25, -0.42)).Position
		local b = (face * CFrame.new(x * 1.3, -0.5, -0.42)).Position
		local c = (face * CFrame.new(x * 1.9, -0.05, -0.42)).Position
		Props.rod(m, "Moustache", a, b, 0.22, rgb(40, 28, 16), M.SmoothPlastic, nc())
		Props.rod(m, "Moustache", b, c, 0.16, rgb(40, 28, 16), M.SmoothPlastic, nc())
		S(m, "Curl", 0.26, CFrame.new(c), rgb(40, 28, 16), M.SmoothPlastic, nc())
		-- ручки и ножки
		local sh = (face * CFrame.new(x * 2.9, -0.2, 0)).Position
		local hand = (face * CFrame.new(x * 3.7, -1.2, -0.4)).Position
		Props.rod(m, "Arm", sh, hand, 0.2, dark, M.Metal, nc())
		S(m, "Hand", 0.45, CFrame.new(hand), gold, M.Metal, nc())
		local hip = (face * CFrame.new(x * 0.9, -2.1, 0)).Position
		local foot = (face * CFrame.new(x * 1, -3.25, 0)).Position
		Props.rod(m, "Leg", hip, foot, 0.22, dark, M.Metal, nc())
		P(m, "Shoe", Vector3.new(0.6, 0.3, 0.9), CFrame.new(foot) * cf.Rotation * CFrame.new(0, 0, -0.2), rgb(40, 28, 16), M.SmoothPlastic, nc())
	end
	S(m, "Nose", 0.4, face * CFrame.new(0, 0, -0.5), dark, M.Metal, nc())
	P(m, "Mouth", Vector3.new(0.9, 0.12, 0.08), face * CFrame.new(0, -0.9, -0.38), rgb(60, 30, 10), M.SmoothPlastic, nc())
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
	P(hole, "Dark", Vector3.new(4.2, 4.6, 0.3), holeCF * CFrame.new(0, 2.3, 0.75), rgb(0, 0, 0), M.SmoothPlastic, nc())
	for _, s in { -1, 1 } do
		P(hole, "Jamb", Vector3.new(0.5, 4.8, 0.5), holeCF * CFrame.new(s * 2.35, 2.4, 0.9), rgb(120, 114, 104), M.Limestone, nc())
	end
	P(hole, "Arch", Vector3.new(5.6, 0.6, 0.6), holeCF * CFrame.new(0, 5.1, 0.9), rgb(120, 114, 104), M.Limestone, nc())
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
	-- ключ лежит на подушке в правом крыле; в левом — пустой постамент
	local _, keyTop = Props.plinth(m, at(origin, 26, 0, -22), 2, 3)
	P(m, "Cushion", Vector3.new(1.5, 0.2, 1.5), keyTop * CFrame.new(0, 0.1, 0), rgb(100, 20, 30), M.Fabric, nc())
	local _, key = Props.pickup(m, keyTop * CFrame.new(0, 0.2, 0), "key")
	key:SetAttribute("KeyFor", d.door + 1)
	Props.vase(m, at(origin, -26, 0, -22), 3)
	info.code = code
	info.codePanel = panel
	info.sealed = true
	Props.LIGHT = 1
	return info
end

-- ---------------------------------------------------------------------------
-- Арена Колосса: парадная лестница вниз, зеркала на стойках, луч из дыры в потолке,
-- куски мяса, плита-приманка перед кристаллом

function Special.arena(parent, d, origin: CFrame, rand, prev)
	local m, info = begin(parent, d, origin, rand, prev)
	local fy = d.dy
	local function cell(i: number, j: number): CFrame
		return at(origin, i * 10, fy, -(40 + j * 10))
	end
	local MR = Rules.MIRRORS
	-- дыра в потолке и столб света на первое (неподвижное) зеркало
	local src = cell(MR.source.i, MR.source.j)
	C(m, "Skylight", 0.4, 7, src * CFrame.new(0, d.h - fy - 0.2, 0), rgb(255, 244, 200), M.Neon, nc())
	local shaft = C(m, "LightShaft", d.h - fy - 6, 1.4, src * CFrame.new(0, 5.6 + (d.h - fy - 6) / 2, 0), rgb(255, 240, 190), M.Neon, nc({ Transparency = 0.6 }))
	local sl = Instance.new("PointLight")
	sl.Range = 46
	sl.Brightness = 1.2
	sl.Color = rgb(255, 236, 190)
	sl.Parent = shaft
	local _, srcHead = Props.mirrorStand(m, src)
	srcHead:PivotTo(src * CFrame.Angles(0, math.rad(45), 0))
	local arena = { cell = cell, mirrors = {}, y = 5.6, solved = false, meat = nil }
	for k, c in MR.cells do
		local cf = cell(c.i, c.j)
		local sm, head, glass = Props.mirrorStand(m, cf)
		local state = (c.need + 1 + math.floor(rand() * 3)) % 4
		head:PivotTo(cf * CFrame.Angles(0, state * math.pi / 4, 0))
		Props.prompt(glass, "turn", 0, 8)
		arena.mirrors[k] = { model = sm, head = head, glass = glass, cf = cf, state = state }
	end
	-- кристалл в конце пути луча и плита для приманки перед ним
	local tcf = cell(MR.target.i, MR.target.j)
	C(m, "CrystalStand", 4.6, 0.5, tcf * CFrame.new(0, 2.3, 0), Props.IRON, M.Metal)
	arena.crystal = P(m, "Crystal", Vector3.new(1.8, 1.8, 1.8), tcf * CFrame.new(0, 5.6, 0) * CFrame.Angles(0.6, 0.8, 0.3), rgb(150, 190, 220), M.Glass, nc({ Transparency = 0.3 }))
	local plateCF = at(origin, 0, fy, -84)
	local plate = C(m, "BaitPlate", 0.2, 5, plateCF * CFrame.new(0, 0.1, 0), rgb(60, 56, 54), M.Slate)
	Props.prompt(plate, "bait", 0.5, 8)
	arena.plate = plate
	arena.plateCF = plateCF
	-- 18 кусков мяса
	local k = 0
	for _, x in { -35, -28, -12, 12, 28, 35 } do
		for _, z in { -34, -56, -78 } do
			k += 1
			local cf = at(origin, x, fy, z) * CFrame.Angles(0, k * 0.7, 0)
			P(m, "Tray", Vector3.new(1.8, 0.1, 1.4), cf * CFrame.new(0, 0.05, 0), rgb(150, 150, 154), M.Metal, nc())
			Props.pickup(m, cf * CFrame.new(0, 0.1, 0), "meat")
		end
	end
	-- постамент, с которого сойдёт Колосс
	P(m, "ColossusBase", Vector3.new(9, 0.6, 9), at(origin, -20, fy + 0.3, -80), rgb(120, 116, 110), M.Marble, nc())
	arena.spawn = at(origin, -20, fy + 0.6, -80) * CFrame.Angles(0, math.pi, 0)
	arena.wander = {}
	for _, p in { { -30, -45 }, { 30, -45 }, { -30, -65 }, { 30, -65 }, { -10, -95 }, { 10, -95 }, { -30, -92 }, { 30, -92 }, { 10, -38 }, { -10, -62 } } do
		table.insert(arena.wander, at(origin, p[1], fy + 3, p[2]).Position)
	end
	for _, z in { -50, -88 } do
		for _, slot in { Builder.slotL, Builder.slotR } do
			local _, shade = Props.sconce(m, slot(d, origin, z) * CFrame.new(0, 9, Builder.F - 0.6))
			table.insert(info.lights, shade)
		end
	end
	arena.beam = Props.model(m, "Beam")
	info.arena = arena
	info.sealed = true
	info.boss = true
	Props.LIGHT = 1
	return info
end

-- перерисовать луч по состоянию зеркал; возвращает, дошёл ли он до кристалла
function Special.drawBeam(info): boolean
	local arena = info.arena
	local states = {}
	for k, mr in arena.mirrors do
		states[k] = mr.state
	end
	local path, hit = Rules.trace(states)
	arena.beam:ClearAllChildren()
	for i = 1, #path - 1 do
		local a = (arena.cell(path[i].i, path[i].j) * CFrame.new(0, arena.y, 0)).Position
		local b = (arena.cell(path[i + 1].i, path[i + 1].j) * CFrame.new(0, arena.y, 0)).Position
		local p = Props.rod(arena.beam, "Ray", a, b, 0.35, rgb(255, 236, 170), M.Neon, nc({ Transparency = 0.25 }))
		if i % 2 == 1 then
			local l = Instance.new("PointLight")
			l.Range = 14
			l.Brightness = 0.8
			l.Color = rgb(255, 230, 170)
			l.Parent = p
		end
	end
	arena.solved = hit
	arena.crystal.Material = if hit then M.Neon else M.Glass
	arena.crystal.Color = if hit then rgb(255, 220, 140) else rgb(150, 190, 220)
	return hit
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
