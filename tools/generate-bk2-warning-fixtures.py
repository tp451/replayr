"""Original examples of BizHawk timing axes, throttle, and legal separators.

Field definitions: BizHawk ab81ea25762af8ece499ba278e3f5cc3848ec742,
Gambatte.cs CreateControllerDefinition, MGBAHawk.IEmulator.cs, and
Bk2Controller.cs. Throttle Stick: MAME mame0255 namcos22.cpp, airco22
input ports (IPT_AD_STICK_Z). No game data or existing movie is included.
"""

from pathlib import Path
import zipfile, json

root = Path(__file__).resolve().parents[1] / "inst/extdata/bk2-variants"
root.mkdir(parents=True, exist_ok=True)
examples = {
    "subframe-gb.bk2": (
        "GB",
        "Gambatte",
        "LogKey:#Input Length|Up|Down|Left|Right|Start|Select|B|A|Power|",
        [
            "|35112,U........|",
            "|    1,.......A.|",
            "| 5758,...R..B..|",
            "|    0,........P|",
        ],
    ),
    "subframe-gba.bk2": (
        "GBA",
        "mGBA",
        "LogKey:#Input Length|Tilt X|Tilt Y|Tilt Z|Light Sensor|Up|Down|Left|Right|Start|Select|B|A|L|R|Power|",
        [
            "|280896,   17,  -23,   41,   99,...R...A...||",
            "|12345,  -31,   47,  -59,   83,......B...P||",
        ],
    ),
    "arcade-throttle.bk2": (
        "Arcade",
        "MAME",
        "LogKey:#AD Stick X|AD Stick Y|Throttle Stick|1 Player Start|Coin 1|Gun Trigger|Missile Button|Service 1|",
        ["|  321,  432,  345,..G..|", "|  654,  567,  456,.C.M.|"],
    ),
    "empty-separators.bk2": (
        "NES",
        "NesHawk",
        "LogKey:#Power|Reset|#P1 Up|P1 Down|P1 Left|P1 Right|P1 Start|P1 Select|P1 B|P1 A|",
        ["||..||U.......|||", "|.|.U|....|..A|", "|..|...R..B.||||"],
    ),
}
for name, (platform, core, key, rows) in examples.items():
    with zipfile.ZipFile(root / name, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for member, text in [
            (
                "Header.txt",
                f"MovieVersion BizHawk v2.0\nPlatform {platform}\nCore {core}\nemuVersion Version 2.10\nAuthor Original replayr example\n",
            ),
            (
                "Input Log.txt",
                "[Input]\n" + key + "\n" + "\n".join(rows) + "\n[/Input]\n",
            ),
        ]:
            info = zipfile.ZipInfo(member, date_time=(2000, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, text.encode())
(root / "expected.json").write_text(
    json.dumps(
        {
            "subframe-gb.bk2": {
                "Input Length": [35112, 1, 5758, 0],
                "Power": [False, False, False, True],
                "active_controls": [["dpad_up"], ["a"], ["dpad_right", "b"], []],
            },
            "subframe-gba.bk2": {
                "Input Length": [280896, 12345],
                "Tilt X": [17, -31],
                "Tilt Y": [-23, 47],
                "Tilt Z": [41, -59],
                "Light Sensor": [99, 83],
            },
            "arcade-throttle.bk2": {
                "AD Stick X": [321, 654],
                "AD Stick Y": [432, 567],
                "Throttle Stick": [345, 456],
            },
            "empty-separators.bk2": {
                "active_controls": [["dpad_up"], ["dpad_up", "a"], ["dpad_right", "b"]]
            },
        },
        indent=2,
    )
    + "\n",
    encoding="utf-8",
)
print("Generated four original BK2 variant examples.")
