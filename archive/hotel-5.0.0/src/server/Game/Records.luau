--!nonstrict
-- Рекорды: лучший номер двери и сколько раз глава пройдена (больше ничего не сохраняется)

local Config = require(script.Parent.Parent.Config)
local Adapter = require(script.Parent.Parent.DataStoreAdapter)

local Records = {}

local store = nil
local best: { [number]: number } = {}

local function key(userId: number): string
	return "u_" .. userId
end

function Records.init()
	local _ = Config
	store = Adapter.create()
end

function Records.load(p: Player): number
	local ok, data = pcall(function()
		return store.get(key(p.UserId))
	end)
	local b = if ok and type(data) == "table" and type(data.best) == "number" then data.best else 0
	best[p.UserId] = b
	return b
end

function Records.get(p: Player): number
	return best[p.UserId] or 0
end

-- новый рекорд сохраняется сразу (в фоне)
function Records.offer(p: Player, door: number): boolean
	if p.UserId <= 0 or door <= (best[p.UserId] or 0) then
		return false
	end
	best[p.UserId] = door
	task.spawn(function()
		pcall(function()
			store.update(key(p.UserId), function(old)
				local o = if type(old) == "table" then old else {}
				o.best = math.max(tonumber(o.best) or 0, door)
				return o
			end)
		end)
	end)
	return true
end

-- глава пройдена до конца (добежал до пустоты)
function Records.complete(p: Player)
	if p.UserId <= 0 then
		return
	end
	task.spawn(function()
		pcall(function()
			store.update(key(p.UserId), function(old)
				local o = if type(old) == "table" then old else {}
				o.done = (tonumber(o.done) or 0) + 1
				return o
			end)
		end)
	end)
end

function Records.forget(p: Player)
	best[p.UserId] = nil
end

return Records
