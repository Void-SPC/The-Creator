--!nonstrict
-- Вкладка «Объекты»: список всего, что есть на карте (как Explorer в Studio)
-- Касание строки выбирает объект и показывает его камерой

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local UiText = require(Shared.UiText)
local Kit = require(script.Parent.Parent.Parent.UI.Kit)

local L = UiText.L

local ExplorerPanel = {}

local ROLE_ICON = {
	closet = "🚪", door = "🚪", light = "💡", npc = "🙂", creature = "🦊",
	zone = "▢", waypoint = "•", spawn = "⚑",
}

function ExplorerPanel.render(editor, panel: Frame)
	local search = Kit.textbox(panel, editor.explorerQuery or "", L.Search, nil, { Size = UDim2.new(1, 0, 0, Kit.TAP) })
	local count = Kit.label(panel, "", { Position = UDim2.fromOffset(0, Kit.TAP + 4), TextColor3 = Kit.C.dim, TextSize = 13 })
	local list = Kit.scroll(panel, { Position = UDim2.fromOffset(0, Kit.TAP + 30), Size = UDim2.new(1, 0, 1, -Kit.TAP - 30) })
	Kit.list(list, 4)

	local function fill()
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local q = string.lower(search.Text)
		local rows = {}
		for id, obj in editor.state.project.map.objects do
			local hay = string.lower(obj.name .. " " .. (obj.latin or ""))
			if q == "" or string.find(hay, q, 1, true) then
				table.insert(rows, { id = id, obj = obj })
			end
		end
		table.sort(rows, function(a, b)
			return a.obj.name < b.obj.name
		end)
		count.Text = string.format(L.ObjectsCount, #rows)
		for i, r in rows do
			local o = r.obj
			local icon = if o.role then ROLE_ICON[o.role.type] or "◆" elseif o.kind == "model" then "▣" else "■"
			local marks = (if o.frozen then "  ❄" else "") .. (if o.hidden then "  ◌" else "")
			local b = Kit.button(list, icon .. "  " .. o.name .. marks .. "\n" .. (o.latin or ""), function()
				editor:select({ r.id })
				editor:focusSelection()
			end, { LayoutOrder = i, Size = UDim2.new(1, -6, 0, Kit.TAP + 4), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 14 })
			Kit.pad(b, 8)
			Kit.setActive(b, table.find(editor.selection, r.id) ~= nil)
		end
	end
	search:GetPropertyChangedSignal("Text"):Connect(function()
		editor.explorerQuery = search.Text
		fill()
	end)
	fill()
	local prev = editor.onProjectChanged
	editor.onProjectChanged = function()
		fill()
		if prev then
			prev()
		end
	end
	return function()
		editor.onProjectChanged = prev
	end
end

return ExplorerPanel
