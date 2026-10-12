"""Draw the universal controller layout from replayr's public button registry.

Run from any directory: python tools/draw-input-devices.py --rscript Rscript
The R executable reads the checkout's registry; no installed replayr is used.
"""

from pathlib import Path
from html import escape
import argparse, csv, io, math, subprocess

args = argparse.ArgumentParser()
args.add_argument("--rscript", default="Rscript")
args.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
args = args.parse_args()
repo = args.repo.resolve()
r = subprocess.run(
    [
        args.rscript,
        "--vanilla",
        "-e",
        "source(commandArgs(TRUE)[1]); write.csv(button_layout(),stdout(),row.names=FALSE)",
        str(repo / "R/controller_layout.R"),
    ],
    check=True,
    capture_output=True,
    text=True,
)
registry = {row["key"]: row for row in csv.DictReader(io.StringIO(r.stdout))}
seen = set()
parts = [
    """<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="2160" viewBox="0 0 1400 2160" role="img" aria-labelledby="title description">
<title id="title">replayr universal button layout</title>
<desc id="description">A composite controller and peripheral diagrams map every registered control to its stable numeric ID, including both eight-direction stick sets and L3 and R3 clicks. The Wii Remote shows shared IDs for every recorded button. Keyboard and touchscreen examples retain source identities and numeric channels. Stable IDs differ from compact recording column numbers.</desc>
<defs><style>
text{font-family:Georgia,'Times New Roman',serif;fill:#222}
.title{font-size:34px;font-weight:700}.head{font-size:25px;font-weight:700}
.body{font-size:21px}.small{font-size:18px}.tiny{font-size:16px}.code{font-family:Consolas,monospace;font-size:19px}
.shell{fill:#fdfaf3;stroke:#222;stroke-width:2.3;stroke-linejoin:round}
.wire{fill:none;stroke:#7b8d96;stroke-width:1.7;stroke-linecap:round;stroke-linejoin:round}
.button{fill:#fff;stroke:#333;stroke-width:2}.id{font-size:25px;font-weight:700;fill:#222;text-anchor:middle}
.label{font-size:18px;text-anchor:middle}.derived{fill:#f3eef9;stroke:#81649e;stroke-width:1.8}.dirid{font-size:23px;font-weight:700;fill:#67498c;text-anchor:middle}
.numeric{fill:#fff4e8;stroke:#b87a40;stroke-width:1.5}.orange{fill:#996126}.purple{fill:#67498c}
.rule{stroke:#d5dee1;stroke-width:1.5}.arrow{fill:none;stroke:#607782;stroke-width:1.8;marker-end:url(#arrow)}
</style><marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0 0 L8 4 L0 8" fill="none" stroke="#607782" stroke-width="1.3"/></marker></defs>
<rect width="1400" height="2160" fill="#f5efe1"/>
"""
]


def add(x):
    parts.append(x)


def text(x, y, value, cls="body", anchor=None):
    add(
        f'<text class="{cls}" x="{x}" y="{y}"'
        + (f' text-anchor="{anchor}"' if anchor else "")
        + f">{escape(str(value))}</text>"
    )


def rect(x, y, w, h, cls="button", rx=10):
    add(f'<rect class="{cls}" x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}"/>')


def circle(x, y, r, cls="button"):
    add(f'<circle class="{cls}" cx="{x}" cy="{y}" r="{r}"/>')


def path(d, cls="wire"):
    add(f'<path class="{cls}" d="{d}"/>')


def ident(key):
    seen.add(key)
    return registry[key]["id"]


def button(x, y, key, label=None, w=86, h=63, cls="button"):
    add(f'<g data-key="{key}" data-id="{ident(key)}">')
    rect(x - w / 2, y - h / 2, w, h, cls, 11)
    text(x, y - 2, registry[key]["id"], "dirid" if cls == "derived" else "id")
    text(x, y + 21, label or registry[key]["name"], "label")
    add("</g>")


def callout(x, y, key, label):
    add(f'<g data-key="{key}" data-id="{ident(key)}">')
    rect(x, y - 22, 43, 31, "button", 8)
    text(x + 21.5, y + 2, registry[key]["id"], "id")
    text(x + 55, y + 1, label, "small")
    add("</g>")


text(40, 48, "Universal button layout", "title")
text(
    40,
    83,
    "Numbers are stable IDs from button_layout(). Labels identify the controls.",
    "body",
)
rect(1030, 27, 39, 31)
text(1049.5, 51, "8", "id")
text(1082, 50, "Registered button", "small")
rect(1030, 70, 39, 31, "derived")
text(1049.5, 94, "24", "dirid")
text(1082, 93, "Derived direction", "small")

# Controller housing leaves space for both sticks and their direction labels.
add('<g transform="translate(-92,-6) scale(1.8,1.35)">')
path(
    "M200 245 C200 175 320 145 440 145 C560 145 680 175 680 245 L680 410 C680 490 600 530 530 530 L350 530 C280 530 200 490 200 410 Z",
    "shell",
)
add("</g>")
for x, side in [(355, "l"), (1045, "r")]:
    button(x, 170, side + "2", side.upper() + "2", 100, 52)
    button(x, 232, side + "1", side.upper() + "1", 125, 52)
button(603, 290, "select", "Select / −", 126, 56)
button(797, 290, "start", "Start / +", 126, 56)
button(700, 352, "mode", "Mode", 96, 56)
# D-pad and six-button face arrangement.
path("M406 300 H454 V346 H500 V394 H454 V440 H406 V394 H360 V346 H406Z", "button")
for x, y, k in [
    (430, 328, "dpad_up"),
    (430, 424, "dpad_down"),
    (382, 378, "dpad_left"),
    (478, 378, "dpad_right"),
]:
    add(f'<g data-key="{k}" data-id="{ident(k)}">')
    text(x, y, registry[k]["id"], "id")
    add("</g>")
text(430, 470, "D-pad", "small", "middle")
for x, y, k in [
    (916, 340, "x"),
    (977, 325, "y"),
    (1038, 340, "c"),
    (916, 402, "b"),
    (977, 417, "a"),
    (1038, 402, "z"),
]:
    add(f'<g data-key="{k}" data-id="{ident(k)}">')
    circle(x, y, 27)
    text(x, y - 3, registry[k]["id"], "id")
    text(x, y + 18, k.upper(), "label")
    add("</g>")
# Position both sticks in the lower half of the housing.
dirs = [
    ("e", 0),
    ("ne", 45),
    ("n", 90),
    ("nw", 135),
    ("w", 180),
    ("sw", 225),
    ("s", 270),
    ("se", 315),
]
for cx, side, click in [(510, "left", "l3"), (890, "right", "r3")]:
    cy = 581
    circle(cx, cy, 62, "shell")
    circle(cx, cy, 38)
    add(f'<g data-key="{click}" data-id="{ident(click)}">')
    text(cx, cy - 2, registry[click]["id"], "id")
    text(cx, cy + 20, click.upper(), "label")
    add("</g>")
    for d, angle in dirs:
        a = math.radians(angle)
        x = round(cx + 94 * math.cos(a), 1)
        y = round(cy - 94 * math.sin(a), 1)
        key = f"{side}_{d}"
        add(f'<g data-key="{key}" data-id="{ident(key)}">')
        text(x, y, registry[key]["id"], "dirid")
        text(x, y + 18, d.upper(), "label purple")
        add("</g>")
    text(cx, 728, side.capitalize() + " stick", "small", "middle")
for dx, dy, k in [
    (0, -36, "c_up"),
    (0, 36, "c_down"),
    (-40, 0, "c_left"),
    (40, 0, "c_right"),
]:
    x = 700 + dx
    y = 459 + dy
    add(f'<g data-key="{k}" data-id="{ident(k)}">')
    circle(x, y, 22)
    text(x, y + 8, registry[k]["id"], "id")
    add("</g>")
text(700, 535, "N64 C-buttons", "small", "middle")
text(40, 185, "D-pad", "head")
for i, (k, label) in enumerate(
    [
        ("dpad_right", "Right"),
        ("dpad_left", "Left"),
        ("dpad_down", "Down"),
        ("dpad_up", "Up"),
    ]
):
    callout(40, 223 + 37 * i, k, label)
text(40, 443, "Stick clicks", "head")
callout(40, 483, "l3", "Left (L3)")
callout(40, 526, "r3", "Right (R3)")
text(1171, 185, "Face buttons", "head")
for i, k in enumerate(["b", "a", "x", "y", "c", "z"]):
    callout(1171, 223 + 37 * i, k, k.upper())
text(1171, 503, "C-buttons", "head")
for i, (k, label) in enumerate(
    [("c_right", "Right"), ("c_left", "Left"), ("c_down", "Down"), ("c_up", "Up")]
):
    callout(1171, 542 + 37 * i, k, label)
text(
    40,
    747,
    "Direction IDs are added by cardinal4 or cardinal8. Angles and magnitudes appear in stick_channels().",
    "small",
)
add('<line class="rule" x1="40" y1="773" x2="1360" y2="773"/>')

# Peripheral identities: numbers remain the same even in a small movie layout.
text(40, 815, "Keypad digits", "head")
text(490, 815, "Mouse and light gun", "head")
text(965, 815, "Power Pad sensors", "head")
rect(58, 845, 360, 302, "shell", 27)
for digit in range(1, 10):
    row, col = divmod(digit - 1, 3)
    button(131 + col * 107, 890 + row * 77, f"numbered_{digit}", str(digit), 88, 62)
button(238, 1121, "numbered_0", "0", 88, 59)
text(238, 1184, "Equal digits share IDs with Power Pad", "small", "middle")

# Mouse button boundaries and a small wheel; its click ID is called out outside.
path(
    "M602 849 C552 849 521 881 521 931 V965 C521 1004 553 1028 602 1028 C651 1028 683 1004 683 965 V931 C683 881 652 849 602 849 Z",
    "shell",
)
path("M602 850 V948 M522 948 Q602 963 682 948")
rect(591, 868, 22, 42, "button", 10)
for y in [879, 887, 895]:
    path(f"M596 {y} H608")
for x, k, label in [(555, "a", "Left"), (649, "b", "Right")]:
    add(f'<g data-key="{k}" data-id="{ident(k)}">')
    text(x, 915, registry[k]["id"], "id")
    text(x, 937, label, "label")
    add("</g>")
path("M614 888 H704")
callout(713, 895, "x", "Wheel click")
text(713, 956, "X / Y movement", "small orange")
text(713, 986, "Wheel movement", "small orange")
text(713, 1020, "Side 4/5 → 11/12", "small")
path(
    "M508 1050 H695 L718 1068 H755 V1100 H678 L658 1120 H605 L593 1173 H550 L565 1113 H519Z",
    "shell",
)
path("M610 1120 Q636 1142 656 1119")
circle(619, 1116, 7)
callout(737, 1071, "y", "Offscreen shot")
callout(689, 1143, "a", "Trigger / A")
path("M686 1134 H652 L619 1116", "arrow")
text(523, 1191, "Aim X / Y → analog_channels()", "small orange")

path("M956 849 H1350 L1365 1157 H940Z", "shell")
for sensor in range(1, 13):
    row, col = divmod(sensor - 1, 4)
    x = 1003 + col * 100
    y = 904 + row * 100
    circle(x, y, 39)
    key = f"numbered_{sensor}"
    add(f'<g data-key="{key}" data-id="{ident(key)}">')
    text(x, y - 1, registry[key]["id"], "id")
    text(x, y + 21, str(sensor), "label")
    add("</g>")
text(1153, 1191, "ID above · sensor number below", "small", "middle")

text(40, 1251, "Shared action buttons", "head")
path("M62 1275 H1338 L1360 1460 H40Z", "shell")
for x, key, first, second in [
    (220, "a", "Attack · Punch · Fire", "Arcade 1 · Doom Attack"),
    (540, "b", "Jump · Use · Missile", "Arcade 2 · Jump/Start"),
    (860, "x", "Kick · Arcade 3", "Mouse middle"),
    (1180, "y", "Arcade D · Arcade 4", "Offscreen shot"),
]:
    add(f'<g data-key="{key}" data-id="{ident(key)}">')
    circle(x, 1320, 32)
    text(x, 1318, registry[key]["id"], "id")
    text(x, 1340, key.upper(), "label")
    text(x, 1384, first, "small", "middle")
    text(x, 1413, second, "small", "middle")
    add("</g>")
text(
    700,
    1446,
    "Arcade buttons 5–8 → L1, R1, L2, R2. View change → Select.",
    "small",
    "middle",
)

add('<line class="rule" x1="40" y1="1480" x2="1360" y2="1480"/>')
text(40, 1521, "Shared controls and keyboard identities", "head")
text(
    40,
    1552,
    "Equivalent buttons share an ID. Keyboard keys retain their source key codes.",
    "small",
)

# Wii Remote: every recorded button is shown; B is on the back.
text(46, 1600, "Wii Remote", "head")
rect(51, 1623, 121, 361, "shell", 20)
circle(73, 1645, 9, "wire")
text(190, 1649, "Power (not in DTM input)", "small")
path("M99 1664 H125 V1689 H150 V1715 H125 V1740 H99 V1715 H74 V1689 H99Z", "button")
for x, y, key in [
    (112, 1684, "dpad_up"),
    (112, 1734, "dpad_down"),
    (87, 1709, "dpad_left"),
    (137, 1709, "dpad_right"),
]:
    text(x, y, ident(key), "label")
circle(112, 1777, 25)
text(112, 1774, ident("a"), "id")
text(112, 1794, "A", "label")
for x, label in [(77, "−"), (112, "⌂"), (147, "+")]:
    circle(x, 1827, 13)
    text(x, 1833, label, "label")
for y, label in [(1876, "1"), (1921, "2")]:
    circle(112, y, 17)
    text(112, y + 6, label, "label")
for x in [82, 102, 122, 142]:
    rect(x, 1958, 7, 7, "wire", 1)
rect(204, 1714, 48, 126, "shell", 17)
rect(209, 1740, 39, 58, "button", 10)
text(228.5, 1765, ident("b"), "id")
text(228.5, 1787, "B", "label")
text(228, 1867, "Back", "small", "middle")
for i, (label, key) in enumerate(
    [
        ("D-pad", "dpad_right"),
        ("A", "a"),
        ("B", "b"),
        ("+", "start"),
        ("−", "select"),
        ("Home", "mode"),
        ("1", "x"),
        ("2", "y"),
    ]
):
    value = (
        "D-pad → 1–4"
        if label == "D-pad"
        else f"{label} → {ident(key)} ({registry[key]['name']})"
    )
    text(281, 1694 + 37 * i, value, "code")
text(46, 2030, "IR, acceleration, rotation → analog_channels()", "small orange")

# WASD keycaps and their actual unshifted libTAS KeySym identities.
text(727, 1600, "Keyboard (libTAS)", "head")
rect(727, 1623, 623, 236, "shell", 18)
for x, y, label in [
    (888, 1644, "W"),
    (804, 1710, "A"),
    (888, 1710, "S"),
    (972, 1710, "D"),
]:
    rect(x, y, 65, 53, "button", 6)
    text(x + 32.5, y + 34, label, "id")
rect(804, 1778, 391, 53, "button", 6)
text(999.5, 1812, "Space", "label")
for x, y, key, code in [
    (727, 1895, "W", "77"),
    (1050, 1895, "A", "61"),
    (727, 1927, "S", "73"),
    (1050, 1927, "D", "64"),
]:
    text(x, y, f"{key} → control:keysym_{code}", "code")
text(727, 1959, "Space → control:keysym_20", "code")
text(727, 1991, "Key codes shown for unshifted letters.", "small")

# Touch coordinates remain numeric; contact and microphone are discrete controls.
rect(727, 2020, 137, 81, "shell", 10)
rect(739, 2032, 113, 54, "numeric", 3)
path("M766 2068 L823 2046")
circle(823, 2046, 4)
text(887, 2038, "DS touch → control:touch", "code")
text(887, 2070, "Touch X / Y → analog_channels()", "small orange")
callout(46, 2080, "microphone", "Microphone")
text(
    40,
    2135,
    "Compact columns: in sample.dtm, column 6 is ID 7 (B); column 12 is ID 18 (Z). Inspect button_layout(movie).",
    "small",
)
add("</svg>")
assert seen == set(
    registry
), f"Registered controls missing from diagram: {set(registry)-seen}"
out = repo / "man/figures/universal_buttons_layout.svg"
out.write_text("\n".join(parts), encoding="utf-8")
print(f"{out}: all {len(registry)} registered IDs included")
