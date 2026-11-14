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
	{ id = "season", target = "none", arg = SEASONS, en = "Season", ru = "Время года" },
	{ id = "day", target = "none", en = "Day", ru = "День" },
	{ id = "dusk", target = "none", en = "Evening", ru = "Вечер" },
	{ id = "night", target = "none", en = "Night", ru = "Ночь" },
	{ id = "weather", target = "none", arg = WEATHER, en = "Weather", ru = "Погода" },
	{ id = "lightning", target = "none", en = "Lightning", ru = "Молния" },
	{ id = "announce", target = "none", arg = "text", en = "Message to castle", ru = "Сообщение в замок" },
	{ id = "fireworks", target = "none", en = "Fireworks", ru = "Салют" },
	{ id = "confetti", target = "none", en = "Confetti", ru = "Конфетти" },
	{ id = "passage_open", target = "none", en = "Open secret passage", ru = "Открыть тайный ход" },
	{ id = "passage_close", target = "none", en = "Close secret passage", ru = "Закрыть тайный ход" },
	{ id = "gates_open", target = "none", en = "Open gates", ru = "Открыть ворота" },
	{ id = "gates_close", target = "none", en = "Close gates", ru = "Закрыть ворота" },
	{ id = "free_all", target = "none", en = "Free all prisoners", ru = "Отпустить всех узников" },
	{ id = "spawn_guards", target = "none", arg = "number", en = "Spawn NPC guards", ru = "Призвать стражу NPC" },
	{ id = "clear_npcs", target = "none", en = "Remove NPCs", ru = "Убрать NPC" },
	{ id = "pvp_on", target = "none", en = "Fights on", ru = "Бои включены" },
	{ id = "pvp_off", target = "none", en = "Fights off", ru = "Бои выключены" },
	{ id = "needs_on", target = "none", en = "Hunger on", ru = "Голод включён" },
	{ id = "needs_off", target = "none", en = "Hunger off", ru = "Голод выключен" },
	{ id = "music", target = "none", arg = "text", en = "Play music by ID", ru = "Музыка по ID" },
	{ id = "music_stop", target = "none", en = "Stop music", ru = "Выключить музыку" },
	{ id = "reset_roles", target = "none", en = "Reset all roles", ru = "Сбросить все роли" },
	{ id = "heal_all", target = "none", en = "Heal everyone", ru = "Вылечить всех" },
	{ id = "feed_all", target = "none", en = "Feed everyone", ru = "Накормить всех" },
	-- игрок
	{ id = "kill", target = "player", en = "Kill", ru = "Убить" },
	{ id = "heal", target = "player", en = "Heal", ru = "Вылечить" },
	{ id = "refill", target = "player", en = "Feed and water", ru = "Накормить и напоить" },
	{ id = "starve", target = "player", en = "Make hungry", ru = "Сделать голодным" },
	{ id = "god", target = "player", en = "Immortal", ru = "Бессмертие" },
	{ id = "ungod", target = "player", en = "Mortal", ru = "Снять бессмертие" },
	{ id = "speed", target = "player", arg = "number", en = "Speed", ru = "Скорость" },
	{ id = "jump", target = "player", arg = "number", en = "Jump power", ru = "Сила прыжка" },
	{ id = "fly", target = "player", en = "Fly", ru = "Полёт" },
	{ id = "unfly", target = "player", en = "Stop flying", ru = "Без полёта" },
	{ id = "invisible", target = "player", en = "Invisible", ru = "Невидимость" },
	{ id = "visible", target = "player", en = "Visible", ru = "Видимость" },
	{ id = "hidename", target = "player", en = "Hide name", ru = "Скрыть ник" },
	{ id = "showname", target = "player", en = "Show name", ru = "Показать ник" },
	{ id = "freeze", target = "player", en = "Freeze", ru = "Заморозить" },
	{ id = "thaw", target = "player", en = "Unfreeze", ru = "Разморозить" },
	{ id = "bring", target = "player", en = "Bring to me", ru = "Ко мне" },
	{ id = "goto", target = "player", en = "Go to player", ru = "К игроку" },
	{ id = "tp_throne", target = "player", en = "To throne room", ru = "В тронный зал" },
	{ id = "tp_yard", target = "player", en = "To courtyard", ru = "Во двор" },
	{ id = "jail", target = "player", en = "To dungeon", ru = "В темницу" },
	{ id = "free", target = "player", en = "Release", ru = "Освободить" },
	{ id = "kick", target = "player", en = "Kick from server", ru = "Выгнать с сервера" },
	{ id = "give_gold", target = "player", arg = "number", en = "Give gold", ru = "Дать золото" },
	{ id = "take_gold", target = "player", arg = "number", en = "Take gold", ru = "Забрать золото" },
	{ id = "give_item", target = "player", arg = ITEMS, en = "Give item", ru = "Дать предмет" },
	{ id = "clear_items", target = "player", en = "Empty inventory", ru = "Очистить инвентарь" },
	{ id = "set_role", target = "player", arg = ROLES, en = "Set role", ru = "Назначить роль" },
	{ id = "dethrone", target = "player", en = "Take the crown", ru = "Лишить короны" },
	{ id = "size_big", target = "player", en = "Giant", ru = "Великан" },
	{ id = "size_small", target = "player", en = "Tiny", ru = "Малыш" },
	{ id = "size_normal", target = "player", en = "Normal size", ru = "Обычный рост" },
	{ id = "sparkles", target = "player", en = "Sparkles", ru = "Искры" },
	{ id = "fire", target = "player", en = "Fire", ru = "Огонь" },
	{ id = "smoke", target = "player", en = "Smoke", ru = "Дым" },
	{ id = "forcefield", target = "player", en = "Shield", ru = "Щит" },
	{ id = "clear_effects", target = "player", en = "Remove effects", ru = "Убрать эффекты" },
	{ id = "fling", target = "player", en = "Toss", ru = "Подбросить" },
	{ id = "sit", target = "player", en = "Sit down", ru = "Усадить" },
	{ id = "respawn", target = "player", en = "Respawn", ru = "Возродить" },
	{ id = "glow", target = "player", en = "Glow", ru = "Подсветка" },
	{ id = "mute", target = "player", en = "Mute chat", ru = "Запретить чат" },
	{ id = "unmute", target = "player", en = "Unmute chat", ru = "Разрешить чат" },
	{ id = "explode", target = "player", en = "Harmless boom", ru = "Безопасный взрыв" },
}

C.BY_ID = {}
for _, c in C.LIST do
	C.BY_ID[c.id] = c
end

return C
