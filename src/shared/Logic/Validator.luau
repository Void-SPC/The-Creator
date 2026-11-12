--!strict
-- Проверка логики карты. Одна и та же проверка работает в редакторе (подсветка
-- блока или строки) и на сервере перед запуском. Сервер не исполняет сценарий,
-- который ссылается на чужие объекты или неизвестные команды

local Commands = require(script.Parent.Commands)

local Validator = {}

Validator.LIMITS = { handlers = 100, statements = 2000, depth = 12, textLen = 600 }

local function clipNames(obj)
	local names = {}
	if obj and obj.kind == "model" then
		for _, clip in obj.model.clips do
			names[clip.name] = true
		end
	end
	return names
end

function Validator.validate(script, project)
	local errors = {}
	local objects = project.map.objects
	local statements = 0

	local function report(node, msg: string, extra: { [string]: any }?)
		local e = { line = node and node.line, bid = node and node.bid, message = msg }
		if extra then
			for k, v in extra do
				e[k] = v
			end
		end
		table.insert(errors, e)
	end

	if type(script) ~= "table" or type(script.handlers) ~= "table" then
		report(nil, "логика повреждена")
		return errors
	end
	if #script.handlers > Validator.LIMITS.handlers then
		report(nil, "слишком много событий в логике")
	end

	local function checkArgs(owner, def, args, title: string)
		if type(args) ~= "table" then
			report(owner, title .. ": неверные аргументы")
			return
		end
		local minArgs = Commands.minArgs(def)
		if #args < minArgs or #args > #def.args then
			report(owner, string.format("%s: нужно аргументов %d–%d, указано %d", title, minArgs, #def.args, #args))
			return
		end
		local modelObj = nil
		for i, a in args do
			local spec = def.args[i]
			local t = spec.type
			local check = Commands.TARGET_TYPES[t]
			if check then
				if a.kind ~= "ref" then
					report(a.line and a or owner, string.format("%s: «%s» должен быть объектом карты", title, spec.title))
				else
					local obj = objects[a.ref]
					if not obj then
						report(owner, string.format("%s: цель «%s» удалена, нужна новая привязка", title, spec.title), {
							broken = true, argIndex = i, ref = a.ref,
						})
					elseif not check(obj) then
						report(owner, string.format("%s: «%s» не подходит для поля «%s»", title, obj.name, spec.title))
					elseif t == "model" and not modelObj then
						modelObj = obj
					end
				end
			elseif t == "clip" then
				if a.kind ~= "str" then
					report(owner, title .. ": имя клипа должно быть строкой")
				elseif modelObj and not clipNames(modelObj)[a.value] then
					report(owner, string.format("%s: у модели «%s» нет клипа «%s»", title, modelObj.name, a.value))
				end
			elseif t == "text" or t == "string" then
				if a.kind ~= "str" then
					report(owner, string.format("%s: «%s» должен быть текстом в кавычках", title, spec.title))
				elseif utf8.len(a.value) == nil or (utf8.len(a.value) :: number) > Validator.LIMITS.textLen then
					report(owner, title .. ": текст слишком длинный")
				end
			elseif t == "number" then
				if a.kind == "num" then
					if (spec.min and a.value < spec.min) or (spec.max and a.value > spec.max) then
						report(owner, string.format("%s: «%s» вне диапазона %s–%s", title, spec.title, tostring(spec.min), tostring(spec.max)))
					end
				elseif a.kind == "str" or a.kind == "bool" or a.kind == "ref" then
					report(owner, string.format("%s: «%s» должно быть числом", title, spec.title))
				end
			elseif t == "bool" then
				if a.kind == "num" or a.kind == "str" or a.kind == "ref" then
					report(owner, string.format("%s: «%s» должно быть true или false", title, spec.title))
				end
			end
		end
	end

	local checkExpr
	function checkExpr(owner, e, depth: number)
		if type(e) ~= "table" then
			report(owner, "повреждённое выражение")
			return
		end
		if depth > 20 then
			report(owner, "слишком сложное выражение")
			return
		end
		local k = e.kind
		if k == "cond" then
			local def = Commands.conditions[e.name]
			if not def then
				report(owner, "неизвестное условие «" .. tostring(e.name) .. "»")
				return
			end
			checkArgs(owner, def, e.args, def.title)
		elseif k == "not" or k == "neg" then
			checkExpr(owner, e.e, depth + 1)
		elseif k == "bin" then
			checkExpr(owner, e.a, depth + 1)
			checkExpr(owner, e.b, depth + 1)
		elseif k == "ref" then
			if not objects[e.ref] then
				report(owner, "объект удалён, нужна новая привязка", { broken = true, ref = e.ref })
			end
		elseif k ~= "num" and k ~= "str" and k ~= "bool" and k ~= "var" then
			report(owner, "неизвестное выражение")
		end
	end

	local checkBody
	function checkBody(body, depth: number)
		if type(body) ~= "table" then
			return
		end
		if depth > Validator.LIMITS.depth then
			report(nil, "слишком глубокая вложенность")
			return
		end
		for _, st in body do
			statements += 1
			local k = st.kind
			if k == "call" then
				local def = Commands.actions[st.name]
				if not def then
					report(st, "неизвестная команда «" .. tostring(st.name) .. "»")
				else
					checkArgs(st, def, st.args, def.title)
					for _, a in st.args do
						if a.kind ~= "ref" then
							checkExpr(st, a, 0)
						end
					end
				end
			elseif k == "if" then
				for _, br in st.branches or {} do
					checkExpr(st, br.cond, 0)
					checkBody(br.body, depth + 1)
				end
				if st.elseBody then
					checkBody(st.elseBody, depth + 1)
				end
			elseif k == "for" then
				checkExpr(st, st.from, 0)
				checkExpr(st, st.to, 0)
				checkBody(st.body, depth + 1)
			elseif k == "local" or k == "assign" then
				checkExpr(st, st.value, 0)
			else
				report(st, "неизвестный блок")
			end
		end
	end

	for _, h in script.handlers do
		local def = Commands.events[h.event]
		if not def then
			report(h, "неизвестное событие «" .. tostring(h.event) .. "»")
		else
			checkArgs(h, def, h.args, def.title)
		end
		checkBody(h.body, 1)
	end
	if statements > Validator.LIMITS.statements then
		report(nil, "слишком много блоков в логике")
	end
	return errors
end

return Validator
