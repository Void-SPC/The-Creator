--!strict
-- Иерархия деталей модели (суставы) и прямая кинематика
-- У каждой детали модели есть поза покоя (pos/rot относительно начала модели),
-- необязательный родитель и точка вращения pivot в координатах самой детали
-- Поворот родителя переносит всех потомков: голова поворачивается вместе с ушами

local MathX = require(script.Parent.MathX)

local Rig = {}

-- Порядок обхода: родители раньше детей
function Rig.order(model): { string }
	local parts = model.parts
	local out, state = {}, {}
	local function visit(id: string)
		if state[id] == 2 then
			return
		end
		if state[id] == 1 then
			return -- цикл; Format.validateObject не пропускает такие данные
		end
		state[id] = 1
		local p = parts[id]
		if p.parent and parts[p.parent] then
			visit(p.parent)
		end
		state[id] = 2
		table.insert(out, id)
	end
	local ids = {}
	for id in parts do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		visit(id)
	end
	return out
end

function Rig.rest(part)
	return MathX.tf(part.pos, part.rot)
end

-- Смещение из ключа: D = T(dp) * T(c) * R * T(-c)
function Rig.deltaTf(pivot, dpos, drot)
	local m = MathX.matFromEuler(drot or { 0, 0, 0 })
	local c = pivot or { 0, 0, 0 }
	local p = MathX.add(MathX.add(dpos or { 0, 0, 0 }, c), MathX.scale(MathX.matApply(m, c), -1))
	return { p = p, m = m }
end

-- Обратное к deltaTf: из матрицы смещения получаем dp и углы
function Rig.deltaFromTf(pivot, d)
	local c = pivot or { 0, 0, 0 }
	local dp = MathX.add(MathX.sub(d.p, c), MathX.matApply(d.m, c))
	return dp, MathX.eulerFromMat(d.m)
end

-- Мировые трансформы всех деталей для позы sample = {[partId] = {pos, rot}}
function Rig.pose(model, sample, modelTf)
	local parts = model.parts
	local world = {}
	sample = sample or {}
	for _, id in Rig.order(model) do
		local part = parts[id]
		local s = sample[id]
		local d = if s then Rig.deltaTf(part.pivot, s.pos, s.rot) else MathX.tfIdentity()
		local base
		if part.parent and world[part.parent] then
			local parentRest = Rig.rest(parts[part.parent])
			local localRest = MathX.toLocal(parentRest, Rig.rest(part))
			base = MathX.mul(world[part.parent], localRest)
		else
			base = MathX.mul(modelTf, Rig.rest(part))
		end
		world[id] = MathX.mul(base, d)
	end
	return world
end

-- Какое смещение ключа даст детали мировой трансформ desired при текущей позе родителей
function Rig.solveDelta(model, world, modelTf, partId: string, desired)
	local part = model.parts[partId]
	local base
	if part.parent and world[part.parent] then
		local parentRest = Rig.rest(model.parts[part.parent])
		local localRest = MathX.toLocal(parentRest, Rig.rest(part))
		base = MathX.mul(world[part.parent], localRest)
	else
		base = MathX.mul(modelTf, Rig.rest(part))
	end
	local d = MathX.toLocal(base, desired)
	return Rig.deltaFromTf(part.pivot, d)
end

-- Установка родителя с защитой от циклов
function Rig.setParent(model, partId: string, parentId: string?): boolean
	if parentId == nil then
		model.parts[partId].parent = nil
		return true
	end
	if parentId == partId or model.parts[parentId] == nil then
		return false
	end
	local cur: string? = parentId
	while cur do
		if cur == partId then
			return false
		end
		cur = model.parts[cur].parent
	end
	model.parts[partId].parent = parentId
	return true
end

-- Удаление детали: дети переходят к её родителю, клипы не трогаем
function Rig.removePart(model, partId: string)
	local removed = model.parts[partId]
	if not removed then
		return
	end
	for _, p in model.parts do
		if p.parent == partId then
			p.parent = removed.parent
		end
	end
	model.parts[partId] = nil
end

return Rig
