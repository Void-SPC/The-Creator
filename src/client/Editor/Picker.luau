--!nonstrict
-- Выбор цели: касанием на карте или из списка. Показывает понятное название и
-- латинское имя; внутри хранится постоянный ID

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local UiText = require(Shared.UiText)
local Commands = require(Shared.Logic.Commands)
local Kit = require(script.Parent.Parent.UI.Kit)

local L, H = UiText.L, UiText.H

local Picker = {}

function Picker.display(project, id: string?): (string, boolean)
	if not id or id == "" then
		return L.NeedsRebind, false
	end
	local obj = project.map.objects[id]
	if not obj then
		return L.NeedsRebind, false
	end
	if obj.latin then
		return string.format(L.ObjectNameFormat, obj.name, obj.latin), true
	end
	return obj.name, true
end

local function accepts(argType: string?, obj): boolean
	if not argType then
		return true
	end
	local check = Commands.TARGET_TYPES[argType]
	return check == nil or check(obj)
end

function Picker.pick(editor, argType: string?, onPick: (string) -> ())
	Kit.choose(editor.gui, L.PickOnMap, {
		{ id = "map", title = L.PickOnMap },
		{ id = "list", title = L.PickFromList },
	}, function(how)
		if how == "map" then
			editor:pickTarget(function(id)
				local obj = editor.state:obj(id)
				if obj and accepts(argType, obj) then
					onPick(id)
				else
					Kit.toast(editor.gui, H.WrongTargetHint, Kit.C.bad)
				end
			end)
		else
			local options = {}
			for id, obj in editor.state.project.map.objects do
				if accepts(argType, obj) then
					table.insert(options, { id = id, title = obj.name, hint = obj.latin })
				end
			end
			table.sort(options, function(a, b)
				return a.title < b.title
			end)
			Kit.choose(editor.gui, L.PickFromList, options, onPick)
		end
	end)
end

-- Кнопка-поле со ссылкой на объект. Удалённая цель подсвечивается красным
function Picker.field(editor, parent: Instance, title: string, argType: string?, currentId: string?, onPick: (string?) -> (), order: number?, optional: boolean?)
	local _, slot = Kit.row(parent, title, order)
	local text, ok = Picker.display(editor.state.project, currentId)
	if optional and (currentId == nil or currentId == "") then
		text, ok = L.None, true
	end
	local b = Kit.button(slot, text, function()
		Picker.pick(editor, argType, function(id)
			onPick(id)
		end)
	end, { TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left })
	Kit.pad(b, 6)
	if not ok then
		b.BackgroundColor3 = Kit.C.bad
	end
	slot.Parent.Size = UDim2.new(1, 0, 0, 52)
	return b
end

return Picker
