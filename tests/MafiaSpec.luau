local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Rules = require(Shared.MafiaRules)

return function(T)
	T.suite("Mafia rules")

	T.test("automatic role counts", function()
		T.eq(Rules.autoCounts(8).mafia, 2)
		T.eq(Rules.autoCounts(12).mafia, 4)
		T.eq(Rules.autoCounts(13).mafia, 4)
		T.eq(Rules.autoCounts(4).mafia, 1)
		T.eq(Rules.autoCounts(8).doctor, 1)
		T.eq(Rules.autoCounts(8).sheriff, 1)
	end)

	T.test("manual counts are checked", function()
		T.eq(Rules.checkCounts(10, { mafia = 3, doctor = 1, sheriff = 2 }), nil)
		T.eq(Rules.checkCounts(10, { mafia = 7, doctor = 1, sheriff = 1 }), "mafia")
		T.eq(Rules.checkCounts(10, { mafia = 2, doctor = 4, sheriff = 1 }), "doctor")
		T.eq(Rules.checkCounts(6, { mafia = 3, doctor = 1, sheriff = 1 }), "too_much_mafia")
		T.eq(Rules.checkCounts(5, { mafia = 2, doctor = 3, sheriff = 1 }), "too_many_roles")
	end)

	T.test("everyone gets exactly one role", function()
		local ids = {}
		for i = 1, 12 do
			ids[i] = i
		end
		local seed = 7
		local function rand(a, b)
			seed = (seed * 1103515245 + 12345) % 2147483648
			return a + (seed // 65536) % (b - a + 1)
		end
		local roles = Rules.assign(ids, { mafia = 4, doctor = 1, sheriff = 1 }, rand)
		local count = { mafia = 0, doctor = 0, sheriff = 0, civilian = 0 }
		local n = 0
		for _, r in roles do
			count[r] += 1
			n += 1
		end
		T.eq(n, 12)
		T.eq(count.mafia, 4)
		T.eq(count.doctor, 1)
		T.eq(count.sheriff, 1)
		T.eq(count.civilian, 6)
	end)

	T.test("day vote", function()
		local alive = { a = true, b = true, c = true, d = true, e = true }
		T.eq(Rules.dayResult({ a = "c", b = "c", d = "e" }, alive), "c")
		T.eq(Rules.dayResult({ a = "c", b = "e" }, alive), nil, "tie keeps everyone")
		T.eq(Rules.dayResult({ a = "c", b = "skip", d = "skip" }, alive), nil, "skip wins")
		local _, tally = Rules.dayResult({ a = "c", x = "c", y = "c" }, alive)
		T.eq(tally.c, 1, "dead do not vote")
	end)

	T.test("mafia must agree", function()
		local roles = { m1 = "mafia", m2 = "mafia", c = "civilian", d = "doctor" }
		local alive = { m1 = true, m2 = true, c = true, d = true }
		local t, agreed = Rules.mafiaTarget({ m1 = "c", m2 = "d" }, roles, alive)
		T.eq(t, nil)
		T.ok(not agreed)
		t = Rules.mafiaTarget({ m1 = "c" }, roles, alive)
		T.eq(t, nil, "everyone has to vote")
		t, agreed = Rules.mafiaTarget({ m1 = "c", m2 = "c" }, roles, alive)
		T.eq(t, "c")
		T.ok(agreed)
		alive.m2 = false
		T.eq(Rules.mafiaTarget({ m1 = "d" }, roles, alive), "d", "only living mafia count")
	end)

	T.test("doctor saves", function()
		T.eq(Rules.nightResult("c", { "d" }), "c")
		local victim, saved = Rules.nightResult("c", { "x", "c" })
		T.eq(victim, nil)
		T.ok(saved)
	end)

	T.test("winner", function()
		local roles = { m = "mafia", a = "civilian", b = "doctor" }
		T.eq(Rules.winner(roles, { m = true, a = true, b = true }), nil)
		T.eq(Rules.winner(roles, { m = true, a = true }), "mafia")
		T.eq(Rules.winner(roles, { a = true, b = true }), "town")
	end)

	T.test("chat rights", function()
		local civ = { role = "civilian", alive = true }
		local maf = { role = "mafia", alive = true }
		local ghost = { role = "mafia", alive = false }
		local host = { host = true }
		local send, see = Rules.chat("general", civ, "day")
		T.ok(send and see)
		send = Rules.chat("general", civ, "night")
		T.ok(not send, "nobody talks at night")
		send, see = Rules.chat("mafia", civ, "night")
		T.ok(not send and not see, "town never sees mafia chat")
		send, see = Rules.chat("mafia", maf, "night")
		T.ok(send and see, "mafia talks on its turn")
		send, see = Rules.chat("general", ghost, "day")
		T.ok(not send and see, "ghosts read but cannot hint")
		send, see = Rules.chat("ghost", civ, "day")
		T.ok(not send and not see, "living players do not see ghost chat")
		send, see = Rules.chat("mafia", ghost, "night")
		T.ok(not send and not see, "dead mafia leaves the mafia chat")
		send, see = Rules.chat("ghost", host, "night")
		T.ok(send and see, "host sees and writes everywhere")
	end)
end
