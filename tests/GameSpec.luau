--!nonstrict
-- Правила музея, план залов и тексты

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Rules = require(Shared.Rules)
local Plan = require(Shared.RoomPlan)
local Lang = require(Shared.Lang)
local Commands = require(Shared.AdminCommands)

return function(T)
	T.suite("rules")
	T.test("plates and zones", function()
		T.eq(Rules.plate(1), "001")
		T.eq(Rules.plate(100), "100")
		T.eq(Rules.zone(20), "classic")
		T.eq(Rules.zone(70), "old")
		T.eq(Rules.zone(100), "ruin")
		T.ok(Rules.light(80) < Rules.light(20))
	end)
	T.test("coinkeeper: 20 to 100 in the first location, +100 per location, max 500", function()
		T.eq(Rules.coinPrice(1), 20)
		T.eq(Rules.coinPrice(100), 100)
		T.eq(Rules.coinPrice(101), 100)
		T.eq(Rules.coinPrice(200), 200)
		T.eq(Rules.coinPrice(500), 500)
		T.eq(Rules.coinPrice(600), 500)
		T.eq(Rules.coinPrice(950), 500)
		T.eq(Rules.coinChance(29), 0)
		T.ok(Rules.coinChance(30) > 0)
	end)
	T.test("paying with yourself takes 70% and kills at 1 health", function()
		T.near(Rules.afterSelfToll(100), 30)
		T.near(Rules.afterSelfToll(10), 3)
		T.eq(Rules.afterSelfToll(1), 0)
	end)
	T.test("darkness chance grows with every door", function()
		T.eq(Rules.darkChance(2), 0)
		T.ok(Rules.darkChance(5) > Rules.darkChance(4))
		T.ok(Rules.darkChance(40) <= 0.4)
	end)
	T.test("flashlight and inventory", function()
		T.near(Rules.drain(100, 10, true), 92)
		T.eq(Rules.recharge(80), 100)
		local inv = {}
		T.ok(Rules.add(inv, "hammer"))
		T.ok(not Rules.add(inv, "hammer"))
		T.ok(Rules.take(inv, "hammer") and inv.hammer == nil)
		for _ = 1, 3 do
			T.ok(Rules.add(inv, "meat"))
		end
		T.ok(not Rules.add(inv, "meat"))
	end)
	T.test("loot: plants and hammers are rare", function()
		local count = { coins = 0, battery = 0, plant = 0, lockpick = 0, hammer = 0, nothing = 0 }
		for k = 0, 999 do
			count[Rules.loot(k / 1000, 10)] += 1
		end
		T.ok(count.plant > 0 and count.plant < 30)
		T.ok(count.hammer > 0 and count.hammer < 20)
		T.ok(count.nothing > 300)
	end)
	T.test("code lock has four digits in colour order", function()
		local c = Rules.code(Plan.rng(5))
		T.eq(#c.text, 4)
		for i = 1, 4 do
			T.eq(string.sub(c.text, i, i), tostring(c.digits[c.order[i]]))
		end
	end)
	T.test("mirrors: only the right angles bring the beam to the target", function()
		local need = {}
		for k, c in Rules.MIRRORS.cells do
			need[k] = c.need
		end
		local path, hit = Rules.trace(need)
		T.ok(hit, "solution works")
		T.ok(#path >= 6)
		local solved = 0
		for a = 0, 3 do
			for b = 0, 3 do
				for c = 0, 3 do
					for e = 0, 3 do
						local _, ok = Rules.trace({ a, b, c, e })
						if ok then
							solved += 1
						end
					end
				end
			end
		end
		T.eq(solved, 1, "single solution")
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
	T.test("special rooms stand at their doors", function()
		local list = plan(7, 100)
		T.eq(list[0].kind, "start")
		T.eq(list[49].kind, "codehall")
		T.eq(list[50].kind, "arena")
		T.eq(list[99].kind, "lifthall")
		T.eq(list[100].kind, "final")
		T.eq(list[49].exitSize, "grand")
	end)
	T.test("many kinds of halls appear", function()
		local seen, n = {}, 0
		for seed = 1, 30 do
			local list = plan(seed, 99)
			for i = 1, 99 do
				if not seen[list[i].kind] then
					seen[list[i].kind] = true
					n += 1
				end
			end
		end
		T.ok(n >= 21, "kinds " .. n)
		T.ok(seen.figures and seen.voidhall)
	end)
	T.test("nearby rooms never overlap or touch wall to wall", function()
		for seed = 1, 80 do
			local st = Plan.new(seed * 131)
			for n = 0, 98 do
				local before = { ox = st.ox, oz = st.oz, heading = st.heading, rects = table.clone(st.rects) }
				local d = Plan.room(st, n)
				T.ok(not Plan.overlaps(before, Plan.footprint(before, d.w, d.l)), "seed " .. seed .. " room " .. n .. " " .. d.kind)
				T.ok(d.heading >= -1 and d.heading <= 1)
			end
		end
	end)
	T.test("doors: entry matches the previous exit and fits the room", function()
		for seed = 1, 40 do
			local list = plan(seed, 100)
			for n = 1, 99 do
				local d = list[n]
				T.eq(d.entrySize, list[n - 1].exitSize)
				local e, x = Plan.DOORS[d.entrySize], Plan.DOORS[d.exitSize]
				T.ok(e.h < d.h and x.h < d.h, d.kind .. " door height")
				T.ok(e.w < d.w - 2 and x.w < d.w - 2)
			end
		end
	end)
	T.test("lockers: never two rooms in a row without one, darkness only near lockers", function()
		for seed = 1, 40 do
			local list = plan(seed, 98)
			local firstDark = nil
			for n = 2, 98 do
				local d = list[n]
				if n ~= 49 and n ~= 50 and n ~= 51 then
					T.ok(d.hides > 0 or list[n - 1].hides > 0, "seed " .. seed .. " room " .. n)
				end
				if d.dark then
					firstDark = firstDark or n
					T.ok(d.hides > 0 or list[n - 1].hides > 0)
					T.ok(d.kind ~= "figures" and d.kind ~= "voidhall")
				end
				T.ok(not (d.locked and d.coin))
				if d.coin then
					T.ok(n >= 30)
				end
			end
			T.ok(firstDark and firstDark >= 11 and firstDark <= 17, "first darkness " .. tostring(firstDark))
		end
	end)
	T.test("exits and decoys stay inside the walls", function()
		for seed = 1, 20 do
			local list = plan(seed, 98)
			for n = 0, 98 do
				local d = list[n]
				for _, e in { d.exit, table.unpack(d.decoys) } do
					T.ok(math.abs(e.x) <= d.w / 2 + 0.01 and e.z <= 0 and e.z >= -d.l)
				end
				for _, e in d.decoys do
					T.ok(not (e.x == d.exit.x and e.z == d.exit.z))
				end
			end
		end
	end)
	T.test("same seed gives the same museum", function()
		local a, b = plan(99, 60), plan(99, 60)
		for n = 0, 60 do
			T.eq(a[n].kind, b[n].kind)
			T.eq(a[n].exit.name, b[n].exit.name)
			T.eq(a[n].hides, b[n].hides)
		end
	end)

	T.suite("texts")
	T.test("both languages, no periods", function()
		local problems = Lang.lint()
		T.eq(#problems, 0, table.concat(problems, "; "))
	end)
	T.test("admin commands have both languages", function()
		for _, c in Commands.LIST do
			T.ok(c.en and c.ru and Commands.BY_ID[c.id])
		end
	end)
end
