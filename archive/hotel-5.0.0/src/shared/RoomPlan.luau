--!nonstrict
-- План забега без Roblox API: какая комната за каждой дверью (19 видов), где у неё
-- настоящий выход и ложные двери, лестницы вверх и вниз, замки, Монетчик,
-- Смотритель, Гул, свет. Путь идёт «лесенкой» и никогда не налезает на старые комнаты

local Rules = require(script.Parent.Rules)

local Plan = {}

-- Виды комнат. w — ширина, l — длина, h — высота, dy — подъём пола к выходу (лестницы),
-- exits — какие выходы бывают: front (по центру), frontL/frontR (у углов дальней стены),
-- side (в боковой стене у дальнего конца), branch — сколько дверей (лишние ведут
-- в никуда и переносят игрока к настоящей), min — с какой двери встречается
Plan.TEMPLATES = {
	corridor = { w = 10, l = 40, h = 12, weight = 13, exits = { "front", "side" } },
	longhall = { w = 10, l = 64, h = 12, weight = 6, min = 5, exits = { "front", "side" } },
	shorthall = { w = 10, l = 20, h = 12, weight = 5, exits = { "front" } },
	bedroom = { w = 26, l = 28, h = 13, weight = 10, exits = { "front", "frontL", "frontR", "side" } },
	suite = { w = 36, l = 40, h = 14, weight = 6, min = 8, exits = { "front", "frontL", "frontR", "side" }, branch = 3 },
	office = { w = 26, l = 26, h = 12, weight = 7, exits = { "front", "frontL", "frontR" } },
	library = { w = 34, l = 40, h = 16, weight = 5, min = 10, exits = { "frontL", "frontR", "side" }, branch = 2 },
	lounge = { w = 32, l = 30, h = 14, weight = 6, exits = { "front", "side" } },
	dining = { w = 30, l = 38, h = 14, weight = 5, exits = { "front", "side" } },
	kitchen = { w = 26, l = 30, h = 12, weight = 5, exits = { "front", "side" } },
	storage = { w = 30, l = 34, h = 14, weight = 5, min = 6, exits = { "frontL", "frontR", "side" }, branch = 2 },
	pillarhall = { w = 42, l = 46, h = 20, weight = 4, min = 12, exits = { "front", "frontL", "frontR", "side" }, branch = 3 },
	stairsup = { w = 14, l = 40, h = 12, weight = 4, min = 4, dy = 10, exits = { "front" } },
	stairsdown = { w = 14, l = 40, h = 12, weight = 4, min = 4, dy = -10, exits = { "front" } },
	bathroom = { w = 22, l = 24, h = 12, weight = 4, exits = { "front" } },
	laundry = { w = 26, l = 26, h = 12, weight = 4, exits = { "front", "side" } },
	empty = { w = 30, l = 30, h = 14, weight = 3, min = 15, exits = { "front", "frontL", "frontR" } },
	gallery = { w = 30, l = 40, h = 14, weight = 4, exits = { "front", "side" }, branch = 2 },
	crawl = { w = 12, l = 30, h = 9, weight = 3, min = 20, exits = { "front" } },
	-- особые
	start = { w = 30, l = 30, h = 14, exits = { "front" } },
	boss = { w = 76, l = 88, h = 26, exits = { "front" } },
}

Plan.ORDER = { "corridor", "longhall", "shorthall", "bedroom", "suite", "office", "library", "lounge", "dining", "kitchen", "storage", "pillarhall", "stairsup", "stairsdown", "bathroom", "laundry", "empty", "gallery", "crawl" }

-- выход по названию: x, z в кадре комнаты и поворот (-1 влево, 1 вправо, 0 прямо)
function Plan.exitPos(t, name: string, side: number): (number, number, number)
	if name == "front" then
		return 0, -t.l, 0
	elseif name == "frontL" then
		return -t.w / 4, -t.l, 0
	elseif name == "frontR" then
		return t.w / 4, -t.l, 0
	end
	return side * t.w / 2, -(t.l - 6), side
end

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
	-- путь идёт вперёд и в одну сторону (за забег сторона одна)
	local side = if rand() < 0.5 then -1 else 1
	return { seed = seed, heading = 0, side = side, lastHum = -99, rand = rand, ox = 0, oy = 0, oz = 0, rects = {} }
end

-- «вперёд» и «вправо» на полу для курса h (0 — -Z, -1 — -X, 1 — +X)
local function frame(h: number): (number, number, number, number)
	if h == 0 then
		return 0, -1, 1, 0
	elseif h < 0 then
		return -1, 0, 0, -1
	end
	return 1, 0, 0, 1
end
Plan.frame = frame

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

-- налезает ли (или стоит вплотную стена к стене) на недавние комнаты, кроме предыдущей
Plan.GAP = 2.4
local function overlaps(state, r): boolean
	for i, o in state.rects do
		if i < #state.rects then
			local ox = math.min(r[3], o[3]) - math.max(r[1], o[1])
			local oz = math.min(r[4], o[4]) - math.max(r[2], o[2])
			if ox > -Plan.GAP and oz > -Plan.GAP then
				return true
			end
		end
	end
	return false
end
Plan.overlaps = overlaps

local function pickKind(rand, door: number): string
	local total = 0
	for _, id in Plan.ORDER do
		local t = Plan.TEMPLATES[id]
		if door >= (t.min or 0) then
			total += t.weight
		end
	end
	local r = rand() * total
	for _, id in Plan.ORDER do
		local t = Plan.TEMPLATES[id]
		if door >= (t.min or 0) then
			r -= t.weight
			if r <= 0 then
				return id
			end
		end
	end
	return "corridor"
end

-- куда ведёт выход: позиция следующей комнаты и её курс
local function after(state, x: number, z: number, turn: number)
	local fx, fz, rx, rz = frame(state.heading)
	return { ox = state.ox + rx * x + fx * -z, oz = state.oz + rz * x + fz * -z, heading = state.heading + turn }
end

-- поворот разрешён: вперёд или в сторону «лесенки», назад нельзя
local function turnAllowed(state, turn: number): boolean
	if turn == 0 then
		return true
	end
	local h = state.heading + turn
	if h < -1 or h > 1 then
		return false
	end
	if state.heading == 0 then
		return turn == state.side
	end
	return h == 0
end

-- Комната за дверью door. Вызывать по порядку с 0
function Plan.room(state, door: number)
	local rand = state.rand
	local d = { door = door, zone = Rules.zone(math.max(1, door)), decoys = {} }
	if door == 0 then
		d.kind = "start"
	elseif Rules.isBoss(door) then
		d.kind = "boss"
	else
		d.kind = pickKind(rand, door)
	end
	-- перед залом Слепого и в начале путь прямой и спокойный
	local calm = door <= 1 or d.kind == "boss" or d.kind == "start"
	local beforeBoss = door >= Rules.BOSS_DOOR - 3
	-- не помещается рядом со старыми — берётся комната поуже
	if not calm then
		for _, kind in { d.kind, "corridor", "shorthall" } do
			local t = Plan.TEMPLATES[kind]
			if not overlaps(state, footprint(state, t.w, t.l)) then
				d.kind = kind
				break
			end
		end
		if beforeBoss and (d.kind == "stairsup" or d.kind == "stairsdown") then
			d.kind = "corridor"
		end
	end
	local t = Plan.TEMPLATES[d.kind]
	d.w, d.l, d.h, d.dy = t.w, t.l, t.h, t.dy or 0
	-- выбор настоящего выхода: из разрешённых, с местом для следующей большой комнаты
	local mine = footprint(state, d.w, d.l)
	local options = {}
	for _, name in t.exits do
		local x, z, turn = Plan.exitPos(t, name, if state.heading == 0 then state.side else -state.heading)
		if turnAllowed(state, turn) and not (beforeBoss and turn ~= 0) and not (calm and name ~= "front") then
			table.insert(options, { name = name, x = x, z = z, turn = turn })
		end
	end
	-- перемешать варианты
	for i = #options, 2, -1 do
		local j = math.floor(rand() * i) + 1
		options[i], options[j] = options[j], options[i]
	end
	local chosen = nil
	for _, o in options do
		local nx = after(state, o.x, o.z, o.turn)
		nx.rects = table.clone(state.rects)
		-- для следующей комнаты эта будет «предыдущей» (стоит вплотную у двери)
		table.insert(nx.rects, mine)
		local big = Plan.TEMPLATES.suite
		if not overlaps(nx, footprint(nx, big.w, big.l)) then
			chosen = o
			break
		end
	end
	if not chosen then
		local x, z = Plan.exitPos(t, "front", 0)
		chosen = { name = "front", x = x, z = z, turn = 0 }
	end
	d.exit = { name = chosen.name, x = chosen.x, z = chosen.z, turn = chosen.turn, y = d.dy }
	-- ложные двери в развилистых комнатах: на других местах выхода
	if t.branch and not calm and not beforeBoss then
		local want = t.branch - 1
		for _, name in t.exits do
			if want > 0 and name ~= chosen.name then
				local side = if state.heading == 0 then state.side else -state.heading
				local x, z, turn = Plan.exitPos(t, name, side)
				-- боковая ложная дверь может быть и на другой стене: она никуда не ведёт
				if name == "side" and rand() < 0.5 then
					x, z, turn = Plan.exitPos(t, name, -side)
				end
				table.insert(d.decoys, { name = name, x = x, z = z, turn = turn, y = 0 })
				want -= 1
			end
		end
	end
	if not calm then
		local nextDoor = door + 1
		if not Rules.isBoss(nextDoor) then
			if rand() < Rules.lockedChance(door) then
				d.locked = true
			elseif rand() < Rules.coinChance(door) then
				d.coin = true
			end
		end
		d.watcher = d.kind ~= "corridor" and d.kind ~= "shorthall" and d.kind ~= "longhall" and d.kind ~= "crawl" and d.kind ~= "stairsup" and d.kind ~= "stairsdown" and rand() < Rules.watcherChance(door)
		if door - state.lastHum >= Rules.HUM_GAP and rand() < Rules.humChance(door) then
			d.hum = true
			state.lastHum = door
		end
		d.windows = d.kind ~= "crawl" and rand() < Rules.windowChance(door)
	end
	d.light = Rules.light(door)
	d.blackout = Rules.blackout(door)
	-- запомнить место и перейти к выходу
	table.insert(state.rects, mine)
	if #state.rects > 7 then
		table.remove(state.rects, 1)
	end
	local nx = after(state, d.exit.x, d.exit.z, d.exit.turn)
	state.ox, state.oz, state.heading = nx.ox, nx.oz, nx.heading
	state.oy += d.dy
	d.heading = state.heading
	d.oy = state.oy
	return d
end

return Plan
