--!nonstrict
-- Ручная анимация с ключевыми кадрами
-- Автор выбирает модель и деталь, ставит указатель времени, тянет деталь ручкой
-- (деталь двигается сразу, дети по суставам следуют за ней) и сохраняет ключ
-- Между ключами при прокрутке времени видна промежуточная поза

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local UiText = require(Shared.UiText)
local Util = require(Shared.Util)
local Anim = require(Shared.Anim)
local Rig = require(Shared.Rig)
local Format = require(Shared.Format)
local Convert = require(Shared.Roblox.Convert)
local WorldBuilder = require(Shared.Roblox.WorldBuilder)

local Kit = require(script.Parent.Parent.Parent.UI.Kit)

local L, H = UiText.L, UiText.H

local AnimPanel = {}

local LIFT = CFrame.new(0, 2.5, 0)

local function uniqueId(prefix: string, taken: { [string]: any }): string
	local n = 1
	while taken[prefix .. tostring(n)] do
		n += 1
	end
	return prefix .. tostring(n)
end

function AnimPanel.render(editor, panel: Frame, bottom: Frame)
	local project = editor.state.project
	local target = editor.animTarget
	if not target or not project.map.objects[target.id] then
		local sel = editor.selection[1]
		local o = sel and project.map.objects[sel]
		if o and o.kind == "model" then
			target = { kind = "model", id = sel }
		else
			target = nil
		end
	end
	editor.animTarget = target

	local side = Kit.scroll(panel)
	Kit.list(side, 6)
	if not target then
		Kit.label(side, H.ClipsNeedModelHint, { TextColor3 = Kit.C.dim, Size = UDim2.new(1, 0, 0, 60) })
		editor.animController = { onTap = function(_, id)
			local o = id and project.map.objects[id]
			if o and o.kind == "model" then
				editor.animTarget = { kind = "model", id = id }
				editor:select({ id })
				editor:renderPanel()
			end
		end, stop = function() end }
		editor.gizmo:setTarget(nil)
		return function()
			editor.animController = nil
		end
	end

	local c = {
		clipId = nil :: string?,
		time = 0,
		playing = false,
		part = nil :: string?,
		clipboard = nil,
		live = nil, -- временная поза детали, пока тянут ручку
	}
	local obj = project.map.objects[target.id]

	local function getClip()
		local o = project.map.objects[target.id]
		if not o then
			return nil
		end
		if target.kind == "closet" then
			return o.role and o.role[target.which]
		end
		if c.clipId and o.model.clips[c.clipId] then
			return o.model.clips[c.clipId]
		end
		return nil
	end
	local function clipPath(): { any }
		if target.kind == "closet" then
			return { "role", target.which }
		end
		return { "model", "clips", c.clipId :: string }
	end
	local function saveClip(clip)
		local ok, err = editor.state:apply({ op = "set", id = target.id, path = clipPath(), value = clip })
		if not ok then
			Kit.toast(editor.gui, tostring(err), Kit.C.bad)
		end
	end

	if target.kind == "model" then
		local first = nil
		for id, clip in obj.model.clips do
			if not first or clip.name < obj.model.clips[first].name then
				first = id
			end
		end
		c.clipId = editor.animClipId and obj.model.clips[editor.animClipId] and editor.animClipId or first
	else
		c.part = "PlayerRoot"
	end

	-- -----------------------------------------------------------------------
	-- поза на экране

	local function handle()
		return editor.preview.handles[target.id]
	end
	local function baseCF(): CFrame
		local o = project.map.objects[target.id]
		return WorldBuilder.objectCFrame(o, editor.preview.ORIGIN or Vector3.new(0, 0, -6000))
	end

	local function currentSample()
		local clip = getClip()
		local s = if clip then Anim.sample(clip, c.time) else {}
		if c.live then
			s[c.live.track] = { pos = c.live.pos, rot = c.live.rot }
		end
		return s
	end

	local function proxyFor(track: string): BasePart
		local size = if track == "Camera" then Vector3.new(0.8, 0.8, 1.4) else Vector3.new(2, 5, 1)
		local color = if track == "Camera" then Color3.fromRGB(240, 180, 60) else Color3.fromRGB(80, 200, 120)
		return editor:proxy("Anim_" .. track, CFrame.new(), size, color)
	end

	local function trackWorld(track: string, s): CFrame?
		local v = s[track]
		if not v then
			return nil
		end
		local cf = baseCF() * Convert.cfFrom(v.pos, v.rot)
		if track == "PlayerRoot" then
			cf *= LIFT
		end
		return cf
	end

	local updateGizmo

	local function showPose()
		local h = handle()
		if not h then
			return
		end
		local s = currentSample()
		if target.kind == "model" then
			WorldBuilder.poseModel(h, s, baseCF())
		else
			for _, track in { "PlayerRoot", "Camera" } do
				local cf = trackWorld(track, s)
				local p = proxyFor(track)
				p.CFrame = cf or baseCF()
			end
		end
	end

	function updateGizmo()
		local h = handle()
		if not h or not c.part or c.playing then
			editor.gizmo:setTarget(nil)
			return
		end
		local clip = getClip()
		if not clip then
			editor.gizmo:setTarget(nil)
			return
		end
		local track = c.part :: string
		if target.kind == "closet" then
			local p = proxyFor(track)
			editor.gizmo:setTarget({
				adornee = p, cf = p.CFrame, size = p.Size, allowMove = true, allowRotate = true, allowScale = false,
				onLive = function(cf)
					p.CFrame = cf
				end,
				onCommit = function(cf)
					local localCF = baseCF():ToObjectSpace(if track == "PlayerRoot" then cf * LIFT:Inverse() else cf)
					local pos, rot = Convert.posRot(localCF)
					local copy = Util.deepCopy(clip)
					Anim.setKey(copy, track, c.time, pos, rot, "smooth")
					saveClip(copy)
				end,
			})
			return
		end
		local part = h.parts[track]
		local o = project.map.objects[target.id]
		local data = o.model.parts[track]
		if not part or not data then
			editor.gizmo:setTarget(nil)
			return
		end
		local modelTf = Convert.tf(baseCF())
		editor.gizmo:setTarget({
			adornee = part, cf = part.CFrame, size = part.Size, allowMove = true, allowRotate = true, allowScale = false,
			pivot = CFrame.new(Convert.v3(data.pivot)),
			onLive = function(cf)
				-- деталь и все её дети двигаются сразу
				local s = Anim.sample(clip, c.time)
				local world = Rig.pose(o.model, s, modelTf)
				local dp, dr = Rig.solveDelta(o.model, world, modelTf, track, Convert.tf(cf))
				c.live = { track = track, pos = dp, rot = dr }
				showPose()
			end,
			onCommit = function()
				local live = c.live
				c.live = nil
				if not live then
					return
				end
				local copy = Util.deepCopy(clip)
				Anim.setKey(copy, track, c.time, live.pos, live.rot, "smooth")
				saveClip(copy)
			end,
		})
	end

	-- -----------------------------------------------------------------------
	-- боковая панель: клипы, детали, суставы, метки

	local renderTimeline

	local function renderSide()
		for _, ch in side:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		local o = project.map.objects[target.id]
		if not o then
			return
		end
		local order = 0
		local function n()
			order += 1
			return order
		end
		Kit.titleBlock(side, o.name, if target.kind == "closet" then (if target.which == "enterClip" then "EnterCloset" else "ExitCloset") else o.latin, n())
		local clip = getClip()
		if target.kind == "model" then
			Kit.label(side, L.Clips, { Font = Kit.FONT_BOLD, LayoutOrder = n() })
			local ids = Util.keys(o.model.clips)
			table.sort(ids, function(a, b)
				return o.model.clips[a].name < o.model.clips[b].name
			end)
			for _, cid in ids do
				local b = Kit.button(side, o.model.clips[cid].name, function()
					c.clipId = cid
					editor.animClipId = cid
					c.time = 0
					renderSide()
					renderTimeline()
					showPose()
					updateGizmo()
				end, { LayoutOrder = n() })
				Kit.setActive(b, cid == c.clipId)
			end
			Kit.button(side, L.NewClip, function()
				local cid = uniqueId("c", o.model.clips)
				local nc = Format.newClip(cid, L.NewClip .. " " .. tostring(Util.count(o.model.clips) + 1))
				local ok = editor.state:apply({ op = "set", id = target.id, path = { "model", "clips", cid }, value = nc })
				if ok then
					c.clipId = cid
					editor.animClipId = cid
				end
			end, { LayoutOrder = n() })
		end
		if clip then
			if target.kind == "model" then
				Kit.textbox(side, clip.name, L.ClipName, function(text)
					if text ~= "" and text ~= clip.name then
						local copy = Util.deepCopy(clip)
						copy.name = text
						saveClip(copy)
					end
				end, { LayoutOrder = n() })
				Kit.button(side, L.Delete, function()
					editor.state:apply({ op = "set", id = target.id, path = { "model", "clips", c.clipId :: string }, value = nil })
					c.clipId = nil
				end, { LayoutOrder = n(), BackgroundColor3 = Kit.C.bad })
			end
			Kit.stepper(side, L.ClipLength, clip.length, 0.1, 0.1, 120, function(v)
				local copy = Util.deepCopy(clip)
				Anim.setLength(copy, v)
				saveClip(copy)
			end, n())
			local modeRow = Kit.frame(side, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Kit.TAP), LayoutOrder = n() })
			local once = Kit.button(modeRow, L.ModeOnce, function()
				local copy = Util.deepCopy(clip)
				copy.loop = false
				saveClip(copy)
			end, { Size = UDim2.new(0.5, -3, 1, 0) })
			local loop = Kit.button(modeRow, L.ModeLoop, function()
				local copy = Util.deepCopy(clip)
				copy.loop = true
				saveClip(copy)
			end, { Size = UDim2.new(0.5, -3, 1, 0), Position = UDim2.new(0.5, 3, 0, 0) })
			Kit.setActive(once, not clip.loop)
			Kit.setActive(loop, clip.loop)

			-- метки на шкале времени
			Kit.label(side, L.Marker, { Font = Kit.FONT_BOLD, LayoutOrder = n() })
			for _, mk in clip.markers do
				local r = Kit.frame(side, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Kit.TAP), LayoutOrder = n() })
				Kit.button(r, string.format("%.2f  %s", mk.t, mk.name), function()
					c.time = mk.t
					renderTimeline()
					showPose()
				end, { Size = UDim2.new(1, -52, 1, 0), TextXAlignment = Enum.TextXAlignment.Left })
				Kit.button(r, "✕", function()
					local copy = Util.deepCopy(clip)
					Anim.removeMarker(copy, mk.id)
					saveClip(copy)
				end, { Size = UDim2.new(0, 46, 1, 0), Position = UDim2.new(1, -46, 0, 0), BackgroundColor3 = Kit.C.bad })
			end
			local markerName = Kit.textbox(side, "", L.Marker, nil, { LayoutOrder = n() })
			Kit.button(side, L.AddMarker, function()
				local name = Util.trim(markerName.Text)
				if name == "" then
					return
				end
				local copy = Util.deepCopy(clip)
				local taken = {}
				for _, mk in copy.markers do
					taken[mk.id] = true
				end
				Anim.addMarker(copy, uniqueId("k", taken), c.time, name)
				saveClip(copy)
			end, { LayoutOrder = n() })
		end

		if target.kind == "closet" then
			for _, track in { "PlayerRoot", "Camera" } do
				local b = Kit.button(side, track, function()
					c.part = track
					renderSide()
					renderTimeline()
					updateGizmo()
				end, { LayoutOrder = n() })
				Kit.setActive(b, c.part == track)
			end
			return
		end

		-- суставы выбранной детали
		Kit.label(side, L.Joints, { Font = Kit.FONT_BOLD, LayoutOrder = n() })
		local pid = c.part
		local part = pid and o.model.parts[pid]
		if not part then
			Kit.label(side, L.PickPart, { TextColor3 = Kit.C.dim, LayoutOrder = n() })
		else
			Kit.label(side, part.name, { LayoutOrder = n() })
			local _, slot = Kit.row(side, L.JointParent, n())
			local parentName = if part.parent and o.model.parts[part.parent] then o.model.parts[part.parent].name else L.NoParent
			Kit.button(slot, parentName, function()
				local opts = { { id = false, title = L.NoParent } }
				for qid, q in o.model.parts do
					if qid ~= pid then
						table.insert(opts, { id = qid, title = q.name, hint = qid })
					end
				end
				Kit.choose(editor.gui, L.JointParent, opts, function(parentId)
					local copy = Util.deepCopy(o.model)
					if Rig.setParent(copy, pid :: string, if parentId then parentId else nil) then
						editor.state:apply({ op = "set", id = target.id, path = { "model", "parts", pid :: string, "parent" }, value = copy.parts[pid :: string].parent })
					end
				end)
			end, { TextSize = 13 })
			for axis = 1, 3 do
				Kit.stepper(side, L.Pivot .. " " .. ({ "X", "Y", "Z" })[axis], part.pivot[axis], 0.1, -512, 512, function(v)
					local p = table.clone(part.pivot)
					p[axis] = v
					editor.state:apply({ op = "set", id = target.id, path = { "model", "parts", pid :: string, "pivot" }, value = p })
				end, n())
			end
		end

		-- дорожки удалённых деталей: ключи сохранены, их можно перенести
		if clip then
			local missing = Anim.validate(clip, o.model.parts)
			if #missing > 0 then
				Kit.label(side, H.MissingTrackHint, { TextColor3 = Kit.C.bad, TextSize = 13, LayoutOrder = n(), Size = UDim2.new(1, 0, 0, 60) })
				for _, trackId in missing do
					Kit.button(side, L.MissingPart .. "\n" .. trackId, function()
						if not c.part or not o.model.parts[c.part] then
							Kit.toast(editor.gui, L.PickPart)
							return
						end
						local copy = Util.deepCopy(clip)
						if Anim.retarget(copy, trackId, c.part) then
							saveClip(copy)
						end
					end, { LayoutOrder = n(), BackgroundColor3 = Kit.C.bad, Size = UDim2.new(1, 0, 0, 52) })
				end
			end
		end
	end

	-- -----------------------------------------------------------------------
	-- шкала времени

	local tl = Kit.frame(bottom, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local controls = Kit.scroll(tl, {
		Size = UDim2.new(1, 0, 0, Kit.TAP), ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollBarThickness = 0,
	})
	Kit.list(controls, 4, true)
	local timeLabel = Kit.label(controls, "0.00", { Size = UDim2.new(0, 64, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 0 })
	local playButton
	local function stepT(): number
		return if editor.grid > 0 then 0.1 else 0.05
	end
	local buttons = {
		{ L.Preview, function()
			c.playing = not c.playing
			playButton.Text = if c.playing then L.Stop else L.Preview
			updateGizmo()
		end },
		{ L.KeyAdd, function()
			local clip = getClip()
			if not clip or not c.part then
				Kit.toast(editor.gui, L.PickPart)
				return
			end
			local s = currentSample()[c.part]
			local copy = Util.deepCopy(clip)
			Anim.setKey(copy, c.part, c.time, if s then s.pos else { 0, 0, 0 }, if s then s.rot else { 0, 0, 0 }, "smooth")
			saveClip(copy)
		end },
		{ L.KeyDelete, function()
			local clip = getClip()
			if clip and c.part then
				local copy = Util.deepCopy(clip)
				if Anim.removeKey(copy, c.part, c.time) then
					saveClip(copy)
				end
			end
		end },
		{ L.KeyCopy, function()
			local clip = getClip()
			local k = clip and c.part and Anim.findKey(clip, c.part, c.time)
			if k then
				c.clipboard = Util.deepCopy(k)
			end
		end },
		{ L.KeyPaste, function()
			local clip = getClip()
			if clip and c.part and c.clipboard then
				local copy = Util.deepCopy(clip)
				Anim.setKey(copy, c.part, c.time, c.clipboard.pos, c.clipboard.rot, c.clipboard.ease)
				saveClip(copy)
			end
		end },
		{ L.KeyMoveLeft, function()
			local clip = getClip()
			if clip and c.part then
				local copy = Util.deepCopy(clip)
				local to = math.max(0, c.time - stepT())
				if Anim.moveKey(copy, c.part, c.time, to) then
					c.time = to
					saveClip(copy)
				end
			end
		end },
		{ L.KeyMoveRight, function()
			local clip = getClip()
			if clip and c.part then
				local copy = Util.deepCopy(clip)
				local to = math.min(clip.length, c.time + stepT())
				if Anim.moveKey(copy, c.part, c.time, to) then
					c.time = to
					saveClip(copy)
				end
			end
		end },
	}
	for i, b in buttons do
		local btn = Kit.button(controls, b[1], b[2], { Size = UDim2.new(0, 108, 1, 0), LayoutOrder = i, TextSize = 13 })
		if i == 1 then
			playButton = btn
		end
	end

	local area = Kit.scroll(tl, { Position = UDim2.fromOffset(0, Kit.TAP + 4), Size = UDim2.new(1, 0, 1, -Kit.TAP - 4) })
	Kit.list(area, 2)
	local NAME_W = 130

	local scrub = Kit.frame(area, { BackgroundColor3 = Kit.C.bg, Size = UDim2.new(1, -8, 0, 34), LayoutOrder = 0 })
	Kit.corner(scrub, 6)
	local playhead = Kit.frame(scrub, { BackgroundColor3 = Kit.C.accent, Size = UDim2.new(0, 3, 1, 0) })
	local rowsHolder = Kit.frame(area, { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 })
	Kit.list(rowsHolder, 2)

	local function laneX(t: number, width: number): number
		local clip = getClip()
		local len = if clip then clip.length else 1
		return NAME_W + (width - NAME_W) * (t / len)
	end

	local function updatePlayhead()
		timeLabel.Text = string.format("%.2f", c.time)
		local w = scrub.AbsoluteSize.X
		playhead.Position = UDim2.fromOffset(laneX(c.time, w), 0)
	end

	function renderTimeline()
		for _, ch in rowsHolder:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		local clip = getClip()
		updatePlayhead()
		if not clip then
			return
		end
		local o = project.map.objects[target.id]
		local tracks = {}
		local seen = {}
		for trackId in clip.tracks do
			table.insert(tracks, trackId)
			seen[trackId] = true
		end
		if c.part and not seen[c.part] then
			table.insert(tracks, c.part)
		end
		table.sort(tracks)
		local missing = {}
		if target.kind == "model" then
			for _, m in Anim.validate(clip, o.model.parts) do
				missing[m] = true
			end
		end
		local width = rowsHolder.AbsoluteSize.X
		for i, trackId in tracks do
			local row = Kit.frame(rowsHolder, { BackgroundColor3 = if missing[trackId] then Color3.fromRGB(90, 30, 30) else Kit.C.panel2, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = i })
			Kit.corner(row, 6)
			local name = trackId
			if target.kind == "model" and o.model.parts[trackId] then
				name = o.model.parts[trackId].name
			elseif missing[trackId] then
				name = L.MissingPart
			end
			local nb = Kit.button(row, name, function()
				if target.kind == "closet" or o.model.parts[trackId] then
					c.part = trackId
					renderSide()
					renderTimeline()
					updateGizmo()
				end
			end, { Size = UDim2.new(0, NAME_W - 6, 1, 0), TextSize = 12, BackgroundTransparency = if c.part == trackId then 0 else 1 })
			if missing[trackId] then
				nb.TextColor3 = Kit.C.bad
			end
			local track = clip.tracks[trackId]
			for _, k in (track and track.keys) or {} do
				local dot = Kit.button(row, "", function()
					c.time = k.t
					c.part = if target.kind == "closet" or o.model.parts[trackId] then trackId else c.part
					renderTimeline()
					showPose()
					updateGizmo()
				end, {
					Size = UDim2.fromOffset(18, 18),
					Position = UDim2.fromOffset(laneX(k.t, width) - 9, 9),
					BackgroundColor3 = if math.abs(k.t - c.time) < Anim.KEY_EPS then Kit.C.warn else Kit.C.text,
				})
				Kit.corner(dot, 9)
			end
		end
		for _, mk in clip.markers do
			local m = Kit.frame(scrub, { BackgroundColor3 = Kit.C.warn, Size = UDim2.fromOffset(4, 34), Position = UDim2.fromOffset(laneX(mk.t, scrub.AbsoluteSize.X) - 2, 0) })
			m.Name = "Marker"
		end
	end

	-- перетаскивание указателя времени
	local scrubbing = false
	local function scrubAt(x: number)
		local clip = getClip()
		if not clip then
			return
		end
		local w = scrub.AbsoluteSize.X
		local a = math.clamp((x - scrub.AbsolutePosition.X - NAME_W) / math.max(w - NAME_W, 1), 0, 1)
		local step = if editor.grid > 0 then 1 / 30 else 1 / 120
		c.time = math.floor(a * clip.length / step + 0.5) * step
		updatePlayhead()
		showPose()
	end
	local conns = {}
	table.insert(conns, scrub.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			scrubbing = true
			c.playing = false
			playButton.Text = L.Preview
			scrubAt(input.Position.X)
		end
	end))
	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if scrubbing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			scrubAt(input.Position.X)
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		if scrubbing and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			scrubbing = false
			renderTimeline()
			updateGizmo()
		end
	end))

	-- предпросмотр «Один раз» / «Повтор»
	table.insert(conns, RunService.RenderStepped:Connect(function(dt)
		if not c.playing then
			return
		end
		local clip = getClip()
		if not clip then
			return
		end
		c.time += dt
		if c.time >= clip.length then
			if clip.loop then
				c.time %= clip.length
			else
				c.time = clip.length
				c.playing = false
				playButton.Text = L.Preview
				updateGizmo()
			end
		end
		updatePlayhead()
		showPose()
	end))
	table.insert(conns, scrub:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		renderTimeline()
	end))

	editor.animController = {
		onTap = function(id: string?, partId: string?)
			if target.kind == "model" and id == target.id and partId then
				c.part = partId
				renderSide()
				renderTimeline()
				updateGizmo()
			elseif id and id ~= target.id then
				local o = project.map.objects[id]
				if o and o.kind == "model" then
					editor.animTarget = { kind = "model", id = id }
					editor:select({ id })
				end
			end
		end,
		stop = function()
			c.playing = false
		end,
	}

	local prevChanged = editor.onProjectChanged
	editor.onProjectChanged = function()
		project = editor.state.project
		if not project.map.objects[target.id] then
			return
		end
		if target.kind == "model" and c.clipId and not project.map.objects[target.id].model.clips[c.clipId] then
			c.clipId = nil
		end
		renderSide()
		renderTimeline()
		showPose()
		updateGizmo()
	end

	renderSide()
	task.defer(function()
		renderTimeline()
		showPose()
		updateGizmo()
	end)

	return function()
		for _, cn in conns do
			cn:Disconnect()
		end
		editor.onProjectChanged = prevChanged
		editor.animController = nil
		editor.gizmo:setTarget(nil)
		editor:clearHelpers()
		local h = handle()
		if h then
			WorldBuilder.restWorld(h, baseCF())
		end
	end
end

return AnimPanel
