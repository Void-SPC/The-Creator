--!nonstrict
-- Правила «The Labyrinth» без Roblox API: глава из 100 дверей, свет и тьма по
-- глубине, предметы, Монетчик, фонарик, шум, Слепой. Проверяются тестами

local Rules = {}

-- глава ---------------------------------------------------------------------

Rules.CHAPTER = 100 -- за дверью 100 зал Слепого, потом погоня и пустота
Rules.BOSS_DOOR = 100

function Rules.isBoss(door: number): boolean
	return door == Rules.BOSS_DOOR
end

-- три цифры на табличке: 001 … 100
function Rules.plate(door: number): string
	return string.format("%03d", door)
end

-- оформление по глубине: отель → выцветший → гниль → глубина
function Rules.zone(door: number): string
	if door <= 30 then
		return "hotel"
	elseif door <= 60 then
		return "faded"
	elseif door <= 85 then
		return "decay"
	end
	return "deep"
end

-- яркость ламп: с 20-й двери свет слабеет, 61–75 — электричества нет совсем
function Rules.light(door: number): number
	if door < 20 then
		return 1
	elseif door <= 60 then
		return 1 - (door - 20) / 40 * 0.6
	elseif door <= 75 then
		return 0
	end
	return 0.3
end

function Rules.blackout(door: number): boolean
	return door > 60 and door <= 75
end

-- окна в пустоту: чем глубже, тем реже, после 45-й их нет
function Rules.windowChance(door: number): number
	if door >= 45 then
		return 0
	end
	return 0.65 * (1 - door / 45)
end

-- здоровье и Монетчик --------------------------------------------------------

Rules.MAX_HEALTH = 100
Rules.TOLL_SHARE = 0.7 -- плата кровью: 70 % текущего здоровья

-- цена растёт с глубиной: в начале мало, у последних дверей около 500
function Rules.coinPrice(door: number): number
	local t = math.clamp(door / Rules.CHAPTER, 0, 1)
	return math.floor(5 + t ^ 1.6 * 495 + 0.5)
end

function Rules.afterBloodToll(health: number): number
	return math.max(1, health - health * Rules.TOLL_SHARE)
end

Rules.COINS_PER_DOOR = 3

-- фонарик --------------------------------------------------------------------

Rules.FLASH_MAX = 100
Rules.FLASH_DRAIN = 0.8 -- в секунду, пока горит
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
Rules.CAP = { battery = 5, plant = 2, lockpick = 3, whistle = 1, key = 9, fuse = 2 }
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

-- что лежит в ящике: r в [0, 1). Лечебное растение — большая редкость
function Rules.loot(r: number, door: number): (string, number)
	if r < 0.4 then
		return "coins", 2 + math.floor(r * 25) + math.floor(door / 10)
	elseif r < 0.52 then
		return "battery", 1
	elseif r < 0.56 then
		return "lockpick", 1
	elseif r < 0.575 then
		return "plant", 1
	end
	return "nothing", 0
end

-- шум и Слепой ---------------------------------------------------------------

function Rules.noise(speed: number, sneaking: boolean): number
	if sneaking or speed <= Rules.SPEED.sneak + 1 then
		return 0
	end
	return 30
end

Rules.NOISE = { repair = 45, gate = 120, whistle = 200, door = 60 }
Rules.BLIND_SPEED = { wander = 9, hunt = 17, chase = 14.5 }
Rules.BLIND_CONFUSED = 6
Rules.GENERATORS = 3
Rules.FUSES = 5
Rules.REPAIR_STEP = 34

function Rules.repair(progress: number): number
	return math.min(100, progress + Rules.REPAIR_STEP)
end

-- Смотритель -----------------------------------------------------------------

Rules.WATCHER_SPEED = 28
Rules.WATCHER_DAMAGE = 45
Rules.WATCHER_SEEN_TIME = 0.35
Rules.WHISTLE_FREEZE = 6

function Rules.watcherMoves(lastSeen: number?, now: number, frozenUntil: number?): boolean
	if frozenUntil and now < frozenUntil then
		return false
	end
	return not lastSeen or now - lastSeen > Rules.WATCHER_SEEN_TIME
end

-- шансы у двери (r в [0, 1)) -------------------------------------------------

function Rules.humChance(door: number): number
	if door < 10 then
		return 0
	end
	return math.min(0.24, 0.08 + door / 500)
end

function Rules.watcherChance(door: number): number
	if door < 15 then
		return 0
	end
	return math.min(0.22, 0.07 + door / 500)
end

function Rules.coinChance(door: number): number
	if door < 6 then
		return 0
	end
	return 0.08
end

function Rules.lockedChance(door: number): number
	if door < 3 then
		return 0
	end
	return math.min(0.3, 0.14 + door / 500)
end

Rules.HUM_GAP = 5

return Rules
