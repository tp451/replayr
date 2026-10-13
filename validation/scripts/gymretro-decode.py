"""A separate decoder of the BK2 files that Gym Retro writes. It reads them as
Gym Retro's own reader does (openai/retro, src/movie-bk2.cpp, step()): the
first group of a row is skipped, and in each player's group a character
other than a dot is the button that character stands for, wherever it is.
replayr instead names the controls by their place in the line of names.
For each recording the decoder writes, row by row, the buttons each player
holds; it shares no code with replayr.
Usage: python -I gymretro-decode.py <folder with recordings> <folder for the output>"""
import pathlib
import sys
import zipfile

# The characters of the writer (s_keyNames) under the names of replayr's keys.
BUTTONS = {"A": "a", "B": "b", "C": "c", "X": "x", "Y": "y", "Z": "z", "S": "start", "s": "select", "M": "mode",
           "U": "dpad_up", "D": "dpad_down", "L": "dpad_left", "R": "dpad_right", "l": "l1", "r": "r1"}

source = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
for path in sorted(source.glob("*.bk2")):
    with zipfile.ZipFile(path) as archive:
        log = archive.read("Input Log.txt").decode("utf-8").splitlines()
    lines = []
    for row in log:
        if not row.startswith("|"):
            continue
        groups = row.split("|")[1:-1]
        system = groups[0]
        players = [" ".join(sorted(BUTTONS[c] for c in group if c != ".")) for group in groups[1:]]
        lines.append(system + "\t" + "\t".join(players))
    (out / (path.name + ".txt")).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("%-70s %6d rows" % (path.name, len(lines)))
