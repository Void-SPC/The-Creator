--!nonstrict
-- Настройки сервера «The Museum»

local Config = {}

-- Создатели (админ-панель): владелец игры всегда, плюс эти имена (проверяются по ID)
Config.CREATOR_USERNAMES = { "Saren45hil", "Nataliaavira13" } :: { string }
Config.CREATOR_USER_IDS = {} :: { number }

-- Хранилище рекордов и журнала
Config.DATASTORE_NAME = "Museum_Records_v1"

-- Значки (бейджи). Создай значок в Creator Dashboard, скопируй его ID и впиши сюда
-- вместо нуля — игра начнёт выдавать его сама. Ноль значит «значка пока нет»
Config.BADGES = {
	darkness = 0, -- первая встреча с Тьмой
	mimic = 0, -- первая встреча с тебЯ
	coinkeeper = 0, -- первая встреча с Монетчиком
	colossus = 0, -- первая встреча с Колоссом
	void = 0, -- коридор с проломами
	colossus_down = 0, -- Колосс побеждён
	finale = 0, -- первая локация пройдена (достижение «Продолжение следует»)
	darkness_hid = 0, -- пережил пролёт Тьмы
	coin_paid = 0, -- расплатился с Монетчиком
	mimic_solved = 0, -- разгадал фигурки тебЯ
	door50 = 0, -- открыл дверь 050
	door100 = 0, -- прошёл дверь 100
}

return Config
