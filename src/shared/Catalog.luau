--!nonstrict
-- Справочники редактора: фигуры, материалы, текстуры, палитра
-- Текстуры можно выбирать только из этого списка; сервер проверяет ID

local Catalog = {}

Catalog.SHAPES = {
	{ id = "Block", title = "Блок" },
	{ id = "Ball", title = "Сфера" },
	{ id = "Cylinder", title = "Цилиндр" },
	{ id = "Wedge", title = "Клин" },
	{ id = "CornerWedge", title = "Угловой клин" },
	{ id = "Ellipsoid", title = "Эллипсоид" },
}

Catalog.MATERIAL_TITLES = {
	Plastic = "Пластик",
	SmoothPlastic = "Гладкий пластик",
	Wood = "Дерево",
	WoodPlanks = "Доски",
	Brick = "Кирпич",
	Concrete = "Бетон",
	Marble = "Мрамор",
	Granite = "Гранит",
	Slate = "Сланец",
	Metal = "Металл",
	DiamondPlate = "Рифлёный металл",
	CorrodedMetal = "Ржавчина",
	Fabric = "Ткань",
	Grass = "Трава",
	Sand = "Песок",
	Glass = "Стекло",
	Neon = "Неон",
	Ice = "Лёд",
	Cobblestone = "Брусчатка",
	Pebble = "Галька",
}

-- image — изображение для Texture на всех гранях детали
-- Свои текстуры: загрузите изображение в Roblox и добавьте строку с rbxassetid://ID
Catalog.TEXTURES = {
	{ id = "spawn", title = "Плитка старта", image = "rbxasset://textures/SpawnLocation.png", tile = 4 },
	{ id = "face", title = "Лицо", image = "rbxasset://textures/face.png", tile = 0 },
}

Catalog.TEXTURE_SET = {}
for _, t in Catalog.TEXTURES do
	Catalog.TEXTURE_SET[t.id] = t
end

Catalog.PALETTE = {
	{ 245, 245, 245 }, { 163, 162, 165 }, { 99, 95, 98 }, { 27, 42, 53 }, { 17, 17, 17 },
	{ 196, 40, 28 }, { 218, 133, 65 }, { 245, 205, 48 }, { 75, 151, 75 }, { 13, 105, 172 },
	{ 107, 50, 124 }, { 255, 152, 220 }, { 124, 92, 70 }, { 86, 66, 54 }, { 204, 142, 105 },
	{ 234, 184, 146 }, { 255, 201, 201 }, { 175, 221, 255 }, { 0, 255, 255 }, { 255, 176, 0 },
}

-- Готовые модели в каталоге (строятся в Prefabs)
Catalog.PREFABS = {
	{ id = "room", title = "Комната", group = "Строения" },
	{ id = "corridor", title = "Коридор", group = "Строения" },
	{ id = "floorAbove", title = "Этаж выше", group = "Строения" },
	{ id = "stairs", title = "Лестница", group = "Строения" },
	{ id = "wall", title = "Стена", group = "Строения" },
	{ id = "door", title = "Дверь", group = "Интерактивное" },
	{ id = "closet", title = "Шкаф", group = "Интерактивное" },
	{ id = "lamp", title = "Лампа", group = "Интерактивное" },
	{ id = "bookshelf", title = "Книжный шкаф", group = "Мебель" },
	{ id = "table", title = "Стол", group = "Мебель" },
	{ id = "chair", title = "Стул", group = "Мебель" },
	{ id = "bed", title = "Кровать", group = "Мебель" },
	{ id = "sign", title = "Табличка", group = "Надписи" },
	{ id = "spawn", title = "Старт игрока", group = "Точки" },
	{ id = "zone", title = "Зона срабатывания", group = "Точки" },
	{ id = "waypoint", title = "Точка назначения", group = "Точки" },
	{ id = "npcNew", title = "NPC «Новый»", group = "Персонажи" },
	{ id = "npcRetro", title = "NPC «Ретро»", group = "Персонажи" },
	{ id = "fox", title = "Лисик", group = "Персонажи" },
	{ id = "officeInspector", title = "Билетёрша", group = "Джентльмен и Билетёрша" },
	{ id = "officeCoin", title = "Монета-джентльмен", group = "Джентльмен и Билетёрша" },
	{ id = "officeCoinMoustache", title = "Монета-джентльмен с усами", group = "Джентльмен и Билетёрша" },
}

return Catalog
