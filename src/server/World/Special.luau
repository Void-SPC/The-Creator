--!nonstrict
-- Особые места: рабочий лифт с кнопками секторов и автоматом-лавкой, зал Слепого
-- с генераторами, деталями и воротами, Сборщик платы у двери

local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local M = require(Shared.Materials)
local Rules = require(Shared.Rules)
local Props = require(script.Parent.Props)
local Builder = require(script.Parent.RoomBuilder)

local P, nc, rgb = Props.P, Props.nc, Props.rgb
local at = Builder.at

local Special = {}

local METAL = rgb(92, 94, 98)

-- Лифт: зал ожидания с автоматом и кабина с решёткой и кнопками. Выход кабины —
-- обычная дверь следующего номера, она открывается сама после поездки
function Special.elevator(parent, d, origin: CFrame)
	local th = Builder.theme(d.sector)
	local m = Props.model(parent, string.format("Room_%04d", d.door))
	local info = { desc = d, model = m, origin = origin, closets = {}, searchables = {}, tops = {}, lights = {}, elevator = true }
	info.exitCF = Builder.shell(m, d, origin, th)
	local cz0 = -16 -- граница кабины
	-- стенки кабины из металла поверх обоев
	for _, side in { -1, 1 } do
		P(m, "CabinWall", Vector3.new(0.4, d.h, d.l + cz0), at(origin, side * 6.2, d.h / 2, (cz0 - d.l) / 2), METAL, M.DiamondPlate)
		P(m, "CabinFront", Vector3.new(5, d.h, 0.4), at(origin, side * 8.7, d.h / 2, cz0), METAL, M.DiamondPlate)
	end
	P(m, "CabinFloor", Vector3.new(12, 0.2, d.l + cz0), at(origin, 0, 0.1, (cz0 - d.l) / 2), rgb(70, 72, 76), M.DiamondPlate)
	P(m, "CabinTop", Vector3.new(17.4, 0.6, 0.6), at(origin, 0, 11.4, cz0), METAL, M.Metal)
	-- раздвижная решётка (поднимается)
	local gate = Props.model(m, "CabinGate")
	local bars = {}
	for k = -5, 5 do
		table.insert(bars, P(gate, "Bar", Vector3.new(0.25, 11, 0.25), at(origin, k * 1.1, 5.5, cz0), rgb(150, 150, 156), M.Metal))
	end
	local gateBlock = P(gate, "Block", Vector3.new(12, 11, 0.4), at(origin, 0, 5.5, cz0), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1 })
	info.gate = gate
	info.gateBlock = gateBlock
	gate.WorldPivot = at(origin, 0, 0, cz0)
	-- поднята в начале: лифт ждёт игроков
	gate:PivotTo(at(origin, 0, 10.5, cz0))
	gateBlock.CanCollide = false
	-- кнопки: текущий сектор, следующий, остальные недоступны
	local panelCF = at(origin, 5.9, 4.5, cz0 - 4) * CFrame.Angles(0, math.pi / 2, 0)
	P(m, "Panel", Vector3.new(2.2, 4.2, 0.2), panelCF, rgb(40, 40, 44), M.Metal)
	info.buttons = {}
	for k = 0, 2 do
		local s = d.sector + k
		local b = P(m, "Button", Vector3.new(1.2, 0.9, 0.25), panelCF * CFrame.new(0, 1.3 - k * 1.3, -0.15), if k == 1 then rgb(240, 190, 80) else rgb(90, 90, 96), M.Neon)
		if k ~= 1 then
			b.Material = M.Metal
		end
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.Parent = b
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.TextScaled = true
		t.Font = Enum.Font.GothamBold
		t.TextColor3 = rgb(20, 20, 20)
		t.Text = tostring(s)
		t.Parent = gui
		if Rules.canRide(d.sector, s) then
			info.rideButton = b
			Props.prompt(b, "ride", 1, 7)
		end
	end
	-- автомат-лавка и скамья в зале ожидания
	local vend = Props.model(m, "Vending")
	local body = P(vend, "Body", Vector3.new(4, 7.5, 2.6), at(origin, -d.w / 2 + 2, 3.75, -8) * CFrame.Angles(0, -math.pi / 2, 0), rgb(120, 30, 34), M.Metal)
	P(vend, "Glass", Vector3.new(2.6, 4, 0.1), body.CFrame * CFrame.new(-0.4, 0.8, -1.32), rgb(200, 220, 230), M.Glass, nc({ Transparency = 0.4 }))
	local glow = P(vend, "Glow", Vector3.new(2.4, 3.8, 0.05), body.CFrame * CFrame.new(-0.4, 0.8, -1.25), rgb(255, 230, 180), M.Neon, nc())
	Props.light(glow, 12, 0.8)
	Props.prompt(body, "shop", 0, 8)
	Props.bench(m, Builder.sideSlot(origin, d.w, 1, -8), 7)
	Props.plantPot(m, Builder.sideSlot(origin, d.w, 1, -3) * CFrame.new(0, 0, -1.2))
	Props.plantPot(m, Builder.sideSlot(origin, d.w, -1, -3) * CFrame.new(0, 0, -1.2))
	Builder.ceilingLights(m, d, origin, info, 1)
	local _, cabinLamp = Props.ceilingLight(m, at(origin, 0, d.h, (cz0 - d.l) / 2).Position)
	table.insert(info.lights, cabinLamp)
	info.cabinCenter = at(origin, 0, 3, (cz0 - d.l) / 2)
	info.cabinZ = { cz0, -d.l }
	info.path = { at(origin, 0, 4, -2).Position, at(origin, 0, 4, -10).Position }
	info.center = at(origin, 0, d.h / 2, -d.l / 2)
	info.size = Vector3.new(d.w, d.h, d.l)
	info.watcherSpawn = at(origin, 0, 0, -6)
	return info
end

-- игрок в кабине лифта
function Special.inCabin(info, pos: Vector3): boolean
	local lp = info.origin:PointToObjectSpace(pos)
	return math.abs(lp.X) < 6 and lp.Z < info.cabinZ[1] - 0.3 and lp.Z > info.cabinZ[2]
end

-- Зал Слепого: колонны, ящики для укрытия, шкафы, три генератора, детали и ворота.
-- За воротами сразу лифт (строится отдельно от exitCF)
function Special.boss(parent, d, origin: CFrame, rand)
	local th = Builder.theme(d.sector)
	local m = Props.model(parent, string.format("Room_%04d", d.door))
	local info = { desc = d, model = m, origin = origin, closets = {}, searchables = {}, tops = {}, lights = {}, boss = true }
	local w, l, h = d.w, d.l, d.h
	P(m, "Floor", Vector3.new(w + 2, 1, l), at(origin, 0, -0.5, -l / 2), rgb(70, 70, 68), M.Concrete)
	P(m, "Ceiling", Vector3.new(w + 2, 1, l), at(origin, 0, h + 0.5, -l / 2), rgb(50, 50, 50), M.Concrete)
	local wallC = th.wall:Lerp(rgb(40, 40, 40), 0.5)
	Props.wall(m, at(origin, 0, 0, 0), w + 2, h, 1.2, { { x = 0, w = 5.6, h = 9.4 } }, wallC, M.Concrete)
	Props.wall(m, at(origin, 0, 0, -l) * CFrame.Angles(0, math.pi, 0), w + 2, h, 1, { { x = 0, w = 12, h = 14 } }, wallC, M.Concrete)
	for _, side in { -1, 1 } do
		Props.wall(m, at(origin, side * (w / 2 + 0.5), 0, -l / 2) * CFrame.Angles(0, if side < 0 then math.pi / 2 else -math.pi / 2, 0), l, h, 1, {}, wallC, M.Concrete)
	end
	-- колонны сеткой (между ними удобно прятаться от Слепого)
	for _, x in { -22, 0, 22 } do
		for _, z in { -20, -44, -68 } do
			if not (x == 0 and z == -44) then
				Props.pillar(m, at(origin, x, 0, z), h)
			end
		end
	end
	-- ящики-укрытия
	local crates = { { -12, -30 }, { 12, -30 }, { -30, -56 }, { 30, -56 }, { -10, -78 }, { 10, -78 }, { 0, -12 } }
	for i, c in crates do
		Props.crate(m, at(origin, c[1], 0, c[2]) * CFrame.Angles(0, i * 0.4, 0), 3.5)
	end
	-- шкафы вдоль стен
	for _, side in { -1, 1 } do
		for _, z in { -14, -44, -74 } do
			Builder.addCloset(m, info, Builder.sideSlot(origin, w, side, z))
		end
	end
	-- генераторы
	info.generators = {}
	for _, g in { { -30, -30 }, { 30, -30 }, { 0, -60 } } do
		local gm, body, lamp = Props.generator(m, at(origin, g[1], 0, g[2]) * CFrame.Angles(0, math.pi, 0))
		table.insert(info.generators, { model = gm, body = body, lamp = lamp, progress = 0, fused = false, done = false })
	end
	-- детали: случайные места из списка
	local spots = { { -34, -12 }, { 34, -12 }, { -20, -50 }, { 20, -50 }, { -34, -80 }, { 34, -80 }, { 0, -30 }, { -8, -68 }, { 8, -84 } }
	for i = #spots, 2, -1 do
		local j = math.floor(rand() * i) + 1
		spots[i], spots[j] = spots[j], spots[i]
	end
	info.fuses = {}
	for i = 1, Rules.FUSES do
		local s = spots[i]
		local _, part = Props.pickup(m, at(origin, s[1], 0, s[2]), "fuse")
		table.insert(info.fuses, part)
	end
	-- аварийный красный свет
	for _, x in { -26, 26 } do
		for _, z in { -24, -64 } do
			local lamp = P(m, "EmergencyLamp", Vector3.new(1.4, 0.6, 1.4), at(origin, x, h - 0.4, z), rgb(200, 40, 30), M.Neon, nc())
			Props.light(lamp, 34, 0.9, rgb(255, 50, 40))
			table.insert(info.lights, lamp)
		end
	end
	-- ворота: тяжёлая решётка, поднимается, когда починены все генераторы
	local gate = Props.model(m, "BigGate")
	for k = -5, 5 do
		P(gate, "Bar", Vector3.new(0.5, 14, 0.5), at(origin, k * 1.1, 7, -l), rgb(70, 70, 74), M.Metal)
	end
	for _, y in { 2, 7, 12 } do
		P(gate, "Rail", Vector3.new(12, 0.6, 0.6), at(origin, 0, y, -l), rgb(70, 70, 74), M.Metal)
	end
	info.bigGate = gate
	info.bigGateHome = gate:GetPivot()
	-- середина зала и границы для проверок
	info.exitCF = at(origin, 0, 0, -l)
	info.center = at(origin, 0, h / 2, -l / 2)
	info.size = Vector3.new(w, h, l)
	info.path = { at(origin, 0, 4, -2).Position }
	info.watcherSpawn = at(origin, 0, 0, -10)
	info.blindSpawn = at(origin, 0, 3, -44)
	info.wander = {}
	for _, p in { { -30, -12 }, { 30, -12 }, { -34, -44 }, { 34, -44 }, { -30, -80 }, { 30, -80 }, { 0, -24 }, { 0, -70 }, { -12, -44 }, { 12, -44 } } do
		table.insert(info.wander, at(origin, p[1], 3, p[2]).Position)
	end
	return info
end

-- Сборщик платы: высокая фигура в плаще с фонарём и весами. Стоит перед выходом
function Special.tollKeeper(parent, cf: CFrame, price: number)
	local m = Props.model(parent, "TollKeeper")
	local robe = rgb(30, 26, 34)
	P(m, "Robe", Vector3.new(3.4, 7, 2.2), cf * CFrame.new(0, 3.5, 0), robe, M.SmoothPlastic)
	P(m, "Hood", Vector3.new(2.6, 2.4, 2.4), cf * CFrame.new(0, 8.1, 0.1), robe, M.SmoothPlastic)
	P(m, "Face", Vector3.new(1.6, 1.4, 0.1), cf * CFrame.new(0, 8, -1.2), rgb(10, 8, 10), M.SmoothPlastic, nc())
	for _, x in { -0.4, 0.4 } do
		local eye = P(m, "Eye", Vector3.new(0.25, 0.25, 0.05), cf * CFrame.new(x, 8.2, -1.27), rgb(255, 200, 80), M.Neon, nc())
		local _ = eye
	end
	local lantern = P(m, "Lantern", Vector3.new(0.8, 1, 0.8), cf * CFrame.new(-2.2, 3.6, -0.6), rgb(255, 190, 90), M.Neon, nc())
	Props.light(lantern, 16, 1.2, rgb(255, 180, 90))
	P(m, "Chain", Vector3.new(0.1, 1.6, 0.1), cf * CFrame.new(-2.2, 4.9, -0.6), Props.IRON, M.Metal, nc())
	-- чаша для монет
	local bowl = P(m, "Bowl", Vector3.new(1.8, 0.4, 1.8), cf * CFrame.new(1.9, 4.2, -0.8), rgb(200, 170, 80), M.Metal, nc())
	local payCoins = P(m, "PayCoins", Vector3.new(1.5, 1.5, 1.5), cf * CFrame.new(1.9, 4.6, -0.8), rgb(0, 0, 0), M.SmoothPlastic, nc({ Transparency = 1 }))
	local payBlood = P(m, "PayBlood", Vector3.new(1.5, 1.5, 1.5), cf * CFrame.new(-0.6, 5, -1), rgb(0, 0, 0), M.SmoothPlastic, nc({ Transparency = 1 }))
	local _ = bowl
	-- блок, чтобы нельзя было пройти мимо
	P(m, "Block", Vector3.new(7, 10, 1), cf * CFrame.new(0, 5, 0.6), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1 })
	local pc = Props.prompt(payCoins, "paycoins", 0.4, 9)
	pc:SetAttribute("Price", price)
	-- обе кнопки видны одновременно (разные клавиши)
	pc.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	pc.KeyboardKeyCode = Enum.KeyCode.E
	pc.UIOffset = Vector2.new(0, 40)
	local pb = Props.prompt(payBlood, "payblood", 1.2, 9)
	pb.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	pb.KeyboardKeyCode = Enum.KeyCode.F
	pb.GamepadKeyCode = Enum.KeyCode.ButtonY
	pb.UIOffset = Vector2.new(0, -40)
	CollectionService:AddTag(m, "TollKeeper")
	return m, pc, pb
end

return Special
