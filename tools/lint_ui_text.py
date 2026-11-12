#!/usr/bin/env python3
"""Проверка правила точек во всех встроенных строках интерфейса.

UiText.luau проверяется отдельно тестом UiTextSpec (там есть подсказки из полных
предложений). Здесь проверяются все остальные строковые литералы с кириллицей:
сообщения проверки логики, подписи подсказок взаимодействия, названия деталей
каталога. Для них действует правило коротких подписей:
  * нет конечной точки;
  * нет точки-разделителя между частями («Шкаф. Вход»).
Также выводится список кириллических литералов в клиенте мимо UiText.

Авторские реплики демосцены (Demo.luau, поля text/lines) — это контент автора,
а не встроенный интерфейс, они пропускаются.

Запуск: python3 tools/lint_ui_text.py   (код возврата 1 при нарушениях)
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP_FILES = {"UiText.luau"}
CYR = re.compile(r"[А-Яа-яЁё]")
STRING = re.compile(r'"((?:[^"\\\n]|\\.)*)"')


def strip_comment(line: str) -> str:
    # комментарий начинается с -- вне строки
    out, in_str, i = [], False, 0
    while i < len(line):
        c = line[i]
        if c == '"' and (i == 0 or line[i - 1] != "\\"):
            in_str = not in_str
        if not in_str and line.startswith("--", i):
            break
        out.append(c)
        i += 1
    return "".join(out)


def check(text: str):
    masked = re.sub(r"\d+\.\d+", "0", text)
    problems = []
    if re.search(r"\.$", masked) or re.search(r"\.\s*\\n", masked):
        problems.append("конечная точка")
    if re.search(r"\.\s+[А-ЯЁA-Z]", masked):
        problems.append("точка-разделитель")
    return problems


def main():
    violations, hardcoded = [], []
    for base in ("src",):
        for dirpath, _, files in os.walk(os.path.join(ROOT, base)):
            for f in files:
                if not f.endswith(".luau") or f in SKIP_FILES:
                    continue
                path = os.path.join(dirpath, f)
                rel = os.path.relpath(path, ROOT)
                with open(path, encoding="utf-8") as fh:
                    for n, line in enumerate(fh, 1):
                        code = strip_comment(line)
                        for m in STRING.finditer(code):
                            s = m.group(1)
                            if not CYR.search(s):
                                continue
                            authored = f in ("Demo.luau", "Prefabs.luau") and ("text =" in code)
                            if authored:
                                continue
                            for p in check(s):
                                violations.append(f"{rel}:{n}: {p}: \"{s}\"")
                            if "/client/" in path.replace(os.sep, "/"):
                                hardcoded.append(f"{rel}:{n}: \"{s}\"")
    for v in violations:
        print("НАРУШЕНИЕ " + v)
    for h in hardcoded:
        print("в обход UiText " + h)
    print(f"нарушений: {len(violations)}, литералов в клиенте мимо UiText: {len(hardcoded)}")
    return 1 if violations or hardcoded else 0


if __name__ == "__main__":
    sys.exit(main())
