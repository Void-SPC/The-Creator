--!nonstrict
-- Все встроенные строки интерфейса мастерской
--
-- Правило оформления:
--  * L — короткие подписи: кнопки, вкладки, заголовки, статусы. Без конечной точки
--    и без точки-разделителя внутри. Заголовок и уточнение разделяются переносом строки
--  * H — подсказки из полных предложений. Точка завершает предложение, но не отделяет
--    заголовок от уточнения
--  * Числа с дробной частью, версии и синтаксис кода сохраняют свои точки
-- Авторские названия и реплики сюда не входят: они хранятся как ввёл автор и проходят
-- фильтрацию Roblox

local UiText = {}

UiText.L = {
	AppTitle = "Мастерская",
	AppSubtitle = "Карты, модели и существа",
	MyMaps = "Мои карты",
	NewMap = "Новая карта",
	NewDemo = "Демосцена",
	Catalog = "Каталог карт",
	EnterCode = "Ввести код",
	Play = "Играть",
	Open = "Открыть",
	Back = "Назад",
	Close = "Закрыть",
	Cancel = "Отмена",
	Apply = "Применить",
	Delete = "Удалить",
	Rename = "Переименовать",
	Loading = "Загрузка…",
	LoadFailed = "Не удалось загрузить",
	NothingHere = "Здесь пока пусто",
	CodePlaceholder = "Код карты",
	MapNamePlaceholder = "Название карты",

	TabMap = "Карта",
	TabModels = "Модели",
	TabCreatures = "Существа",
	TabAnimation = "Анимация",
	TabLogic = "Логика",
	TabCamera = "Камера",
	TabTexts = "Тексты",

	ToolSelect = "Выбор",
	ToolMove = "Двигать",
	ToolRotate = "Вращать",
	ToolScale = "Размер",
	Grid = "Сетка",
	GridOff = "Без сетки",
	Undo = "Отменить",
	Redo = "Повторить",
	Freeze = "Заморозить",
	Unfreeze = "Разморозить",
	Glue = "Склеить",
	Unglue = "Разобрать",
	EditModel = "Править модель",
	DoneEditing = "Готово",
	Duplicate = "Копия",
	SaveToMyModels = "В «Мои модели»",
	MyModels = "Мои модели",
	AddShape = "Фигура",
	AddPrefab = "Каталог",
	AssignAs = "Назначить",
	ClearRole = "Снять назначение",
	Properties = "Свойства",
	Name = "Название",
	LatinName = "Латинское имя",
	Size = "Размер",
	Rotation = "Поворот",
	Position = "Позиция",
	Color = "Цвет",
	Material = "Материал",
	Texture = "Текстура",
	NoTexture = "Без текстуры",
	Transparency = "Прозрачность",
	Anchored = "Закреплён в игре",
	CanCollide = "Твёрдый",
	HiddenAtStart = "Скрыт в начале",
	Shapes = "Фигуры",
	MultiSelect = "Несколько",
	DefaultModelName = "Модель",
	Nudge = "Точный сдвиг",
	NoRole = "Без назначения",
	None = "Нет",
	Yes = "Да",
	No = "Нет",
	ObjectNameFormat = "%s\n%s",
	PartsOfModel = "Детали модели",
	Joints = "Суставы",
	OpenOnStart = "Открыта в начале",
	Locked = "Заперта",
	HingeOffset = "Петли, смещение",
	Fox = "Лисик",
	BodyPart = "Тело",
	DemoMapName = "Шум за дверью",
	SessionTest = "Тест черновика",
	PlayersCount = "Игроков: %d",

	AssignCloset = "Назначить как шкаф",
	AssignDoor = "Назначить как дверь",
	AssignLight = "Назначить как лампу",
	AssignNpc = "Назначить как NPC",
	AssignCreature = "Назначить как существо",
	AssignZone = "Назначить как зону",
	AssignWaypoint = "Назначить как точку назначения",
	AssignSpawn = "Назначить как старт игрока",

	RoleCloset = "Шкаф",
	RoleDoor = "Дверь",
	RoleLight = "Лампа",
	RoleNpc = "NPC",
	RoleCreature = "Существо",
	RoleZone = "Зона срабатывания",
	RoleWaypoint = "Точка назначения",
	RoleSpawn = "Старт игрока",

	ClosetEntry = "Точка входа",
	ClosetInside = "Позиция внутри",
	ClosetExit = "Точка выхода",
	EditEnterClip = "Клип входа\nEnterCloset",
	EditExitClip = "Клип выхода\nExitCloset",
	ResetClosetClips = "Собрать клипы по точкам",
	Hide = "Спрятаться",
	LeaveCloset = "Выйти",

	DoorAngle = "Угол открытия",
	DoorTime = "Время открытия",
	DoorOpen = "Открыть",
	DoorClose = "Закрыть",
	LightOn = "Включена",
	Brightness = "Яркость",
	Range = "Дальность",
	Speed = "Скорость",
	NextPoint = "Следующая точка",
	NpcTrigger = "Когда приветствовать",
	TriggerRoomEnter = "При входе в комнату",
	TriggerInteract = "После взаимодействия",
	TriggerLogic = "Только из логики",
	GreetingClip = "Клип приветствия",
	Lines = "Реплики",
	AddLine = "Добавить реплику",
	LineDelay = "Пауза, с",
	LineDuration = "Показ, с",
	TextAnchor = "Где показывать",
	AnchorSelf = "Над NPC",
	TextSize = "Размер текста",
	Talk = "Поговорить",
	Interact = "Взаимодействовать",

	LabelText = "Надпись",
	LabelOnSurface = "На поверхности",
	LabelAbove = "Над объектом",
	Wrap = "Перенос строк",
	PhonePreview = "Предпросмотр\nна телефоне",
	AddLabel = "Добавить надпись",
	RemoveLabel = "Убрать надпись",

	BodyNew = "Новый",
	BodyRetro = "Ретро",
	NewCreature = "Новое существо",
	JointParent = "Родитель",
	NoParent = "Без родителя",
	Pivot = "Точка вращения",
	SetPivotHere = "Точка вращения здесь",

	Clips = "Клипы",
	NewClip = "Новый клип",
	ClipName = "Имя клипа",
	ClipLength = "Длина, с",
	ModeOnce = "Один раз",
	ModeLoop = "Повтор",
	KeyAdd = "Ключ",
	KeyDelete = "Удалить ключ",
	KeyCopy = "Копировать",
	KeyPaste = "Вставить",
	KeyMoveLeft = "Ключ влево",
	KeyMoveRight = "Ключ вправо",
	Preview = "Предпросмотр",
	Stop = "Стоп",
	Marker = "Метка",
	AddMarker = "Добавить метку",
	MissingPart = "Нет детали",
	PickPart = "Выберите деталь",

	LogicBlocks = "Блоки",
	LogicText = "Текст",
	AddEvent = "Событие",
	AddAction = "Действие",
	AddCondition = "Условие",
	AddIf = "Если",
	AddElse = "Иначе",
	AddRepeat = "Повторить",
	Check = "Проверить",
	PickOnMap = "Выбрать на карте",
	PickFromList = "Выбрать из списка",
	NeedsRebind = "Нужна новая привязка",
	NoErrors = "Ошибок нет",
	ErrorAtLine = "Строка %d\n%s",
	ErrorInBlock = "Ошибка в блоке\n%s",

	CameraFirst = "Камера от первого лица",
	CameraDefault = "Обычная камера",
	Sensitivity = "Чувствительность",
	Fov = "Поле зрения",
	Bob = "Покачивание",
	HealthBar = "Полоска здоровья",

	Test = "Тестировать",
	StopTest = "Вернуться в редактор",
	Publish = "Опубликовать",
	PublishedAs = "Код карты\n%s",
	PublishedVersion = "Версия %d",

	SaveSaved = "Сохранено",
	SaveDirty = "Есть изменения",
	SaveSaving = "Сохранение…",
	SaveFailed = "Не сохранено",
	SaveReadOnly = "Только просмотр",
	SaveOffline = "Нет связи",

	Admin = "Админ",
	AdminTitle = "Панель администратора",
	AdminEndSession = "Завершить сессию",
	AdminUnlist = "Снять с публикации",
	AdminKick = "Удалить из сессии",
}

UiText.H = {
	EmptyMaps = "У вас пока нет карт. Создайте новую или откройте демосцену.",
	CodeHint = "Введите шесть символов кода, который дал автор.",
	SelectHint = "Коснитесь объекта, чтобы выбрать его.",
	FrozenHint = "Объект заморожен в редакторе. Размер по-прежнему можно менять.",
	GlueHint = "Выберите несколько деталей и нажмите «Склеить».",
	PickTargetHint = "Коснитесь нужного объекта на карте.",
	ClosetHint = "Точки входа, внутри и выхода двигаются вместе со шкафом.",
	MissingTrackHint = "Деталь удалена из модели. Ключи дорожки сохранены, назначьте её другой детали или верните деталь.",
	BrokenBindingHint = "Цель удалена. Выберите новую цель на карте или из списка.",
	ReadOnlyHint = "Карта открыта на другом сервере. Изменения сохранятся, когда она освободится.",
	LoadFailedHint = "Карту не удалось загрузить. Сохранённая версия не изменена, попробуйте позже.",
	SaveFailedHint = "Последние изменения ещё не записаны. Мастерская попробует снова.",
	PublishHint = "Опубликованная версия не меняется, пока вы не опубликуете карту снова.",
	PublishFailedHint = "Карту не удалось опубликовать. Проверьте ошибки в логике и тексты.",
	FilterFailedHint = "Текст не прошёл проверку Roblox. Измените его и попробуйте снова.",
	NotFoundHint = "Карта с таким кодом не найдена.",
	LogicErrorHint = "Сценарий остановлен из-за ошибки. Исправьте отмеченный блок или строку.",
	BobHint = "Ноль полностью отключает покачивание.",
	TouchHint = "Одним пальцем вращайте камеру, двумя двигайте и приближайте.",
	ModelEditHint = "Вы правите детали модели. Нажмите «Готово», чтобы вернуться к карте.",
	GlueRoleHint = "Сначала снимите назначение с выбранных объектов.",
	LatinHint = "Латинское имя может содержать только латинские буквы, цифры и подчёркивание.",
	LatinTakenHint = "Такое латинское имя уже занято или совпадает с командой.",
	WrongTargetHint = "Этот объект не подходит для выбранного поля.",
	SavedToLibraryHint = "Модель сохранена в «Мои модели».",
	ClipsNeedModelHint = "Выберите модель на карте, чтобы работать с её клипами.",
}

-- Проверка правила точек. Возвращает список нарушений
function UiText.lint()
	local problems = {}
	for key, text in UiText.L do
		-- маскируем десятичные числа и версии
		local masked = string.gsub(text, "%d+%.%d+", "0")
		if string.find(masked, "%.$") or string.find(masked, "%.%s*\n") then
			table.insert(problems, "L." .. key .. ": конечная точка в короткой подписи")
		end
		if string.find(masked, "%.%s+%S") then
			table.insert(problems, "L." .. key .. ": точка-разделитель внутри подписи")
		end
	end
	for key, text in UiText.H do
		local masked = string.gsub(text, "%d+%.%d+", "0")
		-- каждое предложение начинается с заглавной буквы и содержит хотя бы два слова (подлежащее и сказуемое)
		for sentence in string.gmatch(masked .. " ", "(.-[%.!?])%s") do
			local words = 0
			for _ in string.gmatch(sentence, "%S+") do
				words += 1
			end
			if words < 2 then
				table.insert(problems, "H." .. key .. ": обрывок вместо предложения «" .. sentence .. "»")
			end
		end
		local cp = utf8.codepoint(masked, 1)
		local isLower = (cp >= 0x61 and cp <= 0x7A) or (cp >= 0x430 and cp <= 0x44F) or cp == 0x451
		if isLower then
			table.insert(problems, "H." .. key .. ": предложение со строчной буквы")
		end
		if not string.find(masked, "[%.!?]$") then
			table.insert(problems, "H." .. key .. ": подсказка не завершена")
		end
	end
	table.sort(problems)
	return problems
end

function UiText.f(key: string, ...: any): string
	local s = UiText.L[key] or UiText.H[key]
	if not s then
		return key
	end
	if select("#", ...) > 0 then
		return string.format(s, ...)
	end
	return s
end

return UiText
