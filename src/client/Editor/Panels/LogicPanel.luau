--!nonstrict
-- Логика карты: блоки в духе Scratch и текстовый режим с командами, похожими на Luau
-- Оба режима редактируют одно дерево и пользуются одним набором команд

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local UiText = require(Shared.UiText)
local Util = require(Shared.Util)
local Logic = require(Shared.Logic)
local Commands = require(Shared.Logic.Commands)

local Kit = require(script.Parent.Parent.Parent.UI.Kit)
local Picker = require(script.Parent.Parent.Picker)

local L, H = UiText.L, UiText.H

local LogicPanel = {}

local function sortedDefs(t)
	local out = {}
	for name, def in t do
		table.insert(out, { id = name, title = def.title, hint = name })
	end
	table.sort(out, function(a, b)
		return a.title < b.title
	end)
	return out
end

local function defaultArg(spec)
	local t = spec.type
	if t == "number" then
		return { kind = "num", value = spec.min or 1 }
	elseif t == "bool" then
		return { kind = "bool", value = true }
	elseif t == "weather" then
		return { kind = "str", value = "Rain" }
	elseif t == "text" or t == "string" or t == "clip" or t == "sound" then
		return { kind = "str", value = "" }
	end
	return { kind = "ref", ref = "" }
end

local function defaultArgs(def)
	local args = {}
	for i, spec in def.args do
		if not spec.optional then
			args[i] = defaultArg(spec)
		end
	end
	return args
end

function LogicPanel.render(editor, panel: Frame)
	local project = editor.state.project
	local root = Kit.frame(panel, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })

	local header = Kit.frame(root, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Kit.TAP) })
	Kit.list(header, 6, true)
	local body = Kit.frame(root, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, Kit.TAP + 6), Size = UDim2.new(1, 0, 1, -Kit.TAP - 6) })

	local errorsBox: Frame
	local errorsByBid: { [string]: string } = {}
	local errorsByLine: { [number]: string } = {}

	local function compileErrors()
		local _, errs = Logic.compile(editor.state.project)
		local all = table.clone(errs or {})
		for _, e in editor.logicErrors or {} do
			if e.runtime then
				table.insert(all, e)
			end
		end
		return all
	end

	local render

	local function showErrors(errs)
		table.clear(errorsByBid)
		table.clear(errorsByLine)
		for _, ch in errorsBox:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		if #errs == 0 then
			Kit.label(errorsBox, L.NoErrors, { TextColor3 = Kit.C.good, TextSize = 14 })
			return
		end
		for i, e in errs do
			if e.bid then
				errorsByBid[e.bid] = e.message
			end
			if e.line then
				errorsByLine[e.line] = e.message
			end
			local text = if e.line and project.logic.mode == "text"
				then string.format(L.ErrorAtLine, e.line, e.message)
				else string.format(L.ErrorInBlock, e.message)
			Kit.label(errorsBox, text, { TextColor3 = Kit.C.bad, TextSize = 13, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 40) })
		end
	end

	local function setTree(tree)
		local ok, err = editor.state:apply({ op = "setProject", path = { "logic", "blocks" }, value = tree })
		if not ok then
			Kit.toast(editor.gui, tostring(err), Kit.C.bad)
		end
		editor.logicErrors = {}
		render()
	end

	local modeBlocks = Kit.button(header, L.LogicBlocks, function()
		if project.logic.mode == "blocks" then
			return
		end
		local tree, errs = Logic.Parser.parse(project.logic.text.source, Logic.nameResolver(project))
		if not tree or (errs and #errs > 0) then
			showErrors(errs or {})
			Kit.toast(editor.gui, H.LogicErrorHint, Kit.C.bad)
			return
		end
		editor.state:apply({ op = "batch", ops = {
			{ op = "setProject", path = { "logic", "blocks" }, value = tree },
			{ op = "setProject", path = { "logic", "mode" }, value = "blocks" },
		} })
		render()
	end, { Size = UDim2.new(0, 110, 1, 0), LayoutOrder = 1 })
	local modeText = Kit.button(header, L.LogicText, function()
		if project.logic.mode == "text" then
			return
		end
		local source = Logic.toText(project, project.logic.blocks)
		editor.state:apply({ op = "batch", ops = {
			{ op = "setProject", path = { "logic", "text" }, value = { source = source, refs = Logic.collectRefs(project.logic.blocks) } },
			{ op = "setProject", path = { "logic", "mode" }, value = "text" },
		} })
		render()
	end, { Size = UDim2.new(0, 110, 1, 0), LayoutOrder = 2 })
	Kit.button(header, L.Check, function()
		showErrors(compileErrors())
	end, { Size = UDim2.new(0, 110, 1, 0), LayoutOrder = 3 })

	-- -----------------------------------------------------------------------
	-- блоки

	local nextBid = 0
	local function freshBid(tree): string
		local used = {}
		local function walk(v)
			if type(v) ~= "table" then
				return
			end
			if type(v.bid) == "string" then
				used[v.bid] = true
			end
			for _, x in v do
				walk(x)
			end
		end
		walk(tree)
		repeat
			nextBid += 1
		until not used["b" .. nextBid]
		return "b" .. nextBid
	end

	local function argField(parent: Instance, tree, node, def, i: number, order: number)
		local spec = def.args[i]
		local a = node.args[i]
		local title = spec.title
		local t = spec.type
		if Commands.TARGET_TYPES[t] then
			Picker.field(editor, parent, title, t, a and a.ref, function(id)
				node.args[i] = { kind = "ref", ref = id }
				setTree(tree)
			end, order)
		elseif t == "clip" then
			local _, slot = Kit.row(parent, title, order)
			local modelId = nil
			for j, s in def.args do
				if s.type == "model" and node.args[j] and node.args[j].kind == "ref" then
					modelId = node.args[j].ref
					break
				end
			end
			Kit.button(slot, if a and a.kind == "str" and a.value ~= "" then a.value else "…", function()
				local m = modelId and project.map.objects[modelId]
				local opts = {}
				if spec.optional then
					table.insert(opts, { id = false, title = L.None })
				end
				if m and m.kind == "model" then
					for _, cl in m.model.clips do
						table.insert(opts, { id = cl.name, title = cl.name })
					end
				end
				Kit.choose(editor.gui, title, opts, function(name)
					if name then
						node.args[i] = { kind = "str", value = name }
					else
						node.args[i] = nil
					end
					setTree(tree)
				end)
			end, { TextSize = 13 })
		elseif t == "weather" then
			local _, slot = Kit.row(parent, title, order)
			local cur = a and a.kind == "str" and Commands.WEATHER_TITLES[a.value] or "…"
			Kit.button(slot, cur, function()
				local opts = {}
				for _, id in { "Clear", "Rain", "Snow", "Fog", "Storm" } do
					table.insert(opts, { id = id, title = Commands.WEATHER_TITLES[id] })
				end
				Kit.choose(editor.gui, title, opts, function(id)
					node.args[i] = { kind = "str", value = id }
					setTree(tree)
				end)
			end, { TextSize = 13 })
		elseif t == "bool" then
			local v = a and a.kind == "bool" and a.value
			Kit.toggle(parent, title, v == true, function(nv)
				node.args[i] = { kind = "bool", value = nv }
				setTree(tree)
			end, order)
		elseif t == "number" then
			local _, slot = Kit.row(parent, title, order)
			local text = if a and a.kind == "num" then tostring(a.value) elseif a then Logic.Printer.exprText(a, Logic.nameOf(project)) else ""
			Kit.textbox(slot, text, "—", function(s)
				local n = tonumber((string.gsub(s, ",", ".")))
				if n then
					node.args[i] = { kind = "num", value = n }
				elseif s == "" and spec.optional then
					node.args[i] = nil
				else
					return
				end
				-- необязательные аргументы не должны оставлять дыр
				setTree(tree)
			end)
		else
			local _, slot = Kit.row(parent, title, order)
			Kit.textbox(slot, if a and a.kind == "str" then a.value else "", title, function(s)
				node.args[i] = { kind = "str", value = s }
				setTree(tree)
			end, { MultiLine = t == "text", TextWrapped = true })
			if t == "text" then
				slot.Parent.Size = UDim2.new(1, 0, 0, 64)
			end
		end
	end

	local function fixHoles(args)
		-- аргументы идут подряд: после пропущенного необязательного остальные не учитываются
		local n = 0
		for k in args do
			if type(k) == "number" and k > n then
				n = k
			end
		end
		for k = 1, n do
			if args[k] == nil then
				for j = k, n do
					args[j] = nil
				end
				break
			end
		end
	end

	local renderBody

	local function card(parent: Instance, bid: string?, depth: number, order: number): Frame
		local f = Kit.frame(parent, {
			BackgroundColor3 = if depth == 0 then Kit.C.accentDim else Kit.C.panel2,
			Size = UDim2.new(1, -depth * 12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
		})
		Kit.corner(f, 8)
		Kit.pad(f, 6)
		Kit.list(f, 4)
		if bid and errorsByBid[bid] then
			local s = Instance.new("UIStroke")
			s.Color = Kit.C.bad
			s.Thickness = 2
			s.Parent = f
			Kit.label(f, errorsByBid[bid], { TextColor3 = Kit.C.bad, TextSize = 13, LayoutOrder = 999, Size = UDim2.new(1, 0, 0, 36) })
		end
		return f
	end

	local function moveButtons(parent: Instance, tree, list, index: number)
		local row = Kit.frame(parent, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 900 })
		Kit.list(row, 4, true)
		Kit.button(row, "↑", function()
			if index > 1 then
				list[index], list[index - 1] = list[index - 1], list[index]
				setTree(tree)
			end
		end, { Size = UDim2.new(0, 52, 1, 0), LayoutOrder = 1 })
		Kit.button(row, "↓", function()
			if index < #list then
				list[index], list[index + 1] = list[index + 1], list[index]
				setTree(tree)
			end
		end, { Size = UDim2.new(0, 52, 1, 0), LayoutOrder = 2 })
		Kit.button(row, L.Delete, function()
			table.remove(list, index)
			setTree(tree)
		end, { Size = UDim2.new(0, 100, 1, 0), LayoutOrder = 3, BackgroundColor3 = Kit.C.bad })
	end

	local function condEditor(parent: Instance, tree, holder, key: string)
		local cond = holder[key]
		local negated = cond and cond.kind == "not"
		local inner = if negated then cond.e else cond
		if inner and inner.kind ~= "cond" then
			Kit.label(parent, Logic.Printer.exprText(cond, Logic.nameOf(project)), { TextSize = 13, LayoutOrder = 2 })
			return
		end
		local def = inner and Commands.conditions[inner.name]
		Kit.button(parent, if def then def.title else L.AddCondition, function()
			Kit.choose(editor.gui, L.AddCondition, sortedDefs(Commands.conditions), function(name)
				local c = { kind = "cond", name = name, args = defaultArgs(Commands.conditions[name]) }
				holder[key] = if negated then { kind = "not", e = c } else c
				setTree(tree)
			end)
		end, { LayoutOrder = 2 })
		Kit.toggle(parent, "not", negated, function(v)
			if inner then
				holder[key] = if v then { kind = "not", e = inner } else inner
				setTree(tree)
			end
		end, 3)
		if def then
			for i = 1, #def.args do
				argField(parent, tree, inner, def, i, 10 + i)
			end
		end
	end

	function renderBody(parent: Instance, tree, list, depth: number, baseOrder: number)
		for index, st in list do
			local f = card(parent, st.bid, depth, baseOrder + index)
			if st.kind == "call" then
				local def = Commands.actions[st.name]
				Kit.button(f, if def then def.title else tostring(st.name), function()
					Kit.choose(editor.gui, L.AddAction, sortedDefs(Commands.actions), function(name)
						st.name = name
						st.args = defaultArgs(Commands.actions[name])
						setTree(tree)
					end)
				end, { LayoutOrder = 1, Font = Kit.FONT_BOLD })
				if def then
					for i = 1, #def.args do
						argField(f, tree, st, def, i, 10 + i)
					end
					fixHoles(st.args)
				end
			elseif st.kind == "if" then
				Kit.label(f, L.AddIf, { Font = Kit.FONT_BOLD, LayoutOrder = 1 })
				local br = st.branches[1]
				condEditor(f, tree, br, "cond")
				local inner = Kit.frame(f, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 50 })
				Kit.list(inner, 4)
				renderBody(inner, tree, br.body, depth + 1, 0)
				st.elseBody = st.elseBody or {}
				Kit.label(f, L.AddElse, { Font = Kit.FONT_BOLD, LayoutOrder = 60 })
				local elseF = Kit.frame(f, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 61 })
				Kit.list(elseF, 4)
				renderBody(elseF, tree, st.elseBody, depth + 1, 0)
			elseif st.kind == "for" then
				Kit.label(f, L.AddRepeat, { Font = Kit.FONT_BOLD, LayoutOrder = 1 })
				local count = if st.to.kind == "num" then st.to.value else 1
				Kit.stepper(f, L.AddRepeat, count, 1, 1, 1000, function(v)
					st.from = { kind = "num", value = 1 }
					st.to = { kind = "num", value = v }
					setTree(tree)
				end, 2)
				local inner = Kit.frame(f, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 50 })
				Kit.list(inner, 4)
				renderBody(inner, tree, st.body, depth + 1, 0)
			else
				-- переменные редактируются в текстовом режиме
				Kit.label(f, Logic.Printer.stmtText(st, Logic.nameOf(project)), { TextSize = 13, LayoutOrder = 1, Font = Enum.Font.Code })
			end
			moveButtons(f, tree, list, index)
		end
		-- добавление блоков
		local adds = Kit.frame(parent, { BackgroundTransparency = 1, Size = UDim2.new(1, -depth * 12, 0, 40), LayoutOrder = baseOrder + #list + 1 })
		Kit.list(adds, 4, true)
		Kit.button(adds, "+ " .. L.AddAction, function()
			Kit.choose(editor.gui, L.AddAction, sortedDefs(Commands.actions), function(name)
				table.insert(list, { kind = "call", name = name, args = defaultArgs(Commands.actions[name]), bid = freshBid(tree) })
				setTree(tree)
			end)
		end, { Size = UDim2.new(0, 140, 1, 0), LayoutOrder = 1, TextSize = 13 })
		Kit.button(adds, "+ " .. L.AddIf, function()
			table.insert(list, {
				kind = "if", bid = freshBid(tree),
				branches = { { cond = { kind = "cond", name = "LightIsOn", args = { { kind = "ref", ref = "" } } }, body = {} } },
				elseBody = {},
			})
			setTree(tree)
		end, { Size = UDim2.new(0, 100, 1, 0), LayoutOrder = 2, TextSize = 13 })
		Kit.button(adds, "+ " .. L.AddRepeat, function()
			table.insert(list, { kind = "for", var = "i", from = { kind = "num", value = 1 }, to = { kind = "num", value = 3 }, body = {}, bid = freshBid(tree) })
			setTree(tree)
		end, { Size = UDim2.new(0, 130, 1, 0), LayoutOrder = 3, TextSize = 13 })
	end

	local function renderBlocks(container: Instance)
		local tree = Util.deepCopy(project.logic.blocks)
		local list = Kit.scroll(container)
		Kit.list(list, 8)
		for hi, h in tree.handlers do
			local f = card(list, h.bid, 0, hi)
			local def = Commands.events[h.event]
			Kit.button(f, if def then def.title else tostring(h.event), function()
				Kit.choose(editor.gui, L.AddEvent, sortedDefs(Commands.events), function(name)
					h.event = name
					h.args = defaultArgs(Commands.events[name])
					setTree(tree)
				end)
			end, { LayoutOrder = 1, Font = Kit.FONT_BOLD })
			if def then
				for i = 1, #def.args do
					argField(f, tree, h, def, i, 10 + i)
				end
			end
			local inner = Kit.frame(f, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 50 })
			Kit.list(inner, 4)
			renderBody(inner, tree, h.body, 1, 0)
			moveButtons(f, tree, tree.handlers, hi)
		end
		Kit.button(list, "+ " .. L.AddEvent, function()
			Kit.choose(editor.gui, L.AddEvent, sortedDefs(Commands.events), function(name)
				table.insert(tree.handlers, { kind = "handler", event = name, args = defaultArgs(Commands.events[name]), body = {}, bid = freshBid(tree) })
				setTree(tree)
			end)
		end, { LayoutOrder = #tree.handlers + 1 })
	end

	-- -----------------------------------------------------------------------
	-- текст

	local function renderText(container: Instance)
		Logic.refreshText(project)
		local src = project.logic.text.source
		local scroll = Kit.scroll(container, { ScrollingDirection = Enum.ScrollingDirection.XY, AutomaticCanvasSize = Enum.AutomaticSize.XY })
		local gutter = Kit.label(scroll, "", {
			Size = UDim2.new(0, 34, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.Code, TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Kit.C.dim, RichText = true,
			TextWrapped = false,
		})
		local box = Kit.textbox(scroll, src, "on MapStarted() do\n  Wait(1)\nend", nil, {
			MultiLine = true, TextWrapped = false, Font = Enum.Font.Code, TextSize = 15,
			TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(40, 0),
			Size = UDim2.new(1, -44, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
		})
		local function updateGutter()
			local lines = {}
			local n = 1
			for _ in string.gmatch(box.Text, "\n") do
				n += 1
			end
			for i = 1, n do
				if errorsByLine[i] then
					table.insert(lines, string.format('<font color="#eb5050">%d</font>', i))
				else
					table.insert(lines, tostring(i))
				end
			end
			gutter.Text = table.concat(lines, "\n")
		end
		updateGutter()
		box:GetPropertyChangedSignal("Text"):Connect(updateGutter)
		box.FocusLost:Connect(function()
			-- введённый код сохраняется всегда, даже с ошибками, чтобы его можно было исправить
			local text = box.Text
			local tree = Logic.Parser.parse(text, Logic.nameResolver(project))
			local refs = if tree then Logic.collectRefs(tree) else project.logic.text.refs
			editor.state:apply({ op = "setProject", path = { "logic", "text" }, value = { source = text, refs = refs } })
			editor.logicErrors = {}
			showErrors(compileErrors())
			updateGutter()
		end)
	end

	function render()
		project = editor.state.project
		for _, ch in body:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		Kit.setActive(modeBlocks, project.logic.mode == "blocks")
		Kit.setActive(modeText, project.logic.mode == "text")
		errorsBox = Kit.frame(body, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
		Kit.list(errorsBox, 2)
		local errs = compileErrors()
		for _, e in editor.logicErrors or {} do
			if not e.runtime then
				table.insert(errs, e)
			end
		end
		showErrors(errs)
		local content = Kit.frame(body, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromScale(1, 1) })
		errorsBox:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			content.Position = UDim2.fromOffset(0, errorsBox.AbsoluteSize.Y + 6)
			content.Size = UDim2.new(1, 0, 1, -errorsBox.AbsoluteSize.Y - 6)
		end)
		content.Position = UDim2.fromOffset(0, errorsBox.AbsoluteSize.Y + 6)
		content.Size = UDim2.new(1, 0, 1, -errorsBox.AbsoluteSize.Y - 6)
		if project.logic.mode == "text" then
			renderText(content)
		else
			renderBlocks(content)
		end
	end

	render()
	return nil
end

return LogicPanel
