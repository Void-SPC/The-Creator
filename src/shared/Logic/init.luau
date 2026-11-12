--!nonstrict
-- Логика карты: общий вход для блоков и текста

local Parser = require(script.Parser)
local Printer = require(script.Printer)
local Validator = require(script.Validator)
local Commands = require(script.Commands)

local Logic = {}

Logic.Parser = Parser
Logic.Printer = Printer
Logic.Validator = Validator
Logic.Commands = Commands
Logic.Interpreter = require(script.Interpreter)

-- Латинское имя объекта не должно совпадать с командой или ключевым словом
function Logic.isReservedName(name: string): boolean
	return Parser.KEYWORDS[name] ~= nil
		or Commands.actions[name] ~= nil
		or Commands.conditions[name] ~= nil
		or Commands.events[name] ~= nil
end

function Logic.nameResolver(project)
	local byLatin = {}
	for id, obj in project.map.objects do
		if obj.latin then
			byLatin[obj.latin] = id
		end
	end
	return function(name: string): string?
		return byLatin[name]
	end
end

function Logic.nameOf(project)
	return function(id: string): string
		local obj = project.map.objects[id]
		if obj and obj.latin then
			return obj.latin
		end
		return "Missing_" .. string.gsub(id, "[^%w]", "_")
	end
end

-- Текст хранится как есть, плюс таблица «имя -> ID» на момент сохранения
-- Если объект переименовали, имя в тексте обновится; если удалили, проверка покажет строку
function Logic.refreshText(project): boolean
	local text = project.logic.text
	local renames = {}
	local changed = false
	local newRefs = {}
	for name, id in text.refs or {} do
		local obj = project.map.objects[id]
		if obj and obj.latin and obj.latin ~= name then
			renames[name] = obj.latin
			newRefs[obj.latin] = id
			changed = true
		else
			newRefs[name] = id
		end
	end
	if changed then
		text.source = Parser.renameIdentifiers(text.source, renames)
		text.refs = newRefs
	end
	return changed
end

-- Собирает таблицу ссылок для сохранения текста
function Logic.collectRefs(tree)
	local refs = {}
	local function walk(v)
		if type(v) ~= "table" then
			return
		end
		if v.kind == "ref" and v.name and v.ref ~= "" then
			refs[v.name] = v.ref
		end
		for _, x in v do
			if type(x) == "table" then
				walk(x)
			end
		end
	end
	walk(tree)
	return refs
end

-- Возвращает дерево и список ошибок (пустой, если всё в порядке)
function Logic.compile(project)
	local lg = project.logic
	local tree
	if lg.mode == "text" then
		local parsed, parseErrors = Parser.parse(lg.text.source, Logic.nameResolver(project))
		if parseErrors then
			return parsed, parseErrors
		end
		tree = parsed
	else
		tree = lg.blocks
	end
	local errors = Validator.validate(tree, project)
	return tree, errors
end

function Logic.toText(project, tree): string
	return Printer.print(tree, Logic.nameOf(project))
end

-- Объекты и роли, которые ссылаются на удалённые цели
function Logic.brokenBindings(project)
	local out = {}
	local objects = project.map.objects
	for id, obj in objects do
		local role = obj.role
		if role then
			for _, field in { "zone", "anchor", "next" } do
				local r = role[field]
				if type(r) == "table" and r.ref and not objects[r.ref] then
					table.insert(out, { objectId = id, field = field, ref = r.ref })
				end
			end
		end
	end
	local tree, errors = Logic.compile(project)
	if tree then
		for _, e in errors do
			if e.broken then
				table.insert(out, { logic = true, line = e.line, bid = e.bid, message = e.message, ref = e.ref })
			end
		end
	end
	return out
end

return Logic
