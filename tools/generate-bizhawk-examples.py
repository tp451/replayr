"""Create original input demonstrations; no published recordings are copied.
Run from the repository root. Each short gesture has an explicit test below.
"""
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED
ROOT = Path(__file__).resolve().parents[1] / "inst" / "extdata" / "expanded"
ROOT.mkdir(parents=True, exist_ok=True)

def movie(name, platform, groups, rows, core="", version="Version 2.10"):
    header = f"MovieVersion BizHawk v2.0\nPlatform {platform}\nCore {core}\nemuVersion {version}\nAuthor replayr contributors\nGameName Original input demonstration\n"
    key = "LogKey:" + "".join("#" + "|".join(g) + "|" for g in groups)
    text = "[Input]\n" + key + "\n" + "\n".join(rows) + "\n[/Input]\n"
    with ZipFile(ROOT / name, "w", compression=ZIP_DEFLATED) as z:
        for member, content in [("Header.txt", header), ("Input Log.txt", text)]:
            info = ZipInfo(member, date_time=(2020, 1, 1, 0, 0, 0))
            info.compress_type = ZIP_DEFLATED
            z.writestr(info, content.encode("utf-8"))

# Keyboard typing R, U, N, Return, followed by a joystick move while Shift is held.
keys = ["Key " + c for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"] + ["Key " + str(i) for i in range(10)] + ["Key Return", "Key Shift"]
rows = []
for name, joy in [("Key R", "....."), ("Key U", "....."), ("Key N", "....."), ("Key Return", "....."), ("Key Shift", "...RB")]:
    rows.append("|" + "".join("!" if k == name else "." for k in keys) + "|" + joy + "|")
movie("keyboard-command.bk2", "C64", [keys, ["P1 " + k for k in ["Up", "Down", "Left", "Right", "Button"]]], rows, "C64Hawk")
# A pen stroke from left to right, released before a microphone sample.
movie("touch-stroke.bk2", "NDS", [["Touch X", "Touch Y", "Mic Volume", "GBA Light Sensor", "Up", "A", "Touch", "LidOpen", "LidClose", "Power"]],
      ["|20,80,0,7,..T...|", "|80,80,0,7,..T...|", "|140,80,0,7,..T...|", "|140,80,60,7,......|"], "MelonDS")
# Independent Circle Pad and C-stick motions with one half-strength diagonal.
movie("two-stick-3ds.bk2", "3DS", [["Circle Pad X", "Circle Pad Y", "C-Stick X", "C-Stick Y", "Touch X", "Touch Y", "Tilt X", "Tilt Y", "A", "ZL", "ZR", "Touch", "Tilt", "Reset"]],
      ["|0,0,0,0,160,120,160,120,......|", "|127,0,0,127,160,120,160,120,A.....|", "|64,64,-128,0,160,120,160,120,.L....|", "|0,-128,0,-64,160,120,160,120,..R...|"], "Encore")
# Sweep each of the sixteen Intellivision disc contacts exactly once.
directions = "N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW".split()
movie("sixteen-direction-disc.bk2", "INTV", [["Power", "Reset"], ["P1 " + x for x in directions + ["Key 0", "Enter", "Clear"]]],
      ["|..|" + "." * i + "!" + "." * (18 - i) + "|" for i in range(16)], "IntelliHawk")
# Left and right digital pads move independently; they are not analogue sticks.
movie("dual-digital-pad.bk2", "VB", [["L_Up", "L_Down", "L_Left", "L_Right", "R_Up", "R_Down", "R_Left", "R_Right", "A", "B", "Power"]],
      ["|U......R...|", "|...R.U..A..|", "|...........|"], "Virtual Boyee")
# Relative mouse movement and all four 3DO mouse buttons, including button four.
movie("four-button-mouse.bk2", "3DO", [["Reset"], ["P1 Mouse X", "P1 Mouse Y", "P1 Left Button", "P1 Middle Button", "P1 Right Button", "P1 Fourth Button"]],
      ["|.|3,-2,L...|", "|.|4,0,...F|", "|.|0,0,.MR.|"], "Opera")
# Non-ASCII and punctuation keys retain distinct identities.
movie("punctuation-keys.bk2", "AppleII", [["'", ",", ".", "/", "A", "Return", "Previous Disk", "Next Disk"]],
      ["|!.......|", "|.!......|", "|..!...D.|", "|...!..D.|", "|....A...|"], "Virtu")
movie("unknown-control.bk2", "Example", [["Reset"], ["P1 Accelerator", "P1 Gear 1", "P1 Gear 2"]],
      ["|.|A1.|", "|.|A.2|"], "Example core")
# Legacy N64 BKM fields: fourteen button bits precede the two signed axes.
(ROOT / "legacy-n64.bkm").write_text("emuVersion Version 1.5.2\nMovieVersion BizHawk v0.0.1\nPlatform N64\nAuthor replayr contributors\n|.|.....A........ 127, 000|....B......... 000, 127|\n|r|.............. -128, 000|.............. 000, -128|\n", encoding="utf-8")
(ROOT / "legacy-sms.tas").write_text("emuVersion BizHawk v1.0.0\nMovieVersion BizHawk v0.0.1\nPlatform SMS\nAuthor replayr contributors\n|...R1.|......|..|\n|....1.|U.....|pr|\n", encoding="utf-8")
movie("gba-input.gbmv", "GBA", [["P1 Up", "P1 Down", "P1 Left", "P1 Right", "P1 Start", "P1 Select", "P1 B", "P1 A", "P1 L", "P1 R", "P1 Power"]],
      ["|...R...A...|", "|....T.....P|"], "GBAHawk")
movie("editor-input.tasproj", "NES", [["Power", "Reset"], ["P1 Up", "P1 Down", "P1 Left", "P1 Right", "P1 Start", "P1 Select", "P1 B", "P1 A"]],
      ["|..|...R...A|", "|..|...R....|"], "NesHawk")
