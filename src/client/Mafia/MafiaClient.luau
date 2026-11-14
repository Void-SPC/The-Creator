--!nonstrict
-- Клиент «Мафии»: лобби с выбором стиля, своя роль, таймер фаз, голосования,
-- ночные действия, блокнот шерифа, переключатель чатов, панель ведущего, вид призрака

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local UiText = require(Shared.UiText)
local Remotes = require(Shared.Roblox.Remotes)
local MafiaSounds = require(Shared.MafiaSounds)

local Kit = require(script.Parent.Parent.UI.Kit)
local FreeCamera = require(script.Parent.Parent.Common.FreeCamera)
local WeatherFx = require(script.Parent.Parent.Common.WeatherFx)

local L, H = UiText.L, UiText.H

local MafiaClient = {}
MafiaClient.__index = MafiaClient

local player = Players.LocalPlayer

local PHASE_TITLE = {
	lobby = L.PhaseLobby, reveal = L.PhaseReveal, dusk = L.PhaseDusk, night = L.PhaseNight,
	morning = L.PhaseMorning, day = L.PhaseDay, vote = L.PhaseVote, verdict = L.PhaseVerdict, ended = L.PhaseEnded,
}
local ROLE_TITLE = { mafia = L.RoleMafia, doctor = L.RoleDoctor, sheriff = L.RoleSheriff, civilian = L.RoleCivilian }
local ROLE_HINT = { mafia = H.MafiaRoleHint, doctor = H.DoctorRoleHint, sheriff = H.SheriffRoleHint, civilian = H.CivilianRoleHint }
local ROLE_COLOR = {
	mafia = Color3.fromRGB(170, 40, 50), doctor = Color3.fromRGB(60, 160, 110),
	sheriff = Color3.fromRGB(70, 110, 200), civilian = Color3.fromRGB(110, 110, 120),
}
local CLOCK = { lobby = 14, reveal = 19, dusk = 19.5, night = 0, morning = 6.5, day = 13, vote = 16, verdict = 17.5, ended = 14 }

local function request(...)
	local ok, res = pcall(function(...)
		return Remotes.fn("MafiaRequest"):InvokeServer(...)
	end, ...)
	return if ok then res else nil
end

function MafiaClient.new(app)
	local self = setmetatable({}, MafiaClient)
	self.app = app
	self.state = {}
	self.notes = ""
	local gui = Instance.new("ScreenGui")
	gui.Name = "WsMafia"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = app.playerGui
	self.gui = gui
	self.weather = WeatherFx.new()

	-- фаза и таймер: название и время двумя строками
	self.phaseBox = Kit.frame(gui, { Size = UDim2.fromOffset(170, 52), Position = UDim2.new(0.5, -85, 0, 6), BackgroundTransparency = 0.25, BackgroundColor3 = Kit.C.bg })
	Kit.corner(self.phaseBox, 12)
	self.phaseLabel = Kit.label(self.phaseBox, "", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Font = Kit.FONT_BOLD, TextSize = 16 })
	-- своя роль
	self.roleChip = Kit.button(gui, "", function()
		self:showRoleCard()
	end, { Size = UDim2.fromOffset(150, 40), Position = UDim2.new(0.5, -75, 0, 62), TextSize = 14, Visible = false })
	-- крупное объявление
	self.banner = Kit.label(gui, "", {
		Size = UDim2.new(0.8, 0, 0, 90), Position = UDim2.new(0.1, 0, 0.22, 0), TextXAlignment = Enum.TextXAlignment.Center,
		Font = Kit.FONT_BOLD, TextSize = 28, TextStrokeTransparency = 0.3, Visible = false,
	})
	-- переключатель чатов слева
	self.chatBar = Kit.frame(gui, { BackgroundTransparency = 1, Size = UDim2.fromOffset(110, 3 * (Kit.TAP + 4)), Position = UDim2.new(0, 6, 0.42, 0) })
	Kit.list(self.chatBar, 4)
	self.chatButtons = {}
	for i, ch in { { "general", L.ChatTown, "MafiaTown" }, { "mafia", L.ChatMafia, "MafiaRoom" }, { "ghost", L.ChatGhost, "GhostRoom" } } do
		self.chatButtons[ch[1]] = Kit.button(self.chatBar, ch[2], function()
			self:setChannel(ch[3], ch[1])
		end, { Size = UDim2.new(1, 0, 0, Kit.TAP), LayoutOrder = i, TextSize = 13, Visible = false, BackgroundTransparency = 0.2 })
	end
	-- нижняя панель: лобби, голосование, ночные действия
	self.sheet = Kit.frame(gui, { Size = UDim2.new(0, math.min(520, Kit.viewport().X - 24), 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 0.08 })
	Kit.corner(self.sheet, 14)
	Kit.pad(self.sheet, 10)
	-- кнопки справа: блокнот шерифа и панель ведущего
	self.side = Kit.frame(gui, { BackgroundTransparency = 1, Size = UDim2.fromOffset(120, 2 * (Kit.TAP + 4)), Position = UDim2.new(1, -126, 0.42, 0) })
	Kit.list(self.side, 4)
	self.noteButton = Kit.button(self.side, L.Notebook, function()
		self:openNotebook()
	end, { Size = UDim2.new(1, 0, 0, Kit.TAP), LayoutOrder = 1, Visible = false, TextSize = 13 })
	self.hostButton = Kit.button(self.side, L.HostPanel, function()
		self:openHostPanel()
	end, { Size = UDim2.new(1, 0, 0, Kit.TAP), LayoutOrder = 2, Visible = false, TextSize = 13, BackgroundColor3 = Kit.C.accentDim })

	self.conn = Remotes.event("Mafia").OnClientEvent:Connect(function(msg)
		self:onMessage(msg)
	end)
	self.tick = RunService.Heartbeat:Connect(function()
		self:updateTimer()
	end)
	return self
end

-- ---------------------------------------------------------------------------

function MafiaClient:sound(key: string?)
	local id = key and MafiaSounds[key]
	if not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = 0.6
	s.Parent = SoundService
	s.Ended:Once(function()
		s:Destroy()
	end)
	s:Play()
	task.delay(15, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

function MafiaClient:announce(text: string)
	self.banner.Text = text
	self.banner.Visible = true
	local token = {}
	self.bannerToken = token
	task.delay(4, function()
		if self.bannerToken == token then
			self.banner.Visible = false
		end
	end)
	-- то же сообщение в чате как системное
	local tc = TextChatService:FindFirstChild("TextChannels")
	local town = tc and tc:FindFirstChild("MafiaTown")
	if town then
		pcall(function()
			(town :: TextChannel):DisplaySystemMessage((string.gsub(text, "\n", " ")))
		end)
	end
end

function MafiaClient:updateTimer()
	local st = self.state
	local title = PHASE_TITLE[st.phase or "lobby"] or ""
	if st.phase and st.phase ~= "lobby" and st.endsAt then
		local left = math.max(0, math.floor(st.endsAt - workspace:GetServerTimeNow()))
		self.phaseLabel.Text = string.format("%s\n%d:%02d", title, left // 60, left % 60)
	else
		self.phaseLabel.Text = title
	end
end

function MafiaClient:setChannel(name: string, key: string)
	local tc = TextChatService:FindFirstChild("TextChannels")
	local c = tc and tc:FindFirstChild(name)
	if c then
		pcall(function()
			TextChatService.ChatInputBarConfiguration.TargetTextChannel = c
		end)
	end
	self.channel = key
	for k, b in self.chatButtons do
		Kit.setActive(b, k == key)
	end
end

function MafiaClient:applyChat()
	local chat = self.state.chat or {}
	local firstSend = nil
	for key, b in self.chatButtons do
		local rights = chat[key]
		b.Visible = rights ~= nil and rights.see == true
		if rights and rights.send and not firstSend then
			firstSend = key
		end
	end
	pcall(function()
		TextChatService.ChannelTabsConfiguration.Enabled = true
	end)
	local cur = self.channel and chat[self.channel]
	if not cur or not cur.send then
		local key = firstSend or "general"
		local names = { general = "MafiaTown", mafia = "MafiaRoom", ghost = "GhostRoom" }
		self:setChannel(names[key], key)
	end
end

-- ---------------------------------------------------------------------------
-- мир: время суток, окна, погода, крыши для призраков

function MafiaClient:applyWorld()
	local st = self.state
	local clock = CLOCK[st.phase or "lobby"] or 14
	TweenService:Create(Lighting, TweenInfo.new(3), { ClockTime = clock }):Play()
	local village = workspace:FindFirstChild("MafiaVillage")
	local night = clock < 6 or clock > 18.5
	if village then
		for _, d in village:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("NightGlow") then
				d.Material = if night then Enum.Material.Neon else Enum.Material.Glass
			end
		end
	end
	local ghost = st.role ~= nil and st.alive == false or (st.alive == false and st.phase ~= "lobby")
	-- призракам крыши прозрачны, чтобы видеть всё сверху
	if village then
		for _, d in village:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("Roof") then
				d.LocalTransparencyModifier = if ghost then 0.85 else 0
			end
		end
	end
	if ghost and not self.ghostCam and self.world then
		self.ghostCam = FreeCamera.new(self.world.center + Vector3.new(0, 4, 0))
		self.ghostCam.dist = 150
		self.ghostCam.pitch = math.rad(-62)
	elseif not ghost and self.ghostCam then
		self.ghostCam:destroy()
		self.ghostCam = nil
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	end
	if self.world then
		self.weather:set({ weather = self.world.weather or "Clear", at = 0, auto = false, minutes = 5 })
		-- фоновый звук сезона, если указан в MafiaSounds
		local style = self.world.style or "spring"
		local id = MafiaSounds["ambient" .. string.upper(string.sub(style, 1, 1)) .. string.sub(style, 2)]
		if self.ambientStyle ~= style then
			self.ambientStyle = style
			if self.ambient then
				self.ambient:Destroy()
				self.ambient = nil
			end
			if id and id ~= "" then
				local s = Instance.new("Sound")
				s.SoundId = id
				s.Looped = true
				s.Volume = 0.35
				s.Parent = SoundService
				s:Play()
				self.ambient = s
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- сообщения сервера

function MafiaClient:onMessage(msg)
	local t = msg.type
	if t == "state" then
		local prevRole = self.state.role
		self.state = msg
		self.roleChip.Visible = msg.role ~= nil or msg.youHost
		if msg.youHost then
			self.roleChip.Text = L.RoleHost
			self.roleChip.BackgroundColor3 = Kit.C.accentDim
		elseif msg.role then
			self.roleChip.Text = if msg.alive then ROLE_TITLE[msg.role] else L.RoleGhost
			self.roleChip.BackgroundColor3 = if msg.alive then ROLE_COLOR[msg.role] else Kit.C.panel2
		end
		self.noteButton.Visible = msg.role == "sheriff"
		self.hostButton.Visible = msg.youHost == true or (msg.hostId == nil and msg.creator == true and msg.phase ~= "lobby")
		if not self.hostButton.Visible and self.hostPanel then
			self.hostPanel:Destroy()
			self.hostPanel = nil
		end
		if msg.role and msg.role ~= prevRole then
			self:showRoleCard()
		end
		self:applyChat()
		self:applyWorld()
		self:renderSheet()
		if self.hostPanel then
			self:openHostPanel(true)
		end
	elseif t == "phase" then
		self.state.phase = msg.phase
		self.state.endsAt = msg.endsAt
		if msg.world then
			self.world = msg.world
		end
		if msg.phase == "night" then
			self:announce(H.NightSilenceHint)
		end
		self:applyWorld()
		self:renderSheet()
	elseif t == "announce" then
		self:announce(msg.text)
		self:sound(msg.sound)
	elseif t == "sound" then
		self:sound(msg.sound)
	elseif t == "ghost" then
		self:announce(H.GhostHint)
	elseif t == "joined" then
		self:sound("join")
	end
end

-- ---------------------------------------------------------------------------
-- карточка роли

function MafiaClient:showRoleCard()
	local st = self.state
	if self.card then
		self.card:Destroy()
	end
	local role = st.role
	local title = if st.youHost then L.RoleHost elseif role then ROLE_TITLE[role] else nil
	if not title then
		return
	end
	local hint = if st.youHost then H.HostRoleHint else ROLE_HINT[role]
	local w = math.min(360, Kit.viewport().X - 32)
	local card = Kit.frame(self.gui, { Size = UDim2.fromOffset(w, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0.5, -w / 2, 0.2, 0), BackgroundColor3 = if role then ROLE_COLOR[role] else Kit.C.accentDim, ZIndex = 40 })
	Kit.corner(card, 16)
	Kit.pad(card, 16)
	Kit.list(card, 8)
	Kit.label(card, title, { Font = Kit.FONT_BOLD, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 40), ZIndex = 41, LayoutOrder = 1 })
	Kit.label(card, hint or "", { TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 41, LayoutOrder = 2 })
	if st.house then
		Kit.label(card, string.format(L.YourHouse, st.house), { TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 41, LayoutOrder = 3 })
	end
	if role == "mafia" and st.mafiaTeam then
		local names = {}
		for _, p in st.players or {} do
			if table.find(st.mafiaTeam, p.userId) and p.userId ~= player.UserId then
				table.insert(names, p.name)
			end
		end
		if #names > 0 then
			Kit.label(card, table.concat(names, ", "), { TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 41, LayoutOrder = 4 })
		end
	end
	Kit.button(card, L.GotIt, function()
		card:Destroy()
		self.card = nil
	end, { ZIndex = 42, LayoutOrder = 10, BackgroundColor3 = Kit.C.bg })
	self.card = card
end

-- ---------------------------------------------------------------------------
-- нижняя панель по фазе

local function clear(f: Instance)
	for _, c in f:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

function MafiaClient:playerGrid(order: number, filter, onPick, marked, labelOf)
	local grid = Kit.frame(self.sheet, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order })
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(0.5, -4, 0, Kit.TAP)
	g.CellPadding = UDim2.fromOffset(6, 6)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = grid
	for i, p in self.state.players or {} do
		if filter(p) then
			local b = Kit.button(grid, if labelOf then labelOf(p) else p.name, function()
				self:sound("click")
				onPick(p)
			end, { LayoutOrder = i, TextSize = 14 })
			if marked and marked(p) then
				Kit.setActive(b, true)
			end
		end
	end
	return grid
end

function MafiaClient:renderSheet()
	local st = self.state
	clear(self.sheet)
	Kit.list(self.sheet, 8)
	local phase = st.phase
	self.sheet.Visible = true
	if phase == "lobby" then
		self:renderLobby()
		return
	end
	local me = nil
	for _, p in st.players or {} do
		if p.userId == player.UserId then
			me = p
		end
	end
	if phase == "ended" then
		Kit.label(self.sheet, L.AllRoles, { Font = Kit.FONT_BOLD, LayoutOrder = 1 })
		for i, p in st.players or {} do
			Kit.label(self.sheet, p.name .. "   " .. (ROLE_TITLE[p.role] or ""), { TextSize = 14, LayoutOrder = 1 + i, TextColor3 = ROLE_COLOR[p.role] or Kit.C.text })
		end
		return
	end
	if not st.alive or not st.role then
		self.sheet.Visible = false
		return
	end
	if phase == "vote" then
		Kit.label(self.sheet, L.ChooseExile, { Font = Kit.FONT_BOLD, LayoutOrder = 1 })
		local tally = st.tally or {}
		self:playerGrid(2, function(p)
			return p.alive
		end, function(p)
			request("Vote", p.userId)
		end, function(p)
			return st.vote == p.userId
		end, function(p)
			local n = tally[tostring(p.userId)]
			return if n then p.name .. "   " .. tostring(n) else p.name
		end)
		local skip = Kit.button(self.sheet, L.VoteSkip .. (if tally.skip then "   " .. tally.skip else ""), function()
			request("Vote", "skip")
		end, { LayoutOrder = 3 })
		Kit.setActive(skip, st.vote == "skip")
	elseif phase == "night" then
		local role = st.role
		if role == "mafia" then
			Kit.label(self.sheet, L.ChooseVictim, { Font = Kit.FONT_BOLD, LayoutOrder = 1 })
			local myPick = st.mafiaVotes and st.mafiaVotes[tostring(player.UserId)]
			self:playerGrid(2, function(p)
				return p.alive and not table.find(st.mafiaTeam or {}, p.userId)
			end, function(p)
				request("Night", p.userId)
			end, function(p)
				return myPick == p.userId
			end)
			-- выбор остальных мафиози, чтобы договориться
			local byId = {}
			for _, p in st.players do
				byId[tostring(p.userId)] = p.name
			end
			local order = 3
			for voter, target in st.mafiaVotes or {} do
				order += 1
				Kit.label(self.sheet, string.format(L.MafiaVotesFormat, byId[voter] or "?", byId[tostring(target)] or "?"), { TextSize = 13, TextColor3 = Kit.C.dim, LayoutOrder = order })
			end
		elseif role == "doctor" then
			Kit.label(self.sheet, L.ChooseHeal, { Font = Kit.FONT_BOLD, LayoutOrder = 1 })
			self:playerGrid(2, function(p)
				return p.alive and p.userId ~= st.lastHeal
			end, function(p)
				request("Night", p.userId)
			end, function(p)
				return st.heal == p.userId
			end)
		elseif role == "sheriff" then
			Kit.label(self.sheet, L.ChooseCheck, { Font = Kit.FONT_BOLD, LayoutOrder = 1 })
			local checked = false
			for _, c in st.checks or {} do
				if c.round == st.round then
					checked = true
					Kit.label(self.sheet, string.format(if c.mafia then L.IsMafia else L.NotMafia, c.name), { Font = Kit.FONT_BOLD, TextSize = 18, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 48), TextColor3 = if c.mafia then Kit.C.bad else Kit.C.good })
				end
			end
			if not checked then
				self:playerGrid(2, function(p)
					return p.alive and p.userId ~= player.UserId
				end, function(p)
					request("Night", p.userId)
				end)
			end
		else
			self.sheet.Visible = false
		end
	else
		self.sheet.Visible = false
	end
	local _ = me
end

function MafiaClient:renderLobby()
	local st = self.state
	local s = st.settings or {}
	local n = #(st.players or {})
	local order = 0
	local function o()
		order += 1
		return order
	end
	Kit.label(self.sheet, string.format(L.PlayersFormat, n), { Font = Kit.FONT_BOLD, LayoutOrder = o() })
	local hostName = nil
	for _, p in Players:GetPlayers() do
		if p.UserId == st.hostId then
			hostName = p.DisplayName
		end
	end
	Kit.label(self.sheet, if hostName then string.format(L.HostFormat, hostName) else L.NoHost, { TextSize = 14, TextColor3 = Kit.C.dim, LayoutOrder = o(), Size = UDim2.new(1, 0, 0, 40) })
	Kit.button(self.sheet, if st.youHost then L.StopHosting else L.BecomeHost, function()
		request("BecomeHost", not st.youHost)
	end, { LayoutOrder = o(), Visible = st.youHost or st.hostId == nil or st.creator })
	if st.canStart then
		-- стиль деревни
		local row = Kit.frame(self.sheet, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Kit.TAP), LayoutOrder = o() })
		Kit.list(row, 4, true)
		for i, sty in { { "summer", L.StyleSummer }, { "spring", L.StyleSpring }, { "autumn", L.StyleAutumn }, { "winter", L.StyleWinter } } do
			local b = Kit.button(row, sty[2], function()
				request("Settings", { style = sty[1], theme = "plain", auto = s.auto, counts = s.counts })
			end, { Size = UDim2.new(0.25, -3, 1, 0), LayoutOrder = i, TextSize = 14 })
			Kit.setActive(b, s.style == sty[1])
		end
		local themes = ({
			summer = {},
			spring = { { "april", L.ThemeApril } },
			autumn = { { "halloween", L.ThemeHalloween } },
			winter = { { "newyear", L.ThemeNewYear } },
		})[s.style or "spring"] or {}
		if #themes > 0 then
			local trow = Kit.frame(self.sheet, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Kit.TAP), LayoutOrder = o() })
			Kit.list(trow, 4, true)
			local plain = Kit.button(trow, L.ThemePlain, function()
				request("Settings", { style = s.style, theme = "plain", auto = s.auto, counts = s.counts })
			end, { Size = UDim2.new(0.5, -2, 1, 0), LayoutOrder = 1, TextSize = 14 })
			Kit.setActive(plain, s.theme == "plain")
			for i, th in themes do
				local b = Kit.button(trow, th[2], function()
					request("Settings", { style = s.style, theme = th[1], auto = s.auto, counts = s.counts })
				end, { Size = UDim2.new(0.5, -2, 1, 0), LayoutOrder = 1 + i, TextSize = 14 })
				Kit.setActive(b, s.theme == th[1])
			end
		end
		-- роли: сами или вручную
		local rrow = Kit.frame(self.sheet, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Kit.TAP), LayoutOrder = o() })
		Kit.list(rrow, 4, true)
		local auto = Kit.button(rrow, L.RolesAuto, function()
			request("Settings", { style = s.style, theme = s.theme, auto = true, counts = s.counts })
		end, { Size = UDim2.new(0.5, -2, 1, 0), LayoutOrder = 1, TextSize = 14 })
		local manual = Kit.button(rrow, L.RolesManual, function()
			request("Settings", { style = s.style, theme = s.theme, auto = false, counts = s.counts })
		end, { Size = UDim2.new(0.5, -2, 1, 0), LayoutOrder = 2, TextSize = 14 })
		Kit.setActive(auto, s.auto ~= false)
		Kit.setActive(manual, s.auto == false)
		if s.auto == false then
			for _, k in { { "mafia", L.CountMafia, 1, 6 }, { "doctor", L.CountDoctor, 1, 3 }, { "sheriff", L.CountSheriff, 1, 3 } } do
				Kit.stepper(self.sheet, k[2], (s.counts or {})[k[1]] or k[3], 1, k[3], k[4], function(v)
					local c = table.clone(s.counts or {})
					c[k[1]] = v
					request("Settings", { style = s.style, theme = s.theme, auto = false, counts = c })
				end, o())
			end
		end
		Kit.button(self.sheet, L.StartGame, function()
			local res = request("Start")
			if res and not res.ok then
				Kit.toast(self.gui, if res.error == "few" then H.FewPlayersHint else tostring(res.error), Kit.C.bad)
			end
		end, { LayoutOrder = o(), BackgroundColor3 = Kit.C.accent, Font = Kit.FONT_BOLD })
	end
	if not (self.app.mode and self.app.mode.showcase and self.app.mode.showcase.code == "MAFIA" and not self.app.mode.creator) then
		Kit.button(self.sheet, L.LeaveMafia, function()
			request("Leave")
			self.app:leaveMafia()
		end, { LayoutOrder = o(), BackgroundColor3 = Kit.C.panel2 })
	end
end

-- ---------------------------------------------------------------------------
-- блокнот шерифа: только у себя на устройстве

function MafiaClient:openNotebook()
	if self.notebook then
		self.notebook:Destroy()
		self.notebook = nil
		return
	end
	local w = math.min(380, Kit.viewport().X - 24)
	local box = Kit.frame(self.gui, { Size = UDim2.fromOffset(w, 320), Position = UDim2.new(0.5, -w / 2, 0.15, 0), ZIndex = 30 })
	Kit.corner(box, 12)
	Kit.pad(box, 10)
	Kit.label(box, L.Notebook, { Font = Kit.FONT_BOLD, ZIndex = 31, Size = UDim2.new(1, -50, 0, 28) })
	Kit.button(box, "✕", function()
		box:Destroy()
		self.notebook = nil
	end, { Size = UDim2.fromOffset(40, 32), Position = UDim2.new(1, -40, 0, -2), ZIndex = 31 })
	local history = {}
	for _, c in self.state.checks or {} do
		table.insert(history, (string.gsub(string.format(if c.mafia then L.IsMafia else L.NotMafia, c.name), "\n", " — ")))
	end
	local t = Kit.textbox(box, self.notes, "…", function(text)
		self.notes = text
	end, { MultiLine = true, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 1, -34 - (#history > 0 and 60 or 0)), ZIndex = 31 })
	t:GetPropertyChangedSignal("Text"):Connect(function()
		self.notes = t.Text
	end)
	if #history > 0 then
		Kit.label(box, table.concat(history, "\n"), { Position = UDim2.new(0, 0, 1, -56), Size = UDim2.new(1, 0, 0, 56), TextSize = 13, ZIndex = 31, TextColor3 = Kit.C.dim })
	end
	self.notebook = box
end

-- ---------------------------------------------------------------------------
-- панель ведущего

function MafiaClient:openHostPanel(refresh: boolean?)
	if self.hostPanel then
		self.hostPanel:Destroy()
		self.hostPanel = nil
		if not refresh then
			return
		end
	elseif refresh then
		return
	end
	local st = self.state
	local w = math.min(420, Kit.viewport().X - 24)
	local box = Kit.frame(self.gui, { Size = UDim2.fromOffset(w, math.min(460, Kit.viewport().Y - 140)), Position = UDim2.new(1, -w - 12, 0, 110), ZIndex = 30 })
	Kit.corner(box, 12)
	Kit.pad(box, 10)
	Kit.label(box, L.HostPanel, { Font = Kit.FONT_BOLD, ZIndex = 31, Size = UDim2.new(1, -50, 0, 28) })
	Kit.button(box, "✕", function()
		box:Destroy()
		self.hostPanel = nil
	end, { Size = UDim2.fromOffset(40, 32), Position = UDim2.new(1, -40, 0, -2), ZIndex = 31 })
	local list = Kit.scroll(box, { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 1, -34), ZIndex = 31 })
	Kit.list(list, 6)
	local row = Kit.frame(list, { BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, ZIndex = 31 })
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(0.5, -4, 0, Kit.TAP)
	g.CellPadding = UDim2.fromOffset(6, 6)
	g.Parent = row
	for _, a in { { "next", L.HostNext }, { "more", L.HostMore }, { "home", L.HostHome }, { "table", L.HostTable } } do
		Kit.button(row, a[2], function()
			request("Host", a[1])
		end, { ZIndex = 32, TextSize = 14 })
	end
	local roles = st.allRoles or {}
	for i, p in st.players or {} do
		local card = Kit.frame(list, { BackgroundColor3 = Kit.C.panel2, Size = UDim2.new(1, -6, 0, Kit.TAP * 2 + 14), LayoutOrder = 10 + i, ZIndex = 31 })
		Kit.corner(card, 8)
		Kit.pad(card, 4)
		local role = roles[tostring(p.userId)]
		Kit.label(card, p.name .. "   " .. (if role then ROLE_TITLE[role] else "") .. (if p.alive then "" else "   " .. L.RoleGhost), { Size = UDim2.new(1, 0, 0, Kit.TAP), ZIndex = 32, TextSize = 14, TextColor3 = if role then ROLE_COLOR[role]:Lerp(Color3.new(1, 1, 1), 0.35) else Kit.C.text })
		local br = Kit.frame(card, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, Kit.TAP + 4), Size = UDim2.new(1, 0, 0, Kit.TAP), ZIndex = 32 })
		Kit.list(br, 4, true)
		for j, a in { { "toss", L.HostToss }, { "bring", L.HostBring }, { "sendHome", L.HostSendHome } } do
			Kit.button(br, a[2], function()
				request("Host", a[1], p.userId)
			end, { Size = UDim2.new(1 / 3, -3, 1, 0), LayoutOrder = j, ZIndex = 33, TextSize = 13 })
		end
	end
	self.hostPanel = box
end

function MafiaClient:destroy()
	self.conn:Disconnect()
	self.tick:Disconnect()
	self.weather:destroy()
	if self.ambient then
		self.ambient:Destroy()
	end
	if self.ghostCam then
		self.ghostCam:destroy()
	end
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	self.gui:Destroy()
	pcall(function()
		TextChatService.ChatInputBarConfiguration.TargetTextChannel = nil
	end)
end

return MafiaClient
