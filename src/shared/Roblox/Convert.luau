--!nonstrict
-- Перевод данных проекта в типы Roblox и обратно

local MathX = require(script.Parent.Parent.MathX)

local Convert = {}

local function r3(x: number): number
	local v = math.floor(x * 1000 + 0.5) / 1000
	if v == 0 then
		return 0
	end
	return v
end

function Convert.v3(v): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

function Convert.fromV3(v: Vector3)
	return { r3(v.X), r3(v.Y), r3(v.Z) }
end

function Convert.cf(tf): CFrame
	local m = tf.m
	return CFrame.new(tf.p[1], tf.p[2], tf.p[3], m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9])
end

function Convert.tf(cf: CFrame)
	local x, y, z, a, b, c, d, e, f, g, h, i = cf:GetComponents()
	return { p = { x, y, z }, m = { a, b, c, d, e, f, g, h, i } }
end

function Convert.cfFrom(pos, rot): CFrame
	return Convert.cf(MathX.tf(pos, rot))
end

-- CFrame -> pos, rot (градусы YXZ) для хранения в проекте
function Convert.posRot(cf: CFrame)
	local tf = Convert.tf(cf)
	local pos, rot = MathX.decompose(tf)
	return { r3(pos[1]), r3(pos[2]), r3(pos[3]) }, rot
end

function Convert.color(c): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

function Convert.fromColor(c: Color3)
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end

return Convert
