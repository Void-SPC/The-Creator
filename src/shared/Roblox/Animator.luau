--!nonstrict
-- Проигрывание клипов модели. Движение по карте (корень модели) и движение частей
-- тела (клип) независимы: маршрут меняет root, клип двигает лапы относительно root

local Shared = script.Parent.Parent
local Anim = require(Shared.Anim)
local WorldBuilder = require(script.Parent.WorldBuilder)

local Animator = {}
Animator.__index = Animator

function Animator.new(handle, rootCF: CFrame)
	local self = setmetatable({}, Animator)
	self.handle = handle
	self.root = rootCF
	self.clip = nil
	self.elapsed = 0
	self.loopOverride = nil
	self.dirty = true
	return self
end

function Animator:findClip(name: string)
	local obj = self.handle.obj
	if obj.kind ~= "model" then
		return nil
	end
	for _, c in obj.model.clips do
		if c.name == name then
			return c
		end
	end
	return nil
end

function Animator:play(name: string, loop: boolean?)
	local clip = self:findClip(name)
	if not clip then
		return false
	end
	self.clip = clip
	self.elapsed = 0
	self.loopOverride = loop
	self.dirty = true
	return true
end

function Animator:stop()
	self.clip = nil
	self.dirty = true
end

function Animator:setRoot(cf: CFrame)
	self.root = cf
	self.dirty = true
end

function Animator:isLooping(): boolean
	if not self.clip then
		return false
	end
	if self.loopOverride ~= nil then
		return self.loopOverride
	end
	return self.clip.loop
end

-- Возвращает пройденные метки и завершённый клип (для событий логики)
function Animator:update(dt: number)
	local markers, finished = nil, nil
	local sample = nil
	if self.clip then
		local clip = self.clip
		local e0 = self.elapsed
		self.elapsed += dt
		local looping = self:isLooping()
		local view = if looping ~= clip.loop then table.clone(clip) else clip
		if view ~= clip then
			view.loop = looping
		end
		markers = Anim.markersCrossed(view, e0, self.elapsed)
		local t, done = Anim.wrapTime(view, self.elapsed)
		sample = Anim.sample(clip, t)
		if done then
			finished = clip
			self.clip = nil
		end
		self.dirty = true
	end
	if self.dirty then
		WorldBuilder.poseModel(self.handle, sample, self.root)
		self.dirty = self.clip ~= nil
	end
	return markers, finished
end

return Animator
