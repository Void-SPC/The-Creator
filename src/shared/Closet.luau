--!nonstrict
-- Шкаф: состояния «Свободен» -> «Вход» -> «Внутри» -> «Выход» -> «Свободен»
-- Точки входа, внутри и выхода хранятся относительно шкафа, поэтому при
-- перемещении и повороте шкафа они переезжают вместе с ним

local MathX = require(script.Parent.MathX)
local Format = require(script.Parent.Format)
local Anim = require(script.Parent.Anim)

local Closet = {}

Closet.FREE = "Free"
Closet.ENTERING = "Entering"
Closet.INSIDE = "Inside"
Closet.EXITING = "Exiting"

Closet.ENTER_CLIP = "EnterCloset"
Closet.EXIT_CLIP = "ExitCloset"

function Closet.new()
	return { state = Closet.FREE, occupant = nil, token = 0, since = 0, clipLength = 0 }
end

-- Нажатие «Спрятаться» или «Выйти». Повторное нажатие во время клипа отклоняется,
-- поэтому клипы не накладываются
function Closet.request(c, userId: number, now: number, clipLengths: { enter: number, exit: number })
	if c.state == Closet.FREE then
		c.state = Closet.ENTERING
		c.occupant = userId
		c.token += 1
		c.since = now
		c.clipLength = clipLengths.enter
		return true, "enter", c.token
	elseif c.state == Closet.INSIDE then
		if c.occupant ~= userId then
			return false, "occupied", nil
		end
		c.state = Closet.EXITING
		c.token += 1
		c.since = now
		c.clipLength = clipLengths.exit
		return true, "exit", c.token
	end
	if c.occupant == userId then
		return false, "busy", nil
	end
	return false, "occupied", nil
end

-- Клип завершился. Устаревший токен (после прерывания) игнорируется
function Closet.complete(c, token: number, now: number)
	if token ~= c.token then
		return false
	end
	if c.state == Closet.ENTERING then
		c.state = Closet.INSIDE
		c.since = now
		return true
	elseif c.state == Closet.EXITING then
		c.state = Closet.FREE
		c.occupant = nil
		c.since = now
		return true
	end
	return false
end

-- Освобождение при смерти, выходе игрока, удалении шкафа или прерывании клипа
function Closet.release(c, now: number)
	local who = c.occupant
	local was = c.state
	c.state = Closet.FREE
	c.occupant = nil
	c.token += 1
	c.since = now
	return who, was
end

-- Сторож: клип не может длиться дольше своей длины с запасом
function Closet.isStuck(c, now: number): boolean
	if c.state ~= Closet.ENTERING and c.state ~= Closet.EXITING then
		return false
	end
	return now - c.since > c.clipLength + 2
end

-- Мировая поза точки шкафа
function Closet.worldPose(closetPos, closetRot, localPose)
	local base = MathX.tf(closetPos, closetRot)
	return MathX.mul(base, MathX.tf(localPose.pos, localPose.rot))
end

local function key(clip, track, t, pose)
	Anim.setKey(clip, track, t, pose.pos, pose.rot, "smooth")
end

-- Поза камеры: на уровне глаз над точкой персонажа (точки шкафа стоят на полу)
Closet.EYE_HEIGHT = 4.6
local function eye(pose)
	return { pos = { pose.pos[1], pose.pos[2] + Closet.EYE_HEIGHT, pose.pos[3] }, rot = { pose.rot[1], pose.rot[2], pose.rot[3] } }
end

function Closet.defaultClips(entry, inside, exit)
	local enter = Format.newClip(Closet.ENTER_CLIP, Closet.ENTER_CLIP)
	enter.length = 0.9
	key(enter, "PlayerRoot", 0, entry)
	key(enter, "PlayerRoot", 0.9, inside)
	key(enter, "Camera", 0, eye(entry))
	key(enter, "Camera", 0.9, eye(inside))
	local leave = Format.newClip(Closet.EXIT_CLIP, Closet.EXIT_CLIP)
	leave.length = 0.8
	key(leave, "PlayerRoot", 0, inside)
	key(leave, "PlayerRoot", 0.8, exit)
	key(leave, "Camera", 0, eye(inside))
	key(leave, "Camera", 0.8, eye(exit))
	return enter, leave
end

-- Роль шкафа для модели глубиной depth (передняя сторона смотрит в -Z, как у Roblox)
function Closet.newRole(depth: number?)
	local d = depth or 3
	local entry = { pos = { 0, 0, -(d / 2 + 2) }, rot = { 0, 180, 0 } }
	local inside = { pos = { 0, 0, 0 }, rot = { 0, 0, 0 } } -- внутри лицом к дверце
	local exit = { pos = { 0, 0, -(d / 2 + 2.5) }, rot = { 0, 0, 0 } }
	local enterClip, exitClip = Closet.defaultClips(entry, inside, exit)
	return {
		type = "closet",
		entry = entry,
		inside = inside,
		exit = exit,
		enterClip = enterClip,
		exitClip = exitClip,
	}
end

-- Поза игрока (PlayerRoot) и камеры в мире для клипа шкафа в момент t
function Closet.sampleWorld(closetPos, closetRot, clip, t: number)
	local s = Anim.sample(clip, t)
	local base = MathX.tf(closetPos, closetRot)
	local out = {}
	for track, v in s do
		out[track] = MathX.mul(base, MathX.tf(v.pos, v.rot))
	end
	return out
end

return Closet
