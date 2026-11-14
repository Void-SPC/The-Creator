--!nonstrict
-- Игра в замке на клиенте: камера от первого лица, шкалы здоровья, еды и воды,
-- инвентарь, роли, панель короля, казино, магазин, шаги по материалу, погода и эффекты

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local Rules = require(Shared.CastleRules)
local Remotes = require(Shared.Roblox.Remotes)
local Sounds = require(Shared.CastleSounds)

local Ui = require(script.Parent.Ui)
local Menu = require(script.Parent.Menu)
local CameraController = require(script.Parent.Parent.Common.CameraController)
local WeatherFx = require(script.Parent.Parent.Common.WeatherFx)

local player = Players.LocalPlayer

local Client = {}
Client.__index = Client

local function request(...)
	local ok, res = pcall(function(...)
		return Remotes.fn("CastleRequest"):InvokeServer(...)
	end, ...)
	return if ok then res else nil
end

local ITEM_COLOR = {
	bread = Color3.fromRGB(196, 140, 70), apple = Color3.fromRGB(190, 40, 40), meat = Color3.fromRGB(140, 70, 40),
	soup = Color3.fromRGB(150, 100, 60), cake = Color3.fromRGB(250, 200, 220), water = Color3.fromRGB(80, 140, 200),
	juice = Color3.fromRGB(240, 150, 40), spoon = Color3.fromRGB(200, 200, 210), broom = Color3.fromRGB(150, 110, 60),
	book = Color3.fromRGB(110, 40, 40), scepter = Color3.fromRGB(214, 172, 80), sword = Color3.fromRGB(190, 192, 200),
	cuffs = Color3.fromRGB(90, 86, 82),
}
local SYMBOL = { crown = "👑", sword = "⚔️", apple = "🍎", bell = "🔔", skull = "💀" }

-- материал под ногами -> скорость и громкость шагов
local STEP = {
	[Enum.Material.Carpet] = { 0.7, 0.22 },
	[Enum.Material.Fabric] = { 0.72, 0.25 },
	[Enum.Material.Wood] = { 0.95, 0.5 },
	[Enum.Material.WoodPlanks] = { 0.95, 0.5 },
	[Enum.Material.Grass] = { 0.85, 0.32 },
	[Enum.Material.LeafyGrass] = { 0.85, 0.32 },
	[Enum.Material.Mud] = { 0.8, 0.35 },
	[Enum.Material.Snow] = { 0.7, 0.4 },
	[Enum.Material.Sand] = { 0.8, 0.3 },
	[Enum.Material.Metal] = { 1.3, 0.55 },
	[Enum.Material.DiamondPlate] = { 1.3, 0.55 },
}
local STONE_STEP = { 1.15, 0.6 }

function Client.new(app)
	local self = setmetatable({}, Client)
	self.app = app
	self.conns = {}
	local gui = Instance.new("ScreenGui")
	gui.Name = "CastleHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Parent = app.playerGui
	self.gui = gui
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
	self.camera = CameraController.new({ camera = { mode = "first", sensitivity = app.settings.sensitivity, fov = app.settings.fov, bob = app.settings.bob } })
	self.weather = WeatherFx.new()
	self:buildHud()
	self:localizePrompts()
	self:buildSounds()
	self:watch()
	self:applySettings()
	return self
end

function Client:T(key, ...)
	return self.app.T(key, ...)
end

function Client:toast(text: string, color: Color3?)
	Ui.toast(self.gui, text, color)
end

-- окно открыто: на компьютере освобождаем курсор
function Client:sheet(title, onClose, width)
	self.camera:setFreeCursor(true)
	return Ui.sheet(self.gui, title, function()
		self.camera:setFreeCursor(false)
		if onClose then
			onClose()
		end
	end, width)
end

-- ---------------------------------------------------------------------------
-- HUD

local function bar(parent, order, color)
	local f = Ui.frame(parent, { Size = UDim2.new(1, 0, 0, 16), BackgroundColor3 = Ui.C.bg, BackgroundTransparency = 0.25, LayoutOrder = order })
	Ui.corner(f, 4)
	Ui.stroke(f, Ui.C.line, 1)
	local fill = Ui.frame(f, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color })
	Ui.corner(fill, 4)
	local l = Ui.label(f, "", { Size = UDim2.new(1, -8, 1, 0), Position = UDim2.fromOffset(6, 0), TextSize = 12, Font = Ui.FONT_BOLD, ZIndex = 2 })
	return fill, l
end

function Client:buildHud()
	local gui = self.gui
	local inset = game:GetService("GuiService").TopbarInset
	local top = math.max(inset.Height, 36) + 8
	local box = Ui.frame(gui, { BackgroundTransparency = 1, Size = UDim2.fromOffset(170, 120), Position = UDim2.fromOffset(12, top) })
	Ui.list(box, 4)
	self.hpFill, self.hpLabel = bar(box, 1, Ui.C.health)
	self.foodFill, self.foodLabel = bar(box, 2, Ui.C.food)
	self.drinkFill, self.drinkLabel = bar(box, 3, Ui.C.drink)
	self.roleLabel = Ui.label(box, "", { TextSize = 14, Font = Ui.FONT_BOLD, TextColor3 = Ui.C.gold, LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 18) })
	self.goldLabel = Ui.label(box, "", { TextSize = 14, TextColor3 = Ui.C.text, LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 18) })
	-- кнопки справа: компактные, чтобы не закрывать обзор
	local right = Ui.frame(gui, { BackgroundTransparency = 1, Size = UDim2.fromOffset(110, 200), Position = UDim2.new(1, -122, 0, top) })
	Ui.list(right, 6)
	local function small(text, order, fn)
		return Ui.button(right, text, fn, { Size = UDim2.new(1, 0, 0, 34), TextSize = 14, LayoutOrder = order, BackgroundTransparency = 0.2 })
	end
	self.menuBtn = small(self:T("Menu"), 1, function()
		self:openMenu()
	end)
	self.rolesBtn = small(self:T("Roles"), 2, function()
		self:openRoles()
	end)
	self.kingBtn = small(self:T("KingPanel"), 3, function()
		self:openKing()
	end)
	self.kingBtn.TextColor3 = Ui.C.gold
	self.kingBtn.Visible = false
	-- инвентарь внизу по центру, над джойстиком не заходит
	self.inv = Ui.frame(gui, { BackgroundTransparency = 1, Size = UDim2.fromOffset(5 * 64, 70), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12) })
	local l = Ui.list(self.inv, 6, true)
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	-- точка прицела в центре, как в DOORS
	local dot = Ui.frame(gui, { Size = UDim2.fromOffset(4, 4), Position = UDim2.new(0.5, -2, 0.5, -2), BackgroundColor3 = Ui.C.text, BackgroundTransparency = 0.4 })
	Ui.corner(dot, 2)
	-- объявления для всего замка
	self.banner = Ui.label(gui, "", { Font = Ui.TITLE, TextSize = 34, TextColor3 = Ui.C.gold, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -40, 0, 90), Position = UDim2.new(0, 20, 0.2, 0), Visible = false, TextStrokeTransparency = 0.4 })
	self:refresh()
end

-- подписи у объектов замка на языке игрока (сервер оставляет их пустыми)
function Client:localizePrompts()
	local castle = workspace:FindFirstChild("TheCastle")
	if not castle then
		return
	end
	for _, d in castle:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			local kind = d:GetAttribute("Kind")
			if kind then
				d.ActionText = self:T("p_" .. kind)
			end
		end
	end
end

function Client:refresh()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local hp = if hum then math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1) else 0
	self.hpFill.Size = UDim2.fromScale(hp, 1)
	self.hpLabel.Text = string.format("%s  %d", self:T("Health"), math.floor(hp * 100 + 0.5))
	local food = player:GetAttribute("Food") or 100
	local drink = player:GetAttribute("Drink") or 100
	self.foodFill.Size = UDim2.fromScale(food / 100, 1)
	self.foodLabel.Text = string.format("%s  %d", self:T("Food"), food)
	self.drinkFill.Size = UDim2.fromScale(drink / 100, 1)
	self.drinkLabel.Text = string.format("%s  %d", self:T("Drink"), drink)
	local role = player:GetAttribute("CastleRole") or "peasant"
	self.roleLabel.Text = self:T("role_" .. role)
	local stats = player:FindFirstChild("leaderstats")
	local gold = stats and stats:FindFirstChild("Gold")
	self.goldLabel.Text = string.format("%s  %d", self:T("Gold"), if gold then gold.Value else 0)
	self.kingBtn.Visible = role == "king"
end

function Client:refreshInventory()
	for _, c in self.inv:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local inv = string.split(player:GetAttribute("Inv") or "", ",")
	local slots = player:GetAttribute("Slots") or 3
	local equipped = player.Character and player.Character:FindFirstChildOfClass("Tool")
	local eqSlot = equipped and equipped:GetAttribute("Slot")
	for i = 1, slots do
		local item = inv[i]
		if item == "" then
			item = nil
		end
		local b = Ui.button(self.inv, if item then self:T("item_" .. item) else "", function()
			if item then
				request("Use", i)
			end
		end, { Size = UDim2.fromOffset(58, 58), TextSize = 11, LayoutOrder = i, BackgroundTransparency = 0.15, TextYAlignment = Enum.TextYAlignment.Bottom })
		if item then
			local icon = Ui.frame(b, { Size = UDim2.fromOffset(22, 22), Position = UDim2.new(0.5, -11, 0, 7), BackgroundColor3 = ITEM_COLOR[item] or Ui.C.dim })
			Ui.corner(icon, 11)
			-- маленькая кнопка «выбросить» в углу
			Ui.button(b, "x", function()
				request("Drop", i)
			end, { Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -19, 0, 1), TextSize = 11, BackgroundColor3 = Ui.C.red, ZIndex = 3 })
		end
		if eqSlot == i then
			Ui.stroke(b, Ui.C.gold, 2)
		end
	end
end

-- ---------------------------------------------------------------------------
-- окна

function Client:openMenu()
	local _, c, close = self:sheet(self:T("Menu"), nil, 360)
	Ui.button(c, self:T("Settings"), function()
		close()
		self.camera:setFreeCursor(true)
		Menu.settingsSheet(self.app, self.gui)
	end, { LayoutOrder = 1, ZIndex = 43 })
	Ui.button(c, self:T("HowToPlay"), function()
		close()
		self.camera:setFreeCursor(true)
		Menu.tutorialSheet(self.app, self.gui)
	end, { LayoutOrder = 2, ZIndex = 43 })
	Ui.button(c, self:T("Casino"), function()
		close()
		self:openSlots()
	end, { LayoutOrder = 3, ZIndex = 43 })
	Ui.button(c, self:T("MainMenu"), function()
		close()
		self.app:backToMenu()
	end, { LayoutOrder = 4, ZIndex = 43, BackgroundColor3 = Ui.C.red })
end

function Client:openRoles()
	local _, c, close = self:sheet(self:T("Roles"))
	local mine = player:GetAttribute("CastleRole")
	for i, role in Rules.ROLE_ORDER do
		local max = Rules.ROLES[role].max
		local n = workspace:GetAttribute("CastleCount_" .. role) or 0
		local text = if max >= 99 then self:T("role_" .. role) else string.format("%s   %d / %d", self:T("role_" .. role), n, max)
		local b = Ui.button(c, text, function()
			if Rules.APPOINTED[role] then
				self:toast(self:T(if role == "king" then "p_throne" else "Appointed"))
				return
			end
			local res = request("TakeRole", role)
			if res and res.ok then
				close()
			elseif res and res.error == "jailed" then
				self:toast(self:T("JailedNo"), Ui.C.red)
			else
				self:toast(self:T("RoleTaken"), Ui.C.red)
			end
		end, { LayoutOrder = i, ZIndex = 43 })
		if role == mine then
			Ui.setActive(b, true)
		end
		if Rules.APPOINTED[role] then
			b.TextColor3 = Ui.C.dim
		end
	end
end

function Client:openShop()
	local f, c, close = self:sheet(self:T("Shop"))
	local _ = f
	local owned = {}
	for _, id in string.split(player:GetAttribute("Owned") or "", ",") do
		owned[id] = true
	end
	local worn = {}
	for _, id in string.split(player:GetAttribute("Worn") or "", ",") do
		worn[id] = true
	end
	for i, s in Rules.SHOP do
		local row = Ui.frame(c, { BackgroundColor3 = Ui.C.panel, Size = UDim2.new(1, 0, 0, Ui.TAP + 8), LayoutOrder = i, ZIndex = 43 })
		Ui.corner(row, 6)
		Ui.label(row, self:T("shop_" .. s.id), { Size = UDim2.new(0.5, 0, 0, 22), Position = UDim2.fromOffset(10, 4), ZIndex = 44 })
		Ui.label(row, if owned[s.id] then self:T("Owned") else self:T("PriceFormat", s.price), { Size = UDim2.new(0.5, 0, 0, 18), Position = UDim2.fromOffset(10, 26), TextSize = 13, TextColor3 = Ui.C.gold, ZIndex = 44 })
		local text = if not owned[s.id] then self:T("Buy") elseif worn[s.id] then self:T("TakeOff") else self:T("Wear")
		Ui.button(row, text, function()
			local res
			if not owned[s.id] then
				res = request("Buy", s.id)
				if res and res.ok then
					self:toast(self:T("Bought"), Ui.C.good)
				elseif res and res.error == "gold" then
					self:toast(self:T("NotEnoughGold"), Ui.C.red)
				end
			else
				res = request("Wear", s.id, not worn[s.id])
			end
			close()
			task.wait(0.2)
			self:openShop()
		end, { Size = UDim2.new(0.42, 0, 1, -12), Position = UDim2.new(0.56, 0, 0, 6), ZIndex = 44, BackgroundColor3 = if owned[s.id] then Ui.C.panel2 else Ui.C.line })
	end
end

local function betRow(self, parent, order, onBet)
	local row = Ui.frame(parent, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Ui.TAP), LayoutOrder = order, ZIndex = 43 })
	local buttons = {}
	local current = Rules.BETS[1]
	for i, bet in Rules.BETS do
		local b = Ui.button(row, string.format("%d", bet), function()
			current = bet
			for j, x in buttons do
				Ui.setActive(x, Rules.BETS[j] == bet)
			end
			onBet(bet)
		end, { Size = UDim2.new(1 / #Rules.BETS, -6, 1, 0), Position = UDim2.new((i - 1) / #Rules.BETS, 3, 0, 0), ZIndex = 44 })
		buttons[i] = b
	end
	Ui.setActive(buttons[1], true)
	onBet(current)
end

function Client:openSlots()
	local _, c = self:sheet(self:T("p_slots"), nil, 400)
	Ui.label(c, self:T("Bet"), { TextColor3 = Ui.C.dim, LayoutOrder = 1, ZIndex = 43 })
	local bet = Rules.BETS[1]
	betRow(self, c, 2, function(b)
		bet = b
	end)
	local reels = Ui.label(c, "👑  ⚔️  🍎", { TextSize = 46, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 70), LayoutOrder = 3, ZIndex = 43 })
	local result = Ui.label(c, "", { TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 4, ZIndex = 43, TextColor3 = Ui.C.gold })
	local spinning = false
	Ui.button(c, self:T("Spin"), function()
		if spinning then
			return
		end
		spinning = true
		local res = request("Slots", bet)
		if not res or not res.ok then
			spinning = false
			result.Text = if res and res.error == "gold" then self:T("NotEnoughGold") else self:T("Failed")
			return
		end
		local syms = Rules.SLOT_SYMBOLS
		for k = 1, 12 do
			reels.Text = string.format("%s  %s  %s", SYMBOL[syms[math.random(1, 5)]], SYMBOL[syms[math.random(1, 5)]], SYMBOL[syms[math.random(1, 5)]])
			task.wait(0.05 + k * 0.01)
		end
		reels.Text = string.format("%s  %s  %s", SYMBOL[res.symbols[1]], SYMBOL[res.symbols[2]], SYMBOL[res.symbols[3]])
		result.Text = if res.win > 0 then self:T("SlotsWin", res.win) else self:T("SlotsLose")
		self:sound(Sounds.coin, 0.5)
		spinning = false
	end, { LayoutOrder = 5, ZIndex = 43, BackgroundColor3 = Ui.C.line, Font = Ui.FONT_BOLD })
end

function Client:openCoin()
	local _, c = self:sheet(self:T("p_coin"), nil, 400)
	Ui.label(c, self:T("Bet"), { TextColor3 = Ui.C.dim, LayoutOrder = 1, ZIndex = 43 })
	local bet = Rules.BETS[1]
	betRow(self, c, 2, function(b)
		bet = b
	end)
	local result = Ui.label(c, "", { TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3, ZIndex = 43, TextColor3 = Ui.C.gold, Size = UDim2.new(1, 0, 0, 40) })
	Ui.button(c, self:T("Flip"), function()
		local res = request("Coin", bet)
		if not res or not res.ok then
			result.Text = if res and res.error == "gold" then self:T("NotEnoughGold") else self:T("Failed")
			return
		end
		result.Text = if res.won then self:T("CoinWin", res.win) else self:T("CoinLose")
		self:sound(Sounds.coin, 0.5)
	end, { LayoutOrder = 4, ZIndex = 43, BackgroundColor3 = Ui.C.line, Font = Ui.FONT_BOLD })
end

local function otherPlayers()
	local list = {}
	for _, p in Players:GetPlayers() do
		if p ~= player and p:GetAttribute("InCastle") then
			table.insert(list, { id = p.UserId, title = p.DisplayName .. "  @" .. p.Name })
		end
	end
	return list
end

function Client:openKing()
	local _, c, close = self:sheet(self:T("KingPanel"))
	local o = 0
	local function n()
		o += 1
		return o
	end
	local alive = workspace:GetAttribute("CastleMinions") or 0
	Ui.label(c, self:T("GuardsFormat", alive, Rules.MINION_MAX), { TextColor3 = Ui.C.dim, LayoutOrder = n(), ZIndex = 43 })
	local last = workspace:GetAttribute("CastleSummonAt") or 0
	local left = Rules.MINION_COOLDOWN - (workspace:GetServerTimeNow() - last)
	local summonText = if last > 0 and left > 0 then self:T("Summon") .. "\n" .. self:T("CooldownFormat", math.ceil(left)) else self:T("Summon")
	Ui.button(c, summonText, function()
		local res = request("KingSummon")
		if res and not res.ok then
			if res.error == "cooldown" then
				self:toast(self:T("CooldownFormat", math.max(1, res.left or 0)), Ui.C.red)
			elseif res.error == "max" then
				self:toast(self:T("MaxGuards"), Ui.C.red)
			end
		end
		close()
	end, { LayoutOrder = n(), ZIndex = 43, BackgroundColor3 = Ui.C.line, Size = UDim2.new(1, 0, 0, Ui.TAP + 12) })
	Ui.button(c, self:T("Order"), function()
		close()
		self.orderMode = true
		self:toast(self:T("OrderHint"))
	end, { LayoutOrder = n(), ZIndex = 43 })
	Ui.button(c, self:T("Recall"), function()
		request("KingOrder", nil)
		close()
	end, { LayoutOrder = n(), ZIndex = 43 })
	local open = workspace:GetAttribute("CastlePassage") == true
	Ui.button(c, if open then self:T("ClosePassage") else self:T("PassageOpen"), function()
		request("KingPassage", not open)
		close()
	end, { LayoutOrder = n(), ZIndex = 43 })
	Ui.toggle(c, self:T("AllowGuards"), workspace:GetAttribute("CastleGuardsPassage") == true, self:T("On"), self:T("Off"), function(x)
		request("KingGuardsPassage", x)
	end, n())
	Ui.label(c, self:T("Appoint"), { TextColor3 = Ui.C.gold, Font = Ui.FONT_BOLD, LayoutOrder = n(), ZIndex = 43 })
	for _, entry in otherPlayers() do
		Ui.button(c, entry.title, function()
			Ui.choose(self.gui, entry.title, {
				{ id = "queen", title = self:T("MakeQueen") },
				{ id = "commander", title = self:T("MakeCommander") },
				{ id = "guard", title = self:T("MakeGuard") },
				{ id = "dismiss", title = self:T("Dismiss") },
				{ id = "jail", title = self:T("SendToJail") },
				{ id = "free", title = self:T("Release") },
			}, function(action)
				local res = request("KingAppoint", entry.id, action)
				self:toast(if res and res.ok then self:T("Done") else self:T("Failed"), if res and res.ok then Ui.C.good else Ui.C.red)
			end)
		end, { LayoutOrder = n(), ZIndex = 43 })
	end
	Ui.button(c, self:T("Abdicate"), function()
		request("Abdicate")
		close()
	end, { LayoutOrder = n(), ZIndex = 43, BackgroundColor3 = Ui.C.red })
end

-- ---------------------------------------------------------------------------
-- звуки: шаги по материалу, дождь, музыка

function Client:sound(id: string, volume: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = (volume or 0.5) * self.app.settings.volume
	s.Parent = workspace.CurrentCamera
	s:Play()
	Debris:AddItem(s, 5)
end

function Client:buildSounds()
	local steps = Instance.new("Sound")
	steps.Name = "CastleSteps"
	steps.SoundId = Sounds.steps
	steps.Looped = true
	steps.Volume = 0
	steps.Parent = workspace.CurrentCamera
	self.steps = steps
	local rain = Instance.new("Sound")
	rain.SoundId = Sounds.rain
	rain.Looped = true
	rain.Volume = 0
	rain.Parent = workspace.CurrentCamera
	rain:Play()
	self.rain = rain
	local music = Instance.new("Sound")
	music.Looped = true
	music.Parent = workspace.CurrentCamera
	self.music = music
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	table.insert(self.conns, RunService.Heartbeat:Connect(function()
		local s = self.app.settings
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		-- стандартный звук бега заменяем своим
		local running = root and root:FindFirstChild("Running")
		if running and running:IsA("Sound") then
			running.Volume = 0
		end
		local speed = if root then Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude else 0
		if hum and root and s.footsteps and speed > 1 and hum.FloorMaterial ~= Enum.Material.Air and hum.FloorMaterial ~= Enum.Material.Water then
			params.FilterDescendantsInstances = { char }
			local hit = workspace:Raycast(root.Position, Vector3.new(0, -6, 0), params)
			local mat = if hit then hit.Material else hum.FloorMaterial
			local st = STEP[mat] or STONE_STEP
			steps.PlaybackSpeed = st[1] * math.clamp(speed / 16, 0.6, 1.4)
			steps.Volume = st[2] * s.volume
			if not steps.IsPlaying then
				steps:Play()
			end
		elseif steps.IsPlaying then
			steps:Stop()
		end
		-- дождь слышно на улице, в замке тише
		local w = workspace:GetAttribute("CastleWeather")
		local wet = w == "Rain" or w == "Storm"
		local inside = false
		if wet and root then
			params.FilterDescendantsInstances = { char }
			inside = workspace:Raycast(root.Position, Vector3.new(0, 80, 0), params) ~= nil
		end
		local target = if wet then (if inside then 0.15 else 0.6) * (if w == "Storm" then 1.3 else 1) * s.volume else 0
		rain.Volume += (target - rain.Volume) * 0.05
		self.music.Volume = 0.5 * s.music
	end))
end

-- ---------------------------------------------------------------------------
-- события сервера, атрибуты, ввод

function Client:onMessage(msg)
	if type(msg) ~= "table" then
		return
	end
	if msg.type == "toast" then
		self:toast(self:T(msg.key, table.unpack(msg.args or {})))
	elseif msg.type == "announce" then
		local text = if msg.key then self:T(msg.key, table.unpack(msg.args or {})) else tostring(msg.text or "")
		self.banner.Text = text
		self.banner.Visible = true
		local token = {}
		self.bannerToken = token
		task.delay(5, function()
			if self.bannerToken == token then
				self.banner.Visible = false
			end
		end)
		local tc = TextChatService:FindFirstChild("TextChannels")
		local general = tc and tc:FindFirstChild("RBXGeneral")
		if general then
			pcall(function()
				(general :: TextChannel):DisplaySystemMessage((string.gsub(text, "\n", " ")))
			end)
		end
		self:sound(Sounds.open, 0.6)
	elseif msg.type == "open" then
		if msg.panel == "roles" then
			self:openRoles()
		elseif msg.panel == "shop" then
			self:openShop()
		elseif msg.panel == "slots" then
			self:openSlots()
		elseif msg.panel == "coin" then
			self:openCoin()
		end
	elseif msg.type == "book" then
		self:toast(self:T("Book" .. math.random(1, 3)), nil)
	elseif msg.type == "fx" then
		self:fx(msg.kind)
	end
end

function Client:fx(kind: string)
	if kind == "lightning" then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Brightness = 0.7
		cc.Parent = Lighting
		Debris:AddItem(cc, 0.15)
		task.delay(0.6, function()
			self:sound(Sounds.thunder, 0.8)
		end)
		return
	end
	if not self.app.settings.effects then
		return
	end
	if kind == "fireworks" then
		for k = 1, 10 do
			task.delay(k * 0.4, function()
				local p = Instance.new("Part")
				p.Anchored = true
				p.CanCollide = false
				p.Transparency = 1
				p.Size = Vector3.one
				p.Position = Vector3.new(math.random(-60, 60), math.random(70, 110), math.random(-140, -40))
				p.Parent = workspace
				local e = Instance.new("ParticleEmitter")
				e.Color = ColorSequence.new(Color3.fromHSV(math.random(), 0.8, 1))
				e.LightEmission = 1
				e.Speed = NumberRange.new(30, 45)
				e.SpreadAngle = Vector2.new(180, 180)
				e.Lifetime = NumberRange.new(1.2, 1.8)
				e.Drag = 3
				e.Acceleration = Vector3.new(0, -10, 0)
				e.Size = NumberSequence.new(0.8, 0)
				e.Rate = 0
				e.Parent = p
				e:Emit(120)
				self:sound("rbxasset://sounds/collide.wav", 0.4)
				Debris:AddItem(p, 3)
			end)
		end
	elseif kind == "confetti" then
		local cam = workspace.CurrentCamera
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.Transparency = 1
		p.Size = Vector3.new(30, 1, 30)
		p.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 15, 0))
		p.Parent = workspace
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 200, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 220, 80)) })
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Speed = NumberRange.new(5, 10)
		e.Lifetime = NumberRange.new(3, 4)
		e.RotSpeed = NumberRange.new(-200, 200)
		e.Size = NumberSequence.new(0.3)
		e.Rate = 0
		e.Parent = p
		e:Emit(250)
		Debris:AddItem(p, 5)
	end
end

function Client:watch()
	local function upd()
		self:refresh()
	end
	for _, a in { "Food", "Drink", "CastleRole" } do
		table.insert(self.conns, player:GetAttributeChangedSignal(a):Connect(upd))
	end
	for _, a in { "Inv", "Slots" } do
		table.insert(self.conns, player:GetAttributeChangedSignal(a):Connect(function()
			self:refreshInventory()
		end))
	end
	table.insert(self.conns, workspace:GetAttributeChangedSignal("CastleWeather"):Connect(function()
		self.weather:set({ weather = workspace:GetAttribute("CastleWeather") or "Clear", at = 0, auto = false, minutes = 5 })
	end))
	self.weather:set({ weather = workspace:GetAttribute("CastleWeather") or "Clear", at = 0, auto = false, minutes = 5 })
	local function music()
		local id = workspace:GetAttribute("CastleMusic") or ""
		if id == "" then
			self.music:Stop()
		else
			self.music.SoundId = id
			self.music:Play()
		end
	end
	table.insert(self.conns, workspace:GetAttributeChangedSignal("CastleMusic"):Connect(music))
	music()
	table.insert(self.conns, Remotes.event("Castle").OnClientEvent:Connect(function(msg)
		self:onMessage(msg)
	end))
	-- инвентарь: подсветка взятого в руку предмета
	local function charConns(char)
		table.insert(self.conns, char.ChildAdded:Connect(function(c)
			if c:IsA("Tool") then
				self:refreshInventory()
			end
		end))
		table.insert(self.conns, char.ChildRemoved:Connect(function(c)
			if c:IsA("Tool") then
				self:refreshInventory()
			end
		end))
		local hum = char:WaitForChild("Humanoid", 5)
		if hum then
			table.insert(self.conns, hum.HealthChanged:Connect(upd))
		end
		upd()
		self:refreshInventory()
	end
	if player.Character then
		task.spawn(charConns, player.Character)
	end
	table.insert(self.conns, player.CharacterAdded:Connect(charConns))
	-- золото
	task.spawn(function()
		local stats = player:WaitForChild("leaderstats", 30)
		local gold = stats and stats:WaitForChild("Gold", 30)
		if gold and self.gui.Parent then
			table.insert(self.conns, gold.Changed:Connect(upd))
			upd()
		end
	end)
	-- приказ стражникам: касание игрока
	table.insert(self.conns, UserInputService.InputBegan:Connect(function(input, processed)
		if not self.orderMode or processed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		local cam = workspace.CurrentCamera
		local pos = if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then cam.ViewportSize / 2 else Vector2.new(input.Position.X, input.Position.Y)
		local ray = cam:ViewportPointToRay(pos.X, pos.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
		local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
		local target = model and Players:GetPlayerFromCharacter(model)
		if target then
			self.orderMode = false
			request("KingOrder", target.UserId)
			self:toast(target.DisplayName, Ui.C.red)
		end
	end))
	-- полёт по команде админа и парящий жрец
	local flyVel: LinearVelocity? = nil
	local floatT = 0
	table.insert(self.conns, RunService.RenderStepped:Connect(function(dt)
		floatT += dt
		local decor = workspace:FindFirstChild("CastleDecor")
		if decor then
			for _, m in decor:GetChildren() do
				if m:IsA("Model") and m:GetAttribute("Float") then
					local base = m:GetAttribute("BaseCF")
					if not base then
						base = m:GetPivot()
						m:SetAttribute("BaseCF", base)
					end
					m:PivotTo(base * CFrame.new(0, math.sin(floatT * 0.8) * 0.8, 0) * CFrame.Angles(0, math.sin(floatT * 0.3) * 0.1, 0))
				end
			end
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if player:GetAttribute("Fly") and root and hum then
			if not flyVel or flyVel.Parent == nil then
				local att = root:FindFirstChild("FlyAtt") or Instance.new("Attachment", root)
				att.Name = "FlyAtt"
				flyVel = Instance.new("LinearVelocity")
				flyVel.Attachment0 = att :: Attachment
				flyVel.MaxForce = 1e6
				flyVel.Parent = root
			end
			local cam = workspace.CurrentCamera
			local move = hum.MoveDirection
			local v = Vector3.zero
			if move.Magnitude > 0.05 then
				local look = cam.CFrame.LookVector
				local flat = Vector3.new(look.X, 0, look.Z)
				local up = if flat.Magnitude > 0.01 and move:Dot(flat.Unit) > 0.3 then look.Y else 0
				v = (move + Vector3.new(0, up, 0)).Unit * 40
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) or hum.Jump then
				v += Vector3.new(0, 25, 0)
			end
			flyVel.VectorVelocity = v
		elseif flyVel then
			flyVel:Destroy()
			flyVel = nil
		end
	end))
end

function Client:applySettings()
	local s = self.app.settings
	if self.camera then
		self.camera.settings.sensitivity = s.sensitivity
		self.camera.settings.fov = s.fov
		self.camera.settings.bob = s.bob
	end
	Lighting.GlobalShadows = s.shadows
	local bloom = Lighting:FindFirstChild("CastleBloom")
	if bloom then
		(bloom :: BloomEffect).Enabled = s.effects
	end
end

function Client:destroy()
	for _, c in self.conns do
		c:Disconnect()
	end
	self.camera:destroy()
	self.weather:destroy()
	self.steps:Destroy()
	self.rain:Destroy()
	self.music:Destroy()
	self.gui:Destroy()
end

return Client
