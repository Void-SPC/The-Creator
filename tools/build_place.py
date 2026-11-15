#!/usr/bin/env python3
"""Сборка файла плейса игры «The Museum» (Roblox XML, .rbxlx) только средствами Python.

Дерево совпадает с default.project.json (Rojo):
  ReplicatedStorage/Workshop/Shared  <- src/shared
  ServerScriptService/Workshop       <- src/server
  StarterPlayer/StarterPlayerScripts/Workshop <- src/client
Правила Rojo: *.server.luau -> Script, *.client.luau -> LocalScript, остальное ->
ModuleScript; папка с init.luau становится ModuleScript с дочерними модулями.
Рядом пишется manifest с SHA-256: workflow публикации сверяет его перед загрузкой.

Запуск: python3 tools/build_place.py [--out dist/Workshop.rbxlx]
"""
import argparse
import hashlib
import json
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION = "6.0.0"


class Builder:
    def __init__(self):
        self.root = ET.Element("roblox", {"version": "4"})
        ET.SubElement(self.root, "External").text = "null"
        ET.SubElement(self.root, "External").text = "nil"
        self.serial = 0
        self.scripts = []

    def item(self, parent, cls, name):
        self.serial += 1
        node = ET.SubElement(parent, "Item", {"class": cls, "referent": f"RBX{self.serial:08X}"})
        props = ET.SubElement(node, "Properties")
        ET.SubElement(props, "string", {"name": "Name"}).text = name
        return node, props

    @staticmethod
    def prop(props, tag, name, value):
        ET.SubElement(props, tag, {"name": name}).text = str(value).lower() if isinstance(value, bool) else str(value)

    @staticmethod
    def vec3(props, name, xyz):
        e = ET.SubElement(props, "Vector3", {"name": name})
        for axis, v in zip("XYZ", xyz):
            ET.SubElement(e, axis).text = str(v)

    @staticmethod
    def cframe(props, name, xyz):
        e = ET.SubElement(props, "CoordinateFrame", {"name": name})
        values = {"X": xyz[0], "Y": xyz[1], "Z": xyz[2], "R00": 1, "R01": 0, "R02": 0, "R10": 0, "R11": 1, "R12": 0, "R20": 0, "R21": 0, "R22": 1}
        for k, v in values.items():
            ET.SubElement(e, k).text = str(v)

    @staticmethod
    def color3(props, name, rgb):
        e = ET.SubElement(props, "Color3", {"name": name})
        for k, v in zip("RGB", rgb):
            ET.SubElement(e, k).text = str(v)

    def script(self, parent, path: Path, name: str, cls: str):
        node, props = self.item(parent, cls, name)
        self.prop(props, "ProtectedString", "Source", path.read_text(encoding="utf-8"))
        if cls != "ModuleScript":
            self.prop(props, "bool", "Disabled", False)
        self.scripts.append({"path": str(path.relative_to(ROOT)), "class": cls, "name": name})
        return node

    def tree(self, parent, folder: Path):
        """Содержимое папки по правилам Rojo."""
        for entry in sorted(folder.iterdir()):
            if entry.is_dir():
                init = entry / "init.luau"
                if init.exists():
                    node = self.script(parent, init, entry.name, "ModuleScript")
                else:
                    node, _ = self.item(parent, "Folder", entry.name)
                self.tree(node, entry)
            elif entry.suffix == ".luau" and entry.name != "init.luau":
                if entry.name.endswith(".server.luau"):
                    self.script(parent, entry, entry.name[: -len(".server.luau")], "Script")
                elif entry.name.endswith(".client.luau"):
                    self.script(parent, entry, entry.name[: -len(".client.luau")], "LocalScript")
                else:
                    self.script(parent, entry, entry.stem, "ModuleScript")


def build(dest: Path):
    b = Builder()
    ws, wp = b.item(b.root, "Workspace", "Workspace")
    b.prop(wp, "float", "Gravity", 196.2)
    b.prop(wp, "float", "FallenPartsDestroyHeight", -500)
    # лабиринт строится по ходу игры; на телефоне подгружается только то, что рядом
    b.prop(wp, "bool", "StreamingEnabled", True)
    b.prop(wp, "int", "StreamingMinRadius", 64)
    b.prop(wp, "int", "StreamingTargetRadius", 200)

    _, lp = b.item(b.root, "Lighting", "Lighting")
    b.prop(lp, "float", "Brightness", 0)
    b.prop(lp, "float", "ClockTime", 0)
    b.prop(lp, "bool", "GlobalShadows", True)
    # освещение Future: тёплые лампы и тени в комнатах (на слабых телефонах Roblox упрощает сам)
    b.prop(lp, "token", "Technology", 4)
    b.color3(lp, "Ambient", (0.05, 0.05, 0.05))
    b.color3(lp, "OutdoorAmbient", (0, 0, 0))

    rep, _ = b.item(b.root, "ReplicatedStorage", "ReplicatedStorage")
    wsFolder, _ = b.item(rep, "Folder", "Workshop")
    shared, _ = b.item(wsFolder, "Folder", "Shared")
    b.tree(shared, ROOT / "src/shared")

    sss, _ = b.item(b.root, "ServerScriptService", "ServerScriptService")
    server, _ = b.item(sss, "Folder", "Workshop")
    b.tree(server, ROOT / "src/server")

    starter, stp = b.item(b.root, "StarterPlayer", "StarterPlayer")
    b.prop(stp, "float", "CharacterWalkSpeed", 15)
    # прыжков нет: в лабиринте всё проходится пешком
    b.prop(stp, "bool", "CharacterUseJumpPower", True)
    b.prop(stp, "float", "CharacterJumpPower", 0)
    b.prop(stp, "float", "CharacterJumpHeight", 0)
    b.prop(stp, "float", "CameraMaxZoomDistance", 40)
    sps, _ = b.item(starter, "StarterPlayerScripts", "StarterPlayerScripts")
    client, _ = b.item(sps, "Folder", "Workshop")
    b.tree(client, ROOT / "src/client")

    dest.parent.mkdir(parents=True, exist_ok=True)
    ET.indent(b.root)
    # Roblox распознаёт XML-плейс, только если файл начинается с <roblox
    ET.ElementTree(b.root).write(dest, encoding="utf-8", xml_declaration=False)
    parsed = ET.parse(dest)
    sources = parsed.findall('.//ProtectedString[@name="Source"]')
    assert len(sources) == len(b.scripts), "не все скрипты попали в файл"
    for s in sources:
        assert s.text, "пустой скрипт в файле"
    assert dest.read_bytes()[:7] == b"<roblox"
    data = dest.read_bytes()
    manifest = {
        "file": dest.name,
        "version": VERSION,
        "sha256": hashlib.sha256(data).hexdigest(),
        "bytes": len(data),
        "scripts": b.scripts,
        "target": {"universeId": 6616737535, "placeId": 74144820847995},
        "status": "XML собран и разобран обратно; запуск в движке Roblox этим скриптом не проверяется",
    }
    dest.with_suffix(".manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({k: manifest[k] for k in ("file", "version", "sha256", "bytes")}, ensure_ascii=False))
    print(f"скриптов: {len(b.scripts)}")
    return manifest


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, default=ROOT / "dist" / "Workshop.rbxlx")
    build(ap.parse_args().out)
