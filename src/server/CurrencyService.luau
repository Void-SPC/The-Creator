--!nonstrict
-- Монеты игрока: общая валюта Creator, сохраняется между заходами
-- В DataStore записывается только приращение (+5, −3), а не итог, поэтому
-- ошибка загрузки или второй сервер не могут затереть баланс

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local UiText = require(Shared.UiText)

local CurrencyService = {}

local store: any
local wallets: { [Player]: { base: number, delta: number, loaded: boolean, value: IntValue } } = {}

local function key(userId: number): string
	return string.format("u%d:coins", userId)
end

local function valueOf(player: Player): IntValue
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	local v = stats:FindFirstChild(UiText.L.Coins) :: IntValue?
	if not v then
		local nv = Instance.new("IntValue")
		nv.Name = UiText.L.Coins
		nv.Parent = stats
		v = nv
	end
	return v :: IntValue
end

local function show(player: Player)
	local w = wallets[player]
	if w then
		w.value.Value = w.base + w.delta
	end
end

local function flush(player: Player): boolean
	local w = wallets[player]
	if not w or w.delta == 0 then
		return true
	end
	local delta = w.delta
	local ok, res = store:_update(key(player.UserId), function(old)
		local cur = (type(old) == "table" and old.coins) or 0
		return { coins = math.max(0, cur + delta) }
	end)
	if ok then
		w.delta -= delta
		w.base = res.coins - w.delta
		w.loaded = true
		show(player)
		return true
	end
	return false
end

function CurrencyService.get(player: Player): number?
	local w = wallets[player]
	if not w or not w.loaded then
		return nil
	end
	return w.base + w.delta
end

function CurrencyService.add(player: Player, amount: number): boolean
	local w = wallets[player]
	if not w then
		return false
	end
	if amount < 0 then
		-- списывать можно только при известном балансе
		local cur = CurrencyService.get(player)
		if not cur or cur + amount < 0 then
			return false
		end
	end
	w.delta += math.floor(amount)
	show(player)
	return true
end

function CurrencyService.init(projectStore)
	store = projectStore
	local function join(player: Player)
		local w = { base = 0, delta = 0, loaded = false, value = valueOf(player) }
		wallets[player] = w
		local ok, rec = store:_get(key(player.UserId))
		if ok then
			w.base = (type(rec) == "table" and rec.coins) or 0
			w.loaded = true
		else
			warn("[Creator] монеты не загрузились, баланс не меняется до следующей попытки")
		end
		show(player)
	end
	Players.PlayerAdded:Connect(join)
	for _, p in Players:GetPlayers() do
		task.spawn(join, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		flush(player)
		wallets[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(30)
			for p, w in wallets do
				if w.delta ~= 0 then
					task.spawn(flush, p)
				elseif not w.loaded then
					local ok, rec = store:_get(key(p.UserId))
					if ok then
						w.base = (type(rec) == "table" and rec.coins) or 0
						w.loaded = true
						show(p)
					end
				end
			end
		end
	end)
	game:BindToClose(function()
		for p in wallets do
			task.spawn(flush, p)
		end
		task.wait(3)
	end)
end

return CurrencyService
