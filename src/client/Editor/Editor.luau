--!nonstrict
-- Редактор карты: вкладки, инструменты, выбор объектов, ручки, тест и публикация

local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local UiText = require(Shared.UiText)
local Model = require(Shared.Model)
local Closet = require(Shared.Closet)
local Prefabs = require(Shared.Prefabs)
local Remotes = require(Shared.Roblox.Remotes)
local Convert = require(Shared.Roblox.Convert)
local WorldBuilder = require(Shared.Roblox.WorldBuilder)

local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local Preview = require(script.Parent.Preview)
local FreeCamera = require(script.Parent.FreeCamera)
local Gizmo = require(script.Parent.Gizmo)
local Panels = script.Parent.Panels

local L, H = UiText.L, UiText.H

local Editor = {}
Editor.__index = Editor

local TABS = {
	{ id = "map", title = L.TabMap },
	{ id = "models", title = L.TabModels },
	{ id = "creatures", title = L.TabCreatures },
	{ id = "anim", title = L.TabAnimation },
	{ id = "logic", title = L.TabLogic },
	{ id = "camera", title = L.TabCamera },
	{ id = "texts", title = L.TabTexts },
}

local STATUS = {
	saved = { L.SaveSaved, Kit.C.good },
	dirty = { L.SaveDirty, Kit.C.dim },
	saving = { L.SaveSaving, Kit.C.dim },
	failed = { L.SaveFailed, Kit.C.bad },
	readonly = { L.SaveReadOnly, Kit.C.warn },
}

function Editor.new(app, project, readOnly: boolean)
	local self = setmetatable({}, Editor)
	self.app = app
	self.state = State.new(project, readOnly)
	self.preview = Preview.new(self.state)
	self.camera = FreeCamera.new(Preview.ORIGIN + Vector3.new(0, 4, 0))
	self.gizmo = Gizmo.new(self.camera)
	self.selection = {} :: { string }
	self.selPart = nil :: string?
	self.modelEdit = nil :: string?
	self.tool = "move"
	self.grid = 1
	self.multi = false
	self.tab = "map"
	self.pickCallback = nil
	self.logicErrors = {}
	self.panelCleanup = nil
	self.helpers = {}
	self.selectionChanged = State.signal()

	self:buildUi()
	self.camera.onTap = function(pos)
		self:onTap(pos)
	end
	self.state.changed.connect(function()
		self:afterChange()
	end)
	self.state.resynced.connect(function()
		self:afterChange()
		self:renderPanel()
	end)
	self.state.status.connect(function(st)
		self:setStatus(st)
	end)
	self.state.rejected.connect(function(reason)
		if reason == "frozen" then
			Kit.toast(self.gui, H.FrozenHint)
		end
	end)
	self.preview.onRebuilt = function(id)
		if table.find(self.selection, id) then
			task.defer(function()
				self:updateGizmo()
			end)
		end
	end
	self.keyConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftMeta)
		if ctrl and input.KeyCode == Enum.KeyCode.Z then
			self.state:undo()
		elseif ctrl and input.KeyCode == Enum.KeyCode.Y then
			self.state:redo()
		elseif input.KeyCode == Enum.KeyCode.Delete then
			self:deleteSelection()
		elseif input.KeyCode == Enum.KeyCode.One then
			self:setTool("select")
		elseif input.KeyCode == Enum.KeyCode.Two then
			self:setTool("move")
		elseif input.KeyCode == Enum.KeyCode.Three then
			self:setTool("rotate")
		elseif input.KeyCode == Enum.KeyCode.Four then
			self:setTool("scale")
		end
	end)
	self:setStatus(if readOnly then "readonly" else "saved")
	self:selectTab("map")
	return self
end

-- ---------------------------------------------------------------------------
-- Интерфейс

function Editor:buildUi()
	local gui = Instance.new("ScreenGui")
	gui.Name = "WsEditor"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = self.app.playerGui
	self.gui = gui
	local compact = Kit.compact()
	self.compact = compact

	local top = Kit.frame(gui, { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = Kit.C.bg })
	Kit.pad(top, 4)
	Kit.button(top, L.Back, function()
		self.app:closeEditor()
	end, { Size = UDim2.new(0, 84, 1, 0) })
	self.nameLabel = Kit.label(top, self.state.project.meta.name, {
		Position = UDim2.fromOffset(92, 0), Size = UDim2.new(0.3, -92, 1, 0), Font = Kit.FONT_BOLD, TextSize = 16,
		TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false,
	})
	local right = Kit.frame(top, { BackgroundTransparency = 1, Size = UDim2.new(0.7, 0, 1, 0), Position = UDim2.new(0.3, 0, 0, 0) })
	local rl = Kit.list(right, 6, true)
	rl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	self.statusLabel = Kit.label(right, "", { Size = UDim2.new(0, 120, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 14, LayoutOrder = 1 })
	Kit.button(right, L.Test, function()
		self:startTest()
	end, { Size = UDim2.new(0, 130, 1, 0), LayoutOrder = 2, BackgroundColor3 = Kit.C.accentDim })
	Kit.button(right, L.Publish, function()
		self:publish()
	end, { Size = UDim2.new(0, 130, 1, 0), LayoutOrder = 3, BackgroundColor3 = Kit.C.accent })

	local tabs = Kit.scroll(gui, {
		Size = UDim2.new(1, 0, 0, 48), Position = UDim2.fromOffset(0, 52), BackgroundTransparency = 0,
		BackgroundColor3 = Kit.C.panel, ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollBarThickness = 0,
	})
	Kit.pad(tabs, 2)
	Kit.list(tabs, 4, true)
	self.tabButtons = {}
	for i, t in TABS do
		self.tabButtons[t.id] = Kit.button(tabs, t.title, function()
			self:selectTab(t.id)
		end, { Size = UDim2.new(0, 112, 1, 0), LayoutOrder = i })
	end

	-- инструменты слева
	local rail = Kit.scroll(gui, {
		Size = UDim2.new(0, 84, 1, -100), Position = UDim2.fromOffset(0, 100), BackgroundTransparency = 0,
		BackgroundColor3 = Kit.C.bg,
	})
	Kit.pad(rail, 4)
	Kit.list(rail, 4)
	self.rail = rail
	self.toolButtons = {}
	local function railButton(text: string, fn: () -> (), order: number)
		return Kit.button(rail, text, fn, { Size = UDim2.new(1, 0, 0, 48), TextSize = 13, LayoutOrder = order })
	end
	local tools = { { "select", L.ToolSelect }, { "move", L.ToolMove }, { "rotate", L.ToolRotate }, { "scale", L.ToolScale } }
	for i, t in tools do
		self.toolButtons[t[1]] = railButton(t[2], function()
			self:setTool(t[1])
		end, i)
	end
	self.gridButton = railButton(L.Grid, function()
		self.grid = if self.grid == 1 then 0.5 elseif self.grid == 0.5 then 0 else 1
		self:updateGridButton()
	end, 10)
	self.multiButton = railButton(L.MultiSelect, function()
		self.multi = not self.multi
		Kit.setActive(self.multiButton, self.multi)
	end, 11)
	railButton(L.Undo, function()
		self.state:undo()
	end, 20)
	railButton(L.Redo, function()
		self.state:redo()
	end, 21)
	self.freezeButton = railButton(L.Freeze, function()
		self:toggleFreeze()
	end, 30)
	railButton(L.Glue, function()
		self:glue()
	end, 31)
	railButton(L.Duplicate, function()
		self:duplicate()
	end, 32)
	railButton(L.Delete, function()
		self:deleteSelection()
	end, 33)
	self:updateGridButton()

	-- боковая панель (на телефоне — нижняя)
	local panel
	if compact then
		panel = Kit.frame(gui, { Size = UDim2.new(1, -88, 0.46, 0), Position = UDim2.new(0, 88, 0.54, 0), BackgroundTransparency = 0.05 })
	else
		panel = Kit.frame(gui, { Size = UDim2.new(0, 340, 1, -104), Position = UDim2.new(1, -344, 0, 102), BackgroundTransparency = 0.05 })
	end
	Kit.corner(panel, 10)
	Kit.pad(panel, 8)
	self.panel = panel
	self.panelToggle = Kit.button(gui, "▾", function()
		panel.Visible = not panel.Visible
		self.panelToggle.Text = if panel.Visible then "▾" else "▴"
	end, { Size = UDim2.fromOffset(48, 40), Position = if compact then UDim2.new(1, -52, 0.54, -44) else UDim2.new(1, -52, 0, 104) - UDim2.fromOffset(0, 0), ZIndex = 5 })
	self.panelToggle.Visible = compact

	-- нижняя полоса (шкала анимации)
	local bottom = Kit.frame(gui, {
		Size = if compact then UDim2.new(1, -88, 0.46, 0) else UDim2.new(1, -436, 0, 210),
		Position = if compact then UDim2.new(0, 88, 0.54, 0) else UDim2.new(0, 88, 1, -214),
		Visible = false, BackgroundTransparency = 0.05,
	})
	Kit.corner(bottom, 10)
	Kit.pad(bottom, 6)
	self.bottom = bottom

	self.hint = Kit.label(gui, "", {
		Position = UDim2.new(0, 96, 0, 106), Size = UDim2.new(0.5, 0, 0, 40), TextColor3 = Kit.C.text,
		TextStrokeTransparency = 0.5, TextSize = 14, Visible = false,
	})
end

function Editor:updateGridButton()
	self.gizmo.grid = self.grid
	self.gizmo.rotStep = if self.grid > 0 then 15 else 0
	if self.grid == 0 then
		self.gridButton.Text = L.GridOff
		Kit.setActive(self.gridButton, false)
	else
		self.gridButton.Text = L.Grid .. "\n" .. tostring(self.grid)
		Kit.setActive(self.gridButton, true)
	end
end

function Editor:setStatus(st: string)
	local s = STATUS[st]
	if s then
		self.statusLabel.Text = s[1]
		self.statusLabel.TextColor3 = s[2]
	end
	if st == "readonly" then
		Kit.toast(self.gui, H.ReadOnlyHint, Kit.C.panel2, 5)
	elseif st == "failed" then
		Kit.toast(self.gui, H.SaveFailedHint, Kit.C.panel2, 4)
	end
end

function Editor:showHint(text: string?)
	self.hint.Text = text or ""
	self.hint.Visible = text ~= nil
end

function Editor:selectTab(id: string)
	self.tab = id
	for tid, b in self.tabButtons do
		Kit.setActive(b, tid == id)
	end
	self.bottom.Visible = id == "anim"
	self.panel.Visible = not (self.compact and id == "anim")
	if id ~= "anim" and self.animController then
		self.animController:stop()
	end
	if id == "logic" then
		self.panel.Size = if self.compact then UDim2.new(1, -88, 0.62, 0) else UDim2.new(0, 560, 1, -104)
		self.panel.Position = if self.compact then UDim2.new(0, 88, 0.38, 0) else UDim2.new(1, -564, 0, 102)
	else
		self.panel.Size = if self.compact then UDim2.new(1, -88, 0.46, 0) else UDim2.new(0, 340, 1, -104)
		self.panel.Position = if self.compact then UDim2.new(0, 88, 0.54, 0) else UDim2.new(1, -344, 0, 102)
	end
	self:renderPanel()
	self:updateGizmo()
end

function Editor:renderPanel()
	if self.panelCleanup then
		self.panelCleanup()
		self.panelCleanup = nil
	end
	for _, c in self.panel:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for _, c in self.bottom:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local moduleName = ({
		map = "MapPanel", models = "MapPanel", creatures = "CreaturePanel", anim = "AnimPanel",
		logic = "LogicPanel", camera = "SettingsPanel", texts = "TextsPanel",
	})[self.tab]
	local mod = require(Panels:WaitForChild(moduleName) :: ModuleScript) :: any
	self.panelCleanup = mod.render(self, self.panel, self.bottom)
end

-- ---------------------------------------------------------------------------
-- Выбор

function Editor:onTap(pos: Vector2)
	local id, partId = self.preview:pick(pos)
	if self.pickCallback then
		local cb = self.pickCallback
		if id then
			self.pickCallback = nil
			self:showHint(nil)
			cb(id)
		end
		return
	end
	if self.tab == "anim" and self.animController then
		self.animController:onTap(id, partId)
		return
	end
	if self.modelEdit then
		if id == self.modelEdit then
			self.selPart = partId
		else
			self.selPart = nil
		end
		self:afterSelection()
		return
	end
	if not id then
		if not self.multi then
			self.selection = {}
		end
	elseif self.multi then
		local i = table.find(self.selection, id)
		if i then
			table.remove(self.selection, i)
		else
			table.insert(self.selection, id)
		end
	else
		self.selection = { id }
	end
	self:afterSelection()
end

function Editor:select(ids: { string })
	self.selection = ids
	self:afterSelection()
end

function Editor:afterSelection()
	local ids = self.selection
	if self.modelEdit then
		ids = { self.modelEdit }
	end
	self.preview:setHighlight(ids)
	self:updateGizmo()
	self:updateFreezeButton()
	self.selectionChanged.fire()
	if self.tab ~= "logic" and self.tab ~= "camera" then
		self:renderPanel()
	end
end

function Editor:afterChange()
	-- выбранные объекты могли быть удалены
	local alive = {}
	for _, id in self.selection do
		if self.state:obj(id) then
			table.insert(alive, id)
		end
	end
	self.selection = alive
	if self.modelEdit and not self.state:obj(self.modelEdit) then
		self.modelEdit = nil
		self.selPart = nil
	end
	self.nameLabel.Text = self.state.project.meta.name
	self.preview:setHighlight(if self.modelEdit then { self.modelEdit } else self.selection)
	self:updateFreezeButton()
	task.defer(function()
		self:updateGizmo()
	end)
	if self.onProjectChanged then
		self.onProjectChanged()
	end
end

function Editor:updateFreezeButton()
	local obj = self.selection[1] and self.state:obj(self.selection[1])
	self.freezeButton.Text = if obj and obj.frozen then L.Unfreeze else L.Freeze
	Kit.setActive(self.freezeButton, obj ~= nil and obj.frozen == true)
end

function Editor:setTool(tool: string)
	self.tool = tool
	for t, b in self.toolButtons do
		Kit.setActive(b, t == tool)
	end
	self.gizmo:setTool(tool)
end

-- Прокси для ручек модели целиком
function Editor:proxy(name: string, cf: CFrame, size: Vector3, color: Color3?): BasePart
	local p = self.helpers[name]
	if not p or not p.Parent then
		p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Material = Enum.Material.ForceField
		p.Parent = self.preview.folder
		self.helpers[name] = p
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color or Color3.fromRGB(88, 140, 255)
	p.Transparency = if color then 0.3 else 1
	return p
end

function Editor:clearHelpers(except: { [string]: boolean }?)
	for name, p in self.helpers do
		if not except or not except[name] then
			p:Destroy()
			self.helpers[name] = nil
		end
	end
end

function Editor:updateGizmo()
	if self.tab == "anim" then
		return -- ручками управляет шкала анимации
	end
	self.tool = self.tool or "move"
	self.gizmo:setTool(self.tool)
	local keep = {}
	-- точки шкафа показываются, пока шкаф выбран
	local selObj = #self.selection == 1 and self.state:obj(self.selection[1]) or nil
	if selObj and selObj.role and selObj.role.type == "closet" and not self.modelEdit then
		local base = self.preview:worldCF(selObj.pos, selObj.rot)
		for _, which in { "entry", "inside", "exit" } do
			local pose = selObj.role[which]
			local cf = base * Convert.cfFrom(pose.pos, pose.rot) * CFrame.new(0, 2.5, 0)
			local colors = { entry = Color3.fromRGB(80, 200, 120), inside = Color3.fromRGB(240, 180, 60), exit = Color3.fromRGB(235, 80, 80) }
			local p = self:proxy("Closet_" .. which, cf, Vector3.new(1.6, 5, 0.8), colors[which])
			keep["Closet_" .. which] = true
			local face = p:FindFirstChild("Face") :: BasePart?
			if not face then
				local nose = Instance.new("Part")
				nose.Name = "Face"
				nose.Anchored = true
				nose.CanCollide = false
				nose.CanQuery = false
				nose.Size = Vector3.new(0.6, 0.6, 0.6)
				nose.Color = Color3.new(1, 1, 1)
				nose.Parent = p
				face = nose
			end
			(face :: BasePart).CFrame = cf * CFrame.new(0, 1.8, -0.6)
		end
	end
	if self.closetPoint and selObj and selObj.role and selObj.role.type == "closet" then
		keep["Closet_" .. self.closetPoint] = true
		self:clearHelpers(keep)
		local which = self.closetPoint
		local p = self.helpers["Closet_" .. which]
		local base = self.preview:worldCF(selObj.pos, selObj.rot)
		local id = selObj.id
		self.gizmo:setTarget({
			adornee = p, cf = p.CFrame, size = p.Size, allowMove = true, allowRotate = true, allowScale = false,
			onLive = function(cf)
				p.CFrame = cf
			end,
			onCommit = function(cf)
				local localCF = base:ToObjectSpace(cf * CFrame.new(0, -2.5, 0))
				local pos, rot = Convert.posRot(localCF)
				self.state:apply({ op = "set", id = id, path = { "role", which }, value = { pos = pos, rot = rot } })
			end,
		})
		return
	end
	self:clearHelpers(keep)
	if self.modelEdit then
		local obj = self.state:obj(self.modelEdit)
		local h = self.preview.handles[self.modelEdit]
		local pid = self.selPart
		if not obj or not h or not pid or not h.parts[pid] then
			self.gizmo:setTarget(nil)
			return
		end
		local part = h.parts[pid]
		local base = self.preview:worldCF(obj.pos, obj.rot)
		local mid = self.modelEdit
		self.gizmo:setTarget({
			adornee = part, cf = part.CFrame, size = part.Size, allowMove = true, allowRotate = true, allowScale = true,
			onLive = function(cf, size)
				part.CFrame = cf
				part.Size = size
			end,
			onCommit = function(cf, size)
				local pos, rot = Convert.posRot(base:ToObjectSpace(cf))
				self.state:apply({ op = "batch", ops = {
					{ op = "set", id = mid, path = { "model", "parts", pid, "pos" }, value = pos },
					{ op = "set", id = mid, path = { "model", "parts", pid, "rot" }, value = rot },
					{ op = "set", id = mid, path = { "model", "parts", pid, "size" }, value = Convert.fromV3(size) },
				} })
			end,
		})
		return
	end
	if #self.selection ~= 1 then
		self.gizmo:setTarget(nil)
		return
	end
	local id = self.selection[1]
	local obj = self.state:obj(id)
	local h = self.preview.handles[id]
	if not obj or not h then
		self.gizmo:setTarget(nil)
		return
	end
	local frozen = obj.frozen
	if obj.kind == "part" then
		local part = h.part
		self.gizmo:setTarget({
			adornee = part, cf = part.CFrame, size = part.Size,
			allowMove = not frozen, allowRotate = not frozen, allowScale = true, symmetric = frozen,
			onLive = function(cf, size)
				part.CFrame = cf
				part.Size = size
			end,
			onCommit = function(cf, size)
				local pos, rot = self.preview:toProject(cf)
				local ops = { { op = "set", id = id, path = { "size" }, value = Convert.fromV3(size) } }
				if not frozen then
					table.insert(ops, { op = "set", id = id, path = { "pos" }, value = pos })
					table.insert(ops, { op = "set", id = id, path = { "rot" }, value = rot })
				end
				self.state:apply({ op = "batch", ops = ops })
			end,
		})
	else
		local cf = WorldBuilder.objectCFrame(obj, Preview.ORIGIN)
		local proxy = self:proxy("ModelProxy", cf, Vector3.new(3, 3, 3))
		keep.ModelProxy = true
		local model = h.root :: Model
		local startPivot = model:GetPivot()
		local offset = cf:ToObjectSpace(startPivot)
		self.gizmo:setTarget({
			adornee = proxy, cf = cf, size = proxy.Size,
			allowMove = not frozen, allowRotate = not frozen, allowScale = false,
			onLive = function(newCf)
				proxy.CFrame = newCf
				model:PivotTo(newCf * offset)
			end,
			onCommit = function(newCf)
				local pos, rot = self.preview:toProject(newCf)
				self.state:apply({ op = "batch", ops = {
					{ op = "set", id = id, path = { "pos" }, value = pos },
					{ op = "set", id = id, path = { "rot" }, value = rot },
				} })
			end,
		})
	end
end

-- Выбор цели для действия или поля: касанием на карте
function Editor:pickTarget(cb: (string) -> ())
	self.pickCallback = cb
	self:showHint(H.PickTargetHint)
end

-- ---------------------------------------------------------------------------
-- Команды

function Editor:addObjects(objs)
	local ops = {}
	for _, o in objs do
		table.insert(ops, { op = "add", obj = o })
	end
	local ok, err = self.state:apply({ op = "batch", ops = ops })
	if ok then
		local ids = {}
		for _, o in objs do
			table.insert(ids, o.id)
		end
		self:select(ids)
	else
		Kit.toast(self.gui, tostring(err), Kit.C.bad)
	end
end

function Editor:addPrefab(prefabId: string)
	local at = self.preview:placementPoint(self.grid)
	local objs = Prefabs.build(self.state.project, prefabId, at)
	if objs then
		self:addObjects(objs)
	end
end

function Editor:addShape(shape: string)
	if self.modelEdit then
		-- деталь добавляется в редактируемую модель
		local obj = self.state:obj(self.modelEdit)
		local n = obj.model.nextPart or 1
		local pid = "p" .. tostring(n)
		local part = {
			id = pid, name = L.AddShape, shape = shape, size = { 2, 2, 2 }, pos = { 0, 3, 0 }, rot = { 0, 0, 0 },
			color = { 200, 200, 200 }, material = "SmoothPlastic", transparency = 0, pivot = { 0, 0, 0 },
		}
		self.state:apply({ op = "batch", ops = {
			{ op = "set", id = obj.id, path = { "model", "parts", pid }, value = part },
			{ op = "set", id = obj.id, path = { "model", "nextPart" }, value = n + 1 },
		} })
		self.selPart = pid
		self:afterSelection()
		return
	end
	local at = self.preview:placementPoint(self.grid)
	local p = Prefabs.shape(self.state.project, shape, at)
	self:addObjects({ p })
end

function Editor:deleteSelection()
	if self.modelEdit and self.selPart then
		local obj = self.state:obj(self.modelEdit)
		-- дети удалённой детали переходят к её родителю, потом деталь удаляется
		-- (дорожки клипов этой детали остаются, редактор анимации подсветит их)
		local ops = {}
		for pid, part in obj.model.parts do
			if part.parent == self.selPart then
				table.insert(ops, { op = "set", id = obj.id, path = { "model", "parts", pid, "parent" }, value = obj.model.parts[self.selPart].parent })
			end
		end
		table.insert(ops, { op = "set", id = obj.id, path = { "model", "parts", self.selPart }, value = nil })
		self.state:apply({ op = "batch", ops = ops })
		self.selPart = nil
		self:afterSelection()
		return
	end
	if #self.selection == 0 then
		return
	end
	local ops = {}
	for _, id in self.selection do
		table.insert(ops, { op = "remove", id = id })
	end
	self.state:apply({ op = "batch", ops = ops })
	self:select({})
end

function Editor:duplicate()
	if #self.selection == 0 then
		return
	end
	local op, copies = Model.duplicate(self.state.project, self.selection, { 2, 0, 2 })
	if self.state:apply(op) then
		local ids = {}
		for _, c in copies do
			table.insert(ids, c.id)
		end
		self:select(ids)
	end
end

function Editor:toggleFreeze()
	if #self.selection == 0 then
		return
	end
	local first = self.state:obj(self.selection[1])
	local value = not first.frozen
	local ops = {}
	for _, id in self.selection do
		table.insert(ops, { op = "set", id = id, path = { "frozen" }, value = value })
	end
	self.state:apply({ op = "batch", ops = ops })
	if value then
		Kit.toast(self.gui, H.FrozenHint)
	end
end

function Editor:glue()
	if #self.selection < 1 then
		Kit.toast(self.gui, H.GlueHint)
		return
	end
	local op, res = Model.glue(self.state.project, self.selection, L.DefaultModelName)
	if not op then
		Kit.toast(self.gui, if res == "has role" then H.GlueRoleHint else tostring(res), Kit.C.bad)
		return
	end
	if self.state:apply(op) then
		self:select({ res.id })
	end
end

function Editor:enterModelEdit(id: string?)
	self.modelEdit = id
	self.selPart = nil
	self.closetPoint = nil
	self:showHint(if id then H.ModelEditHint else nil)
	self:afterSelection()
end

function Editor:assignRole(roleType: string?)
	local id = self.selection[1]
	local obj = id and self.state:obj(id)
	if not obj then
		return
	end
	local size = if obj.size then obj.size else { 4, 7, 3 }
	local role = nil
	if roleType == "closet" then
		role = Closet.newRole(size[3])
	elseif roleType == "door" then
		role = { type = "door", open = false, openAngle = 95, openTime = 0.6, hinge = { -size[1] / 2, 0, 0 }, locked = false }
	elseif roleType == "light" then
		role = { type = "light", on = true, brightness = 3, range = 24, color = { 255, 214, 170 } }
	elseif roleType == "npc" then
		role = Prefabs.npcRole()
	elseif roleType == "creature" then
		role = { type = "creature", speed = 14 }
	elseif roleType then
		role = { type = roleType }
	end
	local ok, err = self.state:apply({ op = "set", id = id, path = { "role" }, value = role })
	if not ok then
		Kit.toast(self.gui, tostring(err), Kit.C.bad)
	end
	self:renderPanel()
end

-- ---------------------------------------------------------------------------
-- Тест и публикация

function Editor:showLogicErrors(errors)
	self.logicErrors = errors or {}
	self:selectTab("logic")
	Kit.toast(self.gui, H.PublishFailedHint, Kit.C.bad, 4)
end

function Editor:startTest()
	local res = Remotes.fn("Request"):InvokeServer("StartTest")
	if not res or not res.ok then
		if res and res.error == "logic" then
			self:showLogicErrors(res.errors)
		elseif res and res.error == "filter" then
			Kit.toast(self.gui, H.FilterFailedHint, Kit.C.bad)
		else
			Kit.toast(self.gui, L.LoadFailed, Kit.C.bad)
		end
		return
	end
	self:setEnabled(false)
end

function Editor:publish()
	local res = Remotes.fn("Request"):InvokeServer("Publish")
	if not res or not res.ok then
		if res and res.error == "logic" then
			self:showLogicErrors(res.errors)
		elseif res and res.error == "filter" then
			Kit.toast(self.gui, H.FilterFailedHint, Kit.C.bad)
		else
			Kit.toast(self.gui, H.PublishFailedHint, Kit.C.bad)
		end
		return
	end
	self.state.project.meta.publishCode = res.code
	self.state.project.meta.publishedVersion = res.version
	Kit.choose(self.gui, string.format(L.PublishedAs, res.code), {
		{ id = 1, title = string.format(L.PublishedVersion, res.version), hint = H.PublishHint },
	}, function() end)
end

function Editor:setEnabled(on: boolean)
	self.gui.Enabled = on
	self.camera.enabled = on
	self.gizmo:setEnabled(on)
	self.preview.folder.Parent = if on then workspace else nil
	if on then
		self.camera:apply()
	end
end

function Editor:destroy()
	if self.panelCleanup then
		self.panelCleanup()
	end
	self.keyConn:Disconnect()
	self.gizmo:destroy()
	self.camera:destroy()
	self.preview:destroy()
	self.state:destroy()
	self.gui:Destroy()
end

return Editor
