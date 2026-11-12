--!nonstrict
-- Состояние редактора на клиенте: локальная копия проекта, отмена и повтор,
-- отправка правок на сервер и обработка отказов

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local Ops = require(Shared.Ops)
local Remotes = require(Shared.Roblox.Remotes)

local State = {}
State.__index = State

local function signal()
	local handlers = {}
	return {
		connect = function(fn)
			table.insert(handlers, fn)
			return function()
				local i = table.find(handlers, fn)
				if i then
					table.remove(handlers, i)
				end
			end
		end,
		fire = function(...)
			for _, fn in table.clone(handlers) do
				task.spawn(fn, ...)
			end
		end,
	}
end
State.signal = signal

-- ID объектов, которых касается операция
function State.touchedIds(op, out)
	out = out or {}
	if op.op == "batch" then
		for _, o in op.ops do
			State.touchedIds(o, out)
		end
	elseif op.op == "add" then
		out[op.obj.id] = true
	elseif op.op == "remove" or op.op == "set" then
		out[op.id] = true
	end
	return out
end

function State.new(project, readOnly: boolean)
	local self = setmetatable({}, State)
	self.project = project
	self.readOnly = readOnly
	self.history = Ops.newHistory(150)
	self.seq = 0
	self.changed = signal() -- (ids, op)
	self.resynced = signal()
	self.status = signal() -- (state)
	self.rejected = signal() -- (reason)
	self.connections = {}
	table.insert(self.connections, Remotes.event("EditAck").OnClientEvent:Connect(function(seq, ok, reason, serverProject)
		if ok then
			return
		end
		self.rejected.fire(reason)
		if serverProject then
			-- сервер не принял правку: берём его копию, историю сбрасываем
			self.project = serverProject
			self.history = Ops.newHistory(150)
			if reason == "readonly" then
				self.readOnly = true
			end
			self.resynced.fire()
		end
	end))
	table.insert(self.connections, Remotes.event("SaveStatus").OnClientEvent:Connect(function(state)
		if state == "readonly" then
			self.readOnly = true
		elseif state == "saved" then
			self.readOnly = false
		end
		self.status.fire(state)
	end))
	return self
end

function State:destroy()
	for _, c in self.connections do
		c:Disconnect()
	end
end

-- Применяет правку локально и отправляет на сервер
function State:apply(op, record: boolean?): (boolean, any)
	if self.readOnly then
		return false, "readonly"
	end
	local ok, inv = Ops.apply(self.project, op, { validate = true })
	if not ok then
		return false, inv
	end
	if record ~= false then
		Ops.record(self.history, inv, op)
	end
	self.seq += 1
	Remotes.event("EditOps"):FireServer(self.seq, op)
	self.changed.fire(State.touchedIds(op), op)
	return true, inv
end

function State:undo(): boolean
	local op = Ops.popUndo(self.history)
	if not op then
		return false
	end
	local ok = self:apply(op, false)
	return ok
end

function State:redo(): boolean
	local op = Ops.popRedo(self.history)
	if not op then
		return false
	end
	local ok = self:apply(op, false)
	return ok
end

function State:obj(id: string)
	return self.project.map.objects[id]
end

return State
