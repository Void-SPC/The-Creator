--!nonstrict
-- Кто считается создателем: владелец игры, пользователи из Config и (в Studio) все
-- Права проверяются только на сервере; клиент лишь прячет кнопки

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Config)

local Access = {}

local resolvedIds: { [number]: boolean } = {}
local cache: { [number]: boolean } = {}

-- Имена из Config переводятся в постоянные ID аккаунтов, чтобы смена ника не давала
-- доступ чужому человеку с таким же именем
task.spawn(function()
	for _, name in Config.CREATOR_USERNAMES do
		for _ = 1, 3 do
			local ok, id = pcall(function()
				return Players:GetUserIdFromNameAsync(name)
			end)
			if ok and type(id) == "number" then
				resolvedIds[id] = true
				table.clear(cache)
				break
			end
			task.wait(2)
		end
	end
end)

local function ownerOf(player: Player): boolean
	if game.CreatorType == Enum.CreatorType.User then
		return game.CreatorId == player.UserId
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroup(game.CreatorId)
	end)
	return ok and rank >= 254
end

function Access.isCreator(player: Player): boolean
	local c = cache[player.UserId]
	if c ~= nil then
		return c
	end
	local result = RunService:IsStudio()
		or ownerOf(player)
		or resolvedIds[player.UserId] == true
		or table.find(Config.CREATOR_USER_IDS, player.UserId) ~= nil
	-- кэшируем только положительный ответ: ID имени может прийти чуть позже
	if result then
		cache[player.UserId] = true
	end
	return result
end

function Access.forget(player: Player)
	cache[player.UserId] = nil
end

return Access
