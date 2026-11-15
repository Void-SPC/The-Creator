--!nonstrict
-- Тексты «The Labyrinth» на английском и русском. Правило: без точек в конце и между
-- частями (короткие подписи); формат string.format

local Lang = {}

Lang.en = {
	Settings = "Settings",
	Language = "Language",
	Shadows = "Shadows",
	On = "On",
	Off = "Off",
	Close = "Close",
	Admin = "Admin",
	Done = "Done",
	Failed = "Failed",
	Leave = "Leave",
	BackToLobby = "Back to the lobby",

	item_flashlight = "Flashlight",
	item_battery = "Battery",
	item_plant = "Healing plant",
	item_whistle = "Whistle",
	item_lockpick = "Lockpick",
	item_key = "Key",
	item_fuse = "Fuse",
	tip_flashlight = "Click to switch the light",
	tip_battery = "Click to put a fresh battery in the flashlight",
	tip_plant = "Click to heal",
	tip_whistle = "Click to whistle: the Watcher freezes, the Blind runs to the sound",
	tip_lockpick = "Hold the button at a locked door",
	tip_key = "Opens the door of the room where it was found",
	tip_fuse = "Put it into a generator",

	p_hide = "Hide / leave",
	p_search = "Search",
	p_pick = "Take",
	p_repair = "Repair",
	p_lockpick = "Pick the lock",
	p_paycoins = "Pay %d coins",
	p_payblood = "Pay with blood (70%% health)",

	ClosetTaken = "Someone is already hiding here",
	BagFull = "You cannot carry more",
	HealthFull = "Your health is full",
	Healed = "The plant healed you",
	FlashFull = "The flashlight is charged",
	Recharged = "Fresh battery in the flashlight",
	FlashEmpty = "The flashlight is dead, find a battery",
	WhistleWait = "Catch your breath first",
	Unlocked = "The key opened the door",
	Locked = "Locked, the key is somewhere in this room",
	LockedPick = "Locked, find the key or pick the lock",
	Picked = "The lockpick opened the door",
	NoLockpick = "You have no lockpick",
	NotEnoughCoins = "Not enough coins (%d needed)",
	PaidCoins = "The Coinkeeper took %d coins",
	PaidBlood = "The Coinkeeper took your blood",
	FuseIn = "Fuse inserted, now repair the generator",
	NeedFuse = "The generator needs a fuse",
	Repairing = "Generator repaired %d%%",
	Empty = "Empty",
	Found_coins = "%d coins",
	Found_battery = "A battery",
	Found_plant = "A healing plant",
	Found_lockpick = "A lockpick",
	Found_whistle = "A whistle",
	Found_fuse = "A fuse",
	KeyTaken = "A key, it fits only the door of this room",
	GodOn = "Immortality on",
	GodOff = "Immortality off",
	LiftFailed = "The elevator is stuck, try again",

	PlayerDied = "%s died at door %s",
	BossHall = "Something blind is listening here",
	Blackout = "The power is gone",
	GateOpen = "The gate is opening",
	Run = "Run",
	GeneratorFixed = "Generator fixed (%d of %d)",
	HumWarn = "Hide",

	Died = "You died",
	cause_hum = "The Hum caught you in the open",
	cause_watcher = "The Watcher reached you",
	cause_blind = "The Blind heard you",
	cause_unknown = "The labyrinth took you",
	DiedAt = "Door %s",
	Spectating = "Watching %s",
	SpectateNext = "Next",
	Results = "The run is over: door %s",
	ToBeContinued = "To be continued",
	Going = "Going down",
	LobbyRules = "THE LABYRINTH\n\nStep into the service elevator to go down\nDoors open as you come close\nWhen the lights flicker, hide in a locker\nDo not look away from the Watcher\nThe Coinkeeper wants coins or blood",
}

Lang.ru = {
	Settings = "Настройки",
	Language = "Язык",
	Shadows = "Тени",
	On = "Вкл",
	Off = "Выкл",
	Close = "Закрыть",
	Admin = "Админ",
	Done = "Готово",
	Failed = "Не вышло",
	Leave = "Выйти",
	BackToLobby = "В лобби",

	item_flashlight = "Фонарик",
	item_battery = "Батарейка",
	item_plant = "Лечебное растение",
	item_whistle = "Свисток",
	item_lockpick = "Отмычка",
	item_key = "Ключ",
	item_fuse = "Деталь",
	tip_flashlight = "Нажми, чтобы включить или выключить свет",
	tip_battery = "Нажми, чтобы вставить новую батарейку в фонарик",
	tip_plant = "Нажми, чтобы вылечиться",
	tip_whistle = "Нажми и свистни: Смотритель замирает, Слепой бежит на звук",
	tip_lockpick = "Удерживай кнопку у запертой двери",
	tip_key = "Открывает дверь комнаты, где ключ найден",
	tip_fuse = "Вставь в генератор",

	p_hide = "Спрятаться / выйти",
	p_search = "Обыскать",
	p_pick = "Взять",
	p_repair = "Чинить",
	p_lockpick = "Вскрыть замок",
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
	Unlocked = "Ключ открыл дверь",
	Locked = "Заперто, ключ где-то в этой комнате",
	LockedPick = "Заперто, найди ключ или вскрой замок",
	Picked = "Отмычка открыла дверь",
	NoLockpick = "Отмычки нет",
	NotEnoughCoins = "Не хватает монет (нужно %d)",
	PaidCoins = "Монетчик забрал %d монет",
	PaidBlood = "Монетчик забрал твою кровь",
	FuseIn = "Деталь вставлена, теперь чини генератор",
	NeedFuse = "Генератору нужна деталь",
	Repairing = "Генератор починен на %d%%",
	Empty = "Пусто",
	Found_coins = "Монеты: %d",
	Found_battery = "Батарейка",
	Found_plant = "Лечебное растение",
	Found_lockpick = "Отмычка",
	Found_whistle = "Свисток",
	Found_fuse = "Деталь",
	KeyTaken = "Ключ, он подходит только к двери этой комнаты",
	GodOn = "Бессмертие включено",
	GodOff = "Бессмертие выключено",
	LiftFailed = "Лифт застрял, попробуй ещё раз",

	PlayerDied = "%s погиб у двери %s",
	BossHall = "Здесь что-то слепое прислушивается",
	Blackout = "Электричества больше нет",
	GateOpen = "Ворота открываются",
	Run = "Беги",
	GeneratorFixed = "Генератор починен (%d из %d)",
	HumWarn = "Прячься",

	Died = "Ты погиб",
	cause_hum = "Гул застал тебя на открытом месте",
	cause_watcher = "Смотритель добрался до тебя",
	cause_blind = "Слепой тебя услышал",
	cause_unknown = "Лабиринт забрал тебя",
	DiedAt = "Дверь %s",
	Spectating = "Наблюдаешь: %s",
	SpectateNext = "Дальше",
	Results = "Забег окончен: дверь %s",
	ToBeContinued = "Продолжение следует",
	Going = "Лифт едет вниз",
	LobbyRules = "ЛАБИРИНТ\n\nЗайди в рабочий лифт, чтобы спуститься\nДвери открываются, когда подходишь\nМигает свет — прячься в шкафчик\nНе отводи взгляд от Смотрителя\nМонетчик просит монеты или кровь",
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
