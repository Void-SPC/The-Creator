--!nonstrict
-- Клипы с ключевыми кадрами: правка ключей, интерполяция, метки, проверка дорожек
-- Дорожка клипа привязана к детали модели по её ID. Ключ хранит смещение детали
-- относительно позы покоя: pos (в координатах детали) и rot (градусы, YXZ)

local MathX = require(script.Parent.MathX)

local Anim = {}

Anim.KEY_EPS = 1 / 120
Anim.SPECIAL_TRACKS = { PlayerRoot = true, Camera = true }

local function sortKeys(track)
	table.sort(track.keys, function(a, b)
		return a.t < b.t
	end)
end

local function roundT(t: number): number
	return math.floor(t * 1000 + 0.5) / 1000
end

function Anim.ensureTrack(clip, trackId: string)
	local track = clip.tracks[trackId]
	if not track then
		track = { keys = {} }
		clip.tracks[trackId] = track
	end
	return track
end

function Anim.findKey(clip, trackId: string, t: number)
	local track = clip.tracks[trackId]
	if not track then
		return nil, nil
	end
	for i, k in track.keys do
		if math.abs(k.t - t) <= Anim.KEY_EPS then
			return k, i
		end
	end
	return nil, nil
end

function Anim.setKey(clip, trackId: string, t: number, pos, rot, ease: string?)
	t = roundT(math.clamp(t, 0, clip.length))
	local track = Anim.ensureTrack(clip, trackId)
	local existing = Anim.findKey(clip, trackId, t)
	if existing then
		existing.pos = { pos[1], pos[2], pos[3] }
		existing.rot = { rot[1], rot[2], rot[3] }
		existing.ease = ease or existing.ease or "smooth"
		return existing
	end
	local key = { t = t, pos = { pos[1], pos[2], pos[3] }, rot = { rot[1], rot[2], rot[3] }, ease = ease or "smooth" }
	table.insert(track.keys, key)
	sortKeys(track)
	return key
end

function Anim.removeKey(clip, trackId: string, t: number): boolean
	local _, i = Anim.findKey(clip, trackId, t)
	if not i then
		return false
	end
	table.remove(clip.tracks[trackId].keys, i)
	return true
end

function Anim.copyKey(clip, trackId: string, fromT: number, toT: number): boolean
	local k = Anim.findKey(clip, trackId, fromT)
	if not k then
		return false
	end
	Anim.setKey(clip, trackId, toT, k.pos, k.rot, k.ease)
	return true
end

function Anim.moveKey(clip, trackId: string, fromT: number, toT: number): boolean
	local k, i = Anim.findKey(clip, trackId, fromT)
	if not k or not i then
		return false
	end
	local pos, rot, ease = k.pos, k.rot, k.ease
	table.remove(clip.tracks[trackId].keys, i)
	Anim.setKey(clip, trackId, toT, pos, rot, ease)
	return true
end

-- Копирует все ключи в момент fromT (по всем дорожкам) в момент toT
function Anim.copyFrame(clip, fromT: number, toT: number): number
	local n = 0
	for trackId in clip.tracks do
		if Anim.copyKey(clip, trackId, fromT, toT) then
			n += 1
		end
	end
	return n
end

function Anim.setLength(clip, length: number)
	clip.length = math.clamp(length, 0.1, 120)
	for _, track in clip.tracks do
		for _, k in track.keys do
			if k.t > clip.length then
				k.t = clip.length
			end
		end
		-- после обрезки могли появиться ключи в одной точке: оставляем последний
		local seen = {}
		for i = #track.keys, 1, -1 do
			local tt = roundT(track.keys[i].t)
			if seen[tt] then
				table.remove(track.keys, i)
			else
				seen[tt] = true
			end
		end
		sortKeys(track)
	end
end

local function ease(kind: string?, a: number): number
	if kind == "step" then
		return 0
	elseif kind == "linear" then
		return a
	end
	return a * a * (3 - 2 * a)
end

-- Значение дорожки в момент t: pos, rot (эйлер) или nil, если ключей нет
function Anim.sampleTrack(track, t: number)
	local keys = track.keys
	local n = #keys
	if n == 0 then
		return nil, nil
	end
	if t <= keys[1].t then
		return keys[1].pos, keys[1].rot
	end
	if t >= keys[n].t then
		return keys[n].pos, keys[n].rot
	end
	for i = 1, n - 1 do
		local k0, k1 = keys[i], keys[i + 1]
		if t >= k0.t and t <= k1.t then
			local span = k1.t - k0.t
			local a = if span > 0 then (t - k0.t) / span else 1
			a = ease(k0.ease, a)
			local pos = MathX.lerp(k0.pos, k1.pos, a)
			local q = MathX.slerp(
				MathX.quatFromMat(MathX.matFromEuler(k0.rot)),
				MathX.quatFromMat(MathX.matFromEuler(k1.rot)),
				a
			)
			return pos, MathX.eulerFromMat(MathX.matFromQuat(q))
		end
	end
	return keys[n].pos, keys[n].rot
end

function Anim.sample(clip, t: number)
	local out = {}
	for trackId, track in clip.tracks do
		local pos, rot = Anim.sampleTrack(track, t)
		if pos then
			out[trackId] = { pos = pos, rot = rot }
		end
	end
	return out
end

-- Приводит время воспроизведения к клипу. Возвращает локальное время и признак завершения
function Anim.wrapTime(clip, elapsed: number): (number, boolean)
	if clip.loop then
		if clip.length <= 0 then
			return 0, false
		end
		return elapsed % clip.length, false
	end
	if elapsed >= clip.length then
		return clip.length, true
	end
	return elapsed, false
end

-- Метки, пройденные при переходе от прошедшего времени e0 к e1 (e0 < m <= e1)
function Anim.markersCrossed(clip, e0: number, e1: number)
	local out = {}
	if e1 <= e0 or #clip.markers == 0 then
		return out
	end
	local len = clip.length
	local function scan(a: number, b: number)
		for _, m in clip.markers do
			if m.t > a and m.t <= b then
				table.insert(out, m)
			end
		end
	end
	if not clip.loop then
		-- метка ровно на нуле срабатывает в первом кадре
		if e0 <= 0 then
			for _, m in clip.markers do
				if m.t == 0 then
					table.insert(out, m)
				end
			end
		end
		scan(e0, math.min(e1, len))
		return out
	end
	local cycle0 = e0 // len
	local cycle1 = e1 // len
	if cycle0 == cycle1 then
		scan(e0 - cycle0 * len, e1 - cycle0 * len)
	else
		scan(e0 - cycle0 * len, len)
		for _ = cycle0 + 1, math.min(cycle1 - 1, cycle0 + 3) do
			scan(-1, len)
		end
		scan(-1, e1 - cycle1 * len)
	end
	return out
end

function Anim.addMarker(clip, id: string, t: number, name: string)
	local m = { id = id, t = roundT(math.clamp(t, 0, clip.length)), name = name }
	table.insert(clip.markers, m)
	table.sort(clip.markers, function(a, b)
		return a.t < b.t
	end)
	return m
end

function Anim.removeMarker(clip, id: string): boolean
	for i, m in clip.markers do
		if m.id == id then
			table.remove(clip.markers, i)
			return true
		end
	end
	return false
end

-- Проверка клипа на модели: какие дорожки ссылаются на отсутствующие детали
-- Ключи таких дорожек не удаляются: автор может вернуть деталь или перенести кадры
function Anim.validate(clip, parts: { [string]: any }, allowSpecial: boolean?)
	local missing = {}
	for trackId, track in clip.tracks do
		local special = allowSpecial and Anim.SPECIAL_TRACKS[trackId]
		if not special and parts[trackId] == nil and #track.keys > 0 then
			table.insert(missing, trackId)
		end
	end
	table.sort(missing)
	return missing
end

-- Переносит дорожку на другую деталь (например, после замены удалённой лапы)
function Anim.retarget(clip, fromTrack: string, toTrack: string): boolean
	local t = clip.tracks[fromTrack]
	if not t or clip.tracks[toTrack] then
		return false
	end
	clip.tracks[toTrack] = t
	clip.tracks[fromTrack] = nil
	return true
end

return Anim
