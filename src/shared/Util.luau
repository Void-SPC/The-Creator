--!nonstrict
-- Мелкие помощники для работы с таблицами данных проекта

local Util = {}

function Util.deepCopy<T>(v: T): T
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v :: any do
		out[k] = Util.deepCopy(x)
	end
	return (out :: any) :: T
end

function Util.deepEqual(a: any, b: any): boolean
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not Util.deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

function Util.keys(t: { [any]: any }): { any }
	local out = {}
	for k in t do
		table.insert(out, k)
	end
	table.sort(out, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return out
end

function Util.count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

function Util.clamp(v: number, lo: number, hi: number): number
	if v ~= v then
		return lo
	end
	if v < lo then
		return lo
	elseif v > hi then
		return hi
	end
	return v
end

function Util.trim(s: string): string
	return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

-- Грубая оценка размера данных в байтах (для лимита DataStore)
function Util.approxSize(v: any): number
	local t = type(v)
	if t == "string" then
		return #v + 2
	elseif t == "number" then
		return 8
	elseif t == "boolean" then
		return 5
	elseif t == "table" then
		local n = 2
		for k, x in v do
			n += Util.approxSize(k) + Util.approxSize(x) + 1
		end
		return n
	end
	return 4
end

return Util
