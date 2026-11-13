--!nonstrict
-- Главное меню мастерской: мои карты, новая карта, демосцена, каталог и вход по коду

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local UiText = require(Shared.UiText)
local Remotes = require(Shared.Roblox.Remotes)
local Kit = require(script.Parent.Kit)

local L, H = UiText.L, UiText.H

local Menu = {}
Menu.__index = Menu

local ERRORS = {
	not_found = H.NotFoundHint,
	bad_code = H.CodeHint,
	load_failed = H.LoadFailedHint,
}

function Menu.new(app)
	local self = setmetatable({}, Menu)
	self.app = app
	local gui = Instance.new("ScreenGui")
	gui.Name = "WsMenu"
	gui.ResetOnSpawn = false
	gui.Parent = app.playerGui
	self.gui = gui
	local bg = Kit.frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Kit.C.bg, BackgroundTransparency = 0.15 })
	local v = Kit.viewport()
	local w = math.min(720, v.X - 24)
	local box = Kit.frame(bg, { Size = UDim2.new(0, w, 1, -40), Position = UDim2.new(0.5, -w / 2, 0, 20), BackgroundTransparency = 1 })
	-- название и подзаголовок — двумя строками
	Kit.label(box, L.AppTitle, { Font = Kit.FONT_BOLD, TextSize = 30, Size = UDim2.new(1, 0, 0, 38) })
	Kit.label(box, L.AppSubtitle, { TextColor3 = Kit.C.dim, TextSize = 16, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 22) })

	local actions = Kit.frame(box, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(if Kit.compact() then 0.5 else 0.25, -6, 0, 56)
	g.CellPadding = UDim2.fromOffset(6, 6)
	g.Parent = actions
	Kit.button(actions, L.NewMap, function()
		self:createMap(nil)
	end, { BackgroundColor3 = Kit.C.accent })
	Kit.button(actions, L.Mafia, function()
		self.app:joinMafia()
	end, { BackgroundColor3 = Color3.fromRGB(120, 30, 40) })
	Kit.button(actions, L.NewDemo, function()
		self:createMap("demo")
	end)
	Kit.button(actions, L.Catalog, function()
		self:showCatalog()
	end)
	Kit.button(actions, L.EnterCode, function()
		self:enterCode()
	end)

	-- витрина включена: создатель видит её название и может выключить или открыть
	self.showcaseBanner = Kit.frame(box, {
		Position = UDim2.new(0, 0, 1, -(Kit.TAP * 2 + 34)), Size = UDim2.new(1, 0, 0, Kit.TAP * 2 + 30),
		BackgroundColor3 = Kit.C.accentDim, Visible = false, ZIndex = 5,
	})
	Kit.corner(self.showcaseBanner, 10)
	Kit.pad(self.showcaseBanner, 8)
	self.showcaseTitle = Kit.label(self.showcaseBanner, "", { Font = Kit.FONT_BOLD, Size = UDim2.new(1, 0, 0, 40), ZIndex = 6 })
	Kit.button(self.showcaseBanner, L.ShowcaseOpen, function()
		self.app:openShowcase()
	end, { Size = UDim2.new(0.5, -4, 0, Kit.TAP), Position = UDim2.new(0, 0, 1, -Kit.TAP), ZIndex = 6 })
	Kit.button(self.showcaseBanner, L.ShowcaseTurnOff, function()
		local r = Remotes.fn("Request"):InvokeServer("SetShowcase", nil)
		if r and r.ok then
			self.app.mode.showcase = nil
			self:updateShowcase()
		end
	end, { Size = UDim2.new(0.5, -4, 0, Kit.TAP), Position = UDim2.new(0.5, 4, 1, -Kit.TAP), ZIndex = 6, BackgroundColor3 = Kit.C.bad })

	-- создатель может сделать «Мафию» тем, что видят все вместо меню
	self.mafiaShowcase = Kit.button(box, L.ShowcaseMafia, function()
		local r = Remotes.fn("Request"):InvokeServer("SetShowcase", "MAFIA")
		if r and r.ok then
			Kit.toast(self.gui, L.ShowcaseSetDone, Kit.C.good)
		end
	end, { Size = UDim2.fromOffset(220, 52), Position = UDim2.new(1, -220, 0, 0), Visible = false, TextSize = 13, BackgroundColor3 = Color3.fromRGB(120, 30, 40) })

	self.nameBox = Kit.textbox(box, "", L.MapNamePlaceholder, nil, { Position = UDim2.fromOffset(0, if Kit.compact() then 200 else 140), Size = UDim2.new(1, 0, 0, Kit.TAP) })
	local listTop = if Kit.compact() then 252 else 192
	self.mapsTitle = Kit.label(box, L.MyMaps, { Font = Kit.FONT_BOLD, TextSize = 18, Position = UDim2.fromOffset(0, listTop), Size = UDim2.new(1, 0, 0, 26) })
	self.listTop = listTop + 32
	self.list = Kit.scroll(box, { Position = UDim2.fromOffset(0, listTop + 32), Size = UDim2.new(1, 0, 1, -(listTop + 32)) })
	Kit.list(self.list, 6)
	self:refresh()
	return self
end

function Menu:refresh()
	for _, c in self.list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	Kit.label(self.list, L.Loading, { TextColor3 = Kit.C.dim })
	task.spawn(function()
		local res = Remotes.fn("Request"):InvokeServer("ListProjects")
		for _, c in self.list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		if not res or not res.ok then
			-- ошибка загрузки показывается как ошибка, а не как пустой список
			Kit.label(self.list, H.LoadFailedHint, { TextColor3 = Kit.C.bad, Size = UDim2.new(1, 0, 0, 44) })
			return
		end
		if #res.projects == 0 then
			Kit.label(self.list, H.EmptyMaps, { TextColor3 = Kit.C.dim, Size = UDim2.new(1, 0, 0, 44) })
			return
		end
		self.mapsTitle.Text = L.MyMaps .. "   " .. string.format(L.SavesCount, #res.projects, 10)
		for i, p in res.projects do
			local sub = if p.publishCode then string.format(L.PublishedAs, p.publishCode) else nil
			local text = p.name
			if sub then
				text = p.name .. "\n" .. string.gsub(sub, "\n", " ")
			end
			local row = Kit.frame(self.list, { BackgroundTransparency = 1, LayoutOrder = i, Size = UDim2.new(1, -8, 0, 56) })
			Kit.button(row, text, function()
				self.app:openProject(p.id)
			end, { Size = UDim2.new(1, -62, 1, 0), TextXAlignment = Enum.TextXAlignment.Left })
			Kit.button(row, "✕", function()
				Kit.choose(self.gui, L.Delete .. "\n" .. p.name, {
					{ id = "yes", title = L.Delete },
					{ id = "no", title = L.Cancel },
				}, function(choice)
					if choice == "yes" then
						Remotes.fn("Request"):InvokeServer("DeleteProject", p.id)
						self:refresh()
					end
				end)
			end, { Size = UDim2.new(0, 56, 1, 0), Position = UDim2.new(1, -56, 0, 0), BackgroundColor3 = Kit.C.bad })
		end
	end)
end

function Menu:createMap(template: string?)
	local name = self.nameBox.Text
	if name == "" then
		name = if template == "demo" then L.DemoMapName else L.NewMap
	end
	local res = Remotes.fn("Request"):InvokeServer("CreateProject", name, template)
	if res and res.ok then
		self.app:openEditor(res.project, res.readOnly)
	elseif res and res.error == "name_taken" then
		Kit.toast(self.gui, H.NameTakenHint, Kit.C.bad, 4)
	elseif res and res.error == "too_many_projects" then
		Kit.toast(self.gui, H.TooManyHint, Kit.C.bad, 4)
	else
		Kit.toast(self.gui, H.LoadFailedHint, Kit.C.bad)
	end
end

function Menu:showCatalog()
	local res = Remotes.fn("Request"):InvokeServer("ListCatalog")
	if not res or not res.ok then
		Kit.toast(self.gui, H.LoadFailedHint, Kit.C.bad)
		return
	end
	local opts = {}
	for _, e in res.entries do
		table.insert(opts, { id = e.code, title = e.name, hint = e.code })
	end
	if #opts == 0 then
		Kit.toast(self.gui, L.NothingHere)
		return
	end
	Kit.choose(self.gui, L.Catalog, opts, function(code)
		self.app:joinByCode(code)
	end)
end

function Menu:enterCode()
	local shade = Kit.frame(self.gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 40 })
	local w = math.min(380, Kit.viewport().X - 32)
	local box = Kit.frame(shade, { Size = UDim2.fromOffset(w, 200), Position = UDim2.new(0.5, -w / 2, 0.3, 0), ZIndex = 41 })
	Kit.corner(box, 12)
	Kit.pad(box, 12)
	Kit.label(box, L.EnterCode, { Font = Kit.FONT_BOLD, TextSize = 18, ZIndex = 42 })
	Kit.label(box, H.CodeHint, { TextColor3 = Kit.C.dim, TextSize = 13, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 36), ZIndex = 42 })
	local t = Kit.textbox(box, "", L.CodePlaceholder, nil, { Position = UDim2.fromOffset(0, 68), ZIndex = 42, TextXAlignment = Enum.TextXAlignment.Center, TextSize = 22 })
	Kit.button(box, L.Cancel, function()
		shade:Destroy()
	end, { Size = UDim2.new(0.5, -4, 0, Kit.TAP), Position = UDim2.new(0, 0, 1, -Kit.TAP), ZIndex = 42 })
	Kit.button(box, L.Play, function()
		local code = t.Text
		shade:Destroy()
		self.app:joinByCode(code)
	end, { Size = UDim2.new(0.5, -4, 0, Kit.TAP), Position = UDim2.new(0.5, 4, 1, -Kit.TAP), ZIndex = 42, BackgroundColor3 = Kit.C.accent })
end

function Menu:updateShowcase()
	local mode = self.app.mode or {}
	local sc = mode.showcase
	self.showcaseBanner.Visible = sc ~= nil and mode.creator == true
	self.mafiaShowcase.Visible = mode.creator == true and (sc == nil or sc.code ~= "MAFIA")
	local extra = if self.showcaseBanner.Visible then Kit.TAP * 2 + 42 else 0
	self.list.Size = UDim2.new(1, 0, 1, -(self.listTop + extra))
	if sc then
		self.showcaseTitle.Text = string.format(L.ShowcaseOnTitle, sc.name or sc.code)
	end
end

function Menu:showError(code: string?)
	Kit.toast(self.gui, ERRORS[code or ""] or H.LoadFailedHint, Kit.C.bad)
end

function Menu:setVisible(v: boolean)
	self.gui.Enabled = v
	if v then
		self:refresh()
		self:updateShowcase()
	end
end

return Menu
