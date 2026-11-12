--!nonstrict
-- Разбор текстового режима логики карты. Синтаксис похож на Luau:
--
--   on DoorOpened(FrontDoor) do
--     PlayClip(Fox, "Появление")
--     Wait(1.5)
--     if LightIsOn(HallLamp) then
--       SetLight(HallLamp, false)
--     end
--   end
--
-- Результат: то же дерево, которое редактирует блочный режим

local Parser = {}

local KEYWORDS = {
	on = true, ["do"] = true, ["end"] = true, ["if"] = true, ["then"] = true,
	["elseif"] = true, ["else"] = true, ["for"] = true, ["local"] = true,
	["not"] = true, ["and"] = true, ["or"] = true, ["true"] = true, ["false"] = true,
}

Parser.KEYWORDS = KEYWORDS

local function err(line: number, col: number, msg: string)
	return { line = line, col = col, message = msg }
end

function Parser.lex(src: string)
	local tokens = {}
	local i, n = 1, #src
	local line, lineStart = 1, 1
	while i <= n do
		local c = string.sub(src, i, i)
		local col = i - lineStart + 1
		if c == "\n" then
			line += 1
			i += 1
			lineStart = i
		elseif c == " " or c == "\t" or c == "\r" then
			i += 1
		elseif string.sub(src, i, i + 1) == "--" then
			local e = string.find(src, "\n", i, true)
			i = if e then e else n + 1
		elseif string.match(c, "[%a_]") then
			local s, e = string.find(src, "^[%w_]+", i)
			local word = string.sub(src, s :: number, e :: number)
			table.insert(tokens, {
				t = if KEYWORDS[word] then word else "name",
				v = word, line = line, col = col, s = s, e = e,
			})
			i = (e :: number) + 1
		elseif string.match(c, "%d") or (c == "." and string.match(string.sub(src, i + 1, i + 1), "%d")) then
			local s, e = string.find(src, "^%d*%.?%d+", i)
			if not s then
				s, e = string.find(src, "^%d+", i)
			end
			local text = string.sub(src, s :: number, e :: number)
			table.insert(tokens, { t = "number", v = tonumber(text), line = line, col = col, s = s, e = e })
			i = (e :: number) + 1
		elseif c == '"' or c == "'" then
			local q = c
			local j = i + 1
			local buf = {}
			local closed = false
			while j <= n do
				local d = string.sub(src, j, j)
				if d == "\\" then
					local nx = string.sub(src, j + 1, j + 1)
					if nx == "n" then
						table.insert(buf, "\n")
					elseif nx == "t" then
						table.insert(buf, "\t")
					else
						table.insert(buf, nx)
					end
					j += 2
				elseif d == q then
					closed = true
					break
				elseif d == "\n" then
					break
				else
					table.insert(buf, d)
					j += 1
				end
			end
			if not closed then
				return nil, err(line, col, "строка не закрыта кавычкой")
			end
			table.insert(tokens, { t = "string", v = table.concat(buf), line = line, col = col, s = i, e = j })
			i = j + 1
		else
			local two = string.sub(src, i, i + 1)
			if two == "==" or two == "~=" or two == "<=" or two == ">=" then
				table.insert(tokens, { t = two, v = two, line = line, col = col, s = i, e = i + 1 })
				i += 2
			elseif string.find("(),=<>+-*/", c, 1, true) then
				table.insert(tokens, { t = c, v = c, line = line, col = col, s = i, e = i })
				i += 1
			else
				return nil, err(line, col, "непонятный символ «" .. c .. "»")
			end
		end
	end
	table.insert(tokens, { t = "eof", v = "", line = line, col = 1, s = n + 1, e = n + 1 })
	return tokens, nil
end

-- resolveName(name) -> id или nil. Имена локальных переменных разрешаются раньше
function Parser.parse(src: string, resolveName: (string) -> string?)
	local tokens, lexErr = Parser.lex(src)
	if not tokens then
		return nil, { lexErr }
	end
	local pos = 1
	local nextBid = 0
	local errors = {}
	local scopes: { { [string]: boolean } } = {}

	local function bid()
		nextBid += 1
		return "t" .. tostring(nextBid)
	end
	local function peek()
		return tokens[pos]
	end
	local function advance()
		local t = tokens[pos]
		pos += 1
		return t
	end
	local function fail(tok, msg)
		error({ parseError = err(tok.line, tok.col, msg) }, 0)
	end
	local function expect(t: string, what: string?)
		local tok = peek()
		if tok.t ~= t then
			fail(tok, "ожидалось «" .. (what or t) .. "», найдено «" .. (if tok.t == "eof" then "конец текста" else tostring(tok.v)) .. "»")
		end
		return advance()
	end
	local function isLocal(name: string)
		for i = #scopes, 1, -1 do
			if scopes[i][name] then
				return true
			end
		end
		return false
	end

	local parseExpr

	local function parseArgs()
		expect("(")
		local args = {}
		if peek().t ~= ")" then
			table.insert(args, parseExpr())
			while peek().t == "," do
				advance()
				table.insert(args, parseExpr())
			end
		end
		expect(")")
		return args
	end

	local function parsePrimary()
		local tok = peek()
		if tok.t == "number" then
			advance()
			return { kind = "num", value = tok.v, line = tok.line }
		elseif tok.t == "string" then
			advance()
			return { kind = "str", value = tok.v, line = tok.line }
		elseif tok.t == "true" or tok.t == "false" then
			advance()
			return { kind = "bool", value = tok.t == "true", line = tok.line }
		elseif tok.t == "(" then
			advance()
			local e = parseExpr()
			expect(")")
			return e
		elseif tok.t == "name" then
			advance()
			if peek().t == "(" then
				local args = parseArgs()
				return { kind = "cond", name = tok.v, args = args, line = tok.line }
			end
			if isLocal(tok.v) then
				return { kind = "var", name = tok.v, line = tok.line }
			end
			local id = resolveName(tok.v)
			if not id then
				table.insert(errors, err(tok.line, tok.col, "на карте нет объекта «" .. tok.v .. "»"))
				return { kind = "ref", ref = "", name = tok.v, line = tok.line }
			end
			return { kind = "ref", ref = id, name = tok.v, line = tok.line }
		end
		fail(tok, "ожидалось значение")
		return nil
	end

	local function parseUnary()
		local tok = peek()
		if tok.t == "not" then
			advance()
			return { kind = "not", e = parseUnary(), line = tok.line }
		elseif tok.t == "-" then
			advance()
			return { kind = "neg", e = parseUnary(), line = tok.line }
		end
		return parsePrimary()
	end

	local PREC = {
		["or"] = 1, ["and"] = 2,
		["=="] = 3, ["~="] = 3, ["<"] = 3, [">"] = 3, ["<="] = 3, [">="] = 3,
		["+"] = 4, ["-"] = 4, ["*"] = 5, ["/"] = 5,
	}

	local function parseBin(minPrec: number)
		local left = parseUnary()
		while true do
			local tok = peek()
			local p = PREC[tok.t]
			if not p or p < minPrec then
				break
			end
			advance()
			local right = parseBin(p + 1)
			left = { kind = "bin", op = tok.t, a = left, b = right, line = tok.line }
		end
		return left
	end

	function parseExpr()
		return parseBin(1)
	end

	local parseBlock

	local function parseStatement()
		local tok = peek()
		if tok.t == "if" then
			advance()
			local node = { kind = "if", branches = {}, elseBody = nil, line = tok.line, bid = bid() }
			local cond = parseExpr()
			expect("then")
			table.insert(node.branches, { cond = cond, body = parseBlock() })
			while peek().t == "elseif" do
				advance()
				local c = parseExpr()
				expect("then")
				table.insert(node.branches, { cond = c, body = parseBlock() })
			end
			if peek().t == "else" then
				advance()
				node.elseBody = parseBlock()
			end
			expect("end")
			return node
		elseif tok.t == "for" then
			advance()
			local var = expect("name", "имя переменной")
			expect("=")
			local from = parseExpr()
			expect(",")
			local to = parseExpr()
			expect("do")
			table.insert(scopes, { [var.v] = true })
			local body = parseBlock()
			table.remove(scopes)
			expect("end")
			return { kind = "for", var = var.v, from = from, to = to, body = body, line = tok.line, bid = bid() }
		elseif tok.t == "local" then
			advance()
			local name = expect("name", "имя переменной")
			expect("=")
			local value = parseExpr()
			scopes[#scopes][name.v] = true
			return { kind = "local", name = name.v, value = value, line = tok.line, bid = bid() }
		elseif tok.t == "name" then
			advance()
			if peek().t == "=" then
				advance()
				if not isLocal(tok.v) then
					fail(tok, "переменная «" .. tok.v .. "» не объявлена через local")
				end
				return { kind = "assign", name = tok.v, value = parseExpr(), line = tok.line, bid = bid() }
			end
			local args = parseArgs()
			return { kind = "call", name = tok.v, args = args, line = tok.line, bid = bid() }
		end
		fail(tok, "ожидалась команда")
		return nil
	end

	function parseBlock()
		local body = {}
		table.insert(scopes, {})
		while true do
			local t = peek().t
			if t == "end" or t == "else" or t == "elseif" or t == "eof" then
				break
			end
			table.insert(body, parseStatement())
		end
		table.remove(scopes)
		return body
	end

	local function parseHandler()
		local tok = expect("on", "on")
		local name = expect("name", "имя события")
		local args = parseArgs()
		expect("do")
		local body = parseBlock()
		expect("end")
		return { kind = "handler", event = name.v, args = args, body = body, line = tok.line, bid = bid() }
	end

	local ok, res = pcall(function()
		local script = { handlers = {} }
		while peek().t ~= "eof" do
			table.insert(script.handlers, parseHandler())
		end
		return script
	end)
	if not ok then
		if type(res) == "table" and res.parseError then
			table.insert(errors, 1, res.parseError)
			return nil, errors
		end
		error(res, 0)
	end
	if #errors > 0 then
		return res, errors
	end
	return res, nil
end

-- Переименование идентификаторов в исходнике без изменения остального текста
function Parser.renameIdentifiers(src: string, renames: { [string]: string }): string
	local tokens = Parser.lex(src)
	if not tokens then
		return src
	end
	local out = {}
	local last = 1
	for _, tok in tokens do
		if tok.t == "name" and renames[tok.v] then
			table.insert(out, string.sub(src, last, tok.s - 1))
			table.insert(out, renames[tok.v])
			last = tok.e + 1
		end
	end
	table.insert(out, string.sub(src, last))
	return table.concat(out)
end

return Parser
