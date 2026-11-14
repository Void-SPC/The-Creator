--!nonstrict
-- Правила «The Labyrinth» без Roblox API: сектора, двери, предметы, цены,
-- фонарик, шум, сборщик платы, шансы существ. Проверяются тестами

local Rules = {}

-- двери и сектора ------------------------------------------------------------

Rules.SECTOR_LEN = 25 -- дверей в секторе; за последней — лифт (с сектора 2 — зал Слепого)

function Rules.sectorOf(door: number): number
	return math.floor((math.max(1, door) - 1) / Rules.SECTOR_LEN) + 1
end

-- дверь, за которой конец сектора
function Rules.isSectorEnd(door: number): boolean
	return door > 0 and door % Rules.SECTOR_LEN == 0
end

-- в конце сектора 2 и дальше — зал Слепого перед лифтом
function Rules.hasBoss(sector: number): boolean
	return sector >= 2
end

-- лифт едет только вертикально и только на один сектор вперёд
function Rules.canRide(fromSector: number, toSector: number): boolean
	return toSector == fromSector + 1
end

-- здоровье и сборщик платы -------------------------------------------------

Rules.MAX_HEALTH = 100
Rules.TOLL_SHARE = 0.7 -- плата кровью: 70 % текущего здоровья

function Rules.tollPrice(door: number): number
	return 5 + math.floor(door / 10)
end

-- сколько здоровья останется после платы кровью (никогда не убивает)
function Rules.afterBloodToll(health: number): number
	return math.max(1, health - health * Rules.TOLL_SHARE)
end

-- фонарик --------------------------------------------------------------------

Rules.FLASH_MAX = 100
Rules.FLASH_DRAIN = 1 -- в секунду, пока включён
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

Rules.ITEMS = { "battery", "plant", "lockpick", "whistle", "key", "fuse" }
-- сколько штук можно нести
Rules.CAP = { battery = 3, plant = 3, lockpick = 3, whistle = 1, key = 9, fuse = 2 }
Rules.PLANT_HEAL = 35
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

-- лавка в лифте
Rules.PRICES = { battery = 8, plant = 12, lockpick = 15, whistle = 20 }
Rules.SHOP = { "battery", "plant", "lockpick", "whistle" }

function Rules.buy(inv, coins: number, item: string): (boolean, number, string?)
	local price = Rules.PRICES[item]
	if not price then
		return false, coins, "unknown"
	end
	if coins < price then
		return false, coins, "coins"
	end
	if not Rules.canAdd(inv, item) then
		return false, coins, "full"
	end
	Rules.add(inv, item)
	return true, coins - price, nil
end

-- находки в ящиках: r в [0, 1)
function Rules.loot(r: number, door: number): (string, number)
	if r < 0.45 then
		return "coins", 1 + math.floor(r * 10) + math.floor(door / 25)
	elseif r < 0.62 then
		return "battery", 1
	elseif r < 0.74 then
		return "plant", 1
	elseif r < 0.82 then
		return "lockpick", 1
	end
	return "nothing", 0
end

-- шум и Слепой ---------------------------------------------------------------

-- радиус, в котором Слепой слышит игрока
function Rules.noise(speed: number, sneaking: boolean): number
	if sneaking or speed < 1 then
		return 0
	end
	if speed <= Rules.SPEED.sneak + 1 then
		return 0
	end
	return 30
end

Rules.NOISE = { repair = 45, gate = 120, whistle = 200, door = 60 }
Rules.BLIND_SPEED = { wander = 9, hunt = 17 }
Rules.BLIND_CONFUSED = 6 -- секунд стоит на месте после свистка
Rules.GENERATORS = 3
Rules.FUSES = 5 -- деталей разбросано по залу (нужно 3)
Rules.REPAIR_STEP = 34 -- один ремонт (удержание) даёт 34 %

function Rules.repair(progress: number): number
	return math.min(100, progress + Rules.REPAIR_STEP)
end

-- Смотритель -----------------------------------------------------------------

Rules.WATCHER_SPEED = 28
Rules.WATCHER_DAMAGE = 45
Rules.WATCHER_SEEN_TIME = 0.35 -- сколько секунд действует отметка «на него смотрят»
Rules.WHISTLE_FREEZE = 6

function Rules.watcherMoves(lastSeen: number?, now: number, frozenUntil: number?): boolean
	if frozenUntil and now < frozenUntil then
		return false
	end
	return not lastSeen or now - lastSeen > Rules.WATCHER_SEEN_TIME
end

-- шансы событий у двери (r в [0, 1)) -----------------------------------------

function Rules.humChance(door: number): number
	if door < 8 then
		return 0
	end
	return math.min(0.22, 0.08 + door / 600)
end

function Rules.watcherChance(door: number): number
	if door < 12 then
		return 0
	end
	return math.min(0.25, 0.08 + door / 500)
end

function Rules.tollChance(door: number): number
	if door < 6 then
		return 0
	end
	return 0.09
end

function Rules.lockedChance(door: number): number
	if door < 3 then
		return 0
	end
	return math.min(0.35, 0.15 + door / 400)
end

function Rules.darkChance(door: number): number
	if door < 5 then
		return 0
	end
	return math.min(0.45, 0.1 + door / 300)
end

-- Гул не приходит два раза подряд слишком быстро
Rules.HUM_GAP = 5

return Rules
