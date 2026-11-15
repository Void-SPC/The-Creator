--!nonstrict
-- Админ-панель: быстрые проверки игры одному. Доступ только создателям, проверка на сервере

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Commands = require(Shared.AdminCommands)
local Rules = require(Shared.Rules)
local Remotes = require(Shared.Roblox.Remotes)

local Access = require(script.Parent.Parent.Access)
local Entities = require(script.Parent.Entities)
local G = require(script.Parent.Game)

local Admin = {}

-- открыть несколько дверей подряд и перенести живых игроков к последней
local function skip(count: number)
	local run = G.run
	if G.mode ~= "run" then
		return
	end
	for _ = 1, count do
		local n = run.front + 1
		local info = run.rooms[n - 1]
		if not info or not info.door or n >= Rules.FINAL_ROOM then
			break
		end
		info.sealed = false
		if info.toll then
			info.toll.paid = true
			info.toll.model:Destroy()
			info.toll.block:Destroy()
		end
		G.openDoor(n, true)
	end
	local info = run.rooms[run.front]
	if info then
		for _, p in G.alivePlayers() do
			G.unhide(p)
			G.teleport(p, info.origin * CFrame.new(0, 3, -4))
		end
	end
end

local RUN = {
	start_here = function()
		G.startHere()
	end,
	coins = function(p)
		G.give(p, "coins", 100)
	end,
	items = function(p)
		for _, it in { "battery", "plant", "lockpick", "hammer" } do
			G.give(p, it)
		end
	end,
	heal = function(p)
		local hum = G.humOf(p)
		if hum then
			hum.Health = hum.MaxHealth
		end
	end,
	god = function(p)
		local s = G.players[p]
		if s then
			s.god = not s.god
			G.toast(p, if s.god then "GodOn" else "GodOff")
		end
	end,
	skip = function()
		skip(5)
	end,
	skip20 = function()
		skip(20)
	end,
	to_code = function()
		skip(math.max(0, Rules.CODE_ROOM - G.run.front))
	end,
	to_lift = function()
		skip(math.max(0, Rules.LIFT_ROOM - G.run.front))
	end,
	darkness = function()
		task.spawn(Entities.darkness)
	end,
	unseal = function()
		local info = G.run.rooms[G.run.front]
		if info then
			info.sealed = false
			if info.door then
				info.door.locked = false
			end
			if info.locks then
				info.locks.code, info.locks.order = true, true
			end
			if info.gate and not info.gate.opened then
				for _, l in info.levers do
					l.need = l.on
				end
			end
		end
	end,
	restart = function()
		task.spawn(G.endRun)
	end,
}

function Admin.init()
	Remotes.fn("AdminRequest").OnServerInvoke = function(p: Player, action: any, id: any)
		if action == "Status" then
			return { ok = true, admin = Access.isCreator(p) }
		end
		if action ~= "Run" or not Access.isCreator(p) then
			return { ok = false }
		end
		if type(id) ~= "string" or not Commands.BY_ID[id] or not RUN[id] then
			return { ok = false }
		end
		local ok, err = pcall(RUN[id], p)
		if not ok then
			warn("[Museum] admin " .. id .. ": " .. tostring(err))
		end
		return { ok = ok }
	end
end

return Admin
