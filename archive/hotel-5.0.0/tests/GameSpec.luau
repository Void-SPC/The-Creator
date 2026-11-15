--!nonstrict
-- Правила лабиринта, план комнат и тексты

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Rules = require(Shared.Rules)
local Plan = require(Shared.RoomPlan)
local Lang = require(Shared.Lang)
local Commands = require(Shared.AdminCommands)

return function(T)
	T.suite("rules")
	T.test("chapter of 100 doors with three-digit plates", function()
		T.eq(Rules.plate(1), "001")
		T.eq(Rules.plate(100), "100")
		T.ok(Rules.isBoss(100) and not Rules.isBoss(99))
	end)
	T.test("light fades after door 20, blackout 61-75", function()
		T.eq(Rules.light(5), 1)
		T.ok(Rules.light(40) < 1 and Rules.light(40) > Rules.light(55))
		T.ok(Rules.blackout(61) and Rules.blackout(75) and not Rules.blackout(60) and not Rules.blackout(76))
		T.eq(Rules.light(70), 0)
		T.eq(Rules.windowChance(50), 0)
		T.ok(Rules.windowChance(5) > Rules.windowChance(30))
	end)
	T.test("coin keeper price grows to about 500", function()
		T.ok(Rules.coinPrice(6) < 15)
		T.ok(Rules.coinPrice(50) > Rules.coinPrice(20))
		T.eq(Rules.coinPrice(100), 500)
		local last = 0
		for d = 1, 100 do
			T.ok(Rules.coinPrice(d) >= last)
			last = Rules.coinPrice(d)
		end
	end)
	T.test("blood toll takes 70% of current health and never kills", function()
		T.near(Rules.afterBloodToll(100), 30)
		T.near(Rules.afterBloodToll(50), 15)
		T.ok(Rules.afterBloodToll(1) >= 1)
	end)
	T.test("flashlight drains and batteries recharge", function()
		T.eq(Rules.drain(100, 10, false), 100)
		T.near(Rules.drain(100, 10, true), 92)
		T.eq(Rules.drain(3, 10, true), 0)
		T.eq(Rules.recharge(80), 100)
		T.eq(Rules.recharge(10), 60)
	end)
	T.test("inventory caps", function()
		local inv = {}
		for _ = 1, 5 do
			T.ok(Rules.add(inv, "battery"))
		end
		T.ok(not Rules.add(inv, "battery"))
		T.ok(Rules.add(inv, "whistle"))
		T.ok(not Rules.add(inv, "whistle"))
		T.ok(Rules.take(inv, "whistle") and inv.whistle == nil)
	end)
	T.test("healing plants are rare, batteries more common", function()
		local count = { coins = 0, battery = 0, plant = 0, lockpick = 0, nothing = 0 }
		for k = 0, 999 do
			local item = Rules.loot(k / 1000, 10)
			count[item] += 1
		end
		T.ok(count.plant > 0 and count.plant < 30, "plant " .. count.plant)
		T.ok(count.battery > count.plant * 4)
		T.ok(count.nothing > 300)
	end)
	T.test("sneaking is silent, walking is heard", function()
		T.eq(Rules.noise(15, true), 0)
		T.eq(Rules.noise(7, false), 0)
		T.ok(Rules.noise(15, false) > 0)
		T.ok(Rules.BLIND_SPEED.chase < Rules.SPEED.walk, "the chase can be outrun")
	end)
	T.test("watcher moves only when nobody looks and not frozen", function()
		T.ok(Rules.watcherMoves(nil, 10, nil))
		T.ok(not Rules.watcherMoves(9.9, 10, nil))
		T.ok(not Rules.watcherMoves(nil, 10, 12))
	end)

	T.suite("room plan")
	local function plan(seed, count)
		local st = Plan.new(seed)
		local list = {}
		for n = 0, count do
			list[n] = Plan.room(st, n)
		end
		return list, st
	end
	T.test("start, boss at door 100", function()
		local list = plan(7, 100)
		T.eq(list[0].kind, "start")
		T.eq(list[100].kind, "boss")
		T.eq(list[100].exit.turn, 0)
	end)
	T.test("many kinds of rooms appear", function()
		local seen, n = {}, 0
		for seed = 1, 20 do
			local list = plan(seed, 99)
			for i = 1, 99 do
				if not seen[list[i].kind] then
					seen[list[i].kind] = true
					n += 1
				end
			end
		end
		T.ok(n >= 17, "kinds " .. n)
	end)
	T.test("the path never turns back", function()
		for seed = 1, 40 do
			local list = plan(seed, 100)
			for n = 0, 100 do
				local d = list[n]
				T.ok(d.heading >= -1 and d.heading <= 1)
			end
		end
	end)
	T.test("nearby rooms never overlap or touch wall to wall", function()
		for seed = 1, 60 do
			local st = Plan.new(seed * 131)
			for n = 0, 100 do
				local before = { ox = st.ox, oz = st.oz, heading = st.heading, rects = table.clone(st.rects) }
				local d = Plan.room(st, n)
				if d.kind ~= "boss" then
					T.ok(not Plan.overlaps(before, Plan.footprint(before, d.w, d.l)), "seed " .. seed .. " room " .. n .. " " .. d.kind)
				end
			end
		end
	end)
	T.test("no lock and coin keeper together, hum keeps its gap, nothing early", function()
		for seed = 1, 30 do
			local list = plan(seed, 100)
			local last = -99
			for n = 0, 100 do
				local d = list[n]
				T.ok(not (d.locked and d.coin))
				if d.hum then
					T.ok(n - last >= Rules.HUM_GAP)
					last = n
				end
				if n < 10 then
					T.ok(not d.hum and not d.watcher)
				end
			end
		end
	end)
	T.test("exits and decoys stay inside the walls", function()
		for seed = 1, 20 do
			local list = plan(seed, 100)
			for n = 0, 100 do
				local d = list[n]
				for _, e in { d.exit, table.unpack(d.decoys) } do
					T.ok(math.abs(e.x) <= d.w / 2 + 0.01 and e.z <= 0 and e.z >= -d.l)
					T.ok(not (e.x == 0 and e.z == 0), "not at the entrance")
				end
				for _, e in d.decoys do
					T.ok(not (e.x == d.exit.x and e.z == d.exit.z), "decoy on the real exit")
				end
			end
		end
	end)
	T.test("same seed gives the same labyrinth", function()
		local a, b = plan(99, 60), plan(99, 60)
		for n = 0, 60 do
			T.eq(a[n].kind, b[n].kind)
			T.eq(a[n].exit.name, b[n].exit.name)
			T.eq(a[n].locked, b[n].locked)
		end
	end)

	T.suite("texts")
	T.test("both languages, no periods", function()
		local problems = Lang.lint()
		T.eq(#problems, 0, table.concat(problems, "; "))
	end)
	T.test("formatting with percent", function()
		T.eq(Lang.t("en", "p_payblood"), "Pay with blood (70% health)")
		T.eq(Lang.t("ru", "Repairing", 34), "Генератор починен на 34%")
	end)
	T.test("admin commands have both languages", function()
		for _, c in Commands.LIST do
			T.ok(c.en and c.ru and Commands.BY_ID[c.id])
		end
	end)
end
