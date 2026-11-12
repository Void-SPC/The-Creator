--!strict
-- Чистая математика трансформаций без зависимостей от Roblox
-- Вектор: {x, y, z}; матрица поворота 3x3: {r00, r01, r02, r10, ..., r22} (по строкам)
-- Трансформ: {p = vec, m = mat}; совпадает по смыслу с CFrame
-- Эйлеровы углы хранятся в градусах в порядке YXZ, как CFrame.fromOrientation

local MathX = {}

local rad, deg = math.rad, math.deg
local sin, cos, sqrt = math.sin, math.cos, math.sqrt
local asin, atan2 = math.asin, math.atan2

function MathX.v(x: number?, y: number?, z: number?)
	return { x or 0, y or 0, z or 0 }
end

function MathX.add(a, b)
	return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
end

function MathX.sub(a, b)
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end

function MathX.scale(a, s: number)
	return { a[1] * s, a[2] * s, a[3] * s }
end

function MathX.lerp(a, b, t: number)
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

function MathX.len(a)
	return sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
end

function MathX.identity()
	return { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
end

function MathX.matMul(a, b)
	local r = table.create(9, 0)
	for i = 0, 2 do
		for j = 0, 2 do
			local s = 0
			for k = 0, 2 do
				s += a[i * 3 + k + 1] * b[k * 3 + j + 1]
			end
			r[i * 3 + j + 1] = s
		end
	end
	return r
end

function MathX.matT(a)
	return { a[1], a[4], a[7], a[2], a[5], a[8], a[3], a[6], a[9] }
end

function MathX.matApply(m, v)
	return {
		m[1] * v[1] + m[2] * v[2] + m[3] * v[3],
		m[4] * v[1] + m[5] * v[2] + m[6] * v[3],
		m[7] * v[1] + m[8] * v[2] + m[9] * v[3],
	}
end

local function rotX(a)
	local c, s = cos(a), sin(a)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function rotY(a)
	local c, s = cos(a), sin(a)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rotZ(a)
	local c, s = cos(a), sin(a)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end

-- Углы в градусах, порядок как у CFrame.fromOrientation: R = Ry * Rx * Rz
function MathX.matFromEuler(e)
	return MathX.matMul(MathX.matMul(rotY(rad(e[2])), rotX(rad(e[1]))), rotZ(rad(e[3])))
end

function MathX.eulerFromMat(m)
	-- m[6] = r12 = -sin(x)
	local sx = -m[6]
	if sx > 1 then
		sx = 1
	elseif sx < -1 then
		sx = -1
	end
	local x = asin(sx)
	local y, z
	if math.abs(sx) < 0.99999 then
		y = atan2(m[3], m[9])
		z = atan2(m[4], m[5])
	else
		y = atan2(-m[7], m[1])
		z = 0
	end
	local function clean(v: number)
		local d = deg(v)
		local r = math.floor(d * 1000 + 0.5) / 1000
		if r == 0 then
			r = 0
		end
		return r
	end
	return { clean(x), clean(y), clean(z) }
end

function MathX.tf(p, e)
	return { p = { p[1], p[2], p[3] }, m = MathX.matFromEuler(e or { 0, 0, 0 }) }
end

function MathX.tfIdentity()
	return { p = { 0, 0, 0 }, m = MathX.identity() }
end

function MathX.mul(a, b)
	return { p = MathX.add(a.p, MathX.matApply(a.m, b.p)), m = MathX.matMul(a.m, b.m) }
end

function MathX.inv(a)
	local mt = MathX.matT(a.m)
	return { p = MathX.scale(MathX.matApply(mt, a.p), -1), m = mt }
end

function MathX.apply(a, v)
	return MathX.add(a.p, MathX.matApply(a.m, v))
end

-- Трансформ b в системе координат base
function MathX.toLocal(base, b)
	return MathX.mul(MathX.inv(base), b)
end

function MathX.toWorld(base, localTf)
	return MathX.mul(base, localTf)
end

function MathX.decompose(t)
	return { t.p[1], t.p[2], t.p[3] }, MathX.eulerFromMat(t.m)
end

-- Кватернионы {w, x, y, z}
function MathX.quatFromMat(m)
	local tr = m[1] + m[5] + m[9]
	local w, x, y, z
	if tr > 0 then
		local s = sqrt(tr + 1) * 2
		w = 0.25 * s
		x = (m[8] - m[6]) / s
		y = (m[3] - m[7]) / s
		z = (m[4] - m[2]) / s
	elseif m[1] > m[5] and m[1] > m[9] then
		local s = sqrt(1 + m[1] - m[5] - m[9]) * 2
		w = (m[8] - m[6]) / s
		x = 0.25 * s
		y = (m[2] + m[4]) / s
		z = (m[3] + m[7]) / s
	elseif m[5] > m[9] then
		local s = sqrt(1 + m[5] - m[1] - m[9]) * 2
		w = (m[3] - m[7]) / s
		x = (m[2] + m[4]) / s
		y = 0.25 * s
		z = (m[6] + m[8]) / s
	else
		local s = sqrt(1 + m[9] - m[1] - m[5]) * 2
		w = (m[4] - m[2]) / s
		x = (m[3] + m[7]) / s
		y = (m[6] + m[8]) / s
		z = 0.25 * s
	end
	return { w, x, y, z }
end

function MathX.matFromQuat(q)
	local w, x, y, z = q[1], q[2], q[3], q[4]
	return {
		1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w),
		2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w),
		2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y),
	}
end

function MathX.slerp(a, b, t: number)
	local dot = a[1] * b[1] + a[2] * b[2] + a[3] * b[3] + a[4] * b[4]
	local bb = b
	if dot < 0 then
		bb = { -b[1], -b[2], -b[3], -b[4] }
		dot = -dot
	end
	if dot > 0.9995 then
		local r = {
			a[1] + (bb[1] - a[1]) * t,
			a[2] + (bb[2] - a[2]) * t,
			a[3] + (bb[3] - a[3]) * t,
			a[4] + (bb[4] - a[4]) * t,
		}
		local l = sqrt(r[1] * r[1] + r[2] * r[2] + r[3] * r[3] + r[4] * r[4])
		return { r[1] / l, r[2] / l, r[3] / l, r[4] / l }
	end
	local theta0 = math.acos(dot)
	local theta = theta0 * t
	local s0 = cos(theta) - dot * sin(theta) / sin(theta0)
	local s1 = sin(theta) / sin(theta0)
	return {
		a[1] * s0 + bb[1] * s1,
		a[2] * s0 + bb[2] * s1,
		a[3] * s0 + bb[3] * s1,
		a[4] * s0 + bb[4] * s1,
	}
end

function MathX.tfLerp(a, b, t: number)
	local q = MathX.slerp(MathX.quatFromMat(a.m), MathX.quatFromMat(b.m), t)
	return { p = MathX.lerp(a.p, b.p, t), m = MathX.matFromQuat(q) }
end

function MathX.near(a: number, b: number, eps: number?)
	return math.abs(a - b) <= (eps or 1e-4)
end

function MathX.vNear(a, b, eps: number?)
	return MathX.near(a[1], b[1], eps) and MathX.near(a[2], b[2], eps) and MathX.near(a[3], b[3], eps)
end

function MathX.snap(v: number, step: number)
	if step <= 0 then
		return v
	end
	return math.floor(v / step + 0.5) * step
end

return MathX
