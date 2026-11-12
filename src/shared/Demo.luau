--!nonstrict
-- Демонстрационная сцена: игрок открывает дверь, лисик выбирается из книжного шкафа
-- и бежит на шум; на метке клипа «Скример» гаснет лампа, затем лисик убегает
-- Любой объект сцены можно заменить в редакторе: логика ссылается на ID, а не на имена

local Format = require(script.Parent.Format)
local Prefabs = require(script.Parent.Prefabs)
local Logic = require(script.Parent.Logic)

local Demo = {}

Demo.SOURCE = [[
-- Демосцена: шум за дверью
on DoorOpened(FrontDoor) do
  SetVisible(Fox, true)
  PlayClip(Fox, "Появление")
  Wait(1.4)
  MoveTo(Fox, NoisePoint, "Бег", 14)
end

on Arrived(Fox, NoisePoint) do
  Say(Fox, "Кто здесь шумит?", 2.5)
  PlayClip(Fox, "Скример")
end

on MarkerReached(Fox, "Скример", "Погасить") do
  SetLight(HallLamp, false)
end

on ClipFinished(Fox, "Скример") do
  MoveTo(Fox, EscapePoint, "Бег", 22)
end

on Arrived(Fox, EscapePoint) do
  SetVisible(Fox, false)
  Wait(3)
  SetLight(HallLamp, true)
end
]]

local function put(project, objs)
	for _, o in objs do
		project.map.objects[o.id] = o
	end
	return objs[1]
end

function Demo.build(projectId: string, ownerId: number)
	local p = Format.newProject(projectId, "Шум за дверью", ownerId)

	put(p, Prefabs.room(p, 28, 24, 10))
	local spawn = put(p, Prefabs.build(p, "spawn", { 0, 0, -30 }))
	spawn.latin = "Start"

	-- коридор перед дверью
	local corridor = Prefabs.build(p, "corridor", { 0, 0, -23.5 }) :: any
	put(p, corridor)

	local door = put(p, Prefabs.build(p, "door", { 0, 0, -11.5 }))
	door.name = "Входная дверь"
	door.latin = "FrontDoor"

	local lamp = put(p, Prefabs.build(p, "lamp", { 0, 0, 0 }))
	lamp.name = "Лампа в холле"
	lamp.latin = "HallLamp"

	local shelf = put(p, Prefabs.build(p, "bookshelf", { 8, 1, 10 }))
	shelf.rot = { 0, 0, 0 }
	shelf.latin = "Bookshelf01"

	-- лисик стоит перед полками; клип «Появление» начинается с позы внутри шкафа
	local fox = put(p, Prefabs.build(p, "fox", { 8, 1, 7 }))
	fox.latin = "Fox"
	fox.rot = { 0, 0, 0 }
	fox.hidden = true

	local noise = put(p, Prefabs.build(p, "waypoint", { -6, 0, -4 }))
	noise.name = "Источник шума"
	noise.latin = "NoisePoint"

	local escape = put(p, Prefabs.build(p, "waypoint", { -10, 0, 9 }))
	escape.name = "Точка побега"
	escape.latin = "EscapePoint"

	local closet = put(p, Prefabs.build(p, "closet", { -11, 1, -6 }))
	closet.rot = { 0, -90, 0 } -- дверцами в комнату
	closet.latin = "Closet01"

	local sign = put(p, Prefabs.build(p, "sign", { 0, 5, -12.15 }))
	sign.label.text = "Не открывай после полуночи"
	sign.latin = "WarningSign"

	local npc = put(p, Prefabs.build(p, "npcNew", { -2.5, 1, -20 }))
	npc.name = "Сторож"
	npc.latin = "Keeper"
	npc.rot = { 0, -90, 0 }
	npc.role.lines = {
		{ text = "Здравствуй! Говорят, в этом доме по ночам кто-то шуршит за книжным шкафом. Если услышишь шум, спрячься в шкаф у стены и не выходи, пока свет снова не загорится.", delay = 0, duration = 7 },
		{ text = "Удачи!", delay = 7.5, duration = 2 },
	}

	p.settings.lighting.clockTime = 0

	local tree, errors = Logic.Parser.parse(Demo.SOURCE, Logic.nameResolver(p))
	assert(tree and not errors, "demo logic must parse")
	p.logic.mode = "blocks"
	p.logic.blocks = tree
	p.logic.text.source = Demo.SOURCE
	p.logic.text.refs = Logic.collectRefs(tree)
	return p
end

-- Вспомогательное для проверки: ID объекта по латинскому имени
function Demo.idOf(project, latin: string): string?
	for id, o in project.map.objects do
		if o.latin == latin then
			return id
		end
	end
	return nil
end

return Demo
