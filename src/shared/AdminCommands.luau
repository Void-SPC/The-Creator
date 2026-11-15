--!nonstrict
-- Команды админ-панели (для проверки игры). Исполняет сервер (Game/Admin)

local C = {}

C.LIST = {
	{ id = "start_here", en = "Start a run in this server", ru = "Начать забег в этом сервере" },
	{ id = "coins", en = "+100 coins", ru = "+100 монет" },
	{ id = "items", en = "Battery, plant, lockpick, hammer", ru = "Батарейка, растение, отмычка, молоток" },
	{ id = "heal", en = "Full health", ru = "Полное здоровье" },
	{ id = "god", en = "Immortality on / off", ru = "Бессмертие вкл / выкл" },
	{ id = "skip", en = "Open 5 doors ahead", ru = "Открыть 5 дверей вперёд" },
	{ id = "skip20", en = "Open 20 doors ahead", ru = "Открыть 20 дверей вперёд" },
	{ id = "to_code", en = "To door 048 (hall of three locks)", ru = "К двери 048 (зал трёх замков)" },
	{ id = "to_lift", en = "To door 099 (elevator and stairs)", ru = "К двери 099 (лифт и лестница)" },
	{ id = "darkness", en = "Summon the Darkness", ru = "Вызвать Тьму" },
	{ id = "unseal", en = "Solve the puzzle of this room", ru = "Решить загадку этого зала" },
	{ id = "restart", en = "End the run", ru = "Закончить забег" },
}

C.BY_ID = {}
for _, c in C.LIST do
	C.BY_ID[c.id] = c
end

return C
