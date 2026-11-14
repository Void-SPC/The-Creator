--!nonstrict
-- Правила лабиринта, план комнат и тексты

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Rules = require(Shared.Rules)
local Plan = require(Shared.RoomPlan)
local Lang = require(Shared.Lang)
local Commands = require(Shared.AdminCommands)

return function(T)
	T.suite("rules")
	T.test("sectors: 25 doors each, boss from sector 2", function()
		T.eq(Rules.sectorOf(1), 1)
		T.eq(Rules.sectorOf(25), 1)
		T.eq(Rules.sectorOf(26), 2)
		T.ok(Rules.isSectorEnd(25) and Rules.isSectorEnd(50) and not Rules.isSectorEnd(26))
		T.ok(not Rules.hasBoss(1) and Rules.hasBoss(2) and Rules.hasBoss(7))
	end)
	T.test("elevator: only one sector forward", function()
		T.ok(Rules.canRide(2, 3))
		T.ok(not Rules.canRide(2, 4))
		T.ok(not Rules.canRide(2, 1))
		T.ok(not Rules.canRide(2, 2))
	end)
	T.test("blood toll takes 70% of current health and never kills", function()
		T.near(Rules.afterBloodToll(100), 30)
		T.near(Rules.afterBloodToll(50), 15)
		T.ok(Rules.afterBloodToll(1) >= 1)
		T.eq(Rules.tollPrice(6), 5)
		T.eq(Rules.tollPrice(40), 9)
	end)
	T.test("flashlight drains and batteries recharge", function()
		T.eq(Rules.drain(100, 10, false), 100)
		T.eq(Rules.drain(100, 10, true), 90)
		T.eq(Rules.drain(3, 10, true), 0)
		T.eq(Rules.recharge(80), 100)
		T.eq(Rules.recharge(10), 60)
	end)
	T.test("inventory caps and shop", function()
		local inv = {}
		T.ok(Rules.add(inv, "battery"))
		T.ok(Rules.add(inv, "battery"))
		T.ok(Rules.add(inv, "battery"))
		T.ok(not Rules.add(inv, "battery"))
		T.ok(Rules.add(inv, "whistle"))
		T.ok(not Rules.add(inv, "whistle"))
		T.ok(Rules.take(inv, "whistle") and inv.whistle == nil)
		local ok, coins, why = Rules.buy(inv, 5, "plant")
		T.ok(not ok and coins == 5 and why == "coins")
		ok, coins = Rules.buy(inv, 30, "plant")
		T.ok(ok and coins == 18 and inv.plant == 1)
		ok, _, why = Rules.buy(inv, 30, "battery")
		T.ok(not ok and why == "full")
	end)
	T.test("sneaking is silent, walking is heard", function()
		T.eq(Rules.noise(15, true), 0)
		T.eq(Rules.noise(7, false), 0)
		T.ok(Rules.noise(15, false) > 0)
		T.eq(Rules.repair(80), 100)
	end)
	T.test("watcher moves only when nobody looks and not frozen", function()
		T.ok(Rules.watcherMoves(nil, 10, nil))
		T.ok(not Rules.watcherMoves(9.9, 10, nil))
		T.ok(Rules.watcherMoves(9, 10, nil))
		T.ok(not Rules.watcherMoves(nil, 10, 12))
	end)
	T.test("loot table covers all outcomes", function()
		local seen = {}
		for k = 0, 99 do
			local item = Rules.loot(k / 100, 10)
			seen[item] = true
		end
		for _, it in { "coins", "battery", "plant", "lockpick", "nothing" } do
			T.ok(seen[it], it)
		end
	end)

	T.suite("room plan")
	local function plan(seed, count)
		local st = Plan.new(seed)
		local list = {}
		for n = 0, count do
			list[n] = Plan.room(st, n)
		end
		return list
	end
	T.test("start, sector ends, boss halls", function()
		local list = plan(7, 80)
		T.eq(list[0].kind, "start")
		T.eq(list[25].kind, "elevator")
		T.eq(list[50].kind, "boss")
		T.eq(list[75].kind, "boss")
		T.eq(list[26].sector, 2)
	end)
	T.test("the path never turns back", function()
		for seed = 1, 40 do
			local list = plan(seed, 120)
			for n = 0, 120 do
				local d = list[n]
				T.ok(d.heading >= -1 and d.heading <= 1, "heading " .. seed .. ":" .. n)
			end
		end
	end)
	T.test("special and short rooms go straight", function()
		for seed = 1, 30 do
			local list = plan(seed, 100)
			for n = 0, 100 do
				local d = list[n]
				if d.kind == "boss" or d.kind == "elevator" or d.kind == "start" or d.kind == "office" or Rules.isSectorEnd(n + 1) then
					T.eq(d.turn, 0, d.kind .. " " .. n)
				end
			end
		end
	end)
	T.test("no lock and toll together, hum keeps its gap, every room has a closet", function()
		for seed = 1, 30 do
			local list = plan(seed, 150)
			local last = -99
			for n = 0, 150 do
				local d = list[n]
				T.ok(not (d.locked and d.toll), "lock+toll")
				T.ok(d.closets >= 1)
				if d.hum then
					T.ok(n - last >= Rules.HUM_GAP, "hum gap")
					last = n
				end
				if n < 8 then
					T.ok(not d.hum and not d.watcher)
				end
			end
		end
	end)
	T.test("same seed gives the same labyrinth", function()
		local a, b = plan(99, 60), plan(99, 60)
		for n = 0, 60 do
			T.eq(a[n].kind, b[n].kind)
			T.eq(a[n].turn, b[n].turn)
			T.eq(a[n].locked, b[n].locked)
		end
	end)
	T.test("side exits stay inside the wall", function()
		for seed = 1, 20 do
			local list = plan(seed, 60)
			for n = 0, 60 do
				local d = list[n]
				local x, z = Plan.exitOf(d)
				T.ok(math.abs(x) <= d.w / 2 + 0.01 and z <= 0 and z >= -d.l)
				if d.turn ~= 0 then
					T.ok(-z - 3 > 0 and -z + 3 < d.l, "door fits")
				end
			end
		end
	end)

	T.test("nearby rooms never overlap", function()
		for seed = 1, 60 do
			local st = Plan.new(seed * 131)
			local recent = {}
			for n = 0, 160 do
				local before = { ox = st.ox, oz = st.oz, heading = st.heading, rects = recent }
				local d = Plan.room(st, n)
				local r = Plan.footprint(before, d.w, d.l)
				if d.kind ~= "boss" then
					T.ok(not Plan.overlaps(before, r), "seed " .. seed .. " room " .. n)
				end
				table.insert(recent, r)
				if #recent > 6 then
					table.remove(recent, 1)
				end
			end
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
		T.eq(Lang.t("en", "Door", 12), "Door 12")
	end)
	T.test("admin commands have both languages", function()
		for _, c in Commands.LIST do
			T.ok(c.en and c.ru and Commands.BY_ID[c.id])
		end
	end)
end
