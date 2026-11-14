--!nonstrict
-- Тексты «The Labyrinth» на английском и русском. Правило: без точек в конце и между
-- частями (короткие подписи); формат string.format

local Lang = {}

Lang.en = {
	Title = "The Labyrinth",
	Subtitle = "An endless hotel of doors",
	Play = "Play",
	Settings = "Settings",
	HowToPlay = "How to play",
	Best = "Best door: %d",
	Language = "Language",
	Back = "Back",
	Next = "Next",
	Close = "Close",
	Volume = "Volume",
	Sensitivity = "Camera sensitivity",
	Shadows = "Shadows",
	On = "On",
	Off = "Off",

	Door = "Door %d",
	Sector = "Sector %d",
	Coins = "%d coins",
	Flash = "Light",
	Sneak = "Sneak",
	Sneaking = "Sneaking",
	Health = "Health",
	item_battery = "Battery",
	item_plant = "Healing plant",
	item_lockpick = "Lockpick",
	item_whistle = "Whistle",
	item_key = "Key",
	item_fuse = "Fuse",

	p_door = "Open",
	p_hide = "Hide / leave",
	p_search = "Search",
	p_pick = "Take",
	p_repair = "Repair",
	p_ride = "Next sector",
	p_shop = "Shop",
	p_paycoins = "Pay %d coins",
	p_payblood = "Pay with blood (70%% health)",

	ClosetTaken = "Someone is already hiding here",
	BagFull = "You cannot carry more",
	HealthFull = "Your health is full",
	Healed = "The plant healed you",
	FlashFull = "The flashlight is charged",
	Recharged = "New battery in the flashlight",
	FlashEmpty = "The flashlight is dead, find a battery",
	WhistleWait = "Catch your breath first",
	TollBlocks = "The Toll Keeper blocks the door: %d coins or blood",
	RideFirst = "Ride the elevator first",
	Unlocked = "The key opened the door",
	Picked = "The lockpick opened the door",
	Locked = "Locked, find the key in this room or use a lockpick",
	NotEnoughCoins = "Not enough coins (%d needed)",
	PaidCoins = "You paid %d coins",
	PaidBlood = "The Toll Keeper took your blood",
	FuseIn = "Fuse inserted, now repair the generator",
	NeedFuse = "The generator needs a fuse",
	Repairing = "Generator repaired %d%%",
	Empty = "Nothing here",
	Found_coins = "Found %d coins",
	Found_battery = "Found a battery",
	Found_plant = "Found a healing plant",
	Found_lockpick = "Found a lockpick",
	Found_whistle = "Found a whistle",
	Found_fuse = "Found a fuse",
	KeyTaken = "Key taken, it only fits the door of this room",
	GodOn = "Immortality on",
	GodOff = "Immortality off",

	PlayerDied = "%s died at door %d",
	BossHall = "Generator hall: something blind listens in the dark",
	SectorEnd = "End of sector %d",
	GateOpen = "The gate is opening",
	GeneratorFixed = "Generator fixed (%d of %d)",
	ElevatorLeaving = "The elevator leaves in %d seconds, get into the cabin",
	SectorWelcome = "Sector %d",
	HumWarn = "The lights flicker, hide in a closet",

	Died = "You died",
	cause_hum = "The Hum caught you in the open",
	cause_watcher = "The Watcher reached you",
	cause_blind = "The Blind heard you",
	cause_unknown = "The labyrinth took you",
	DiedAt = "Door %d",
	Spectating = "Watching: %s",
	SpectateNext = "Next player",
	Results = "The run is over: door %d",
	NewRun = "A new run starts soon",

	Shop = "Elevator shop",
	Buy = "Buy",
	Price = "%d coins",
	Admin = "Admin",
	Done = "Done",
	Failed = "Failed",

	H1t = "Doors",
	H1 = "Open door after door, each one has a number, and the highest door you reach is your record",
	H2t = "The Hum",
	H2 = "When the lights flicker and a rumble grows, hide in a closet at once, the Hum kills everyone in the open",
	H3t = "The Watcher",
	H3 = "A tall pale-masked figure moves fast while nobody looks at it, keep your eyes on it and back away",
	H4t = "Keys and the Toll Keeper",
	H4 = "A locked door opens with the key from the same room or a lockpick, the Toll Keeper wants coins or 70% of your health",
	H5t = "Flashlight and items",
	H5 = "The flashlight runs down, batteries recharge it, healing plants restore health, the whistle freezes the Watcher",
	H6t = "Elevator and the Blind",
	H6 = "At the end of a sector a service elevator goes one sector deeper, from sector 2 the Blind guards it, sneak, collect fuses, repair three generators and open the gate",
}

Lang.ru = {
	Title = "Лабиринт",
	Subtitle = "Бесконечный отель дверей",
	Play = "Играть",
	Settings = "Настройки",
	HowToPlay = "Как играть",
	Best = "Рекорд: дверь %d",
	Language = "Язык",
	Back = "Назад",
	Next = "Дальше",
	Close = "Закрыть",
	Volume = "Громкость",
	Sensitivity = "Чувствительность камеры",
	Shadows = "Тени",
	On = "Вкл",
	Off = "Выкл",

	Door = "Дверь %d",
	Sector = "Сектор %d",
	Coins = "Монет: %d",
	Flash = "Свет",
	Sneak = "Тихо",
	Sneaking = "Крадёшься",
	Health = "Здоровье",
	item_battery = "Батарейка",
	item_plant = "Лечебное растение",
	item_lockpick = "Отмычка",
	item_whistle = "Свисток",
	item_key = "Ключ",
	item_fuse = "Деталь",

	p_door = "Открыть",
	p_hide = "Спрятаться / выйти",
	p_search = "Обыскать",
	p_pick = "Взять",
	p_repair = "Чинить",
	p_ride = "Следующий сектор",
	p_shop = "Лавка",
	p_paycoins = "Заплатить %d монет",
	p_payblood = "Заплатить кровью (70%% здоровья)",

	ClosetTaken = "Здесь уже кто-то прячется",
	BagFull = "Больше не унести",
	HealthFull = "Здоровье и так полное",
	Healed = "Растение вылечило тебя",
	FlashFull = "Фонарик заряжен",
	Recharged = "В фонарике новая батарейка",
	FlashEmpty = "Фонарик сел, найди батарейку",
	WhistleWait = "Сначала отдышись",
	TollBlocks = "Сборщик платы загородил дверь: %d монет или кровь",
	RideFirst = "Сначала поезжай на лифте",
	Unlocked = "Ключ открыл дверь",
	Picked = "Отмычка открыла дверь",
	Locked = "Заперто, найди ключ в этой комнате или используй отмычку",
	NotEnoughCoins = "Не хватает монет (нужно %d)",
	PaidCoins = "Ты заплатил %d монет",
	PaidBlood = "Сборщик забрал твою кровь",
	FuseIn = "Деталь вставлена, теперь чини генератор",
	NeedFuse = "Генератору нужна деталь",
	Repairing = "Генератор починен на %d%%",
	Empty = "Пусто",
	Found_coins = "Найдено монет: %d",
	Found_battery = "Найдена батарейка",
	Found_plant = "Найдено лечебное растение",
	Found_lockpick = "Найдена отмычка",
	Found_whistle = "Найден свисток",
	Found_fuse = "Найдена деталь",
	KeyTaken = "Ключ взят, он подходит только к двери этой комнаты",
	GodOn = "Бессмертие включено",
	GodOff = "Бессмертие выключено",

	PlayerDied = "%s погиб у двери %d",
	BossHall = "Зал генераторов: в темноте слушает что-то слепое",
	SectorEnd = "Конец сектора %d",
	GateOpen = "Ворота открываются",
	GeneratorFixed = "Генератор починен (%d из %d)",
	ElevatorLeaving = "Лифт уходит через %d секунд, заходи в кабину",
	SectorWelcome = "Сектор %d",
	HumWarn = "Свет мигает, прячься в шкаф",

	Died = "Ты погиб",
	cause_hum = "Гул застал тебя на открытом месте",
	cause_watcher = "Смотритель добрался до тебя",
	cause_blind = "Слепой тебя услышал",
	cause_unknown = "Лабиринт забрал тебя",
	DiedAt = "Дверь %d",
	Spectating = "Наблюдаешь: %s",
	SpectateNext = "Следующий игрок",
	Results = "Забег окончен: дверь %d",
	NewRun = "Скоро новый забег",

	Shop = "Лавка в лифте",
	Buy = "Купить",
	Price = "%d монет",
	Admin = "Админ",
	Done = "Готово",
	Failed = "Не вышло",

	H1t = "Двери",
	H1 = "Открывай дверь за дверью, у каждой свой номер, а самая дальняя дверь — твой рекорд",
	H2t = "Гул",
	H2 = "Когда мигает свет и нарастает гул, сразу прячься в шкаф: Гул убивает всех на открытом месте",
	H3t = "Смотритель",
	H3 = "Высокая фигура в бледной маске быстро идёт, пока на неё никто не смотрит: не своди с неё глаз и отходи",
	H4t = "Ключи и Сборщик платы",
	H4 = "Запертую дверь открывает ключ из этой же комнаты или отмычка, а Сборщик платы требует монеты или 70% здоровья",
	H5t = "Фонарик и предметы",
	H5 = "Фонарик садится, батарейки его заряжают, лечебные растения лечат, свисток замораживает Смотрителя",
	H6t = "Лифт и Слепой",
	H6 = "В конце сектора рабочий лифт едет на один сектор глубже, а с сектора 2 его стережёт Слепой: крадись, собирай детали, чини три генератора и открой ворота",
}

function Lang.t(lang: string, key: string, ...): string
	local pack = Lang[lang] or Lang.en
	local s = pack[key] or Lang.en[key] or key
	if select("#", ...) > 0 then
		local ok, res = pcall(string.format, s, ...)
		return if ok then res else s
	end
	if string.find(s, "%%%%") then
		return (string.gsub(s, "%%%%", "%%"))
	end
	return s
end

-- Проверка: оба языка с одинаковыми ключами, без точек в конце и между частями
function Lang.lint(): { string }
	local problems = {}
	for _, lang in { "en", "ru" } do
		local other = if lang == "en" then Lang.ru else Lang.en
		for key, text in Lang[lang] do
			if other[key] == nil then
				table.insert(problems, lang .. ": no pair for " .. key)
			end
			local masked = string.gsub(text, "%d+%.%d+", "0")
			if string.find(masked, "%.$") or string.find(masked, "%.%s+%S") then
				table.insert(problems, lang .. "." .. key .. ": period")
			end
		end
	end
	return problems
end

return Lang
