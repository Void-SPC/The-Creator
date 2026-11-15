--!nonstrict
-- Адаптер DataStore для рекордов
-- В Studio без доступа к API используется память сервера с предупреждением в выводе

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

local Adapter = {}

local function waitBudget(kind: Enum.DataStoreRequestType)
	local deadline = os.clock() + 15
	while DataStoreService:GetRequestBudgetForRequestType(kind) < 1 and os.clock() < deadline do
		task.wait(0.5)
	end
end

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local o = {}
	for k, x in v do
		o[k] = deepCopy(x)
	end
	return o
end

function Adapter.memory()
	local data = {}
	return {
		kind = "memory",
		get = function(key: string)
			return deepCopy(data[key])
		end,
		update = function(key: string, fn)
			local nv = fn(deepCopy(data[key]))
			if nv ~= nil then
				data[key] = deepCopy(nv)
			end
			return deepCopy(nv)
		end,
	}
end

function Adapter.create()
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if ok and RunService:IsStudio() then
		-- проверяем доступ к API в Studio
		local probe = pcall(function()
			return store:GetAsync("probe")
		end)
		if not probe then
			ok = false
		end
	end
	if not ok then
		warn("[Labyrinth] DataStore недоступен, поэтому данные хранятся только в памяти этого сервера (включите Studio Access to API Services)")
		return Adapter.memory()
	end
	local ds = store :: DataStore
	return {
		kind = "datastore",
		get = function(key: string)
			waitBudget(Enum.DataStoreRequestType.GetAsync)
			return ds:GetAsync(key)
		end,
		update = function(key: string, fn)
			waitBudget(Enum.DataStoreRequestType.UpdateAsync)
			return ds:UpdateAsync(key, function(old)
				return fn(old)
			end)
		end,
	}
end

return Adapter
