--!nonstrict
-- Особые места: зал Слепого с генераторами и воротами, технический сектор для погони
-- с обрывом в пустоту, Монетчик (живая монета на пути), лобби с рабочим лифтом

local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local M = require(Shared.Materials)
local Rules = require(Shared.Rules)
local Props = require(script.Parent.Props)
local Builder = require(script.Parent.RoomBuilder)

local P, C, S, nc, rgb = Props.P, Props.C, Props.S, Props.nc, Props.rgb
local at = Builder.at

local Special = {}

-- ---------------------------------------------------------------------------
-- Зал Слепого: колонны, ящики-укрытия, шкафчики, три генератора, детали, ворота.
-- За воротами сразу начинается технический сектор

function Special.boss(parent, d, origin: CFrame, rand, prevInfo)
	local m = Props.model(parent, string.format("Room_%03d", d.door))
	local info = { desc = d, model = m, origin = origin, hideSpots = {}, searchables = {}, tops = {}, lights = {}, boss = true }
	-- проём ворот ровно по ширине и высоте тоннеля за ними
	d.exitHole = { w = 10, h = 11 }
	d.zone = "deep"
	d.decoys = {}
	local st = Builder.style(d, rand)
	st.paper = rgb(64, 64, 62)
	st.paperMat = M.Concrete
	st.floor = rgb(62, 62, 60)
	st.floorMat = M.Concrete
	st.ceil = rgb(44, 44, 44)
	st.wainscot = false
	info.top = d.h
	local sh = Builder.shell(m, d, origin, st, Builder.prevWallFor(prevInfo, origin))
	for k, v in sh do
		info[k] = v
	end
	local w, l, h = d.w, d.l, d.h
	-- колонны сеткой (между ними прячутся от Слепого)
	for _, x in { -22, 0, 22 } do
		for _, z in { -20, -44, -68 } do
			if not (x == 0 and z == -44) then
				Props.pillar(m, at(origin, x, 0, z), h, rgb(110, 108, 104))
			end
		end
	end
	for i, c in { { -12, -30 }, { 12, -30 }, { -30, -56 }, { 30, -56 }, { -10, -80 }, { 10, -80 }, { 0, -12 } } do
		Props.crate(m, at(origin, c[1], 0, c[2]) * CFrame.Angles(0, i * 0.4, 0), 3.5)
	end
	for _, side in { -1, 1 } do
		local slot = if side < 0 then Builder.slotL else Builder.slotR
		for _, z in { -14, -44, -74 } do
			local _, cavity = Props.locker(m, slot(d, origin, z))
			table.insert(info.hideSpots, cavity)
		end
	end
	info.generators = {}
	for _, g in { { -30, -30 }, { 30, -30 }, { 0, -60 } } do
		local gm, body, lamp = Props.generator(m, at(origin, g[1], 0, g[2]) * CFrame.Angles(0, math.pi, 0))
		table.insert(info.generators, { model = gm, body = body, lamp = lamp, progress = 0, fused = false, done = false })
	end
	local spots = { { -34, -12 }, { 34, -12 }, { -20, -50 }, { 20, -50 }, { -34, -84 }, { 34, -84 }, { 0, -30 }, { -8, -68 }, { 8, -84 } }
	for i = #spots, 2, -1 do
		local j = math.floor(rand() * i) + 1
		spots[i], spots[j] = spots[j], spots[i]
	end
	for i = 1, Rules.FUSES do
		Props.pickup(m, at(origin, spots[i][1], 0, spots[i][2]), "fuse")
	end
	for _, x in { -26, 26 } do
		for _, z in { -24, -64 } do
			Props.emergencyLamp(m, at(origin, x, h - 0.2, z).Position)
		end
	end
	-- ворота: тяжёлая решётка, поднимается, когда починены все генераторы
	local gate = Props.model(m, "BigGate")
	for k = -4, 4 do
		P(gate, "Bar", Vector3.new(0.5, 10.9, 0.5), at(origin, k * 1.1, 5.45, -l), rgb(70, 70, 74), M.Metal)
	end
	for _, y in { 2, 6, 10 } do
		P(gate, "Rail", Vector3.new(8.9, 0.6, 0.7), at(origin, 0, y, -l), rgb(80, 80, 84), M.Metal)
	end
	info.bigGate = gate
	info.bigGateHome = gate:GetPivot()
	info.center = at(origin, 0, h / 2, -l / 2)
	info.size = Vector3.new(w, h, l)
	info.path = { at(origin, 0, 4, -2).Position }
	info.watcherSpawn = at(origin, 0, 0, -10)
	info.blindSpawn = at(origin, 0, 3, -44)
	info.wander = {}
	for _, p in { { -30, -12 }, { 30, -12 }, { -34, -44 }, { 34, -44 }, { -30, -80 }, { 30, -80 }, { 0, -24 }, { 0, -72 }, { -12, -44 }, { 12, -44 } } do
		table.insert(info.wander, at(origin, p[1], 3, p[2]).Position)
	end
	-- технический сектор за воротами
	info.chase = Special.tunnel(m, info.exitCF)
	return info
end

-- ---------------------------------------------------------------------------
-- Технический сектор: тесный тоннель из клеток 10 × 10 с трубами и решётками,
-- два поворота, в конце обрыв в пустоту

function Special.tunnel(parent, start: CFrame)
	local m = Props.model(parent, "TechSector")
	local H = 11
	-- клетки (i, j): i — вбок, j — вперёд
	local cells = {}
	local order = {}
	local function add(i, j)
		local key = i .. "," .. j
		if not cells[key] then
			cells[key] = { i = i, j = j }
			table.insert(order, cells[key])
		end
	end
	for j = 0, 5 do
		add(0, j)
	end
	for i = 1, 3 do
		add(i, 5)
	end
	for j = 6, 11 do
		add(3, j)
	end
	for i = 2, 0, -1 do
		add(i, 11)
	end
	for j = 12, 15 do
		add(0, j)
	end
	local function cellCF(i, j)
		return start * CFrame.new(i * 10, 0, -5 - j * 10)
	end
	local wallC = rgb(58, 60, 60)
	local lastJ = 15
	for _, c in order do
		local cf = cellCF(c.i, c.j)
		local edge = c.j == lastJ
		-- пол обрывается в последней клетке на середине
		if edge then
			P(m, "Grate", Vector3.new(10, 1, 5), cf * CFrame.new(0, -0.5, 2.5), rgb(60, 60, 60), M.DiamondPlate)
		else
			P(m, "Grate", Vector3.new(10, 1, 10), cf * CFrame.new(0, -0.5, 0), rgb(60, 60, 60), M.DiamondPlate)
		end
		-- первая клетка начинается за стеной зала (её толщина 0.5 по эту сторону)
		local first = c.i == 0 and c.j == 0
		local len, shift = if first then 9.5 else 10, if first then -0.25 else 0
		P(m, "Ceiling", Vector3.new(10, 1, len), cf * CFrame.new(0, H + 0.52, shift), rgb(40, 40, 40), M.Concrete)
		for _, n in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local ni, nj = c.i + n[1], c.j + n[2]
			local open = cells[ni .. "," .. nj] ~= nil or (n[2] == -1 and first) or (edge and n[2] == 1)
			if not open then
				if n[1] ~= 0 then
					P(m, "TunnelWall", Vector3.new(1, H, len), cf * CFrame.new(n[1] * 5, H / 2, shift), wallC, M.Concrete)
				else
					P(m, "TunnelWall", Vector3.new(10, H, 1), cf * CFrame.new(0, H / 2, -n[2] * 5), wallC, M.Concrete)
				end
			end
		end
		-- трубы у потолка и лампа-клетка через одну клетку
		if (c.i + c.j) % 2 == 0 then
			Props.emergencyLamp(m, (cf * CFrame.new(0, H - 0.2, 0)).Position)
		end
	end
	-- трубы вдоль первого прямого участка
	Props.pipes(m, (start * CFrame.new(-3.8, H - 0.8, -1)).Position, (start * CFrame.new(-3.8, H - 0.8, -55)).Position, 2)
	Props.pipes(m, (start * CFrame.new(33.8, H - 0.8, -60)).Position, (start * CFrame.new(33.8, H - 0.8, -115)).Position, 2)
	-- перила-обломок у края
	local edgeCF = cellCF(0, lastJ)
	P(m, "BrokenRail", Vector3.new(3, 0.25, 0.25), edgeCF * CFrame.new(-3, 3.2, 0.2) * CFrame.Angles(0, 0, -0.3), rgb(110, 60, 40), M.Metal, nc())
	-- путь для погони: середины клеток по порядку
	local path = {}
	for _, c in order do
		table.insert(path, (cellCF(c.i, c.j) * CFrame.new(0, 3, 0)).Position)
	end
	local trigger = P(m, "VoidEdge", Vector3.new(10, 12, 2), edgeCF * CFrame.new(0, 6, 1), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	return { model = m, path = path, edge = edgeCF * CFrame.new(0, 0, 0), trigger = trigger, start = start }
end

-- ---------------------------------------------------------------------------
-- Монетчик: огромная живая монета с лицом, раскинула руки поперёк двери.
-- Сначала берёт мало, у последних дверей — до 500 монет

function Special.coinKeeper(parent, cf: CFrame, price: number)
	local m = Props.model(parent, "CoinKeeper")
	local gold = rgb(214, 172, 62)
	local dark = rgb(150, 112, 34)
	local face = cf * CFrame.new(0, 5.4, 0)
	-- ребристый край и выпуклая середина
	C(m, "Rim", 0.6, 8.4, face * CFrame.Angles(math.pi / 2, 0, 0), dark, M.Metal)
	C(m, "Face", 0.9, 7.4, face * CFrame.Angles(math.pi / 2, 0, 0), gold, M.Metal)
	for k = 0, 23 do
		local a = k / 24 * math.pi * 2
		P(m, "Mill", Vector3.new(0.35, 0.5, 0.5), face * CFrame.Angles(0, 0, a) * CFrame.new(0, 4.25, 0), dark, M.Metal, nc())
	end
	-- лицо: сердитые глаза, брови, рот-прорезь для монет
	for _, x in { -1.4, 1.4 } do
		C(m, "Eye", 0.2, 1.1, face * CFrame.new(x, 1, -0.5) * CFrame.Angles(math.pi / 2, 0, 0), rgb(20, 14, 8), M.SmoothPlastic, nc())
		S(m, "Pupil", 0.45, face * CFrame.new(x, 1, -0.62), rgb(255, 210, 90), M.Neon, nc())
		P(m, "Brow", Vector3.new(1.6, 0.3, 0.2), face * CFrame.new(x, 1.9, -0.52) * CFrame.Angles(0, 0, if x < 0 then -0.35 else 0.35), dark, M.Metal, nc())
	end
	P(m, "Slot", Vector3.new(3, 0.45, 0.2), face * CFrame.new(0, -1.5, -0.52), rgb(12, 8, 4), M.SmoothPlastic, nc())
	for k = -2, 2 do
		P(m, "Tooth", Vector3.new(0.3, 0.3, 0.12), face * CFrame.new(k * 0.6, -1.25, -0.6), rgb(236, 228, 200), M.SmoothPlastic, nc())
	end
	-- руки поперёк проёма
	for _, s in { -1, 1 } do
		local shoulder = (face * CFrame.new(s * 3.9, -0.5, 0)).Position
		local elbow = (face * CFrame.new(s * 5.2, -2, -0.6)).Position
		local hand = (face * CFrame.new(s * 5.6, -3.6, -0.2)).Position
		Props.rod(m, "Arm", shoulder, elbow, 0.35, dark, M.Metal, nc())
		Props.rod(m, "Arm", elbow, hand, 0.3, dark, M.Metal, nc())
		S(m, "Hand", 0.6, CFrame.new(hand), gold, M.Metal, nc())
	end
	-- монетка-цена над головой
	local tag = P(m, "PriceTag", Vector3.new(1, 1, 1), face * CFrame.new(0, 5.3, 0), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(120, 40)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 40
	bb.Parent = tag
	local t = Instance.new("TextLabel")
	t.Name = "Price"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextColor3 = rgb(255, 214, 90)
	t.TextStrokeTransparency = 0.4
	t.Text = "● " .. price
	t.Parent = bb
	local glow = Instance.new("PointLight")
	glow.Range = 14
	glow.Brightness = 0.8
	glow.Color = rgb(255, 200, 90)
	glow.Parent = tag
	-- невидимый блок: мимо не пройти
	P(m, "Block", Vector3.new(7, 10, 1.2), cf * CFrame.new(0, 5, 0.8), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CastShadow = false })
	local payC = P(m, "PayCoins", Vector3.new(2, 2, 2), face * CFrame.new(-1.5, -1.5, -1), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	local payB = P(m, "PayBlood", Vector3.new(2, 2, 2), face * CFrame.new(1.5, -1.5, -1), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	local pc = Props.prompt(payC, "paycoins", 0.5, 10)
	pc:SetAttribute("Price", price)
	pc.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	pc.KeyboardKeyCode = Enum.KeyCode.E
	pc.UIOffset = Vector2.new(-80, 0)
	local pb = Props.prompt(payB, "payblood", 1.5, 10)
	pb.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	pb.KeyboardKeyCode = Enum.KeyCode.F
	pb.GamepadKeyCode = Enum.KeyCode.ButtonY
	pb.UIOffset = Vector2.new(80, 0)
	m.WorldPivot = cf
	CollectionService:AddTag(m, "CoinKeeper")
	return m, pc, pb
end

-- ---------------------------------------------------------------------------
-- Лобби: тёмный служебный холл с рабочим лифтом. Кто зашёл в кабину — едет в лабиринт

function Special.lobby(parent)
	local m = Props.model(parent, "Lobby")
	local origin = CFrame.new(0, 0, 0)
	local d = { kind = "start", door = 0, zone = "faded", w = 36, l = 40, h = 16, dy = 0, decoys = {}, exit = { name = "front", x = 0, z = -40, turn = 0, y = 0 }, exitHole = { w = 9, h = 10 }, windows = false }
	local st = Builder.style(d, function()
		return 0.3
	end)
	st.paper = rgb(84, 80, 72)
	st.floor = rgb(58, 46, 40)
	local info = { desc = d, model = m, origin = origin, hideSpots = {}, searchables = {}, tops = {}, lights = {}, top = d.h }
	local sh = Builder.shell(m, d, origin, st, nil)
	for k, v in sh do
		info[k] = v
	end
	-- кабина лифта за проёмом
	local cab = at(origin, 0, 0, -40)
	local steel = rgb(96, 98, 100)
	-- стенки кабины чуть шире проёма, чтобы их грани не совпадали с краями проёма
	P(m, "CabFloor", Vector3.new(9.6, 0.4, 9), cab * CFrame.new(0, -0.2, -5), rgb(70, 70, 72), M.DiamondPlate)
	P(m, "CabCeil", Vector3.new(9.6, 0.4, 9), cab * CFrame.new(0, 10.25, -5), steel, M.Metal)
	P(m, "CabBack", Vector3.new(9.6, 10.45, 0.4), cab * CFrame.new(0, 5.03, -9.7), steel, M.Metal)
	for _, s in { -1, 1 } do
		P(m, "CabSide", Vector3.new(0.4, 10.45, 8.9), cab * CFrame.new(s * 4.75, 5.03, -5), steel, M.Metal)
	end
	local _, cabLamp = Props.ceilingLamp(m, (cab * CFrame.new(0, 10, -4.5)).Position)
	local _ = cabLamp
	local zone = P(m, "ElevatorZone", Vector3.new(8.4, 8, 8.4), cab * CFrame.new(0, 4, -4.6), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	-- табло над кабиной
	local board = P(m, "Board", Vector3.new(8, 1.6, 0.2), cab * CFrame.new(0, 11.4, 0.85), rgb(20, 20, 20), M.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.Code
	t.TextScaled = true
	t.TextColor3 = rgb(255, 120, 60)
	t.Text = "001"
	t.Parent = gui
	-- доска с правилами на стене
	local rules = P(m, "RulesBoard", Vector3.new(9, 6, 0.2), Builder.slotL(d, origin, -16) * CFrame.new(0, 6, -0.15), rgb(40, 30, 24), M.Wood)
	local rg = Instance.new("SurfaceGui")
	rg.Face = Enum.NormalId.Front
	rg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	rg.PixelsPerStud = 30
	rg.Parent = rules
	local rt = Instance.new("TextLabel")
	rt.BackgroundTransparency = 1
	rt.Size = UDim2.fromScale(1, 1)
	rt.Font = Enum.Font.Antique
	rt.TextScaled = true
	rt.TextWrapped = true
	rt.TextColor3 = rgb(230, 214, 180)
	rt.Text = ""
	rt:SetAttribute("LangKey", "LobbyRules")
	rt.Parent = rg
	for _, s in { -1, 1 } do
		Props.bench(m, (if s < 0 then Builder.slotL else Builder.slotR)(d, origin, -28), 8)
		Props.plantPot(m, at(origin, s * 14, 0, -36))
	end
	Props.sofa(m, Builder.slotR(d, origin, -12), rgb(70, 30, 30))
	Props.rug(m, at(origin, 0, 0, -20), 10, 26, rgb(80, 24, 26))
	Props.LIGHT = 0.7
	for _, z in { -10, -26 } do
		local _, b = Props.ceilingLamp(m, at(origin, 0, d.h, z).Position)
		local _ = b
	end
	Props.LIGHT = 1
	return { model = m, zone = zone, board = t, spawn = at(origin, 0, 3, -8) * CFrame.Angles(0, 0, 0), cabin = cab * CFrame.new(0, 3, -4.5) }
end

return Special
