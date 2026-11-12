--!nonstrict
-- Вкладка «Существа»: человекоподобные NPC «Новый» и «Ретро», лисик и существа с нуля
-- Внешность правится теми же инструментами, что и любая модель

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Workshop"):WaitForChild("Shared")
local UiText = require(Shared.UiText)
local Format = require(Shared.Format)
local Ids = require(Shared.Ids)

local Kit = require(script.Parent.Parent.Parent.UI.Kit)
local MapPanel = require(script.Parent.MapPanel)

local L = UiText.L

local CreaturePanel = {}

function CreaturePanel.render(editor, panel: Frame, bottom: Frame)
	if editor.modelEdit then
		return MapPanel.render(editor, panel, bottom)
	end
	local project = editor.state.project
	local wrap = Kit.frame(panel, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(0.5, -4, 0, 52)
	g.CellPadding = UDim2.fromOffset(6, 6)
	g.Parent = wrap
	Kit.button(wrap, L.BodyNew, function()
		editor:addPrefab("npcNew")
	end)
	Kit.button(wrap, L.BodyRetro, function()
		editor:addPrefab("npcRetro")
	end)
	Kit.button(wrap, L.Fox, function()
		editor:addPrefab("fox")
	end)
	Kit.button(wrap, L.NewCreature, function()
		local m = Format.newModel(Ids.alloc(project, "o"))
		m.name = L.NewCreature
		m.latin = Ids.suggestLatin(project, "Creature")
		m.pos = editor.preview:placementPoint(editor.grid)
		m.model.parts.p1 = {
			id = "p1", name = L.BodyPart, shape = "Block", size = { 2, 2, 3 }, pos = { 0, 1.5, 0 }, rot = { 0, 0, 0 },
			color = { 218, 133, 65 }, material = "Fabric", transparency = 0, pivot = { 0, 0, 0 },
		}
		m.model.nextPart = 2
		m.role = { type = "creature", speed = 12 }
		editor:addObjects({ m })
		editor:enterModelEdit(m.id)
	end)
	local rest = Kit.frame(panel, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 118), Size = UDim2.new(1, 0, 1, -118) })
	return MapPanel.render(editor, rest, bottom)
end

return CreaturePanel
