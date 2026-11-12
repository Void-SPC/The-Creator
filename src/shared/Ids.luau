--!strict
-- Постоянные ID объектов проекта
-- ID выдаются из счётчика проекта и никогда не переиспользуются
-- Имена (отображаемое и латинское) можно менять, ссылки хранят только ID

local Ids = {}

local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"

local function base36(n: number): string
	if n == 0 then
		return "0"
	end
	local s = ""
	while n > 0 do
		local d = n % 36
		s = string.sub(DIGITS, d + 1, d + 1) .. s
		n = n // 36
	end
	return s
end

function Ids.alloc(project, prefix: string): string
	local n = project.nextId or 1
	project.nextId = n + 1
	return prefix .. "_" .. base36(n)
end

-- Латинское имя: только буквы, цифры, подчёркивание; начинается с буквы
function Ids.isValidLatin(s: string): boolean
	return string.match(s, "^[A-Za-z][A-Za-z0-9_]*$") ~= nil and #s <= 40
end

function Ids.latinTaken(project, latin: string, exceptId: string?): boolean
	for id, obj in project.map.objects do
		if id ~= exceptId and obj.latin == latin then
			return true
		end
	end
	return false
end

-- Предлагает свободное латинское имя: Closet01, Closet02, ...
function Ids.suggestLatin(project, base: string, exceptId: string?): string
	local clean = string.gsub(base, "[^A-Za-z0-9_]", "")
	if clean == "" or not string.match(clean, "^[A-Za-z]") then
		clean = "Obj" .. clean
	end
	clean = string.gsub(clean, "%d+$", "")
	if clean == "" then
		clean = "Obj"
	end
	clean = string.sub(clean, 1, 34)
	for i = 1, 9999 do
		local candidate = string.format("%s%02d", clean, i)
		if not Ids.latinTaken(project, candidate, exceptId) then
			return candidate
		end
	end
	return clean .. tostring(os.time())
end

-- Обходит значение и вызывает fn для каждой ссылки на объект карты
-- Ссылка в данных: таблица {ref = "o_xx"}
function Ids.forEachRef(value: any, fn: (holder: any) -> ())
	if type(value) ~= "table" then
		return
	end
	if type(value.ref) == "string" then
		fn(value)
	end
	for _, v in value do
		if type(v) == "table" then
			Ids.forEachRef(v, fn)
		end
	end
end

return Ids
