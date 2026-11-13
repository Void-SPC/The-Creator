--!nonstrict
-- Формат данных проекта мастерской
-- Всё, что делает автор (карта, модели, клипы, роли, логика, камера, тексты), хранится
-- в одной таблице, совместимой с DataStore. У формата есть версия и цепочка миграций

local Util = require(script.Parent.Util)
local Catalog = require(script.Parent.Catalog)

local Format = {}

Format.VERSION = 2

Format.LIMITS = {
	objects = 1500,
	partsPerModel = 120,
	clipsPerModel = 24,
	keysPerTrack = 400,
	markersPerClip = 64,
	nameLen = 60,
	latinLen = 40,
	textLen = 600,
	codeLen = 20000,
	coord = 20000,
	sizeMin = 0.01, -- Roblox допускает от 0.001; у деталей Office встречается 0.03
	sizeMax = 512,
	clipLength = 120,
	dataBytes = 3_500_000,
}

Format.SHAPES = { Block = true, Ball = true, Cylinder = true, Wedge = true, CornerWedge = true, Ellipsoid = true }

Format.MATERIALS = {
	"Plastic", "SmoothPlastic", "Wood", "WoodPlanks", "Brick", "Concrete", "Marble", "Granite",
	"Slate", "Metal", "DiamondPlate", "CorrodedMetal", "Fabric", "Grass", "Sand", "Glass",
	"Neon", "Ice", "Cobblestone", "Pebble",
}
local MATERIAL_SET = {}
for _, m in Format.MATERIALS do
	MATERIAL_SET[m] = true
end
Format.MATERIAL_SET = MATERIAL_SET

Format.ROLES = {
	closet = true, door = true, light = true, npc = true, creature = true,
	zone = true, waypoint = true, spawn = true,
}

local function vec(x: number, y: number, z: number)
	return { x, y, z }
end

function Format.newSettings()
	return {
		camera = {
			mode = "first", -- first | default
			sensitivity = 1,
			fov = 70,
			bob = 0.5, -- 0 отключает покачивание
		},
		hud = { health = false },
		lighting = { ambient = { 40, 40, 48 }, clockTime = 0, brightness = 1 },
	}
end

function Format.newProject(id: string, name: string, ownerId: number)
	return {
		format = Format.VERSION,
		id = id,
		ownerId = ownerId,
		nextId = 1,
		meta = {
			name = name,
			createdAt = os.time(),
			publishCode = nil,
			publishedVersion = 0,
		},
		map = { objects = {} },
		logic = {
			mode = "blocks",
			blocks = { handlers = {} },
			text = { source = "", refs = {} },
		},
		settings = Format.newSettings(),
	}
end

function Format.newPart(id: string, shape: string?)
	return {
		id = id,
		kind = "part",
		name = "Деталь",
		latin = nil,
		pos = vec(0, 2, 0),
		rot = vec(0, 0, 0),
		size = vec(4, 4, 4),
		shape = shape or "Block",
		color = { 200, 200, 200 },
		material = "SmoothPlastic",
		texture = nil,
		transparency = 0,
		frozen = false,
		physics = { anchored = true, canCollide = true },
		role = nil,
		label = nil,
	}
end

function Format.newModel(id: string)
	return {
		id = id,
		kind = "model",
		name = "Модель",
		latin = nil,
		pos = vec(0, 0, 0),
		rot = vec(0, 0, 0),
		frozen = false,
		physics = { anchored = true, canCollide = true },
		model = {
			parts = {}, -- [partId] = деталь с pos/rot относительно начала модели, parent, pivot
			clips = {}, -- [clipId] = клип
			nextPart = 1,
			body = nil, -- "new" | "retro" для человекоподобных NPC
		},
		role = nil,
		label = nil,
	}
end

function Format.newClip(id: string, name: string)
	return { id = id, name = name, length = 2, loop = false, tracks = {}, markers = {} }
end

-- ---------------------------------------------------------------------------
-- Миграции: каждая функция поднимает данные на одну версию

local MIGRATIONS = {}

-- v1 (ранний прототип): объекты массивом в project.objects, камера в settings.fov/sensitivity,
-- у логики был только блочный режим в project.script
MIGRATIONS[1] = function(p)
	local objects = {}
	for _, obj in p.objects or {} do
		if type(obj) == "table" and type(obj.id) == "string" then
			objects[obj.id] = obj
		end
	end
	p.objects = nil
	p.map = { objects = objects }
	local s = p.settings or {}
	local settings = Format.newSettings()
	settings.camera.fov = s.fov or settings.camera.fov
	settings.camera.sensitivity = s.sensitivity or settings.camera.sensitivity
	p.settings = settings
	p.logic = {
		mode = "blocks",
		blocks = p.script or { handlers = {} },
		text = { source = "", refs = {} },
	}
	p.script = nil
	p.meta = p.meta or { name = p.name or "Карта", createdAt = os.time(), publishedVersion = 0 }
	p.name = nil
	p.format = 2
	return p
end

function Format.migrate(data: any): (boolean, any)
	if type(data) ~= "table" then
		return false, "not a table"
	end
	local v = data.format
	if type(v) ~= "number" then
		return false, "no format version"
	end
	if v > Format.VERSION then
		return false, "format from the future: " .. tostring(v)
	end
	while v < Format.VERSION do
		local step = MIGRATIONS[v]
		if not step then
			return false, "no migration from " .. tostring(v)
		end
		local ok, res = pcall(step, data)
		if not ok then
			return false, "migration " .. tostring(v) .. " failed: " .. tostring(res)
		end
		data = res
		v = data.format
	end
	return true, data
end

-- ---------------------------------------------------------------------------
-- Проверка данных. Используется сервером на каждой правке и перед сохранением

local L = Format.LIMITS

local function isNum(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function checkVec(v, lo, hi, what)
	if type(v) ~= "table" or #v ~= 3 then
		return what .. ": vector expected"
	end
	for i = 1, 3 do
		if not isNum(v[i]) or v[i] < lo or v[i] > hi then
			return what .. ": bad component"
		end
	end
	return nil
end

local function checkStr(v, maxLen, what, optional)
	if v == nil and optional then
		return nil
	end
	if type(v) ~= "string" then
		return what .. ": string expected"
	end
	if utf8.len(v) == nil then
		return what .. ": bad utf8"
	end
	if #v > maxLen * 4 or (utf8.len(v) :: number) > maxLen then
		return what .. ": too long"
	end
	return nil
end

local function checkColor(c, what)
	if type(c) ~= "table" or #c ~= 3 then
		return what .. ": color expected"
	end
	for i = 1, 3 do
		if not isNum(c[i]) or c[i] < 0 or c[i] > 255 then
			return what .. ": bad color"
		end
	end
	return nil
end

local function checkRef(r, what, optional)
	if r == nil and optional then
		return nil
	end
	if type(r) ~= "table" or type(r.ref) ~= "string" or #r.ref > 32 then
		return what .. ": reference expected"
	end
	return nil
end

local function checkPose(pose, what)
	if type(pose) ~= "table" then
		return what .. ": pose expected"
	end
	return checkVec(pose.pos, -200, 200, what .. ".pos") or checkVec(pose.rot, -720, 720, what .. ".rot")
end

function Format.validateClip(clip): string?
	if type(clip) ~= "table" then
		return "clip: table expected"
	end
	local e = checkStr(clip.id, 32, "clip.id") or checkStr(clip.name, L.nameLen, "clip.name")
	if e then
		return e
	end
	if not isNum(clip.length) or clip.length <= 0 or clip.length > L.clipLength then
		return "clip.length"
	end
	if type(clip.loop) ~= "boolean" then
		return "clip.loop"
	end
	if type(clip.tracks) ~= "table" or type(clip.markers) ~= "table" then
		return "clip.tracks"
	end
	for trackId, track in clip.tracks do
		if type(trackId) ~= "string" or type(track) ~= "table" or type(track.keys) ~= "table" then
			return "clip.track"
		end
		if #track.keys > L.keysPerTrack then
			return "clip.track: too many keys"
		end
		for _, k in track.keys do
			if type(k) ~= "table" or not isNum(k.t) or k.t < 0 or k.t > clip.length + 1e-6 then
				return "clip.key.t"
			end
			local ke = checkVec(k.pos, -L.coord, L.coord, "key.pos") or checkVec(k.rot, -720, 720, "key.rot")
			if ke then
				return ke
			end
			if k.ease ~= nil and k.ease ~= "linear" and k.ease ~= "smooth" and k.ease ~= "step" then
				return "clip.key.ease"
			end
		end
	end
	if #clip.markers > L.markersPerClip then
		return "clip: too many markers"
	end
	for _, m in clip.markers do
		if type(m) ~= "table" or not isNum(m.t) or m.t < 0 or m.t > clip.length + 1e-6 then
			return "clip.marker"
		end
		local me = checkStr(m.name, L.nameLen, "marker.name")
		if me then
			return me
		end
	end
	return nil
end

local function validateRole(role): string?
	if role == nil then
		return nil
	end
	if type(role) ~= "table" or not Format.ROLES[role.type] then
		return "role.type"
	end
	local t = role.type
	if t == "closet" then
		local e = checkPose(role.entry, "closet.entry")
			or checkPose(role.inside, "closet.inside")
			or checkPose(role.exit, "closet.exit")
			or Format.validateClip(role.enterClip)
			or Format.validateClip(role.exitClip)
		if e then
			return e
		end
	elseif t == "door" then
		if type(role.open) ~= "boolean" then
			return "door.open"
		end
		if not isNum(role.openAngle) or math.abs(role.openAngle) > 180 then
			return "door.openAngle"
		end
		if not isNum(role.openTime) or role.openTime < 0 or role.openTime > 10 then
			return "door.openTime"
		end
		local e = checkVec(role.hinge, -200, 200, "door.hinge")
		if e then
			return e
		end
	elseif t == "light" then
		if type(role.on) ~= "boolean" then
			return "light.on"
		end
		if not isNum(role.brightness) or role.brightness < 0 or role.brightness > 40 then
			return "light.brightness"
		end
		if not isNum(role.range) or role.range < 0 or role.range > 60 then
			return "light.range"
		end
		local e = checkColor(role.color, "light.color")
		if e then
			return e
		end
	elseif t == "npc" then
		if type(role.lines) ~= "table" or #role.lines > 40 then
			return "npc.lines"
		end
		for _, line in role.lines do
			local e = checkStr(line.text, L.textLen, "npc.line")
			if e then
				return e
			end
			if not isNum(line.delay) or line.delay < 0 or line.delay > 120 then
				return "npc.line.delay"
			end
			if not isNum(line.duration) or line.duration < 0.5 or line.duration > 60 then
				return "npc.line.duration"
			end
		end
		if role.trigger ~= "roomEnter" and role.trigger ~= "interact" and role.trigger ~= "logic" then
			return "npc.trigger"
		end
		local e = checkRef(role.zone, "npc.zone", true)
			or checkStr(role.greetingClip, 60, "npc.greetingClip", true)
			or checkRef(role.anchor, "npc.anchor", true)
		if e then
			return e
		end
		if not isNum(role.textSize) or role.textSize < 8 or role.textSize > 60 then
			return "npc.textSize"
		end
	elseif t == "creature" then
		if not isNum(role.speed) or role.speed <= 0 or role.speed > 100 then
			return "creature.speed"
		end
		local e = checkStr(role.idleClip, 60, "creature.idleClip", true)
		if e then
			return e
		end
	elseif t == "waypoint" then
		-- маршрут: точка может ссылаться на следующую
		local e = checkRef(role.next, "waypoint.next", true)
		if e then
			return e
		end
	end
	return nil
end

local function validateLabel(label): string?
	if label == nil then
		return nil
	end
	if type(label) ~= "table" then
		return "label"
	end
	local e = checkStr(label.text, L.textLen, "label.text")
	if e then
		return e
	end
	if label.mode ~= "surface" and label.mode ~= "billboard" then
		return "label.mode"
	end
	if not isNum(label.size) or label.size < 6 or label.size > 80 then
		return "label.size"
	end
	if type(label.wrap) ~= "boolean" then
		return "label.wrap"
	end
	return checkColor(label.color, "label.color")
end

local function validatePartFields(p, what): string?
	if not Format.SHAPES[p.shape] then
		return what .. ".shape"
	end
	local e = checkVec(p.size, L.sizeMin, L.sizeMax, what .. ".size") or checkColor(p.color, what .. ".color")
	if e then
		return e
	end
	if not MATERIAL_SET[p.material] then
		return what .. ".material"
	end
	if p.texture ~= nil and (type(p.texture) ~= "string" or Catalog.TEXTURE_SET[p.texture] == nil) then
		return what .. ".texture"
	end
	if not isNum(p.transparency) or p.transparency < 0 or p.transparency > 1 then
		return what .. ".transparency"
	end
	return nil
end

function Format.validateObject(obj): string?
	if type(obj) ~= "table" then
		return "object: table expected"
	end
	local e = checkStr(obj.id, 32, "id")
		or checkStr(obj.name, L.nameLen, "name")
		or checkStr(obj.latin, L.latinLen, "latin", true)
		or checkVec(obj.pos, -L.coord, L.coord, "pos")
		or checkVec(obj.rot, -720, 720, "rot")
	if e then
		return e
	end
	if obj.latin ~= nil and not string.match(obj.latin, "^[A-Za-z][A-Za-z0-9_]*$") then
		return "latin: only A-Z, 0-9 and _"
	end
	if type(obj.frozen) ~= "boolean" then
		return "frozen"
	end
	if obj.hidden ~= nil and type(obj.hidden) ~= "boolean" then
		return "hidden"
	end
	if type(obj.physics) ~= "table" or type(obj.physics.anchored) ~= "boolean" or type(obj.physics.canCollide) ~= "boolean" then
		return "physics"
	end
	if obj.kind == "part" then
		e = validatePartFields(obj, "part")
		if e then
			return e
		end
	elseif obj.kind == "model" then
		local m = obj.model
		if type(m) ~= "table" or type(m.parts) ~= "table" or type(m.clips) ~= "table" then
			return "model"
		end
		local n = 0
		for pid, part in m.parts do
			n += 1
			if type(pid) ~= "string" or type(part) ~= "table" or part.id ~= pid then
				return "model.part.id"
			end
			e = validatePartFields(part, "model.part")
				or checkStr(part.name, L.nameLen, "model.part.name")
				or checkVec(part.pos, -L.coord, L.coord, "model.part.pos")
				or checkVec(part.rot, -720, 720, "model.part.rot")
				or checkVec(part.pivot, -L.sizeMax, L.sizeMax, "model.part.pivot")
			if e then
				return e
			end
			if part.parent ~= nil and (type(part.parent) ~= "string" or m.parts[part.parent] == nil) then
				return "model.part.parent"
			end
		end
		if n > L.partsPerModel then
			return "model: too many parts"
		end
		-- запрет циклов в иерархии суставов
		for pid in m.parts do
			local seen = {}
			local cur = pid
			while cur do
				if seen[cur] then
					return "model: joint cycle"
				end
				seen[cur] = true
				cur = m.parts[cur] and m.parts[cur].parent
			end
		end
		local nc = 0
		for cid, clip in m.clips do
			nc += 1
			if clip.id ~= cid then
				return "model.clip.id"
			end
			e = Format.validateClip(clip)
			if e then
				return e
			end
		end
		if nc > L.clipsPerModel then
			return "model: too many clips"
		end
		if m.body ~= nil and m.body ~= "new" and m.body ~= "retro" then
			return "model.body"
		end
	else
		return "kind"
	end
	return validateRole(obj.role) or validateLabel(obj.label)
end

function Format.validateSettings(s): string?
	if type(s) ~= "table" or type(s.camera) ~= "table" or type(s.hud) ~= "table" then
		return "settings"
	end
	local c = s.camera
	if c.mode ~= "first" and c.mode ~= "default" then
		return "camera.mode"
	end
	if not isNum(c.sensitivity) or c.sensitivity < 0.05 or c.sensitivity > 5 then
		return "camera.sensitivity"
	end
	if not isNum(c.fov) or c.fov < 40 or c.fov > 110 then
		return "camera.fov"
	end
	if not isNum(c.bob) or c.bob < 0 or c.bob > 2 then
		return "camera.bob"
	end
	if type(s.hud.health) ~= "boolean" then
		return "hud.health"
	end
	return nil
end

function Format.validateProject(p): string?
	if type(p) ~= "table" or p.format ~= Format.VERSION then
		return "format"
	end
	if type(p.map) ~= "table" or type(p.map.objects) ~= "table" then
		return "map"
	end
	if type(p.meta) ~= "table" then
		return "meta"
	end
	local e = checkStr(p.meta.name, L.nameLen, "meta.name")
	if e then
		return e
	end
	local n = 0
	for id, obj in p.map.objects do
		n += 1
		if obj.id ~= id then
			return "object id mismatch"
		end
		e = Format.validateObject(obj)
		if e then
			return id .. ": " .. e
		end
	end
	if n > L.objects then
		return "too many objects"
	end
	if type(p.logic) ~= "table" or type(p.logic.text) ~= "table" then
		return "logic"
	end
	if type(p.logic.text.source) ~= "string" or #p.logic.text.source > L.codeLen then
		return "logic.text"
	end
	e = Format.validateSettings(p.settings)
	if e then
		return e
	end
	if Util.approxSize(p) > L.dataBytes then
		return "project too large"
	end
	return nil
end

return Format
