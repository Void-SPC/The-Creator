--!nonstrict
-- Команды админ-панели «The Castle». target: "player" — нужен игрок, "none" — для всего замка
-- arg: nil | "number" | "text" | { варианты }. Сами команды исполняет сервер (Castle/Admin)

local C = {}

local SEASONS = { "summer", "spring", "april", "autumn", "halloween", "winter", "newyear" }
local WEATHER = { "Clear", "Rain", "Snow", "Fog", "Storm" }
local ROLES = { "king", "queen", "commander", "guard", "cook", "servant", "librarian", "peasant" }
local ITEMS = { "bread", "apple", "meat", "soup", "cake", "water", "juice", "spoon", "broom", "book", "scepter", "sword", "cuffs", "backpack" }

C.LIST = {
	-- мир
	{ id = "season", cat = "world", target = "none", arg = SEASONS, en = "Season", ru = "Время года" },
	{ id = "day", cat = "world", target = "none", en = "Day", ru = "День" },
	{ id = "dusk", cat = "world", target = "none", en = "Evening", ru = "Вечер" },
	{ id = "night", cat = "world", target = "none", en = "Night", ru = "Ночь" },
	{ id = "weather", cat = "world", target = "none", arg = WEATHER, en = "Weather", ru = "Погода" },
	{ id = "lightning", cat = "world", target = "none", en = "Lightning", ru = "Молния" },
	{ id = "announce", cat = "world", target = "none", arg = "text", en = "Message to castle", ru = "Сообщение в замок" },
	{ id = "fireworks", cat = "fun", target = "none", en = "Fireworks", ru = "Салют" },
	{ id = "confetti", cat = "fun", target = "none", en = "Confetti", ru = "Конфетти" },
	{ id = "passage_open", cat = "world", target = "none", en = "Open secret passage", ru = "Открыть тайный ход" },
	{ id = "passage_close", cat = "world", target = "none", en = "Close secret passage", ru = "Закрыть тайный ход" },
	{ id = "gates_open", cat = "world", target = "none", en = "Open gates", ru = "Открыть ворота" },
	{ id = "gates_close", cat = "world", target = "none", en = "Close gates", ru = "Закрыть ворота" },
	{ id = "free_all", cat = "moderation", target = "none", en = "Free all prisoners", ru = "Отпустить всех узников" },
	{ id = "spawn_guards", cat = "moderation", target = "none", arg = "number", en = "Spawn NPC guards", ru = "Призвать стражу NPC" },
	{ id = "clear_npcs", cat = "moderation", target = "none", en = "Remove NPCs", ru = "Убрать NPC" },
	{ id = "pvp_on", cat = "world", target = "none", en = "Fights on", ru = "Бои включены" },
	{ id = "pvp_off", cat = "world", target = "none", en = "Fights off", ru = "Бои выключены" },
	{ id = "needs_on", cat = "world", target = "none", en = "Hunger on", ru = "Голод включён" },
	{ id = "needs_off", cat = "world", target = "none", en = "Hunger off", ru = "Голод выключен" },
	{ id = "music", cat = "world", target = "none", arg = "text", en = "Play music by ID", ru = "Музыка по ID" },
	{ id = "music_stop", cat = "world", target = "none", en = "Stop music", ru = "Выключить музыку" },
	{ id = "reset_roles", cat = "moderation", target = "none", en = "Reset all roles", ru = "Сбросить все роли" },
	{ id = "heal_all", cat = "players", target = "none", en = "Heal everyone", ru = "Вылечить всех" },
	{ id = "feed_all", cat = "players", target = "none", en = "Feed everyone", ru = "Накормить всех" },
	-- игрок
	{ id = "kill", cat = "moderation", target = "player", en = "Kill", ru = "Убить" },
	{ id = "heal", cat = "players", target = "player", en = "Heal", ru = "Вылечить" },
	{ id = "refill", cat = "players", target = "player", en = "Feed and water", ru = "Накормить и напоить" },
	{ id = "starve", cat = "players", target = "player", en = "Make hungry", ru = "Сделать голодным" },
	{ id = "god", cat = "players", target = "player", en = "Immortal", ru = "Бессмертие" },
	{ id = "ungod", cat = "players", target = "player", en = "Mortal", ru = "Снять бессмертие" },
	{ id = "speed", cat = "players", target = "player", arg = "number", en = "Speed", ru = "Скорость" },
	{ id = "jump", cat = "players", target = "player", arg = "number", en = "Jump power", ru = "Сила прыжка" },
	{ id = "fly", cat = "players", target = "player", en = "Fly", ru = "Полёт" },
	{ id = "unfly", cat = "players", target = "player", en = "Stop flying", ru = "Без полёта" },
	{ id = "invisible", cat = "players", target = "player", en = "Invisible", ru = "Невидимость" },
	{ id = "visible", cat = "players", target = "player", en = "Visible", ru = "Видимость" },
	{ id = "hidename", cat = "players", target = "player", en = "Hide name", ru = "Скрыть ник" },
	{ id = "showname", cat = "players", target = "player", en = "Show name", ru = "Показать ник" },
	{ id = "freeze", cat = "moderation", target = "player", en = "Freeze", ru = "Заморозить" },
	{ id = "thaw", cat = "moderation", target = "player", en = "Unfreeze", ru = "Разморозить" },
	{ id = "bring", cat = "moderation", target = "player", en = "Bring to me", ru = "Ко мне" },
	{ id = "goto", cat = "moderation", target = "player", en = "Go to player", ru = "К игроку" },
	{ id = "tp_throne", cat = "moderation", target = "player", en = "To throne room", ru = "В тронный зал" },
	{ id = "tp_yard", cat = "moderation", target = "player", en = "To courtyard", ru = "Во двор" },
	{ id = "jail", cat = "moderation", target = "player", en = "To dungeon", ru = "В темницу" },
	{ id = "free", cat = "moderation", target = "player", en = "Release", ru = "Освободить" },
	{ id = "kick", cat = "moderation", target = "player", en = "Kick from server", ru = "Выгнать с сервера" },
	{ id = "give_gold", cat = "moderation", target = "player", arg = "number", en = "Give gold", ru = "Дать золото" },
	{ id = "take_gold", cat = "moderation", target = "player", arg = "number", en = "Take gold", ru = "Забрать золото" },
	{ id = "give_item", cat = "moderation", target = "player", arg = ITEMS, en = "Give item", ru = "Дать предмет" },
	{ id = "clear_items", cat = "moderation", target = "player", en = "Empty inventory", ru = "Очистить инвентарь" },
	{ id = "set_role", cat = "moderation", target = "player", arg = ROLES, en = "Set role", ru = "Назначить роль" },
	{ id = "dethrone", cat = "moderation", target = "player", en = "Take the crown", ru = "Лишить короны" },
	{ id = "size_big", cat = "fun", target = "player", en = "Giant", ru = "Великан" },
	{ id = "size_small", cat = "fun", target = "player", en = "Tiny", ru = "Малыш" },
	{ id = "size_normal", cat = "fun", target = "player", en = "Normal size", ru = "Обычный рост" },
	{ id = "sparkles", cat = "fun", target = "player", en = "Sparkles", ru = "Искры" },
	{ id = "fire", cat = "fun", target = "player", en = "Fire", ru = "Огонь" },
	{ id = "smoke", cat = "fun", target = "player", en = "Smoke", ru = "Дым" },
	{ id = "forcefield", cat = "fun", target = "player", en = "Shield", ru = "Щит" },
	{ id = "clear_effects", cat = "fun", target = "player", en = "Remove effects", ru = "Убрать эффекты" },
	{ id = "fling", cat = "fun", target = "player", en = "Toss", ru = "Подбросить" },
	{ id = "sit", cat = "fun", target = "player", en = "Sit down", ru = "Усадить" },
	{ id = "respawn", cat = "moderation", target = "player", en = "Respawn", ru = "Возродить" },
	{ id = "glow", cat = "fun", target = "player", en = "Glow", ru = "Подсветка" },
	{ id = "mute", cat = "moderation", target = "player", en = "Mute chat", ru = "Запретить чат" },
	{ id = "unmute", cat = "moderation", target = "player", en = "Unmute chat", ru = "Разрешить чат" },
	{ id = "explode", cat = "fun", target = "player", en = "Harmless boom", ru = "Безопасный взрыв" },
	-- силы Бога
	{ id = "smite", cat = "god", target = "player", en = "Smite with lightning", ru = "Поразить молнией" },
	{ id = "bless", cat = "god", target = "player", en = "Blessing", ru = "Благословение" },
	{ id = "levitate", cat = "god", target = "player", en = "Lift into the air", ru = "Поднять в воздух" },
	{ id = "holy_light", cat = "god", target = "player", en = "Pillar of light", ru = "Столп света" },
	{ id = "resurrect", cat = "god", target = "player", en = "Resurrect here", ru = "Воскресить на месте" },
	{ id = "divine_voice", cat = "god", target = "none", arg = "text", en = "Voice from the sky", ru = "Голос с небес" },
	{ id = "earthquake", cat = "god", target = "none", en = "Earthquake", ru = "Землетрясение" },
	{ id = "meteors", cat = "god", target = "none", en = "Meteor shower", ru = "Звездопад" },
	{ id = "gold_rain", cat = "god", target = "none", en = "Rain of gold", ru = "Золотой дождь" },
	{ id = "gravity_low", cat = "god", target = "none", en = "Low gravity", ru = "Слабая гравитация" },
	{ id = "gravity_normal", cat = "god", target = "none", en = "Normal gravity", ru = "Обычная гравитация" },
	{ id = "darkness", cat = "god", target = "none", en = "Darkness", ru = "Тьма" },
	{ id = "dawn", cat = "god", target = "none", en = "Holy dawn", ru = "Святой рассвет" },
	{ id = "freeze_all", cat = "god", target = "none", en = "Freeze everyone", ru = "Заморозить всех" },
	{ id = "thaw_all", cat = "god", target = "none", en = "Unfreeze everyone", ru = "Разморозить всех" },
	{ id = "bring_all", cat = "god", target = "none", en = "Gather everyone", ru = "Собрать всех ко мне" },
	{ id = "shield_all", cat = "god", target = "none", en = "Shield everyone", ru = "Щит всем" },
	{ id = "rainbow", cat = "god", target = "none", en = "Rainbow sky", ru = "Радужное небо" },
}

C.CATEGORIES = { "world", "players", "moderation", "fun", "god" }

C.BY_ID = {}
for _, c in C.LIST do
	C.BY_ID[c.id] = c
end

return C
