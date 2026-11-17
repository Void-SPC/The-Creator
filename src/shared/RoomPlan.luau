--!nonstrict
-- План забега без Roblox API: какой зал музея за каждой дверью, где настоящий выход и
-- ложные двери, размер дверей (служебная, обычная, парадная), сколько шкафчиков,
-- замки, Монетчик, Тьма, аномалии. Путь идёт «лесенкой» и не налезает на старые залы

local Rules = require(script.Parent.Rules)

local Plan = {}

-- w — ширина, l — длина, h — высота, dy — подъём пола к выходу, exits — возможные
-- выходы, branch — сколько дверей (лишние ложные), min — с какой двери встречается,
-- door — какие двери любит зал, hides — сколько шкафчиков самое большее
Plan.TEMPLATES = {
	corridor = { w = 12, l = 40, h = 13, weight = 4, exits = { "front", "side" }, door = "normal", hides = 1 },
	longhall = { w = 12, l = 70, h = 13, weight = 2, min = 5, exits = { "front", "side" }, door = "normal", hides = 2 },
	shorthall = { w = 12, l = 22, h = 13, weight = 2, exits = { "front" }, door = "normal", hides = 1 },
	gallery = { w = 30, l = 44, h = 16, weight = 10, exits = { "front", "side" }, branch = 2, door = "grand", hides = 2 },
	sculpture = { w = 36, l = 40, h = 18, weight = 10, exits = { "front", "frontL", "frontR", "side" }, door = "grand", hides = 2 },
	cases = { w = 30, l = 34, h = 14, weight = 9, exits = { "front", "frontL", "frontR", "side" }, door = "normal", hides = 2 },
	fossil = { w = 44, l = 56, h = 24, weight = 7, min = 8, exits = { "front", "side" }, door = "grand", hides = 3 },
	armory = { w = 28, l = 36, h = 14, weight = 7, exits = { "front", "side" }, door = "normal", hides = 2 },
	ceramics = { w = 26, l = 30, h = 14, weight = 7, exits = { "front", "frontL", "frontR" }, door = "normal", hides = 2 },
	archive = { w = 34, l = 40, h = 16, weight = 5, min = 6, exits = { "frontL", "frontR", "side" }, branch = 2, door = "normal", hides = 2 },
	storage = { w = 30, l = 34, h = 14, weight = 4, min = 6, exits = { "frontL", "frontR", "side" }, branch = 2, door = "small", hides = 2 },
	tech = { w = 12, l = 34, h = 10, weight = 3, min = 12, exits = { "front" }, door = "small", hides = 2 },
	stairsup = { w = 16, l = 40, h = 13, weight = 2, min = 4, dy = 10, exits = { "front" }, door = "normal", hides = 1 },
	stairsdown = { w = 16, l = 40, h = 13, weight = 2, min = 4, dy = -10, exits = { "front" }, door = "normal", hides = 1 },
	restroom = { w = 24, l = 26, h = 12, weight = 3, exits = { "front" }, door = "small", hides = 1 },
	cafe = { w = 32, l = 32, h = 14, weight = 4, exits = { "front", "side" }, door = "normal", hides = 1 },
	rotunda = { w = 46, l = 46, h = 24, weight = 6, min = 10, exits = { "front", "frontL", "frontR", "side" }, branch = 3, door = "grand", hides = 3 },
	oddities = { w = 30, l = 30, h = 14, weight = 7, exits = { "front", "frontL", "frontR" }, door = "normal", hides = 2 },
	blank = { w = 30, l = 30, h = 14, weight = 2, min = 15, exits = { "front", "frontL", "frontR" }, door = "normal", hides = 1 },
	clocks = { w = 30, l = 36, h = 16, weight = 6, min = 3, exits = { "front", "frontL", "frontR", "side" }, door = "normal", hides = 2 },
	music = { w = 32, l = 34, h = 16, weight = 6, min = 3, exits = { "front", "frontL", "frontR", "side" }, door = "normal", hides = 2 },
	archaeology = { w = 40, l = 44, h = 18, weight = 5, min = 8, exits = { "front", "frontL", "frontR", "side" }, branch = 2, door = "grand", hides = 2 },
	-- большие залы стран и эпох
	egypt = { w = 48, l = 56, h = 24, weight = 5, min = 4, exits = { "front", "frontL", "frontR", "side" }, branch = 2, door = "grand", hides = 3 },
	rome = { w = 50, l = 56, h = 24, weight = 5, min = 4, exits = { "front", "frontL", "frontR", "side" }, branch = 2, door = "grand", hides = 2 },
	knights = { w = 44, l = 52, h = 22, weight = 6, min = 2, exits = { "front", "frontL", "frontR", "side" }, branch = 2, door = "grand", hides = 3 },
	estonia = { w = 40, l = 48, h = 20, weight = 5, min = 6, exits = { "front", "frontL", "frontR", "side" }, door = "grand", hides = 2 },
	russia = { w = 44, l = 50, h = 22, weight = 5, min = 6, exits = { "front", "frontL", "frontR", "side" }, door = "grand", hides = 2 },
	england = { w = 42, l = 48, h = 20, weight = 5, min = 6, exits = { "front", "frontL", "frontR", "side" }, door = "grand", hides = 2 },
	france = { w = 44, l = 50, h = 22, weight = 5, min = 6, exits = { "front", "frontL", "frontR", "side" }, door = "grand", hides = 2 },
	japan = { w = 40, l = 46, h = 20, weight = 4, min = 8, exits = { "front", "frontL", "frontR", "side" }, door = "normal", hides = 2 },
	mechanisms = { w = 34, l = 38, h = 18, weight = 5, min = 12, exits = { "front", "frontL", "frontR", "side" }, door = "small", hides = 2 },
	-- особые: выбираются отдельно
	figures = { w = 40, l = 40, h = 16, exits = { "front" }, door = "normal", hides = 0 },
	voidhall = { w = 12, l = 180, h = 14, exits = { "front" }, door = "normal", hides = 2 },
	start = { w = 30, l = 30, h = 16, exits = { "front" }, door = "grand", hides = 0 },
	codehall = { w = 76, l = 44, h = 18, exits = { "front" }, door = "grand", hides = 2 },
	passage = { w = 18, l = 44, h = 16, exits = { "front" }, door = "grand", hides = 1 },
	arena = { w = 80, l = 104, h = 26, dy = -10, stairW = 56, exits = { "front" }, door = "grand", hides = 0 },
	lifthall = { w = 30, l = 30, h = 16, exits = { "front" }, door = "small", hides = 0 },
	final = { w = 50, l = 60, h = 20, exits = { "front" }, door = "normal", hides = 0 },
}

Plan.ORDER = { "corridor", "longhall", "shorthall", "gallery", "sculpture", "cases", "fossil", "armory", "ceramics", "archive", "storage", "tech", "stairsup", "stairsdown", "restroom", "cafe", "rotunda", "oddities", "blank", "clocks", "music", "archaeology", "mechanisms", "egypt", "rome", "knights", "estonia", "russia", "england", "france", "japan" }

Plan.DOORS = { small = { w = 4, h = 7.5 }, normal = { w = 5, h = 8 }, grand = { w = 8, h = 11 } }
local RANK = { small = 1, normal = 2, grand = 3 }

local SPECIAL = { [0] = "start", [Rules.CODE_ROOM] = "codehall", [Rules.PASS_ROOM] = "passage", [Rules.BOSS_ROOM] = "arena", [Rules.LIFT_ROOM] = "lifthall", [Rules.FINAL_ROOM] = "final" }

-- перед особыми залами путь прямой и спокойный
local function straightZone(door: number): boolean
	return (door >= Rules.CODE_ROOM - 5 and door <= Rules.BOSS_ROOM + 1) or door >= Rules.LIFT_ROOM - 3
end

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
	local side = if rand() < 0.5 then -1 else 1
	local first = Rules.DARK_FIRST[1] + math.floor(rand() * (Rules.DARK_FIRST[2] - Rules.DARK_FIRST[1] + 1))
	return {
		seed = seed,
		heading = 0,
		side = side,
		rand = rand,
		ox = 0,
		oy = 0,
		oz = 0,
		rects = {},
		firstDark = first,
		lastDark = -99,
		lastFig = 0,
		lastVoid = 0,
		lastHides = 1,
		lastExit = nil,
		nextKind = nil,
	}
end

local function frame(h: number): (number, number, number, number)
	if h == 0 then
		return 0, -1, 1, 0
	elseif h < 0 then
		return -1, 0, 0, -1
	end
	return 1, 0, 0, 1
end
Plan.frame = frame

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

-- налезает ли (или стоит вплотную) на недавние залы, кроме предыдущего
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

-- залы, к которым сбоку может быть пристроен туалет: где в боковой стене дверь (z)
Plan.ANNEX = { sculpture = -26, cases = -22, armory = -24.5, fossil = -44 }
Plan.ANNEX_SIZE = { w = 18, l = 16, h = 11 }

-- какой зал будет за дверью door (выбирается заранее, чтобы знать размер двери)
local function pickKind(state, door: number): string
	if SPECIAL[door] then
		return SPECIAL[door]
	end
	local rand = state.rand
	local calm = straightZone(door)
	if not calm and state.lastHides > 0 and door >= Rules.MIMIC.from and door - state.lastFig >= Rules.MIMIC.gap and rand() < Rules.MIMIC.chance then
		return "figures"
	end
	if not calm and door >= 25 and door - state.lastVoid >= 20 and rand() < 0.035 then
		return "voidhall"
	end
	local total = 0
	local function ok(id)
		local t = Plan.TEMPLATES[id]
		return door >= (t.min or 0) and not (calm and t.dy)
	end
	for _, id in Plan.ORDER do
		if ok(id) then
			total += Plan.TEMPLATES[id].weight
		end
	end
	local r = rand() * total
	for _, id in Plan.ORDER do
		if ok(id) then
			r -= Plan.TEMPLATES[id].weight
			if r <= 0 then
				return id
			end
		end
	end
	return "corridor"
end

local function after(state, x: number, z: number, turn: number)
	local fx, fz, rx, rz = frame(state.heading)
	return { ox = state.ox + rx * x + fx * -z, oz = state.oz + rz * x + fz * -z, heading = state.heading + turn }
end

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

-- Зал за дверью door. Вызывать по порядку с 0
function Plan.room(state, door: number)
	local rand = state.rand
	local d = { door = door, zone = Rules.zone(door), decoys = {} }
	d.kind = state.nextKind or pickKind(state, door)
	if SPECIAL[door] then
		d.kind = SPECIAL[door]
	end
	local special = SPECIAL[door] ~= nil
	local calm = special or door <= 1 or straightZone(door)
	-- не помещается рядом со старыми залами — берётся коридор
	if not special then
		for _, kind in { d.kind, "corridor", "shorthall" } do
			local t = Plan.TEMPLATES[kind]
			if not overlaps(state, footprint(state, t.w, t.l)) then
				d.kind = kind
				break
			end
		end
	end
	if d.kind == "figures" then
		state.lastFig = door
	elseif d.kind == "voidhall" then
		state.lastVoid = door
	end
	local quiet = special or d.kind == "figures" or d.kind == "voidhall"
	local t = Plan.TEMPLATES[d.kind]
	d.w, d.l, d.h, d.dy = t.w, t.l, t.h, t.dy or 0
	d.stairW = t.stairW
	-- настоящий выход: из разрешённых, с местом для следующего большого зала
	local mine = footprint(state, d.w, d.l)
	local options = {}
	for _, name in t.exits do
		local x, z, turn = Plan.exitPos(t, name, if state.heading == 0 then state.side else -state.heading)
		if turnAllowed(state, turn) and not (calm and name ~= "front") then
			table.insert(options, { name = name, x = x, z = z, turn = turn })
		end
	end
	for i = #options, 2, -1 do
		local j = math.floor(rand() * i) + 1
		options[i], options[j] = options[j], options[i]
	end
	local chosen = nil
	for _, o in options do
		local nx = after(state, o.x, o.z, o.turn)
		nx.rects = table.clone(state.rects)
		table.insert(nx.rects, mine)
		local big = Plan.TEMPLATES.rotunda
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
	-- ложные двери в развилках
	if t.branch and not calm then
		local want = t.branch - 1
		for _, name in t.exits do
			if want > 0 and name ~= chosen.name then
				local side = if state.heading == 0 then state.side else -state.heading
				local x, z, turn = Plan.exitPos(t, name, side)
				if name == "side" and rand() < 0.5 then
					x, z, turn = Plan.exitPos(t, name, -side)
				end
				table.insert(d.decoys, { name = name, x = x, z = z, turn = turn, y = 0 })
				want -= 1
			end
		end
	end
	-- шкафчики: не в каждом зале, но двух залов подряд без укрытия не бывает
	local hides = math.floor(rand() * (t.hides + 1))
	if hides == 0 and state.lastHides == 0 and t.hides > 0 then
		hides = 1
	end
	if special then
		hides = t.hides
	end
	d.hides = hides
	if not quiet and door > 1 then
		local nextSpecial = SPECIAL[door + 1] ~= nil
		if not nextSpecial then
			if rand() < Rules.lockedChance(door) then
				d.locked = true
			elseif rand() < Rules.coinChance(door) then
				d.coin = true
			end
		end
		-- Тьма: первый раз между 11-й и 17-й дверью, потом шанс растёт с каждой дверью
		if not straightZone(door) and (hides > 0 or state.lastHides > 0) then
			local since = door - state.lastDark
			if (state.lastDark < 0 and door >= state.firstDark) or (state.lastDark > 0 and rand() < Rules.darkChance(since)) then
				d.dark = true
				state.lastDark = door
			end
		end
		d.windows = door < 60 and rand() < 0.4
		d.mono = door > 10 and rand() < 0.04
	end
	state.lastHides = hides
	-- пристройка-туалет с той стороны, куда путь не поворачивает (если там свободно)
	local az = Plan.ANNEX[d.kind]
	if az and not special and door >= 3 and rand() < 0.45 then
		local s = if state.heading == 0 then -state.side else state.heading
		local A = Plan.ANNEX_SIZE
		local fx, fz, rx, rz = frame(state.heading)
		local xs, zs = {}, {}
		for _, c in { { d.w / 2, -az - A.w / 2 }, { d.w / 2 + A.l + 1, -az - A.w / 2 }, { d.w / 2, -az + A.w / 2 }, { d.w / 2 + A.l + 1, -az + A.w / 2 } } do
			table.insert(xs, state.ox + rx * s * c[1] + fx * c[2])
			table.insert(zs, state.oz + rz * s * c[1] + fz * c[2])
		end
		local r = { math.min(table.unpack(xs)), math.min(table.unpack(zs)), math.max(table.unpack(xs)), math.max(table.unpack(zs)) }
		local free = true
		for _, o in state.rects do
			if math.min(r[3], o[3]) - math.max(r[1], o[1]) > -Plan.GAP and math.min(r[4], o[4]) - math.max(r[2], o[2]) > -Plan.GAP then
				free = false
			end
		end
		if free then
			d.annex = { side = s, z = az, rect = r }
			table.insert(state.rects, r)
		end
	end
	d.light = Rules.light(door)
	-- размер дверей: вход — как выход прошлого зала; выход — по вкусу этого и следующего
	d.entrySize = state.lastExit or "grand"
	state.nextKind = if door < Rules.FINAL_ROOM then pickKind(state, door + 1) else nil
	local nextT = state.nextKind and Plan.TEMPLATES[state.nextKind]
	local a, b = t.door, if nextT then nextT.door else t.door
	d.exitSize = if RANK[a] <= RANK[b] then a else b
	if door == Rules.CODE_ROOM then
		d.exitSize = "grand"
	end
	state.lastExit = d.exitSize
	-- запомнить место и перейти к выходу
	table.insert(state.rects, mine)
	while #state.rects > 9 do
		table.remove(state.rects, 1)
	end
	local nx = after(state, d.exit.x, d.exit.z, d.exit.turn)
	state.ox, state.oz, state.heading = nx.ox, nx.oz, nx.heading
	state.oy += d.dy
	d.heading = state.heading
	return d
end

return Plan
