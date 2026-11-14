--!nonstrict
-- Сборка одной комнаты лабиринта по описанию из RoomPlan. Кадр комнаты: вход в
-- точке origin, комната уходит вперёд (LookVector). Мебель ставится зеркально
-- у левой и правой стен, проходы к дверям всегда свободны

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local M = require(Shared.Materials)
local Plan = require(Shared.RoomPlan)
local Props = require(script.Parent.Props)

local P, nc, rgb = Props.P, Props.nc, Props.rgb

local Builder = {}

-- оформление сектора: обои, пол, плинтус (сектора чередуются)
Builder.THEMES = {
	{ wall = rgb(70, 82, 62), wallMat = M.Plaster, floor = rgb(96, 66, 44), floorMat = M.WoodPlanks, trim = rgb(54, 38, 28), ceil = rgb(186, 178, 160) },
	{ wall = rgb(110, 52, 46), wallMat = M.Plaster, floor = rgb(150, 146, 136), floorMat = M.CeramicTiles, trim = rgb(60, 34, 30), ceil = rgb(170, 160, 150) },
	{ wall = rgb(112, 112, 108), wallMat = M.Concrete, floor = rgb(80, 80, 78), floorMat = M.Concrete, trim = rgb(56, 56, 56), ceil = rgb(120, 120, 118) },
	{ wall = rgb(44, 54, 86), wallMat = M.Plaster, floor = rgb(170, 164, 156), floorMat = M.Marble, trim = rgb(30, 30, 44), ceil = rgb(160, 160, 170) },
}

function Builder.theme(sector: number)
	return Builder.THEMES[((sector - 1) % #Builder.THEMES) + 1]
end

local WALL_T = 1
local DOOR_HOLE = { w = 5.6, h = 9.4 }

-- мировой кадр по локальным координатам комнаты
local function at(origin: CFrame, x: number, y: number, z: number)
	return origin * CFrame.new(x, y, z)
end

-- место у боковой стены: side = -1 левая, 1 правая; LookVector в комнату
local function sideSlot(origin, w, side, z)
	return origin * CFrame.new(side * w / 2, 0, z) * CFrame.Angles(0, if side > 0 then math.pi / 2 else -math.pi / 2, 0)
end

-- место у дальней стены (её внутренняя сторона на -l + 0.5), LookVector в комнату
local function frontSlot(origin, l, x)
	return origin * CFrame.new(x, 0, -l + 0.5) * CFrame.Angles(0, math.pi, 0)
end

-- место у стены входа (она толще: внутренняя сторона на -0.6)
local function backSlot(origin, x)
	return origin * CFrame.new(x, 0, -0.6)
end

-- Голые стены, пол, потолок, плинтус. Вход в задней стене, выход по плану
local function shell(m, d, origin, th)
	local w, l, h = d.w, d.l, d.h
	P(m, "Floor", Vector3.new(w + 2, 1, l), at(origin, 0, -0.5, -l / 2), th.floor, th.floorMat)
	P(m, "Ceiling", Vector3.new(w + 2, 1, l), at(origin, 0, h + 0.5, -l / 2), th.ceil, M.SmoothPlastic)
	local ex, ez, rot = Plan.exitOf(d)
	local hasEntrance = d.kind ~= "start"
	-- задняя стена (толще, чтобы не мерцала со стеной прошлой комнаты)
	Props.wall(m, at(origin, 0, 0, 0), w + 2, h, WALL_T + 0.2, if hasEntrance then { { x = 0, w = DOOR_HOLE.w, h = DOOR_HOLE.h } } else {}, th.wall, th.wallMat)
	-- дальняя стена
	Props.wall(m, at(origin, 0, 0, -l) * CFrame.Angles(0, math.pi, 0), w + 2, h, WALL_T, if rot == 0 then { { x = 0, w = DOOR_HOLE.w, h = DOOR_HOLE.h } } else {}, th.wall, th.wallMat)
	-- боковые стены: локальная ось стены идёт вдоль Z комнаты
	for _, side in { -1, 1 } do
		local holes = {}
		if rot ~= 0 and math.sign(ex) == side then
			-- x стены = -z комнаты (для левой) или z (для правой)
			holes = { { x = if side < 0 then -(ez + l / 2) else (ez + l / 2), w = DOOR_HOLE.w, h = DOOR_HOLE.h } }
		end
		local cf = at(origin, side * (w / 2 + WALL_T / 2), 0, -l / 2) * CFrame.Angles(0, if side < 0 then math.pi / 2 else -math.pi / 2, 0)
		Props.wall(m, cf, l, h, WALL_T, holes, th.wall, th.wallMat)
	end
	-- плинтус вдоль боковых стен
	for _, side in { -1, 1 } do
		P(m, "Baseboard", Vector3.new(0.2, 0.6, l), at(origin, side * (w / 2 - 0.1), 0.3, -l / 2), th.trim, M.Wood, nc())
	end
	local exitCF = origin * CFrame.new(ex, 0, ez) * CFrame.Angles(0, rot * math.pi / 2, 0)
	return exitCF
end

-- свет под потолком вдоль середины комнаты
local function ceilingLights(m, d, origin, info, count: number)
	for k = 1, count do
		local z = -d.l * k / (count + 1)
		local _, bulb = Props.ceilingLight(m, at(origin, 0, d.h, z).Position)
		table.insert(info.lights, bulb)
	end
end

-- зеркальная пара у боковых стен на глубине z (если там не выход)
local function pair(info, d, origin, z, fn)
	local _, ez, rot = Plan.exitOf(d)
	if rot ~= 0 and math.abs(z - ez) < 5.5 then
		return false
	end
	if z > -4 then
		return false
	end
	for _, side in { -1, 1 } do
		fn(sideSlot(origin, d.w, side, z), side)
	end
	local _ = info
	return true
end

local function addCloset(m, info, cf)
	local _, body = Props.closet(m, cf)
	table.insert(info.closets, body)
end

local function addDresser(m, info, cf)
	local _, body = Props.dresser(m, cf)
	table.insert(info.searchables, body)
	-- место для предмета на крышке
	table.insert(info.tops, cf * CFrame.new(1.2, 3.5, -0.9))
	return body
end

-- обстановка по типу комнаты ---------------------------------------------------

local furnish = {}

furnish.start = function(m, d, origin, info)
	-- холл-приёмная: стойка, диваны-скамьи, растения, табличка лабиринта
	Props.table(m, at(origin, 0, 0, -8), 10, 2.4)
	for _, side in { -1, 1 } do
		Props.bench(m, sideSlot(origin, d.w, side, -16), 8)
		Props.plantPot(m, sideSlot(origin, d.w, side, -4) * CFrame.new(0, 0, -1.2))
		Props.plantPot(m, sideSlot(origin, d.w, side, -27) * CFrame.new(0, 0, -1.2))
		Props.painting(m, sideSlot(origin, d.w, side, -16) * CFrame.new(0, 7, -0.15), 6, 4, side + 3)
		addCloset(m, info, frontSlot(origin, d.l, side * 9))
	end
	Props.lamp(m, at(origin, -3.5, 3.15, -8).Position)
	Props.lamp(m, at(origin, 3.5, 3.15, -8).Position)
	ceilingLights(m, d, origin, info, 2)
end

furnish.corridor = function(m, d, origin, info)
	local k = 0
	for z = -8, -d.l + 6, -8 do
		k += 1
		pair(info, d, origin, z, function(cf, side)
			if k == 2 and side < 0 then
				addCloset(m, info, cf)
			elseif k == 2 then
				addDresser(m, info, cf)
			else
				Props.painting(m, cf * CFrame.new(0, 6.5, -0.15), 3.6, 2.6, k + side)
			end
		end)
	end
	ceilingLights(m, d, origin, info, 3)
end

furnish.room = function(m, d, origin, info)
	-- выход сбоку: кровать по центру дальней стены; выход прямо: две кровати у боковых стен
	local blanket = Color3.fromHSV((d.door * 0.17) % 1, 0.4, 0.45)
	if d.turn ~= 0 then
		Props.bed(m, frontSlot(origin, d.l, 0), blanket)
	else
		for _, side in { -1, 1 } do
			Props.bed(m, sideSlot(origin, d.w, side, -d.l / 2), blanket)
		end
	end
	pair(info, d, origin, -6, function(cf)
		addCloset(m, info, cf)
	end)
	pair(info, d, origin, -d.l + 4, function(cf)
		addDresser(m, info, cf)
		Props.lamp(m, (cf * CFrame.new(-1.4, 3.5, -0.9)).Position)
	end)
	Props.table(m, at(origin, 0, 0, -d.l / 2), 4, 3)
	table.insert(info.tops, at(origin, 0.8, 3.2, -d.l / 2))
	Props.chair(m, at(origin, -2.8, 0, -d.l / 2) * CFrame.Angles(0, -math.pi / 2, 0))
	Props.chair(m, at(origin, 2.8, 0, -d.l / 2) * CFrame.Angles(0, math.pi / 2, 0))
	for _, x in { -7, 7 } do
		Props.painting(m, backSlot(origin, x) * CFrame.new(0, 7, -0.15), 4, 3, d.door + x)
	end
	ceilingLights(m, d, origin, info, 1)
end

furnish.office = function(m, d, origin, info)
	pair(info, d, origin, -5.5, function(cf)
		addCloset(m, info, cf)
	end)
	pair(info, d, origin, -12, function(cf, side)
		Props.shelf(m, cf, d.door + side)
	end)
	pair(info, d, origin, -18, function(cf)
		addDresser(m, info, cf)
	end)
	for _, x in { -5, 5 } do
		Props.desk(m, at(origin, x, 0, -10) * CFrame.Angles(0, math.pi, 0))
		Props.chair(m, at(origin, x, 0, -6.2))
		table.insert(info.tops, at(origin, x + 1.2, 3.2, -8.7))
	end
	ceilingLights(m, d, origin, info, 2)
end

furnish.hall = function(m, d, origin, info)
	for _, x in { -8, 8 } do
		for _, z in { -10, -24 } do
			Props.pillar(m, at(origin, x, 0, z), d.h)
		end
	end
	pair(info, d, origin, -6, function(cf)
		addCloset(m, info, cf)
	end)
	pair(info, d, origin, -17, function(cf)
		Props.bench(m, cf, 7)
		Props.painting(m, cf * CFrame.new(0, 8, -0.15), 6, 4, d.door)
	end)
	pair(info, d, origin, -28, function(cf)
		addCloset(m, info, cf)
	end)
	if d.turn == 0 then
		for _, x in { -11, 11 } do
			addDresser(m, info, frontSlot(origin, d.l, x))
		end
	else
		for _, x in { -11, 11 } do
			addDresser(m, info, backSlot(origin, x))
		end
	end
	for _, x in { -14, 14 } do
		Props.plantPot(m, at(origin, x, 0, -17))
	end
	ceilingLights(m, d, origin, info, 3)
end

-- Построить комнату. Возвращает сведения для игры: выход, шкафы, ящики, свет, путь
function Builder.build(parent: Instance, d, origin: CFrame)
	local th = Builder.theme(d.sector)
	local m = Props.model(parent, string.format("Room_%04d", d.door))
	local info = { desc = d, model = m, origin = origin, closets = {}, searchables = {}, tops = {}, lights = {} }
	local exitCF = shell(m, d, origin, th)
	info.exitCF = exitCF
	local f = furnish[d.kind] or furnish.room
	f(m, d, origin, info)
	-- путь сквозь комнату для Гула: вход, середина, перед выходом
	info.path = {
		at(origin, 0, 4, -2).Position,
		at(origin, 0, 4, -d.l / 2).Position,
		(exitCF * CFrame.new(0, 4, 2.5)).Position,
	}
	-- угол для Смотрителя: дальний от входа
	info.watcherSpawn = at(origin, (if d.door % 2 == 0 then 1 else -1) * (d.w / 2 - 3), 0, -d.l + 3)
	info.center = at(origin, 0, d.h / 2, -d.l / 2)
	info.size = Vector3.new(d.w, d.h, d.l)
	-- темнота: свет выключен
	if d.dark then
		for _, bulb in info.lights do
			bulb:SetAttribute("Dark", true)
			local l = bulb:FindFirstChildOfClass("PointLight")
			if l then
				l.Enabled = false
			end
			bulb.Material = M.Glass
			bulb.Color = rgb(60, 56, 50)
		end
		for _, d2 in m:GetDescendants() do
			if d2:IsA("PointLight") then
				d2.Enabled = false
			end
		end
	end
	return info
end

-- Игрок внутри комнаты (по прямоугольнику пола)
function Builder.contains(info, pos: Vector3): boolean
	local lp = info.origin:PointToObjectSpace(pos)
	local d = info.desc
	return math.abs(lp.X) <= d.w / 2 + 0.5 and lp.Z <= 0.5 and lp.Z >= -d.l - 0.5 and lp.Y > -3 and lp.Y < d.h + 2
end

Builder.sideSlot = sideSlot
Builder.frontSlot = frontSlot
Builder.at = at
Builder.shell = shell
Builder.ceilingLights = ceilingLights
Builder.addCloset = addCloset
Builder.addDresser = addDresser

return Builder
