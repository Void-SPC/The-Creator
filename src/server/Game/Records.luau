--!nonstrict
-- Что сохраняется: лучший номер двери, сколько раз локация пройдена и журнал
-- (кого из существ игрок уже встречал). Ход забега не сохраняется

local Adapter = require(script.Parent.Parent.DataStoreAdapter)

local Records = {}

local store = nil
local best: { [number]: number } = {}
local journal: { [number]: { [string]: boolean } } = {}

local function key(userId: number): string
	return "u_" .. userId
end

local function update(p: Player, fn)
	if p.UserId <= 0 then
		return
	end
	task.spawn(function()
		pcall(function()
			store.update(key(p.UserId), function(old)
				local o = if type(old) == "table" then old else {}
				fn(o)
				return o
			end)
		end)
	end)
end

function Records.init()
	store = Adapter.create()
end

function Records.load(p: Player): number
	local ok, data = pcall(function()
		return store.get(key(p.UserId))
	end)
	local d = if ok and type(data) == "table" then data else {}
	best[p.UserId] = if type(d.best) == "number" then d.best else 0
	journal[p.UserId] = if type(d.journal) == "table" then d.journal else {}
	return best[p.UserId]
end

function Records.get(p: Player): number
	return best[p.UserId] or 0
end

function Records.journal(p: Player): { [string]: boolean }
	return journal[p.UserId] or {}
end

function Records.offer(p: Player, door: number): boolean
	if door <= (best[p.UserId] or 0) then
		return false
	end
	best[p.UserId] = door
	update(p, function(o)
		o.best = math.max(tonumber(o.best) or 0, door)
	end)
	return true
end

-- новая запись в журнале; true, если раньше её не было
function Records.discover(p: Player, id: string): boolean
	local j = journal[p.UserId]
	if not j then
		j = {}
		journal[p.UserId] = j
	end
	if j[id] then
		return false
	end
	j[id] = true
	update(p, function(o)
		o.journal = if type(o.journal) == "table" then o.journal else {}
		o.journal[id] = true
	end)
	return true
end

function Records.complete(p: Player)
	update(p, function(o)
		o.done = (tonumber(o.done) or 0) + 1
	end)
end

function Records.forget(p: Player)
	best[p.UserId] = nil
	journal[p.UserId] = nil
end

return Records
