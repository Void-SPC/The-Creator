-- Запуск тестов чистого ядра: python3 tools/bundle_tests.py build/tests.luau && luau build/tests.luau

local T = {}
local passed, failed = 0, 0
local failures = {}
local currentSuite = ""

function T.suite(name: string)
	currentSuite = name
end

function T.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		table.insert(failures, currentSuite .. " / " .. name .. "\n    " .. tostring(err))
	end
end

local function show(v: any): string
	if type(v) == "table" then
		local parts = {}
		for k, x in v do
			table.insert(parts, tostring(k) .. "=" .. show(x))
		end
		table.sort(parts)
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end
T.show = show

function T.eq(a: any, b: any, msg: string?)
	if a ~= b then
		error((msg or "eq") .. ": expected " .. show(b) .. ", got " .. show(a), 2)
	end
end

function T.ok(v: any, msg: string?)
	if not v then
		error(msg or "expected truthy", 2)
	end
end

function T.near(a: number, b: number, eps: number?, msg: string?)
	if math.abs(a - b) > (eps or 1e-3) then
		error((msg or "near") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
	end
end

function T.vnear(a, b, eps: number?, msg: string?)
	for i = 1, 3 do
		if math.abs(a[i] - b[i]) > (eps or 1e-3) then
			error((msg or "vnear") .. ": expected " .. show(b) .. ", got " .. show(a), 2)
		end
	end
end

local specs = {
	"MathSpec", "AnimSpec", "FormatSpec", "OpsSpec", "ModelSpec", "LogicSpec",
	"ClosetSpec", "StoreSpec", "UiTextSpec", "ScenarioSpec", "OfficeSpec",
}
for _, name in specs do
	local spec = require((script.Parent :: any)[name])
	spec(T)
end

print(string.format("passed %d, failed %d", passed, failed))
for _, f in failures do
	print("FAIL " .. f)
end
if failed > 0 then
	error("tests failed")
end
return nil
