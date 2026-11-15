--!nonstrict
-- Команды админ-панели (для проверки игры). Исполняет сервер (Game/Admin)

local C = {}

C.LIST = {
	{ id = "start_here", en = "Start a run in this server", ru = "Начать забег в этом сервере" },
	{ id = "coins", en = "+100 coins", ru = "+100 монет" },
	{ id = "items", en = "Battery, plant, lockpick", ru = "Батарейка, растение, отмычка" },
	{ id = "fuses", en = "2 fuses (generator hall)", ru = "2 детали (зал генераторов)" },
	{ id = "heal", en = "Full health", ru = "Полное здоровье" },
	{ id = "god", en = "Immortality on / off", ru = "Бессмертие вкл / выкл" },
	{ id = "skip", en = "Open 5 doors ahead", ru = "Открыть 5 дверей вперёд" },
	{ id = "skip20", en = "Open 20 doors ahead", ru = "Открыть 20 дверей вперёд" },
	{ id = "to_boss", en = "To door 099 (before the Blind)", ru = "К двери 099 (перед Слепым)" },
	{ id = "hum", en = "Summon the Hum", ru = "Вызвать Гул" },
	{ id = "watcher", en = "Watcher in this room", ru = "Смотритель в этой комнате" },
	{ id = "fix_gens", en = "Almost repair all generators", ru = "Почти починить все генераторы" },
	{ id = "restart", en = "End the run", ru = "Закончить забег" },
}

C.BY_ID = {}
for _, c in C.LIST do
	C.BY_ID[c.id] = c
end

return C
