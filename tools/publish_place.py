#!/usr/bin/env python3
"""Загрузка собранного плейса в Roblox через Open Cloud. Запускается только вручную.

Защита от ошибки:
  * нужно ввести подтверждение ровно "UPDATE 74144820847995";
  * SHA-256 файла должен совпасть с тем, что показала сборка (manifest);
  * ключ берётся только из переменной окружения ROBLOX_API_KEY (секрет GitHub Actions),
    никогда не печатается и не передаётся в командной строке;
  * повторной отправки при сбое нет: ответ мог не дойти, а плейс уже обновился.

Способы:
  assets — PATCH /assets/v1/assets/{placeId} (так публикует Office, ключ уже проверен);
  places — POST /universes/v1/{universeId}/places/{placeId}/versions (Place Publishing API,
           ключу нужно право universe-places:write).
"""
import argparse, hashlib, json, os, re, time, urllib.error, urllib.request, uuid
from pathlib import Path

UNIVERSE = 6616737535
PLACE = 74144820847995
HOST = "https://apis.roblox.com"


def check(path: Path, confirmation: str, expected: str) -> bytes:
    if confirmation.strip() != f"UPDATE {PLACE}":
        raise ValueError(f'Подтверждение не совпало: нужно ввести "UPDATE {PLACE}"')
    data = path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if not re.fullmatch("[0-9a-f]{64}", expected.strip()) or digest != expected.strip():
        raise ValueError("SHA-256 файла не совпал с проверенной сборкой")
    if path.suffix != ".rbxlx" or not data.startswith(b"<roblox") or len(data) > 100_000_000:
        raise ValueError("Ожидался XML-плейс .rbxlx меньше 100 МБ")
    return data


def via_assets(data: bytes, key: str):
    boundary = "WorkshopBoundary" + uuid.uuid4().hex
    request = json.dumps({"assetId": PLACE, "assetType": "Place", "published": True}).encode()
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\nContent-Type: application/json\r\n\r\n'.encode() + request +
            f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="Workshop.rbxlx"\r\nContent-Type: application/xml\r\n\r\n'.encode() +
            data + f'\r\n--{boundary}--\r\n'.encode())
    req = urllib.request.Request(f"{HOST}/assets/v1/assets/{PLACE}", data=body, method="PATCH",
                                 headers={"x-api-key": key, "Content-Type": "multipart/form-data; boundary=" + boundary})
    with urllib.request.urlopen(req, timeout=120) as r:
        result = json.load(r)
    op = result.get("path", "")
    if not re.fullmatch(r"operations/[A-Za-z0-9_-]+", op):
        raise RuntimeError("Неожиданный ответ Roblox; проверьте Creator Hub перед повтором")
    for _ in range(90):
        req = urllib.request.Request(f"{HOST}/assets/v1/{op}", headers={"x-api-key": key})
        with urllib.request.urlopen(req, timeout=30) as r:
            status = json.load(r)
        if status.get("done"):
            if status.get("error"):
                raise RuntimeError("Roblox отклонил загрузку: " + str(status["error"]))
            resp = status.get("response", {})
            if resp.get("isPublished") is not True:
                raise RuntimeError("Roblox не подтвердил публикацию")
            return {"revision": resp.get("revisionId")}
        time.sleep(2)
    raise TimeoutError("Операция ещё идёт: проверьте Creator Hub, не загружайте повторно вслепую")


def via_places(data: bytes, key: str):
    req = urllib.request.Request(
        f"{HOST}/universes/v1/{UNIVERSE}/places/{PLACE}/versions?versionType=Published",
        data=data, method="POST", headers={"x-api-key": key, "Content-Type": "application/xml"})
    with urllib.request.urlopen(req, timeout=120) as r:
        result = json.load(r)
    if "versionNumber" not in result:
        raise RuntimeError("Roblox не вернул номер версии")
    return {"versionNumber": result["versionNumber"]}


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--file", type=Path, required=True)
    p.add_argument("--confirm", required=True)
    p.add_argument("--sha256", required=True)
    p.add_argument("--method", choices=["assets", "places"], default="assets")
    a = p.parse_args()
    try:
        data = check(a.file, a.confirm, a.sha256)
        key = os.environ.get("ROBLOX_API_KEY")
        if not key:
            raise ValueError("Секрет ROBLOX_API_KEY не задан")
        res = via_assets(data, key) if a.method == "assets" else via_places(data, key)
        res.update({"universeId": UNIVERSE, "placeId": PLACE, "sha256": a.sha256.strip(), "method": a.method})
        print(json.dumps(res, ensure_ascii=False))
        print(f"Игра: https://www.roblox.com/games/{PLACE}")
    except urllib.error.HTTPError as e:
        raise SystemExit(f"Roblox HTTP {e.code}; ключ и тело ответа не печатаются. Проверьте права ключа и Creator Hub")
    except Exception as e:
        raise SystemExit(str(e))


if __name__ == "__main__":
    main()
