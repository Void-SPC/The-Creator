--!nonstrict
-- Построение экземпляров Roblox по данным проекта
-- Используется клиентом редактора (локальный предпросмотр) и сервером игры

local Shared = script.Parent.Parent
local Convert = require(script.Parent.Convert)
local MathX = require(Shared.MathX)
local Rig = require(Shared.Rig)
local Catalog = require(Shared.Catalog)

local WorldBuilder = {}

local MARKER_ROLES = { spawn = true, zone = true, waypoint = true }
local FACES = { "Front", "Back", "Left", "Right", "Top", "Bottom" }

local function newBasePart(shape: string): BasePart
	if shape == "Wedge" then
		return Instance.new("WedgePart")
	elseif shape == "CornerWedge" then
		return Instance.new("CornerWedgePart")
	end
	local p = Instance.new("Part")
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	else
		p.Shape = Enum.PartType.Block
	end
	return p
end

function WorldBuilder.applyLook(inst: BasePart, data)
	inst.Size = Convert.v3(data.size)
	inst.Color = Convert.color(data.color)
	inst.Material = (Enum.Material :: any)[data.material] or Enum.Material.SmoothPlastic
	inst.Transparency = data.transparency or 0
	inst.TopSurface = Enum.SurfaceType.Smooth
	inst.BottomSurface = Enum.SurfaceType.Smooth
	for _, c in inst:GetChildren() do
		if c:IsA("Texture") or c:IsA("Decal") then
			c:Destroy()
		end
	end
	local tex = data.texture and Catalog.TEXTURE_SET[data.texture]
	if tex then
		if tex.tile and tex.tile > 0 then
			for _, face in FACES do
				local t = Instance.new("Texture")
				t.Texture = tex.image
				t.Face = (Enum.NormalId :: any)[face]
				t.StudsPerTileU = tex.tile
				t.StudsPerTileV = tex.tile
				t.Parent = inst
			end
		else
			local d = Instance.new("Decal")
			d.Texture = tex.image
			d.Face = Enum.NormalId.Front
			d.Parent = inst
		end
	end
end

local function configurePart(inst: BasePart, obj, mode: string)
	inst.Anchored = true
	inst.CanCollide = obj.physics.canCollide
	if mode == "edit" then
		inst.CanCollide = false
		inst.CanTouch = false
	end
	inst:SetAttribute("WsId", obj.id)
end

-- Мировая трансформа объекта (с учётом смещения сессии)
function WorldBuilder.objectCFrame(obj, origin: Vector3): CFrame
	return CFrame.new(origin) * Convert.cfFrom(obj.pos, obj.rot)
end

-- handle = { obj, root: Instance, part: BasePart?, parts: { [pid]: BasePart }, primary: BasePart }
function WorldBuilder.build(obj, parent: Instance, origin: Vector3, mode: string)
	local handle: any = { obj = obj, parts = {}, origin = origin, mode = mode }
	local isMarker = obj.role and MARKER_ROLES[obj.role.type]
	if obj.kind == "part" then
		local p = newBasePart(obj.shape)
		p.Name = obj.latin or obj.id
		WorldBuilder.applyLook(p, obj)
		configurePart(p, obj, mode)
		p.CFrame = WorldBuilder.objectCFrame(obj, origin)
		if mode == "play" and isMarker then
			p.Transparency = 1
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
		if mode == "play" and not obj.physics.anchored and not obj.role then
			p.Anchored = false
		end
		p.Parent = parent
		handle.root = p
		handle.part = p
		handle.primary = p
	else
		local m = Instance.new("Model")
		m.Name = obj.latin or obj.id
		m:SetAttribute("WsId", obj.id)
		local base = WorldBuilder.objectCFrame(obj, origin)
		local first: BasePart? = nil
		local ids = {}
		for pid in obj.model.parts do
			table.insert(ids, pid)
		end
		table.sort(ids)
		for _, pid in ids do
			local data = obj.model.parts[pid]
			local p = newBasePart(data.shape)
			p.Name = pid
			WorldBuilder.applyLook(p, data)
			configurePart(p, obj, mode)
			p:SetAttribute("WsPart", pid)
			p.CFrame = base * Convert.cfFrom(data.pos, data.rot)
			p.Parent = m
			handle.parts[pid] = p
			if not first then
				first = p
			end
		end
		-- незакреплённая модель без клипов держится сваркой
		local hasClips = next(obj.model.clips) ~= nil
		if mode == "play" and not obj.physics.anchored and not hasClips and not obj.role and first then
			for _, p in handle.parts do
				if p ~= first then
					local w = Instance.new("WeldConstraint")
					w.Part0 = first
					w.Part1 = p
					w.Parent = first
				end
				p.Anchored = false
			end
		end
		if first then
			m.PrimaryPart = first
		end
		m.Parent = parent
		handle.root = m
		handle.primary = first
	end
	if mode == "play" and obj.hidden then
		WorldBuilder.setVisible(handle, false)
	end
	if obj.role and obj.role.type == "light" then
		WorldBuilder.applyLight(handle, obj.role)
	end
	return handle
end

function WorldBuilder.allParts(handle): { BasePart }
	if handle.part then
		return { handle.part }
	end
	local out = {}
	for _, p in handle.parts do
		table.insert(out, p)
	end
	return out
end

-- Видимость в игре: запоминаем исходную прозрачность и твёрдость
function WorldBuilder.setVisible(handle, visible: boolean)
	handle.visible = visible
	for _, p in WorldBuilder.allParts(handle) do
		if p:GetAttribute("BaseT") == nil then
			p:SetAttribute("BaseT", p.Transparency)
			p:SetAttribute("BaseC", p.CanCollide)
		end
		p.Transparency = if visible then p:GetAttribute("BaseT") :: number else 1
		p.CanCollide = if visible then p:GetAttribute("BaseC") :: boolean else false
		for _, d in p:GetChildren() do
			if d:IsA("Decal") or d:IsA("Texture") then
				d.Transparency = if visible then 0 else 1
			elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
				d.Enabled = visible
			end
		end
	end
end

function WorldBuilder.applyLight(handle, role)
	local p = handle.primary
	if not p then
		return
	end
	local light = p:FindFirstChildOfClass("PointLight")
	if not light then
		light = Instance.new("PointLight")
		light.Shadows = true
		light.Parent = p
	end
	light.Enabled = role.on
	light.Brightness = role.brightness
	light.Range = role.range
	light.Color = Convert.color(role.color)
	if p.Material == Enum.Material.Neon or p:GetAttribute("GlowMaterial") then
		if not p:GetAttribute("GlowMaterial") then
			p:SetAttribute("GlowMaterial", p.Material.Name)
		end
		p.Material = if role.on then (Enum.Material :: any)[p:GetAttribute("GlowMaterial")] else Enum.Material.SmoothPlastic
	end
end

-- Надпись автора: на поверхности или над объектом. text — уже проверенный текст
function WorldBuilder.applyLabel(handle, label, text: string)
	local p = handle.primary
	if not p then
		return nil
	end
	for _, c in p:GetChildren() do
		if c.Name == "WsLabel" then
			c:Destroy()
		end
	end
	if not label then
		return nil
	end
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.Text = text
	tl.TextWrapped = label.wrap
	tl.TextColor3 = Convert.color(label.color)
	tl.Font = Enum.Font.GothamMedium
	tl.RichText = false
	local gui: Instance
	if label.mode == "surface" then
		local sg = Instance.new("SurfaceGui")
		sg.Face = (Enum.NormalId :: any)[label.face or "Front"] or Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 50
		sg.LightInfluence = 0.3
		tl.TextSize = label.size * 2
		tl.Parent = sg
		gui = sg
	else
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(240, 90)
		local extents = if handle.root:IsA("Model") then (handle.root :: Model):GetExtentsSize() else (handle.root :: BasePart).Size
		bb.StudsOffsetWorldSpace = Vector3.new(0, extents.Y / 2 + 1.5, 0)
		bb.MaxDistance = 80
		bb.LightInfluence = 0
		bb.AlwaysOnTop = false
		tl.TextSize = label.size
		tl.TextStrokeTransparency = 0.6
		tl.Parent = bb
		gui = bb
	end
	gui.Name = "WsLabel"
	if label.visible == false then
		(gui :: any).Enabled = false
	end
	gui.Parent = p
	return gui
end

-- Поза модели по сэмплу клипа. modelCF — текущий корень модели в мире
function WorldBuilder.poseModel(handle, sample, modelCF: CFrame)
	local obj = handle.obj
	if obj.kind ~= "model" then
		if handle.part then
			handle.part.CFrame = modelCF
		end
		return
	end
	local world = Rig.pose(obj.model, sample, Convert.tf(modelCF))
	local parts, cfs = {}, {}
	for pid, tf in world do
		local p = handle.parts[pid]
		if p then
			table.insert(parts, p)
			table.insert(cfs, Convert.cf(tf))
		end
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

function WorldBuilder.restWorld(handle, modelCF: CFrame)
	WorldBuilder.poseModel(handle, nil, modelCF)
end

-- Точка над объектом для реплик
function WorldBuilder.headPoint(handle): BasePart?
	if handle.part then
		return handle.part
	end
	local best, bestY = nil, -math.huge
	for _, p in handle.parts do
		local y = p.Position.Y + p.Size.Y / 2
		if y > bestY then
			best, bestY = p, y
		end
	end
	return best
end

WorldBuilder.MathX = MathX

return WorldBuilder
