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

Rules.MIMIC = { speed = 13, wait = 1, damage = 35, from = 20, gap = 8, chance = 0.07 }

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

Rules.CAP = { battery = 5, plant = 2, lockpick = 3, key = 9, hammer = 1, meat = 3 }
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

Rules.COLOSSUS = { wander = 8, hunt = 16, sniffEvery = 11, sniffTime = 2.6, sniffRange = 30, meat = 18 }

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

-- зеркала: сетка клеток (i, j). Зеркало в состоянии 1 меняет местами оси луча,
-- в состоянии 3 — меняет и разворачивает; в 0 и 2 стоит ребром и гасит луч
Rules.MIRRORS = {
	source = { i = -2, j = 0, di = 0, dj = 1 },
	target = { i = 0, j = 5 },
	cells = { { i = -2, j = 3, need = 1 }, { i = 2, j = 3, need = 3 }, { i = 2, j = 1, need = 1 }, { i = 0, j = 1, need = 3 } },
}

-- Путь луча. states[k] — состояние зеркала k. Возвращает точки пути и попал ли в цель
function Rules.trace(states: { number })
	local M = Rules.MIRRORS
	local i, j, di, dj = M.source.i, M.source.j, M.source.di, M.source.dj
	local path = { { i = i, j = j } }
	for _ = 1, 40 do
		i += di
		j += dj
		if i < -4 or i > 4 or j < -1 or j > 6 then
			table.insert(path, { i = i, j = j })
			return path, false
		end
		if i == M.target.i and j == M.target.j then
			table.insert(path, { i = i, j = j })
			return path, true
		end
		for k, c in M.cells do
			if c.i == i and c.j == j then
				table.insert(path, { i = i, j = j })
				local s = states[k]
				if s == 1 then
					di, dj = dj, di
				elseif s == 3 then
					di, dj = -dj, -di
				else
					return path, false
				end
				break
			end
		end
	end
	return path, false
end

return Rules
