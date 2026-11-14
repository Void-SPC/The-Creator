local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Rules = require(Shared.ManiacRules)
local Lang = require(Shared.Lang)

return function(T)
	T.suite("Maniac")

	T.test("two hits put a survivor down, revive brings them back", function()
		T.eq(Rules.hit("healthy"), "injured")
		T.eq(Rules.hit("injured"), "downed")
		T.eq(Rules.hit("downed"), "downed")
		T.eq(Rules.revive("downed"), "injured")
		T.ok(Rules.isAlive("downed"))
		T.ok(not Rules.isAlive("dead"))
	end)

	T.test("generators depend on survivors", function()
		T.eq(Rules.generatorsFor(1), 3)
		T.eq(Rules.generatorsFor(4), 5)
		T.eq(Rules.generatorsFor(11), 6)
		T.eq(Rules.repair(0, 1), 25)
		T.eq(Rules.repair(90, 3), 100)
	end)

	T.test("abilities have cooldowns", function()
		T.ok(Rules.ready("scream", nil, 0))
		local ok, left = Rules.ready("scream", 10, 20)
		T.ok(not ok)
		T.eq(left, 15)
		T.ok(Rules.ready("scream", 10, 36))
		T.ok(not Rules.ready("fly", nil, 0))
	end)

	T.test("who wins", function()
		T.eq(Rules.winner({ a = "dead", b = "dead" }, false), "maniac")
		T.eq(Rules.winner({ a = "dead", b = "escaped" }, false), "survivors")
		T.eq(Rules.winner({ a = "injured", b = "escaped" }, false), nil)
		T.eq(Rules.winner({ a = "injured" }, true), "maniac")
		T.eq(Rules.winner({ a = "injured", b = "escaped" }, true), "survivors")
	end)

	T.test("maniac texts exist in both languages", function()
		for _, a in Rules.ABILITY_ORDER do
			T.ok(Lang.en.L["ab_" .. a] and Lang.ru.L["ab_" .. a], a)
		end
		for _, k in { "Maniac", "Survivor", "Generators", "ManiacWins", "SurvivorsWin", "Lobby", "Ghost" } do
			T.ok(Lang.en.L[k] and Lang.ru.L[k], k)
		end
	end)
end
