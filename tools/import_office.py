#!/usr/bin/env python3
"""Перенос Монеты-джентльмена и Инспектора из исходников Office в каталог мастерской.

Инструмент не перерисовывает модели вручную. Он исполняет оригинальные функции
Office (`M.clerk`, `M.toll` из src/server/Models.luau и позы `inspector`, `coin` из
src/client/Animator.luau) в CLI luau с минимальной эмуляцией CFrame/Instance и
записывает:
  * детали: имя, размер, цвет, материал, форму (Ball/Round = сферический меш,
    Cyl = цилиндр), прозрачность, мировое положение в позе покоя;
  * суставы: родитель по Motor6D, точка вращения = C1 сустава;
  * клипы: процедурные позы каждого состояния (Idle, Demand, Walk, Grab),
    выбранные с шагом по времени и пересчитанные в смещения ключей мастерской.
Каждый кадр проверяется: поза, собранная кинематикой мастерской (Rig.pose) из
записанных ключей, сравнивается с позой по формуле Roblox
Part1 = Part0 * C0 * Transform * C1^-1. При расхождении больше допуска сборка падает.

Логика Office (оплата, проверка карточки, таймер, погоня, захват, урон, экономика)
находится в Main.server.luau и Entities.luau и сюда не переносится.

Запуск:
  python3 tools/import_office.py --office <папка OfficePrototype> --luau <путь к luau> \
      --archive-sha <sha256 архива>  > src/shared/OfficeModels.luau
"""
import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def extract_function(src: str, name: str) -> str:
    m = re.search(r"^local function " + re.escape(name) + r"\(.*?^end\n", src, re.S | re.M)
    if not m:
        raise SystemExit(f"в Animator.luau нет функции {name}")
    return m.group(0)


SHIM = r'''
local CFmt = {}
local function newCF(p, m) return setmetatable({ p = p, m = m }, CFmt) end
local function rotX(a) local c, s = math.cos(a), math.sin(a) return { 1,0,0, 0,c,-s, 0,s,c } end
local function rotY(a) local c, s = math.cos(a), math.sin(a) return { c,0,s, 0,1,0, -s,0,c } end
local function rotZ(a) local c, s = math.cos(a), math.sin(a) return { c,-s,0, s,c,0, 0,0,1 } end
CFmt.__mul = function(a, b)
  local r = MathX.mul(a, b) return newCF(r.p, r.m)
end
CFmt.__index = function(t, k)
  if k == "Position" then return t.p
  elseif k == "Inverse" then return function(self) local r = MathX.inv(self) return newCF(r.p, r.m) end
  elseif k == "Lerp" then return function(self, o, a) local r = MathX.tfLerp(self, o, a) return newCF(r.p, r.m) end
  end
  return nil
end
CFrame = {
  new = function(x, y, z) return newCF({ x or 0, y or 0, z or 0 }, MathX.identity()) end,
  -- Roblox: CFrame.Angles(rx, ry, rz) = Rx * Ry * Rz
  Angles = function(x, y, z) return newCF({ 0, 0, 0 }, MathX.matMul(MathX.matMul(rotX(x or 0), rotY(y or 0)), rotZ(z or 0))) end,
}
Vector3 = { new = function(x, y, z) return { x or 0, y or 0, z or 0 } end }
Color3 = {
  fromRGB = function(r, g, b) return { r, g, b } end,
  new = function(r, g, b) return { math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5) } end,
}
Enum = setmetatable({}, { __index = function(_, cat)
  return setmetatable({}, { __index = function(_, item) return item end })
end })
local created = {}
local Inst = {}
Inst.__index = function(t, k)
  if k == "SetAttribute" then return function(self, n, v) rawget(self, "_attr")[n] = v end end
  if k == "GetAttribute" then return function(self, n) return rawget(self, "_attr")[n] end end
  return rawget(t, "_props")[k]
end
Inst.__newindex = function(t, k, v)
  rawget(t, "_props")[k] = v
  if k == "Parent" and v ~= nil and rawget(v, "_class") == "Part" and rawget(t, "_class") == "SpecialMesh" then
    rawget(v, "_props")._sphere = true
  end
end
Instance = { new = function(class)
  local o = setmetatable({ _class = class, _props = { Name = class }, _attr = {} }, Inst)
  table.insert(created, o)
  return o
end }
'''

DRIVER = r'''
local function r4(x) local v = math.floor(x * 10000 + 0.5) / 10000 if v == 0 then v = 0 end return v end
local function cls(o) return rawget(o, "_class") end
local function P(o) return rawget(o, "_props") end

-- Собирает модель: вызывает оригинальную функцию Office и снимает данные
local function capture(build)
  table.clear(created)
  local model = build()
  local parts, motors = {}, {}
  for _, o in created do
    if cls(o) == "Part" and P(o).Name ~= "RigRoot" then table.insert(parts, o) end
    if cls(o) == "Motor6D" then motors[P(P(o).Part1).Name] = o end
  end
  local data = { parts = {}, joints = {}, order = {} }
  for _, o in parts do
    local p = P(o)
    local name = p.Name
    assert(data.parts[name] == nil, "повтор имени детали " .. name)
    local shape = "Block"
    if p._sphere then shape = "Ellipsoid" elseif p.Shape == "Cylinder" then shape = "Cylinder" elseif p.Shape == "Ball" then shape = "Ball" end
    local pos, rot = MathX.decompose(p.CFrame)
    local mot = motors[name]
    local parentName = nil
    local pivot = { 0, 0, 0 }
    if mot then
      local p0 = P(P(mot).Part0).Name
      if p0 ~= "RigRoot" then parentName = p0 end
      pivot = { r4(P(mot).C1.p[1]), r4(P(mot).C1.p[2]), r4(P(mot).C1.p[3]) }
      data.joints[name] = { C0 = P(mot).C0, C1 = P(mot).C1, parent = p0 }
    end
    data.parts[name] = {
      id = name, name = name, shape = shape,
      size = { r4(p.Size[1]), r4(p.Size[2]), r4(p.Size[3]) },
      pos = { r4(pos[1]), r4(pos[2]), r4(pos[3]) }, rot = rot,
      color = p.Color or { 27, 31, 39 }, material = p.Material or "Plastic",
      transparency = p.Transparency or 0, pivot = pivot, parent = parentName,
      _cf = p.CFrame,
    }
    table.insert(data.order, name)
  end
  return data
end

local function blendLoop(fn, L, fade)
  return function(t)
    local a = fn(t)
    if t <= L - fade then return a end
    local b = fn(t - L)
    local w = (t - (L - fade)) / fade
    w = w * w * (3 - 2 * w)
    local out = {}
    for k, v in a do out[k] = v:Lerp(b[k] or CFrame.new(), w) end
    for k, v in b do if not out[k] then out[k] = CFrame.new():Lerp(v, w) end end
    return out
  end
end

-- Переход между состояниями с тем же сглаживанием, что в Animator (alpha = dt * 9)
local function simulate(fnOf, segments, step)
  local dt = 1 / 60
  local alpha = math.min(1, dt * 9)
  local cur = fnOf(segments[1].state)(0)
  local samples = {}
  local t, nextSample, total = 0, 0, 0
  for _, s in segments do total += s.duration end
  local seg, segStart = 1, 0
  while t <= total + 1e-9 do
    while seg < #segments and t >= segStart + segments[seg].duration do
      segStart += segments[seg].duration
      seg += 1
    end
    local target = fnOf(segments[seg].state)(t)
    local names = {}
    for k in cur do names[k] = true end
    for k in target do names[k] = true end
    for k in names do
      cur[k] = (cur[k] or CFrame.new()):Lerp(target[k] or CFrame.new(), alpha)
    end
    if t >= nextSample - 1e-9 then
      local snap = {}
      for k, v in cur do snap[k] = v end
      table.insert(samples, { t = math.floor(t * 1000 + 0.5) / 1000, pose = snap })
      nextSample += step
    end
    t += dt
  end
  return samples, total
end

local function bake(data, spec)
  local samples, length
  if spec.segments then
    samples, length = simulate(spec.fnOf, spec.segments, spec.step)
  else
    length = spec.length
    local fn = blendLoop(spec.fn, length, math.min(2, length * 0.25))
    samples = {}
    local n = math.floor(length / spec.step + 0.5)
    for i = 0, n do
      local t = math.min(length, i * spec.step)
      table.insert(samples, { t = math.floor(t * 1000 + 0.5) / 1000, pose = fn(t) })
    end
  end
  local tracks = {}
  local maxPos, maxRot = 0, 0
  for _, s in samples do
    local sample = {}
    for joint, T in s.pose do
      local j = data.joints[joint]
      if j then
        local d = MathX.mul(MathX.mul(j.C1, T), MathX.inv(j.C1))
        local dp, rot = Rig.deltaFromTf(data.parts[joint].pivot, d)
        local key = { s.t, r4(dp[1]), r4(dp[2]), r4(dp[3]), rot[1], rot[2], rot[3] }
        tracks[joint] = tracks[joint] or {}
        table.insert(tracks[joint], key)
        sample[joint] = { pos = { key[2], key[3], key[4] }, rot = { key[5], key[6], key[7] } }
      end
    end
    -- проверка: кинематика мастерской против формулы Roblox Motor6D
    local world = Rig.pose({ parts = data.parts }, sample, MathX.tfIdentity())
    local office = {}
    local function W(name)
      if name == "RigRoot" then return MathX.tfIdentity() end
      if office[name] then return office[name] end
      local j = data.joints[name]
      local w
      if not j then
        w = data.parts[name]._cf
      else
        local T = s.pose[name] or CFrame.new()
        w = MathX.mul(MathX.mul(MathX.mul(W(j.parent), j.C0), T), MathX.inv(j.C1))
      end
      office[name] = w
      return w
    end
    for name in data.parts do
      local a, b = world[name], W(name)
      for i = 1, 3 do maxPos = math.max(maxPos, math.abs(a.p[i] - b.p[i])) end
      for i = 1, 9 do maxRot = math.max(maxRot, math.abs(a.m[i] - b.m[i])) end
    end
  end
  assert(maxPos < 0.003 and maxRot < 0.001, string.format("%s: расхождение %.5f / %.5f", spec.name, maxPos, maxRot))
  io_stderr(string.format("clip %-20s keys/track %3d tracks %2d  err pos %.5f rot %.6f", spec.name, #samples, (function() local n = 0 for _ in tracks do n += 1 end return n end)(), maxPos, maxRot))
  return { name = spec.name, length = math.floor(length * 1000 + 0.5) / 1000, loop = spec.loop, tracks = tracks }
end

-- ---- вывод ----
local out = {}
local function emit(s) table.insert(out, s) end
local function num(v)
  if v == math.floor(v) then return string.format("%d", v) end
  local s = string.format("%.4f", v):gsub("0+$", ""):gsub("%.$", "")
  return s
end
local function list(t) local p = {} for i, v in t do p[i] = num(v) end return "{" .. table.concat(p, ",") .. "}" end
local function str(s) return string.format("%q", s) end

local function writeModel(key, title, data, clips, extra)
  emit(string.format("M.%s = {\n\tname = %s,\n\tparts = {", key, str(title)))
  for _, name in data.order do
    local p = data.parts[name]
    emit(string.format("\t\t{ id = %s, shape = %s, size = %s, pos = %s, rot = %s, color = %s, material = %s, transparency = %s, pivot = %s%s },",
      str(p.id), str(p.shape), list(p.size), list(p.pos), list(p.rot), list(p.color), str(p.material), num(p.transparency), list(p.pivot),
      p.parent and (", parent = " .. str(p.parent)) or ""))
  end
  emit("\t},\n\tclips = {")
  for _, c in clips do
    emit(string.format("\t\t{ name = %s, length = %s, loop = %s, tracks = {", str(c.name), num(c.length), tostring(c.loop)))
    local names = {}
    for n in c.tracks do table.insert(names, n) end
    table.sort(names)
    for _, n in names do
      local keys = {}
      for _, k in c.tracks[n] do table.insert(keys, list(k)) end
      emit(string.format("\t\t\t[%s] = {%s},", str(n), table.concat(keys, ",")))
    end
    emit("\t\t} },")
  end
  emit("\t},")
  if extra then emit(extra) end
  emit("}\n")
end

local TAU = math.pi * 2
local function stateFn(poseFn, state) return function(t) return poseFn(t, state) end end

local inspector = capture(function() return OfficeModels.clerk() end)
local inspectorClips = {
  bake(inspector, { name = "Ожидание", fn = stateFn(inspectorPose, "Idle"), length = 4 * TAU / 1.4, step = 0.3, loop = true }),
  bake(inspector, { name = "Требование карты", fn = stateFn(inspectorPose, "Demand"), length = 2 * TAU / 3, step = 0.2, loop = true }),
  bake(inspector, { name = "Ходьба", fn = stateFn(inspectorPose, "Walk"), length = TAU / 5.5, step = 1 / 24, loop = true }),
  bake(inspector, { name = "Захват", loop = false, step = 1 / 15,
    fnOf = function(st) return stateFn(inspectorPose, st) end,
    segments = { { state = "Idle", duration = 0.1 }, { state = "Grab", duration = 1.5 }, { state = "Idle", duration = 0.6 } } }),
}
local coinEye = capture(function() return OfficeModels.toll(1, "Eye") end)
local coinMoustache = capture(function() return OfficeModels.toll(1, "Moustache") end)
local function coinClips(data)
  return {
    bake(data, { name = "Ожидание", fn = stateFn(coinPose, "Idle"), length = TAU / 0.45, step = 0.25, loop = true }),
    bake(data, { name = "Требование оплаты", fn = stateFn(coinPose, "Demand"), length = 2 * TAU / 7, step = 1 / 30, loop = true }),
  }
end

emit("-- Сгенерировано tools/import_office.py из исходников Office, не править вручную")
emit("-- Источник: " .. SOURCE_INFO)
emit("-- Ключ клипа: { время, dx, dy, dz, rx, ry, rz } относительно позы покоя детали")
emit("local M = {}\n")
writeModel("inspector", "Инспектор", inspector, inspectorClips, "\tbody = \"office\",\n\toriginal = \"CardInspector (Models.clerk)\",")
writeModel("coinEye", "Монета-джентльмен", coinEye, coinClips(coinEye), "\toriginal = \"CoinGentleman (Models.toll, Look = Eye)\",")
writeModel("coinMoustache", "Монета-джентльмен с усами", coinMoustache, coinClips(coinMoustache), "\toriginal = \"CoinGentleman (Models.toll, Look = Moustache)\",")
emit("return M")
print(table.concat(out, "\n"))
'''


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--office", type=Path, required=True)
    ap.add_argument("--luau", required=True)
    ap.add_argument("--archive-sha", default="unknown")
    a = ap.parse_args()
    models = (a.office / "src/server/Models.luau").read_text(encoding="utf-8")
    animator = (a.office / "src/client/Animator.luau").read_text(encoding="utf-8")
    mathx = (ROOT / "src/shared/MathX.luau").read_text(encoding="utf-8")
    rig = (ROOT / "src/shared/Rig.luau").read_text(encoding="utf-8").replace("require(script.Parent.MathX)", "MathX")
    helpers = "local sin,cos,abs,max=math.sin,math.cos,math.abs,math.max\nlocal function ang(x,y,z) return CFrame.Angles(x or 0,y or 0,z or 0) end\n"
    pose_insp = extract_function(animator, "inspector")
    pose_coin = extract_function(animator, "coin")
    program = "\n".join([
        "local function io_stderr(s) print('#' .. s) end",
        "MathX = (function()\n" + mathx + "\nend)()",
        SHIM,
        "Rig = (function()\n" + rig + "\nend)()",
        "OfficeModels = (function()\n" + models + "\nend)()",
        "local inspectorPose, coinPose\ndo\n" + helpers + pose_insp + pose_coin + "inspectorPose, coinPose = inspector, coin\nend",
        "local SOURCE_INFO = " + repr("OfficePrototype-0.1.0-source.zip (Office 0.2.0-test), sha256 " + a.archive_sha).replace("'", '"'),
        DRIVER,
    ])
    with tempfile.TemporaryDirectory() as d:
        path = Path(d) / "import.luau"
        path.write_text(program, encoding="utf-8")
        res = subprocess.run([a.luau, str(path)], capture_output=True, text=True)
    if res.returncode != 0:
        sys.stderr.write(res.stdout[-3000:] + res.stderr[-3000:])
        raise SystemExit("импорт не удался")
    lines = res.stdout.splitlines()
    for l in lines:
        if l.startswith("#"):
            sys.stderr.write(l[1:] + "\n")
    sys.stdout.write("\n".join(l for l in lines if not l.startswith("#")) + "\n")


if __name__ == "__main__":
    main()
