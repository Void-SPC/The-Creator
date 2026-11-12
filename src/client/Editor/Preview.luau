--!nonstrict
-- Локальный предпросмотр карты в редакторе (экземпляры видны только автору)

local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local WorldBuilder = require(Shared.Roblox.WorldBuilder)
local Convert = require(Shared.Roblox.Convert)

local Preview = {}
Preview.__index = Preview

Preview.ORIGIN = Vector3.new(0, 0, -6000)

function Preview.new(state)
	local self = setmetatable({}, Preview)
	self.state = state
	self.handles = {}
	self.folder = Instance.new("Folder")
	self.folder.Name = "WsEditor"
	self.folder.Parent = workspace
	self.highlights = {}
	self.savedLighting = { ClockTime = Lighting.ClockTime, Ambient = Lighting.Ambient, Brightness = Lighting.Brightness }
	Lighting.ClockTime = 14
	Lighting.Ambient = Color3.fromRGB(110, 110, 120)
	self:rebuildAll()
	self.unsub = {
		state.changed.connect(function(ids)
			for id in ids do
				self:rebuild(id)
			end
		end),
		state.resynced.connect(function()
			self:rebuildAll()
		end),
	}
	return self
end

function Preview:rebuild(id: string)
	local old = self.handles[id]
	if old then
		old.root:Destroy()
		self.handles[id] = nil
	end
	local obj = self.state:obj(id)
	if not obj then
		return
	end
	local h = WorldBuilder.build(obj, self.folder, Preview.ORIGIN, "edit")
	if obj.label then
		WorldBuilder.applyLabel(h, obj.label, obj.label.text)
	end
	self.handles[id] = h
	if self.onRebuilt then
		self.onRebuilt(id, h)
	end
end

function Preview:rebuildAll()
	for _, h in self.handles do
		h.root:Destroy()
	end
	self.handles = {}
	for id in self.state.project.map.objects do
		self:rebuild(id)
	end
	if self.onRebuiltAll then
		self.onRebuiltAll()
	end
end

-- Луч из точки экрана: объект и деталь модели под пальцем
function Preview:pick(screenPos: Vector2): (string?, string?, Vector3?)
	local cam = workspace.CurrentCamera
	local ray = cam:ViewportPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { self.folder }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
	if not hit then
		return nil, nil, nil
	end
	local inst: Instance? = hit.Instance
	local partId = hit.Instance:GetAttribute("WsPart") :: string?
	while inst and inst:GetAttribute("WsId") == nil do
		inst = inst.Parent
	end
	if not inst then
		return nil, nil, hit.Position
	end
	return inst:GetAttribute("WsId") :: string, partId, hit.Position
end

-- Точка на полу перед камерой: туда ставятся новые объекты (в координатах проекта)
function Preview:placementPoint(grid: number): { number }
	local cam = workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { self.folder }
	local hit = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 300, params)
	local p = if hit then hit.Position else cam.CFrame.Position + cam.CFrame.LookVector * 20
	local local3 = p - Preview.ORIGIN
	local function snap(v: number)
		if grid <= 0 then
			return math.floor(v * 10 + 0.5) / 10
		end
		return math.floor(v / grid + 0.5) * grid
	end
	return { snap(local3.X), math.max(0, math.floor(local3.Y * 10 + 0.5) / 10), snap(local3.Z) }
end

function Preview:worldCF(pos, rot): CFrame
	return CFrame.new(Preview.ORIGIN) * Convert.cfFrom(pos, rot)
end

function Preview:toProject(cf: CFrame)
	return Convert.posRot(CFrame.new(-Preview.ORIGIN) * cf)
end

function Preview:setHighlight(ids: { string }, color: Color3?)
	for _, h in self.highlights do
		h:Destroy()
	end
	self.highlights = {}
	for _, id in ids do
		local handle = self.handles[id]
		if handle then
			local hl = Instance.new("Highlight")
			hl.FillTransparency = 0.85
			hl.OutlineColor = color or Color3.fromRGB(88, 140, 255)
			hl.FillColor = color or Color3.fromRGB(88, 140, 255)
			hl.Adornee = handle.root
			hl.Parent = self.folder
			table.insert(self.highlights, hl)
		end
	end
end

function Preview:destroy()
	for _, u in self.unsub do
		u()
	end
	self.folder:Destroy()
	for k, v in self.savedLighting do
		(Lighting :: any)[k] = v
	end
end

return Preview
