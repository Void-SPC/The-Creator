--!nonstrict
-- Камера игры: от первого лица в духе DOORS с настраиваемой чувствительностью,
-- полем зрения и покачиванием (до нуля). Для шкафов и кат-сцен камера временно
-- идёт по заданной траектории, затем возвращается к управлению игрока

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local Anim = require(Shared.Anim)
local Convert = require(Shared.Roblox.Convert)

local CameraController = {}
CameraController.__index = CameraController

local player = Players.LocalPlayer

function CameraController.new(settings)
	local self = setmetatable({}, CameraController)
	self.settings = settings.camera
	self.mode = "player" -- player | track | inside
	self.yaw = 0
	self.pitch = 0
	self.bobT = 0
	self.track = nil
	self.inside = nil
	self.lookTouch = nil :: InputObject?
	self.conns = {}
	local cam = workspace.CurrentCamera
	self.firstPerson = self.settings.mode == "first"

	if self.firstPerson then
		cam.CameraType = Enum.CameraType.Scriptable
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			local _, y = hrp.CFrame:ToOrientation()
			self.yaw = y
		end
	else
		cam.CameraType = Enum.CameraType.Custom
	end
	cam.FieldOfView = self.settings.fov

	-- поворот взгляда: мышь (центр зафиксирован) или палец на свободной части экрана
	table.insert(self.conns, UserInputService.InputChanged:Connect(function(input, processed)
		if not self.firstPerson or self.mode == "track" then
			return
		end
		local sens = self.settings.sensitivity
		if input.UserInputType == Enum.UserInputType.MouseMovement and not self.freeCursor then
			self:look(input.Delta.X * 0.0035 * sens, input.Delta.Y * 0.0035 * sens)
		elseif input.UserInputType == Enum.UserInputType.Touch and input == self.lookTouch and not processed then
			self:look(input.Delta.X * 0.006 * sens, input.Delta.Y * 0.006 * sens)
		end
	end))
	table.insert(self.conns, UserInputService.TouchStarted:Connect(function(input, processed)
		if processed or self.lookTouch then
			return
		end
		-- левая нижняя часть экрана занята джойстиком движения
		local v = workspace.CurrentCamera.ViewportSize
		if input.Position.X < v.X * 0.4 and input.Position.Y > v.Y * 0.45 then
			return
		end
		self.lookTouch = input
	end))
	table.insert(self.conns, UserInputService.TouchEnded:Connect(function(input)
		if input == self.lookTouch then
			self.lookTouch = nil
		end
	end))

	RunService:BindToRenderStep("WsCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		self:update(dt)
	end)
	return self
end

function CameraController:look(dx: number, dy: number)
	self.yaw -= dx
	local limit = if self.mode == "inside" then math.rad(35) else math.rad(80)
	self.pitch = math.clamp(self.pitch - dy, -limit, limit)
	if self.mode == "inside" and self.inside then
		self.yaw = math.clamp(self.yaw, self.inside.yaw - math.rad(55), self.inside.yaw + math.rad(55))
	end
end

local function setCharacterVisible(visible: boolean)
	local char = player.Character
	if not char then
		return
	end
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			(d :: any).LocalTransparencyModifier = if visible then 0 else 1
		end
	end
end

function CameraController:update(dt: number)
	local cam = workspace.CurrentCamera
	if self.mode == "track" and self.track then
		local tr = self.track
		tr.elapsed += dt
		local t = math.min(tr.elapsed, tr.clip.length)
		local s = Anim.sample(tr.clip, t).Camera
		cam.CameraType = Enum.CameraType.Scriptable
		if s then
			cam.CFrame = tr.base * Convert.cfFrom(s.pos, s.rot)
		end
		if tr.elapsed >= tr.clip.length then
			self.track = nil
			self.mode = tr.after or "player"
			if tr.done then
				task.spawn(tr.done)
			end
		end
		if self.firstPerson then
			setCharacterVisible(false)
		end
		return
	end
	if self.mode == "inside" and self.inside then
		cam.CameraType = Enum.CameraType.Scriptable
		local eye = self.inside.eye
		cam.CFrame = CFrame.new(eye.Position) * CFrame.fromOrientation(self.pitch, self.yaw, 0)
		if self.firstPerson then
			setCharacterVisible(false)
		end
		return
	end
	if not self.firstPerson then
		if cam.CameraType ~= Enum.CameraType.Custom then
			cam.CameraType = Enum.CameraType.Custom
		end
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = self.settings.fov
	-- заставка: игрока ведут к дому, камера плавно идёт сзади и чуть сбоку
	if self.walkMode then
		hum.AutoRotate = true
		local look = hrp.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		flatLook = if flatLook.Magnitude > 0.01 then flatLook.Unit else Vector3.new(0, 0, -1)
		local right = Vector3.new(-flatLook.Z, 0, flatLook.X)
		local want = CFrame.lookAt(hrp.Position - flatLook * 10 + Vector3.new(0, 4.5, 0) + right * 2.5, hrp.Position + flatLook * 8 + Vector3.new(0, 2.5, 0))
		self.walkCF = if self.walkCF then self.walkCF:Lerp(want, 1 - math.exp(-dt * 3)) else want
		cam.CFrame = self.walkCF
		setCharacterVisible(true)
		return
	end
	self.walkCF = nil
	if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		-- курсор свободен, пока открыто окно (магазин, роли, админ-панель)
		UserInputService.MouseBehavior = if self.freeCursor then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = self.freeCursor == true
	end
	-- мягкая камера от первого лица: взгляд догоняет поворот, шаги дают плавное
	-- покачивание вверх-вниз и из стороны в сторону, при шаге вбок камера слегка
	-- наклоняется, на месте едва заметно «дышит». Интенсивность 0 всё отключает
	local vel = hrp.AssemblyLinearVelocity
	local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local bob = self.settings.bob
	local onGround = hum.FloorMaterial ~= Enum.Material.Air
	local moving = speed > 0.5 and onGround
	self.bobAmp = (self.bobAmp or 0) + ((if moving then 1 else 0) - (self.bobAmp or 0)) * math.min(1, dt * 6)
	self.bobT += dt * math.clamp(speed / 14, 0.5, 1.7) * 8.5
	self.idleT = (self.idleT or 0) + dt
	local amp = self.bobAmp * bob
	local offset = Vector3.new(
		math.sin(self.bobT * 0.5) * 0.08 * amp,
		(math.abs(math.sin(self.bobT * 0.5)) * 0.16 - 0.08) * amp + math.sin(self.idleT * 1.6) * 0.015 * bob,
		0
	)
	-- наклон при шаге и при движении вбок
	local localVel = CFrame.fromOrientation(0, self.yaw, 0):VectorToObjectSpace(vel)
	local strafe = math.clamp(localVel.X / 16, -1, 1)
	local rollTarget = (-strafe * math.rad(2.2) + math.sin(self.bobT * 0.5) * math.rad(0.6) * self.bobAmp) * bob
	self.roll = (self.roll or 0) + (rollTarget - (self.roll or 0)) * math.min(1, dt * 8)
	-- сглаживание взгляда
	self.viewYaw = self.viewYaw or self.yaw
	self.viewPitch = self.viewPitch or self.pitch
	local k = 1 - math.exp(-dt * 22)
	local dy = (self.yaw - self.viewYaw + math.pi) % (2 * math.pi) - math.pi
	self.viewYaw += dy * k
	self.viewPitch += (self.pitch - self.viewPitch) * k
	local headY = if hum.RigType == Enum.HumanoidRigType.R6 then 1.5 else hum.HipHeight * 0.75
	local eye = hrp.Position + Vector3.new(0, headY, 0)
	local rot = CFrame.fromOrientation(self.viewPitch, self.viewYaw, 0) * CFrame.Angles(0, 0, self.roll)
	cam.CFrame = CFrame.new(eye) * rot * CFrame.new(offset)
	-- персонаж поворачивается вслед за взглядом
	if not hrp.Anchored then
		hum.AutoRotate = false
		local flat = CFrame.fromOrientation(0, self.yaw, 0)
		hrp.CFrame = CFrame.new(hrp.Position) * flat
	end
	setCharacterVisible(false)
end

-- Режим заставки при проводке по маршруту
function CameraController:setWalk(on: boolean)
	self.walkMode = on
	if not on then
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			local _, y = hrp.CFrame:ToOrientation()
			self.yaw = y
			self.viewYaw = y
			self.pitch = 0
			self.viewPitch = 0
		end
	end
end

-- Временная траектория камеры (дорожка Camera клипа в системе координат base)
function CameraController:playTrack(base: CFrame, clip, after: string?, done: (() -> ())?)
	if not clip.tracks.Camera then
		if done then
			task.spawn(done)
		end
		return
	end
	self.mode = "track"
	self.track = { base = base, clip = clip, elapsed = 0, after = after, done = done }
end

function CameraController:enterInside(eye: CFrame)
	local _, y = eye:ToOrientation()
	self.inside = { eye = eye, yaw = y }
	self.yaw = y
	self.pitch = 0
	if self.mode ~= "track" then
		self.mode = "inside"
	elseif self.track then
		self.track.after = "inside"
	end
end

-- Возврат управления игроку (после выхода, прерывания или смерти)
function CameraController:restore()
	self.track = nil
	self.inside = nil
	self.mode = "player"
	self.pitch = 0
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		local _, y = hrp.CFrame:ToOrientation()
		self.yaw = y
	end
end

function CameraController:setFreeCursor(on: boolean)
	self.freeCursor = on
end

function CameraController:destroy()
	RunService:UnbindFromRenderStep("WsCamera")
	for _, c in self.conns do
		c:Disconnect()
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.AutoRotate = true
	end
	setCharacterVisible(true)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
end

return CameraController
