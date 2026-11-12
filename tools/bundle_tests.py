#!/usr/bin/env python3
"""Собирает чистые Luau-модули проекта и тесты в один файл для запуска в CLI `luau`.

Модули обращаются друг к другу как в Roblox (`require(script.Parent.X)`,
`game:GetService("ReplicatedStorage").Workshop.Shared`). Сборщик эмулирует дерево
экземпляров Rojo минимальными узлами, поэтому код модулей не меняется.

Использование: python3 tools/bundle_tests.py out.luau
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Рут-папки, как в default.project.json
TREES = [
    ("src/shared", ["ReplicatedStorage", "Workshop", "Shared"]),
    ("src/server/Core", ["ServerScriptService", "Workshop", "Core"]),
    ("tests", ["Tests"]),
]


def collect():
    modules = {}
    folders = set()
    for rel, base in TREES:
        top = os.path.join(ROOT, rel)
        if not os.path.isdir(top):
            continue
        for dirpath, _, files in os.walk(top):
            sub = os.path.relpath(dirpath, top)
            parts = [] if sub == "." else sub.split(os.sep)
            for i in range(len(base) + len(parts) + 1):
                folders.add("/".join((base + parts)[:i]))
            for f in sorted(files):
                if not f.endswith(".luau") or f.endswith(".server.luau") or f.endswith(".client.luau"):
                    continue
                name = f[: -len(".luau")]
                path = base + parts if name == "init" else base + parts + [name]
                with open(os.path.join(dirpath, f), encoding="utf-8") as fh:
                    src = fh.read()
                src = re.sub(r"^export type ", "type ", src, flags=re.M)
                modules["/".join(path)] = src
    return modules, folders


PRELUDE = r'''
local __defs = {}
local __cache = {}
local __known = {}
local __nodes = {}
local __node
local function __children(path)
    local out = {}
    local prefix = path == "" and "" or (path .. "/")
    for p in __known do
        if string.sub(p, 1, #prefix) == prefix and p ~= path then
            local rest = string.sub(p, #prefix + 1)
            if not string.find(rest, "/", 1, true) then
                table.insert(out, __node(p))
            end
        end
    end
    return out
end
function __node(path)
    local n = __nodes[path]
    if n then return n end
    n = setmetatable({ __path = path }, {
        __index = function(self, key)
            if key == "Parent" then
                local parent = string.match(path, "^(.*)/[^/]+$") or ""
                return __node(parent)
            elseif key == "Name" then
                return string.match(path, "([^/]+)$") or "game"
            elseif key == "GetChildren" then
                return function() return __children(path) end
            elseif key == "FindFirstChild" then
                return function(_, name)
                    local p = path == "" and name or (path .. "/" .. name)
                    if __known[p] then return __node(p) end
                    return nil
                end
            elseif key == "GetService" then
                return function(_, name) return __node(name) end
            end
            local p = path == "" and key or (path .. "/" .. key)
            if __known[p] then return __node(p) end
            error(tostring(key) .. " is not a valid member of " .. (path == "" and "game" or path), 2)
        end,
    })
    __nodes[path] = n
    return n
end
local function __require(node)
    local path = node.__path
    if __cache[path] ~= nil then return __cache[path] end
    local def = __defs[path]
    if not def then error("no module " .. path) end
    __cache[path] = false
    local res = def(node, __require, __node(""))
    __cache[path] = res
    return res
end
'''


def main():
    out = sys.argv[1]
    modules, folders = collect()
    lines = [PRELUDE]
    for f in sorted(folders):
        if f:
            lines.append("__known[%r] = true" % f)
    for path in sorted(modules):
        lines.append("__known[%r] = true" % path)
    for path, src in sorted(modules.items()):
        lines.append("__defs[%r] = function(script, require, game)" % path)
        lines.append(src)
        lines.append("end")
    lines.append('return __require(__node("Tests/Run"))')
    with open(out, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))


if __name__ == "__main__":
    main()
