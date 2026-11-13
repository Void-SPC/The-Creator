--!nonstrict
-- Клиент игры: чистый экран, камера, шкафы, реплики, компактная полоска здоровья
-- Кнопки строительства, шкала анимации и служебные сообщения сюда не попадают

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local UiText = require(Shared.UiText)
local Remotes = require(Shared.Roblox.Remotes)
local Convert = require(Shared.Roblox.Convert)
local Closet = require(Shared.Closet)
local Format = require(Shared.Format)

local Kit = require(script.Parent.Parent.UI.Kit)
local CameraController = require(script.Parent.CameraController)
local Bubble = require(script.Parent.Bubble)
local WeatherFx = require(script.Parent.WeatherFx)
local SoundService = game:GetService("SoundService")
local TextService = game:GetService("TextService")

local L = UiText.L

local PlayClient = {}
PlayClient.__index = PlayClient

local player = Players.LocalPlayer

function PlayClient.new(app, msg)
	local self = setmetatable({}, PlayClient)
	self.app = app
	self.kind = msg.kind
	self.isOwner = msg.isOwner
	self.settings = msg.settings
	self.closetId = nil :: string?
	self.bubbles = {}
	local gui = Instance.new("ScreenGui")
	gui.Name = "WsPlay"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = app.playerGui
	self.gui = gui
	self.camera = CameraController.new(msg.settings)
	self.weather = WeatherFx.new()
	local w = msg.settings.weather
	if w then
		self.weather:set({ weather = w.type, at = workspace:GetServerTimeNow(), auto = w.auto == true, minutes = w.minutes or 5 })
	end
	self.savedLighting = { ClockTime = Lighting.ClockTime, Ambient = Lighting.Ambient, Brightness = Lighting.Brightness }
	local lt = msg.settings.lighting
	-- смена дня и ночи считается на каждом клиенте по общему серверному времени
	self.time = { clock = (lt and lt.clockTime) or 14, at = workspace:GetServerTimeNow(), dayNight = lt and lt.dayNight == true, dayMinutes = (lt and lt.dayMinutes) or 12 }
	self.timeConn = game:GetService("RunService").RenderStepped:Connect(function()
		local t = self.time
		Lighting.ClockTime = Format.clockAt(t, t.clock, t.at, workspace:GetServerTimeNow())
	end)
	if lt then
		Lighting.ClockTime = lt.clockTime or 14
		Lighting.Brightness = lt.brightness or 1
		if lt.ambient then
			Lighting.Ambient = Color3.fromRGB(lt.ambient[1], lt.ambient[2], lt.ambient[3])
		end
	end

	-- в витрине игроки видят только карту; создатель — маленькую кнопку своего меню
	local mode = app.mode or {}
	local inShowcase = mode.showcase ~= nil and msg.code ~= nil and msg.code == mode.showcase.code
	self.inShowcase = inShowcase
	if inShowcase then
		if mode.creator then
			Kit.button(gui, L.CreatorMenu, function()
				app:openCreatorMenu()
			end, { Size = UDim2.fromOffset(170, 40), Position = UDim2.new(1, -180, 0, 60), BackgroundTransparency = 0.35, TextSize = 14 })
		end
	-- выход из теста — только у автора и только в тесте (это часть редактора)
	elseif self.kind == "test" and self.isOwner then
		Kit.button(gui, L.StopTest, function()
			app:stopPlay()
		end, { Size = UDim2.fromOffset(190, 40), Position = UDim2.new(1, -200, 0, 60), BackgroundTransparency = 0.25, TextSize = 14 })
	else
		Kit.button(gui, L.Back, function()
			app:stopPlay()
		end, { Size = UDim2.fromOffset(96, 40), Position = UDim2.new(1, -106, 0, 60), BackgroundTransparency = 0.4, TextSize = 14 })
	end

	-- компактная полоска здоровья, если карте она нужна
	if self.settings.hud.health then
		local bar = Kit.frame(gui, { Size = UDim2.fromOffset(160, 8), Position = UDim2.new(0, 16, 1, -24), BackgroundColor3 = Color3.fromRGB(20, 20, 24), BackgroundTransparency = 0.3 })
		Kit.corner(bar, 4)
		local fill = Kit.frame(bar, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Kit.C.good })
		Kit.corner(fill, 4)
		self.healthFill = fill
		self:trackHealth()
	end

	-- кнопка выхода из шкафа появляется только внутри
	self.leaveButton = Kit.button(gui, L.LeaveCloset, function()
		self:requestCloset()
	end, { Size = UDim2.fromOffset(150, 56), Position = UDim2.new(0.5, -75, 1, -110), Visible = false, BackgroundTransparency = 0.2 })
	ContextActionService:BindAction("WsLeaveCloset", function(_, state)
		if state == Enum.UserInputState.Begin and self.closetId and self.leaveButton.Visible then
			self:requestCloset()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonX)

	self.errorConn = nil
	return self
end

function PlayClient:trackHealth()
	local function bind(char: Model)
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		local function upd()
			if self.healthFill then
				self.healthFill.Size = UDim2.fromScale(math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1), 1)
			end
		end
		hum.HealthChanged:Connect(upd)
		upd()
	end
	if player.Character then
		task.spawn(bind, player.Character)
	end
	self.charConn = player.CharacterAdded:Connect(bind)
end

function PlayClient:requestCloset()
	if self.closetId then
		Remotes.event("PlayInput"):FireServer({ type = "closet", id = self.closetId })
	end
end

-- Реплика над выбранной точкой, только на время показа
function PlayClient:say(msg)
	local part = msg.part
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
		return
	end
	local old = self.bubbles[part]
	if old then
		old:Destroy()
	end
	local v = Kit.viewport()
	local size = Bubble.textSize(msg.size or 22, v)
	local maxW = Bubble.maxWidth(v)
	local bb = Instance.new("BillboardGui")
	bb.Adornee = part
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 120
	bb.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y / 2 + 1.2, 0)
	bb.Parent = self.app.playerGui
	local b = Bubble.make(bb, msg.text, size, maxW, true)
	bb.Size = UDim2.fromOffset(b.Size.X.Offset, b.Size.Y.Offset)
	bb.SizeOffset = Vector2.new(0, 0.5)
	self.bubbles[part] = bb
	task.delay(msg.seconds or 3, function()
		if self.bubbles[part] == bb then
			self.bubbles[part] = nil
		end
		bb:Destroy()
	end)
end

function PlayClient:onCloset(msg)
	local base: CFrame = msg.base
	if msg.phase == "enter" then
		self.closetId = msg.closetId
		self.leaveButton.Visible = false
		self.camera:playTrack(base, msg.clip, "inside", nil)
		local inside = msg.clip.tracks.Camera and msg.clip.tracks.Camera.keys[#msg.clip.tracks.Camera.keys]
		if inside then
			self.camera:enterInside(base * Convert.cfFrom(inside.pos, inside.rot))
		end
	elseif msg.phase == "inside" then
		self.closetId = msg.closetId
		local eye = base * Convert.cfFrom(msg.pose.pos, msg.pose.rot) * CFrame.new(0, Closet.EYE_HEIGHT, 0)
		if not self.camera.inside then
			self.camera:enterInside(eye)
		elseif self.camera.mode ~= "track" then
			self.camera.mode = "inside"
		end
		self.leaveButton.Visible = true
	elseif msg.phase == "exit" then
		self.leaveButton.Visible = false
		self.camera.inside = nil
		self.camera:playTrack(base, msg.clip, "player", nil)
	elseif msg.phase == "free" or msg.phase == "released" then
		-- шкаф освобождён: управление и камера возвращаются игроку
		self.closetId = nil
		self.leaveButton.Visible = false
		self.camera:restore()
	end
end

function PlayClient:onMessage(msg)
	local t = msg.type
	if t == "say" then
		self:say(msg)
	elseif t == "closet" then
		self:onCloset(msg)
	elseif t == "cutscene" then
		self.camera:playTrack(msg.base, msg.clip, if self.closetId then "inside" else "player", nil)
	elseif t == "walk" then
		-- во время проводки управление выключено, камера показывает путь
		self.camera:setWalk(msg.on == true)
		local ok, controls = pcall(function()
			local pm = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
			return pm:GetControls()
		end)
		if ok and controls then
			if msg.on then
				controls:Disable()
			else
				controls:Enable()
			end
		end
	elseif t == "weather" then
		self.weather:set({ weather = msg.weather, at = msg.at, auto = msg.auto, minutes = msg.minutes })
	elseif t == "music" then
		if self.music then
			self.music:Destroy()
			self.music = nil
		end
		if msg.id then
			local s = Instance.new("Sound")
			s.SoundId = "rbxassetid://" .. tostring(msg.id)
			s.Volume = math.clamp(msg.volume or 0.6, 0, 1)
			s.Looped = true
			s.Parent = SoundService
			s:Play()
			self.music = s
		end
	elseif t == "sound" then
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. tostring(msg.id)
		s.Volume = math.clamp(msg.volume or 0.6, 0, 1)
		local part = msg.part
		s.Parent = if typeof(part) == "Instance" then part else SoundService
		s.Ended:Once(function()
			s:Destroy()
		end)
		s:Play()
		task.delay(60, function()
			if s.Parent then
				s:Destroy()
			end
		end)
	elseif t == "message" then
		self:showMessage(msg.text, msg.seconds)
	elseif t == "time" then
		self.time = { clock = msg.clock, at = msg.at, dayNight = msg.dayNight, dayMinutes = msg.dayMinutes }
	elseif t == "respawn" then
		self.closetId = nil
		self.leaveButton.Visible = false
		self.camera:restore()
	elseif t == "logicError" then
		-- ошибка сценария видна только автору в тесте, игровой экран остаётся чистым
		if self.kind == "test" and self.isOwner then
			table.insert(self.app.pendingLogicErrors, { line = msg.line, bid = msg.bid, message = msg.message, runtime = true })
		end
	end
end

-- Сообщение автора карты по центру сверху экрана
function PlayClient:showMessage(text: string, seconds: number?)
	if self.messageFrame then
		self.messageFrame:Destroy()
	end
	local v = Kit.viewport()
	local w = math.min(560, v.X - 40)
	local size = TextService:GetTextSize(text, 20, Kit.FONT_BOLD, Vector2.new(w - 32, 1000))
	local f = Kit.frame(self.gui, {
		Size = UDim2.fromOffset(w, size.Y + 28), Position = UDim2.new(0.5, -w / 2, 0, 90),
		BackgroundColor3 = Color3.fromRGB(15, 16, 20), BackgroundTransparency = 0.25,
	})
	Kit.corner(f, 12)
	Kit.label(f, text, {
		Size = UDim2.new(1, -32, 1, -28), Position = UDim2.fromOffset(16, 14), Font = Kit.FONT_BOLD, TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	self.messageFrame = f
	task.delay(seconds or 3, function()
		if self.messageFrame == f then
			self.messageFrame = nil
		end
		f:Destroy()
	end)
end

function PlayClient:destroy()
	self.weather:destroy()
	if self.music then
		self.music:Destroy()
	end
	if self.timeConn then
		self.timeConn:Disconnect()
	end
	ContextActionService:UnbindAction("WsLeaveCloset")
	for _, bb in self.bubbles do
		bb:Destroy()
	end
	if self.charConn then
		self.charConn:Disconnect()
	end
	self.camera:destroy()
	self.gui:Destroy()
	for k, v in self.savedLighting do
		(Lighting :: any)[k] = v
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

return PlayClient
