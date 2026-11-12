--!nonstrict
-- Исполнитель логики карты. Работает только с деревом, которое прошло Validator,
-- и только через команды хоста (сервер реализует их для объектов текущей карты)
-- Каждый запуск обработчика — отдельный поток с лимитом операций и времени жизни

local Interpreter = {}

Interpreter.DEFAULT_LIMITS = {
	opsPerRun = 5000, -- операций на один запуск обработчика
	opsPerSecond = 40000, -- операций всех потоков за секунду
	threads = 32, -- одновременно живущих потоков
	runSeconds = 300, -- максимальное время жизни потока
	maxWait = 60, -- максимальная пауза одной командой Wait
	forIterations = 1000,
}

local RuntimeError = {}
RuntimeError.__index = RuntimeError

local function rtError(node, msg: string)
	error(setmetatable({ line = node and node.line, bid = node and node.bid, message = msg }, RuntimeError), 0)
end

local function sameValue(a, b): boolean
	if type(a) == "table" and type(b) == "table" then
		return a.ref == b.ref
	end
	return a == b
end

function Interpreter.new(tree, host, limits)
	local L = {}
	for k, v in Interpreter.DEFAULT_LIMITS do
		L[k] = (limits and limits[k]) or v
	end
	local rt = {
		tree = tree,
		host = host,
		limits = L,
		threads = {},
		secondStart = 0,
		secondOps = 0,
		stopped = false,
	}

	local function chargeGlobal(node)
		local now = host.now()
		if now - rt.secondStart >= 1 then
			rt.secondStart = now
			rt.secondOps = 0
		end
		rt.secondOps += 1
		if rt.secondOps > L.opsPerSecond then
			rtError(node, "логика выполняет слишком много операций в секунду")
		end
	end

	local function run(thread, handler, eventArgs)
		local env: { [string]: any } = {}
		local function charge(node)
			thread.ops += 1
			if thread.ops > L.opsPerRun then
				rtError(node, "превышен лимит операций сценария")
			end
			chargeGlobal(node)
		end

		local eval
		local function evalArgs(owner, list)
			local out = table.create(#list)
			for i, a in list do
				out[i] = eval(owner, a)
			end
			return out
		end
		function eval(owner, e)
			charge(owner)
			local k = e.kind
			if k == "num" or k == "str" or k == "bool" then
				return e.value
			elseif k == "ref" then
				return { ref = e.ref }
			elseif k == "var" then
				local v = env[e.name]
				if v == nil then
					rtError(owner, "переменная «" .. e.name .. "» не задана")
				end
				return v
			elseif k == "cond" then
				local ok, res = pcall(host.condition, e.name, evalArgs(owner, e.args), eventArgs)
				if not ok then
					rtError(owner, tostring(res))
				end
				return res == true
			elseif k == "not" then
				return not eval(owner, e.e)
			elseif k == "neg" then
				local v = eval(owner, e.e)
				if type(v) ~= "number" then
					rtError(owner, "минус применим только к числу")
				end
				return -v
			elseif k == "bin" then
				local op = e.op
				if op == "and" then
					return eval(owner, e.a) and eval(owner, e.b)
				elseif op == "or" then
					return eval(owner, e.a) or eval(owner, e.b)
				end
				local a, b = eval(owner, e.a), eval(owner, e.b)
				if op == "==" then
					return sameValue(a, b)
				elseif op == "~=" then
					return not sameValue(a, b)
				end
				if type(a) ~= "number" or type(b) ~= "number" then
					rtError(owner, "операция «" .. op .. "» работает только с числами")
				end
				if op == "+" then
					return a + b
				elseif op == "-" then
					return a - b
				elseif op == "*" then
					return a * b
				elseif op == "/" then
					if b == 0 then
						rtError(owner, "деление на ноль")
					end
					return a / b
				elseif op == "<" then
					return a < b
				elseif op == ">" then
					return a > b
				elseif op == "<=" then
					return a <= b
				elseif op == ">=" then
					return a >= b
				end
			end
			rtError(owner, "неизвестное выражение")
			return nil
		end

		local exec
		function exec(body)
			for _, st in body do
				if rt.stopped or thread.dead then
					return
				end
				charge(st)
				local k = st.kind
				if k == "call" then
					local args = evalArgs(st, st.args)
					if st.name == "Wait" then
						local s = args[1]
						if type(s) ~= "number" then
							rtError(st, "Wait ждёт число секунд")
						end
						s = math.clamp(s, 0, L.maxWait)
						thread.wakeAt = host.now() + s
						thread.node = st
						coroutine.yield()
						if host.now() - thread.startedAt > L.runSeconds then
							rtError(st, "сценарий работает слишком долго")
						end
					else
						local ok, res = pcall(host.action, st.name, args, st, eventArgs)
						if not ok then
							if getmetatable(res :: any) == RuntimeError then
								error(res, 0)
							end
							rtError(st, tostring(res))
						end
					end
				elseif k == "if" then
					local done = false
					for _, br in st.branches do
						if eval(st, br.cond) then
							exec(br.body)
							done = true
							break
						end
					end
					if not done and st.elseBody then
						exec(st.elseBody)
					end
				elseif k == "for" then
					local from, to = eval(st, st.from), eval(st, st.to)
					if type(from) ~= "number" or type(to) ~= "number" then
						rtError(st, "границы цикла должны быть числами")
					end
					if to - from + 1 > L.forIterations then
						rtError(st, "слишком много повторов в цикле")
					end
					for i = math.floor(from), math.floor(to) do
						env[st.var] = i
						exec(st.body)
					end
				elseif k == "local" or k == "assign" then
					env[st.name] = eval(st, st.value)
				end
			end
		end
		exec(handler.body)
	end

	local function startThread(handler, eventArgs)
		local alive = 0
		for _, t in rt.threads do
			if not t.dead then
				alive += 1
			end
		end
		if alive >= L.threads then
			host.onError({ line = handler.line, bid = handler.bid, message = "слишком много одновременно работающих сценариев" })
			return
		end
		local thread = { ops = 0, startedAt = host.now(), wakeAt = nil, dead = false, handler = handler, node = nil }
		thread.co = coroutine.create(function()
			run(thread, handler, eventArgs)
		end)
		table.insert(rt.threads, thread)
		rt.resume(thread)
	end

	function rt.resume(thread)
		thread.wakeAt = nil
		local ok, res = coroutine.resume(thread.co)
		if not ok then
			thread.dead = true
			if getmetatable(res :: any) == RuntimeError then
				host.onError(res)
			else
				host.onError({ line = thread.handler.line, bid = thread.handler.bid, message = "внутренняя ошибка: " .. tostring(res) })
			end
		elseif coroutine.status(thread.co) == "dead" then
			thread.dead = true
		end
	end

	function rt.dispatch(event: string, args: { any })
		if rt.stopped then
			return 0
		end
		local started = 0
		for _, h in rt.tree.handlers do
			if h.event == event then
				local match = true
				for i, a in h.args do
					local v = args[i]
					if a.kind == "ref" then
						if type(v) ~= "table" or v.ref ~= a.ref then
							match = false
							break
						end
					elseif a.kind == "str" then
						if v ~= a.value then
							match = false
							break
						end
					end
				end
				if match then
					started += 1
					startThread(h, args)
				end
			end
		end
		return started
	end

	function rt.update()
		if rt.stopped then
			return
		end
		local now = host.now()
		local i = 1
		while i <= #rt.threads do
			local t = rt.threads[i]
			if t.dead then
				table.remove(rt.threads, i)
			else
				if t.wakeAt and now >= t.wakeAt then
					rt.resume(t)
				end
				i += 1
			end
		end
	end

	function rt.stop()
		rt.stopped = true
		for _, t in rt.threads do
			t.dead = true
		end
		table.clear(rt.threads)
	end

	function rt.activeCount(): number
		local n = 0
		for _, t in rt.threads do
			if not t.dead then
				n += 1
			end
		end
		return n
	end

	return rt
end

return Interpreter
