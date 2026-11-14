--!nonstrict
-- Настройки сервера «The Labyrinth»

local Config = {}

-- Создатели (админ-панель): владелец игры всегда, плюс эти имена (проверяются по ID)
Config.CREATOR_USERNAMES = { "Saren45hil", "Nataliaavira13" } :: { string }
Config.CREATOR_USER_IDS = {} :: { number }

-- Хранилище рекордов (только лучший номер двери, прогресс забега не сохраняется)
Config.DATASTORE_NAME = "Labyrinth_Records_v1"

return Config
