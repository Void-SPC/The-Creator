--!nonstrict
-- Админ-панель: быстрые проверки игры одному (монеты, предметы, пропуск дверей,
-- вызов существ). Доступ только создателям, проверка на сервере

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Commands = require(Shared.AdminCommands)
local Rules = require(Shared.Rules)
local Remotes = require(Shared.Roblox.Remotes)

local Access = require(script.Parent.Parent.Access)
local Builder = require(script.Parent.Parent.World.RoomBuilder)
local Entities = require(script.Parent.Entities)
local G = require(script.Parent.Game)

local Admin = {}

-- открыть несколько дверей подряд и перенести живых игроков к последней
local function skip(count: number)
	local run = G.run
	for _ = 1, count do
		local n = run.front + 1
		local info = run.rooms[n - 1]
		if not info or (info.elevatorInfo and not info.elevatorInfo.rideDone) then
			break
		end
		if info.toll then
			info.toll.paid = true
			info.toll.model:Destroy()
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
	coins = function(p)
		G.give(p, "coins", 50)
	end,
	items = function(p)
		for _, it in { "battery", "plant", "lockpick", "whistle" } do
			G.give(p, it)
		end
	end,
	fuses = function(p)
		G.give(p, "fuse")
		G.give(p, "fuse")
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
	sector_end = function()
		local run = G.run
		local target = math.ceil((run.front + 1) / Rules.SECTOR_LEN) * Rules.SECTOR_LEN
		skip(math.max(0, target - run.front))
	end,
	hum = function()
		task.spawn(Entities.hum)
	end,
	watcher = function(p)
		local r = G.rootOf(p)
		for _, info in G.run.rooms do
			if r and Builder.contains(info, r.Position) then
				Entities.spawnWatcher(info)
				return
			end
		end
	end,
	fix_gens = function()
		for _, info in G.run.rooms do
			if info.generators then
				for _, g in info.generators do
					g.fused = true
					g.progress = 99
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
			warn("[Labyrinth] admin " .. id .. ": " .. tostring(err))
		end
		return { ok = ok }
	end
end

return Admin
