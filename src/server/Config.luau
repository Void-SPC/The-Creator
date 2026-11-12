--!nonstrict
-- Настройки сервера мастерской

local Config = {}

-- Администраторы: ID пользователей Roblox. Владелец плейса — администратор всегда
Config.ADMIN_USER_IDS = {} :: { number }
-- Группа: { id = 123, minRank = 200 } или nil
Config.ADMIN_GROUP = nil :: { id: number, minRank: number }?

Config.DATASTORE_NAME = "Workshop_v1"
Config.AUTOSAVE_SECONDS = 20
Config.SAVE_RETRY_SECONDS = 8
Config.READONLY_RETRY_SECONDS = 10

-- Сессии игры размещаются далеко друг от друга, чтобы карты не пересекались
Config.SLOT_SPACING = 4000
-- Предпросмотр редактора строится на клиенте в этой точке
Config.EDITOR_ORIGIN = Vector3.new(0, 0, -6000)
Config.LOBBY_ORIGIN = Vector3.new(0, 0, 0)

Config.EDIT_OPS_PER_SECOND = 40
Config.REQUESTS_PER_SECOND = 6
Config.CLOSET_DISTANCE = 10
Config.CLOSET_TAP_COOLDOWN = 0.3
Config.NPC_GREET_COOLDOWN = 10

return Config
