--!nonstrict
-- Вкладка «Тексты»: надписи на табличках, дверях и над объектами, реплики NPC
-- и предпросмотр на маленьком экране

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local UiText = require(Shared.UiText)
local Catalog = require(Shared.Catalog)
local Util = require(Shared.Util)

local Kit = require(script.Parent.Parent.Parent.UI.Kit)
local Bubble = require(script.Parent.Parent.Parent.Play.Bubble)

local L = UiText.L

local TextsPanel = {}

local PHONE = Vector2.new(667, 375)
local FACES = { "Front", "Back", "Left", "Right", "Top", "Bottom" }

function TextsPanel.render(editor, panel: Frame)
	local project = editor.state.project
	local list = Kit.scroll(panel)
	Kit.list(list, 8)

	-- все тексты карты
	local items = {}
	for id, obj in project.map.objects do
		if obj.label then
			table.insert(items, { id = id, title = obj.name, hint = obj.label.text })
		elseif obj.role and obj.role.type == "npc" and #obj.role.lines > 0 then
			table.insert(items, { id = id, title = obj.name, hint = obj.role.lines[1].text })
		end
	end
	table.sort(items, function(a, b)
		return a.title < b.title
	end)
	for i, it in items do
		local hint = it.hint
		if utf8.len(hint) and (utf8.len(hint) :: number) > 40 then
			hint = string.sub(hint, 1, (utf8.offset(hint, 40) :: number) - 1) .. "…"
		end
		Kit.button(list, it.title .. "\n" .. hint, function()
			editor:select({ it.id })
		end, { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 52), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13 })
	end

	local id = editor.selection[1]
	local obj = id and project.map.objects[id]
	local base = 100
	local previewText: string? = nil
	local previewSize = 22
	local previewWrap = true
	if obj then
		Kit.titleBlock(list, obj.name, obj.latin, base)
		local label = obj.label
		local function set(path, value)
			local full = { "label" }
			for _, k in path do
				table.insert(full, k)
			end
			local ok, err = editor.state:apply({ op = "set", id = obj.id, path = full, value = value })
			if not ok then
				Kit.toast(editor.gui, tostring(err), Kit.C.bad)
			end
		end
		if not label then
			Kit.button(list, L.AddLabel, function()
				editor.state:apply({ op = "set", id = obj.id, path = { "label" }, value = {
					text = obj.name, mode = if obj.kind == "model" then "billboard" else "surface",
					face = "Front", size = 24, wrap = true, color = { 17, 17, 17 }, visible = true,
				} })
				editor:renderPanel()
			end, { LayoutOrder = base + 1 })
		else
			Kit.textbox(list, label.text, L.LabelText, function(text)
				set({ "text" }, text)
				editor:renderPanel()
			end, { MultiLine = true, TextWrapped = true, Size = UDim2.new(1, 0, 0, 80), TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = base + 2 })
			local modeRow = Kit.frame(list, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Kit.TAP), LayoutOrder = base + 3 })
			local surf = Kit.button(modeRow, L.LabelOnSurface, function()
				set({ "mode" }, "surface")
				editor:renderPanel()
			end, { Size = UDim2.new(0.5, -3, 1, 0), TextSize = 13 })
			local above = Kit.button(modeRow, L.LabelAbove, function()
				set({ "mode" }, "billboard")
				editor:renderPanel()
			end, { Size = UDim2.new(0.5, -3, 1, 0), Position = UDim2.new(0.5, 3, 0, 0), TextSize = 13 })
			Kit.setActive(surf, label.mode == "surface")
			Kit.setActive(above, label.mode == "billboard")
			if label.mode == "surface" then
				local _, slot = Kit.row(list, L.Position, base + 4)
				Kit.button(slot, label.face or "Front", function()
					local opts = {}
					for _, f in FACES do
						table.insert(opts, { id = f, title = f })
					end
					Kit.choose(editor.gui, L.Position, opts, function(f)
						set({ "face" }, f)
						editor:renderPanel()
					end)
				end)
			end
			Kit.stepper(list, L.TextSize, label.size, 2, 6, 80, function(v)
				set({ "size" }, v)
			end, base + 5)
			Kit.toggle(list, L.Wrap, label.wrap, function(v)
				set({ "wrap" }, v)
			end, base + 6)
			local grid = Kit.frame(list, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = base + 7 })
			local g = Instance.new("UIGridLayout")
			g.CellSize = UDim2.fromOffset(40, 40)
			g.CellPadding = UDim2.fromOffset(6, 6)
			g.Parent = grid
			for _, c in Catalog.PALETTE do
				Kit.button(grid, "", function()
					set({ "color" }, c)
				end, { BackgroundColor3 = Color3.fromRGB(c[1], c[2], c[3]) })
			end
			Kit.button(grid, L.AnyColor, function()
				Kit.colorPicker(editor.gui, label.color, function(c)
					set({ "color" }, c)
					editor:renderPanel()
				end)
			end, { TextSize = 20 })
			Kit.button(list, L.RemoveLabel, function()
				editor.state:apply({ op = "set", id = obj.id, path = { "label" }, value = nil })
				editor:renderPanel()
			end, { LayoutOrder = base + 8, BackgroundColor3 = Kit.C.bad })
			previewText, previewSize, previewWrap = label.text, label.size, label.wrap
		end
		if obj.role and obj.role.type == "npc" and obj.role.lines[1] then
			-- самая длинная реплика — худший случай для маленького экрана
			local longest = obj.role.lines[1].text
			for _, line in obj.role.lines do
				if #line.text > #longest then
					longest = line.text
				end
			end
			previewText, previewSize, previewWrap = longest, obj.role.textSize, true
		end
	end

	if previewText then
		Kit.label(list, L.PhonePreview, { Font = Kit.FONT_BOLD, LayoutOrder = base + 20, Size = UDim2.new(1, 0, 0, 44) })
		local holder = Kit.frame(list, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 200), LayoutOrder = base + 21 })
		local screen = Kit.frame(holder, { BackgroundColor3 = Color3.fromRGB(60, 70, 90), Size = UDim2.fromOffset(PHONE.X, PHONE.Y) })
		Kit.corner(screen, 18)
		local scale = Instance.new("UIScale")
		scale.Parent = screen
		local function fit()
			local w = math.max(holder.AbsoluteSize.X, 100)
			scale.Scale = w / PHONE.X
			holder.Size = UDim2.new(1, 0, 0, PHONE.Y * scale.Scale)
		end
		holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		task.defer(fit)
		local b = Bubble.make(screen, previewText, Bubble.textSize(previewSize, PHONE), Bubble.maxWidth(PHONE), previewWrap)
		b.Position = UDim2.new(0.5, -b.Size.X.Offset / 2, 0.4, -b.Size.Y.Offset)
		if b.Size.Y.Offset > PHONE.Y * 0.5 then
			b.BackgroundColor3 = Color3.fromRGB(255, 230, 200)
		end
		local _ = Util
	end
	return nil
end

return TextsPanel
