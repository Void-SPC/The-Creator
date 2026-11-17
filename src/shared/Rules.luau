--!nonstrict
-- Правила «The Museum» без Roblox API: первая локация из 100 дверей, свет, предметы,
-- Монетчик, Тьма, тебЯ, Колосс с зеркалами, кодовый замок. Проверяются тестами

local Rules = {}

-- локация --------------------------------------------------------------------

Rules.CHAPTER = 100
Rules.CODE_ROOM = 48 -- зал трёх замков (дверь 049 заперта)
Rules.PASS_ROOM = 49 -- переход к залу Колосса
Rules.BOSS_ROOM = 50 -- зал Колосса
Rules.LIFT_ROOM = 99 -- лифт, загадка и лестница обслуживания
Rules.FINAL_ROOM = 100 -- заброшенный зал

function Rules.isSpecial(door: number): boolean
	return door == 0 or door == Rules.CODE_ROOM or door == Rules.PASS_ROOM or door == Rules.BOSS_ROOM or door == Rules.LIFT_ROOM or door == Rules.FINAL_ROOM
end

function Rules.plate(door: number): string
	return string.format("%03d", door)
end

-- оформление: парадные залы → старое крыло → заброшенная часть
function Rules.zone(door: number): string
	if door <= 50 then
		return "classic"
	elseif door < 100 then
		return "old"
	end
	return "ruin"
end

-- яркость ламп: в старом крыле свет слабее
function Rules.light(door: number): number
	if door <= 30 then
		return 1
	end
	return math.max(0.45, 1 - (door - 30) / 70 * 0.55)
end

-- Монетчик -------------------------------------------------------------------

Rules.SELF_SHARE = 0.7 -- «расплатиться собой»: 70 % текущего здоровья
Rules.COIN_FROM = 30
Rules.COINS_PER_DOOR = 2

-- ставка: в первой локации от 20 до 100, в каждой следующей на 100 больше, максимум 500
function Rules.coinPrice(door: number): number
	local loc = math.floor((math.max(1, door) - 1) / 100)
	local t = ((math.max(1, door) - 1) % 100) / 99
	local lo = if loc == 0 then 20 else loc * 100
	local hi = (loc + 1) * 100
	return math.min(500, math.floor(lo + (hi - lo) * t + 0.5))
end

-- здоровье после платы собой; с 1 здоровья Монетчик забирает всё
function Rules.afterSelfToll(health: number): number
	if health <= 1.5 then
		return 0
	end
	return math.max(1, health * (1 - Rules.SELF_SHARE))
end

function Rules.coinChance(door: number): number
	if door < Rules.COIN_FROM then
		return 0
	end
	return 0.1
end

-- Тьма -----------------------------------------------------------------------

Rules.DARK_FIRST = { 11, 17 } -- первый пролёт где-то между этими дверями
Rules.DARK_GAP = 4

-- шанс после очередной открытой двери растёт с каждой дверью без Тьмы
function Rules.darkChance(since: number): number
	if since < Rules.DARK_GAP then
		return 0
	end
	return math.min(0.4, (since - Rules.DARK_GAP + 1) * 0.06)
end

-- тебЯ ----------------------------------------------------------------------

-- delay — на сколько секунд статуя отстаёт от игрока: повторяет его путь с этой задержкой
-- (стоял пять секунд — и она постоит пять секунд на том же месте)
Rules.MIMIC = { speed = 17, wait = 1, damage = 35, from = 20, gap = 8, chance = 0.07, delay = 2.5 }

-- где статуя должна быть сейчас: последняя запись, сделанная не позже now - delay
function Rules.replayAt(log: { { t: number, x: number, z: number } }, now: number): number?
	local cut = now - Rules.MIMIC.delay
	local found = nil
	for i, e in log do
		if e.t <= cut then
			found = i
		else
			break
		end
	end
	return found
end

-- фонарик --------------------------------------------------------------------

Rules.FLASH_MAX = 100
Rules.FLASH_DRAIN = 0.8
Rules.BATTERY = 50

function Rules.drain(charge: number, dt: number, on: boolean): number
	if not on then
		return charge
	end
	return math.max(0, charge - Rules.FLASH_DRAIN * dt)
end

function Rules.recharge(charge: number): number
	return math.min(Rules.FLASH_MAX, charge + Rules.BATTERY)
end

-- предметы -------------------------------------------------------------------

Rules.CAP = { battery = 5, plant = 2, lockpick = 3, key = 9, hammer = 1, meat = 3, pole = 1, lens = 1, coldkey = 1, clockkey = 1 }
Rules.PLANT_HEAL = 40
Rules.SPEED = { walk = 15, sneak = 7 }

function Rules.canAdd(inv: { [string]: number }, item: string): boolean
	local cap = Rules.CAP[item]
	return cap ~= nil and (inv[item] or 0) < cap
end

function Rules.add(inv: { [string]: number }, item: string): boolean
	if not Rules.canAdd(inv, item) then
		return false
	end
	inv[item] = (inv[item] or 0) + 1
	return true
end

function Rules.take(inv: { [string]: number }, item: string): boolean
	if (inv[item] or 0) <= 0 then
		return false
	end
	inv[item] -= 1
	if inv[item] == 0 then
		inv[item] = nil
	end
	return true
end

-- что лежит в ящике: r в [0, 1)
function Rules.loot(r: number, door: number): (string, number)
	-- у каждого ящика своя находка, поэтому пустых больше
	if r < 0.25 then
		return "coins", 3 + math.floor(r * 40) + math.floor(door / 10)
	elseif r < 0.33 then
		return "battery", 1
	elseif r < 0.355 then
		return "lockpick", 1
	elseif r < 0.365 then
		return "plant", 1
	elseif r < 0.372 then
		return "hammer", 1
	end
	return "nothing", 0
end

function Rules.lockedChance(door: number): number
	if door < 3 then
		return 0
	end
	return math.min(0.25, 0.1 + door / 500)
end

-- шум и Колосс ---------------------------------------------------------------

function Rules.noise(speed: number, sneaking: boolean): number
	if sneaking or speed <= Rules.SPEED.sneak + 1 then
		return 0
	end
	return 34
end

Rules.COLOSSUS = { wander = 8, hunt = 14, sniffEvery = 11, sniffTime = 2.6, sniffRange = 30, meat = 18 }

-- кодовый замок: четыре цифры 1–6 (сколько предметов на витрине каждого цвета)
Rules.COLORS = { "red", "blue", "green", "yellow" }
Rules.ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII" }

function Rules.code(rand: () -> number)
	local digits, order = {}, { 1, 2, 3, 4 }
	for i = 1, 4 do
		digits[i] = 1 + math.floor(rand() * 6)
	end
	for i = 4, 2, -1 do
		local j = 1 + math.floor(rand() * i)
		order[i], order[j] = order[j], order[i]
	end
	local text = ""
	for _, c in order do
		text ..= digits[c]
	end
	-- третий замок: восемь экспонатов с римскими номерами I–VIII в случайном порядке
	local roman = { 1, 2, 3, 4, 5, 6, 7, 8 }
	for i = 8, 2, -1 do
		local j = 1 + math.floor(rand() * i)
		roman[i], roman[j] = roman[j], roman[i]
	end
	local sequence = {}
	for item, num in roman do
		sequence[num] = item
	end
	-- digits[i] — число для цвета i; order — порядок цветов на замке; text — код;
	-- roman[k] — номер экспоната k; sequence — в каком порядке нажимать экспонаты
	return { digits = digits, order = order, text = text, roman = roman, sequence = sequence }
end

-- достижения: порядок в списке лобби; названия и описания — в Lang (a_id, a_id_t)
Rules.ACHIEVEMENTS = { "darkness", "darkness_hid", "coinkeeper", "coin_paid", "mimic_solved", "door50", "colossus_down", "door100", "finale" }

-- Арена Колосса (зал 050). Координаты — в осях зала: x поперёк, z вглубь (отрицательный)
-- Галереи второго этажа на высоте 0 (пол зала на -10), луч идёт над ними на высоте y.
-- Солнечный луч из круглого окна в дальней стене → четыре зеркала на галереях →
-- зеркальце в люстре → вниз, в круг света на полу
Rules.ARENA = {
	y = 6.6, -- высота луча над входом
	source = { x = -34, z = -103.2, dx = 0, dz = 1 },
	mirrors = { { x = -34, z = -92 }, { x = 34, z = -92 }, { x = 34, z = -40 }, { x = -34, z = -40 } },
	lens = { x = 0, z = -66 },
	tol = math.rad(6), -- допуск направления луча (зеркалу — вдвое меньше)
	turn = 24, -- градусов в секунду, пока держат кнопку
	zone = 7.5, -- радиус круга света на полу
	bounds = { x = 39.3, zFar = -103.3, zNear = -12 },
	stun = 14, -- сколько стоит, ослеплённый светом
	coldOpen = 5, -- сколько секунд открыта дверь холодильной камеры
	drop = 10, -- люстра задевает всё ближе этого
}

local function norm(x: number, z: number): (number, number)
	local l = math.sqrt(x * x + z * z)
	if l < 1e-9 then
		return 0, 0
	end
	return x / l, z / l
end

-- Путь луча. angles[k] — угол нормали зеркала k в радианах (нормаль = (cos a, sin a)).
-- Луч цепляется за следующее зеркало, если смотрит на него с ошибкой меньше допуска.
-- Люстра ловит луч только после всех четырёх зеркал. Возвращает точки пути
-- { x, z, k? }, цепочку зеркал и попал ли луч в люстру
function Rules.beam(angles: { number })
	local A = Rules.ARENA
	local x, z, dx, dz = A.source.x, A.source.z, A.source.dx, A.source.dz
	local path = { { x = x, z = z } }
	local chain, used = {}, {}
	for _ = 1, 6 do
		local best, bestD, bestK = nil, math.huge, nil
		local function try(t, k)
			local vx, vz = t.x - x, t.z - z
			local d = math.sqrt(vx * vx + vz * vz)
			if d < 0.5 then
				return
			end
			local c = (vx * dx + vz * dz) / d
			if c > math.cos(A.tol) and d < bestD then
				best, bestD, bestK = t, d, k
			end
		end
		for k, mr in A.mirrors do
			if not used[k] then
				try(mr, k)
			end
		end
		if #chain == #A.mirrors then
			try(A.lens, 0)
		end
		if not best then
			-- в стену зала
			local t = math.huge
			local B = A.bounds
			if dx > 1e-6 then
				t = math.min(t, (B.x - x) / dx)
			elseif dx < -1e-6 then
				t = math.min(t, (-B.x - x) / dx)
			end
			if dz > 1e-6 then
				t = math.min(t, (B.zNear - z) / dz)
			elseif dz < -1e-6 then
				t = math.min(t, (B.zFar - z) / dz)
			end
			table.insert(path, { x = x + dx * t, z = z + dz * t })
			return path, chain, false
		end
		-- луч точно в центр того, за что зацепился
		dx, dz = norm(best.x - x, best.z - z)
		x, z = best.x, best.z
		table.insert(path, { x = x, z = z, k = bestK })
		if bestK == 0 then
			return path, chain, true
		end
		used[bestK] = true
		table.insert(chain, bestK)
		local a = angles[bestK] or 0
		local nx, nz = math.cos(a), math.sin(a)
		local dot = dx * nx + dz * nz
		if math.abs(dot) < 0.12 then
			-- зеркало стоит ребром к лучу: свет гаснет на раме
			return path, chain, false
		end
		dx, dz = dx - 2 * dot * nx, dz - 2 * dot * nz
	end
	return path, chain, false
end

-- углы нормалей, при которых луч проходит зеркала по порядку 1→2→3→4→люстра
function Rules.beamSolution(): { number }
	local A = Rules.ARENA
	local pts = { A.source }
	for _, mr in A.mirrors do
		table.insert(pts, mr)
	end
	table.insert(pts, A.lens)
	local out = {}
	for k = 2, #pts - 1 do
		local ix, iz = norm(pts[k].x - pts[k - 1].x, pts[k].z - pts[k - 1].z)
		local ox, oz = norm(pts[k + 1].x - pts[k].x, pts[k + 1].z - pts[k].z)
		local nx, nz = norm(ox - ix, oz - iz)
		out[k - 1] = math.atan2(nz, nx)
	end
	return out
end

-- остановленные часы в зале: час 1–12 и минуты кратно 15; стрелки механизма
-- двери переводятся по одному шагу
function Rules.clockTime(rand: () -> number): (number, number)
	return 1 + math.floor(rand() * 12), math.floor(rand() * 4) * 15
end

function Rules.clockStep(h: number, m: number, hand: string): (number, number)
	if hand == "hour" then
		return h % 12 + 1, m
	end
	return h, (m + 15) % 60
end

return Rules
