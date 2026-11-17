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
	T.test("third lock: eight exhibits get unique roman numbers", function()
		local c = Rules.code(Plan.rng(9))
		local seen = {}
		for item = 1, 8 do
			T.ok(c.roman[item] >= 1 and c.roman[item] <= 8 and not seen[c.roman[item]])
			seen[c.roman[item]] = true
			T.eq(c.sequence[c.roman[item]], item)
		end
	end)
	T.test("code lock has four digits in colour order", function()
		local c = Rules.code(Plan.rng(5))
		T.eq(#c.text, 4)
		for i = 1, 4 do
			T.eq(string.sub(c.text, i, i), tostring(c.digits[c.order[i]]))
		end
	end)
	T.test("mirrors: the beam reaches the chandelier only through all four mirrors", function()
		local sol = Rules.beamSolution()
		local path, chain, hit = Rules.beam(sol)
		T.ok(hit, "solution works")
		T.eq(#chain, 4)
		T.eq(#path, 6)
		-- немного мимо — всё равно цепляется (допуск)
		local near = table.clone(sol)
		near[2] += math.rad(2)
		local _, _, hit2 = Rules.beam(near)
		T.ok(hit2, "tolerance")
		-- сильно мимо — нет
		local far = table.clone(sol)
		far[3] += math.rad(12)
		local _, c3, hit3 = Rules.beam(far)
		T.ok(not hit3)
		T.ok(#c3 < 4)
		-- случайные углы почти никогда не решают
		local rand = Plan.rng(3)
		local solved = 0
		for _ = 1, 400 do
			local a = {}
			for k = 1, 4 do
				a[k] = rand() * math.pi * 2
			end
			local _, _, h = Rules.beam(a)
			if h then
				solved += 1
			end
		end
		T.ok(solved < 3)
	end)
	T.test("every achievement has a name and a description in both languages", function()
		for _, id in Rules.ACHIEVEMENTS do
			for _, lang in { "en", "ru" } do
				T.ok(Lang[lang]["a_" .. id] ~= nil, lang .. " a_" .. id)
				T.ok(Lang[lang]["a_" .. id .. "_t"] ~= nil, lang .. " a_" .. id .. "_t")
			end
		end
	end)
	T.test("YOUrself replays the path with a delay and waits where the player waited", function()
		local log = {}
		-- игрок идёт 2 секунды, стоит 5 секунд, идёт дальше
		for k = 0, 90 do
			local t = k * 0.1
			local x = if t < 2 then t * 10 elseif t < 7 then 20 else 20 + (t - 7) * 10
			table.insert(log, { t = t, x = x, z = 0 })
		end
		T.eq(Rules.replayAt(log, 1), nil, "nothing yet")
		local function xAt(now)
			return log[Rules.replayAt(log, now)].x
		end
		T.ok(math.abs(xAt(3.5) - 10) < 1.1)
		-- игрок стоял с 2 до 7 секунды — статуя стоит с 4.5 до 9.5
		T.ok(math.abs(xAt(6) - 20) < 0.01)
		T.ok(math.abs(xAt(9.4) - 20) < 0.01)
		T.ok(xAt(10.5) > 20)
	end)
	T.test("clock hands come around", function()
		local h, m = 12, 45
		h, m = Rules.clockStep(h, m, "hour")
		T.eq(h, 1)
		h, m = Rules.clockStep(h, m, "minute")
		T.eq(m, 0)
		local rand = Plan.rng(4)
		for _ = 1, 50 do
			local a, b = Rules.clockTime(rand)
			T.ok(a >= 1 and a <= 12 and b % 15 == 0 and b < 60)
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
	T.test("special rooms stand at their doors", function()
		local list = plan(7, 100)
		T.eq(list[0].kind, "start")
		T.eq(list[48].kind, "codehall")
		T.eq(list[49].kind, "passage")
		T.eq(list[50].kind, "arena")
		T.eq(list[99].kind, "lifthall")
		T.eq(list[100].kind, "final")
		T.eq(list[48].exitSize, "grand")
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
				if n < 48 or n > 51 then
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
	T.test("restroom annexes appear and never touch other rooms", function()
		local count = 0
		for seed = 1, 60 do
			local st = Plan.new(seed * 57)
			local rects = {}
			for n = 0, 98 do
				local before = { ox = st.ox, oz = st.oz, heading = st.heading }
				local d = Plan.room(st, n)
				local mine = Plan.footprint(before, d.w, d.l)
				if d.annex then
					count += 1
					T.ok(Plan.ANNEX[d.kind] ~= nil)
				end
				-- пристройки прошлых залов не пересекаются с новым залом
				for _, a in rects do
					if n - a.n <= 6 and n ~= a.n then
						local ox = math.min(mine[3], a.r[3]) - math.max(mine[1], a.r[1])
						local oz = math.min(mine[4], a.r[4]) - math.max(mine[2], a.r[2])
						T.ok(not (ox > 0.5 and oz > 0.5), "seed " .. seed .. " room " .. n .. " hits annex of " .. a.n)
					end
				end
				if d.annex then
					table.insert(rects, { n = n, r = d.annex.rect })
				end
			end
		end
		T.ok(count > 40, "annexes " .. count)
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
