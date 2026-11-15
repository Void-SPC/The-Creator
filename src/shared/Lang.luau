--!nonstrict
-- Тексты «The Museum» на английском и русском. Правило: без точек в конце и между
-- частями (короткие подписи); формат string.format

local Lang = {}

Lang.en = {
	Settings = "Settings",
	Shadows = "Shadows",
	Steps = "Footsteps",
	Ambience = "Ambience",
	On = "On",
	Off = "Off",
	Admin = "Admin",
	Done = "Done",
	Failed = "Failed",
	Leave = "Leave",
	BackToLobby = "Back to the street",
	Journal = "Journal",
	JournalEmpty = "The pages are empty for now",
	JournalNew = "A new page in the journal",
	MuseumSign = "MUSEUM",
	EndlessSoon = "ENDLESS MODE\nSOON",

	item_flashlight = "Flashlight",
	item_battery = "Battery",
	item_plant = "Healing plant",
	item_lockpick = "Lockpick",
	item_key = "Key",
	item_hammer = "Hammer",
	item_meat = "Meat",

	p_hide = "Hide / leave",
	p_search = "Search",
	p_pick = "Take",
	p_lockpick = "Pick the lock",
	p_talk = "Talk",
	p_code = "Enter the code",
	p_turn = "Turn",
	p_bait = "Put the meat",
	p_call = "Call",
	p_lever = "Pull",
	p_take = "Take",
	p_place = "Put",
	p_open = "Open",

	BagFull = "You cannot carry more",
	Locked = "Locked",
	GodOn = "Immortality on",
	GodOff = "Immortality off",

	DoorShut = "The door seems to have shut, I need to find a way out of here",
	LiftLocked = "The elevator is locked, please use the maintenance stairs",
	CoinLine = "Give me the gold, or pay another way",
	CoinPrice = "%d coins",
	PayGold = "Pay with gold",
	PaySelf = "Pay with yourself",
	NoGold = "Not enough gold",
	Code = "Code",
	Clear = "Clear",

	Died = "You died",
	DiedAt = "Door %s",
	Spectating = "Watching %s",
	SpectateNext = "Next",
	Results = "The run is over: door %s",
	ToBeContinued = "To be continued",

	j_darkness = "The Darkness",
	j_darkness_t = "The lights flicker before it comes, and it flies through every open hall to the last door, opens it, and then comes back even faster, and the lamps burst wherever it has been, so hide in a locker and stay there until it returns",
	j_mimic = "YOUrself",
	j_mimic_t = "A marble statue of you that walks the very path you walked, and it does not stop when you stop, though when it has caught up it waits a second before following again, and it crumbles when every figurine stands on the pedestal of its colour, or under a hammer",
	j_coinkeeper = "The Coinkeeper",
	j_coinkeeper_t = "A golden coin with a moustache that blocks the door and wants gold, and if you pay with yourself it takes most of your health, or all of it when you have almost none left, and it is afraid of the Darkness and runs into its hole when the lights flicker",
	j_colossus = "The Colossus",
	j_colossus_t = "A huge blind statue that hears footsteps and sometimes stops to sniff the air, and then it smells whoever stands near, so move crouching, and it walks to meat, and the light gathered by the mirrors melts stone",
	j_void = "The Breach",
	j_void_t = "A corridor that is far too long, with no ceiling and with holes in the walls, and behind the holes there is nothing, and that nothing pulls you in, and whoever walks slowly past a hole does not walk past it",
}

Lang.ru = {
	Settings = "Настройки",
	Shadows = "Тени",
	Steps = "Звук шагов",
	Ambience = "Звуки музея",
	On = "Вкл",
	Off = "Выкл",
	Admin = "Админ",
	Done = "Готово",
	Failed = "Не вышло",
	Leave = "Выйти",
	BackToLobby = "На улицу",
	Journal = "Журнал",
	JournalEmpty = "Страницы пока пусты",
	JournalNew = "В журнале новая страница",
	MuseumSign = "МУЗЕЙ",
	EndlessSoon = "БЕСКОНЕЧНЫЙ РЕЖИМ\nСКОРО",

	item_flashlight = "Фонарик",
	item_battery = "Батарейка",
	item_plant = "Лечебное растение",
	item_lockpick = "Отмычка",
	item_key = "Ключ",
	item_hammer = "Молоток",
	item_meat = "Мясо",

	p_hide = "Спрятаться / выйти",
	p_search = "Обыскать",
	p_pick = "Взять",
	p_lockpick = "Вскрыть замок",
	p_talk = "Говорить",
	p_code = "Ввести код",
	p_turn = "Повернуть",
	p_bait = "Положить мясо",
	p_call = "Вызвать",
	p_lever = "Дёрнуть",
	p_take = "Взять",
	p_place = "Поставить",
	p_open = "Открыть",

	BagFull = "Больше не унести",
	Locked = "Заперто",
	GodOn = "Бессмертие включено",
	GodOff = "Бессмертие выключено",

	DoorShut = "Кажется, дверь закрылась, надо найти способ выбраться отсюда",
	LiftLocked = "Лифт заперт, пожалуйста, используйте лестницу для техобслуживания",
	CoinLine = "Отдай мне золото или расплатись другим способом",
	CoinPrice = "Монет: %d",
	PayGold = "Расплатиться золотом",
	PaySelf = "Расплатиться собой",
	NoGold = "Золота не хватает",
	Code = "Код",
	Clear = "Стереть",

	Died = "Ты погиб",
	DiedAt = "Дверь %s",
	Spectating = "Наблюдаешь: %s",
	SpectateNext = "Дальше",
	Results = "Забег окончен: дверь %s",
	ToBeContinued = "Продолжение следует",

	j_darkness = "Тьма",
	j_darkness_t = "Перед ней мигает свет, и она летит через все открытые залы до последней двери, открывает её, а потом возвращается обратно ещё быстрее, и там, где она пролетела, лопаются лампы, так что прячься в шкафчик и сиди, пока она не вернётся",
	j_mimic = "тебЯ",
	j_mimic_t = "Мраморная статуя тебя самого, которая идёт тем же путём, каким шёл ты, и не останавливается, когда останавливаешься ты, но, догнав, ждёт секунду и снова идёт следом, а рассыпается она, когда все фигурки стоят на постаментах своего цвета, или под молотком",
	j_coinkeeper = "Монетчик",
	j_coinkeeper_t = "Золотая монета с усами, которая загораживает дверь и требует золото, а если расплатиться собой, забирает почти всё здоровье, или всё, когда его почти не осталось, и ещё он боится Тьмы и убегает в свою норку, когда мигает свет",
	j_colossus = "Колосс",
	j_colossus_t = "Огромная слепая статуя, которая слышит шаги и иногда останавливается принюхаться, и тогда чует того, кто стоит рядом, так что двигайся пригнувшись, а ещё он идёт на мясо, и свет, собранный зеркалами, плавит камень",
	j_void = "Пролом",
	j_void_t = "Слишком длинный коридор без потолка и с дырами в стенах, за которыми ничего нет, и это ничто тянет к себе, и кто идёт мимо дыры медленно, тот мимо не проходит",
}

function Lang.t(lang: string, key: string, ...): string
	local pack = Lang[lang] or Lang.en
	local s = pack[key] or Lang.en[key] or key
	if select("#", ...) > 0 then
		local ok, res = pcall(string.format, s, ...)
		return if ok then res else s
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
