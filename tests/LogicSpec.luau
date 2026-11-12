local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Logic = require(Shared.Logic)
local Demo = require(Shared.Demo)
local Ops = require(Shared.Ops)
local Util = require(Shared.Util)

return function(T)
	T.suite("Logic")

	T.test("demo compiles in both modes to the same tree", function()
		local p = Demo.build("p", 1)
		local blocks, e1 = Logic.compile(p)
		T.eq(#e1, 0, "blocks errors " .. T.show(e1))
		p.logic.mode = "text"
		local text, e2 = Logic.compile(p)
		T.eq(#e2, 0, "text errors " .. T.show(e2))
		T.eq(#blocks.handlers, #text.handlers)
		-- блоки -> текст -> блоки дают ту же структуру
		local printed = Logic.toText(p, blocks)
		local again = Logic.Parser.parse(printed, Logic.nameResolver(p))
		T.eq(Logic.toText(p, again), printed)
	end)

	T.test("parse error points to the line", function()
		local p = Demo.build("p", 1)
		local _, errs = Logic.Parser.parse("on DoorOpened(FrontDoor) do\n  Wait(1\nend\n", Logic.nameResolver(p))
		T.ok(errs and #errs > 0)
		T.eq(errs[1].line, 3)
	end)

	T.test("unknown command and wrong target type are reported by line", function()
		local p = Demo.build("p", 1)
		p.logic.mode = "text"
		p.logic.text.source = "on DoorOpened(FrontDoor) do\n  Explode(Fox)\n  SetLight(Fox, false)\nend\n"
		local _, errs = Logic.compile(p)
		T.eq(#errs, 2)
		T.eq(errs[1].line, 2)
		T.eq(errs[2].line, 3)
	end)

	T.test("missing clip is reported", function()
		local p = Demo.build("p", 1)
		p.logic.mode = "text"
		p.logic.text.source = 'on MapStarted() do\n  PlayClip(Fox, "Танец")\nend\n'
		local _, errs = Logic.compile(p)
		T.eq(#errs, 1)
		T.ok(string.find(errs[1].message, "Танец", 1, true) ~= nil)
	end)

	T.test("deleted target is shown as broken binding in blocks", function()
		local p = Demo.build("p", 1)
		local lampId = Demo.idOf(p, "HallLamp") :: string
		T.ok(Ops.apply(p, { op = "remove", id = lampId }))
		local broken = Logic.brokenBindings(p)
		local logicBroken = 0
		for _, b in broken do
			if b.logic then
				logicBroken += 1
				T.ok(b.bid ~= nil, "block id is known")
				T.eq(b.ref, lampId)
			end
		end
		T.eq(logicBroken, 2, "two SetLight blocks need new target")
		-- остальная логика не пострадала: дерево цело
		T.eq(#p.logic.blocks.handlers, 5)
	end)

	T.test("renaming keeps text references", function()
		local p = Demo.build("p", 1)
		p.logic.mode = "text"
		local lampId = Demo.idOf(p, "HallLamp") :: string
		T.ok(Ops.apply(p, { op = "set", id = lampId, path = { "latin" }, value = "KitchenLamp" }))
		T.ok(Logic.refreshText(p))
		T.ok(string.find(p.logic.text.source, "KitchenLamp", 1, true) ~= nil)
		T.ok(string.find(p.logic.text.source, "HallLamp", 1, true) == nil)
		local _, errs = Logic.compile(p)
		T.eq(#errs, 0)
	end)

	-- Хост-заглушка: время задаётся вручную, действия записываются
	local function fakeHost(p)
		local h = { t = 0, log = {}, errors = {}, light = {} }
		h.now = function()
			return h.t
		end
		h.action = function(name, args)
			local parts = { name }
			for _, a in args do
				if type(a) == "table" then
					local o = p.map.objects[a.ref]
					table.insert(parts, o and o.latin or "?")
				else
					table.insert(parts, tostring(a))
				end
			end
			table.insert(h.log, table.concat(parts, " "))
			if name == "SetLight" then
				h.light[args[1].ref] = args[2]
			end
		end
		h.condition = function(name, args)
			if name == "LightIsOn" then
				return h.light[args[1].ref] ~= false
			end
			return false
		end
		h.onError = function(e)
			table.insert(h.errors, e)
		end
		return h
	end

	T.test("demo scene runs: door, creature, lamp, escape", function()
		local p = Demo.build("p", 1)
		local script = Logic.compile(p)
		local host = fakeHost(p)
		local rt = Logic.Interpreter.new(script, host)
		local door = Demo.idOf(p, "FrontDoor")
		local fox = Demo.idOf(p, "Fox")
		local noise = Demo.idOf(p, "NoisePoint")
		local escape = Demo.idOf(p, "EscapePoint")
		T.eq(rt.dispatch("DoorOpened", { { ref = door } }), 1)
		T.eq(host.log[1], "SetVisible Fox true")
		T.eq(host.log[2], "PlayClip Fox Появление")
		T.eq(#host.log, 2, "waits before moving")
		host.t = 1.5
		rt.update()
		T.eq(host.log[3], "MoveTo Fox NoisePoint Бег 14")
		rt.dispatch("Arrived", { { ref = fox }, { ref = noise } })
		T.eq(host.log[5], "PlayClip Fox Скример")
		rt.dispatch("MarkerReached", { { ref = fox }, "Скример", "Погасить" })
		T.eq(host.log[6], "SetLight HallLamp false")
		rt.dispatch("ClipFinished", { { ref = fox }, "Скример" })
		T.eq(host.log[7], "MoveTo Fox EscapePoint Бег 22")
		rt.dispatch("Arrived", { { ref = fox }, { ref = escape } })
		T.eq(host.log[8], "SetVisible Fox false")
		host.t = 5
		rt.update()
		T.eq(host.log[9], "SetLight HallLamp true")
		T.eq(#host.errors, 0)
		-- событие для другой двери не запускает обработчик
		T.eq(rt.dispatch("DoorOpened", { { ref = "o_unknown" } }), 0)
	end)

	T.test("operation limit stops runaway scripts", function()
		local p = Demo.build("p", 1)
		p.logic.mode = "text"
		p.logic.text.source = [[
on MapStarted() do
  local n = 0
  for i = 1, 1000 do
    for j = 1, 1000 do
      n = n + 1
    end
  end
end
]]
		local script, errs = Logic.compile(p)
		T.eq(#errs, 0)
		local host = fakeHost(p)
		local rt = Logic.Interpreter.new(script, host)
		rt.dispatch("MapStarted", {})
		T.eq(#host.errors, 1)
		T.eq(host.errors[1].line, 5, "error points to the line")
		T.eq(rt.activeCount(), 0)
	end)

	T.test("runtime error keeps other handlers alive", function()
		local p = Demo.build("p", 1)
		p.logic.mode = "text"
		p.logic.text.source = 'on MapStarted() do\n  local x = 1 / 0\nend\non MapStarted() do\n  Wait(1)\n  Say(Fox, "Ещё жив", 2)\nend\n'
		local script = Logic.compile(p)
		local host = fakeHost(p)
		local rt = Logic.Interpreter.new(script, host)
		rt.dispatch("MapStarted", {})
		T.eq(#host.errors, 1)
		T.eq(host.errors[1].line, 2)
		host.t = 2
		rt.update()
		T.eq(host.log[1], "Say Fox Ещё жив 2")
	end)

	T.test("thread limit", function()
		local p = Demo.build("p", 1)
		p.logic.mode = "text"
		p.logic.text.source = "on MapStarted() do\n  Wait(10)\nend\n"
		local script = Logic.compile(p)
		local host = fakeHost(p)
		local rt = Logic.Interpreter.new(script, host, { threads = 3 })
		for _ = 1, 5 do
			rt.dispatch("MapStarted", {})
		end
		T.eq(rt.activeCount(), 3)
		T.eq(#host.errors, 2)
	end)

	T.test("blocks and text share the same command set", function()
		local p = Demo.build("p", 1)
		local tree = Util.deepCopy(p.logic.blocks)
		-- блок с неизвестной командой в блочном режиме ловится тем же валидатором
		table.insert(tree.handlers[1].body, { kind = "call", name = "RunLuau", args = {}, bid = "b99" })
		p.logic.blocks = tree
		local _, errs = Logic.compile(p)
		T.eq(#errs, 1)
		T.eq(errs[1].bid, "b99")
	end)

	T.test("reserved names", function()
		T.ok(Logic.isReservedName("Wait"))
		T.ok(Logic.isReservedName("end"))
		T.ok(not Logic.isReservedName("HallLamp"))
	end)
end
