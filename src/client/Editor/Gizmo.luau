--!nonstrict
-- Ручки перемещения, вращения и размера. Объект меняется только через ручки:
-- пока ручку тянут, объект двигается на экране сразу, а правка уходит на сервер
-- при отпускании (одна запись в истории отмены)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Gizmo = {}
Gizmo.__index = Gizmo

local AXIS_OF_FACE = {
	[Enum.NormalId.Right] = 1, [Enum.NormalId.Left] = 1,
	[Enum.NormalId.Top] = 2, [Enum.NormalId.Bottom] = 2,
	[Enum.NormalId.Back] = 3, [Enum.NormalId.Front] = 3,
}

function Gizmo.new(camera)
	local self = setmetatable({}, Gizmo)
	self.camera = camera
	self.tool = "select"
	self.grid = 1
	self.rotStep = 15
	self.target = nil
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.enabled = true

	self.move = Instance.new("Handles")
	self.move.Style = Enum.HandlesStyle.Movement
	self.move.Color3 = Color3.fromRGB(255, 200, 60)
	self.move.Parent = gui

	self.scale = Instance.new("Handles")
	self.scale.Style = Enum.HandlesStyle.Resize
	self.scale.Color3 = Color3.fromRGB(80, 200, 255)
	self.scale.Parent = gui

	self.rotate = Instance.new("ArcHandles")
	self.rotate.Parent = gui

	local start: { cf: CFrame, size: Vector3 }? = nil
	local function begin()
		if not self.target then
			return
		end
		start = { cf = self.target.cf, size = self.target.size }
		self.camera.blockDrag = true
	end
	local function finish()
		self.camera.blockDrag = false
		if start and self.target and self.target.onCommit then
			self.target.onCommit(self.target.cf, self.target.size)
		end
		start = nil
	end
	local function snap(v: number, step: number)
		if step <= 0 then
			return v
		end
		return math.floor(v / step + 0.5) * step
	end

	for _, h in { self.move, self.scale } do
		h.MouseButton1Down:Connect(begin)
		h.MouseButton1Up:Connect(finish)
	end
	self.rotate.MouseButton1Down:Connect(begin)
	self.rotate.MouseButton1Up:Connect(finish)
	-- палец или кнопку могли отпустить вне ручки
	self.endConn = UserInputService.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if start and (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) then
			finish()
		end
	end)

	self.move.MouseDrag:Connect(function(face, distance)
		local t = self.target
		if not start or not t then
			return
		end
		local dir = start.cf:VectorToWorldSpace(Vector3.FromNormalId(face))
		local d = snap(distance, self.grid)
		t.cf = start.cf + dir * d
		t.onLive(t.cf, t.size)
	end)

	self.scale.MouseDrag:Connect(function(face, distance)
		local t = self.target
		if not start or not t then
			return
		end
		local axis = AXIS_OF_FACE[face]
		local d = snap(distance, self.grid)
		local s = { start.size.X, start.size.Y, start.size.Z }
		local grow = if t.symmetric then d * 2 else d
		s[axis] = math.clamp(s[axis] + grow, 0.2, 512)
		local real = s[axis] - ({ start.size.X, start.size.Y, start.size.Z })[axis]
		t.size = Vector3.new(s[1], s[2], s[3])
		if t.symmetric then
			t.cf = start.cf
		else
			-- противоположная грань остаётся на месте
			local dir = start.cf:VectorToWorldSpace(Vector3.FromNormalId(face))
			t.cf = start.cf + dir * (real / 2)
		end
		t.onLive(t.cf, t.size)
	end)

	self.rotate.MouseDrag:Connect(function(axis, relativeAngle)
		local t = self.target
		if not start or not t then
			return
		end
		local step = math.rad(self.rotStep)
		local a = if self.rotStep > 0 then math.floor(relativeAngle / step + 0.5) * step else relativeAngle
		local pivot = t.pivot or CFrame.new()
		-- вращение вокруг точки вращения в координатах объекта
		t.cf = start.cf * pivot * CFrame.fromAxisAngle(Vector3.FromAxis(axis), a) * pivot:Inverse()
		t.onLive(t.cf, t.size)
	end)

	self:refresh()
	return self
end

-- target = { adornee, cf, size, allowMove, allowRotate, allowScale, symmetric, pivot, onLive, onCommit }
function Gizmo:setTarget(target)
	self.target = target
	self:refresh()
end

function Gizmo:setTool(tool: string)
	self.tool = tool
	self:refresh()
end

function Gizmo:setEnabled(on: boolean)
	self.enabled = on
	self:refresh()
end

function Gizmo:refresh()
	local t = if self.enabled then self.target else nil
	local adornee = t and t.adornee
	self.move.Adornee = if t and self.tool == "move" and t.allowMove then adornee else nil
	self.scale.Adornee = if t and self.tool == "scale" and t.allowScale then adornee else nil
	self.rotate.Adornee = if t and self.tool == "rotate" and t.allowRotate then adornee else nil
	self.move.Visible = self.move.Adornee ~= nil
	self.scale.Visible = self.scale.Adornee ~= nil
	self.rotate.Visible = self.rotate.Adornee ~= nil
end

function Gizmo:destroy()
	self.camera.blockDrag = false
	self.endConn:Disconnect()
	self.move:Destroy()
	self.scale:Destroy()
	self.rotate:Destroy()
end

return Gizmo
