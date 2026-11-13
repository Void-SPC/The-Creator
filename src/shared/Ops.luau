--!nonstrict
-- Операции правки проекта. Одна и та же функция применяется на клиенте (сразу)
-- и на сервере (с проверкой). Каждая операция возвращает обратную, на этом
-- построены отмена и повтор

local Util = require(script.Parent.Util)
local Format = require(script.Parent.Format)
local Ids = require(script.Parent.Ids)

local Ops = {}

local OBJECT_ROOTS = {
	name = true, latin = true, pos = true, rot = true, size = true, shape = true,
	color = true, material = true, texture = true, transparency = true, frozen = true,
	physics = true, role = true, label = true, model = true, hidden = true, textureTile = true,
}

local PROJECT_ROOTS = { settings = true, logic = true, meta = true }
local META_KEYS = { name = true }

local function getPath(root, path)
	local cur = root
	for i = 1, #path do
		if type(cur) ~= "table" then
			return nil
		end
		cur = cur[path[i]]
	end
	return cur
end

local function setPath(root, path, value): boolean
	local cur = root
	for i = 1, #path - 1 do
		local nxt = cur[path[i]]
		if type(nxt) ~= "table" then
			if value == nil then
				return true
			end
			nxt = {}
			cur[path[i]] = nxt
		end
		cur = nxt
	end
	cur[path[#path]] = Util.deepCopy(value)
	return true
end

local function validPath(path, maxDepth): boolean
	if type(path) ~= "table" or #path == 0 or #path > maxDepth then
		return false
	end
	for _, k in path do
		local t = type(k)
		if t == "string" then
			if #k == 0 or #k > 40 then
				return false
			end
		elseif t == "number" then
			if k ~= math.floor(k) or k < 1 or k > 10000 then
				return false
			end
		else
			return false
		end
	end
	return true
end

local applyOne

local function applyBatch(project, ops, opts)
	if type(ops) ~= "table" or #ops > 500 then
		return false, "batch"
	end
	local inverses = {}
	for _, op in ops do
		local ok, res = applyOne(project, op, opts)
		if not ok then
			for i = #inverses, 1, -1 do
				applyOne(project, inverses[i], { validate = false })
			end
			return false, res
		end
		table.insert(inverses, res)
	end
	local rev = {}
	for i = #inverses, 1, -1 do
		table.insert(rev, inverses[i])
	end
	return true, { op = "batch", ops = rev }
end

function applyOne(project, op, opts): (boolean, any)
	opts = opts or {}
	local validate = opts.validate ~= false
	if type(op) ~= "table" then
		return false, "op"
	end
	local kind = op.op
	local objects = project.map.objects

	if kind == "batch" then
		return applyBatch(project, op.ops, opts)
	elseif kind == "add" then
		local obj = op.obj
		if type(obj) ~= "table" or type(obj.id) ~= "string" then
			return false, "add: object"
		end
		if objects[obj.id] then
			return false, "add: id exists"
		end
		if validate then
			local e = Format.validateObject(obj)
			if e then
				return false, e
			end
			if Util.count(objects) >= Format.LIMITS.objects then
				return false, "limit: objects"
			end
			if obj.latin and Ids.latinTaken(project, obj.latin, obj.id) then
				return false, "latin taken"
			end
		end
		objects[obj.id] = Util.deepCopy(obj)
		-- счётчик ID не должен отставать от выданных клиентом ID
		local n = tonumber(string.match(obj.id, "_([0-9a-z]+)$") or "", 36)
		if n and n >= (project.nextId or 1) then
			project.nextId = n + 1
		end
		return true, { op = "remove", id = obj.id }
	elseif kind == "remove" then
		local obj = objects[op.id]
		if not obj then
			return false, "remove: no object"
		end
		objects[op.id] = nil
		return true, { op = "add", obj = obj }
	elseif kind == "set" then
		local obj = objects[op.id]
		if not obj then
			return false, "set: no object"
		end
		if not validPath(op.path, 12) or not OBJECT_ROOTS[op.path[1]] then
			return false, "set: path"
		end
		local root = op.path[1]
		if validate and obj.frozen and (root == "pos" or root == "rot") then
			return false, "frozen"
		end
		local old = Util.deepCopy(getPath(obj, op.path))
		setPath(obj, op.path, op.value)
		if validate then
			local e = Format.validateObject(obj)
			if not e and root == "latin" and obj.latin and Ids.latinTaken(project, obj.latin, obj.id) then
				e = "latin taken"
			end
			if e then
				setPath(obj, op.path, old)
				return false, e
			end
		end
		return true, { op = "set", id = op.id, path = op.path, value = old }
	elseif kind == "setProject" then
		if not validPath(op.path, 12) or not PROJECT_ROOTS[op.path[1]] then
			return false, "setProject: path"
		end
		if op.path[1] == "meta" and not META_KEYS[op.path[2]] then
			return false, "setProject: meta"
		end
		local old = Util.deepCopy(getPath(project, op.path))
		setPath(project, op.path, op.value)
		if validate then
			local e = Format.validateSettings(project.settings)
			if not e and (type(project.meta.name) ~= "string" or #project.meta.name > Format.LIMITS.nameLen * 4) then
				e = "meta.name"
			end
			if not e then
				local lg = project.logic
				if type(lg) ~= "table" or type(lg.text) ~= "table" or type(lg.text.source) ~= "string"
					or #lg.text.source > Format.LIMITS.codeLen or type(lg.blocks) ~= "table"
					or (lg.mode ~= "blocks" and lg.mode ~= "text") then
					e = "logic"
				elseif Util.approxSize(lg) > 400000 then
					e = "logic too large"
				end
			end
			if e then
				setPath(project, op.path, old)
				return false, e
			end
		end
		return true, { op = "setProject", path = op.path, value = old }
	end
	return false, "unknown op"
end

function Ops.apply(project, op, opts): (boolean, any)
	return applyOne(project, op, opts)
end

-- Стек отмены на клиенте
function Ops.newHistory(limit: number?)
	return { undo = {}, redo = {}, limit = limit or 100 }
end

function Ops.record(history, inverse, forward)
	table.insert(history.undo, { inverse = inverse, forward = forward })
	if #history.undo > history.limit then
		table.remove(history.undo, 1)
	end
	table.clear(history.redo)
end

-- Возвращает операцию, которую нужно применить и отправить на сервер
function Ops.popUndo(history)
	local entry = table.remove(history.undo)
	if not entry then
		return nil
	end
	table.insert(history.redo, entry)
	return entry.inverse
end

function Ops.popRedo(history)
	local entry = table.remove(history.redo)
	if not entry then
		return nil
	end
	table.insert(history.undo, entry)
	return entry.forward
end

return Ops
