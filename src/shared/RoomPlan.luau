--!nonstrict
-- План забега без Roblox API: какая комната за каждой дверью, куда она поворачивает,
-- заперта ли дверь, есть ли сборщик платы, Смотритель, темнота и Гул.
-- Путь никогда не разворачивается назад, поэтому комнаты не налезают друг на друга

local Rules = require(script.Parent.Rules)

local Plan = {}

-- размеры комнат: w — ширина, l — длина (от входа до дальней стены)
Plan.SIZES = {
	start = { w = 30, l = 30 },
	corridor = { w = 10, l = 32 },
	room = { w = 24, l = 26 },
	office = { w = 22, l = 22 },
	hall = { w = 34, l = 34 },
	elevator = { w = 22, l = 28 },
	boss = { w = 76, l = 88 },
}
Plan.HEIGHT = { start = 16, corridor = 12, room = 13, office = 12, hall = 18, elevator = 14, boss = 26 }

-- простой генератор случайных чисел (одинаковый в тестах и в игре)
function Plan.rng(seed: number)
	local s = math.floor(seed) % 2147483647
	if s <= 0 then
		s += 2147483646
	end
	return function(): number
		s = (s * 48271) % 2147483647
		return s / 2147483647
	end
end

function Plan.new(seed: number)
	local rand = Plan.rng(seed)
	-- путь идёт «лесенкой»: вперёд и в одну сторону (за забег сторона одна),
	-- поэтому он никогда не возвращается к старым комнатам
	local side = if rand() < 0.5 then -1 else 1
	return { seed = seed, heading = 0, side = side, lastHum = -99, rand = rand, ox = 0, oz = 0, rects = {} }
end

-- направление «вперёд» и «вправо» на полу для курса h (0 — -Z, -1 — -X, 1 — +X)
local function frame(h: number): (number, number, number, number)
	if h == 0 then
		return 0, -1, 1, 0
	elseif h < 0 then
		return -1, 0, 0, -1
	end
	return 1, 0, 0, 1
end

-- прямоугольник комнаты на полу { x0, z0, x1, z1 }
local function footprint(state, w: number, l: number)
	local fx, fz, rx, rz = frame(state.heading)
	local xs, zs = {}, {}
	for _, c in { { -w / 2, 0 }, { w / 2, 0 }, { -w / 2, l }, { w / 2, l } } do
		table.insert(xs, state.ox + rx * c[1] + fx * c[2])
		table.insert(zs, state.oz + rz * c[1] + fz * c[2])
	end
	return { math.min(table.unpack(xs)), math.min(table.unpack(zs)), math.max(table.unpack(xs)), math.max(table.unpack(zs)) }
end
Plan.footprint = footprint

-- налезает ли комната на недавние (одновременно загруженные) комнаты
local function overlaps(state, r): boolean
	for _, o in state.rects do
		local ox = math.min(r[3], o[3]) - math.max(r[1], o[1])
		local oz = math.min(r[4], o[4]) - math.max(r[2], o[2])
		if ox > 1.2 and oz > 1.2 then
			return true
		end
	end
	return false
end
Plan.overlaps = overlaps

local function pickKind(r: number): string
	if r < 0.34 then
		return "corridor"
	elseif r < 0.64 then
		return "room"
	elseif r < 0.8 then
		return "office"
	end
	return "hall"
end

-- Следующая комната: та, в которую ведёт дверь с номером door. Вызывать по порядку
function Plan.room(state, door: number)
	local rand = state.rand
	local sector = Rules.sectorOf(math.max(1, door))
	local d = { door = door, sector = sector, turn = 0 }
	if door == 0 then
		d.kind = "start"
	elseif Rules.isSectorEnd(door) then
		d.kind = if Rules.hasBoss(sector) then "boss" else "elevator"
	else
		d.kind = pickKind(rand())
	end
	local size = Plan.SIZES[d.kind]
	d.w, d.l, d.h = size.w, size.l, Plan.HEIGHT[d.kind]
	-- комната не помещается рядом со старыми: берётся поуже (коридор или кабинет)
	if d.kind == "corridor" or d.kind == "room" or d.kind == "office" or d.kind == "hall" then
		for _, kind in { d.kind, "corridor", "office" } do
			local sz = Plan.SIZES[kind]
			if not overlaps(state, footprint(state, sz.w, sz.l)) then
				d.kind = kind
				d.w, d.l, d.h = sz.w, sz.l, Plan.HEIGHT[kind]
				break
			end
		end
	end
	-- первая комната сектора и особые комнаты всегда прямые и спокойные
	local calm = d.kind == "start" or d.kind == "boss" or d.kind == "elevator" or (door - 1) % Rules.SECTOR_LEN == 0
	-- перед большим залом конца сектора выход прямой, иначе зал налезет на старые комнаты
	local beforeEnd = Rules.isSectorEnd(door + 1) or Rules.isSectorEnd(door + 2) or Rules.isSectorEnd(door + 3)
	if not calm then
		-- поворот: назад развернуться нельзя
		local r = rand()
		-- кабинет короткий, поэтому выход у него всегда прямо
		local wantTurn = if d.kind == "corridor" then r < 0.6 elseif d.kind == "office" then false else r < 0.3
		local _ = rand()
		if wantTurn and not beforeEnd then
			d.turn = if state.heading == 0 then state.side else -state.heading
		end
		-- поворот только туда, где хватит места следующей большой комнате
		local options = { d.turn, 0 }
		local mine = footprint(state, d.w, d.l)
		for _, turn in options do
			if state.heading + turn >= -1 and state.heading + turn <= 1 then
				d.turn = turn
				local ex, ez = Plan.exitOf(d)
				local fx, fz, rx, rz = frame(state.heading)
				local probe = {
					ox = state.ox + rx * ex + fx * -ez,
					oz = state.oz + rz * ex + fz * -ez,
					heading = state.heading + turn,
					rects = table.clone(state.rects),
				}
				table.insert(probe.rects, mine)
				local big = Plan.SIZES.hall
				if not overlaps(probe, footprint(probe, big.w, big.l)) then
					break
				end
			end
			d.turn = 0
		end
		-- запертая дверь или сборщик платы на выходе (не вместе)
		local nextDoor = door + 1
		if not Rules.isSectorEnd(nextDoor) then
			if rand() < Rules.lockedChance(door) then
				d.locked = true
			elseif rand() < Rules.tollChance(door) then
				d.toll = true
			end
		end
		d.dark = rand() < Rules.darkChance(door)
		d.watcher = d.kind ~= "corridor" and rand() < Rules.watcherChance(door)
		if door - state.lastHum >= Rules.HUM_GAP and rand() < Rules.humChance(door) then
			d.hum = true
			state.lastHum = door
		end
	end
	-- шкафы для пряток: в каждой комнате хотя бы один
	d.closets = if d.kind == "hall" then 4 elseif d.kind == "corridor" then 1 elseif d.kind == "boss" then 6 else 2
	-- запомнить место комнаты и перейти к её выходу
	table.insert(state.rects, footprint(state, d.w, d.l))
	if #state.rects > 7 then
		table.remove(state.rects, 1)
	end
	local ex, ez = Plan.exitOf(d)
	if d.kind == "boss" then
		-- сразу за залом Слепого стоит лифт
		local el = Plan.SIZES.elevator
		local fx0, fz0 = frame(state.heading)
		local save = { state.ox, state.oz }
		state.ox += fx0 * d.l
		state.oz += fz0 * d.l
		table.insert(state.rects, footprint(state, el.w, el.l))
		state.ox, state.oz = save[1], save[2]
		ez -= el.l
	end
	local fx, fz, rx, rz = frame(state.heading)
	state.ox += rx * ex + fx * -ez
	state.oz += rz * ex + fz * -ez
	state.heading += d.turn
	d.heading = state.heading
	return d
end

-- Где выход относительно входа комнаты (вход в 0,0, комната уходит в -Z).
-- Возвращает смещение x, z и поворот (в долях пол-оборота: 0, 1 = влево, -1 = вправо)
function Plan.exitOf(d): (number, number, number)
	if d.turn == 0 then
		return 0, -d.l, 0
	end
	local z = -(d.l - 5.5)
	if d.turn < 0 then
		return -d.w / 2, z, 1
	end
	return d.w / 2, z, -1
end

return Plan
