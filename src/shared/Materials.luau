--!nonstrict
-- Материалы с защитой: если какого-то материала нет в версии Roblox, берётся SmoothPlastic
return setmetatable({}, {
	__index = function(t, k)
		local ok, v = pcall(function()
			return (Enum.Material :: any)[k]
		end)
		local m = if ok and v then v else Enum.Material.SmoothPlastic
		rawset(t, k, m)
		return m
	end,
})
