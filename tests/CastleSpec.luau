local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Rules = require(Shared.CastleRules)
local Lang = require(Shared.Lang)
local AdminCommands = require(Shared.AdminCommands)

return function(T)
	T.suite("Castle")

	T.test("inventory holds 3, or 5 with a backpack", function()
		local inv = {}
		for _ = 1, 3 do
			T.ok(Rules.addItem(inv, "bread", false))
		end
		local ok, err = Rules.addItem(inv, "apple", false)
		T.ok(not ok)
		T.eq(err, "full")
		T.ok(Rules.addItem(inv, "apple", true), "backpack gives more room")
		T.ok(Rules.addItem(inv, "water", true))
		T.ok(not Rules.addItem(inv, "cake", true))
		T.ok(Rules.removeItem(inv, "bread"))
		T.eq(#inv, 4)
	end)

	T.test("role items", function()
		T.ok(Rules.canHold("sword", "guard"))
		T.ok(not Rules.canHold("sword", "peasant"))
		T.ok(Rules.canHold("scepter", "king"))
		T.ok(not Rules.canHold("scepter", "queen"))
		T.ok(Rules.canHold("bread", nil))
	end)

	T.test("hunger, thirst and the king", function()
		local s = { food = 100, drink = 100 }
		T.eq(Rules.tick(s, 300, false), 0)
		T.ok(s.food < 100 and s.drink < s.food, "thirst is faster")
		s.drink = 0
		T.ok(Rules.tick(s, 1, false) > 0, "no water hurts")
		local k = { food = 10, drink = 10 }
		T.eq(Rules.tick(k, 1000, true), 0)
		T.eq(k.food, 100, "the king never starves")
	end)

	T.test("full people cannot eat, the king can", function()
		local s = { food = 100, drink = 100 }
		local ok, err = Rules.consume(s, "bread", false)
		T.ok(not ok)
		T.eq(err, "full")
		T.ok(Rules.consume(s, "bread", true), "the king may always eat")
		s.food = 50
		T.ok(Rules.consume(s, "soup", false))
		T.eq(s.food, 85)
		T.ok(not Rules.consume(s, "sword", false))
	end)

	T.test("roles limits", function()
		T.ok(Rules.canTake("guard", { guard = 5 }))
		T.ok(not Rules.canTake("guard", { guard = 6 }), "six guards at most")
		T.ok(not Rules.canTake("king", {}), "the throne makes the king")
		T.ok(Rules.canTake("peasant", { peasant = 40 }))
	end)

	T.test("casino pays out by the table", function()
		local seq = { 1, 1, 1 }
		local i = 0
		local function rand()
			i += 1
			return seq[i]
		end
		local s, win = Rules.slots(10, rand)
		T.eq(s[1], "crown")
		T.eq(win, 100, "three crowns")
		seq, i = { 5, 5, 5 }, 0
		_, win = Rules.slots(10, rand)
		T.eq(win, 0, "three skulls lose")
		seq, i = { 2, 2, 3 }, 0
		_, win = Rules.slots(10, rand)
		T.eq(win, 15)
		local okWin, pay = Rules.coinFlip(50, function()
			return 10
		end)
		T.ok(okWin)
		T.eq(pay, 100)
	end)

	T.test("king summons", function()
		T.ok(Rules.canSummon(0, nil, 0))
		T.ok(not Rules.canSummon(6, nil, 0))
		local ok, why = Rules.canSummon(2, 100, 150)
		T.ok(not ok)
		T.eq(why, "cooldown")
		T.ok(Rules.canSummon(2, 100, 221))
	end)

	T.test("texts in both languages follow the rule", function()
		local problems = Lang.lint()
		T.eq(#problems, 0, table.concat(problems, ", "))
		for _, role in Rules.ROLE_ORDER do
			T.ok(Lang.ru.L["role_" .. role] and Lang.en.L["role_" .. role], role)
		end
		for item in Rules.ITEMS do
			T.ok(Lang.ru.L["item_" .. item], item)
		end
		for _, s in Rules.SHOP do
			T.ok(Lang.ru.L["shop_" .. s.id], s.id)
		end
	end)

	T.test("every interaction has a caption in both languages", function()
		for _, kind in { "throne", "passage", "lever", "bread", "apple", "cook", "water", "sword", "cuffs", "book", "broom", "spoon", "slots", "coin", "shop", "rest", "roles", "cell", "scepter" } do
			T.ok(Lang.en.L["p_" .. kind] and Lang.ru.L["p_" .. kind], kind)
		end
		for _, key in { "Book1", "Book2", "Book3", "OrderHint", "Appointed", "JailedNo", "MaxGuards" } do
			T.ok(Lang.en.H[key] and Lang.ru.H[key], key)
		end
	end)

	T.test("admin panel has about fifty commands", function()
		T.ok(#AdminCommands.LIST >= 50, tostring(#AdminCommands.LIST))
		for _, c in AdminCommands.LIST do
			T.ok(c.en and c.ru and not string.find(c.ru, "%.$"), c.id)
		end
	end)
end
