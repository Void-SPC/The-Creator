--!nonstrict
-- Камера редактора. Касание: один палец вращает, два пальца двигают и приближают
-- Мышь: правая кнопка вращает, средняя двигает, колесо приближает; WASD, Q и E летают
-- Камера никогда не двигает объекты: объект меняется только ручками

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local FreeCamera = {}
FreeCamera.__index = FreeCamera

function FreeCamera.new(focus: Vector3)
	local self = setmetatable({}, FreeCamera)
	self.focus = focus
	self.yaw = math.rad(30)
	self.pitch = math.rad(-35)
	self.dist = 45
	self.enabled = true
	self.blockDrag = false -- выставляет Gizmo, пока тянут ручку
	self.onTap = nil :: ((Vector2) -> ())?
	self.touches = {} :: { [InputObject]: Vector2 }
	self.touchStart = {} :: { [InputObject]: { pos: Vector2, t: number, moved: boolean } }
	self.mouseDown = nil :: { pos: Vector2, t: number, moved: boolean }?
	self.rmb = false
	self.mmb = false
	self.conns = {}
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable

	local function overGui(pos: Vector2): boolean
		local player = game:GetService("Players").LocalPlayer
		local gui = player:FindFirstChildOfClass("PlayerGui")
		if not gui then
			return false
		end
		for _, g in gui:GetGuiObjectsAtPosition(pos.X, pos.Y) do
			if g.Visible and g:FindFirstAncestorOfClass("ScreenGui") and (g:IsA("GuiButton") or g:IsA("TextBox") or g:IsA("ScrollingFrame") or (g:IsA("Frame") and g.BackgroundTransparency < 1)) then
				return true
			end
		end
		return false
	end

	table.insert(self.conns, UserInputService.InputBegan:Connect(function(input, processed)
		if not self.enabled then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch then
			local p = Vector2.new(input.Position.X, input.Position.Y)
			if processed or overGui(p) then
				return
			end
			self.touches[input] = p
			self.touchStart[input] = { pos = p, t = os.clock(), moved = false }
		elseif processed then
			return
		elseif t == Enum.UserInputType.MouseButton1 then
			self.mouseDown = { pos = Vector2.new(input.Position.X, input.Position.Y), t = os.clock(), moved = false }
		elseif t == Enum.UserInputType.MouseButton2 then
			self.rmb = true
		elseif t == Enum.UserInputType.MouseButton3 then
			self.mmb = true
		end
	end))

	table.insert(self.conns, UserInputService.InputChanged:Connect(function(input, processed)
		if not self.enabled then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseWheel and not processed then
			self.dist = math.clamp(self.dist * (1 - input.Position.Z * 0.12), 4, 400)
		elseif t == Enum.UserInputType.MouseMovement then
			local d = input.Delta
			if self.mouseDown and (Vector2.new(input.Position.X, input.Position.Y) - self.mouseDown.pos).Magnitude > 6 then
				self.mouseDown.moved = true
			end
			if self.rmb then
				self:orbit(d.X, d.Y)
			elseif self.mmb then
				self:pan(d.X, d.Y)
			end
		elseif t == Enum.UserInputType.Touch and self.touches[input] then
			local p = Vector2.new(input.Position.X, input.Position.Y)
			local prev = self.touches[input]
			local st = self.touchStart[input]
			if st and (p - st.pos).Magnitude > 10 then
				st.moved = true
			end
			local count = 0
			local other: InputObject? = nil
			for k in self.touches do
				count += 1
				if k ~= input then
					other = k
				end
			end
			if count == 1 then
				if not self.blockDrag then
					local d = p - prev
					self:orbit(d.X, d.Y)
				end
			elseif count >= 2 and other then
				local op = self.touches[other]
				local before = (prev - op).Magnitude
				local after = (p - op).Magnitude
				if before > 1 then
					self.dist = math.clamp(self.dist * before / math.max(after, 1), 4, 400)
				end
				local d = (p - prev) / 2
				self:pan(d.X, d.Y)
			end
			self.touches[input] = p
		end
	end))

	table.insert(self.conns, UserInputService.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch then
			local st = self.touchStart[input]
			local count = 0
			for _ in self.touches do
				count += 1
			end
			self.touches[input] = nil
			self.touchStart[input] = nil
			if st and not st.moved and count == 1 and os.clock() - st.t < 0.35 and self.onTap and not self.blockDrag then
				self.onTap(st.pos)
			end
		elseif t == Enum.UserInputType.MouseButton1 then
			local md = self.mouseDown
			self.mouseDown = nil
			if md and not md.moved and os.clock() - md.t < 0.5 and self.onTap and not self.blockDrag then
				self.onTap(md.pos)
			end
		elseif t == Enum.UserInputType.MouseButton2 then
			self.rmb = false
		elseif t == Enum.UserInputType.MouseButton3 then
			self.mmb = false
		end
	end))

	table.insert(self.conns, RunService.RenderStepped:Connect(function(dt)
		if not self.enabled then
			return
		end
		local move = Vector3.zero
		if not UserInputService:GetFocusedTextBox() then
			local k = UserInputService
			if k:IsKeyDown(Enum.KeyCode.W) then move += Vector3.new(0, 0, -1) end
			if k:IsKeyDown(Enum.KeyCode.S) then move += Vector3.new(0, 0, 1) end
			if k:IsKeyDown(Enum.KeyCode.A) then move += Vector3.new(-1, 0, 0) end
			if k:IsKeyDown(Enum.KeyCode.D) then move += Vector3.new(1, 0, 0) end
			if k:IsKeyDown(Enum.KeyCode.E) then move += Vector3.new(0, 1, 0) end
			if k:IsKeyDown(Enum.KeyCode.Q) then move += Vector3.new(0, -1, 0) end
		end
		if move.Magnitude > 0 then
			local rot = CFrame.Angles(0, self.yaw, 0)
			self.focus += rot:VectorToWorldSpace(move) * dt * math.max(12, self.dist * 0.8)
		end
		self:apply()
	end))
	self:apply()
	return self
end

function FreeCamera:orbit(dx: number, dy: number)
	self.yaw -= dx * 0.008
	self.pitch = math.clamp(self.pitch - dy * 0.008, math.rad(-88), math.rad(88))
end

function FreeCamera:pan(dx: number, dy: number)
	local cam = workspace.CurrentCamera
	local scale = self.dist * 0.0025
	self.focus += cam.CFrame.RightVector * (-dx * scale) + cam.CFrame.UpVector * (dy * scale)
end

function FreeCamera:apply()
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local rot = CFrame.Angles(0, self.yaw, 0) * CFrame.Angles(self.pitch, 0, 0)
	cam.CFrame = CFrame.new(self.focus) * rot * CFrame.new(0, 0, self.dist)
	cam.FieldOfView = 70
end

function FreeCamera:focusOn(pos: Vector3)
	self.focus = pos
end

function FreeCamera:destroy()
	for _, c in self.conns do
		c:Disconnect()
	end
end

return FreeCamera
