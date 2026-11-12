local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local UiText = require(Shared.UiText)

return function(T)
	T.suite("UiText")
	T.test("built-in strings follow the period rule", function()
		local problems = UiText.lint()
		T.eq(#problems, 0, table.concat(problems, "\n"))
	end)
	T.test("lint catches bad strings", function()
		local saveL, saveH = UiText.L, UiText.H
		UiText.L = { A = "Сохранено.", B = "Шкаф. Вход", C = "Версия 1.5", D = "The Hoteliest\nПобег" }
		UiText.H = { E = "Шкаф. Вход в шкаф открыт для всех.", F = "Это нормальное полное предложение." }
		local problems = UiText.lint()
		UiText.L, UiText.H = saveL, saveH
		T.eq(#problems, 3, table.concat(problems, "\n"))
	end)
end
