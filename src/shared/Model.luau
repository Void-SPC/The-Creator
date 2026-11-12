--!nonstrict
-- Склейка деталей в модель, копирование с новыми ID, «Мои модели»

local Util = require(script.Parent.Util)
local MathX = require(script.Parent.MathX)
local Ids = require(script.Parent.Ids)
local Format = require(script.Parent.Format)

local Model = {}

local PART_FIELDS = { "shape", "size", "color", "material", "texture", "transparency", "name" }

local function allocPart(model)
	local n = model.nextPart or 1
	model.nextPart = n + 1
	return "p" .. tostring(n)
end

-- Мировые трансформы деталей модели в позе покоя
function Model.partWorld(obj, partId: string)
	local part = obj.model.parts[partId]
	return MathX.mul(MathX.tf(obj.pos, obj.rot), MathX.tf(part.pos, part.rot))
end

-- Склеивает выбранные объекты в одну модель. Возвращает операцию batch или ошибку
-- Модели без клипов разворачиваются в детали; объекты с ролью склеивать нельзя
function Model.glue(project, ids: { string }, name: string?)
	if #ids < 1 then
		return nil, "nothing selected"
	end
	local objects = project.map.objects
	local sum = { 0, 0, 0 }
	local count = 0
	local minY = math.huge
	for _, id in ids do
		local obj = objects[id]
		if not obj then
			return nil, "missing object"
		end
		if obj.role then
			return nil, "has role"
		end
		if obj.kind == "model" and next(obj.model.clips) ~= nil then
			return nil, "model has clips"
		end
		sum = MathX.add(sum, obj.pos)
		count += 1
		local bottom = obj.pos[2] - (if obj.size then obj.size[2] / 2 else 0)
		minY = math.min(minY, bottom)
	end
	local origin = { sum[1] / count, minY, sum[3] / count }
	local originTf = MathX.tf(origin, { 0, 0, 0 })
	local modelId = Ids.alloc(project, "o")
	local m = Format.newModel(modelId)
	m.name = name or "Модель"
	m.pos = origin
	local partsCount = 0
	for _, id in ids do
		local obj = objects[id]
		if obj.kind == "part" then
			local pid = allocPart(m.model)
			local localTf = MathX.toLocal(originTf, MathX.tf(obj.pos, obj.rot))
			local pos, rot = MathX.decompose(localTf)
			local part = { id = pid, pos = pos, rot = rot, pivot = { 0, 0, 0 }, parent = nil }
			for _, f in PART_FIELDS do
				part[f] = Util.deepCopy(obj[f])
			end
			m.model.parts[pid] = part
			partsCount += 1
		else
			local remap = {}
			for oldPid in obj.model.parts do
				remap[oldPid] = allocPart(m.model)
			end
			for oldPid, src in obj.model.parts do
				local world = Model.partWorld(obj, oldPid)
				local pos, rot = MathX.decompose(MathX.toLocal(originTf, world))
				local part = Util.deepCopy(src)
				part.id = remap[oldPid]
				part.pos, part.rot = pos, rot
				part.parent = if src.parent then remap[src.parent] else nil
				m.model.parts[part.id] = part
				partsCount += 1
			end
		end
	end
	if partsCount > Format.LIMITS.partsPerModel then
		return nil, "too many parts"
	end
	m.latin = Ids.suggestLatin(project, "Model")
	local ops = {}
	for _, id in ids do
		table.insert(ops, { op = "remove", id = id })
	end
	table.insert(ops, { op = "add", obj = m })
	return { op = "batch", ops = ops }, m
end

-- Разбирает модель на отдельные детали карты (клипы при этом теряются)
function Model.unglue(project, id: string)
	local obj = project.map.objects[id]
	if not obj or obj.kind ~= "model" then
		return nil, "not a model"
	end
	local ops = { { op = "remove", id = id } }
	for pid, src in obj.model.parts do
		local world = Model.partWorld(obj, pid)
		local pos, rot = MathX.decompose(world)
		local part = Format.newPart(Ids.alloc(project, "o"), src.shape)
		for _, f in PART_FIELDS do
			part[f] = Util.deepCopy(src[f])
		end
		part.pos, part.rot = pos, rot
		table.insert(ops, { op = "add", obj = part })
	end
	return { op = "batch", ops = ops }
end

-- Копирует объекты: новые ID, свободные латинские имена, ссылки внутри копируемой
-- группы переводятся на копии, ссылки наружу остаются прежними
function Model.duplicate(project, ids: { string }, offset)
	local objects = project.map.objects
	local mapping = {}
	local copies = {}
	for _, id in ids do
		if objects[id] then
			mapping[id] = Ids.alloc(project, "o")
		end
	end
	local reserved = {}
	for _, id in ids do
		local src = objects[id]
		if src then
			local c = Util.deepCopy(src)
			c.id = mapping[id]
			c.pos = MathX.add(c.pos, offset or { 2, 0, 2 })
			c.frozen = false
			if c.latin then
				local candidate = Ids.suggestLatin(project, c.latin)
				while reserved[candidate] do
					local n = tonumber(string.match(candidate, "(%d+)$")) or 1
					candidate = string.gsub(candidate, "%d+$", "") .. string.format("%02d", n + 1)
				end
				reserved[candidate] = true
				c.latin = candidate
			end
			Ids.forEachRef(c, function(holder)
				if mapping[holder.ref] then
					holder.ref = mapping[holder.ref]
				end
			end)
			table.insert(copies, c)
		end
	end
	local ops = {}
	for _, c in copies do
		table.insert(ops, { op = "add", obj = c })
	end
	return { op = "batch", ops = ops }, copies, mapping
end

-- «Мои модели»: модель без положения на карте и без ID карты
function Model.toAsset(obj, assetName: string?)
	local a = Util.deepCopy(obj)
	a.id = nil
	a.pos = { 0, 0, 0 }
	a.frozen = false
	a.latin = nil
	-- ссылки на объекты конкретной карты в библиотеке смысла не имеют
	Ids.forEachRef(a, function(holder)
		holder.ref = ""
	end)
	return { name = assetName or obj.name, version = Format.VERSION, object = a, savedAt = os.time() }
end

function Model.fromAsset(project, asset, pos)
	local obj = Util.deepCopy(asset.object)
	obj.id = Ids.alloc(project, "o")
	obj.pos = { pos[1], pos[2], pos[3] }
	obj.latin = Ids.suggestLatin(project, if obj.kind == "model" then "Model" else "Part")
	local function strip(t)
		for k, v in t do
			if type(v) == "table" then
				if v.ref == "" then
					t[k] = nil
				else
					strip(v)
				end
			end
		end
	end
	strip(obj)
	return obj
end

return Model
