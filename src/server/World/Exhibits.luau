--!nonstrict
-- Экспонаты больших тематических залов: Египет, Рим, рыцари, Эстония, Россия, Англия,
-- Франция, Япония. Модели музейные (макеты, манекены, предметы), всё из простых деталей;
-- флаги, гербы, письмена и мозаики нарисованы плоско на поверхности

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local M = require(Shared.Materials)
local Props = require(script.Parent.Props)

local P, C, S, nc, rgb, rod, model = Props.P, Props.C, Props.S, Props.nc, Props.rgb, Props.rod, Props.model

local X = {}

local GOLD = rgb(214, 170, 70)
local SAND = rgb(206, 178, 128)
local SAND_D = rgb(170, 140, 96)

-- плоская фигура на SurfaceGui (доли от размера поверхности)
local function shape(parent, color: Color3, x, y, w, h, round: number?, rot: number?)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.Rotation = rot or 0
	if round then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(round, 0)
		c.Parent = f
	end
	f.Parent = parent
	return f
end
X.shape = shape

local function canvas(part: BasePart, face: Enum.NormalId, bg: Color3)
	local gui = Props.surface(part, face, 40)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = bg
	f.Parent = gui
	return f
end
X.canvas = canvas

-- ---------------------------------------------------------------------------
-- флаги: полотнище на древке, рисунок плоский. kind: estonia, russia, france,
-- england, japan, egypt (просто цвета), rome (красное знамя с орлом-кругом)

local FLAGS = {
	estonia = { dir = "h", rgb(0, 114, 206), rgb(20, 20, 20), rgb(255, 255, 255) },
	russia = { dir = "h", rgb(255, 255, 255), rgb(0, 57, 166), rgb(213, 43, 30) },
	france = { dir = "v", rgb(0, 35, 149), rgb(255, 255, 255), rgb(237, 41, 57) },
}

function X.flag(parent, cf: CFrame, kind: string, w: number?, h: number?)
	local m = model(parent, "Flag")
	w, h = w or 6, h or 4
	C(m, "Pole", 12, 0.25, cf * CFrame.new(0, 6, 0), rgb(60, 50, 40), M.Wood)
	C(m, "PoleFoot", 0.4, 1.4, cf * CFrame.new(0, 0.2, 0), rgb(40, 36, 32), M.Metal)
	S(m, "Finial", 0.5, cf * CFrame.new(0, 12.2, 0), GOLD, M.Metal, nc())
	local cloth = P(m, "Cloth", Vector3.new(w, h, 0.05), cf * CFrame.new(w / 2 + 0.15, 12 - h / 2 - 0.2, 0) * CFrame.Angles(0, 0, 0), rgb(255, 255, 255), M.Fabric, nc())
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local f = canvas(cloth, face, rgb(255, 255, 255))
		local spec = FLAGS[kind]
		if spec then
			for i = 1, 3 do
				if spec.dir == "h" then
					shape(f, spec[i], 0.5, (i - 0.5) / 3, 1, 1 / 3 + 0.005)
				else
					local x = (i - 0.5) / 3
					if face == Enum.NormalId.Back then
						x = 1 - x
					end
					shape(f, spec[i], x, 0.5, 1 / 3 + 0.005, 1)
				end
			end
		elseif kind == "england" then
			shape(f, rgb(206, 17, 36), 0.5, 0.5, 1, 0.2)
			shape(f, rgb(206, 17, 36), 0.5, 0.5, 0.2 * h / w, 1)
		elseif kind == "japan" then
			shape(f, rgb(188, 0, 45), 0.5, 0.5, 0.6 * h / w, 0.6, 1)
		elseif kind == "rome" then
			f.BackgroundColor3 = rgb(140, 20, 24)
			shape(f, GOLD, 0.5, 0.45, 0.4 * h / w, 0.4, 1)
			shape(f, rgb(140, 20, 24), 0.5, 0.45, 0.3 * h / w, 0.3, 1)
			shape(f, GOLD, 0.5, 0.85, 0.7, 0.08)
		elseif kind == "egypt" then
			f.BackgroundColor3 = rgb(230, 200, 120)
			shape(f, rgb(30, 70, 140), 0.5, 0.2, 1, 0.12)
			shape(f, rgb(30, 70, 140), 0.5, 0.8, 1, 0.12)
			shape(f, rgb(180, 40, 30), 0.5, 0.5, 0.25 * h / w, 0.25, 1)
		end
	end
	return m
end

-- длинное знамя, свисающее со стены (cf — на стене, лицо в зал)
function X.banner(parent, cf: CFrame, w: number, h: number, base: Color3, emblem: Color3, seed: number)
	local m = model(parent, "Banner")
	rod(m, "BannerRod", (cf * CFrame.new(-w / 2 - 0.4, 0, -0.25)).Position, (cf * CFrame.new(w / 2 + 0.4, 0, -0.25)).Position, 0.2, GOLD, M.Metal, nc())
	local cloth = P(m, "Banner", Vector3.new(w, h, 0.06), cf * CFrame.new(0, -h / 2 - 0.1, -0.2), base, M.Fabric, nc())
	local f = canvas(cloth, Enum.NormalId.Front, base)
	shape(f, emblem, 0.5, 0.06, 1, 0.04)
	if seed % 3 == 0 then
		-- лев: круг и «грива»
		shape(f, emblem, 0.5, 0.42, 0.55, 0.55 * w / h, 1)
		shape(f, base, 0.5, 0.42, 0.4, 0.4 * w / h, 1)
		shape(f, emblem, 0.5, 0.42, 0.22, 0.22 * w / h, 0.3, 45)
	elseif seed % 3 == 1 then
		-- крест
		shape(f, emblem, 0.5, 0.42, 0.18, 0.5)
		shape(f, emblem, 0.5, 0.36, 0.6, 0.08)
	else
		-- три звезды-ромба
		for k = 0, 2 do
			shape(f, emblem, 0.5, 0.25 + k * 0.18, 0.3, 0.3 * w / h, 0.1, 45)
		end
	end
	-- хвост-ласточкин хвост: два треугольника тёмного цвета снизу
	shape(f, rgb(10, 10, 10), 0.5, 1.02, 0.4, 0.16, nil, 45)
	return m
end

-- щит с гербом на стене
function X.shield(parent, cf: CFrame, seed: number)
	local m = model(parent, "Shield")
	local colors = { rgb(150, 20, 30), rgb(20, 50, 130), rgb(30, 100, 50), rgb(200, 160, 40) }
	local a, b = colors[seed % 4 + 1], colors[(seed + 2) % 4 + 1]
	local sh = P(m, "Shield", Vector3.new(2.4, 3, 0.2), cf * CFrame.new(0, 0, -0.15), rgb(120, 120, 126), M.Metal, nc())
	P(m, "ShieldTip", Vector3.new(1.7, 1.7, 0.2), cf * CFrame.new(0, -1.5, -0.15) * CFrame.Angles(0, 0, math.rad(45)), rgb(120, 120, 126), M.Metal, nc())
	local f = canvas(sh, Enum.NormalId.Front, a)
	if seed % 2 == 0 then
		shape(f, b, 0.75, 0.5, 0.5, 1)
	else
		shape(f, b, 0.5, 0.35, 1, 0.3)
	end
	shape(f, GOLD, 0.5, 0.5, 0.3, 0.24, 1)
	-- меч за щитом
	P(m, "Blade", Vector3.new(0.25, 5, 0.08), cf * CFrame.new(0, 0, -0.02) * CFrame.Angles(0, 0, math.rad(35)), rgb(180, 184, 190), M.Metal, nc())
	P(m, "Blade", Vector3.new(0.25, 5, 0.08), cf * CFrame.new(0, 0, -0.04) * CFrame.Angles(0, 0, math.rad(-35)), rgb(180, 184, 190), M.Metal, nc())
	return m
end

-- ---------------------------------------------------------------------------
-- Египет

function X.sphinx(parent, cf: CFrame)
	local m = model(parent, "Sphinx")
	P(m, "Base", Vector3.new(5, 1, 9), cf * CFrame.new(0, 0.5, 0), SAND_D, M.Sandstone)
	P(m, "Body", Vector3.new(3.4, 2.6, 6), cf * CFrame.new(0, 2.32, 1), SAND, M.Sandstone)
	P(m, "Haunch", Vector3.new(3.8, 2.2, 2.4), cf * CFrame.new(0, 2.14, 3.2), SAND, M.Sandstone)
	for _, sx in { -1, 1 } do
		P(m, "Paw", Vector3.new(1, 0.9, 3.4), cf * CFrame.new(sx * 1.1, 1.45, -2.6), SAND, M.Sandstone)
	end
	P(m, "Chest", Vector3.new(2.6, 2.4, 1.6), cf * CFrame.new(0, 3, -2), SAND, M.Sandstone)
	P(m, "Head", Vector3.new(1.8, 2, 1.8), cf * CFrame.new(0, 5, -2.2), SAND, M.Sandstone)
	-- платок-немес: полосатый, ниспадает на плечи
	local nemes = P(m, "Nemes", Vector3.new(2.7, 2.2, 1.4), cf * CFrame.new(0, 5.15, -1.6), rgb(196, 160, 90), M.Sandstone, nc())
	local f = canvas(nemes, Enum.NormalId.Front, rgb(196, 160, 90))
	for k = 0, 5 do
		shape(f, rgb(40, 70, 130), 0.5, 0.08 + k * 0.17, 1, 0.07)
	end
	P(m, "Face", Vector3.new(1.4, 1.6, 0.2), cf * CFrame.new(0, 4.9, -3.15), SAND, M.Sandstone, nc())
	P(m, "Beard", Vector3.new(0.4, 0.9, 0.3), cf * CFrame.new(0, 3.7, -3.05), SAND_D, M.Sandstone, nc())
	return m
end

function X.pyramid(parent, cf: CFrame, size: number)
	local m = model(parent, "Pyramid")
	local layers = 7
	for k = 0, layers - 1 do
		local w = size * (1 - k / layers)
		P(m, "Layer", Vector3.new(w, size / layers * 0.7, w), cf * CFrame.new(0, (k + 0.5) * size / layers * 0.7, 0), SAND:Lerp(SAND_D, k % 2 * 0.3), M.Sandstone)
	end
	P(m, "Cap", Vector3.new(size / layers * 0.8, size / layers * 0.5, size / layers * 0.8), cf * CFrame.new(0, size * 0.7 + size / layers * 0.25, 0), GOLD, M.Metal, nc())
	return m
end

function X.sarcophagus(parent, cf: CFrame, seed: number)
	local m = model(parent, "Sarcophagus")
	local _, top = Props.plinth(m, cf, 3.2, 1.4, SAND_D)
	local body = P(m, "Coffin", Vector3.new(2.4, 1.6, 6.4), top * CFrame.new(0, 0.8, 0), rgb(40, 60, 110), M.SmoothPlastic)
	local lid = P(m, "Lid", Vector3.new(2.2, 0.5, 6.2), top * CFrame.new(0, 1.85, 0), GOLD, M.Metal, nc())
	local f = canvas(lid, Enum.NormalId.Top, GOLD)
	-- маска, ожерелье, сложенные руки, полосы
	shape(f, rgb(196, 150, 70), 0.5, 0.1, 0.7, 0.13, 0.4)
	shape(f, rgb(30, 60, 130), 0.5, 0.06, 0.9, 0.04)
	for k = 0, 4 do
		shape(f, if k % 2 == 0 then rgb(30, 60, 130) else rgb(170, 40, 30), 0.5, 0.22 + k * 0.025, 0.8, 0.018)
	end
	shape(f, rgb(180, 140, 60), 0.5, 0.36, 0.7, 0.06, 0.5)
	for k = 0, 5 do
		shape(f, rgb(30, 60, 130), 0.5, 0.5 + k * 0.08, 0.6, 0.02)
	end
	local _ = seed
	local _b = body
	return m
end

function X.egyptColumn(parent, cf: CFrame, h: number)
	local m = model(parent, "Column")
	C(m, "Base", 0.6, 3.6, cf * CFrame.new(0, 0.3, 0), SAND_D, M.Sandstone)
	C(m, "Shaft", h - 2.6, 2.6, cf * CFrame.new(0, 0.6 + (h - 2.6) / 2, 0), SAND, M.Sandstone)
	for k, y in { 0.25, 0.3, 0.75, 0.8 } do
		C(m, "Band", 0.4, 2.66, cf * CFrame.new(0, h * y, 0), if k % 2 == 0 then rgb(40, 70, 140) else rgb(170, 50, 30), M.SmoothPlastic, nc())
	end
	-- капитель-папирус расширяется кверху
	for k = 0, 3 do
		C(m, "Capital", 0.5, 2.8 + k * 0.5, cf * CFrame.new(0, h - 2 + k * 0.5, 0), if k == 3 then rgb(40, 110, 80) else SAND, M.Sandstone)
	end
	return m
end

-- стена с письменами: ряды значков, нарисованных плоско (cf — на стене, лицо в зал)
function X.glyphWall(parent, cf: CFrame, w: number, h: number, seed: number)
	local m = model(parent, "Glyphs")
	local slab = P(m, "GlyphSlab", Vector3.new(w, h, 0.2), cf * CFrame.new(0, h / 2, -0.1), SAND, M.Sandstone, nc())
	local f = canvas(slab, Enum.NormalId.Front, SAND)
	local r = Random.new(seed)
	local ink = { rgb(110, 70, 40), rgb(40, 70, 130), rgb(160, 50, 30) }
	local cols, rows = math.floor(w * 1.2), math.floor(h * 1.1)
	for i = 0, cols - 1 do
		shape(f, rgb(130, 96, 60), (i + 0.97) / cols, 0.5, 0.004, 0.96)
		for j = 0, rows - 1 do
			local x, y = (i + 0.5) / cols, (j + 0.5) / rows
			local c = ink[r:NextInteger(1, 3)]
			local k = r:NextInteger(1, 5)
			local sw, sh = 0.5 / cols, 0.5 / rows
			if k == 1 then
				shape(f, c, x, y, sw, sh * 0.5, 1) -- глаз
				shape(f, SAND, x, y, sw * 0.3, sh * 0.3, 1)
			elseif k == 2 then
				shape(f, c, x, y, sw * 0.2, sh) -- тростник
				shape(f, c, x + sw * 0.2, y - sh * 0.3, sw * 0.4, sh * 0.2)
			elseif k == 3 then
				shape(f, c, x, y + sh * 0.2, sw, sh * 0.25, 0.5) -- птица
				shape(f, c, x - sw * 0.3, y - sh * 0.2, sw * 0.3, sh * 0.3, 1)
			elseif k == 4 then
				shape(f, c, x, y - sh * 0.25, sw * 0.5, sh * 0.5, 1) -- анх
				shape(f, SAND, x, y - sh * 0.25, sw * 0.25, sh * 0.25, 1)
				shape(f, c, x, y + sh * 0.25, sw * 0.15, sh * 0.6)
				shape(f, c, x, y + sh * 0.05, sw * 0.7, sh * 0.12)
			else
				shape(f, c, x, y, sw * 0.8, sh * 0.15) -- волна
				shape(f, c, x, y + sh * 0.25, sw * 0.8, sh * 0.15)
			end
		end
	end
	return m
end

function X.canopic(parent, cf: CFrame, seed: number)
	local m = model(parent, "Canopic")
	local _, top = Props.plinth(m, cf, 2.4, 2.2)
	local heads = { rgb(40, 40, 40), rgb(196, 160, 90), rgb(120, 90, 60), rgb(210, 190, 150) }
	for k = 0, 3 do
		local c = top * CFrame.new(-0.85 + k * 0.57, 0, 0)
		C(m, "Jar", 0.9, 0.44, c * CFrame.new(0, 0.45, 0), rgb(220, 206, 176), M.Marble, nc())
		S(m, "JarHead", 0.42, c * CFrame.new(0, 1.05, 0), heads[(seed + k) % 4 + 1], M.Marble, nc())
	end
	return m
end

-- ---------------------------------------------------------------------------
-- Рим

function X.romanColumn(parent, cf: CFrame, h: number)
	local m = model(parent, "Column")
	local marble = rgb(222, 216, 204)
	P(m, "Plinth", Vector3.new(3.4, 0.5, 3.4), cf * CFrame.new(0, 0.25, 0), marble:Lerp(rgb(0, 0, 0), 0.1), M.Marble)
	C(m, "Torus", 0.5, 3, cf * CFrame.new(0, 0.75, 0), marble, M.Marble)
	C(m, "Shaft", h - 3, 2.4, cf * CFrame.new(0, 1 + (h - 3) / 2, 0), marble, M.Marble)
	-- каннелюры: тонкие тени по стволу
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		P(m, "Flute", Vector3.new(0.12, h - 3.4, 0.05), cf * CFrame.new(math.cos(a) * 1.21, 1 + (h - 3) / 2, math.sin(a) * 1.21) * CFrame.Angles(0, -a + math.pi / 2, 0), marble:Lerp(rgb(0, 0, 0), 0.18), M.Marble, nc())
	end
	-- коринфская капитель: листья и волюты
	C(m, "Bell", 1.2, 2.8, cf * CFrame.new(0, h - 1.6, 0), marble, M.Marble)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		S(m, "Leaf", 0.8, cf * CFrame.new(math.cos(a) * 1.3, h - 1.8, math.sin(a) * 1.3), marble:Lerp(rgb(0, 0, 0), 0.05), M.Marble, nc())
	end
	P(m, "Abacus", Vector3.new(3.4, 0.6, 3.4), cf * CFrame.new(0, h - 0.3, 0), marble, M.Marble)
	return m
end

function X.colosseum(parent, cf: CFrame, r: number)
	local m = model(parent, "Colosseum")
	local stone = rgb(196, 176, 140)
	local _, top = Props.plinth(m, cf, r * 2 + 1, 1.6, rgb(120, 110, 96))
	local n = 20
	for tier = 0, 2 do
		local y = 0.1 + tier * 1.3
		for k = 0, n - 1 do
			if not (tier == 2 and k % 5 == 0) then
				local a = k / n * math.pi * 2
				P(m, "Pier", Vector3.new(0.4, 1.1, 0.5), top * CFrame.new(math.cos(a) * r, y + 0.55, math.sin(a) * r) * CFrame.Angles(0, -a, 0), stone, M.Sandstone, nc())
				local a2 = (k + 0.5) / n * math.pi * 2
				P(m, "Lintel", Vector3.new(0.5, 0.2, r * 2 * math.pi / n + 0.1), top * CFrame.new(math.cos(a2) * r, y + 1.2, math.sin(a2) * r) * CFrame.Angles(0, -a2, 0), stone:Lerp(rgb(0, 0, 0), 0.1), M.Sandstone, nc())
			end
		end
	end
	C(m, "Arena", 0.1, r * 1.3, top * CFrame.new(0, 0.06, 0), rgb(214, 190, 140), M.Sand, nc())
	for k = 0, 2 do
		C(m, "Seats", 0.3, r * 1.3 + 0.5 + k * 0.5, top * CFrame.new(0, 0.2 + k * 0.3, 0), stone:Lerp(rgb(255, 255, 255), 0.1), M.Sandstone, nc())
	end
	return m
end

function X.legionary(parent, cf: CFrame)
	local m = model(parent, "Legionary")
	local red, steel = rgb(150, 26, 30), rgb(170, 172, 178)
	C(m, "Stand", 0.3, 2, cf * CFrame.new(0, 0.15, 0), rgb(50, 40, 32), M.Wood)
	for _, x in { -0.4, 0.4 } do
		P(m, "Leg", Vector3.new(0.5, 2.6, 0.5), cf * CFrame.new(x, 1.6, 0), rgb(150, 110, 80), M.SmoothPlastic, nc())
		P(m, "Sandal", Vector3.new(0.6, 0.3, 0.9), cf * CFrame.new(x, 0.46, -0.1), rgb(80, 50, 30), M.SmoothPlastic, nc())
	end
	P(m, "Tunic", Vector3.new(1.8, 1.2, 1), cf * CFrame.new(0, 3.2, 0), red, M.Fabric)
	for k = 0, 3 do
		P(m, "Lorica", Vector3.new(1.9, 0.36, 1.1), cf * CFrame.new(0, 3.9 + k * 0.38, 0), steel:Lerp(rgb(0, 0, 0), k % 2 * 0.15), M.Metal, nc())
	end
	for _, x in { -1.2, 1.2 } do
		P(m, "Pauldron", Vector3.new(0.9, 0.4, 1.1), cf * CFrame.new(x, 5.4, 0), steel, M.Metal, nc())
		P(m, "Arm", Vector3.new(0.45, 1.8, 0.45), cf * CFrame.new(x * 1.05, 4.4, 0), rgb(150, 110, 80), M.SmoothPlastic, nc())
	end
	S(m, "Head", 1, cf * CFrame.new(0, 6.1, 0), rgb(150, 110, 80), M.SmoothPlastic, nc())
	S(m, "Helmet", 1.15, cf * CFrame.new(0, 6.3, 0.05), steel, M.Metal, nc())
	P(m, "Crest", Vector3.new(0.2, 0.6, 1.4), cf * CFrame.new(0, 7, 0.05), red, M.Fabric, nc())
	-- скутум: высокий изогнутый щит
	local scutum = P(m, "Scutum", Vector3.new(2.2, 3.4, 0.2), cf * CFrame.new(-1.4, 3.6, -0.7) * CFrame.Angles(0, 0.3, 0), red, M.SmoothPlastic, nc())
	local f = canvas(scutum, Enum.NormalId.Front, red)
	shape(f, GOLD, 0.5, 0.5, 0.3, 0.3 * 2.2 / 3.4, 1)
	shape(f, GOLD, 0.5, 0.5, 0.06, 0.9)
	shape(f, GOLD, 0.5, 0.5, 0.9, 0.04)
	C(m, "Pilum", 6.4, 0.12, cf * CFrame.new(1.5, 3.4, 0), rgb(110, 80, 50), M.Wood, nc())
	P(m, "PilumTip", Vector3.new(0.12, 1.4, 0.12), cf * CFrame.new(1.5, 7.3, 0), steel, M.Metal, nc())
	return m
end

-- мозаика на полу: плоский узор на тонкой плите
function X.mosaic(parent, cf: CFrame, w: number, l: number, seed: number)
	local m = model(parent, "Mosaic")
	local slab = P(m, "Mosaic", Vector3.new(w, 0.04, l), cf * CFrame.new(0, 0.02, 0), rgb(230, 220, 196), M.SmoothPlastic, nc())
	local f = canvas(slab, Enum.NormalId.Top, rgb(230, 220, 196))
	local dark, red, blue = rgb(40, 36, 34), rgb(160, 60, 40), rgb(50, 90, 130)
	shape(f, dark, 0.5, 0.03, 1, 0.025)
	shape(f, dark, 0.5, 0.97, 1, 0.025)
	shape(f, dark, 0.03, 0.5, 0.025, 1)
	shape(f, dark, 0.97, 0.5, 0.025, 1)
	-- меандр по краю
	for k = 0, 17 do
		shape(f, red, (k + 0.5) / 18, 0.08, 0.025, 0.05)
		shape(f, red, (k + 0.5) / 18, 0.92, 0.025, 0.05)
	end
	shape(f, blue, 0.5, 0.5, 0.5, 0.5 * w / l, 1)
	shape(f, rgb(230, 220, 196), 0.5, 0.5, 0.42, 0.42 * w / l, 1)
	for k = 0, 7 do
		shape(f, if k % 2 == 0 then red else dark, 0.5, 0.5, 0.36, 0.05, nil, k * 22.5 + seed % 10)
	end
	shape(f, GOLD, 0.5, 0.5, 0.1, 0.1 * w / l, 1)
	return m
end

function X.aqueduct(parent, cf: CFrame, len: number)
	local m = model(parent, "Aqueduct")
	local _, top = Props.plinth(m, cf, 2.6, 1.4, rgb(120, 110, 96))
	local _t = top
	local stone = rgb(196, 176, 140)
	local base = cf * CFrame.new(0, 1.4, 0)
	P(m, "Deck", Vector3.new(1.4, 0.4, len), base * CFrame.new(0, 4.2, 0), stone, M.Sandstone)
	local n = math.floor(len / 2)
	for k = 0, n do
		P(m, "Pier", Vector3.new(1.2, 4, 0.5), base * CFrame.new(0, 2, -len / 2 + k * len / n), stone, M.Sandstone, nc())
	end
	return m
end

-- ---------------------------------------------------------------------------
-- рыцари

function X.roundTable(parent, cf: CFrame, r: number, n: number)
	local m = model(parent, "RoundTable")
	C(m, "Top", 0.4, r * 2, cf * CFrame.new(0, 2.8, 0), rgb(90, 58, 34), M.WoodPlanks)
	C(m, "Leg", 2.6, 1.6, cf * CFrame.new(0, 1.3, 0), rgb(60, 40, 26), M.Wood)
	local top = P(m, "Inlay", Vector3.new(r * 1.4, 0.02, r * 1.4), cf * CFrame.new(0, 3.01, 0), rgb(90, 58, 34), M.Wood, nc())
	local f = canvas(top, Enum.NormalId.Top, rgb(90, 58, 34))
	f.BackgroundTransparency = 1
	for k = 0, n - 1 do
		shape(f, if k % 2 == 0 then rgb(30, 90, 50) else rgb(230, 220, 196), 0.5, 0.5, 0.06, 1, nil, k * 180 / n)
	end
	shape(f, rgb(170, 30, 40), 0.5, 0.5, 0.25, 0.25, 1)
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2
		local c = cf * CFrame.new(math.cos(a) * (r + 1), 0, math.sin(a) * (r + 1)) * CFrame.Angles(0, -a - math.pi / 2, 0)
		P(m, "Seat", Vector3.new(1.6, 0.3, 1.6), c * CFrame.new(0, 1.8, 0), rgb(70, 46, 28), M.Wood)
		P(m, "Back", Vector3.new(1.5, 3, 0.25), c * CFrame.new(0, 3.3, 0.7), rgb(70, 46, 28), M.Wood, nc())
		for _, dx in { -0.65, 0.65 } do
			for _, dz in { -0.65, 0.65 } do
				P(m, "ChairLeg", Vector3.new(0.2, 1.65, 0.2), c * CFrame.new(dx, 0.825, dz), rgb(60, 40, 26), M.Wood, nc())
			end
		end
	end
	return m
end

function X.throne(parent, cf: CFrame)
	local m = model(parent, "Throne")
	P(m, "Dais", Vector3.new(7, 0.6, 5), cf * CFrame.new(0, 0.3, 0), rgb(110, 20, 30), M.Fabric)
	P(m, "Step", Vector3.new(7, 0.3, 1.2), cf * CFrame.new(0, 0.15, -3.1), rgb(110, 20, 30), M.Fabric)
	P(m, "Seat", Vector3.new(3, 1.6, 2.6), cf * CFrame.new(0, 1.4, 0.4), rgb(150, 110, 40), M.Wood)
	P(m, "Cushion", Vector3.new(2.6, 0.3, 2.2), cf * CFrame.new(0, 2.35, 0.3), rgb(140, 20, 34), M.Fabric, nc())
	P(m, "Back", Vector3.new(3.2, 5, 0.5), cf * CFrame.new(0, 4.5, 1.55), rgb(150, 110, 40), M.Wood)
	P(m, "BackPad", Vector3.new(2.2, 3.6, 0.1), cf * CFrame.new(0, 4.3, 1.2), rgb(140, 20, 34), M.Fabric, nc())
	for _, sx in { -1, 1 } do
		P(m, "Arm", Vector3.new(0.4, 1.4, 2.6), cf * CFrame.new(sx * 1.5, 2.9, 0.4), rgb(150, 110, 40), M.Wood, nc())
		S(m, "Knob", 0.6, cf * CFrame.new(sx * 1.5, 7.2, 1.5), GOLD, M.Metal, nc())
	end
	P(m, "Crown", Vector3.new(1.4, 0.8, 0.3), cf * CFrame.new(0, 7.3, 1.5), GOLD, M.Metal, nc())
	return m
end

-- конь в попоне с рыцарем в доспехах
function X.knightHorse(parent, cf: CFrame, seed: number)
	local m = model(parent, "KnightHorse")
	local horse, cloth = rgb(60, 44, 34), if seed % 2 == 0 then rgb(30, 50, 120) else rgb(130, 20, 30)
	local steel = rgb(160, 164, 170)
	P(m, "Plinth", Vector3.new(4.4, 0.6, 8.4), cf * CFrame.new(0, 0.3, 0), rgb(110, 104, 96), M.Marble)
	local b = cf * CFrame.new(0, 0.6, 0)
	for _, sx in { -0.8, 0.8 } do
		for _, z in { -2.4, 2.4 } do
			P(m, "HorseLeg", Vector3.new(0.6, 3.6, 0.6), b * CFrame.new(sx, 1.8, z), horse, M.SmoothPlastic, nc())
			P(m, "Hoof", Vector3.new(0.7, 0.35, 0.8), b * CFrame.new(sx, 0.18, z - 0.05), rgb(30, 26, 24), M.SmoothPlastic, nc())
		end
	end
	P(m, "HorseBody", Vector3.new(2.2, 2.2, 5.8), b * CFrame.new(0, 4.4, 0), horse, M.SmoothPlastic)
	P(m, "Neck", Vector3.new(1.3, 2.6, 1.4), b * CFrame.new(0, 5.8, -2.9) * CFrame.Angles(-0.5, 0, 0), horse, M.SmoothPlastic, nc())
	P(m, "HorseHead", Vector3.new(1.1, 1.1, 2.4), b * CFrame.new(0, 6.6, -4.1) * CFrame.Angles(0.5, 0, 0), horse, M.SmoothPlastic, nc())
	P(m, "Chanfron", Vector3.new(1.15, 0.5, 2.2), b * CFrame.new(0, 7.0, -4.2) * CFrame.Angles(0.5, 0, 0), steel, M.Metal, nc())
	P(m, "Tail", Vector3.new(0.4, 2.4, 0.4), b * CFrame.new(0, 3.8, 3.1) * CFrame.Angles(0.3, 0, 0), rgb(30, 22, 18), M.SmoothPlastic, nc())
	-- попона с гербом свисает по бокам
	for _, sx in { -1, 1 } do
		local cap = P(m, "Caparison", Vector3.new(0.08, 2.6, 6.2), b * CFrame.new(sx * 1.16, 3.7, 0), cloth, M.Fabric, nc())
		local f = canvas(cap, if sx < 0 then Enum.NormalId.Left else Enum.NormalId.Right, cloth)
		shape(f, GOLD, 0.5, 0.45, 0.3, 0.3 * 6.2 / 2.6 * 0.4, 1)
		shape(f, GOLD, 0.5, 0.95, 1, 0.06)
	end
	P(m, "Saddle", Vector3.new(2.3, 0.5, 1.8), b * CFrame.new(0, 5.7, 0.2), rgb(80, 50, 30), M.SmoothPlastic, nc())
	-- всадник
	for _, sx in { -0.9, 0.9 } do
		P(m, "RiderLeg", Vector3.new(0.5, 2.2, 0.6), b * CFrame.new(sx * 1.25, 5, 0.1), steel, M.Metal, nc())
	end
	P(m, "RiderBody", Vector3.new(1.7, 2.2, 1), b * CFrame.new(0, 7.1, 0.2), steel, M.Metal)
	P(m, "Surcoat", Vector3.new(1.75, 1.6, 1.05), b * CFrame.new(0, 6.7, 0.2), cloth, M.Fabric, nc())
	S(m, "RiderHelm", 1.1, b * CFrame.new(0, 8.7, 0.2), steel, M.Metal, nc())
	P(m, "Visor", Vector3.new(0.7, 0.12, 0.1), b * CFrame.new(0, 8.75, -0.32), rgb(10, 10, 10), M.SmoothPlastic, nc())
	C(m, "Lance", 9, 0.25, b * CFrame.new(1.2, 7.4, -2.6) * CFrame.Angles(math.rad(-80), 0, 0), rgb(200, 190, 170), M.Wood, nc())
	return m
end

-- ---------------------------------------------------------------------------
-- Эстония

function X.windmill(parent, cf: CFrame)
	local m = model(parent, "Windmill")
	local wood = rgb(110, 80, 56)
	P(m, "Base", Vector3.new(4, 0.8, 4), cf * CFrame.new(0, 0.4, 0), rgb(120, 116, 110), M.Cobblestone)
	for _, a in { 0.5, -0.5 } do
		rod(m, "Brace", (cf * CFrame.new(-1.6, 0.8, 1.6 * a * 2)).Position, (cf * CFrame.new(0, 3, 0)).Position, 0.3, wood, M.Wood, nc())
	end
	C(m, "Post", 3.4, 0.6, cf * CFrame.new(0, 2.5, 0), wood, M.Wood)
	P(m, "Body", Vector3.new(3, 3.6, 3.2), cf * CFrame.new(0, 5.6, 0), rgb(130, 96, 66), M.WoodPlanks)
	P(m, "Roof", Vector3.new(3.4, 0.4, 3.6), cf * CFrame.new(0, 7.65, 0), rgb(70, 60, 50), M.WoodPlanks)
	P(m, "RoofRidge", Vector3.new(3.2, 0.9, 2.4), cf * CFrame.new(0, 8.2, 0), rgb(70, 60, 50), M.WoodPlanks, nc())
	P(m, "Tail", Vector3.new(0.3, 0.3, 4), cf * CFrame.new(0, 4.2, 3), wood, M.Wood, nc())
	local hub = cf * CFrame.new(0, 6.4, -1.9)
	C(m, "Axle", 0.6, 0.5, hub * CFrame.Angles(math.pi / 2, 0, 0), wood, M.Wood, nc())
	for k = 0, 3 do
		local a = k * math.pi / 2 + 0.4
		local sail = hub * CFrame.Angles(0, 0, a)
		P(m, "Sail", Vector3.new(0.2, 4.4, 0.1), sail * CFrame.new(0, 2.3, -0.2), wood, M.Wood, nc())
		P(m, "SailCloth", Vector3.new(1.2, 3.6, 0.06), sail * CFrame.new(0.65, 2.6, -0.2), rgb(220, 210, 190), M.Fabric, nc())
	end
	return m
end

-- башня старого города: каменная, с красной конической крышей
function X.oldTower(parent, cf: CFrame, h: number, seed: number, s: number?)
	local m = model(parent, "OldTower")
	s = s or 1
	cf = cf * CFrame.new(0, 0, 0)
	local stone = rgb(190, 180, 160):Lerp(rgb(150, 140, 120), (seed % 3) / 3)
	C(m, "Tower", h, 2.6 * s, cf * CFrame.new(0, h / 2, 0), stone, M.Limestone)
	for k = 0, 2 do
		P(m, "Window", Vector3.new(0.4 * s, 0.7 * s, 0.1), cf * CFrame.new(0, h * (0.35 + k * 0.2), -1.3 * s - 0.02), rgb(30, 30, 36), M.SmoothPlastic, nc())
	end
	for k = 0, 5 do
		C(m, "Roof", 0.5 * s, (3 - k * 0.5) * s, cf * CFrame.new(0, h + (0.25 + k * 0.5) * s, 0), rgb(170, 60, 40), M.Slate, nc())
	end
	C(m, "Spire", 0.8 * s, 0.12, cf * CFrame.new(0, h + 3.4 * s, 0), GOLD, M.Metal, nc())
	return m
end

-- макет Таллина на столе: стена с башнями и шпиль
function X.oldTown(parent, cf: CFrame, seed: number)
	local m = model(parent, "OldTown")
	P(m, "Table", Vector3.new(10, 2.6, 7), cf * CFrame.new(0, 1.3, 0), rgb(80, 60, 44), M.Wood)
	local top = cf * CFrame.new(0, 2.6, 0)
	P(m, "Ground", Vector3.new(9.6, 0.1, 6.6), top * CFrame.new(0, 0.05, 0), rgb(70, 100, 60), M.Grass, nc())
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		X.oldTower(m, top * CFrame.new(math.cos(a) * 3.6, 0.1, math.sin(a) * 2.4) * CFrame.Angles(0, -a + math.pi / 2, 0), 2.4 + (k + seed) % 3 * 0.6, k, 0.5)
	end
	for k = 0, 5 do
		local a0, a1 = k / 6 * math.pi * 2, (k + 1) / 6 * math.pi * 2
		rod(m, "TownWall", (top * CFrame.new(math.cos(a0) * 3.6, 0.6, math.sin(a0) * 2.4)).Position, (top * CFrame.new(math.cos(a1) * 3.6, 0.6, math.sin(a1) * 2.4)).Position, 0.9, rgb(180, 170, 150), M.Limestone, nc())
	end
	-- церковь со шпилем и домики
	P(m, "Church", Vector3.new(1.2, 1.8, 2.4), top * CFrame.new(0.6, 1, 0), rgb(220, 214, 200), M.Plaster, nc())
	for k = 0, 4 do
		C(m, "Steeple", 0.6, 1 - k * 0.18, top * CFrame.new(0.6, 2.2 + k * 0.6, -0.8), rgb(40, 70, 60), M.Slate, nc())
	end
	for k = 0, 5 do
		P(m, "House", Vector3.new(0.8, 1, 0.8), top * CFrame.new(-2.4 + (k % 3) * 0.9, 0.6, -0.8 + math.floor(k / 3) * 1.4), ({ rgb(230, 200, 140), rgb(200, 120, 90), rgb(220, 220, 210) })[k % 3 + 1], M.Plaster, nc())
	end
	return m
end

-- манекен в народном костюме: полосатая юбка, белая рубаха, венок
function X.folkCostume(parent, cf: CFrame, seed: number)
	local m = model(parent, "FolkCostume")
	C(m, "Stand", 0.3, 1.8, cf * CFrame.new(0, 0.15, 0), rgb(50, 40, 32), M.Wood)
	local stripes = { rgb(190, 40, 40), rgb(40, 90, 50), rgb(230, 190, 60), rgb(30, 60, 130), rgb(20, 20, 20) }
	for k = 0, 7 do
		C(m, "Skirt", 0.4, 2.2 - k * 0.08, cf * CFrame.new(0, 0.6 + k * 0.4, 0), stripes[(k + seed) % #stripes + 1], M.Fabric)
	end
	P(m, "Apron", Vector3.new(1.1, 2.4, 0.06), cf * CFrame.new(0, 1.9, -1.0), rgb(240, 236, 226), M.Fabric, nc())
	P(m, "Blouse", Vector3.new(1.5, 1.6, 0.9), cf * CFrame.new(0, 4.2, 0), rgb(245, 242, 234), M.Fabric)
	P(m, "Vest", Vector3.new(1.55, 1, 0.95), cf * CFrame.new(0, 4.3, 0), rgb(40, 40, 50), M.Fabric, nc())
	S(m, "Head", 0.9, cf * CFrame.new(0, 5.5, 0), rgb(200, 190, 176), M.SmoothPlastic, nc())
	C(m, "Wreath", 0.2, 1.1, cf * CFrame.new(0, 5.9, 0), rgb(60, 120, 60), M.Grass, nc())
	return m
end

function X.boat(parent, cf: CFrame)
	local m = model(parent, "Boat")
	local wood = rgb(110, 76, 48)
	for _, sx in { -1, 1 } do
		P(m, "Hull", Vector3.new(0.3, 1.2, 6), cf * CFrame.new(sx * 0.9, 1.4, 0) * CFrame.Angles(0, 0, sx * 0.25), wood, M.WoodPlanks)
	end
	P(m, "Keel", Vector3.new(1.4, 0.3, 6.2), cf * CFrame.new(0, 0.85, 0), wood, M.WoodPlanks)
	for _, z in { -3.2, 3.2 } do
		P(m, "Stem", Vector3.new(0.3, 1.8, 0.4), cf * CFrame.new(0, 1.65, z), wood, M.Wood, nc())
	end
	for _, z in { -1, 1 } do
		P(m, "Thwart", Vector3.new(1.9, 0.15, 0.5), cf * CFrame.new(0, 1.6, z), wood, M.Wood, nc())
	end
	rod(m, "Oar", (cf * CFrame.new(-1.6, 1.8, -1)).Position, (cf * CFrame.new(2.4, 1.2, 1)).Position, 0.15, rgb(180, 150, 110), M.Wood, nc())
	for _, z in { -2, 2 } do
		P(m, "Trestle", Vector3.new(2.4, 0.7, 0.4), cf * CFrame.new(0, 0.35, z), rgb(60, 44, 32), M.Wood)
	end
	return m
end

-- ---------------------------------------------------------------------------
-- Россия

function X.matryoshka(parent, cf: CFrame, seed: number)
	local m = model(parent, "Matryoshka")
	local _, top = Props.plinth(m, cf, 4, 2.4)
	local scarf = { rgb(200, 40, 40), rgb(230, 180, 40), rgb(40, 110, 60), rgb(40, 80, 160) }
	for k = 0, 4 do
		local s = 1 - k * 0.17
		local c = top * CFrame.new(-1.4 + k * 0.75 - k * k * 0.03, 0, 0)
		C(m, "DollBody", 1.3 * s, 1.1 * s, c * CFrame.new(0, 0.65 * s, 0), scarf[(k + seed) % 4 + 1], M.SmoothPlastic, nc())
		S(m, "DollHead", 0.95 * s, c * CFrame.new(0, 1.55 * s, 0), scarf[(k + seed) % 4 + 1], M.SmoothPlastic, nc())
		C(m, "DollFace", 0.05, 0.6 * s, c * CFrame.new(0, 1.55 * s, -0.45 * s) * CFrame.Angles(math.pi / 2, 0, 0), rgb(240, 214, 190), M.SmoothPlastic, nc())
		C(m, "Apron", 0.05, 0.7 * s, c * CFrame.new(0, 0.6 * s, -0.53 * s) * CFrame.Angles(math.pi / 2, 0, 0), rgb(250, 246, 236), M.SmoothPlastic, nc())
	end
	return m
end

function X.samovar(parent, cf: CFrame)
	local m = model(parent, "Samovar")
	local brass = rgb(200, 150, 70)
	local _, top = Props.plinth(m, cf, 2.4, 2.4)
	C(m, "Foot", 0.3, 1.2, top * CFrame.new(0, 0.15, 0), brass, M.Metal, nc())
	C(m, "Stem", 0.4, 0.6, top * CFrame.new(0, 0.5, 0), brass, M.Metal, nc())
	C(m, "Body", 1.4, 1.6, top * CFrame.new(0, 1.4, 0), brass, M.Metal, nc())
	C(m, "Shoulder", 0.3, 1.3, top * CFrame.new(0, 2.25, 0), brass, M.Metal, nc())
	C(m, "Chimney", 0.6, 0.4, top * CFrame.new(0, 2.7, 0), brass, M.Metal, nc())
	C(m, "Teapot", 0.6, 0.8, top * CFrame.new(0, 3.3, 0), rgb(240, 240, 236), M.SmoothPlastic, nc())
	P(m, "Tap", Vector3.new(0.15, 0.15, 0.6), top * CFrame.new(0, 1.1, -0.95), brass, M.Metal, nc())
	for _, sx in { -1, 1 } do
		P(m, "Handle", Vector3.new(0.6, 0.15, 0.15), top * CFrame.new(sx * 1, 2.1, 0), rgb(30, 24, 20), M.Wood, nc())
	end
	return m
end

-- макет собора с луковичными куполами
function X.onionChurch(parent, cf: CFrame)
	local m = model(parent, "Cathedral")
	P(m, "Base", Vector3.new(8, 0.6, 8), cf * CFrame.new(0, 0.3, 0), rgb(110, 104, 96), M.Marble)
	local top = cf * CFrame.new(0, 0.6, 0)
	P(m, "Hall", Vector3.new(5, 3, 5), top * CFrame.new(0, 1.5, 0), rgb(170, 60, 50), M.Brick)
	local domes = { { 0, 0, 2.2, 6.4, rgb(230, 190, 60) }, { -2, -2, 1.2, 4.2, rgb(40, 120, 70) }, { 2, -2, 1.2, 4.6, rgb(200, 50, 50) }, { -2, 2, 1.2, 4.4, rgb(40, 80, 160) }, { 2, 2, 1.2, 4, rgb(230, 120, 40) } }
	for _, d in domes do
		local x, z, r, h, col = d[1], d[2], d[3], d[4], d[5]
		C(m, "Drum", h - 1.2, r * 0.8, top * CFrame.new(x, (h - 1.2) / 2, z), rgb(236, 226, 206), M.Plaster, nc())
		S(m, "Onion", r * 1.1, top * CFrame.new(x, h, z), col, M.SmoothPlastic, nc())
		C(m, "OnionTip", r * 0.7, r * 0.3, top * CFrame.new(x, h + r * 0.75, z), col, M.SmoothPlastic, nc())
		P(m, "Cross", Vector3.new(0.1, 0.9, 0.1), top * CFrame.new(x, h + r * 1.4, z), GOLD, M.Metal, nc())
		P(m, "CrossBar", Vector3.new(0.5, 0.1, 0.13), top * CFrame.new(x, h + r * 1.5, z), GOLD, M.Metal, nc())
	end
	return m
end

function X.balalaika(parent, cf: CFrame)
	local m = model(parent, "Balalaika")
	local wood = rgb(170, 110, 60)
	P(m, "Stand", Vector3.new(1.6, 0.4, 1), cf * CFrame.new(0, 0.2, 0), rgb(60, 44, 30), M.Wood)
	local b = cf * CFrame.new(0, 1.6, 0) * CFrame.Angles(-0.15, 0, 0)
	-- треугольный корпус из двух клиньев
	for _, yaw in { math.pi / 2, -math.pi / 2 } do
		local w = Instance.new("WedgePart")
		w.Name = "BalalaikaBody"
		w.Anchored = true
		w.Size = Vector3.new(0.4, 1.8, 1)
		w.CFrame = b * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -0.5)
		w.Color = wood
		w.Material = M.Wood
		w.Parent = m
	end
	P(m, "Neck", Vector3.new(0.25, 2.6, 0.15), b * CFrame.new(0, 2.1, 0), rgb(40, 28, 20), M.Wood, nc())
	P(m, "Head", Vector3.new(0.4, 0.6, 0.15), b * CFrame.new(0, 3.6, 0), wood, M.Wood, nc())
	return m
end

-- ---------------------------------------------------------------------------
-- Англия

function X.phoneBox(parent, cf: CFrame)
	local m = model(parent, "PhoneBox")
	local red = rgb(190, 20, 24)
	P(m, "Base", Vector3.new(3.4, 0.4, 3.4), cf * CFrame.new(0, 0.2, 0), red, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			P(m, "Post", Vector3.new(0.4, 7.4, 0.4), cf * CFrame.new(sx * 1.45, 4.1, sz * 1.45), red, M.SmoothPlastic)
		end
	end
	for k = 0, 3 do
		local face = cf * CFrame.Angles(0, k * math.pi / 2, 0)
		local glass = P(m, "Glass", Vector3.new(2.5, 6, 0.1), face * CFrame.new(0, 4, -1.45), rgb(200, 220, 230), M.Glass, nc({ Transparency = 0.4 }))
		local f = canvas(glass, Enum.NormalId.Front, red)
		f.BackgroundTransparency = 1
		for i = 1, 2 do
			shape(f, red, i / 3, 0.5, 0.06, 1)
		end
		for j = 1, 7 do
			shape(f, red, 0.5, j / 8, 1, 0.025)
		end
		local sign = P(m, "Sign", Vector3.new(2.5, 0.5, 0.1), face * CFrame.new(0, 7.35, -1.5), rgb(30, 30, 30), M.SmoothPlastic, nc())
		local _s = sign
	end
	P(m, "Roof", Vector3.new(3.4, 0.5, 3.4), cf * CFrame.new(0, 8, 0), red, M.SmoothPlastic)
	P(m, "RoofTop", Vector3.new(2.8, 0.5, 2.8), cf * CFrame.new(0, 8.45, 0), red, M.SmoothPlastic, nc())
	S(m, "Crown", 0.6, cf * CFrame.new(0, 8.9, 0), GOLD, M.Metal, nc())
	return m
end

-- макет часовой башни с циферблатами на четырёх сторонах
function X.clockTower(parent, cf: CFrame, h: number)
	local m = model(parent, "ClockTower")
	local stone = rgb(196, 180, 140)
	P(m, "Base", Vector3.new(3.6, 0.6, 3.6), cf * CFrame.new(0, 0.3, 0), rgb(110, 104, 96), M.Marble)
	P(m, "Shaft", Vector3.new(2.4, h, 2.4), cf * CFrame.new(0, 0.6 + h / 2, 0), stone, M.Sandstone)
	for k = 0, 5 do
		P(m, "Rib", Vector3.new(2.5, 0.12, 2.5), cf * CFrame.new(0, 1.5 + k * h / 6, 0), stone:Lerp(rgb(0, 0, 0), 0.2), M.Sandstone, nc())
	end
	P(m, "ClockStage", Vector3.new(3, 3, 3), cf * CFrame.new(0, h + 2.1, 0), stone, M.Sandstone)
	for k = 0, 3 do
		Props.wallClock(m, cf * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, h + 2.1, -1.5), 1.1, k * 5 + 2)
	end
	for k = 0, 4 do
		P(m, "Spire", Vector3.new(2.6 - k * 0.5, 0.8, 2.6 - k * 0.5), cf * CFrame.new(0, h + 4 + k * 0.8, 0), rgb(60, 70, 60), M.Slate, nc())
	end
	return m
end

function X.bus(parent, cf: CFrame)
	local m = model(parent, "Bus")
	local red = rgb(190, 20, 24)
	P(m, "Plinth", Vector3.new(4.4, 0.4, 10.4), cf * CFrame.new(0, 0.2, 0), rgb(60, 60, 60), M.Concrete)
	P(m, "Lower", Vector3.new(3.4, 2.6, 9.6), cf * CFrame.new(0, 2.1, 0), red, M.SmoothPlastic)
	P(m, "Upper", Vector3.new(3.4, 2.3, 9.4), cf * CFrame.new(0, 4.6, 0.1), red, M.SmoothPlastic)
	P(m, "Roof", Vector3.new(3.3, 0.2, 9.3), cf * CFrame.new(0, 5.85, 0.1), rgb(220, 220, 214), M.SmoothPlastic, nc())
	for _, sx in { -1, 1 } do
		for _, y in { 2.6, 4.9 } do
			local win = P(m, "Windows", Vector3.new(0.05, 0.9, 8.6), cf * CFrame.new(sx * 1.725, y, 0), rgb(40, 50, 60), M.Glass, nc())
			local _w = win
		end
		for _, z in { -3.2, 3.2 } do
			C(m, "Wheel", 0.5, 1.4, cf * CFrame.new(sx * 1.55, 0.95, z) * CFrame.Angles(0, 0, 0), rgb(20, 20, 20), M.SmoothPlastic, nc())
		end
	end
	P(m, "Windscreen", Vector3.new(3, 1.2, 0.05), cf * CFrame.new(0, 2.8, -4.82), rgb(40, 50, 60), M.Glass, nc())
	return m
end

-- гвардеец: красный мундир и высокая меховая шапка
function X.guard(parent, cf: CFrame)
	local m = model(parent, "Guard")
	C(m, "Stand", 0.3, 1.8, cf * CFrame.new(0, 0.15, 0), rgb(40, 36, 32), M.Wood)
	for _, x in { -0.4, 0.4 } do
		P(m, "Leg", Vector3.new(0.55, 2.8, 0.6), cf * CFrame.new(x, 1.7, 0), rgb(20, 20, 30), M.Fabric, nc())
	end
	P(m, "Tunic", Vector3.new(1.8, 2.4, 1), cf * CFrame.new(0, 4.3, 0), rgb(190, 20, 30), M.Fabric)
	P(m, "Belt", Vector3.new(1.85, 0.3, 1.05), cf * CFrame.new(0, 3.4, 0), rgb(240, 240, 236), M.Fabric, nc())
	for k = 0, 4 do
		S(m, "Button", 0.16, cf * CFrame.new(0, 3.8 + k * 0.4, -0.52), GOLD, M.Metal, nc())
	end
	for _, x in { -1.15, 1.15 } do
		P(m, "Arm", Vector3.new(0.5, 2.2, 0.55), cf * CFrame.new(x, 4.3, 0), rgb(190, 20, 30), M.Fabric, nc())
	end
	S(m, "Head", 0.95, cf * CFrame.new(0, 6, 0), rgb(220, 190, 160), M.SmoothPlastic, nc())
	C(m, "Bearskin", 1.8, 1.2, cf * CFrame.new(0, 7.2, 0.05), rgb(20, 18, 18), M.Fabric, nc())
	C(m, "Musket", 4.4, 0.16, cf * CFrame.new(1.45, 4.8, -0.2), rgb(80, 56, 36), M.Wood, nc())
	return m
end

-- ---------------------------------------------------------------------------
-- Франция

function X.eiffel(parent, cf: CFrame, h: number)
	local m = model(parent, "Eiffel")
	local iron = rgb(110, 84, 60)
	P(m, "Base", Vector3.new(h * 0.5, 0.5, h * 0.5), cf * CFrame.new(0, 0.25, 0), rgb(120, 116, 110), M.Marble)
	local b = cf * CFrame.new(0, 0.5, 0)
	local foot = h * 0.2
	local stage1, stage2 = h * 0.28, h * 0.55
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local p0 = (b * CFrame.new(sx * foot, 0, sz * foot)).Position
			local p1 = (b * CFrame.new(sx * foot * 0.45, stage1, sz * foot * 0.45)).Position
			local p2 = (b * CFrame.new(sx * foot * 0.18, stage2, sz * foot * 0.18)).Position
			local p3 = (b * CFrame.new(0, h, 0)).Position
			rod(m, "Leg", p0, p1, 0.4, iron, M.Metal, nc())
			rod(m, "Leg", p1, p2, 0.3, iron, M.Metal, nc())
			rod(m, "Leg", p2, p3, 0.2, iron, M.Metal, nc())
			-- раскосы
			rod(m, "Lattice", p0, (b * CFrame.new(-sx * foot * 0.45, stage1, sz * foot * 0.45)).Position, 0.08, iron, M.Metal, nc())
		end
	end
	P(m, "Platform", Vector3.new(foot * 1.1, 0.3, foot * 1.1), b * CFrame.new(0, stage1, 0), iron, M.Metal, nc())
	P(m, "Platform", Vector3.new(foot * 0.5, 0.25, foot * 0.5), b * CFrame.new(0, stage2, 0), iron, M.Metal, nc())
	-- арки между ногами
	for k = 0, 3 do
		local face = b * CFrame.Angles(0, k * math.pi / 2, 0)
		rod(m, "Arch", (face * CFrame.new(-foot * 0.75, stage1 * 0.5, -foot * 0.75)).Position, (face * CFrame.new(0, stage1 * 0.75, -foot * 0.62)).Position, 0.1, iron, M.Metal, nc())
		rod(m, "Arch", (face * CFrame.new(0, stage1 * 0.75, -foot * 0.62)).Position, (face * CFrame.new(foot * 0.75, stage1 * 0.5, -foot * 0.75)).Position, 0.1, iron, M.Metal, nc())
	end
	C(m, "Antenna", h * 0.12, 0.08, b * CFrame.new(0, h + h * 0.06, 0), iron, M.Metal, nc())
	return m
end

function X.triumphArch(parent, cf: CFrame)
	local m = model(parent, "TriumphArch")
	local stone = rgb(220, 210, 190)
	P(m, "Base", Vector3.new(7.4, 0.5, 4.4), cf * CFrame.new(0, 0.25, 0), rgb(120, 116, 110), M.Marble)
	for _, sx in { -1, 1 } do
		P(m, "Pier", Vector3.new(2.2, 5, 3.6), cf * CFrame.new(sx * 2.4, 3, 0), stone, M.Limestone)
		P(m, "Relief", Vector3.new(1.4, 2, 0.1), cf * CFrame.new(sx * 2.4, 2.8, -1.85), stone:Lerp(rgb(0, 0, 0), 0.15), M.Limestone, nc())
	end
	P(m, "Attic", Vector3.new(7, 2.4, 3.6), cf * CFrame.new(0, 6.7, 0), stone, M.Limestone)
	P(m, "Cornice", Vector3.new(7.4, 0.4, 4), cf * CFrame.new(0, 5.75, 0), stone:Lerp(rgb(0, 0, 0), 0.1), M.Limestone, nc())
	P(m, "ArchTop", Vector3.new(2.6, 0.7, 3.6), cf * CFrame.new(0, 5.15, 0), stone, M.Limestone, nc())
	return m
end

-- мольберт с картиной
function X.easel(parent, cf: CFrame, seed: number)
	local m = model(parent, "Easel")
	local wood = rgb(130, 90, 56)
	for _, sx in { -1, 1 } do
		rod(m, "EaselLeg", (cf * CFrame.new(sx * 1.2, 0, -0.5)).Position, (cf * CFrame.new(sx * 0.3, 6, 0)).Position, 0.18, wood, M.Wood, nc())
	end
	rod(m, "EaselLeg", (cf * CFrame.new(0, 0, 1.6)).Position, (cf * CFrame.new(0, 5.6, 0.1)).Position, 0.18, wood, M.Wood, nc())
	P(m, "Ledge", Vector3.new(3, 0.2, 0.5), cf * CFrame.new(0, 2.2, -0.3), wood, M.Wood, nc())
	Props.painting(m, cf * CFrame.new(0, 3.9, -0.15) * CFrame.Angles(0.1, 0, 0) * CFrame.new(0, 0, 0.12), 2.8, 3.2, seed)
	return m
end

-- ---------------------------------------------------------------------------
-- Япония

function X.torii(parent, cf: CFrame, w: number)
	local m = model(parent, "Torii")
	local red = rgb(200, 50, 30)
	for _, sx in { -1, 1 } do
		C(m, "Pillar", 7.4, 0.8, cf * CFrame.new(sx * w / 2, 3.7, 0), red, M.SmoothPlastic)
		C(m, "Foot", 0.6, 1.1, cf * CFrame.new(sx * w / 2, 0.3, 0), rgb(30, 30, 30), M.SmoothPlastic, nc())
	end
	P(m, "Nuki", Vector3.new(w + 1, 0.5, 0.5), cf * CFrame.new(0, 6, 0), red, M.SmoothPlastic, nc())
	P(m, "Kasagi", Vector3.new(w + 2.6, 0.6, 0.9), cf * CFrame.new(0, 7.6, 0), rgb(30, 30, 30), M.SmoothPlastic, nc())
	P(m, "Shimaki", Vector3.new(w + 2, 0.4, 0.7), cf * CFrame.new(0, 7.1, 0), red, M.SmoothPlastic, nc())
	return m
end

function X.pagoda(parent, cf: CFrame)
	local m = model(parent, "Pagoda")
	P(m, "Base", Vector3.new(5, 0.6, 5), cf * CFrame.new(0, 0.3, 0), rgb(110, 104, 96), M.Marble)
	for k = 0, 4 do
		local s = 3 - k * 0.4
		local y = 0.6 + k * 1.5
		P(m, "Storey", Vector3.new(s, 1.1, s), cf * CFrame.new(0, y + 0.55, 0), rgb(150, 40, 30), M.Wood)
		P(m, "Eave", Vector3.new(s + 1.4, 0.25, s + 1.4), cf * CFrame.new(0, y + 1.25, 0), rgb(40, 40, 44), M.Slate, nc())
	end
	C(m, "Sorin", 1.8, 0.2, cf * CFrame.new(0, 9, 0), GOLD, M.Metal, nc())
	return m
end

function X.samurai(parent, cf: CFrame)
	local m = model(parent, "Samurai")
	local lac, cord = rgb(30, 28, 30), rgb(170, 40, 40)
	P(m, "Box", Vector3.new(2.4, 1.6, 2), cf * CFrame.new(0, 0.8, 0), rgb(40, 30, 24), M.Wood)
	local b = cf * CFrame.new(0, 1.6, 0)
	for k = 0, 3 do
		P(m, "Kusazuri", Vector3.new(2.2 - k * 0.05, 0.3, 1.4), b * CFrame.new(0, 0.3 + k * 0.32, 0), if k % 2 == 0 then lac else cord, M.SmoothPlastic, nc())
	end
	P(m, "Do", Vector3.new(1.8, 1.8, 1.2), b * CFrame.new(0, 2.4, 0), lac, M.SmoothPlastic)
	for k = 0, 3 do
		P(m, "Lace", Vector3.new(1.85, 0.08, 1.25), b * CFrame.new(0, 1.8 + k * 0.4, 0), cord, M.Fabric, nc())
	end
	for _, sx in { -1, 1 } do
		P(m, "Sode", Vector3.new(0.9, 1.4, 1.2), b * CFrame.new(sx * 1.3, 2.8, 0) * CFrame.Angles(0, 0, sx * 0.2), lac, M.SmoothPlastic, nc())
	end
	S(m, "Kabuto", 1.3, b * CFrame.new(0, 4, 0), lac, M.SmoothPlastic, nc())
	P(m, "Fukigaeshi", Vector3.new(2, 0.3, 0.8), b * CFrame.new(0, 3.6, 0.1), lac, M.SmoothPlastic, nc())
	P(m, "Kuwagata", Vector3.new(1.2, 0.9, 0.08), b * CFrame.new(0, 4.6, -0.55), GOLD, M.Metal, nc())
	P(m, "Mempo", Vector3.new(0.8, 0.5, 0.2), b * CFrame.new(0, 3.5, -0.6), rgb(120, 30, 30), M.SmoothPlastic, nc())
	return m
end

function X.stoneLantern(parent, cf: CFrame)
	local m = model(parent, "StoneLantern")
	local stone = rgb(150, 146, 140)
	P(m, "Kiso", Vector3.new(1.8, 0.4, 1.8), cf * CFrame.new(0, 0.2, 0), stone, M.Slate)
	C(m, "Sao", 2, 0.7, cf * CFrame.new(0, 1.4, 0), stone, M.Slate)
	P(m, "Chudai", Vector3.new(1.5, 0.4, 1.5), cf * CFrame.new(0, 2.6, 0), stone, M.Slate)
	local light = P(m, "Hibukuro", Vector3.new(1.1, 1, 1.1), cf * CFrame.new(0, 3.3, 0), rgb(255, 214, 140), M.Neon, nc({ Transparency = 0.3 }))
	local l = Instance.new("PointLight")
	l.Range = 10
	l.Brightness = 0.6
	l.Color = rgb(255, 200, 130)
	l.Parent = light
	P(m, "Kasa", Vector3.new(2.2, 0.5, 2.2), cf * CFrame.new(0, 4.05, 0), stone, M.Slate)
	S(m, "Hoju", 0.6, cf * CFrame.new(0, 4.5, 0), stone, M.Slate, nc())
	return m
end

return X
