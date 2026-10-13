"""Input lists of FB Alpha games, read from the driver sources.

Usage: python fba_inputs.py <directory with d_*.cpp files> <output.json>
       [ROM name ...]

With ROM names, only the lists of those games are written.

An FBM recording stores one value for every entry of the game's input list,
in list order (src/burner/win32/replay.cpp), and does not name the game.
The list is the BurnInputInfo array that the game's BurnDriver entry refers
to. This script reads both from the driver sources of TASEmulators/fbarr at
revision b679678de6b9f6548c46862d4c74ba4fb7cc1fdf (fbarr/src/burn/drivers)
and writes, for every ROM name, the ordered inputs with their display name,
type and the short description FB Alpha uses to bind controls. No replayr
file is read.
"""

import json
import re
import sys
from pathlib import Path

_TOKEN = re.compile(r'"(?:\\.|[^"\\])*"|/\*.*?\*/|//[^\n]*', re.S)
_LIST = re.compile(r"struct\s+BurnInputInfo\s+(\w+)InputList\s*\[\s*\]\s*=\s*\{(.*?)\}\s*;", re.S)
_ENTRY = re.compile(
    r'(?:\{|\bA\s*\()\s*"((?:[^"\\]|\\.)*)"\s*,\s*(BIT_\w+)\s*,\s*([^,{}]+?)\s*,'
    r'\s*"((?:[^"\\]|\\.)*)"\s*,?\s*[})]')
_DRIVER = re.compile(r'struct\s+BurnDriver\w*\s+\w+\s*=\s*\{\s*"([^"]+)"(.*?)\}\s*;', re.S)


def clean(text):
    """Remove comments and keep string literals."""
    return _TOKEN.sub(lambda m: m.group(0) if m.group(0).startswith('"') else " ", text)


def main():
    source, target = Path(sys.argv[1]), Path(sys.argv[2])
    games = {}
    for driver in sorted(source.glob("d_*.cpp")):
        text = clean(driver.read_text(encoding="latin-1"))
        lists = {}
        for name, body in _LIST.findall(text):
            lists[name] = [{"name": shown, "type": kind, "info": info,
                            "bound": pointer.strip() not in ("NULL", "0")}
                           for shown, kind, pointer, info in _ENTRY.findall(body)]
        for rom, body in _DRIVER.findall(text):
            used = re.search(r"\b(\w+)InputInfo\b", body)
            if used and used.group(1) in lists:
                games[rom] = {"source": driver.name, "list": used.group(1),
                              "inputs": lists[used.group(1)]}
    wanted = sys.argv[3:]
    if wanted:
        games = {rom: games[rom] for rom in wanted}
    target.write_text(json.dumps(games, indent=1), encoding="utf-8")
    print(len(games), "games")


if __name__ == "__main__":
    main()
