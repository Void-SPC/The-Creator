--!nonstrict
-- Фильтрация авторского текста штатными средствами Roblox
-- Всё, что увидят другие игроки (надписи, реплики, текст в Say, название карты),
-- проходит TextService. Если фильтр недоступен, текст не показывается и карта не публикуется

local TextService = game:GetService("TextService")

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Util = require(Shared.Util)
local Logic = require(Shared.Logic)

local FilterService = {}

local cache: { [string]: string } = {}

function FilterService.filter(text: string, fromUserId: number): (boolean, string)
	if text == "" then
		return true, ""
	end
	local key = tostring(fromUserId) .. "\0" .. text
	if cache[key] then
		return true, cache[key]
	end
	local ok, res = pcall(function()
		local result = TextService:FilterStringAsync(text, fromUserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return false, tostring(res)
	end
	cache[key] = res
	return true, res
end

-- Готовит снимок карты для запуска другими игроками:
-- логика компилируется и проверяется, тексты фильтруются, исходник логики не входит в снимок
-- Возвращает ok, snapshot | false, { kind, errors | message }
function FilterService.prepareSnapshot(project, userId: number)
	local script, errors = Logic.compile(project)
	if not script or #errors > 0 then
		return false, { kind = "logic", errors = errors }
	end
	local snap = Util.deepCopy(project)
	snap.logic.mode = "blocks"
	snap.logic.blocks = Util.deepCopy(script)
	snap.logic.text = { source = "", refs = {} }

	local failed: string? = nil
	local function f(text: string): string
		local ok, res = FilterService.filter(text, userId)
		if not ok then
			failed = res
			return ""
		end
		return res
	end

	snap.meta.name = f(snap.meta.name)
	for _, obj in snap.map.objects do
		if obj.label then
			obj.label.text = f(obj.label.text)
		end
		if obj.role and obj.role.type == "npc" then
			for _, line in obj.role.lines do
				line.text = f(line.text)
			end
		end
	end
	-- текстовые аргументы команд (Say и т.п.)
	local Commands = Logic.Commands
	local function walk(node)
		if type(node) ~= "table" then
			return
		end
		if node.kind == "call" then
			local def = Commands.actions[node.name]
			if def then
				for i, a in node.args do
					local spec = def.args[i]
					if spec and spec.type == "text" and a.kind == "str" then
						a.value = f(a.value)
					end
				end
			end
		end
		for _, v in node do
			if type(v) == "table" then
				walk(v)
			end
		end
	end
	walk(snap.logic.blocks)
	if failed then
		return false, { kind = "filter", message = failed }
	end
	return true, snap
end

return FilterService
