--!nonstrict
-- Общий набор событий, условий и действий карты
-- Его используют блочный редактор, текстовый режим, проверка и исполнитель на сервере
-- Типы аргументов:
--   door, light, zone, closet, waypoint, model, any — ссылка на объект карты
--   clip — имя клипа модели из первого аргумента-модели
--   number, bool, string — значения; text — авторский текст, проходит фильтрацию Roblox

local Commands = {}

local function arg(name: string, typ: string, title: string, extra: { [string]: any }?)
	local a = { name = name, type = typ, title = title }
	if extra then
		for k, v in extra do
			a[k] = v
		end
	end
	return a
end

Commands.events = {
	MapStarted = { title = "Когда карта запущена", args = {} },
	DoorOpened = { title = "Когда открыта дверь", args = { arg("door", "door", "Дверь") } },
	DoorClosed = { title = "Когда закрыта дверь", args = { arg("door", "door", "Дверь") } },
	ZoneEntered = { title = "Когда игрок вошёл в зону", args = { arg("zone", "zone", "Зона") } },
	ZoneLeft = { title = "Когда игрок вышел из зоны", args = { arg("zone", "zone", "Зона") } },
	Interacted = { title = "Когда игрок взаимодействует", args = { arg("target", "any", "Объект") } },
	ClipFinished = {
		title = "Когда клип завершён",
		args = { arg("model", "model", "Модель"), arg("clip", "clip", "Клип") },
	},
	MarkerReached = {
		title = "Когда клип дошёл до метки",
		args = { arg("model", "model", "Модель"), arg("clip", "clip", "Клип"), arg("marker", "string", "Метка") },
	},
	ClosetEntered = { title = "Когда игрок спрятался в шкаф", args = { arg("closet", "closet", "Шкаф") } },
	ClosetExited = { title = "Когда игрок вышел из шкафа", args = { arg("closet", "closet", "Шкаф") } },
	Timer = {
		title = "Каждые N секунд",
		args = { arg("seconds", "number", "Секунд", { min = 0.5, max = 3600 }) },
	},
	PlayerJoined = { title = "Когда игрок зашёл на карту", args = {} },
	PlayerDied = { title = "Когда игрок погиб", args = {} },
	Arrived = { title = "Когда модель дошла до точки", args = { arg("model", "model", "Модель"), arg("point", "waypoint", "Точка") } },
}

Commands.conditions = {
	LightIsOn = { title = "Свет включён", args = { arg("light", "light", "Лампа") } },
	DoorIsOpen = { title = "Дверь открыта", args = { arg("door", "door", "Дверь") } },
	ZoneHasPlayer = { title = "В зоне есть игрок", args = { arg("zone", "zone", "Зона") } },
	ClosetOccupied = { title = "Шкаф занят", args = { arg("closet", "closet", "Шкаф") } },
	IsNight = { title = "Сейчас ночь", args = {} },
	IsWeather = { title = "Сейчас погода", args = { arg("weather", "weather", "Погода") } },
	ScoreAtLeast = { title = "У игрока очков не меньше", args = { arg("score", "number", "Очки", { min = -1000000, max = 1000000 }) } },
	HealthBelow = { title = "Здоровье игрока ниже", args = { arg("health", "number", "Здоровье", { min = 0, max = 1000 }) } },
	Chance = { title = "Случайно с шансом", args = { arg("percent", "number", "Шанс, %", { min = 0, max = 100 }) } },
}

Commands.actions = {
	PlayClip = {
		title = "Воспроизвести клип",
		args = {
			arg("model", "model", "Модель"),
			arg("clip", "clip", "Клип"),
			arg("loop", "bool", "Повтор", { optional = true }),
		},
	},
	StopClip = { title = "Остановить клип", args = { arg("model", "model", "Модель") } },
	MoveTo = {
		title = "Переместить по маршруту",
		args = {
			arg("model", "model", "Модель"),
			arg("point", "waypoint", "Точка назначения"),
			arg("clip", "clip", "Клип в пути", { optional = true }),
			arg("speed", "number", "Скорость", { optional = true, min = 1, max = 60 }),
		},
	},
	SetLight = {
		title = "Изменить свет",
		args = {
			arg("light", "light", "Лампа"),
			arg("on", "bool", "Включить"),
			arg("brightness", "number", "Яркость", { optional = true, min = 0, max = 40 }),
		},
	},
	Say = {
		title = "Показать реплику",
		args = {
			arg("target", "any", "Над кем"),
			arg("text", "text", "Текст"),
			arg("seconds", "number", "Секунд", { optional = true, min = 0.5, max = 60 }),
		},
	},
	Wait = { title = "Подождать", args = { arg("seconds", "number", "Секунд", { min = 0, max = 60 }) } },
	OpenDoor = { title = "Открыть дверь", args = { arg("door", "door", "Дверь") } },
	CloseDoor = { title = "Закрыть дверь", args = { arg("door", "door", "Дверь") } },
	ShowLabel = {
		title = "Показать надпись",
		args = { arg("target", "any", "Объект с надписью"), arg("visible", "bool", "Видна") },
	},
	SetWeather = { title = "Сменить погоду", args = { arg("weather", "weather", "Погода") } },
	PlaySound = {
		title = "Проиграть звук",
		args = {
			arg("sound", "sound", "ID звука"),
			arg("volume", "number", "Громкость", { optional = true, min = 0, max = 1 }),
			arg("target", "any", "Где звучит", { optional = true }),
		},
	},
	PlayMusic = {
		title = "Включить музыку",
		args = { arg("sound", "sound", "ID звука"), arg("volume", "number", "Громкость", { optional = true, min = 0, max = 1 }) },
	},
	StopMusic = { title = "Выключить музыку", args = {} },
	DamagePlayer = { title = "Нанести урон игроку", args = { arg("amount", "number", "Урон", { min = 0, max = 1000 }) } },
	HealPlayer = { title = "Вылечить игрока", args = { arg("amount", "number", "Здоровье", { min = 0, max = 1000 }) } },
	TeleportPlayer = { title = "Переместить игрока", args = { arg("point", "waypoint", "Точка") } },
	SetPlayerSpeed = { title = "Скорость игрока", args = { arg("speed", "number", "Скорость", { min = 0, max = 100 }) } },
	ShowMessage = {
		title = "Сообщение на экран",
		args = { arg("text", "text", "Текст"), arg("seconds", "number", "Секунд", { optional = true, min = 0.5, max = 60 }) },
	},
	AddScore = { title = "Добавить очки", args = { arg("amount", "number", "Очки", { min = -100000, max = 100000 }) } },
	SetTime = {
		title = "Установить время суток",
		args = { arg("hours", "number", "Часы, 0–24", { min = 0, max = 24 }) },
	},
	PlayCutscene = {
		title = "Кат-сцена камеры",
		args = { arg("model", "model", "Модель"), arg("clip", "clip", "Клип с дорожкой камеры") },
	},
	SetVisible = {
		title = "Показать или скрыть объект",
		args = { arg("target", "any", "Объект"), arg("visible", "bool", "Виден") },
	},
}

-- Какие роли подходят под тип аргумента
Commands.TARGET_TYPES = {
	door = function(obj)
		return obj.role ~= nil and obj.role.type == "door"
	end,
	light = function(obj)
		return obj.role ~= nil and obj.role.type == "light"
	end,
	zone = function(obj)
		return obj.role ~= nil and obj.role.type == "zone"
	end,
	closet = function(obj)
		return obj.role ~= nil and obj.role.type == "closet"
	end,
	waypoint = function(obj)
		return obj.role ~= nil and obj.role.type == "waypoint"
	end,
	model = function(obj)
		return obj.kind == "model"
	end,
	any = function(_obj)
		return true
	end,
}

Commands.WEATHER_TITLES = { Clear = "Ясно", Rain = "Дождь", Snow = "Снег", Fog = "Туман", Storm = "Гроза" }

function Commands.lookup(category: string, name: string)
	local t = (Commands :: any)[category]
	return t and t[name]
end

function Commands.minArgs(def): number
	local n = 0
	for i, a in def.args do
		if not a.optional then
			n = i
		end
	end
	return n
end

return Commands
