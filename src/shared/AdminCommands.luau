--!nonstrict
-- Команды админ-панели (для проверки игры). Исполняет сервер (Game/Admin)

local C = {}

C.LIST = {
	{ id = "coins", en = "+50 coins", ru = "+50 монет" },
	{ id = "items", en = "Battery, plant, lockpick, whistle", ru = "Батарейка, растение, отмычка, свисток" },
	{ id = "fuses", en = "2 fuses (generator hall)", ru = "2 детали (зал генераторов)" },
	{ id = "heal", en = "Full health", ru = "Полное здоровье" },
	{ id = "god", en = "Immortality on / off", ru = "Бессмертие вкл / выкл" },
	{ id = "skip", en = "Open 5 doors ahead", ru = "Открыть 5 дверей вперёд" },
	{ id = "sector_end", en = "Go to the end of the sector", ru = "К концу сектора" },
	{ id = "hum", en = "Summon the Hum", ru = "Вызвать Гул" },
	{ id = "watcher", en = "Watcher in this room", ru = "Смотритель в этой комнате" },
	{ id = "fix_gens", en = "Repair all generators", ru = "Починить все генераторы" },
	{ id = "restart", en = "Restart the run", ru = "Начать забег заново" },
}

C.BY_ID = {}
for _, c in C.LIST do
	C.BY_ID[c.id] = c
end

return C
