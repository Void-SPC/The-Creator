--!nonstrict
-- Правила режима «Маньяк» без Roblox API: состояния выживших, удары, генераторы,
-- способности маньяка и условия победы. Проверяются тестами

local Rules = {}

Rules.MIN_PLAYERS = 2
Rules.MAX_PLAYERS = 12
Rules.LOBBY_COUNTDOWN = 20
Rules.ROUND_TIME = 480
Rules.MANIAC_DELAY = 12 -- маньяк выходит через 12 секунд после начала
Rules.RESULTS_TIME = 12
Rules.BLEED_OUT = 60 -- лежачий без помощи погибает через минуту
Rules.REPAIR_STEP = 25 -- один ремонт (удержание кнопки) даёт 25 %

Rules.SPEED = { survivor = 16, injured = 15, downed = 3, maniac = 15.5, dash = 30, scared = 9 }

-- состояния выжившего
Rules.STATES = { "healthy", "injured", "downed", "dead", "escaped" }

-- Удар маньяка: здоров → ранен → лежит. Лежачего можно только казнить
function Rules.hit(state: string): string
	if state == "healthy" then
		return "injured"
	elseif state == "injured" then
		return "downed"
	end
	return state
end

-- Лежачего поднимает другой выживший: он снова ранен
function Rules.revive(state: string): string
	if state == "downed" then
		return "injured"
	end
	return state
end

function Rules.isAlive(state: string): boolean
	return state == "healthy" or state == "injured" or state == "downed"
end

-- Сколько генераторов чинить: на одного больше, чем выживших, от 3 до 6
function Rules.generatorsFor(survivors: number): number
	return math.clamp(survivors + 1, 3, 6)
end

-- Сколько процентов даёт ремонт (несколько выживших у одного генератора чинят быстрее)
function Rules.repair(progress: number, helpers: number): number
	local bonus = math.max(0, helpers - 1) * 0.5
	return math.min(100, progress + Rules.REPAIR_STEP * (1 + bonus))
end

-- Способности маньяка: перезарядка и радиус
Rules.ABILITIES = {
	attack = { cooldown = 1.6, range = 7 },
	scream = { cooldown = 25, range = 40, duration = 3 },
	blind = { cooldown = 30, range = 28, duration = 3.5 },
	dash = { cooldown = 12, duration = 1.6 },
	sense = { cooldown = 40, duration = 5 },
}
Rules.ABILITY_ORDER = { "attack", "scream", "blind", "dash", "sense" }

function Rules.ready(ability: string, lastAt: number?, now: number): (boolean, number)
	local a = Rules.ABILITIES[ability]
	if not a then
		return false, 0
	end
	if not lastAt then
		return true, 0
	end
	local left = a.cooldown - (now - lastAt)
	return left <= 0, math.max(0, left)
end

-- Кто будет маньяком: случайный из списка (rand(1, n) — целое)
function Rules.pickManiac(list: { any }, rand: (number, number) -> number)
	if #list == 0 then
		return nil
	end
	return list[rand(1, #list)]
end

-- Итог раунда. states: { [id] = state } выживших; timeUp — время вышло
function Rules.winner(states: { [any]: string }, timeUp: boolean): string?
	local alive, escaped, total = 0, 0, 0
	for _, s in states do
		total += 1
		if s == "escaped" then
			escaped += 1
		elseif Rules.isAlive(s) then
			alive += 1
		end
	end
	if total == 0 then
		return "maniac"
	end
	if alive == 0 then
		return if escaped > 0 then "survivors" else "maniac"
	end
	if timeUp then
		return if escaped > 0 then "survivors" else "maniac"
	end
	return nil
end

return Rules
