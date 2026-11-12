--!nonstrict
-- Права администратора проверяются только на сервере

local RunService = game:GetService("RunService")
local Config = require(script.Parent.Config)

local AdminService = {}

local cache: { [number]: boolean } = {}

function AdminService.isAdmin(player: Player): boolean
	local cached = cache[player.UserId]
	if cached ~= nil then
		return cached
	end
	local result = false
	if RunService:IsStudio() then
		result = true
	elseif game.CreatorType == Enum.CreatorType.User and game.CreatorId == player.UserId then
		result = true
	elseif table.find(Config.ADMIN_USER_IDS, player.UserId) then
		result = true
	elseif Config.ADMIN_GROUP then
		local g = Config.ADMIN_GROUP
		local ok, rank = pcall(function()
			return player:GetRankInGroup(g.id)
		end)
		result = ok and rank >= g.minRank
	elseif game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(game.CreatorId)
		end)
		result = ok and rank >= 254
	end
	cache[player.UserId] = result
	return result
end

function AdminService.forget(player: Player)
	cache[player.UserId] = nil
end

return AdminService
