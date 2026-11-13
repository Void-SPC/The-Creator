--!nonstrict
-- Вкладки «Карта» и «Модели»: добавление фигур и готовых моделей, свойства, назначения

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local UiText = require(Shared.UiText)
local Catalog = require(Shared.Catalog)
local Format = require(Shared.Format)
local Ids = require(Shared.Ids)
local Logic = require(Shared.Logic)
local Closet = require(Shared.Closet)
local Model = require(Shared.Model)
local Remotes = require(Shared.Roblox.Remotes)

local Kit = require(script.Parent.Parent.Parent.UI.Kit)
local Picker = require(script.Parent.Parent.Picker)

local L, H = UiText.L, UiText.H

local MapPanel = {}

local ROLE_TITLES = {
	closet = L.RoleCloset, door = L.RoleDoor, light = L.RoleLight, npc = L.RoleNpc,
	creature = L.RoleCreature, zone = L.RoleZone, waypoint = L.RoleWaypoint, spawn = L.RoleSpawn,
}

local ASSIGN = {
	{ id = "closet", title = L.AssignCloset },
	{ id = "door", title = L.AssignDoor },
	{ id = "light", title = L.AssignLight },
	{ id = "npc", title = L.AssignNpc },
	{ id = "creature", title = L.AssignCreature },
	{ id = "zone", title = L.AssignZone },
	{ id = "waypoint", title = L.AssignWaypoint },
	{ id = "spawn", title = L.AssignSpawn },
}

local function section(list: Instance, title: string, order: number)
	Kit.label(list, title, { Font = Kit.FONT_BOLD, TextSize = 15, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 28) })
end

-- Палитра цветов сеткой: крупные квадраты под палец
local function palette(list: Instance, current, onPick, order: number, root: Instance?)
	local grid = Kit.frame(list, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order })
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(40, 40)
	g.CellPadding = UDim2.fromOffset(6, 6)
	g.Parent = grid
	for _, c in Catalog.PALETTE do
		local b = Kit.button(grid, "", function()
			onPick(c)
		end, { BackgroundColor3 = Color3.fromRGB(c[1], c[2], c[3]) })
		if current and current[1] == c[1] and current[2] == c[2] and current[3] == c[3] then
			local s = Instance.new("UIStroke")
			s.Thickness = 3
			s.Color = Color3.new(1, 1, 1)
			s.Parent = b
		end
	end
	-- любой цвет через полную палитру
	Kit.button(grid, L.AnyColor, function()
		Kit.colorPicker(root or list:FindFirstAncestorOfClass("ScreenGui"), current, onPick)
	end, { TextSize = 20, BackgroundColor3 = Kit.C.panel2 })
end

-- Свойства детали (отдельной или детали модели). base — путь к детали
local function partProps(editor, list: Instance, id: string, base: { any }, data, order: number)
	local function set(path: { any }, value)
		local full = table.clone(base)
		for _, k in path do
			table.insert(full, k)
		end
		local ok, err = editor.state:apply({ op = "set", id = id, path = full, value = value })
		if not ok then
			Kit.toast(editor.gui, tostring(err), Kit.C.bad)
		end
		return ok
	end
	section(list, L.Size, order)
	for axis = 1, 3 do
		local names = { "X", "Y", "Z" }
		Kit.stepper(list, L.Size .. " " .. names[axis], data.size[axis], if editor.grid > 0 then editor.grid else 0.1, 0.2, 512, function(v)
			local s = table.clone(data.size)
			s[axis] = v
			if set({ "size" }, s) then
				data.size = s
			end
		end, order + axis)
	end
	local shapeRow, shapeSlot = Kit.row(list, L.Shapes, order + 5)
	local _ = shapeRow
	local shapeTitle = data.shape
	for _, s in Catalog.SHAPES do
		if s.id == data.shape then
			shapeTitle = s.title
		end
	end
	Kit.button(shapeSlot, shapeTitle, function()
		local opts = {}
		for _, s in Catalog.SHAPES do
			table.insert(opts, { id = s.id, title = s.title })
		end
		Kit.choose(editor.gui, L.Shapes, opts, function(shape)
			set({ "shape" }, shape)
			editor:renderPanel()
		end)
	end)
	section(list, L.Color, order + 6)
	palette(list, data.color, function(c)
		set({ "color" }, c)
		editor:renderPanel()
	end, order + 7)
	local _, matSlot = Kit.row(list, L.Material, order + 8)
	Kit.button(matSlot, Catalog.MATERIAL_TITLES[data.material] or data.material, function()
		local opts = {}
		for _, m in Format.MATERIALS do
			table.insert(opts, { id = m, title = Catalog.MATERIAL_TITLES[m] or m })
		end
		Kit.choose(editor.gui, L.Material, opts, function(m)
			set({ "material" }, m)
			editor:renderPanel()
		end)
	end)
	local _, texSlot = Kit.row(list, L.Texture, order + 9)
	local texTitle = L.NoTexture
	if data.texture and Catalog.TEXTURE_SET[data.texture] then
		texTitle = Catalog.TEXTURE_SET[data.texture].title
	elseif data.texture then
		texTitle = data.texture
	end
	Kit.button(texSlot, texTitle, function()
		local opts = { { id = false, title = L.NoTexture } }
		for _, t in Catalog.TEXTURES do
			table.insert(opts, { id = t.id, title = t.title })
		end
		table.insert(opts, { id = "custom", title = L.TextureById, hint = H.TextureIdHint })
		Kit.choose(editor.gui, L.Texture, opts, function(t)
			if t == "custom" then
				Kit.prompt(editor.gui, L.TextureById, H.TextureIdHint, L.TextureIdPlaceholder, function(text)
					local id = string.match(text, "(%d+)")
					if id then
						set({ "texture" }, "rbxassetid://" .. id)
					end
					editor:renderPanel()
				end)
				return
			end
			set({ "texture" }, if t then t else nil)
			editor:renderPanel()
		end)
	end, { TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd })
	if data.texture then
		Kit.stepper(list, L.TextureTile, data.textureTile or 4, 0.5, 0.5, 64, function(v)
			set({ "textureTile" }, v)
		end, order + 9)
	end
	Kit.slider(list, L.Transparency, data.transparency or 0, 0, 1, function(v)
		set({ "transparency" }, v)
	end, order + 10)
end

local function nudgePad(editor, list: Instance, obj, order: number)
	if obj.frozen then
		Kit.label(list, H.FrozenHint, { TextColor3 = Kit.C.warn, TextSize = 13, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 36) })
		return
	end
	section(list, L.Nudge, order)
	local pad = Kit.frame(list, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order + 1 })
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(0.25, -6, 0, Kit.TAP)
	g.CellPadding = UDim2.fromOffset(6, 6)
	g.Parent = pad
	local step = if editor.grid > 0 then editor.grid else 0.25
	local function move(axis: number, d: number)
		local pos = table.clone(obj.pos)
		pos[axis] += d
		editor.state:apply({ op = "set", id = obj.id, path = { "pos" }, value = pos })
		obj = editor.state:obj(obj.id)
	end
	local function turn(d: number)
		local rot = table.clone(obj.rot)
		rot[2] = (rot[2] + d) % 360
		editor.state:apply({ op = "set", id = obj.id, path = { "rot" }, value = rot })
		obj = editor.state:obj(obj.id)
	end
	for _, b in {
		{ "X −", function() move(1, -step) end }, { "X +", function() move(1, step) end },
		{ "Y −", function() move(2, -step) end }, { "Y +", function() move(2, step) end },
		{ "Z −", function() move(3, -step) end }, { "Z +", function() move(3, step) end },
		{ "⟲ 15°", function() turn(-15) end }, { "⟳ 15°", function() turn(15) end },
	} do
		Kit.button(pad, b[1], b[2], { TextSize = 14 })
	end
end

local function clipNames(obj)
	local names = {}
	if obj.kind == "model" then
		for _, c in obj.model.clips do
			table.insert(names, { id = c.name, title = c.name })
		end
	end
	table.sort(names, function(a, b)
		return a.title < b.title
	end)
	return names
end

local function roleProps(editor, list: Instance, obj, order: number)
	local role = obj.role
	local id = obj.id
	local function set(path, value)
		local full = { "role" }
		for _, k in path do
			table.insert(full, k)
		end
		local ok, err = editor.state:apply({ op = "set", id = id, path = full, value = value })
		if not ok then
			Kit.toast(editor.gui, tostring(err), Kit.C.bad)
		end
	end
	local t = role.type
	if t == "closet" then
		Kit.label(list, H.ClosetHint, { TextColor3 = Kit.C.dim, TextSize = 13, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 36) })
		for i, which in { { "entry", L.ClosetEntry }, { "inside", L.ClosetInside }, { "exit", L.ClosetExit } } do
			local b = Kit.button(list, which[2], function()
				editor.closetPoint = if editor.closetPoint == which[1] then nil else which[1]
				if editor.tool == "select" or editor.tool == "scale" then
					editor:setTool("move")
				end
				editor:updateGizmo()
				editor:renderPanel()
			end, { LayoutOrder = order + i })
			Kit.setActive(b, editor.closetPoint == which[1])
		end
		Kit.button(list, L.ResetClosetClips, function()
			local enter, leave = Closet.defaultClips(role.entry, role.inside, role.exit)
			editor.state:apply({ op = "batch", ops = {
				{ op = "set", id = id, path = { "role", "enterClip" }, value = enter },
				{ op = "set", id = id, path = { "role", "exitClip" }, value = leave },
			} })
		end, { LayoutOrder = order + 5 })
		Kit.button(list, L.EditEnterClip, function()
			editor.animTarget = { kind = "closet", id = id, which = "enterClip" }
			editor:selectTab("anim")
		end, { LayoutOrder = order + 6, Size = UDim2.new(1, 0, 0, 52) })
		Kit.button(list, L.EditExitClip, function()
			editor.animTarget = { kind = "closet", id = id, which = "exitClip" }
			editor:selectTab("anim")
		end, { LayoutOrder = order + 7, Size = UDim2.new(1, 0, 0, 52) })
	elseif t == "door" then
		Kit.stepper(list, L.DoorAngle, role.openAngle, 5, -180, 180, function(v)
			set({ "openAngle" }, v)
		end, order + 1)
		Kit.stepper(list, L.DoorTime, role.openTime, 0.1, 0, 10, function(v)
			set({ "openTime" }, v)
		end, order + 2)
		Kit.stepper(list, L.HingeOffset, role.hinge[1], 0.1, -200, 200, function(v)
			set({ "hinge" }, { v, role.hinge[2], role.hinge[3] })
		end, order + 3)
		Kit.toggle(list, L.OpenOnStart, role.open, function(v)
			set({ "open" }, v)
		end, order + 4)
		Kit.toggle(list, L.Locked, role.locked == true, function(v)
			set({ "locked" }, v)
		end, order + 5)
	elseif t == "light" then
		Kit.toggle(list, L.LightOn, role.on, function(v)
			set({ "on" }, v)
		end, order + 1)
		Kit.slider(list, L.Brightness, role.brightness, 0, 10, function(v)
			set({ "brightness" }, v)
		end, order + 2)
		Kit.slider(list, L.Range, role.range, 0, 60, function(v)
			set({ "range" }, v)
		end, order + 3)
		palette(list, role.color, function(c)
			set({ "color" }, c)
			editor:renderPanel()
		end, order + 4)
	elseif t == "creature" then
		Kit.stepper(list, L.Speed, role.speed, 1, 1, 100, function(v)
			set({ "speed" }, v)
		end, order + 1)
	elseif t == "waypoint" then
		Picker.field(editor, list, L.NextPoint, "waypoint", role.next and role.next.ref, function(pick)
			set({ "next" }, if pick then { ref = pick } else nil)
			editor:renderPanel()
		end, order + 1, true)
	elseif t == "npc" then
		local triggers = {
			{ id = "roomEnter", title = L.TriggerRoomEnter },
			{ id = "interact", title = L.TriggerInteract },
			{ id = "logic", title = L.TriggerLogic },
		}
		local cur = L.TriggerInteract
		for _, tr in triggers do
			if tr.id == role.trigger then
				cur = tr.title
			end
		end
		local _, trSlot = Kit.row(list, L.NpcTrigger, order + 1)
		Kit.button(trSlot, cur, function()
			Kit.choose(editor.gui, L.NpcTrigger, triggers, function(v)
				set({ "trigger" }, v)
				editor:renderPanel()
			end)
		end, { TextSize = 13 })
		if role.trigger == "roomEnter" then
			Picker.field(editor, list, L.RoleZone, "zone", role.zone and role.zone.ref, function(pick)
				set({ "zone" }, if pick then { ref = pick } else nil)
				editor:renderPanel()
			end, order + 2)
		end
		local _, clipSlot = Kit.row(list, L.GreetingClip, order + 3)
		Kit.button(clipSlot, role.greetingClip or L.None, function()
			local opts = clipNames(obj)
			table.insert(opts, 1, { id = false, title = L.None })
			Kit.choose(editor.gui, L.GreetingClip, opts, function(v)
				set({ "greetingClip" }, if v then v else nil)
				editor:renderPanel()
			end)
		end, { TextSize = 13 })
		Picker.field(editor, list, L.TextAnchor, nil, role.anchor and role.anchor.ref, function(pick)
			set({ "anchor" }, if pick then { ref = pick } else nil)
			editor:renderPanel()
		end, order + 4, true)
		Kit.stepper(list, L.TextSize, role.textSize, 2, 8, 60, function(v)
			set({ "textSize" }, v)
		end, order + 5)
		section(list, L.Lines, order + 6)
		for i, line in role.lines do
			local box = Kit.frame(list, { BackgroundColor3 = Kit.C.panel2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order + 6 + i })
			Kit.corner(box, 8)
			Kit.pad(box, 6)
			Kit.list(box, 4)
			Kit.textbox(box, line.text, L.LabelText, function(text)
				set({ "lines", i, "text" }, text)
			end, { MultiLine = true, TextWrapped = true, Size = UDim2.new(1, 0, 0, 70), TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 1 })
			Kit.stepper(box, L.LineDelay, line.delay, 0.5, 0, 120, function(v)
				set({ "lines", i, "delay" }, v)
			end, 2)
			Kit.stepper(box, L.LineDuration, line.duration, 0.5, 0.5, 60, function(v)
				set({ "lines", i, "duration" }, v)
			end, 3)
			Kit.button(box, L.Delete, function()
				local lines = table.clone(role.lines)
				table.remove(lines, i)
				set({ "lines" }, lines)
				editor:renderPanel()
			end, { LayoutOrder = 4, BackgroundColor3 = Kit.C.bad })
		end
		Kit.button(list, L.AddLine, function()
			local lines = table.clone(role.lines)
			local last = lines[#lines]
			table.insert(lines, { text = "…", delay = if last then last.delay + last.duration + 0.5 else 0, duration = 3 })
			set({ "lines" }, lines)
			editor:renderPanel()
		end, { LayoutOrder = order + 60 })
	end
end

function MapPanel.render(editor, panel: Frame)
	local list = Kit.scroll(panel)
	Kit.list(list, 6)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local project = editor.state.project

	-- добавление
	local adds = Kit.frame(list, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder() })
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(0.5, -4, 0, Kit.TAP)
	g.CellPadding = UDim2.fromOffset(6, 6)
	g.Parent = adds
	Kit.button(adds, L.AddShape, function()
		local opts = {}
		for _, s in Catalog.SHAPES do
			table.insert(opts, { id = s.id, title = s.title })
		end
		Kit.choose(editor.gui, L.Shapes, opts, function(shape)
			editor:addShape(shape)
		end)
	end)
	if not editor.modelEdit then
		Kit.button(adds, L.AddPrefab, function()
			local opts = {}
			for _, p in Catalog.PREFABS do
				table.insert(opts, { id = p.id, title = p.title, hint = p.group })
			end
			Kit.choose(editor.gui, L.AddPrefab, opts, function(pid)
				editor:addPrefab(pid)
			end)
		end)
		Kit.button(adds, L.MyModels, function()
			local res = Remotes.fn("Request"):InvokeServer("ListLibrary")
			if not res or not res.ok then
				Kit.toast(editor.gui, L.LoadFailed, Kit.C.bad)
				return
			end
			local opts = {}
			for _, m in res.models do
				table.insert(opts, { id = m.id, title = m.name })
			end
			if #opts == 0 then
				Kit.toast(editor.gui, L.NothingHere)
				return
			end
			Kit.choose(editor.gui, L.MyModels, opts, function(assetId)
				local r = Remotes.fn("Request"):InvokeServer("GetLibraryModel", assetId)
				if r and r.ok then
					local obj = Model.fromAsset(project, r.asset, editor.preview:placementPoint(editor.grid))
					editor:addObjects({ obj })
				else
					Kit.toast(editor.gui, L.LoadFailed, Kit.C.bad)
				end
			end)
		end)
	end

	local selId = editor.selection[1]
	local obj = selId and project.map.objects[selId]
	if editor.modelEdit then
		local m = project.map.objects[editor.modelEdit]
		Kit.button(adds, L.DoneEditing, function()
			editor:enterModelEdit(nil)
		end, { BackgroundColor3 = Kit.C.accent })
		Kit.label(list, H.ModelEditHint, { TextColor3 = Kit.C.dim, TextSize = 13, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 40) })
		if m and editor.selPart and m.model.parts[editor.selPart] then
			local part = m.model.parts[editor.selPart]
			Kit.textbox(list, part.name, L.Name, function(text)
				editor.state:apply({ op = "set", id = m.id, path = { "model", "parts", editor.selPart, "name" }, value = text })
			end, { LayoutOrder = nextOrder() })
			partProps(editor, list, m.id, { "model", "parts", editor.selPart }, part, nextOrder() * 100)
		else
			Kit.label(list, L.PickPart, { LayoutOrder = nextOrder() })
		end
		return nil
	end

	if obj and #editor.selection == 1 then
		if obj.kind == "model" then
			Kit.button(adds, L.EditModel, function()
				editor:enterModelEdit(obj.id)
			end)
			Kit.button(adds, L.SaveToMyModels, function()
				local r = Remotes.fn("Request"):InvokeServer("SaveLibraryModel", obj.id, obj.name)
				Kit.toast(editor.gui, if r and r.ok then H.SavedToLibraryHint else L.SaveFailed, if r and r.ok then Kit.C.good else Kit.C.bad)
			end)
			Kit.button(adds, L.Unglue, function()
				local op = Model.unglue(project, obj.id)
				if op then
					editor.state:apply(op)
				end
			end)
		end
	end

	if not obj then
		Kit.label(list, H.SelectHint, { TextColor3 = Kit.C.dim, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 40) })
		Kit.label(list, H.TouchHint, { TextColor3 = Kit.C.dim, TextSize = 13, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 40) })
		return nil
	end
	if #editor.selection > 1 then
		Kit.label(list, H.GlueHint, { TextColor3 = Kit.C.dim, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 40) })
		return nil
	end

	section(list, L.Properties, nextOrder())
	Kit.textbox(list, obj.name, L.Name, function(text)
		editor.state:apply({ op = "set", id = obj.id, path = { "name" }, value = text })
	end, { LayoutOrder = nextOrder() })
	Kit.textbox(list, obj.latin or "", L.LatinName, function(text)
		if text == (obj.latin or "") then
			return
		end
		if not Ids.isValidLatin(text) then
			Kit.toast(editor.gui, H.LatinHint, Kit.C.bad)
			editor:renderPanel()
			return
		end
		if Logic.isReservedName(text) then
			Kit.toast(editor.gui, H.LatinTakenHint, Kit.C.bad)
			editor:renderPanel()
			return
		end
		local ok = editor.state:apply({ op = "set", id = obj.id, path = { "latin" }, value = text })
		if not ok then
			Kit.toast(editor.gui, H.LatinTakenHint, Kit.C.bad)
			editor:renderPanel()
		end
	end, { LayoutOrder = nextOrder() })

	nudgePad(editor, list, obj, nextOrder() * 10)
	order += 10

	if obj.kind == "part" then
		partProps(editor, list, obj.id, {}, obj, nextOrder() * 100)
		order = order * 100 + 20
	end

	Kit.toggle(list, L.Anchored, obj.physics.anchored, function(v)
		editor.state:apply({ op = "set", id = obj.id, path = { "physics", "anchored" }, value = v })
	end, nextOrder())
	Kit.toggle(list, L.CanCollide, obj.physics.canCollide, function(v)
		editor.state:apply({ op = "set", id = obj.id, path = { "physics", "canCollide" }, value = v })
	end, nextOrder())
	Kit.toggle(list, L.HiddenAtStart, obj.hidden == true, function(v)
		editor.state:apply({ op = "set", id = obj.id, path = { "hidden" }, value = v })
	end, nextOrder())

	-- назначение
	section(list, if obj.role then ROLE_TITLES[obj.role.type] or L.AssignAs else L.NoRole, nextOrder())
	Kit.button(list, L.AssignAs, function()
		Kit.choose(editor.gui, L.AssignAs, ASSIGN, function(roleType)
			editor:assignRole(roleType)
		end)
	end, { LayoutOrder = nextOrder() })
	if obj.role then
		Kit.button(list, L.ClearRole, function()
			editor:assignRole(nil)
		end, { LayoutOrder = nextOrder() })
		roleProps(editor, list, obj, nextOrder() * 100)
	end

	-- привязки, требующие внимания
	for _, b in Logic.brokenBindings(project) do
		if b.objectId == obj.id then
			Kit.label(list, H.BrokenBindingHint, { TextColor3 = Kit.C.bad, TextSize = 13, LayoutOrder = 99999999, Size = UDim2.new(1, 0, 0, 40) })
			break
		end
	end
	return nil
end

return MapPanel
