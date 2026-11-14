--!nonstrict
-- Маленькая кнопка «Админ» и панель команд. Видна только создателям; каждую команду
-- сервер всё равно проверяет сам

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local Commands = require(Shared.AdminCommands)
local Remotes = require(Shared.Roblox.Remotes)
local Util = require(Shared.Util)

local Ui = require(script.Parent.Ui)

local AdminPanel = {}

local function request(...)
	local ok, res = pcall(function(...)
		return Remotes.fn("AdminRequest"):InvokeServer(...)
	end, ...)
	return if ok then res else nil
end

function AdminPanel.mount(app)
	local res = request("Status")
	if not res or not res.admin then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "CastleAdmin"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 30
	gui.Parent = app.playerGui
	local inset = GuiService.TopbarInset
	-- небольшая, но удобная для пальца кнопка рядом с верхней панелью Roblox
	local btn = Ui.button(gui, "", nil, {
		Size = UDim2.fromOffset(64, 30),
		-- справа вверху: слева кнопки Roblox, там кнопка пряталась под ними
		Position = UDim2.new(1, -76, 0, math.max(6, inset.Min.Y + (inset.Height - 30) / 2)),
		TextSize = 13,
		Font = Ui.FONT_BOLD,
		TextColor3 = Ui.C.gold,
		BackgroundTransparency = 0.2,
	})
	local function label()
		btn.Text = app.T("Admin")
	end
	label()
	app.onLangChanged = app.onLangChanged or {}
	table.insert(app.onLangChanged, label)

	local function run(cmd, targetId, arg)
		local r = request("Run", cmd.id, targetId, arg)
		Ui.toast(gui, if r and r.ok then app.T("Done") else app.T("Failed"), if r and r.ok then Ui.C.good else Ui.C.red, 2)
	end

	local function title(cmd)
		return if app.lang == "ru" then cmd.ru else cmd.en
	end

	local function argTitle(cmd, v)
		if cmd.id == "season" then
			return app.T("season_" .. v)
		elseif cmd.id == "weather" then
			return app.T("weather_" .. v)
		elseif cmd.id == "set_role" then
			return app.T("role_" .. v)
		elseif cmd.id == "give_item" then
			return app.T("item_" .. v)
		end
		return v
	end

	local function withArg(cmd, targetId)
		if cmd.arg == nil then
			run(cmd, targetId, nil)
		elseif type(cmd.arg) == "table" then
			local opts = {}
			for _, v in cmd.arg do
				table.insert(opts, { id = v, title = argTitle(cmd, v) })
			end
			Ui.choose(gui, title(cmd), opts, function(v)
				run(cmd, targetId, v)
			end)
		else
			Ui.prompt(gui, title(cmd) .. "\n" .. app.T("Value"), app.T("Run"), function(text)
				run(cmd, targetId, if cmd.arg == "number" then tonumber(text) else text)
			end)
		end
	end

	local function start(cmd)
		if cmd.target == "player" then
			local opts = {}
			for _, p in Players:GetPlayers() do
				table.insert(opts, { id = p.UserId, title = p.DisplayName .. "  @" .. p.Name })
			end
			Ui.choose(gui, app.T("ChoosePlayer"), opts, function(id)
				withArg(cmd, id)
			end)
		else
			withArg(cmd, nil)
		end
	end

	btn.Activated:Connect(function()
		if app.castle then
			app.castle.camera:setFreeCursor(true)
		end
		local _, content = Ui.sheet(gui, app.T("AdminTitle"), function()
			if app.castle then
				app.castle.camera:setFreeCursor(false)
			end
		end, 460)
		local search = Instance.new("TextBox")
		search.PlaceholderText = app.T("Search")
		search.Text = ""
		search.ClearTextOnFocus = false
		search.Font = Ui.FONT
		search.TextSize = 16
		search.TextColor3 = Ui.C.text
		search.PlaceholderColor3 = Ui.C.dim
		search.BackgroundColor3 = Ui.C.panel
		search.Size = UDim2.new(1, 0, 0, Ui.TAP)
		search.LayoutOrder = 0
		search.ZIndex = 43
		Ui.corner(search, 6)
		Ui.stroke(search)
		search.Parent = content
		-- разделы: мир, игроки, порядок, веселье, силы Бога
		local tabs = Ui.frame(content, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Ui.TAP), LayoutOrder = 1, ZIndex = 43 })
		local tl = Ui.list(tabs, 4, true)
		tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		local current = "world"
		local tabButtons = {}
		local buttons = {}
		local function filter()
			local q = Util.lower(search.Text)
			for cmd, b in buttons do
				local match = q ~= "" and (string.find(string.lower(cmd.en), q, 1, true) ~= nil or string.find(Util.lower(cmd.ru), q, 1, true) ~= nil or string.find(cmd.id, q, 1, true) ~= nil)
				b.Visible = if q ~= "" then match else cmd.cat == current
			end
			for cat, tb in tabButtons do
				Ui.setActive(tb, cat == current and q == "")
			end
		end
		local n = #Commands.CATEGORIES
		for i, cat in Commands.CATEGORIES do
			local tb = Ui.button(tabs, app.T("cat_" .. cat), function()
				current = cat
				search.Text = ""
				filter()
			end, { Size = UDim2.new(1 / n, -4, 1, 0), LayoutOrder = i, TextSize = 13, ZIndex = 44, TextColor3 = if cat == "god" then Ui.C.gold else Ui.C.text })
			tabButtons[cat] = tb
		end
		for i, cmd in Commands.LIST do
			local b = Ui.button(content, title(cmd), function()
				start(cmd)
			end, { LayoutOrder = 10 + i, ZIndex = 43, TextXAlignment = Enum.TextXAlignment.Left })
			Ui.pad(b, 10)
			if cmd.cat == "god" then
				b.TextColor3 = Ui.C.gold
				b.BackgroundColor3 = Color3.fromRGB(60, 46, 26)
			end
			buttons[cmd] = b
		end
		search:GetPropertyChangedSignal("Text"):Connect(filter)
		filter()
	end)
end

return AdminPanel
