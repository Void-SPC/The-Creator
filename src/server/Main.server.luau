--!nonstrict
-- Точка входа сервера «The Labyrinth»

local Players = game:GetService("Players")
local Remotes = require(game:GetService("ReplicatedStorage").Workshop.Shared.Roblox.Remotes)
local Access = require(script.Parent.Access)
local G = require(script.Parent.Game.Game)
local Admin = require(script.Parent.Game.Admin)

-- сеть создаётся до всего остального, чтобы клиенты могли подключиться сразу
Remotes.event("Game")
G.init()
Admin.init()

Players.PlayerRemoving:Connect(function(p)
	Access.forget(p)
end)
