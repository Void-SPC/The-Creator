--!strict
-- Печать дерева логики в текстовый режим (блоки -> текст)

local Printer = {}

local function quote(s: string): string
	s = string.gsub(s, "\\", "\\\\")
	s = string.gsub(s, '"', '\\"')
	s = string.gsub(s, "\n", "\\n")
	return '"' .. s .. '"'
end

local PREC = {
	["or"] = 1, ["and"] = 2,
	["=="] = 3, ["~="] = 3, ["<"] = 3, [">"] = 3, ["<="] = 3, [">="] = 3,
	["+"] = 4, ["-"] = 4, ["*"] = 5, ["/"] = 5,
}

function Printer.print(script, nameOf: (string) -> string): string
	local out = {}
	local function emit(depth: number, s: string)
		table.insert(out, string.rep("  ", depth) .. s)
	end
	local expr
	local function args(list)
		local parts = {}
		for _, a in list do
			table.insert(parts, expr(a, 0))
		end
		return table.concat(parts, ", ")
	end
	function expr(e, parentPrec: number): string
		local k = e.kind
		if k == "num" then
			local v = e.value
			if v == math.floor(v) then
				return string.format("%d", v)
			end
			return tostring(v)
		elseif k == "str" then
			return quote(e.value)
		elseif k == "bool" then
			return if e.value then "true" else "false"
		elseif k == "ref" then
			return nameOf(e.ref)
		elseif k == "var" then
			return e.name
		elseif k == "cond" then
			return e.name .. "(" .. args(e.args) .. ")"
		elseif k == "not" then
			return "not " .. expr(e.e, 6)
		elseif k == "neg" then
			return "-" .. expr(e.e, 6)
		elseif k == "bin" then
			local p = PREC[e.op]
			local s = expr(e.a, p) .. " " .. e.op .. " " .. expr(e.b, p + 1)
			if p < parentPrec then
				return "(" .. s .. ")"
			end
			return s
		end
		return "nil"
	end
	local block
	function block(body, depth: number)
		for _, st in body do
			local k = st.kind
			if k == "call" then
				emit(depth, st.name .. "(" .. args(st.args) .. ")")
			elseif k == "local" then
				emit(depth, "local " .. st.name .. " = " .. expr(st.value, 0))
			elseif k == "assign" then
				emit(depth, st.name .. " = " .. expr(st.value, 0))
			elseif k == "for" then
				emit(depth, "for " .. st.var .. " = " .. expr(st.from, 0) .. ", " .. expr(st.to, 0) .. " do")
				block(st.body, depth + 1)
				emit(depth, "end")
			elseif k == "if" then
				for i, br in st.branches do
					emit(depth, (if i == 1 then "if " else "elseif ") .. expr(br.cond, 0) .. " then")
					block(br.body, depth + 1)
				end
				if st.elseBody then
					emit(depth, "else")
					block(st.elseBody, depth + 1)
				end
				emit(depth, "end")
			end
		end
	end
	for i, h in script.handlers do
		if i > 1 then
			table.insert(out, "")
		end
		emit(0, "on " .. h.event .. "(" .. args(h.args) .. ") do")
		block(h.body, 1)
		emit(0, "end")
	end
	return table.concat(out, "\n") .. (if #out > 0 then "\n" else "")
end

return Printer
