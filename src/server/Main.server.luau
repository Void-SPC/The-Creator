--!nonstrict
-- Точка входа сервера «The Castle»: замок (RP) и отдельный режим «Мафия»

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Remotes = require(Shared.Roblox.Remotes)

local Adapter = require(script.Parent.DataStoreAdapter)
local ProjectStore = require(script.Parent.Core.ProjectStore)
local Access = require(script.Parent.Access)
local CurrencyService = require(script.Parent.CurrencyService)
local MafiaGame = require(script.Parent.Mafia.MafiaGame)
local CastleGame = require(script.Parent.Castle.CastleGame)
local Admin = require(script.Parent.Castle.Admin)

-- сеть создаётся до всего остального, чтобы клиенты могли подключиться сразу
Remotes.event("Castle")

local adapter = Adapter.create()
local store = ProjectStore.new(adapter, { jobId = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false) })

CurrencyService.init(store)
CastleGame.init(store)
Admin.init()
-- переход между замком и мафией: игрок в один момент только в одном режиме,
-- чат и сообщения на экране у режимов раздельные
MafiaGame.init({
	beforeJoin = function(p)
		CastleGame.leave(p)
		CastleGame.addToGeneral(p, false)
	end,
	afterLeave = function(p)
		CastleGame.addToGeneral(p, true)
	end,
})

Players.PlayerRemoving:Connect(function(p)
	Access.forget(p)
end)

-- старые запросы мастерской больше не поддерживаются
Remotes.fn("Request").OnServerInvoke = function()
	return { ok = false, error = "unknown" }
end
