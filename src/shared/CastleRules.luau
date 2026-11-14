--!nonstrict
-- Правила «The Castle» без Roblox API: роли, предметы, голод и жажда, инвентарь, казино

local Rules = {}

-- Роли и сколько их может быть одновременно
Rules.ROLES = {
	king = { max = 1, weapon = true, rank = 7 },
	queen = { max = 1, weapon = false, rank = 6 },
	commander = { max = 1, weapon = true, rank = 5 },
	guard = { max = 6, weapon = true, rank = 4 },
	cook = { max = 3, weapon = false, rank = 2 },
	servant = { max = 6, weapon = false, rank = 2 },
	librarian = { max = 2, weapon = false, rank = 2 },
	peasant = { max = 99, weapon = false, rank = 1 },
}
Rules.ROLE_ORDER = { "king", "queen", "commander", "guard", "cook", "servant", "librarian", "peasant" }
-- роли, которые нельзя взять самому: короля сажает трон, королеву и военачальника назначает король
Rules.APPOINTED = { king = true, queen = true, commander = true }

-- Предметы. food/drink — сколько восстанавливают; roles — кому можно держать
Rules.ITEMS = {
	bread = { kind = "food", food = 25 },
	apple = { kind = "food", food = 15, drink = 5 },
	meat = { kind = "food", food = 40 },
	soup = { kind = "food", food = 35, drink = 20 },
	cake = { kind = "food", food = 30 },
	water = { kind = "drink", drink = 40 },
	juice = { kind = "drink", drink = 30, food = 5 },
	spoon = { kind = "tool" },
	broom = { kind = "tool" },
	book = { kind = "tool" },
	scepter = { kind = "tool", roles = { king = true } },
	sword = { kind = "weapon", damage = 20, cooldown = 0.8, roles = { king = true, commander = true, guard = true } },
	cuffs = { kind = "tool", roles = { king = true, commander = true, guard = true } },
	backpack = { kind = "backpack" },
}

Rules.MAX = 100
Rules.HUNGER_PER_SEC = 100 / 900 -- полная сытость на 15 минут
Rules.THIRST_PER_SEC = 100 / 600 -- полная жажда на 10 минут
Rules.STARVE_DAMAGE = 2 -- урон в секунду, когда еда или вода на нуле

function Rules.capacity(hasBackpack: boolean): number
	return if hasBackpack then 5 else 3
end

function Rules.canHold(item: string, role: string?): boolean
	local def = Rules.ITEMS[item]
	if not def then
		return false
	end
	return def.roles == nil or (role ~= nil and def.roles[role] == true)
end

-- Добавить предмет в инвентарь (список имён). Рюкзак сам слот не занимает
function Rules.addItem(inv: { string }, item: string, hasBackpack: boolean): (boolean, string?)
	if not Rules.ITEMS[item] then
		return false, "unknown"
	end
	if item == "backpack" then
		return not hasBackpack, if hasBackpack then "have" else nil
	end
	if #inv >= Rules.capacity(hasBackpack) then
		return false, "full"
	end
	table.insert(inv, item)
	return true, nil
end

function Rules.removeItem(inv: { string }, item: string): boolean
	local i = table.find(inv, item)
	if not i then
		return false
	end
	table.remove(inv, i)
	return true
end

-- Голод и жажда за dt секунд. Король не голодает
function Rules.tick(stats, dt: number, isKing: boolean)
	if isKing then
		stats.food, stats.drink = Rules.MAX, Rules.MAX
		return 0
	end
	stats.food = math.max(0, stats.food - Rules.HUNGER_PER_SEC * dt)
	stats.drink = math.max(0, stats.drink - Rules.THIRST_PER_SEC * dt)
	if stats.food <= 0 or stats.drink <= 0 then
		return Rules.STARVE_DAMAGE * dt
	end
	return 0
end

-- Съесть или выпить. Сытый не может есть, кроме короля
function Rules.consume(stats, item: string, isKing: boolean): (boolean, string?)
	local def = Rules.ITEMS[item]
	if not def or (def.kind ~= "food" and def.kind ~= "drink") then
		return false, "not_food"
	end
	local food, drink = def.food or 0, def.drink or 0
	if not isKing then
		local helps = (food > 0 and stats.food < Rules.MAX) or (drink > 0 and stats.drink < Rules.MAX)
		if not helps then
			return false, "full"
		end
	end
	stats.food = math.min(Rules.MAX, stats.food + food)
	stats.drink = math.min(Rules.MAX, stats.drink + drink)
	return true, nil
end

-- Можно ли взять роль (без учёта назначаемых)
function Rules.canTake(role: string, counts: { [string]: number }): boolean
	local def = Rules.ROLES[role]
	if not def or Rules.APPOINTED[role] then
		return false
	end
	return (counts[role] or 0) < def.max
end

-- Казино: игровой автомат. rand(a, b) — целое число
Rules.SLOT_SYMBOLS = { "crown", "sword", "apple", "bell", "skull" }
function Rules.slots(bet: number, rand: (number, number) -> number)
	local s = {}
	for i = 1, 3 do
		s[i] = Rules.SLOT_SYMBOLS[rand(1, #Rules.SLOT_SYMBOLS)]
	end
	local win = 0
	if s[1] == s[2] and s[2] == s[3] then
		win = if s[1] == "crown" then bet * 10 elseif s[1] == "skull" then 0 else bet * 5
	elseif s[1] == s[2] or s[2] == s[3] or s[1] == s[3] then
		win = math.floor(bet * 1.5)
	end
	return s, win
end

-- Орёл или решка: чуть меньше половины шансов удвоить ставку
function Rules.coinFlip(bet: number, rand: (number, number) -> number)
	local roll = rand(1, 100)
	return roll <= 48, if roll <= 48 then bet * 2 else 0
end

Rules.BETS = { 10, 50, 100 }
Rules.START_GOLD = 100

-- Магазин: украшения навсегда, цена в золоте
Rules.SHOP = {
	{ id = "flower_crown", price = 150 },
	{ id = "cape_red", price = 250 },
	{ id = "cape_blue", price = 250 },
	{ id = "halo", price = 400 },
	{ id = "glasses", price = 120 },
	{ id = "feather_hat", price = 200 },
	{ id = "backpack", price = 300 },
	{ id = "wings", price = 800 },
}
Rules.SHOP_BY_ID = {}
for _, s in Rules.SHOP do
	Rules.SHOP_BY_ID[s.id] = s
end

-- Король может призвать до 6 стражников-NPC, по 2 за раз, раз в 120 секунд
Rules.MINION_MAX = 6
Rules.MINION_BATCH = 2
Rules.MINION_COOLDOWN = 120

function Rules.canSummon(alive: number, lastAt: number?, now: number): (boolean, string?)
	if alive >= Rules.MINION_MAX then
		return false, "max"
	end
	if lastAt and now - lastAt < Rules.MINION_COOLDOWN then
		return false, "cooldown"
	end
	return true, nil
end

return Rules
