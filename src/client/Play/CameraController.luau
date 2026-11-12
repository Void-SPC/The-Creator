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
		if input.UserInputType == Enum.UserInputType.MouseMovement then
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
	if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	end
	-- покачивание при ходьбе; интенсивность 0 полностью его отключает
	local speed = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z).Magnitude
	local bob = self.settings.bob
	local offset = Vector3.zero
	if bob > 0 and speed > 0.5 and hum.FloorMaterial ~= Enum.Material.Air then
		self.bobT += dt * math.clamp(speed / 16, 0.4, 1.6) * 9
		offset = Vector3.new(math.cos(self.bobT * 0.5) * 0.06, math.abs(math.sin(self.bobT)) * 0.12, 0) * bob
	else
		self.bobT = 0
	end
	local headY = if hum.RigType == Enum.HumanoidRigType.R6 then 1.5 else hum.HipHeight * 0.75
	local eye = hrp.Position + Vector3.new(0, headY, 0)
	local rot = CFrame.fromOrientation(self.pitch, self.yaw, 0)
	cam.CFrame = CFrame.new(eye) * rot * CFrame.new(offset)
	-- персонаж поворачивается вслед за взглядом
	if not hrp.Anchored then
		hum.AutoRotate = false
		local flat = CFrame.fromOrientation(0, self.yaw, 0)
		hrp.CFrame = CFrame.new(hrp.Position) * flat
	end
	setCharacterVisible(false)
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
