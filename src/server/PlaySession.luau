--!nonstrict
-- Сессия игры: черновик в режиме «Тестировать» или опубликованная версия
-- Строит карту, ведёт двери, свет, зоны, шкафы, существ, NPC и исполняет логику

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage").Workshop.Shared
local Logic = require(Shared.Logic)
local Format = require(Shared.Format)
local Closet = require(Shared.Closet)
local Anim = require(Shared.Anim)
local UiText = require(Shared.UiText)
local Convert = require(Shared.Roblox.Convert)
local WorldBuilder = require(Shared.Roblox.WorldBuilder)
local Animator = require(Shared.Roblox.Animator)
local Remotes = require(Shared.Roblox.Remotes)
local Config = require(script.Parent.Config)

local PlaySession = {}
PlaySession.__index = PlaySession

local L = UiText.L

local function sessionsFolder(): Folder
	local f = workspace:FindFirstChild("WsSessions") :: Folder?
	if not f then
		local nf = Instance.new("Folder")
		nf.Name = "WsSessions"
		nf.Parent = workspace
		f = nf
	end
	return f :: Folder
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	if not char then
		return nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- opts: { id, kind = "test" | "published", project, ownerId, code, version, slot }
function PlaySession.new(service, opts)
	local self = setmetatable({}, PlaySession)
	self.service = service
	self.id = opts.id
	self.kind = opts.kind
	self.project = opts.project
	self.ownerId = opts.ownerId
	self.code = opts.code
	self.version = opts.version
	self.slot = opts.slot
	self.origin = Vector3.new(opts.slot * Config.SLOT_SPACING, 0, 0)
	self.players = {} :: { [Player]: boolean }
	self.handles = {}
	self.animators = {}
	self.movers = {}
	self.doors = {}
	self.closets = {}
	self.closetOf = {} :: { [Player]: string }
	self.zoneMembers = {}
	self.greeted = {}
	self.lastTap = {} :: { [Player]: number }
	self.connections = {}
	self.errors = {}
	self.destroyed = false
	self.playEvent = Remotes.event("Play")
	-- время суток: начальное значение и момент, от которого идут сутки
	local lt = self.project.settings.lighting or {}
	self.clockBase = lt.clockTime or 14
	self.clockAt = workspace:GetServerTimeNow()
	return self
end

function PlaySession:objCF(id: string): CFrame
	local h = self.handles[id]
	if self.animators[id] then
		return self.animators[id].root
	end
	if h.part then
		return h.part.CFrame
	end
	return WorldBuilder.objectCFrame(h.obj, self.origin)
end

function PlaySession:clock(): number
	return Format.clockAt(self.project.settings.lighting, self.clockBase, self.clockAt, workspace:GetServerTimeNow())
end

function PlaySession:timeMessage()
	local lt = self.project.settings.lighting or {}
	return { type = "time", clock = self.clockBase, at = self.clockAt, dayNight = lt.dayNight == true, dayMinutes = lt.dayMinutes or 12 }
end

function PlaySession:broadcast(msg)
	for player in self.players do
		self.playEvent:FireClient(player, msg)
	end
end

function PlaySession:reportError(e)
	table.insert(self.errors, e)
	if #self.errors > 50 then
		table.remove(self.errors, 1)
	end
	if self.kind == "test" then
		local owner = Players:GetPlayerByUserId(self.ownerId)
		if owner then
			self.playEvent:FireClient(owner, { type = "logicError", line = e.line, bid = e.bid, message = e.message })
		end
	end
end

-- ---------------------------------------------------------------------------
-- Построение

function PlaySession:start()
	local folder = Instance.new("Folder")
	folder.Name = self.id
	folder.Parent = sessionsFolder()
	self.folder = folder
	local objects = self.project.map.objects
	for id, obj in objects do
		local h = WorldBuilder.build(obj, folder, self.origin, "play")
		self.handles[id] = h
		if obj.label then
			WorldBuilder.applyLabel(h, obj.label, obj.label.text) -- текст уже прошёл фильтр
		end
		if obj.kind == "model" and (next(obj.model.clips) ~= nil or obj.role) then
			self.animators[id] = Animator.new(h, WorldBuilder.objectCFrame(obj, self.origin))
		end
	end
	for id, obj in objects do
		local role = obj.role
		if role then
			if role.type == "door" then
				self:setupDoor(id)
			elseif role.type == "closet" then
				self:setupCloset(id)
			elseif role.type == "npc" then
				self:setupNpc(id)
			end
		end
	end
	self:setupLogic()
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		self:step(dt)
	end))
	self.zoneTimer = 0
	self:emit("MapStarted", {})
end

-- ---------------------------------------------------------------------------
-- Логика

function PlaySession:setupLogic()
	local tree, errors = Logic.compile(self.project)
	if not tree or #errors > 0 then
		for _, e in errors or {} do
			self:reportError(e)
		end
		return
	end
	self.tree = tree
	local host = {
		now = os.clock,
		action = function(name, args, node)
			return self:action(name, args, node)
		end,
		condition = function(name, args)
			return self:condition(name, args)
		end,
		onError = function(e)
			self:reportError(e)
		end,
	}
	self.runtime = Logic.Interpreter.new(tree, host)
	-- объекты, у которых в логике есть «Когда игрок взаимодействует»
	local interactTargets = {}
	for _, h in tree.handlers do
		if h.event == "Interacted" and h.args[1] and h.args[1].kind == "ref" then
			interactTargets[h.args[1].ref] = true
		end
	end
	for id in interactTargets do
		local obj = self.project.map.objects[id]
		local role = obj and obj.role and obj.role.type
		-- у двери, шкафа и NPC с приветствием «После взаимодействия» своя кнопка
		local ownPrompt = role == "door" or role == "closet" or (role == "npc" and obj.role.trigger == "interact")
		if obj and not ownPrompt then
			local prompt = self:prompt(id, if role == "npc" then L.Talk else L.Interact)
			if prompt then
				table.insert(self.connections, prompt.Triggered:Connect(function(player)
					if self.players[player] then
						self:emit("Interacted", { { ref = id } })
					end
				end))
			end
		end
	end
end

function PlaySession:emit(event: string, args)
	if self.runtime and not self.destroyed then
		self.runtime.dispatch(event, args)
	end
end

local function refOf(v, what: string): string
	if type(v) ~= "table" or type(v.ref) ~= "string" then
		error(what .. ": нужен объект карты", 0)
	end
	return v.ref
end

function PlaySession:target(v, what: string)
	local id = refOf(v, what)
	local h = self.handles[id]
	if not h then
		-- сервер исполняет команды только для объектов этой карты
		error(what .. ": объекта нет на карте", 0)
	end
	return id, h
end

function PlaySession:action(name: string, args, _node)
	if name == "PlayClip" then
		local id = self:target(args[1], "PlayClip")
		local a = self.animators[id]
		if not a or not a:play(args[2], args[3]) then
			error("у модели нет клипа «" .. tostring(args[2]) .. "»", 0)
		end
	elseif name == "StopClip" then
		local id = self:target(args[1], "StopClip")
		if self.animators[id] then
			self.animators[id]:stop()
		end
	elseif name == "MoveTo" then
		local id = self:target(args[1], "MoveTo")
		local pointId = self:target(args[2], "MoveTo")
		local a = self.animators[id]
		if not a then
			error("переместить можно только модель", 0)
		end
		local obj = self.project.map.objects[id]
		local speed = args[4] or (obj.role and obj.role.speed) or 12
		self.movers[id] = { point = pointId, speed = math.clamp(speed, 1, 60), clip = args[3], hops = 0 }
		if args[3] then
			a:play(args[3], true)
		end
	elseif name == "SetLight" then
		local id, h = self:target(args[1], "SetLight")
		local role = h.obj.role
		if not role or role.type ~= "light" then
			error("это не лампа", 0)
		end
		role.on = args[2] == true
		if type(args[3]) == "number" then
			role.brightness = math.clamp(args[3], 0, 40)
		end
		WorldBuilder.applyLight(h, role)
		local _ = id
	elseif name == "Say" then
		local id, h = self:target(args[1], "Say")
		local text = tostring(args[2])
		self:say(nil, id, h, text, args[3] or 3, 22)
	elseif name == "OpenDoor" then
		local id = self:target(args[1], "OpenDoor")
		self:setDoor(id, true)
	elseif name == "CloseDoor" then
		local id = self:target(args[1], "CloseDoor")
		self:setDoor(id, false)
	elseif name == "ShowLabel" then
		local _, h = self:target(args[1], "ShowLabel")
		local gui = h.primary and h.primary:FindFirstChild("WsLabel")
		if gui then
			(gui :: any).Enabled = args[2] == true
		end
	elseif name == "SetVisible" then
		local _, h = self:target(args[1], "SetVisible")
		WorldBuilder.setVisible(h, args[2] == true)
	elseif name == "SetTime" then
		local h = tonumber(args[1])
		if not h then
			error("время суток должно быть числом", 0)
		end
		self.clockBase = math.clamp(h, 0, 24) % 24
		self.clockAt = workspace:GetServerTimeNow()
		self:broadcast(self:timeMessage())
	elseif name == "PlayCutscene" then
		local id = self:target(args[1], "PlayCutscene")
		local a = self.animators[id]
		local clip = a and a:findClip(args[2])
		if not clip or not clip.tracks.Camera then
			error("в клипе нет дорожки камеры", 0)
		end
		self:broadcast({ type = "cutscene", base = self:objCF(id), clip = clip })
	else
		error("команда недоступна: " .. tostring(name), 0)
	end
	return nil
end

function PlaySession:condition(name: string, args)
	if name == "LightIsOn" then
		local _, h = self:target(args[1], "LightIsOn")
		return h.obj.role and h.obj.role.on == true
	elseif name == "DoorIsOpen" then
		local id = self:target(args[1], "DoorIsOpen")
		return self.doors[id] ~= nil and self.doors[id].open
	elseif name == "ZoneHasPlayer" then
		local id = self:target(args[1], "ZoneHasPlayer")
		return next(self.zoneMembers[id] or {}) ~= nil
	elseif name == "ClosetOccupied" then
		local id = self:target(args[1], "ClosetOccupied")
		local c = self.closets[id]
		return c ~= nil and c.state.state ~= Closet.FREE
	elseif name == "IsNight" then
		return Format.isNight(self:clock())
	elseif name == "Chance" then
		return math.random() * 100 < (tonumber(args[1]) or 0)
	end
	error("условие недоступно: " .. tostring(name), 0)
end

-- ---------------------------------------------------------------------------
-- Реплики

function PlaySession:say(toPlayer: Player?, id: string, h, text: string, seconds: number, size: number)
	local anchorPart = WorldBuilder.headPoint(h)
	local role = h.obj.role
	if role and role.type == "npc" and role.anchor and role.anchor.ref and self.handles[role.anchor.ref] then
		anchorPart = WorldBuilder.headPoint(self.handles[role.anchor.ref])
	end
	local msg = { type = "say", part = anchorPart, text = text, seconds = seconds, size = size, from = id }
	if toPlayer then
		self.playEvent:FireClient(toPlayer, msg)
	else
		self:broadcast(msg)
	end
end

-- ---------------------------------------------------------------------------
-- Подсказки взаимодействия

function PlaySession:prompt(id: string, text: string, at: CFrame?): ProximityPrompt?
	local h = self.handles[id]
	if not h or not h.primary then
		return nil
	end
	local parent: Instance = h.primary
	if at then
		local att = Instance.new("Attachment")
		att.Parent = h.primary
		att.WorldCFrame = at
		parent = att
	end
	local p = Instance.new("ProximityPrompt")
	p.ActionText = text
	p.ObjectText = ""
	p.HoldDuration = 0
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.Parent = parent
	return p
end

-- ---------------------------------------------------------------------------
-- Двери

function PlaySession:setupDoor(id: string)
	local h = self.handles[id]
	local role = h.obj.role
	local closed = WorldBuilder.objectCFrame(h.obj, self.origin)
	local door = { open = false, closed = closed, role = role, tween = nil, value = nil }
	self.doors[id] = door
	local prompt = self:prompt(id, L.DoorOpen)
	door.prompt = prompt
	if prompt then
		table.insert(self.connections, prompt.Triggered:Connect(function(player)
			if self.players[player] and not role.locked then
				self:setDoor(id, not door.open)
				self:emit("Interacted", { { ref = id } })
			end
		end))
	end
	if role.open then
		door.open = false
		self:setDoor(id, true, true)
	end
end

function PlaySession:setDoor(id: string, open: boolean, instant: boolean?)
	local door = self.doors[id]
	if not door or door.open == open then
		return
	end
	door.open = open
	local h = self.handles[id]
	local role = door.role
	local hinge = Convert.v3(role.hinge)
	local target = if open
		then door.closed * CFrame.new(hinge) * CFrame.Angles(0, math.rad(role.openAngle), 0) * CFrame.new(-hinge)
		else door.closed
	if door.prompt then
		door.prompt.ActionText = if open then L.DoorClose else L.DoorOpen
	end
	if door.tween then
		door.tween:Cancel()
	end
	local info = TweenInfo.new(if instant then 0 else role.openTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if h.part then
		door.tween = TweenService:Create(h.part, info, { CFrame = target })
		door.tween:Play()
	else
		local value = Instance.new("CFrameValue")
		value.Value = (h.root :: Model):GetPivot()
		value.Changed:Connect(function(cf)
			(h.root :: Model):PivotTo(cf)
		end)
		door.tween = TweenService:Create(value, info, { Value = target })
		door.tween.Completed:Once(function()
			value:Destroy()
		end)
		door.tween:Play()
	end
	self:emit(if open then "DoorOpened" else "DoorClosed", { { ref = id } })
end

-- ---------------------------------------------------------------------------
-- Шкафы

function PlaySession:closetCF(id: string): CFrame
	local h = self.handles[id]
	if h.part then
		return h.part.CFrame
	end
	return self.animators[id] and self.animators[id].root or WorldBuilder.objectCFrame(h.obj, self.origin)
end

function PlaySession:closetPose(id: string, pose): CFrame
	return self:closetCF(id) * Convert.cfFrom(pose.pos, pose.rot)
end

function PlaySession:setupCloset(id: string)
	local h = self.handles[id]
	local role = h.obj.role
	local c = { state = Closet.new(), role = role, active = nil }
	self.closets[id] = c
	-- подсказка у точки входа; она переезжает вместе со шкафом, потому что точка относительная
	local entryCF = self:closetPose(id, role.entry) * CFrame.new(0, 2.5, 0)
	c.prompt = self:prompt(id, L.Hide, entryCF)
	if c.prompt then
		table.insert(self.connections, c.prompt.Triggered:Connect(function(player)
			self:closetRequest(player, id)
		end))
	end
	if h.root then
		table.insert(self.connections, h.root.AncestryChanged:Connect(function(_, parent)
			if parent == nil and not self.destroyed then
				self:closetRelease(id)
			end
		end))
	end
end

local function charPose(rootPart: BasePart, cf: CFrame)
	-- точки шкафа задают положение ног; корень персонажа выше на половину роста
	local hum = rootPart.Parent and rootPart.Parent:FindFirstChildOfClass("Humanoid")
	local lift = 3
	if hum then
		lift = if hum.RigType == Enum.HumanoidRigType.R6 then 3 else hum.HipHeight + rootPart.Size.Y / 2
	end
	return cf * CFrame.new(0, lift, 0)
end

function PlaySession:closetRequest(player: Player, id: string)
	if not self.players[player] then
		return
	end
	local c = self.closets[id]
	if not c then
		return
	end
	local now = os.clock()
	if now - (self.lastTap[player] or 0) < Config.CLOSET_TAP_COOLDOWN then
		return
	end
	self.lastTap[player] = now
	local rootPart = rootOf(player)
	if not rootPart then
		return
	end
	local inOther = self.closetOf[player]
	if inOther and inOther ~= id then
		return
	end
	if c.state.state == Closet.FREE then
		local entry = self:closetPose(id, c.role.entry)
		if (rootPart.Position - entry.Position).Magnitude > Config.CLOSET_DISTANCE then
			return
		end
	end
	local ok, action, token = Closet.request(c.state, player.UserId, now, {
		enter = c.role.enterClip.length,
		exit = c.role.exitClip.length,
	})
	if not ok then
		return -- повторное нажатие во время клипа или шкаф занят: ничего не накладываем
	end
	local clip = if action == "enter" then c.role.enterClip else c.role.exitClip
	self.closetOf[player] = id
	rootPart.Anchored = true
	c.active = { player = player, token = token, clip = clip, elapsed = 0, action = action }
	if c.prompt then
		c.prompt.Enabled = false
	end
	self.playEvent:FireClient(player, {
		type = "closet",
		phase = action,
		closetId = id,
		token = token,
		base = self:closetCF(id),
		clip = clip,
	})
	-- смерть во время клипа или внутри освобождает шкаф
	local hum = (rootPart.Parent :: Model):FindFirstChildOfClass("Humanoid")
	if hum and not c.deathConn then
		c.deathConn = hum.Died:Connect(function()
			self:closetRelease(id)
		end)
	end
end

function PlaySession:stepClosets(dt: number)
	local now = os.clock()
	for id, c in self.closets do
		local a = c.active
		if a then
			local rootPart = rootOf(a.player)
			if not rootPart or not self.players[a.player] then
				self:closetRelease(id)
			else
				a.elapsed += dt
				local t = math.min(a.elapsed, a.clip.length)
				local s = Anim.sample(a.clip, t).PlayerRoot
				if s then
					rootPart.CFrame = charPose(rootPart, self:closetCF(id) * Convert.cfFrom(s.pos, s.rot))
				end
				if a.elapsed >= a.clip.length then
					self:closetComplete(id)
				end
			end
		end
		if Closet.isStuck(c.state, now) then
			self:closetRelease(id)
		end
	end
end

function PlaySession:closetComplete(id: string)
	local c = self.closets[id]
	local a = c.active
	if not a then
		return
	end
	if not Closet.complete(c.state, a.token, os.clock()) then
		return
	end
	c.active = nil
	local player = a.player
	local rootPart = rootOf(player)
	if c.state.state == Closet.INSIDE then
		if rootPart then
			rootPart.CFrame = charPose(rootPart, self:closetPose(id, c.role.inside))
		end
		self.playEvent:FireClient(player, { type = "closet", phase = "inside", closetId = id, base = self:closetCF(id), pose = c.role.inside })
		self:emit("ClosetEntered", { { ref = id } })
	else
		self:closetFinishOutside(id, player)
		self:emit("ClosetExited", { { ref = id } })
	end
end

function PlaySession:closetFinishOutside(id: string, player: Player)
	local c = self.closets[id]
	local rootPart = rootOf(player)
	if rootPart then
		rootPart.CFrame = charPose(rootPart, self:closetPose(id, c.role.exit))
		rootPart.Anchored = false
	end
	if self.closetOf[player] == id then
		self.closetOf[player] = nil
	end
	if c.deathConn then
		c.deathConn:Disconnect()
		c.deathConn = nil
	end
	if c.prompt then
		c.prompt.Enabled = true
	end
	self.playEvent:FireClient(player, { type = "closet", phase = "free", closetId = id })
end

-- Освобождение при смерти, выходе, удалении шкафа или сбое клипа
function PlaySession:closetRelease(id: string)
	local c = self.closets[id]
	if not c then
		return
	end
	local userId = Closet.release(c.state, os.clock())
	c.active = nil
	if c.deathConn then
		c.deathConn:Disconnect()
		c.deathConn = nil
	end
	if c.prompt and c.prompt.Parent then
		c.prompt.Enabled = true
	end
	if not userId then
		return
	end
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return
	end
	if self.closetOf[player] == id then
		self.closetOf[player] = nil
	end
	local rootPart = rootOf(player)
	if rootPart then
		-- персонаж жив: ставим у выхода и возвращаем управление
		if self.handles[id] and self.handles[id].root.Parent then
			rootPart.CFrame = charPose(rootPart, self:closetPose(id, c.role.exit))
		end
		rootPart.Anchored = false
	elseif player.Character then
		local hrp = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			hrp.Anchored = false
		end
	end
	self.playEvent:FireClient(player, { type = "closet", phase = "released", closetId = id })
end

-- ---------------------------------------------------------------------------
-- NPC

function PlaySession:setupNpc(id: string)
	local role = self.handles[id].obj.role
	if role.trigger == "interact" then
		local prompt = self:prompt(id, L.Talk)
		if prompt then
			table.insert(self.connections, prompt.Triggered:Connect(function(player)
				if self.players[player] then
					self:greet(id, player)
					self:emit("Interacted", { { ref = id } })
				end
			end))
		end
	end
end

function PlaySession:greet(id: string, player: Player)
	local key = id .. ":" .. player.UserId
	local now = os.clock()
	if self.greeted[key] and now - self.greeted[key] < Config.NPC_GREET_COOLDOWN then
		return
	end
	self.greeted[key] = now
	local h = self.handles[id]
	local role = h.obj.role
	if role.greetingClip and self.animators[id] then
		self.animators[id]:play(role.greetingClip, false)
	end
	for _, line in role.lines do
		task.delay(line.delay, function()
			if not self.destroyed and self.players[player] then
				self:say(player, id, h, line.text, line.duration, role.textSize)
			end
		end)
	end
end

-- ---------------------------------------------------------------------------
-- Кадр

function PlaySession:stepMovers(dt: number)
	for id, m in self.movers do
		local a = self.animators[id]
		local pointHandle = self.handles[m.point]
		if not a or not pointHandle then
			self.movers[id] = nil
			continue
		end
		local p = pointHandle.obj
		local targetPos = WorldBuilder.objectCFrame(p, self.origin).Position
		local floorY = targetPos.Y - (if p.size then p.size[2] / 2 else 0)
		local target = Vector3.new(targetPos.X, floorY, targetPos.Z)
		local cur = a.root.Position
		local delta = target - cur
		local dist = delta.Magnitude
		local stepLen = m.speed * dt
		if dist <= stepLen or dist < 0.05 then
			local flat = Vector3.new(delta.X, 0, delta.Z)
			local look = if flat.Magnitude > 0.01 then flat.Unit else a.root.LookVector
			a:setRoot(CFrame.lookAt(target, target + look))
			local nextRef = p.role and p.role.next and p.role.next.ref
			self:emit("Arrived", { { ref = id }, { ref = m.point } })
			if nextRef and self.handles[nextRef] and m.hops < 64 then
				m.point = nextRef
				m.hops += 1
			else
				self.movers[id] = nil
				if m.clip and a.clip and a.clip.name == m.clip then
					a:stop()
				end
			end
		else
			local dir = delta / dist
			local pos = cur + dir * stepLen
			local flat = Vector3.new(dir.X, 0, dir.Z)
			local look = if flat.Magnitude > 0.01 then flat.Unit else a.root.LookVector
			a:setRoot(CFrame.lookAt(pos, pos + look))
		end
	end
end

function PlaySession:stepZones()
	for id, h in self.handles do
		local role = h.obj.role
		if role and role.type == "zone" and h.part then
			local members = self.zoneMembers[id] or {}
			self.zoneMembers[id] = members
			local cf, size = h.part.CFrame, h.part.Size
			for player in self.players do
				local rp = rootOf(player)
				local inside = false
				if rp then
					local l = cf:PointToObjectSpace(rp.Position)
					inside = math.abs(l.X) <= size.X / 2 and math.abs(l.Y) <= size.Y / 2 + 2 and math.abs(l.Z) <= size.Z / 2
				end
				if inside and not members[player] then
					members[player] = true
					self:emit("ZoneEntered", { { ref = id } })
					for npcId, nh in self.handles do
						local nr = nh.obj.role
						if nr and nr.type == "npc" and nr.trigger == "roomEnter" and nr.zone and nr.zone.ref == id then
							self:greet(npcId, player)
						end
					end
				elseif not inside and members[player] then
					members[player] = nil
					self:emit("ZoneLeft", { { ref = id } })
				end
			end
		end
	end
end

function PlaySession:step(dt: number)
	if self.destroyed then
		return
	end
	self:stepMovers(dt)
	for id, a in self.animators do
		local markers, finished = a:update(dt)
		if markers then
			for _, mk in markers do
				self:emit("MarkerReached", { { ref = id }, a.clip and a.clip.name or (finished and finished.name), mk.name })
			end
		end
		if finished then
			self:emit("ClipFinished", { { ref = id }, finished.name })
		end
	end
	self:stepClosets(dt)
	self.zoneTimer += dt
	if self.zoneTimer >= 0.1 then
		self.zoneTimer = 0
		self:stepZones()
	end
	if self.runtime then
		self.runtime.update()
	end
end

-- ---------------------------------------------------------------------------
-- Игроки

function PlaySession:spawnCF(): CFrame
	for _, h in self.handles do
		if h.obj.role and h.obj.role.type == "spawn" then
			return WorldBuilder.objectCFrame(h.obj, self.origin) * CFrame.new(0, 3.5, 0)
		end
	end
	return CFrame.new(self.origin + Vector3.new(0, 6, 0))
end

function PlaySession:placeCharacter(player: Player)
	local char = player.Character
	if not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		hrp.Anchored = false
	end
	char:PivotTo(self:spawnCF())
end

function PlaySession:addPlayer(player: Player)
	self.players[player] = true
	self:placeCharacter(player)
	self.playEvent:FireClient(player, {
		type = "enter",
		sessionId = self.id,
		kind = self.kind,
		code = self.code,
		version = self.version,
		settings = self.project.settings,
		isOwner = player.UserId == self.ownerId,
	})
	self.playEvent:FireClient(player, self:timeMessage())
	local conn = player.CharacterAdded:Connect(function()
		task.wait()
		if self.players[player] then
			self:placeCharacter(player)
			self.playEvent:FireClient(player, { type = "respawn" })
		end
	end)
	self.charConns = self.charConns or {}
	self.charConns[player] = conn
end

function PlaySession:removePlayer(player: Player)
	if not self.players[player] then
		return
	end
	local closetId = self.closetOf[player]
	if closetId then
		self:closetRelease(closetId)
	end
	self.players[player] = nil
	for _, members in self.zoneMembers do
		members[player] = nil
	end
	if self.charConns and self.charConns[player] then
		self.charConns[player]:Disconnect()
		self.charConns[player] = nil
	end
	if player.Parent then
		self.playEvent:FireClient(player, { type = "leave" })
	end
end

function PlaySession:playerCount(): number
	local n = 0
	for _ in self.players do
		n += 1
	end
	return n
end

function PlaySession:destroy()
	if self.destroyed then
		return
	end
	for id in self.closets do
		self:closetRelease(id)
	end
	local list = {}
	for p in self.players do
		table.insert(list, p)
	end
	for _, p in list do
		self:removePlayer(p)
	end
	self.destroyed = true
	if self.runtime then
		self.runtime.stop()
	end
	for _, c in self.connections do
		c:Disconnect()
	end
	if self.folder then
		self.folder:Destroy()
	end
end

-- Клиент просит выйти из шкафа (кнопка «Выйти» или клавиша E внутри)
function PlaySession:onInput(player: Player, msg)
	if type(msg) ~= "table" then
		return
	end
	if msg.type == "closet" and type(msg.id) == "string" and self.closets[msg.id] then
		self:closetRequest(player, msg.id)
	end
end

return PlaySession
