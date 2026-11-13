--!nonstrict
-- Редактор карты: вкладки, инструменты, выбор объектов, ручки, тест и публикация

local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local UiText = require(Shared.UiText)
local Model = require(Shared.Model)
local Util = require(Shared.Util)
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
	{ id = "objects", title = L.TabObjects },
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
		elseif reason == "name_taken" then
			Kit.toast(self.gui, H.NameTakenHint, Kit.C.bad, 4)
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
		elseif ctrl and input.KeyCode == Enum.KeyCode.C then
			self:copySelection()
		elseif ctrl and input.KeyCode == Enum.KeyCode.V then
			self:paste()
		elseif ctrl and input.KeyCode == Enum.KeyCode.D then
			self:duplicate()
		elseif input.KeyCode == Enum.KeyCode.F then
			self:focusSelection()
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
	local count = 0
	for _ in project.map.objects do
		count += 1
	end
	if count < 3 and not app.startGuideShown then
		app.startGuideShown = true
		self:showStartGuide()
	end
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
	-- размеры раскладки: на телефоне всё тоньше, чтобы карта занимала большую часть экрана
	local TOP = if compact then 44 else 52
	local TABH = if compact then 40 else 44
	local RAIL = if compact then 64 else 80
	self.L = { top = TOP, tabs = TABH, rail = RAIL, head = TOP + TABH }
	self.panelOpen = not compact
	self.uiHidden = false
	self.chrome = {} -- всё, что прячет кнопка «Скрыть интерфейс»

	-- верхняя строка
	local top = Kit.frame(gui, { Size = UDim2.new(1, 0, 0, TOP), BackgroundColor3 = Kit.C.bg })
	Kit.pad(top, 4)
	table.insert(self.chrome, top)
	Kit.button(top, "←", function()
		self.app:closeEditor()
	end, { Size = UDim2.new(0, TOP, 1, 0), TextSize = 20 })
	self.nameLabel = Kit.label(top, self.state.project.meta.name, {
		Position = UDim2.fromOffset(TOP + 6, 0), Size = UDim2.new(0.35, -TOP - 6, 1, 0), Font = Kit.FONT_BOLD, TextSize = if compact then 14 else 16,
		TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false,
	})
	local right = Kit.frame(top, { BackgroundTransparency = 1, Size = UDim2.new(0.65, 0, 1, 0), Position = UDim2.new(0.35, 0, 0, 0) })
	local rl = Kit.list(right, 4, true)
	rl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	self.statusLabel = Kit.label(right, "", { Size = UDim2.new(0, if compact then 86 else 120, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 13, LayoutOrder = 1 })
	Kit.button(right, if compact then "▶" else L.Test, function()
		self:startTest()
	end, { Size = UDim2.new(0, if compact then TOP else 130, 1, 0), LayoutOrder = 2, BackgroundColor3 = Kit.C.accentDim, TextSize = if compact then 18 else 15 })
	Kit.button(right, if compact then "⬆" else L.Publish, function()
		self:publish()
	end, { Size = UDim2.new(0, if compact then TOP else 130, 1, 0), LayoutOrder = 3, BackgroundColor3 = Kit.C.accent, TextSize = if compact then 18 else 15 })
	Kit.button(right, L.HideUi, function()
		self:setUiHidden(true)
	end, { Size = UDim2.new(0, TOP, 1, 0), LayoutOrder = 4, TextSize = 18 })

	-- вкладки
	local tabs = Kit.scroll(gui, {
		Size = UDim2.new(1, 0, 0, TABH), Position = UDim2.fromOffset(0, TOP), BackgroundTransparency = 0,
		BackgroundColor3 = Kit.C.panel, ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollBarThickness = 0,
	})
	table.insert(self.chrome, tabs)
	Kit.pad(tabs, 2)
	Kit.list(tabs, 4, true)
	self.tabButtons = {}
	for i, t in TABS do
		self.tabButtons[t.id] = Kit.button(tabs, t.title, function()
			self:selectTab(t.id)
			self:setPanelOpen(true)
		end, { Size = UDim2.new(0, if compact then 96 else 112, 1, 0), LayoutOrder = i, TextSize = if compact then 13 else 15 })
	end

	-- инструменты слева
	local rail = Kit.scroll(gui, {
		Size = UDim2.new(0, RAIL, 1, -(TOP + TABH)), Position = UDim2.fromOffset(0, TOP + TABH), BackgroundTransparency = 0.15,
		BackgroundColor3 = Kit.C.bg, ScrollBarThickness = 3,
	})
	table.insert(self.chrome, rail)
	Kit.pad(rail, 3)
	Kit.list(rail, 4)
	self.rail = rail
	self.toolButtons = {}
	local function railButton(text: string, fn: () -> (), order: number)
		return Kit.button(rail, text, fn, { Size = UDim2.new(1, 0, 0, Kit.TAP), TextSize = if compact then 11 else 13, LayoutOrder = order })
	end
	local tools = { { "select", L.IconSelect }, { "move", L.IconMove }, { "rotate", L.IconRotate }, { "scale", L.IconScale } }
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
	railButton("↶\n" .. L.Undo, function()
		self.state:undo()
	end, 20)
	railButton("↷\n" .. L.Redo, function()
		self.state:redo()
	end, 21)
	self.freezeButton = railButton(L.Freeze, function()
		self:toggleFreeze()
	end, 30)
	railButton(L.Glue, function()
		self:glue()
	end, 31)
	self:updateGridButton()

	-- панель вкладки: справа на планшете, снизу на телефоне; на телефоне закрыта, пока не нужна
	local panelFrame = Kit.frame(gui, { BackgroundTransparency = 0.04 })
	Kit.corner(panelFrame, 12)
	table.insert(self.chrome, panelFrame)
	self.panelFrame = panelFrame
	local closeH = if compact then 36 else 0
	if compact then
		local grip = Kit.button(panelFrame, "▾  " .. L.Close, function()
			self:setPanelOpen(false)
		end, { Size = UDim2.new(1, 0, 0, closeH), BackgroundTransparency = 1, TextSize = 13, TextColor3 = Kit.C.dim })
		grip.ZIndex = 3
	end
	local panel = Kit.frame(panelFrame, { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, closeH + 4), Size = UDim2.new(1, -16, 1, -closeH - 12) })
	self.panel = panel

	-- нижняя полоса (шкала анимации)
	local bottom = Kit.frame(gui, { Visible = false, BackgroundTransparency = 0.05 })
	Kit.corner(bottom, 10)
	Kit.pad(bottom, 6)
	table.insert(self.chrome, bottom)
	self.bottom = bottom

	self.hint = Kit.label(gui, "", {
		Position = UDim2.new(0, RAIL + 8, 0, TOP + TABH + 4), Size = UDim2.new(0.6, 0, 0, 40), TextColor3 = Kit.C.text,
		TextStrokeTransparency = 0.4, TextSize = 14, Visible = false,
	})

	-- кнопки поверх карты: небольшие и полупрозрачные
	self.addButton = Kit.button(gui, L.AddBig, function()
		self:openAddMenu()
	end, { Size = UDim2.fromOffset(if compact then 130 else 160, Kit.TAP), BackgroundColor3 = Kit.C.accent, Font = Kit.FONT_BOLD, TextSize = 17, ZIndex = 4 })
	table.insert(self.chrome, self.addButton)

	local camBar = Kit.frame(gui, { BackgroundTransparency = 1, ZIndex = 4, Size = UDim2.fromOffset(4 * (Kit.TAP + 4), Kit.TAP) })
	Kit.list(camBar, 4, true)
	table.insert(self.chrome, camBar)
	local function camButton(text: string, fn: () -> (), order: number)
		return Kit.button(camBar, text, fn, { Size = UDim2.fromOffset(Kit.TAP, Kit.TAP), TextSize = 20, LayoutOrder = order, BackgroundTransparency = 0.3 })
	end
	camButton(L.ZoomIn, function()
		self.camera.dist = math.max(4, self.camera.dist * 0.75)
	end, 1)
	camButton(L.ZoomOut, function()
		self.camera.dist = math.min(400, self.camera.dist * 1.33)
	end, 2)
	camButton("◎", function()
		self:focusSelection()
	end, 3)
	self.flyButton = camButton("✈", function()
		self:setFly(not self.flyOn)
	end, 4)
	self.camBar = camBar

	-- полёт пальцем: держите стрелки, ⇧ и ⇩ поднимают и опускают камеру
	local pad = Kit.frame(gui, { BackgroundTransparency = 1, Visible = false, ZIndex = 4, Size = UDim2.fromOffset(3 * (Kit.TAP + 4) + Kit.TAP + 8, 2 * (Kit.TAP + 4)) })
	table.insert(self.chrome, pad)
	self.flyPad = pad
	local function hold(text: string, dir: Vector3, x: number, y: number)
		local b = Kit.button(pad, text, nil, { Size = UDim2.fromOffset(Kit.TAP, Kit.TAP), Position = UDim2.fromOffset(x, y), BackgroundTransparency = 0.3, TextSize = 20 })
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				self.camera.padMove += dir
				self.camera.blockDrag = true
			end
		end)
		b.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				self.camera.padMove -= dir
				if self.camera.padMove.Magnitude < 0.01 then
					self.camera.padMove = Vector3.zero
				end
				self.camera.blockDrag = false
			end
		end)
	end
	local s = Kit.TAP + 4
	hold("▲", Vector3.new(0, 0, -1), s, 0)
	hold("◀", Vector3.new(-1, 0, 0), 0, s)
	hold("▼", Vector3.new(0, 0, 1), s, s)
	hold("▶", Vector3.new(1, 0, 0), 2 * s, s)
	hold("⇧", Vector3.new(0, 1, 0), 3 * s + 8, 0)
	hold("⇩", Vector3.new(0, -1, 0), 3 * s + 8, s)

	-- полоса действий для выбранного объекта (как контекстное меню Studio)
	local selBar = Kit.scroll(gui, {
		BackgroundTransparency = 0.2, BackgroundColor3 = Kit.C.bg, Visible = false, ZIndex = 4,
		ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollBarThickness = 0,
	})
	Kit.corner(selBar, 10)
	Kit.pad(selBar, 4)
	Kit.list(selBar, 4, true)
	table.insert(self.chrome, selBar)
	self.selBar = selBar
	local function selButton(text: string, fn: () -> (), order: number, color: Color3?)
		return Kit.button(selBar, text, fn, { Size = UDim2.new(0, if compact then 84 else 100, 1, 0), TextSize = 13, LayoutOrder = order, BackgroundColor3 = color or Kit.C.panel2, ZIndex = 5 })
	end
	selButton(L.PropertiesShort, function()
		self:setPanelOpen(true)
		if self.tab ~= "map" and self.tab ~= "models" and self.tab ~= "texts" then
			self:selectTab("map")
		end
	end, 1, Kit.C.accentDim)
	selButton(L.Copy, function()
		self:copySelection()
	end, 2)
	selButton(L.Paste, function()
		self:paste()
	end, 3)
	selButton(L.Duplicate, function()
		self:duplicate()
	end, 4)
	selButton(L.Rotate90, function()
		self:rotate90()
	end, 5)
	selButton(L.DropToFloor, function()
		self:dropToFloor()
	end, 6)
	selButton(L.SnapToGrid, function()
		self:snapToGrid()
	end, 7)
	selButton(L.Delete, function()
		self:deleteSelection()
	end, 8, Kit.C.bad)

	-- вернуть интерфейс
	self.showUiButton = Kit.button(gui, L.HideUi, function()
		self:setUiHidden(false)
	end, { Size = UDim2.fromOffset(Kit.TAP, Kit.TAP), Position = UDim2.new(1, -Kit.TAP - 8, 0, 8), Visible = false, BackgroundTransparency = 0.3, TextSize = 18, ZIndex = 9 })

	-- платформа редактора: видна только автору, нужна для прицела и ориентира на пустой карте
	local ground = Instance.new("Part")
	ground.Name = "WsGround"
	ground.Anchored = true
	ground.CanCollide = false
	ground.Size = Vector3.new(2048, 0.2, 2048)
	ground.CFrame = CFrame.new(Preview.ORIGIN + Vector3.new(0, -0.15, 0))
	ground.Color = Color3.fromRGB(70, 74, 82)
	ground.Material = Enum.Material.SmoothPlastic
	ground.Transparency = 0.55
	ground.Parent = self.preview.folder
	local grid = Instance.new("Texture")
	grid.Texture = "rbxasset://textures/SpawnLocation.png"
	grid.Face = Enum.NormalId.Top
	grid.StudsPerTileU = 4
	grid.StudsPerTileV = 4
	grid.Transparency = 0.85
	grid.Parent = ground
	self.ground = ground

	self:layout()
	self.layoutConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		self:layout()
	end)
end

-- Раскладка: панель, шкала анимации и кнопки над картой не перекрывают друг друга
function Editor:layout()
	local L0 = self.L
	local compact = self.compact
	local wide = self.tab == "logic"
	local panelOpen = self.panelOpen and self.tab ~= "anim"
	local panelFrame = self.panelFrame
	local sheet = 0 -- доля экрана снизу, занятая панелью или шкалой
	if compact then
		local h = if wide then 0.62 else 0.48
		panelFrame.Size = UDim2.new(1, -L0.rail - 8, h, -4)
		panelFrame.Position = UDim2.new(0, L0.rail + 4, 1 - h, 0)
		panelFrame.Visible = panelOpen and not self.uiHidden
		if panelOpen then
			sheet = h
		end
		self.bottom.Size = UDim2.new(1, -L0.rail - 8, 0.46, -4)
		self.bottom.Position = UDim2.new(0, L0.rail + 4, 0.54, 0)
		if self.tab == "anim" then
			sheet = 0.46
		end
	else
		local w = if wide then 560 else 340
		panelFrame.Size = UDim2.new(0, w, 1, -L0.head - 4)
		panelFrame.Position = UDim2.new(1, -w - 4, 0, L0.head + 2)
		panelFrame.Visible = panelOpen and not self.uiHidden
		self.bottom.Size = UDim2.new(1, -L0.rail - 352, 0, 210)
		self.bottom.Position = UDim2.new(0, L0.rail + 4, 1, -214)
	end
	self.bottom.Visible = self.tab == "anim" and not self.uiHidden
	local rightInset = if not compact and panelOpen then (if wide then 568 else 348) else 8
	local bottomPx = if not compact and self.tab == "anim" then 220 else 0
	local y = UDim2.new(0, 0, 1 - sheet, -bottomPx - Kit.TAP - 10)
	self.addButton.Position = UDim2.new(0, L0.rail + 8, y.Y.Scale, y.Y.Offset)
	self.camBar.Position = UDim2.new(1, -rightInset - self.camBar.Size.X.Offset, y.Y.Scale, y.Y.Offset)
	self.flyPad.Position = UDim2.new(0, L0.rail + 8, y.Y.Scale, y.Y.Offset - self.flyPad.Size.Y.Offset - 8)
	local barW = math.min(8 * 104, Kit.viewport().X - L0.rail - rightInset - 24)
	self.selBar.Size = UDim2.new(0, barW, 0, Kit.TAP + 8)
	self.selBar.Position = UDim2.new(0, L0.rail + 8, y.Y.Scale, y.Y.Offset - Kit.TAP - 16)
	local hasSel = (#self.selection > 0 or self.selPart ~= nil) and not self.uiHidden and self.tab ~= "anim"
	self.selBar.Visible = hasSel
	if hasSel and self.flyOn then
		self.flyPad.Position = UDim2.new(0, L0.rail + 8, y.Y.Scale, y.Y.Offset - Kit.TAP - 24 - self.flyPad.Size.Y.Offset)
	end
	self.flyPad.Visible = self.flyOn == true and not self.uiHidden
end

function Editor:setPanelOpen(open: boolean)
	self.panelOpen = open
	self:layout()
end

function Editor:setUiHidden(hidden: boolean)
	self.uiHidden = hidden
	for _, g in self.chrome do
		if g ~= self.panelFrame and g ~= self.bottom and g ~= self.selBar and g ~= self.flyPad then
			g.Visible = not hidden
		end
	end
	self.showUiButton.Visible = hidden
	self:layout()
end

function Editor:setFly(on: boolean)
	self.flyOn = on
	Kit.setActive(self.flyButton, on)
	if on then
		Kit.toast(self.gui, H.FlyHint, nil, 3)
	else
		self.camera.padMove = Vector3.zero
	end
	self:layout()
end

-- Studio-подобные действия над выбором
function Editor:copySelection()
	local list = {}
	for _, id in self.selection do
		local o = self.state:obj(id)
		if o then
			table.insert(list, Util.deepCopy(o))
		end
	end
	if #list > 0 then
		self.app.clipboard = list
		Kit.toast(self.gui, L.Copied, nil, 1.5)
	end
end

function Editor:paste()
	local clip = self.app.clipboard
	if not clip or #clip == 0 then
		return
	end
	local op, copies = Model.paste(self.state.project, clip, self.preview:placementPoint(self.grid))
	if op and self.state:apply(op) then
		local ids = {}
		for _, c in copies do
			table.insert(ids, c.id)
		end
		self:select(ids)
	end
end

function Editor:rotate90()
	local ops = {}
	for _, id in self.selection do
		local o = self.state:obj(id)
		if o and not o.frozen then
			table.insert(ops, { op = "set", id = id, path = { "rot" }, value = { o.rot[1], (o.rot[2] + 90) % 360, o.rot[3] } })
		end
	end
	if #ops > 0 then
		self.state:apply({ op = "batch", ops = ops })
	else
		Kit.toast(self.gui, H.FrozenHint)
	end
end

function Editor:snapToGrid()
	local step = if self.grid > 0 then self.grid else 1
	local ops = {}
	for _, id in self.selection do
		local o = self.state:obj(id)
		if o and not o.frozen then
			local p = {}
			for i = 1, 3 do
				p[i] = math.floor(o.pos[i] / step + 0.5) * step
			end
			-- высота у детали: низ на сетке
			if o.size then
				p[2] = math.floor((o.pos[2] - o.size[2] / 2) / step + 0.5) * step + o.size[2] / 2
			end
			table.insert(ops, { op = "set", id = id, path = { "pos" }, value = p })
		end
	end
	if #ops > 0 then
		self.state:apply({ op = "batch", ops = ops })
	end
end

-- «На пол»: опустить объект на ближайшую поверхность под ним
function Editor:dropToFloor()
	for _, id in self.selection do
		local o = self.state:obj(id)
		local h = self.preview.handles[id]
		if o and h and not o.frozen then
			local cf, size
			if h.root:IsA("Model") then
				cf, size = (h.root :: Model):GetBoundingBox()
			else
				local part = h.root :: BasePart
				cf = part.CFrame
				local x, y, z, r00, r01, r02, r10, r11, r12 = cf:GetComponents()
				local _ = x + y + z + r00 + r01 + r02
				local half = 0.5 * (math.abs(r10) * part.Size.X + math.abs(r11) * part.Size.Y + math.abs(r12) * part.Size.Z)
				size = Vector3.new(0, half * 2, 0)
			end
			local bottom = cf.Position.Y - size.Y / 2
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { h.root }
			local hit = workspace:Raycast(Vector3.new(cf.Position.X, bottom + 0.05, cf.Position.Z), Vector3.new(0, -500, 0), params)
			local floorY = if hit then hit.Position.Y else Preview.ORIGIN.Y
			local dy = floorY - bottom
			if math.abs(dy) > 0.01 then
				local p = table.clone(o.pos)
				p[2] = math.floor((p[2] + dy) * 1000 + 0.5) / 1000
				self.state:apply({ op = "set", id = id, path = { "pos" }, value = p })
			end
		end
	end
end

function Editor:openAddMenu()
	local Catalog = require(Shared.Catalog)
	Kit.choose(self.gui, L.AddBig, {
		{ id = "shape", title = L.AddShape, hint = L.Shapes },
		{ id = "prefab", title = L.AddFromCatalog, hint = L.AddPrefab },
		{ id = "mine", title = L.MyModels },
	}, function(kind)
		if kind == "shape" then
			local opts = {}
			for _, s in Catalog.SHAPES do
				table.insert(opts, { id = s.id, title = s.title })
			end
			Kit.choose(self.gui, L.Shapes, opts, function(shape)
				self:addShape(shape)
			end)
		elseif kind == "prefab" then
			local opts = {}
			for _, p in Catalog.PREFABS do
				table.insert(opts, { id = p.id, title = p.title, hint = p.group })
			end
			Kit.choose(self.gui, L.AddFromCatalog, opts, function(pid)
				self:addPrefab(pid)
			end)
		else
			self:addFromLibrary()
		end
	end)
end

function Editor:addFromLibrary()
	local res = Remotes.fn("Request"):InvokeServer("ListLibrary")
	if not res or not res.ok then
		Kit.toast(self.gui, L.LoadFailed, Kit.C.bad)
		return
	end
	local opts = {}
	for _, m in res.models do
		table.insert(opts, { id = m.id, title = m.name })
	end
	if #opts == 0 then
		Kit.toast(self.gui, L.NothingHere)
		return
	end
	Kit.choose(self.gui, L.MyModels, opts, function(assetId)
		local r = Remotes.fn("Request"):InvokeServer("GetLibraryModel", assetId)
		if r and r.ok then
			self:addObjects({ Model.fromAsset(self.state.project, r.asset, self.preview:placementPoint(self.grid)) })
		else
			Kit.toast(self.gui, L.LoadFailed, Kit.C.bad)
		end
	end)
end

function Editor:focusSelection()
	local id = self.modelEdit or self.selection[1]
	local h = id and self.preview.handles[id]
	if not h then
		return
	end
	local pos = if h.root:IsA("Model") then (h.root :: Model):GetPivot().Position else (h.root :: BasePart).Position
	self.camera:focusOn(pos + Vector3.new(0, 2, 0))
	self.camera.dist = math.clamp(self.camera.dist, 10, 40)
end

-- Короткая подсказка «Как начать»: три шага, закрывается кнопкой «Понятно»
function Editor:showStartGuide()
	local shade = Kit.frame(self.gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 60 })
	local v = Kit.viewport()
	local w = math.min(460, v.X - 32)
	local box = Kit.frame(shade, { Size = UDim2.fromOffset(w, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0.5, -w / 2, 0.15, 0), ZIndex = 61 })
	Kit.corner(box, 14)
	Kit.pad(box, 14)
	Kit.list(box, 10)
	Kit.label(box, L.HowToStart, { Font = Kit.FONT_BOLD, TextSize = 22, ZIndex = 62, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 30) })
	for i, key in { "StartStep1", "StartStep2", "StartStep3" } do
		Kit.label(box, tostring(i) .. "   " .. H[key], {
			TextSize = 16, ZIndex = 62, LayoutOrder = 1 + i, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		})
	end
	Kit.button(box, L.GotIt, function()
		shade:Destroy()
	end, { ZIndex = 62, LayoutOrder = 10, BackgroundColor3 = Kit.C.accent, Font = Kit.FONT_BOLD })
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
	if id ~= "anim" and self.animController then
		self.animController:stop()
	end
	self:layout()
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
		logic = "LogicPanel", camera = "SettingsPanel", texts = "TextsPanel", objects = "ExplorerPanel",
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
	self:layout()
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
	elseif roleType == "statue" then
		role = { type = "statue", username = self.app.playerGui.Parent.Name, pose = "admire", orb = true }
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
	local options = {
		{ id = "ok", title = string.format(L.PublishedVersion, res.version), hint = H.PublishHint },
	}
	if self.app.mode and self.app.mode.creator then
		table.insert(options, { id = "showcase", title = L.ShowcaseSet, hint = H.ShowcaseHint })
	end
	Kit.choose(self.gui, string.format(L.PublishedAs, res.code), options, function(choice)
		if choice == "showcase" then
			local r = Remotes.fn("Request"):InvokeServer("SetShowcase", res.code)
			if r and r.ok then
				Kit.toast(self.gui, L.ShowcaseSetDone, Kit.C.good)
			else
				Kit.toast(self.gui, H.ShowcaseOnlyCreators, Kit.C.bad)
			end
		end
	end)
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
	self.layoutConn:Disconnect()
	self.gizmo:destroy()
	self.camera:destroy()
	self.preview:destroy()
	self.state:destroy()
	self.gui:Destroy()
end

return Editor
