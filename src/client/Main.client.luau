--!nonstrict
-- Клиент «The Labyrinth»: меню, интерфейс забега, фонарик, крадущийся шаг, предметы,
-- камера в шкафу, взгляд на Смотрителя, эффекты Гула, смерть и наблюдение, лавка, админ

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local Remotes = require(Shared.Roblox.Remotes)
local Lang = require(Shared.Lang)
local Rules = require(Shared.Rules)
local AdminCommands = require(Shared.AdminCommands)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local app = {
	lang = if string.sub(player.LocaleId or "", 1, 2) == "ru" then "ru" else "en",
	inMenu = true,
	coins = 0,
	inv = {},
	sneaking = false,
	dead = false,
	spectating = nil :: Player?,
	shake = 0,
	lastHp = 100,
}

local function T(key: string, ...)
	return Lang.t(app.lang, key, ...)
end

local function request(...)
	local ok, res = pcall(function(...)
		return Remotes.fn("Request"):InvokeServer(...)
	end, ...)
	return if ok then res else nil
end

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

-- тёмный отель: свет только от ламп и фонарика
Lighting.Ambient = Color3.fromRGB(14, 12, 12)
Lighting.OutdoorAmbient = Color3.fromRGB(0, 0, 0)
Lighting.Brightness = 0
Lighting.ClockTime = 0
Lighting.FogColor = Color3.fromRGB(4, 4, 5)
Lighting.FogStart = 30
Lighting.FogEnd = 150
pcall(function()
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
end)
local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "LabTint"
tint.Saturation = -0.15
tint.Contrast = 0.1
tint.Parent = Lighting

-- ---------------------------------------------------------------------------
-- экраны

local gui = Instance.new("ScreenGui")
gui.Name = "Labyrinth"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local hud = Ui.frame(gui, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
local overlay = Ui.frame(gui, { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Active = false })
local redFlash = Ui.frame(gui, { BackgroundColor3 = Color3.fromRGB(150, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6 })

local toastBox = Ui.frame(gui, { BackgroundTransparency = 1, Size = UDim2.new(0.9, 0, 0, 200), Position = UDim2.new(0.05, 0, 0.62, 0), ZIndex = 20 })
Ui.list(toastBox, 6)

local function toast(text: string, color: Color3?, seconds: number?)
	local l = Ui.label(toastBox, text, {
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 0.25,
		BackgroundColor3 = Ui.C.panel,
		TextColor3 = color or Ui.C.text,
		TextSize = 17,
		ZIndex = 21,
	})
	Ui.corner(l, 6)
	Ui.pad(l, 8)
	task.delay(seconds or 3, function()
		l:Destroy()
	end)
end

local banner = Ui.label(gui, "", { Font = Ui.TITLE, TextSize = 34, TextColor3 = Ui.C.gold, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0.22, 0), TextTransparency = 1, ZIndex = 22 })
local bannerStroke = Instance.new("UIStroke")
bannerStroke.Thickness = 2
bannerStroke.Transparency = 1
bannerStroke.Parent = banner
local function showBanner(text: string, seconds: number?)
	banner.Text = text
	banner.TextTransparency = 0
	bannerStroke.Transparency = 0.3
	task.delay(seconds or 3, function()
		if banner.Text == text then
			TweenService:Create(banner, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
			TweenService:Create(bannerStroke, TweenInfo.new(0.8), { Transparency = 1 }):Play()
		end
	end)
end

local function flashRed(strength: number)
	redFlash.BackgroundTransparency = 1 - strength
	TweenService:Create(redFlash, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()
end

-- ---------------------------------------------------------------------------
-- интерфейс забега

local top = Ui.label(hud, "", { Font = Ui.TITLE, TextSize = 24, TextColor3 = Ui.C.gold, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 44) })

local statusBox = Ui.frame(hud, { BackgroundTransparency = 0.35, Size = UDim2.fromOffset(210, 98), Position = UDim2.new(0, 12, 0, 44) })
Ui.corner(statusBox)
Ui.pad(statusBox, 8)
Ui.list(statusBox, 4)
local function bar(order: number, color: Color3)
	local back = Ui.frame(statusBox, { BackgroundColor3 = Color3.fromRGB(40, 36, 32), Size = UDim2.new(1, 0, 0, 20), LayoutOrder = order })
	Ui.corner(back, 4)
	local fill = Ui.frame(back, { BackgroundColor3 = color, Size = UDim2.fromScale(1, 1) })
	Ui.corner(fill, 4)
	local text = Ui.label(back, "", { Size = UDim2.fromScale(1, 1), TextSize = 13, Font = Ui.BOLD, ZIndex = 2 })
	return fill, text
end
local hpFill, hpText = bar(1, Color3.fromRGB(170, 40, 40))
local flFill, flText = bar(2, Color3.fromRGB(220, 200, 110))
local coinText = Ui.label(statusBox, "", { TextSize = 15, Font = Ui.BOLD, TextColor3 = Ui.C.gold, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left })

-- кнопки справа внизу: свет и крадущийся шаг
local actions = Ui.frame(hud, { BackgroundTransparency = 1, Size = UDim2.fromOffset(120, 2 * 64 + 10), Position = UDim2.new(1, -132, 1, -220) })
Ui.list(actions, 10)
local flashBtn, sneakBtn
local function refreshButtons()
	flashBtn.Text = T("Flash") .. (if player:GetAttribute("FlashOn") then "  ●" else "")
	sneakBtn.Text = if app.sneaking then T("Sneaking") else T("Sneak")
	sneakBtn.BackgroundColor3 = if app.sneaking then Ui.C.line else Ui.C.panel
end
flashBtn = Ui.button(actions, "", function()
	request("Flash")
end, { Size = UDim2.new(1, 0, 0, 60), TextSize = 18 })
local function setSneak(on: boolean)
	app.sneaking = on
	request("Sneak", on)
	refreshButtons()
end
sneakBtn = Ui.button(actions, "", function()
	setSneak(not app.sneaking)
end, { Size = UDim2.new(1, 0, 0, 60), TextSize = 18 })

-- предметы внизу слева: нажатие — использовать
local slotsBox = Ui.frame(hud, { BackgroundTransparency = 1, Size = UDim2.new(0, 6 * 76, 0, 70), Position = UDim2.new(0, 12, 1, -86) })
Ui.list(slotsBox, 6, true).HorizontalAlignment = Enum.HorizontalAlignment.Left
local SLOT_ORDER = { "battery", "plant", "whistle", "lockpick", "key", "fuse" }
local USABLE = { battery = true, plant = true, whistle = true }
local slotButtons = {}
for i, item in SLOT_ORDER do
	local b = Ui.button(slotsBox, "", function()
		if USABLE[item] and (app.inv[item] or 0) > 0 then
			request("Use", item)
		end
	end, { Size = UDim2.fromOffset(70, 66), TextSize = 12, LayoutOrder = i, TextWrapped = true, Visible = false })
	slotButtons[item] = b
end
local function refreshInv()
	for item, b in slotButtons do
		local n = app.inv[item] or 0
		b.Visible = n > 0
		b.Text = T("item_" .. item) .. "\n×" .. n
		b.TextColor3 = if USABLE[item] then Ui.C.text else Ui.C.dim
	end
	coinText.Text = T("Coins", app.coins)
end

local function refreshTop()
	local door = workspace:GetAttribute("Door") or 0
	local sector = workspace:GetAttribute("Sector") or 1
	top.Text = T("Door", door) .. "   ·   " .. T("Sector", sector)
end
workspace:GetAttributeChangedSignal("Door"):Connect(refreshTop)
workspace:GetAttributeChangedSignal("Sector"):Connect(refreshTop)

local function refreshBars()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hp = if hum then math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1) else 0
	hpFill.Size = UDim2.fromScale(hp, 1)
	hpText.Text = T("Health") .. "  " .. math.floor(hp * 100 + 0.5)
	local fl = (player:GetAttribute("Flash") or Rules.FLASH_MAX) / Rules.FLASH_MAX
	flFill.Size = UDim2.fromScale(math.clamp(fl, 0, 1), 1)
	flText.Text = T("Flash") .. "  " .. math.floor(fl * 100 + 0.5) .. "%"
end
player:GetAttributeChangedSignal("Flash"):Connect(refreshBars)
player:GetAttributeChangedSignal("FlashOn"):Connect(function()
	refreshBars()
	refreshButtons()
end)

-- ---------------------------------------------------------------------------
-- подписи кнопок у предметов на языке игрока

local function localizePrompt(d: Instance)
	if d:IsA("ProximityPrompt") then
		local kind = d:GetAttribute("Kind")
		if kind then
			d.ActionText = T("p_" .. kind, d:GetAttribute("Price") or 0)
		end
	end
end
local function localizeAll()
	for _, d in workspace:GetDescendants() do
		localizePrompt(d)
	end
end
workspace.DescendantAdded:Connect(localizePrompt)

-- ---------------------------------------------------------------------------
-- камера: от первого лица; в шкафу — сквозь щель; после смерти — за другими

local camera = workspace.CurrentCamera
local function firstPerson()
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 75
end

local hiddenEye = nil
player:GetAttributeChangedSignal("HiddenEye"):Connect(function()
	local eye = player:GetAttribute("HiddenEye")
	hiddenEye = if typeof(eye) == "CFrame" then eye else nil
	if not hiddenEye and not app.inMenu and not app.dead then
		firstPerson()
	end
end)

-- тело в первом лице скрыто (кроме рук), чтобы шляпы и волосы не лезли в камеру
local function hideHead(char: Model)
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Head" or d.Parent:IsA("Accessory")) then
			d.LocalTransparencyModifier = 1
		end
	end
end

-- ---------------------------------------------------------------------------
-- взгляд на Смотрителя: сервер знает, что на него смотрят

local seenAt: { [number]: number } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function checkWatchers()
	if app.dead or app.inMenu then
		return
	end
	local now = os.clock()
	for _, m in CollectionService:GetTagged("Watcher") do
		local id = m:GetAttribute("WatcherId")
		local head = m:FindFirstChild("Head")
		if id and head then
			local pos = head.Position
			local vp, onScreen = camera:WorldToViewportPoint(pos)
			local body = m:FindFirstChild("Body")
			local vp2, onScreen2 = camera:WorldToViewportPoint(body and body.Position or pos)
			if (onScreen and vp.Z > 0) or (onScreen2 and vp2.Z > 0) then
				local from = camera.CFrame.Position
				rayParams.FilterDescendantsInstances = { player.Character, m }
				local hit = workspace:Raycast(from, pos - from, rayParams)
				if not hit and (pos - from).Magnitude < 90 and now - (seenAt[id] or 0) > 0.12 then
					seenAt[id] = now
					task.spawn(request, "Seen", id)
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- смерть и наблюдение

local deathBox = Ui.frame(gui, { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 30 })
local deathTitle = Ui.label(deathBox, "", { Font = Ui.TITLE, TextSize = 48, TextColor3 = Ui.C.red, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0.25, 0), ZIndex = 31 })
local deathCause = Ui.label(deathBox, "", { TextSize = 20, Size = UDim2.new(0.9, 0, 0, 50), Position = UDim2.new(0.05, 0, 0.25, 70), ZIndex = 31 })
local spectBox = Ui.frame(gui, { BackgroundTransparency = 0.3, Size = UDim2.fromOffset(280, 96), Position = UDim2.new(0.5, -140, 1, -120), Visible = false, ZIndex = 30 })
Ui.corner(spectBox)
Ui.pad(spectBox, 6)
Ui.list(spectBox, 6)
local spectName = Ui.label(spectBox, "", { TextSize = 16, ZIndex = 31 })
local function alivePlayers()
	local list = {}
	for _, q in Players:GetPlayers() do
		if q ~= player and q:GetAttribute("Alive") and q.Character then
			table.insert(list, q)
		end
	end
	return list
end
local function spectate(step: number)
	local list = alivePlayers()
	if #list == 0 then
		spectName.Text = T("NewRun")
		return
	end
	local idx = table.find(list, app.spectating) or 0
	idx = (idx + step - 1) % #list + 1
	local q = list[idx]
	app.spectating = q
	local hum = q.Character:FindFirstChildOfClass("Humanoid")
	player.CameraMode = Enum.CameraMode.Classic
	camera.CameraType = Enum.CameraType.Custom
	if hum then
		camera.CameraSubject = hum
	end
	spectName.Text = T("Spectating", q.DisplayName)
end
Ui.button(spectBox, T("SpectateNext"), function()
	spectate(1)
end, { Size = UDim2.new(1, 0, 0, 44), ZIndex = 31 })

local function onDead(msg)
	app.dead = true
	hiddenEye = nil
	deathTitle.Text = T("Died")
	deathCause.Text = T("cause_" .. (msg.cause or "unknown")) .. "\n" .. T("DiedAt", msg.door or 0)
	deathBox.Visible = true
	hud.Visible = false
	task.delay(4, function()
		if app.dead then
			deathBox.Visible = false
			spectBox.Visible = true
			spectate(1)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- лавка в лифте

local shopBox = Ui.frame(gui, { BackgroundTransparency = 0.05, Size = UDim2.fromOffset(320, 330), Position = UDim2.new(0.5, -160, 0.5, -165), Visible = false, ZIndex = 40 })
Ui.corner(shopBox, 10)
Ui.pad(shopBox, 12)
Ui.list(shopBox, 8)
local shopTitle = Ui.label(shopBox, "", { Font = Ui.TITLE, TextSize = 24, TextColor3 = Ui.C.gold, Size = UDim2.new(1, 0, 0, 30), ZIndex = 41 })
local shopRows = {}
for i, item in Rules.SHOP do
	local b = Ui.button(shopBox, "", function()
		local r = request("Buy", item)
		if r and r.ok then
			toast(T("Found_" .. item, 1), Ui.C.good, 2)
		end
	end, { LayoutOrder = i + 1, ZIndex = 41 })
	shopRows[item] = b
end
local shopClose = Ui.button(shopBox, "", function()
	shopBox.Visible = false
end, { LayoutOrder = 10, ZIndex = 41, BackgroundColor3 = Ui.C.line })
local function openShop()
	shopTitle.Text = T("Shop") .. "   " .. T("Coins", app.coins)
	for item, b in shopRows do
		b.Text = T("item_" .. item) .. "   " .. T("Price", Rules.PRICES[item])
	end
	shopClose.Text = T("Close")
	shopBox.Visible = true
end

-- ---------------------------------------------------------------------------
-- сообщения сервера

Remotes.event("Game").OnClientEvent:Connect(function(msg)
	if msg.type == "toast" then
		toast(T(msg.key, table.unpack(msg.args or {})))
	elseif msg.type == "announce" then
		showBanner(T(msg.key, table.unpack(msg.args or {})), 3.5)
	elseif msg.type == "inv" then
		app.coins = msg.coins or 0
		app.inv = msg.inv or {}
		refreshInv()
		if shopBox.Visible then
			openShop()
		end
	elseif msg.type == "hum" then
		if msg.phase == "warn" then
			showBanner(T("HumWarn"), 3)
			app.shake = math.max(app.shake, 0.25)
			flashRed(0.2)
		elseif msg.phase == "rush" then
			app.shake = 1.2
		else
			app.shake = 0
		end
	elseif msg.type == "fx" then
		if msg.kind == "scare" then
			flashRed(0.6)
			app.shake = 0.6
			task.delay(0.5, function()
				app.shake = 0
			end)
		elseif msg.kind == "blood" then
			flashRed(0.75)
		end
	elseif msg.type == "ride" then
		app.shake = 0.35
		overlay.BackgroundTransparency = 0.4
		task.delay(7, function()
			app.shake = 0
			TweenService:Create(overlay, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()
		end)
	elseif msg.type == "dead" then
		onDead(msg)
	elseif msg.type == "results" then
		showBanner(T("Results", msg.door or 0), 6)
	elseif msg.type == "shop" then
		openShop()
	end
end)

-- ---------------------------------------------------------------------------
-- меню

local menu = Ui.frame(gui, { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), ZIndex = 50 })
local menuCol = Ui.frame(menu, { BackgroundTransparency = 1, Size = UDim2.fromOffset(300, 420), Position = UDim2.new(0.5, -150, 0.5, -210), ZIndex = 51 })
Ui.list(menuCol, 10)
local sheet = Ui.frame(gui, { BackgroundTransparency = 0.05, Size = UDim2.fromOffset(340, 360), Position = UDim2.new(0.5, -170, 0.5, -180), Visible = false, ZIndex = 60 })
Ui.corner(sheet, 10)
Ui.pad(sheet, 14)

local buildMenu
local function openHelp()
	sheet:ClearAllChildren()
	Ui.corner(sheet, 10)
	Ui.pad(sheet, 14)
	Ui.list(sheet, 8)
	local page = 1
	local head = Ui.label(sheet, "", { Font = Ui.TITLE, TextSize = 26, TextColor3 = Ui.C.gold, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1, ZIndex = 61 })
	local body = Ui.label(sheet, "", { TextSize = 17, Size = UDim2.new(1, 0, 0, 200), LayoutOrder = 2, ZIndex = 61, TextYAlignment = Enum.TextYAlignment.Top })
	local function show()
		head.Text = T("H" .. page .. "t")
		body.Text = T("H" .. page) .. "\n\n" .. page .. " / 6"
	end
	local row = Ui.frame(sheet, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 3, ZIndex = 61 })
	Ui.button(row, T("Back"), function()
		if page == 1 then
			sheet.Visible = false
		else
			page -= 1
			show()
		end
	end, { Size = UDim2.new(0.5, -4, 1, 0), ZIndex = 62 })
	Ui.button(row, T("Next"), function()
		if page == 6 then
			sheet.Visible = false
		else
			page += 1
			show()
		end
	end, { Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new(0.5, 4, 0, 0), ZIndex = 62, BackgroundColor3 = Ui.C.line })
	show()
	sheet.Visible = true
end

local function openSettings()
	sheet:ClearAllChildren()
	Ui.corner(sheet, 10)
	Ui.pad(sheet, 14)
	Ui.list(sheet, 10)
	Ui.label(sheet, T("Settings"), { Font = Ui.TITLE, TextSize = 26, TextColor3 = Ui.C.gold, Size = UDim2.new(1, 0, 0, 34), ZIndex = 61, LayoutOrder = 1 })
	Ui.label(sheet, T("Language"), { ZIndex = 61, LayoutOrder = 2 })
	local langRow = Ui.frame(sheet, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), ZIndex = 61, LayoutOrder = 3 })
	for i, l in { "en", "ru" } do
		Ui.button(langRow, string.upper(l), function()
			app.lang = l
			localizeAll()
			refreshInv()
			refreshTop()
			refreshBars()
			refreshButtons()
			buildMenu()
			openSettings()
		end, { Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new((i - 1) * 0.5, (i - 1) * 4, 0, 0), ZIndex = 62, BackgroundColor3 = if app.lang == l then Ui.C.line else Ui.C.panel })
	end
	Ui.label(sheet, T("Shadows"), { ZIndex = 61, LayoutOrder = 4 })
	Ui.button(sheet, if Lighting.GlobalShadows then T("On") else T("Off"), function()
		Lighting.GlobalShadows = not Lighting.GlobalShadows
		openSettings()
	end, { ZIndex = 62, LayoutOrder = 5 })
	Ui.button(sheet, T("Close"), function()
		sheet.Visible = false
	end, { ZIndex = 62, LayoutOrder = 6, BackgroundColor3 = Ui.C.line })
	sheet.Visible = true
end

local function play()
	app.inMenu = false
	menu.Visible = false
	sheet.Visible = false
	hud.Visible = not app.dead
	request("Play")
	if not app.dead then
		firstPerson()
	end
	refreshTop()
	refreshBars()
	refreshButtons()
	refreshInv()
end

function buildMenu()
	menuCol:ClearAllChildren()
	Ui.list(menuCol, 10)
	local title = Ui.label(menuCol, T("Title"), { Font = Ui.TITLE, TextSize = 56, TextColor3 = Ui.C.gold, Size = UDim2.new(1, 0, 0, 70), ZIndex = 52, LayoutOrder = 1 })
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Parent = title
	Ui.label(menuCol, T("Subtitle"), { TextColor3 = Ui.C.dim, ZIndex = 52, LayoutOrder = 2 })
	local status = request("Status")
	local best = if status and status.best then status.best else 0
	Ui.label(menuCol, T("Best", best), { Font = Ui.BOLD, TextColor3 = Ui.C.gold, ZIndex = 52, LayoutOrder = 3 })
	Ui.button(menuCol, T("Play"), play, { ZIndex = 52, LayoutOrder = 4, BackgroundColor3 = Ui.C.line, TextSize = 20 })
	Ui.button(menuCol, T("HowToPlay"), openHelp, { ZIndex = 52, LayoutOrder = 5 })
	Ui.button(menuCol, T("Settings"), openSettings, { ZIndex = 52, LayoutOrder = 6 })
	local langRow = Ui.frame(menuCol, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), ZIndex = 52, LayoutOrder = 7 })
	for i, l in { "en", "ru" } do
		Ui.button(langRow, string.upper(l), function()
			app.lang = l
			localizeAll()
			buildMenu()
		end, { Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new((i - 1) * 0.5, (i - 1) * 4, 0, 0), ZIndex = 53, BackgroundColor3 = if app.lang == l then Ui.C.line else Ui.C.panel })
	end
end

local menuBtn = Ui.button(hud, "≡", function()
	app.inMenu = true
	menu.Visible = true
	hud.Visible = false
	buildMenu()
end, { Size = UDim2.fromOffset(46, 40), Position = UDim2.new(1, -58, 0, 44), TextSize = 22 })
local _ = menuBtn

-- ---------------------------------------------------------------------------
-- админ-панель (только создателям)

task.spawn(function()
	local ok, res = pcall(function()
		return Remotes.fn("AdminRequest"):InvokeServer("Status")
	end)
	if not ok or not res or not res.admin then
		return
	end
	local panel = Ui.frame(gui, { BackgroundTransparency = 0.05, Size = UDim2.fromOffset(300, 420), Position = UDim2.new(1, -312, 0, 92), Visible = false, ZIndex = 70 })
	Ui.corner(panel, 10)
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 6
	scroll.ZIndex = 71
	scroll.Parent = panel
	Ui.pad(scroll, 8)
	Ui.list(scroll, 6)
	local function fill()
		for _, c in scroll:GetChildren() do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		for i, c in AdminCommands.LIST do
			Ui.button(scroll, if app.lang == "ru" then c.ru else c.en, function()
				local r = Remotes.fn("AdminRequest"):InvokeServer("Run", c.id)
				toast(if r and r.ok then T("Done") else T("Failed"), if r and r.ok then Ui.C.good else Ui.C.red, 2)
			end, { LayoutOrder = i, ZIndex = 72, Size = UDim2.new(1, -4, 0, 42), TextSize = 15 })
		end
	end
	local btn = Ui.button(gui, T("Admin"), function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			fill()
		end
	end, { Size = UDim2.fromOffset(70, 32), Position = UDim2.new(1, -82, 0, 6), TextSize = 13, ZIndex = 75, TextColor3 = Ui.C.gold })
	local _ = btn
end)

-- ---------------------------------------------------------------------------
-- клавиатура: F — свет, C — тихо, 1/2/3 — батарейка, растение, свисток

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or app.inMenu or app.dead then
		return
	end
	local k = input.KeyCode
	if k == Enum.KeyCode.F then
		request("Flash")
	elseif k == Enum.KeyCode.C or k == Enum.KeyCode.LeftControl then
		setSneak(not app.sneaking)
	elseif k == Enum.KeyCode.One then
		request("Use", "battery")
	elseif k == Enum.KeyCode.Two then
		request("Use", "plant")
	elseif k == Enum.KeyCode.Three then
		request("Use", "whistle")
	end
end)

-- ---------------------------------------------------------------------------
-- новый персонаж (начало забега)

local function onCharacter(char: Model)
	app.dead = false
	app.spectating = nil
	app.sneaking = false
	hiddenEye = nil
	deathBox.Visible = false
	spectBox.Visible = false
	shopBox.Visible = false
	local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
	if hum then
		camera.CameraSubject = hum
		hum.HealthChanged:Connect(function(h)
			refreshBars()
			if h < (app.lastHp or 100) - 1 then
				flashRed(0.35)
			end
			app.lastHp = h
		end)
		app.lastHp = hum.Health
	end
	if not app.inMenu then
		hud.Visible = true
		firstPerson()
	end
	char.DescendantAdded:Connect(function()
		task.defer(hideHead, char)
	end)
	hideHead(char)
	refreshBars()
	refreshButtons()
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

-- кадр: меню, шкаф, тряска, Смотритель
local watchT = 0
RunService.RenderStepped:Connect(function(dt)
	if app.inMenu then
		camera.CameraType = Enum.CameraType.Scriptable
		local t = os.clock() * 0.15
		camera.CFrame = CFrame.new(math.sin(t) * 6, 7, -6) * CFrame.Angles(0, math.sin(t * 0.7) * 0.25, 0) * CFrame.Angles(-0.08, 0, 0)
		camera.FieldOfView = 70
		return
	end
	if hiddenEye then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = hiddenEye
	elseif camera.CameraType == Enum.CameraType.Scriptable and not app.dead then
		firstPerson()
	end
	if app.shake > 0 then
		local a = app.shake * 0.04
		camera.CFrame *= CFrame.Angles((math.random() - 0.5) * a, (math.random() - 0.5) * a, 0)
	end
	watchT += dt
	if watchT > 0.1 then
		watchT = 0
		checkWatchers()
	end
	if app.dead and app.spectating and not app.spectating:GetAttribute("Alive") then
		spectate(1)
	end
end)

buildMenu()
localizeAll()
refreshInv()
refreshTop()
