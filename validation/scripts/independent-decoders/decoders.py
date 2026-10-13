"""Independent decoders for emulator input recordings.

Each decoder is written from the published format description or the
emulator's own source, cited at the function. No replayr code, constant, or
output is used here. A decoder returns a dictionary:

  n          number of observations decoded from the file
  declared   observation count declared in the header, or None
  players    one {control name: uint8 array of length n} per controller
  numeric    one {channel name: int64 array of length n} per controller
  flags      {name: uint8 array of length n} for per-observation commands

A numeric value that an observation does not hold is NaN. Where a format
stores them, a decoder also returns tables of per-observation columns:
system (console commands), timing, subframes and poll_fields.

Control names are the names used by the format description.
"""

from pathlib import Path
from xml.etree import ElementTree
import gzip
import json
import re
import struct
import tarfile
import zipfile

import numpy as np


class NotCovered(Exception):
    """The file uses a variant that this decoder does not describe."""


def _bit(words, mask):
    return ((words & mask) != 0).astype("u1")


# VBM -- Visual Boy Advance re-recording.
# https://tasvideos.org/EmulatorResources/VBA/VBM (retrieved 12 October 2026)
VBM_BUTTONS = [
    ("A", 0x0001), ("B", 0x0002), ("Select", 0x0004), ("Start", 0x0008),
    ("Right", 0x0010), ("Left", 0x0020), ("Up", 0x0040), ("Down", 0x0080),
    ("R", 0x0100), ("L", 0x0200),
]


def decode_vbm(path):
    data = Path(path).read_bytes()
    if data[:4] != b"VBM\x1a":
        raise NotCovered("no VBM signature")
    declared = struct.unpack_from("<I", data, 0x0C)[0]
    controllers = [i for i in range(4) if data[0x15] & (1 << i)]
    offset = struct.unpack_from("<I", data, 0x3C)[0]
    if not controllers:
        raise NotCovered("no controller in use")
    width = len(controllers)
    n = (len(data) - offset) // (2 * width)
    words = np.frombuffer(data, dtype="<u2", count=n * width, offset=offset)
    words = words.reshape(n, width)
    players = [
        {name: _bit(words[:, column], mask) for name, mask in VBM_BUTTONS}
        for column in range(width)
    ]
    any_port = np.bitwise_or.reduce(words, axis=1)
    flags = {
        "reset_old": _bit(any_port, 0x0400),
        "reset_new": _bit(any_port, 0x0800),
        "motion_left": _bit(any_port, 0x1000),
        "motion_right": _bit(any_port, 0x2000),
        "motion_down": _bit(any_port, 0x4000),
        "motion_up": _bit(any_port, 0x8000),
    }
    return {
        "n": n, "declared": declared, "players": players,
        "numeric": [{} for _ in players], "flags": flags,
        "console": {"gba": bool(data[0x16] & 1), "gbc": bool(data[0x16] & 2),
                    "sgb": bool(data[0x16] & 4)},
    }


# DSM -- DeSmuME.
# https://tasvideos.org/EmulatorResources/DeSmuME/DSM (retrieved 12 October 2026)
# Columns RLDUTSBAYXWEG. The description notes that T is Select and S is Start.
# Record boundaries and command bits follow DeSmuME src/movie.cpp (LoadFM2,
# MovieRecord::parse) and movie.h at revision 1275dc64f5d1f5ef18dc1bc1fa9e012024b6df1a:
# the loader skips whitespace and reads a record at every pipe, so records
# may share a line; microphone 1, reset 2, lid 4.
DSM_BUTTONS = [
    "Right", "Left", "Down", "Up", "Select", "Start", "B", "A", "Y", "X",
    "L", "R", "Debug",
]
_DSM_RECORD = re.compile(rb"\|(\d+)\|([^|]{13})([^|]*)\|")


def decode_dsm(path):
    data = Path(path).read_bytes()
    first = re.search(rb"^[ \t]*\|", data, re.M)
    if first is None or re.search(rb"^binary[ \t]+1", data[:first.start()], re.M):
        raise NotCovered("no text input log")
    records = _DSM_RECORD.findall(data, first.start())
    n = len(records)
    field = bytearray()
    command, touch = [], []
    for number, pad, tail in records:
        command.append(int(number))
        field += pad
        # Later emulator versions append a microphone sample to the stylus triple.
        rest = tail.split()
        if len(rest) < 3:
            raise NotCovered("unexpected stylus fields")
        touch.append((int(rest[0]), int(rest[1]), int(rest[2])))
    symbols = np.frombuffer(bytes(field), dtype="u1").reshape(n, 13)
    buttons = ((symbols != 0x20) & (symbols != 0x2E)).astype("u1")
    touch = np.array(touch, dtype="i8")
    command = np.array(command, dtype="i8")
    players = [{name: buttons[:, j] for j, name in enumerate(DSM_BUTTONS)}]
    numeric = [{"touch_x": touch[:, 0], "touch_y": touch[:, 1],
                "touch_pressed": touch[:, 2]}]
    flags = {
        "microphone": _bit(command, 1),
        "reset": _bit(command, 2),
        "lid": _bit(command, 4),
    }
    return {"n": n, "declared": None, "players": players, "numeric": numeric,
            "flags": flags}


# BKM -- legacy BizHawk text movies.
# BizHawk 1.13.2, BizHawk.Client.Common/movie/bkm/BkmMnemonicConstants.cs and
# BkmControllerAdapter.cs (SetControllersAsMnemonic and its per-system
# variants). A position is pressed when its character is not ".".
# Each entry: first button column, buttons in stored order, controller count,
# and the number of columns per controller including its separator.
_PAD4 = ["Up", "Down", "Left", "Right"]
BKM_LAYOUTS = {
    "NES": (3, _PAD4 + ["Select", "Start", "B", "A"], 4, 9),
    "SNES": (3, _PAD4 + ["Select", "Start", "B", "A", "X", "Y", "L", "R"], 4, 13),
    "GB": (3, _PAD4 + ["Select", "Start", "B", "A"], 1, 9),
    "GEN": (3, _PAD4 + ["A", "B", "C", "Start", "X", "Y", "Z", "Mode"], 2, 13),
    "SMS": (1, _PAD4 + ["B1", "B2"], 2, 7),
    "PCE": (3, _PAD4 + ["Select", "Run", "B2", "B1"], 5, 9),
    "A26": (4, _PAD4 + ["Button"], 2, 6),
    "A78": (6, _PAD4 + ["Trigger", "Trigger 2"], 2, 7),
    "Coleco": (1, _PAD4 + ["L", "R", "Key1", "Key2", "Key3", "Key4", "Key5",
                           "Key6", "Key7", "Key8", "Key9", "Star", "Key0",
                           "Pound"], 2, 19),
    "N64": (3, ["DPad U", "DPad D", "DPad L", "DPad R", "B", "A", "Z", "Start",
                "L", "R", "C Up", "C Down", "C Left", "C Right"], 4, 24),
    "Saturn": (3, _PAD4 + ["Start", "X", "Y", "Z", "A", "B", "C", "L", "R"], 2, 14),
}
BKM_PLATFORMS = {"GBC": "GB", "Genesis": "GEN", "GG": "SMS", "SG": "SMS",
                 "A2600": "A26"}
# The character in column 1 selects one console command on these systems:
# "P" is Power; any other character outside the listed ones is Reset.
BKM_POWER_OR_RESET = {"SNES": ".0", "GEN": ".0", "N64": ".0", "Saturn": ".0"}
BKM_NES_COMMANDS = {"P": "Power", "E": "FDS Eject", "0": "FDS Insert 0",
                    "1": "FDS Insert 1", "2": "FDS Insert 2",
                    "3": "FDS Insert 3", "c": "VS Coin 1", "C": "VS Coin 2"}


def _bkm_system(platform, text, pressed, limit, stride, start):
    """Console commands of a BKM line, named as BizHawk names them."""
    def marks(column, characters):
        return np.isin(text[:, column], list(characters.encode())).astype("u1")

    system = {}
    if platform in BKM_POWER_OR_RESET:
        system["Power"] = marks(1, "P")
        system["Reset"] = 1 - marks(1, "P" + BKM_POWER_OR_RESET[platform])
    elif platform == "NES":
        for mark, name in BKM_NES_COMMANDS.items():
            system[name] = marks(1, mark)
        system["Reset"] = 1 - marks(1, "." + "".join(BKM_NES_COMMANDS))
    elif platform == "GB":
        system["Power"] = 1 - marks(1, ".")
    elif platform == "A26":
        system["Reset"] = 1 - marks(1, ".0")
        system["Select"] = 1 - marks(2, ".0")
    elif platform == "A78":
        for column, name, mark in [(1, "Power", "P"), (2, "Reset", "r"),
                                   (3, "Select", "s"), (4, "Pause", "p")]:
            system[name] = marks(column, mark)
    elif platform == "SMS":
        base = limit * stride + start
        system["Pause"], system["Reset"] = pressed[:, base], pressed[:, base + 1]
    return system


def decode_bkm(path):
    data = Path(path).read_bytes()
    header, lines = {}, []
    for raw in data.split(b"\n"):
        line = raw.rstrip(b"\r")
        if line.startswith(b"|"):
            lines.append(line)
        elif not lines and b" " in line:
            key, value = line.split(b" ", 1)
            header[key.decode("latin1")] = value.decode("latin1")
    if not lines:
        raise NotCovered("no input log")
    platform = header.get("Platform", "")
    platform = BKM_PLATFORMS.get(platform, platform)
    if platform not in BKM_LAYOUTS:
        raise NotCovered("platform " + platform)
    start, names, limit, stride = BKM_LAYOUTS[platform]
    n = len(lines)
    longest = max(len(line) for line in lines)
    # A short line leaves the remaining controls unset.
    text = np.frombuffer(b"".join(line.ljust(longest, b".") for line in lines),
                         dtype="u1").reshape(n, longest)
    pressed = (text != 0x2E).astype("u1")
    players, numeric = [], []
    for player in range(limit):
        first = player * stride + start
        if longest < first + len(names) - 1:
            break
        players.append({name: pressed[:, first + j] for j, name in enumerate(names)})
        axes = {}
        if platform == "N64":
            for k, axis in enumerate(["X Axis", "Y Axis"]):
                at = first + len(names) + 5 * k
                digits = text[:, at:at + 4].copy().view("S4")[:, 0]
                axes[axis] = np.array([int(v) for v in digits], dtype="i8")
        numeric.append(axes)
    return {"n": n, "declared": None, "players": players, "numeric": numeric,
            "flags": {}, "platform": platform,
            "system": _bkm_system(platform, text, pressed, limit, stride, start)}


# LTM -- libTAS.
# https://clementgallet.github.io/libTAS/guides/format/ (retrieved 12 October
# 2026) and libTAS src/program/movie/InputSerialization.cpp (readFrame and
# the per-section readers) at revision 32245db8e35ab8f2389bdb781e81ab5e5b92c4db.
# A frame is a line starting with a pipe. Tagged sections K, M, C<n>, F, T and
# D may appear in any order; a line without tags uses the positional layout
# of libTAS 1.3.5 and earlier: keyboard, mouse if supported, each controller,
# flags, frame rate.
LTM_BUTTONS = ["A", "B", "X", "Y", "Back", "Guide", "Start", "LeftStick",
               "RightStick", "LeftShoulder", "RightShoulder", "DpadUp",
               "DpadDown", "DpadLeft", "DpadRight"]
LTM_AXES = ["left_x", "left_y", "right_x", "right_y", "trigger_left",
            "trigger_right"]
_LTM_INT = re.compile(r"\s*([+-]?\d+)")
_LTM_HEX = re.compile(r"\s*(?:0[xX])?([0-9a-fA-F]+)")


class _Stream:
    """The subset of C++ stream extraction that the libTAS reader relies on."""

    def __init__(self, text):
        self.text, self.pos = text, 0

    def peek(self):
        return self.text[self.pos] if self.pos < len(self.text) else ""

    def char(self):
        while self.pos < len(self.text) and self.text[self.pos].isspace():
            self.pos += 1
        if self.pos >= len(self.text):
            return ""
        self.pos += 1
        return self.text[self.pos - 1]

    def number(self, pattern, base):
        match = pattern.match(self.text, self.pos)
        if match is None:
            self.pos = len(self.text)
            return None
        self.pos = match.end()
        return int(match.group(1), base)


def _ltm_keyboard(stream, frame):
    if stream.peek() == "|":
        stream.pos += 1
        return
    for _ in range(16):
        key = stream.number(_LTM_HEX, 16)
        if key is None:
            return
        if key:
            frame["keys"].add(key)
        mark = stream.char()
        if mark != ":":
            return


def _ltm_mouse(stream, frame):
    mouse = {"x": 0, "y": 0, "mode": 0, "mask": [0] * 5, "wheel": 0}
    frame["mouse"] = mouse
    mouse["x"] = stream.number(_LTM_INT, 10) or 0
    if stream.char() != ":":
        return
    mouse["y"] = stream.number(_LTM_INT, 10) or 0
    if stream.char() != ":":
        return
    mark = stream.char()
    if mark in ("R", "A"):
        mouse["mode"] = 1 if mark == "R" else 0
        stream.char()
        mark = stream.char()
    for button in range(5):
        mouse["mask"][button] = int(mark not in (".", ""))
        mark = stream.char()
    if mark == ":":
        mouse["wheel"] = stream.number(_LTM_INT, 10) or 0
        stream.char()


def _ltm_controller(stream, frame, joy):
    pad = frame["controllers"].setdefault(joy, {"axes": [0] * 6, "buttons": [0] * 15})
    for axis in range(6):
        value = stream.number(_LTM_INT, 10)
        pad["axes"][axis] = value or 0
        if stream.char() != ":":
            return
    for button in range(15):
        if stream.char() not in (".", ""):
            pad["buttons"][button] = 1
    stream.char()


def _ltm_flags(stream, frame):
    mark = stream.char()
    while mark not in ("|", ""):
        frame["flags"] += mark
        mark = stream.char()


def _ltm_pair(stream, frame, field):
    first = stream.number(_LTM_INT, 10)
    stream.char()
    second = stream.number(_LTM_INT, 10)
    stream.char()
    if first is not None and second is not None:
        frame[field] = (first, second)


def _ltm_frame(line, mouse_support, controllers):
    frame = {"keys": set(), "mouse": None, "controllers": {}, "flags": "",
             "framerate": None, "realtime": None}
    stream = _Stream(line)
    stream.pos = 1
    while stream.peek():
        tag = stream.peek()
        if tag == "E":
            raise NotCovered("ordered event frames")
        if tag == "K":
            stream.pos += 1
            _ltm_keyboard(stream, frame)
        elif tag == "M":
            stream.pos += 1
            _ltm_mouse(stream, frame)
        elif tag == "C":
            stream.pos += 1
            _ltm_controller(stream, frame, ord(stream.char()) - ord("1"))
        elif tag == "F":
            stream.pos += 1
            _ltm_flags(stream, frame)
        elif tag in ("T", "D"):
            stream.pos += 1
            _ltm_pair(stream, frame, "framerate" if tag == "T" else "realtime")
        else:
            _ltm_keyboard(stream, frame)
            if mouse_support:
                _ltm_mouse(stream, frame)
            for joy in range(controllers):
                _ltm_controller(stream, frame, joy)
            _ltm_flags(stream, frame)
            _ltm_pair(stream, frame, "framerate")
    return frame


def decode_ltm(path):
    with tarfile.open(path, "r:*") as archive:
        config = archive.extractfile("config.ini").read().decode("utf-8", "replace")
        log = archive.extractfile("inputs").read().decode("latin1")

    def setting(name, default):
        found = re.search(r"^" + name + r"=(.*)$", config, re.M)
        return found.group(1).strip() if found else default

    mouse_support = setting("mouse_support", "false") == "true"
    controllers = int(setting("nb_controllers", "0"))
    lines = [line.rstrip() for line in log.split("\n") if line.startswith("|")]
    frames = [_ltm_frame(line, mouse_support, controllers) for line in lines]
    n = len(frames)
    keys = sorted(set().union(*(f["keys"] for f in frames))) if frames else []
    index = {key: j for j, key in enumerate(keys)}
    held = np.zeros((n, len(keys)), dtype="u1")
    mouse = np.zeros((n, 9), dtype="i8")
    count = max(1, controllers)
    axes = np.zeros((n, count, 6), dtype="i8")
    buttons = np.zeros((n, count, 15), dtype="u1")
    for i, frame in enumerate(frames):
        for key in frame["keys"]:
            held[i, index[key]] = 1
        if frame["mouse"] is not None:
            m = frame["mouse"]
            mouse[i] = [m["x"], m["y"], m["wheel"], m["mode"]] + m["mask"]
        for joy, pad in frame["controllers"].items():
            if 0 <= joy < count:
                axes[i, joy] = pad["axes"]
                buttons[i, joy] = pad["buttons"]
    players, numeric = [], []
    for joy in range(count):
        states = {name: buttons[:, joy, j] for j, name in enumerate(LTM_BUTTONS)}
        channels = {name: axes[:, joy, j] for j, name in enumerate(LTM_AXES)}
        if joy == 0:
            states.update({"keysym_%x" % key: held[:, index[key]] for key in keys})
            states.update({"Mouse%d" % (b + 1): mouse[:, 4 + b].astype("u1")
                           for b in range(5)})
            channels.update({"mouse_x": mouse[:, 0], "mouse_y": mouse[:, 1],
                             "mouse_wheel": mouse[:, 2], "mouse_mode": mouse[:, 3]})
        players.append(states)
        numeric.append(channels)
    # A frame without its own rate uses the rate of the configuration.
    default = (int(setting("framerate_num", "60")), int(setting("framerate_den", "1")))
    rate = np.array([f["framerate"] or default for f in frames], dtype="i8").reshape(n, 2)
    clock = np.array([f["realtime"] or (0, 0) for f in frames], dtype="i8").reshape(n, 2)
    timing = {"framerate_num": rate[:, 0], "framerate_den": rate[:, 1],
              "realtime_sec": clock[:, 0], "realtime_nsec": clock[:, 1],
              "duration_seconds": rate[:, 1] / rate[:, 0]}
    return {"n": n, "declared": int(setting("frame_count", "0")), "players": players,
            "numeric": numeric, "flags": {}, "mouse_support": mouse_support,
            "controllers": controllers, "timing": timing,
            "flag_text": [f["flags"] for f in frames]}


# FMV -- Famtasia.
# https://tasvideos.org/EmulatorResources/Famtasia/FMV (retrieved 12 October 2026)
FMV_BUTTONS = [("Right", 0x01), ("Left", 0x02), ("Up", 0x04), ("Down", 0x08),
               ("B", 0x10), ("A", 0x20), ("Select", 0x40), ("Start", 0x80)]


def decode_fmv(path):
    data = Path(path).read_bytes()
    if data[:4] != b"FMV\x1a":
        raise NotCovered("no FMV signature")
    pads = [bool(data[5] & 0x80), bool(data[5] & 0x40)]
    disk = bool(data[5] & 0x20)
    width = sum(pads) + disk
    if not width:
        raise NotCovered("no controller in use")
    n = (len(data) - 144) // width
    frames = np.frombuffer(data, dtype="u1", count=n * width, offset=144).reshape(n, width)
    players = [{name: _bit(frames[:, column], mask) for name, mask in FMV_BUTTONS}
               for column in range(sum(pads))]
    flags = {"disk": frames[:, width - 1].astype("i8")} if disk else {}
    return {"n": n, "declared": None, "players": players,
            "numeric": [{} for _ in players], "flags": flags,
            "ports": [i + 1 for i, used in enumerate(pads) if used]}


# GMV -- Gens.
# https://tasvideos.org/EmulatorResources/Gens/GMV (retrieved 12 October 2026)
# A set bit means the button is NOT pressed.
GMV_BUTTONS = [("Up", 0x01), ("Down", 0x02), ("Left", 0x04), ("Right", 0x08),
               ("A", 0x10), ("B", 0x20), ("C", 0x40), ("Start", 0x80)]
GMV_EXTRA = ["X", "Y", "Z", "Mode"]


def decode_gmv(path):
    data = Path(path).read_bytes()
    if data[:15] != b"Gens Movie TEST":
        raise NotCovered("no GMV signature")
    # The flags byte is defined from format version A on.
    three = data[15:16] >= b"A" and bool(data[0x16] & 0x20)
    n = (len(data) - 64) // 3
    frames = np.frombuffer(data, dtype="u1", count=n * 3, offset=64).reshape(n, 3)
    held = 255 - frames
    players = [{name: _bit(held[:, pad], mask) for name, mask in GMV_BUTTONS}
               for pad in range(3 if three else 2)]
    # Gens reads the pad types from format version 9 on (Gens-rr movie.cpp,
    # GetMovieInfo, revision 53601d3b2c601c367aacb6355fa1c0282174cf1e).
    types = data[0x14:0x16].decode("latin1") if data[15:16] >= b"9" else "??"
    # Extra-button bits recorded for a pad declared as three-button.
    outside = np.zeros(n, dtype="i8")
    if not three:
        for pad in range(2):
            for j, name in enumerate(GMV_EXTRA):
                values = _bit(held[:, 2], 1 << (4 * pad + j))
                if types[pad] == "3":
                    outside |= values.astype("i8") << (4 * pad + j)
                else:
                    players[pad][name] = values
    return {"n": n, "declared": None, "players": players,
            "numeric": [{} for _ in players], "flags": {"outside": outside},
            "pad_types": types, "three": three}


# SMV -- Snes9x.
# https://tasvideos.org/EmulatorResources/Snes9x/SMV (retrieved 12 October 2026)
# Versions 1 (1.43), 4 (1.51) and 5 (1.52). Each sample holds one
# little-endian word per controller in use, then any peripheral bytes.
SMV_BUTTONS = [("R", 0x0010), ("L", 0x0020), ("X", 0x0040), ("A", 0x0080),
               ("Right", 0x0100), ("Left", 0x0200), ("Down", 0x0400),
               ("Up", 0x0800), ("Start", 0x1000), ("Select", 0x2000),
               ("Y", 0x4000), ("B", 0x8000)]
SMV_PERIPHERAL_BYTES = {2: 5, 3: 6, 4: 11}  # mouse, Super Scope, Justifier


def decode_smv(path):
    data = Path(path).read_bytes()
    if data[:4] != b"SMV\x1a":
        raise NotCovered("no SMV signature")
    version = struct.unpack_from("<I", data, 4)[0]
    if version not in (1, 4, 5):
        raise NotCovered("version %d" % version)
    frames = struct.unpack_from("<I", data, 0x10)[0]
    limit = 5 if version == 1 else 8
    pads = [i for i in range(limit) if data[0x14] & (1 << i)]
    offset = struct.unpack_from("<I", data, 0x1C)[0]
    extra, declared = 0, frames + 1
    if version != 1:
        extra = sum(SMV_PERIPHERAL_BYTES.get(kind, 0) for kind in data[0x24:0x26])
        # Snes9x raises the sample count to the frame count and reads one
        # sample more (movie.cpp, read_movie_header and S9xMovieOpen, at
        # revision 1bcc369e89f08243e0a462882fb1f3e42e51de3a).
        declared = max(frames, struct.unpack_from("<I", data, 0x20)[0]) + 1
    if not pads:
        raise NotCovered("no controller in use")
    size = 2 * len(pads) + extra
    n = (len(data) - offset) // size
    block = np.frombuffer(data, dtype="u1", count=n * size, offset=offset).reshape(n, size)
    words = block[:, :2 * len(pads)].copy().view("<u2")
    # In the reset-recording patch FF FF for every controller denotes a reset.
    reset = (words == 0xFFFF).all(axis=1)
    players = []
    for column in range(len(pads)):
        states = {name: _bit(words[:, column], mask) for name, mask in SMV_BUTTONS}
        for values in states.values():
            values[reset] = 0
        players.append(states)
    return {"n": n, "declared": declared, "players": players,
            "numeric": [{} for _ in players],
            "flags": {"reset": reset.astype("u1")}, "version": version,
            "peripheral_bytes": extra}


# M64 -- Mupen64.
# https://tasvideos.org/EmulatorResources/Mupen/M64 (retrieved 12 October 2026)
# Four bytes per input sample: two button bytes, then signed X and Y.
M64_BUTTONS = [
    ("DPad Right", 0, 0x01), ("DPad Left", 0, 0x02), ("DPad Down", 0, 0x04),
    ("DPad Up", 0, 0x08), ("Start", 0, 0x10), ("Z", 0, 0x20), ("B", 0, 0x40),
    ("A", 0, 0x80), ("C Right", 1, 0x01), ("C Left", 1, 0x02),
    ("C Down", 1, 0x04), ("C Up", 1, 0x08), ("R", 1, 0x10), ("L", 1, 0x20)]


def decode_m64(path):
    data = Path(path).read_bytes()
    if data[:4] != b"M64\x1a":
        raise NotCovered("no M64 signature")
    version = struct.unpack_from("<I", data, 4)[0]
    offset = 0x400 if version == 3 else 0x200
    declared = struct.unpack_from("<I", data, 0x18)[0]
    n = (len(data) - offset) // 4
    samples = np.frombuffer(data, dtype="u1", count=n * 4, offset=offset).reshape(n, 4)
    states = {name: _bit(samples[:, byte], mask) for name, byte, mask in M64_BUTTONS}
    axes = samples[:, 2:4].copy().view("i1").astype("i8")
    flags = {"reserved": ((samples[:, 1] & 0xC0) != 0).astype("u1")}
    return {"n": n, "declared": declared, "players": [states],
            "numeric": [{"X": axes[:, 0], "Y": axes[:, 1]}], "flags": flags,
            "controllers": [i + 1 for i in range(4)
                            if struct.unpack_from("<I", data, 0x20)[0] & (1 << i)]}


# FCM -- FCE Ultra.
# https://tasvideos.org/EmulatorResources/FCEU/FCM (retrieved 12 October 2026)
# and FCEUX src/oldmovie.cpp (convert_fcm, _addjoy) at revision
# ce042d758a08f9434a6625580b2cc72495e8aa9a, whose stepping this follows.
FCM_BUTTONS = ["A", "B", "Select", "Start", "Up", "Down", "Left", "Right"]


def decode_fcm(path):
    data = Path(path).read_bytes()
    if data[:4] != b"FCM\x1a":
        raise NotCovered("no FCM signature")
    # Versions 1 and 2 share the first 32 header bytes and the controller data.
    if struct.unpack_from("<I", data, 4)[0] not in (1, 2):
        raise NotCovered("FCM version other than 1 or 2")
    flags = data[8]
    n, _, size, _, first = struct.unpack_from("<5I", data, 0x0C)
    stream = data[first:first + size]
    pads = np.zeros((n, 4), dtype="u1")
    command = np.zeros(n, dtype="u1")
    # One bit per control code applied in a frame: bit (code - 1).
    controls = np.zeros(n, dtype="i8")
    state = [0, 0, 0, 0]
    pos, wait, due, pending = 0, 0, 0, -1
    # The first frame of a movie that starts from reset carries the reset.
    if n and (flags & 0x02) and not (flags & 0x08):
        command[0] = 1
    frame = 0
    while frame < n:
        ended = False
        while due == wait or pending == -1:
            if pending != -1:
                if pending & 0x80:
                    if pending & 0x1F == 1:
                        command[frame] = 1      # reset
                    elif pending & 0x1F == 2:
                        command[frame] = 2      # power
                    if pending & 0x1F:
                        controls[frame] |= 1 << ((pending & 0x1F) - 1)
                else:
                    state[(pending >> 3) & 3] ^= 1 << (pending & 7)
            if pos >= len(stream):
                ended = True
                break
            update = stream[pos]
            pos += 1
            count = (update >> 5) & 3
            due = int.from_bytes(stream[pos:pos + count], "little")
            pos += count
            # Movies recorded before FCEU 0.98.11 can hold one more delta byte.
            if count in (1, 2) and due == 0 and pos < len(stream):
                due = stream[pos] << (8 * count)
                pos += 1
            if pending != -1:
                wait = 0
            pending = update
        if ended:
            # FCEUX re-applies the last update on every frame past the data.
            pads[frame] = state
            frame += 1
            continue
        # Hold the current state until the next update falls due.
        run = min(n - frame, due - wait if due > wait else n - frame)
        pads[frame:frame + run] = state
        frame += run
        wait += run
    players = [{name: _bit(pads[:, pad], 1 << bit) for bit, name in enumerate(FCM_BUTTONS)}
               for pad in range(4)]
    # "command" is what FCEUX's converter writes to FM2 (reset or power only);
    # "controls" keeps every control code of the frame.
    return {"n": n, "declared": n, "players": players,
            "numeric": [{} for _ in players],
            "flags": {"command": command, "controls": controls}}


# FM2 -- FCEUX.
# https://fceux.com/web/FM2.html (retrieved 12 October 2026) and FCEUX
# src/movie.cpp (LoadFM2, MovieRecord::parse, parseJoy, parseBinary) at
# revision ce042d758a08f9434a6625580b2cc72495e8aa9a. A record starts at a
# pipe; a gamepad field is eight characters in the order RLDUTSBA, each set
# unless it is "." or a space.
FM2_BUTTONS = ["Right", "Left", "Down", "Up", "Start", "Select", "B", "A"]
_FM2_NUMBER = re.compile(rb"\D*(\d+)")
_FM2_ROW = re.compile(rb"[ \t\r\n]*\|")
_FM2_ZAPPER = ["x", "y", "button", "bogo", "hit"]


def _fm2_record(text, pos, fourscore, ports):
    """Read one text record after its first pipe; return fields and end."""
    found = _FM2_NUMBER.match(text, pos)
    if found is None:
        return None
    command, pos = int(found.group(1)), found.end() + 1
    spans, zappers = [], []
    for port in ([1, 1, 1, 1] if fourscore else ports):
        if port == 1:
            spans.append((pos, pos + 8))
            pos += 8
        elif port == 2:
            values = []
            for _ in range(5):
                found = _FM2_NUMBER.match(text, pos)
                if found is None:
                    return None
                values.append(int(found.group(1)))
                pos = found.end()
            zappers.append(values)
        pos += 1
    return command, spans, zappers, pos + 1


def decode_fm2(path):
    data = Path(path).read_bytes()
    if data[:9] != b"version 3":
        raise NotCovered("no FM2 version line")
    start = re.search(rb"^[ \t]*\|", data, re.M)
    head = data[:start.start()] if start else data
    keys = {}
    for line in head.splitlines():
        parts = line.split(None, 1)
        if parts:
            keys[parts[0]] = parts[1].strip() if len(parts) > 1 else b""
    fourscore = keys.get(b"fourscore", b"0") == b"1"
    ports = [int(keys.get(b"port0", b"1")), int(keys.get(b"port1", b"1"))]
    pads = 4 if fourscore else ports.count(1)
    limit = int(keys.get(b"length", b"-1"))
    zapper_ports = [] if fourscore else [i for i, port in enumerate(ports) if port == 2]
    command, held, zapped = [], [], []
    if start is None:
        pass
    elif keys.get(b"binary", b"0") == b"1":
        body = data[start.end():]
        size = 1 + (4 if fourscore else sum({1: 1, 2: 12}.get(p, 0) for p in ports))
        count = len(body) // size
        if 0 <= limit < count:
            count = limit
        block = np.frombuffer(body, dtype="u1", count=count * size).reshape(count, size)
        command = block[:, 0].astype("i8")
        columns, at = [], 1
        for port in ([1, 1, 1, 1] if fourscore else ports):
            if port == 1:
                columns.append(at)
            elif port == 2:
                # x, y, buttons and counter as bytes, then 64-bit hit ticks.
                ticks = block[:, at + 4:at + 12].copy().view("<u8")[:, 0]
                zapped.append(np.column_stack(
                    [block[:, at:at + 4].astype("f8"), ticks.astype("f8")]))
            at += {1: 1, 2: 12}.get(port, 0)
        # bit 0 is A and bit 7 is Right; the text order is the reverse.
        states = np.stack([(block[:, columns] >> (7 - j)) & 1 for j in range(8)], axis=2)
        values = np.stack(zapped, axis=1) if zapped else []
        return _fm2_result(command, states.astype("u1"), values, fourscore, ports, limit)
    else:
        pos = start.start()
        while True:
            found = _FM2_ROW.match(data, pos)
            if found is None:
                # A key line between records: continue at the next line.
                following = data.find(b"\n", pos)
                if following < 0 or not data[pos:].strip():
                    break
                pos = following + 1
                continue
            record = _fm2_record(data, found.end(), fourscore, ports)
            if record is None:
                break
            value, spans, zappers, pos = record
            command.append(value)
            held.append(b"".join(data[a:b].ljust(8, b".") for a, b in spans))
            zapped.append(zappers)
            if 0 <= limit == len(command):
                break
    n = len(command)
    symbols = np.frombuffer(b"".join(held), dtype="u1").reshape(n, pads * 8)
    states = ((symbols != 0x2E) & (symbols != 0x20)).astype("u1").reshape(n, pads, 8)
    values = (np.array(zapped, dtype="f8").reshape(n, len(zapper_ports), 5)
              if zapper_ports else [])
    return _fm2_result(np.array(command, dtype="i8"), states, values, fourscore,
                       ports, limit)


def _fm2_result(command, states, zapped, fourscore, ports, limit):
    """One controller for every port in use, in port order.

    A Zapper logs its position, the mouse buttons (bit 0 is the trigger and
    bit 1 a shot aimed off the screen, input/zapper.cpp), a trigger counter
    and the tick count of the last light detection.
    """
    n = len(command)
    players, numeric, pad, gun = [], [], 0, 0
    for port in ([1, 1, 1, 1] if fourscore else ports):
        if port == 1:
            players.append({name: states[:, pad, j]
                            for j, name in enumerate(FM2_BUTTONS)})
            numeric.append({})
            pad += 1
        elif port == 2:
            held = zapped[:, gun, 2].astype("i8")
            players.append({"Trigger": (held & 1).astype("u1"),
                            "Offscreen": ((held >> 1) & 1).astype("u1")})
            numeric.append({name: zapped[:, gun, j]
                            for j, name in enumerate(_FM2_ZAPPER)})
            gun += 1
    return {"n": n, "declared": limit if limit >= 0 else None, "players": players,
            "numeric": numeric, "flags": {"command": command}}


# PXM -- PCSX-rr, and PJM -- PSXjin.
# https://tasvideos.org/EmulatorResources/PCSX/PXM and .../PSXjin/PJM
# (retrieved 12 October 2026); PSXjin psxjin/movie.cpp (SetBytesPerFrame,
# MOV_ReadJoy, MOV_ReadControl) at revision
# 534fd3856913c3198e649806a91db5c232e4d34a for the text layout and multitaps.
PSX_BUTTONS = [("Select", 0x0001), ("L3", 0x0002), ("R3", 0x0004),
               ("Start", 0x0008), ("Up", 0x0010), ("Right", 0x0020),
               ("Down", 0x0040), ("Left", 0x0080), ("L2", 0x0100),
               ("R2", 0x0200), ("L1", 0x0400), ("R1", 0x0800),
               ("Triangle", 0x1000), ("Circle", 0x2000), ("Cross", 0x4000),
               ("Square", 0x8000)]
PSX_AXES = ["left_x", "left_y", "right_x", "right_y"]
# Controller types: 1 mouse, 4 standard, 5 analogue joystick, 7 analogue pad.
_PSX_BINARY = {1: 4, 4: 2, 5: 6, 7: 6}
_PSX_TEXT = {1: 12, 4: 15, 5: 33, 7: 33}


_ATOI = re.compile(rb"\s*([+-]?\d+)")


def _atoi(text):
    """The leading integer of a field, as C's atoi reads it."""
    found = _ATOI.match(text)
    return int(found.group(1)) if found else 0


def _psx_pads(words, axes):
    players, numeric = [], []
    for pad, word in enumerate(words):
        # The format description leaves bits 1 and 2 undefined for the
        # standard pad; they are the stick buttons of the analogue pads.
        players.append({name: _bit(word, mask) for name, mask in PSX_BUTTONS
                        if axes[pad] is not None or name not in ("L3", "R3")})
        numeric.append({} if axes[pad] is None else
                       {name: axes[pad][:, j] for j, name in enumerate(PSX_AXES)})
    return players, numeric


def _decode_psx(path, magic):
    data = Path(path).read_bytes()
    if data[:4] != magic:
        raise NotCovered("no %s signature" % magic.decode().strip())
    flags = struct.unpack_from("<H", data, 0x0C)[0]
    text = magic == b"PJM " and bool(flags & 0x40)
    taps = [bool(flags & 0x80), bool(flags & 0x100)] if magic == b"PJM " else [False, False]
    types = []
    for port in range(2):
        types += [data[0x0E + port]] * (4 if taps[port] else 1)
    declared = struct.unpack_from("<I", data, 0x10)[0]
    offset = struct.unpack_from("<I", data, 0x2C)[0]
    sizes = _PSX_TEXT if text else _PSX_BINARY
    if any(kind == 1 for kind in types):
        raise NotCovered("mouse controller")
    # An unsupported or absent pad takes one text byte and no binary byte.
    widths = [sizes.get(kind, 1 if text else 0) for kind in types]
    stride = sum(widths) + (4 if text else 1)
    # A text file can end without the line break of its last record; the
    # record's fields are complete, so it counts.
    missing = -(len(data) - offset) % stride
    if text and 0 < missing <= 2:
        data += b"\r\n"[-missing:]
    n = (len(data) - offset) // stride
    block = np.frombuffer(data, dtype="u1", count=n * stride, offset=offset).reshape(n, stride)
    words, axes, at = [], [], 0
    for kind, width in zip(types, widths):
        field = block[:, at:at + width]
        at += width
        if kind not in sizes:
            continue
        if not text:
            words.append(field[:, 0].astype("u2") | (field[:, 1].astype("u2") << 8))
            axes.append(field[:, 2:6].astype("i8") if width == 6 else None)
        elif width == 15:
            # Thirteen characters fill bits 15 to 3; the fourteenth is bit 0.
            held = (field[:, :14] != 0x2E).astype("u2")
            word = np.zeros(n, dtype="u2")
            for j in range(13):
                word |= held[:, j] << (15 - j)
            words.append(word | held[:, 13])
            axes.append(None)
        else:
            held = (field[:, :16] != 0x2E).astype("u2")
            word = np.zeros(n, dtype="u2")
            for j in range(16):
                word |= held[:, j] << (15 - j)
            words.append(word)
            digits = field[:, 16:32].copy().view("S4")
            axes.append(np.array([[_atoi(v) for v in row] for row in digits], dtype="i8"))
    if text:
        digits = block[:, at:at + 4].copy().view("S4")[:, 0]
        control = np.array([_atoi(v) for v in digits], dtype="i8")
    else:
        control = block[:, at].astype("i8")
    players, numeric = _psx_pads(words, axes)
    return {"n": n, "declared": declared, "players": players, "numeric": numeric,
            "flags": {"control": control}, "text": text, "types": types}


def decode_pxm(path):
    return _decode_psx(path, b"PXM ")


def decode_pjm(path):
    return _decode_psx(path, b"PJM ")


# LSMV -- lsnes.
# https://tasvideos.org/EmulatorResources/Lsnes/LSMV (retrieved 12 October
# 2026) for the archive members, and lsnes at revision
# 7d9b3e93ecd478c68726e276a08f38880ca00c84 for the input rows:
# include/library/portctrl-data.hpp (read_button_value, frame::deserialize),
# src/library/portctrl-data.cpp (read_axis_value), src/library/
# portctrl-parse.cpp (get_ser_instructions, type_generic::_deserialize),
# src/core/moviefile-text-load.cpp (read_input), and the port schemas and
# settings of src/emulation/bsnes-legacy/{ports.json,core.cpp} and
# src/emulation/gambatte/ports.json. The Super Game Boy core is described by
# controllerjson.hpp and core-freestanding.cpp at revision
# bb5cd617cb396d11415de7a4af6ab170a7d84136.
#
# A row holds one field group per port. A controller stores its buttons, one
# character each, and then its axes as decimal numbers. Controllers of one
# port are separated by a pipe, and so are ports.
_LSMV_PAD = ["B", "Y", "select", "start", "up", "down", "left", "right",
             "A", "X", "L", "R"]
LSMV_CONTROLLERS = {
    "gamepad": (_LSMV_PAD, []),
    "gamepad16": (_LSMV_PAD + ["ext0", "ext1", "ext2", "ext3"], []),
    "justifier": (["trigger", "start"], ["xaxis", "yaxis"]),
    "mouse": (["L", "R"], ["xmotion", "ymotion"]),
    "superscope": (["trigger", "cursor", "turbo", "pause"], ["xaxis", "yaxis"]),
    "gb": (["A", "B", "select", "start", "right", "left", "up", "down"], []),
    "system": (["framesync", "reset"], ["rhigh", "rlow"]),
    "system_hreset": (["framesync", "reset", "hard"], ["rhigh", "rlow"]),
    "system_compact": (["framesync", "reset", "hard"], []),
    "system_gb": (["framesync", "reset"], []),
}
LSMV_PORTS = {
    "none": [], "gamepad": ["gamepad"], "gamepad16": ["gamepad16"],
    "ygamepad16": ["gamepad16"] * 2, "justifier": ["justifier"],
    "justifiers": ["justifier"] * 2, "mouse": ["mouse"],
    "multitap": ["gamepad"] * 4, "multitap16": ["gamepad16"] * 4,
    "superscope": ["superscope"],
}
_LSMV_BSNES = {"snes_ntsc", "snes_pal", "bsx", "bsxslotted", "sufamiturbo",
               "sgb_ntsc", "sgb_pal"}
_LSMV_GAMBATTE = {"gdmg", "ggbc", "ggbca"}
_LSMV_END = frozenset(b"|\r\n\x00")
_LSMV_UNSET = frozenset(b". \t")


def _lsmv_ports(gametype, settings):
    """Controller names of every port; port 0 is the system port."""
    if gametype in _LSMV_GAMBATTE:
        return [["system_gb", "gb"]]
    if gametype == "gambatte_sgb_ntsc":
        system = "system_hreset"
    elif gametype not in _LSMV_BSNES:
        raise NotCovered("system type " + gametype)
    elif settings.get("compact", "0") == "1":
        system = "system_compact"
    elif settings.get("hardreset", "0") == "1":
        system = "system_hreset"
    else:
        system = "system"
    ports = [[system]]
    for name, default in (("port1", "gamepad"), ("port2", "none")):
        kind = settings.get(name, default)
        if kind not in LSMV_PORTS:
            raise NotCovered("port type " + kind)
        ports.append(LSMV_PORTS[kind])
    return ports


def _lsmv_row(line, ports):
    """Read one row as lsnes does: every button and axis value in order."""
    values, pos, end = [], 0, len(line)
    for controllers in ports:
        if not controllers:
            continue
        for index, name in enumerate(controllers):
            buttons, axes = LSMV_CONTROLLERS[name]
            if index:
                while pos < end and line[pos] not in _LSMV_END:
                    pos += 1
                if pos < end and line[pos] == 0x7C:
                    pos += 1
            for _ in buttons:
                if pos < end and line[pos] not in _LSMV_END:
                    values.append(int(line[pos] not in _LSMV_UNSET))
                    pos += 1
                else:
                    values.append(0)
            for _ in axes:
                while pos < end and line[pos] in (0x20, 0x09):
                    pos += 1
                number = 0
                if pos < end and line[pos] not in _LSMV_END:
                    negative = line[pos] == 0x2D
                    if line[pos] in (0x2D, 0x2B):
                        pos += 1
                    while pos < end and 0x30 <= line[pos] <= 0x39:
                        number = number * 10 + line[pos] - 0x30
                        pos += 1
                    if negative:
                        number = -number
                # The value is stored as a signed 16-bit number.
                values.append((number + 32768) % 65536 - 32768)
        while pos < end and line[pos] not in _LSMV_END:
            pos += 1
        if pos < end and line[pos] == 0x7C:
            pos += 1
    return values


def decode_lsmv(path):
    with zipfile.ZipFile(path) as archive:
        members = set(archive.namelist())
        if "input" not in members or "gametype" not in members:
            raise NotCovered("no text input member")

        def first_line(member):
            return archive.read(member).split(b"\n")[0].rstrip(b"\r").decode("latin-1")

        gametype = first_line("gametype")
        settings = {}
        for member in members:
            if re.fullmatch(r"port[0-9]+", member):
                settings[member] = first_line(member)
            elif member.startswith("setting.") and len(member) > 8:
                settings[member[8:]] = first_line(member)
        text = archive.read("input")
    ports = _lsmv_ports(gametype, settings)
    # An empty row is skipped; a row is one subframe.
    rows, numbers = [], []
    for number, line in enumerate(text.split(b"\n"), start=1):
        if line.endswith(b"\r"):
            line = line[:-1]
        if line:
            rows.append(line)
            numbers.append(number)
    n = len(rows)
    known, parsed = {}, []
    index = np.empty(n, dtype="i4")
    for i, line in enumerate(rows):
        at = known.get(line)
        if at is None:
            at = known[line] = len(parsed)
            parsed.append(_lsmv_row(line, ports))
        index[i] = at
    width = sum(len(part) for port in ports for name in port
                for part in LSMV_CONTROLLERS[name])
    table = np.array(parsed, dtype="i4").reshape(len(parsed), width)[index]
    column, fields = 0, []
    for port in ports:
        for name in port:
            buttons, axes = LSMV_CONTROLLERS[name]
            held = {b: table[:, column + j].astype("u1") for j, b in enumerate(buttons)}
            column += len(buttons)
            moved = {a: table[:, column + j].astype("i8") for j, a in enumerate(axes)}
            column += len(axes)
            fields.append((held, moved))
    system, pads = fields[0], fields[1:]
    sync = system[0]["framesync"]
    zero = np.zeros(n, dtype="i8")
    starts = np.flatnonzero(sync)
    frame = np.cumsum(sync.astype("i8"))
    position = np.arange(n, dtype="i8")
    latest = np.maximum.accumulate(np.where(sync != 0, position, -1))
    return {"n": n, "declared": None,
            "players": [held for held, _ in pads],
            "numeric": [moved for _, moved in pads],
            "flags": {"reset": system[0]["reset"],
                      "hard": system[0].get("hard", zero.astype("u1"))},
            "subframes": {"line": np.array(numbers, dtype="i8"),
                          "framesync": sync, "frame": frame,
                          "subframe": position - latest + 1,
                          "reset": system[0]["reset"],
                          "hard": system[0].get("hard", zero),
                          "rhigh": system[1].get("rhigh", zero),
                          "rlow": system[1].get("rlow", zero)},
            "frames": int(starts.size), "ports": ports}


# DTM -- Dolphin.
# Dolphin 5.0, Source/Core/Core/Movie.h (DTMHeader, ControllerState) and
# Movie.cpp (RecordInput, PlayController, RecordWiimote, PlayWiimote). The
# header is 256 bytes; byte 11 holds one bit per GameCube port in its low
# half and one per Wii Remote in its high half. A GameCube poll is eight
# bytes: a 16-bit field of buttons and two console controls, two triggers
# and two sticks. Polls follow one another without a port number.
# The Zelda Edition build, Movie.h at dragonbane0/dolphin revision
# a6e66c227c592d09ff09ef9b238d15ff52dd9632, extends a poll to 17 bytes: bit
# 14 is a loading flag, then a tuner event byte and two 32-bit floats.
DTM_BUTTONS = ["Start", "A", "B", "X", "Y", "Z", "DPadUp", "DPadDown",
               "DPadLeft", "DPadRight", "L", "R"]
DTM_AXES = ["TriggerL", "TriggerR", "AnalogStickX", "AnalogStickY",
            "CStickX", "CStickY"]
_DTM_ZELDA = "a6e66c227c592d09ff09ef9b238d15ff52dd9632"


def decode_dtm(path):
    data = Path(path).read_bytes()
    if len(data) < 256 or data[:4] != b"DTM\x1a":
        raise NotCovered("no DTM signature")
    ports = data[11]
    declared = struct.unpack_from("<Q", data, 21)[0]
    revision = data[209:229].hex()
    if ports & 0xF0:
        return _decode_dtm_wii(data, ports, declared, revision)
    size = 17 if revision == _DTM_ZELDA else 8
    body = data[256:]
    if len(body) % size:
        raise NotCovered("the input ends inside a poll")
    n = len(body) // size
    block = np.frombuffer(body, dtype="u1", count=n * size).reshape(n, size)
    word = block[:, 0].astype("u2") | (block[:, 1].astype("u2") << 8)
    held = {name: _bit(word, 1 << j) for j, name in enumerate(DTM_BUTTONS)}
    axes = {name: block[:, 2 + j].astype("i8") for j, name in enumerate(DTM_AXES)}
    result = {"n": n, "declared": declared, "players": [held], "numeric": [axes],
              "flags": {"disc": _bit(word, 0x1000), "reset": _bit(word, 0x2000)},
              "pads": bin(ports & 0x0F).count("1"), "revision": revision}
    if size == 17:
        tail = np.ascontiguousarray(block[:, 9:17])
        result["poll_fields"] = {
            "loading": _bit(word, 0x4000),
            "tunerEvent": block[:, 8].astype("i8"),
            "LinkX": tail[:, 0:4].copy().view("<f4")[:, 0].astype("f8"),
            "LinkZ": tail[:, 4:8].copy().view("<f4")[:, 0].astype("f8")}
    return result


# Wii Remote polls. A record is a length byte and that many bytes of an input
# report (Movie.cpp, RecordWiimote). Dolphin 5.0 stores the report with its
# HID prefix 0xA1; later builds store it from the report ID. The reports are
# described by Source/Core/Core/HW/WiimoteCommon/WiimoteReport.h (ButtonData)
# and DataReport.cpp (report composition, GetAccelData), the camera objects
# by HW/WiimoteEmu/Camera.h (IRBasic, IRExtended), and the widening of the
# nine-bit accelerometer values by Common/BitUtils.h (ExpandValue), all at
# revision 7eb02ecfa452578d9596501cc097d26b80a15931.
#
# Where GameCube pads are enabled as well, their eight-byte polls share the
# stream. Dolphin 5.0 leaves the two highest bits of the second pad byte at
# zero, which a report prefix never does. Later builds set bit 6 of that
# byte for a connected pad, which a report ID never does, and store a
# disconnected pad without buttons, so its first byte is zero where a record
# would hold its length (Movie.h, ControllerState; Movie.cpp, CheckPadStatus).
# A record whose bytes are not a report of a known kind is kept as a poll
# without values.
WII_BUTTONS = [("left", 0x0001), ("right", 0x0002), ("down", 0x0004),
               ("up", 0x0008), ("plus", 0x0010), ("two", 0x0100),
               ("one", 0x0200), ("b", 0x0400), ("a", 0x0800),
               ("minus", 0x1000), ("home", 0x8000)]
# Report ID -> payload length, accelerometer, camera (offset, length) and
# extension (offset, length); offsets count from the first payload byte.
_WII_REPORTS = {
    0x30: (2, False, None, None), 0x31: (5, True, None, None),
    0x32: (10, False, None, (2, 8)), 0x33: (17, True, (5, 12), None),
    0x34: (21, False, None, (2, 19)), 0x35: (21, True, None, (5, 16)),
    0x36: (21, False, (2, 10), (12, 9)), 0x37: (21, True, (5, 10), (15, 6)),
    0x3D: (21, False, None, (0, 21)),
}
_WII_INTERLEAVED = (0x3E, 0x3F)


def _dtm_records(body, marker, pads, prefix=0):
    """Split the input into pad polls (kind 0) and Wii Remote records."""
    kinds, starts, sizes = [], [], []
    pos, end = 0, len(body)
    while pos + prefix + 1 < end:
        pos += prefix
        second = body[pos + 1]
        if pads and (second != 0xA1 if marker else
                     bool(second & 0x40) or body[pos] == 0):
            if pos + 8 > end:
                return None
            kinds.append(0)
            starts.append(pos)
            sizes.append(8)
            pos += 8
            continue
        size = body[pos]
        if size == 0:
            return None
        if pos + 1 + size > end:
            break  # the last record is incomplete
        kinds.append(1)
        starts.append(pos + 1)
        sizes.append(size)
        pos += 1 + size
    return (np.array(kinds, dtype="u1"), np.array(starts, dtype="i8"),
            np.array(sizes, dtype="i8"))


def _wii_valid(buf, records, lead):
    """Records that hold a complete report of a known kind."""
    kinds, starts, sizes = records
    ident = np.zeros(len(kinds), dtype="i8")
    reach = (kinds == 1) & (sizes >= lead)
    ident[reach] = buf[starts[reach] + lead - 1]
    length = np.full(256, -1, dtype="i8")
    for report, layout in _WII_REPORTS.items():
        length[report] = layout[0]
    for report in _WII_INTERLEAVED:
        length[report] = 21
    valid = reach & (length[ident] + lead == sizes)
    if lead == 2:
        valid &= buf[np.where(reach, starts, 0)] == 0xA1
    return valid, ident, reach


def _decode_dtm_wii(data, ports, declared, revision):
    body = data[256:]
    buf = np.frombuffer(body, dtype="u1")
    pads = ports & 0x0F
    chosen = None
    for lead in (2, 1):
        records = _dtm_records(body, lead == 2, pads)
        if records is None or not len(records[0]):
            continue
        valid, ident, reach = _wii_valid(buf, records, lead)
        wii = records[0] == 1
        # With pads in the stream every record must be a report; otherwise
        # the framing with the larger number of reports is the stored one.
        if pads and not valid[wii].all():
            continue
        if chosen is None or valid.sum() > chosen[2].sum():
            chosen = (records, lead, valid, ident, reach)
    if (chosen is None or not chosen[2].any()) and not pads:
        # One recording was made with a build outside the Dolphin repository
        # (revision a655ada646f7277052802b72b5e5f3cadd37ed5e). Its file shows
        # eight bytes before every record, a rising 64-bit count. That
        # framing is read from the file; the reports are read as above.
        records = _dtm_records(body, True, 0, prefix=8)
        if records is not None and len(records[0]):
            valid, ident, reach = _wii_valid(buf, records, 2)
            ticks = buf[(records[1] - 9)[:, None] + np.arange(8)].copy().view("<u8")[:, 0]
            if valid.all() and (np.diff(ticks.astype("f8")) >= 0).all():
                chosen = (records, 2, valid, ident, reach)
    if chosen is None or not chosen[2].any():
        raise NotCovered("record framing")
    (kinds, starts, sizes), lead, valid, ident, reach = chosen
    if np.isin(ident[valid], _WII_INTERLEAVED).any():
        raise NotCovered("interleaved reports")
    n = len(kinds)
    wii = kinds == 1
    held = {name: np.zeros(n, dtype="u1") for name, _ in WII_BUTTONS}
    names = (["accel_x", "accel_y", "accel_z"]
             + ["ir%d_%s" % (k, part) for k in range(1, 5) for part in ("x", "y", "size")]
             + ["ext%d" % j for j in range(1, 22)])
    values = {name: np.full(n, np.nan) for name in names}
    values["id"] = np.where(reach, ident, np.where(wii, 0, np.nan)).astype("f8")
    core = valid & (ident != 0x3D)
    values["core"] = np.where(wii, core.astype("f8"), np.nan)
    for report, (length, accel, camera, extension) in _WII_REPORTS.items():
        rows = np.flatnonzero(valid & (ident == report))
        if not rows.size:
            continue
        block = buf[(starts[rows] + lead)[:, None] + np.arange(length)].astype("i8")
        if report != 0x3D:
            word = block[:, 0] | (block[:, 1] << 8)
            for name, mask in WII_BUTTONS:
                held[name][rows] = (word & mask) != 0
        if accel:
            values["accel_x"][rows] = (block[:, 2] << 2) | ((block[:, 0] >> 5) & 3)
            for axis, column, bit in (("accel_y", 3, 5), ("accel_z", 4, 6)):
                nine = (block[:, column] << 1) | ((block[:, 1] >> bit) & 1)
                values[axis][rows] = (nine << 1) | (nine & 1)
        if camera and camera[1] == 12:
            for k in range(4):
                b = block[:, camera[0] + 3 * k:camera[0] + 3 * k + 3]
                values["ir%d_x" % (k + 1)][rows] = b[:, 0] | (((b[:, 2] >> 4) & 3) << 8)
                values["ir%d_y" % (k + 1)][rows] = b[:, 1] | ((b[:, 2] >> 6) << 8)
                values["ir%d_size" % (k + 1)][rows] = b[:, 2] & 15
        elif camera:
            for pair in range(2):
                b = block[:, camera[0] + 5 * pair:camera[0] + 5 * pair + 5]
                first, second = 2 * pair + 1, 2 * pair + 2
                values["ir%d_x" % first][rows] = b[:, 0] | (((b[:, 2] >> 4) & 3) << 8)
                values["ir%d_y" % first][rows] = b[:, 1] | (((b[:, 2] >> 6) & 3) << 8)
                values["ir%d_x" % second][rows] = b[:, 3] | ((b[:, 2] & 3) << 8)
                values["ir%d_y" % second][rows] = b[:, 4] | (((b[:, 2] >> 2) & 3) << 8)
        if extension:
            for j in range(extension[1]):
                values["ext%d" % (j + 1)][rows] = block[:, extension[0] + j]
    disc = np.zeros(n, dtype="u1")
    reset = np.zeros(n, dtype="u1")
    if pads:
        rows = np.flatnonzero(~wii)
        block = buf[starts[rows][:, None] + np.arange(8)].astype("i8")
        word = block[:, 0] | (block[:, 1] << 8)
        for j, name in enumerate(DTM_BUTTONS):
            held[name] = np.zeros(n, dtype="u1")
            held[name][rows] = (word >> j) & 1
        for j, name in enumerate(DTM_AXES):
            values[name] = np.full(n, np.nan)
            values[name][rows] = block[:, 2 + j]
        disc[rows] = (word >> 12) & 1
        reset[rows] = (word >> 13) & 1
    return {"n": n, "declared": declared, "players": [held], "numeric": [values],
            "flags": {"disc": disc, "reset": reset}, "lead": lead,
            "reports": int(valid.sum()), "revision": revision}


# MMV -- Dega.
# https://tasvideos.org/EmulatorResources/MMV (retrieved 12 October 2026).
# The header gives the frame count, the offset of the input and the size of
# an input packet; a packet holds one byte per controller. The Game Gear
# uses the first controller only and stores Start in bit 7; on the Master
# System bit 6 is the console's Pause button, which Dega takes from the
# first controller byte only (Plombo/dega, mast/frame.cpp: "if
# (MastInput[0]&0x40) // Cause nmi if pause pressed"; master branch,
# retrieved 13 October 2026).
MMV_BUTTONS = [("up", 0x01), ("down", 0x02), ("left", 0x04), ("right", 0x08),
               ("1", 0x10), ("2", 0x20)]


def decode_mmv(path):
    data = Path(path).read_bytes()
    if data[:4] != b"MMV\0":
        raise NotCovered("no MMV signature")
    frames, = struct.unpack_from("<I", data, 0x08)
    offset, packet = struct.unpack_from("<II", data, 0x18)
    flags, = struct.unpack_from("<I", data, 0x60)
    game_gear = bool(flags & 8)
    if packet < (1 if game_gear else 2):
        raise NotCovered("input packet of %d bytes" % packet)
    body = data[offset:]
    n = len(body) // packet
    block = np.frombuffer(body, dtype="u1", count=n * packet).reshape(n, packet)
    players = []
    for pad in range(1 if game_gear else 2):
        held = {name: _bit(block[:, pad], mask) for name, mask in MMV_BUTTONS}
        if game_gear:
            held["start"] = _bit(block[:, pad], 0x80)
        players.append(held)
    out = {"n": n, "declared": frames, "players": players,
           "numeric": [{} for _ in players], "flags": {},
           "game_gear": game_gear, "packet": packet,
           "other": block[:, 0] & (0x40 if game_gear else 0x80)}
    if not game_gear:
        out["system"] = {"Pause": _bit(block[:, 0], 0x40)}
    return out


# WTF -- Hourglass.
# https://tasvideos.org/EmulatorResources/Hourglass/WTF (retrieved 12 October
# 2026). A 1024-byte header, then eight bytes per frame: the virtual key
# codes held in that frame, ended by the first zero byte.
def decode_wtf(path):
    data = Path(path).read_bytes()
    if data[:4] != bytes([0x66, 0x54, 0x77, 0x02]):
        raise NotCovered("no WTF signature")
    frames, = struct.unpack_from("<I", data, 4)
    body = data[1024:]
    n = len(body) // 8
    block = np.frombuffer(body, dtype="u1", count=n * 8).reshape(n, 8)
    # A code counts while no zero byte precedes it in its frame.
    listed = np.cumsum(block == 0, axis=1) == 0
    held = {}
    for code in np.unique(block[listed]):
        held["vk_%02x" % code] = ((block == code) & listed).any(axis=1).astype("u1")
    return {"n": n, "declared": frames, "players": [held], "numeric": [{}],
            "flags": {}}


# MC2 -- PCEjin and VBjin; YMV -- Yabause.
# movie.cpp of TASEmulators/pcejin, TASEmulators/vbjin and
# adelikat/yabause-rr (src/windows), master branches retrieved 12 October
# 2026: MovieRecord::parse, parsePad and mnemonics. A text record is a pipe,
# a decimal command, and one pad field per port, each followed by a pipe. A
# position is set unless it holds "." or a space. VBjin writes "emulator
# VBjin" in the header; its positions follow the Virtual Boy pad, with S, W,
# E and N for the right-hand direction pad.
MC2_PCE = ["Up", "Down", "Left", "Right", "I", "II", "Run", "Select"]
MC2_VB = ["RightPad Down", "RightPad Left", "Select", "Start", "LeftPad Up",
          "LeftPad Down", "LeftPad Left", "LeftPad Right", "RightPad Right",
          "RightPad Up", "L", "R", "B", "A"]
YMV_PAD = ["Left", "Right", "Up", "Down", "Start", "A", "B", "C", "X", "Y",
           "Z", "L", "R"]


def _jin_text(path, names_for):
    """Records of a text movie written by the "jin" emulators."""
    data = Path(path).read_bytes()
    if data[:9] != b"version 1":
        raise NotCovered("no version line")
    start = re.search(rb"^\|", data, re.M)
    head = data[:start.start()] if start else data
    keys = {}
    for line in head.splitlines():
        parts = line.split(None, 1)
        if parts:
            keys[parts[0]] = parts[1].strip() if len(parts) > 1 else b""
    if keys.get(b"binary", b"0") == b"1":
        raise NotCovered("binary records")
    names, ports = names_for(keys)
    width = len(names)
    command, held = [], []
    pos = start.start() if start else len(data)
    while True:
        found = _FM2_ROW.match(data, pos)
        if found is None:
            following = data.find(b"\n", pos)
            if following < 0 or not data[pos:].strip():
                break
            pos = following + 1
            continue
        number = _FM2_NUMBER.match(data, found.end())
        if number is None:
            break
        pos = number.end() + 1
        row = b""
        for _ in range(ports):
            row += data[pos:pos + width].ljust(width, b".")
            pos += width + 1
        pos += 1
        command.append(int(number.group(1)))
        held.append(row)
    n = len(command)
    symbols = np.frombuffer(b"".join(held), dtype="u1").reshape(n, ports, width)
    states = ((symbols != 0x2E) & (symbols != 0x20)).astype("u1")
    players = [{name: states[:, pad, j] for j, name in enumerate(names)}
               for pad in range(ports)]
    return {"n": n, "declared": None, "players": players,
            "numeric": [{} for _ in players],
            "flags": {"command": np.array(command, dtype="i8")}}


def decode_mc2(path):
    def layout(keys):
        vb = keys.get(b"emulator", b"").lower().startswith(b"vbjin")
        return (MC2_VB if vb else MC2_PCE), int(keys.get(b"ports", b"1"))
    return _jin_text(path, layout)


def decode_ymv(path):
    return _jin_text(path, lambda keys: (YMV_PAD, 1))


# FM3 -- FCEUX TAS Editor project: an FM2 movie whose header gives the
# number of records, followed by the editor's own data (movie.cpp, LoadFM2
# and its use of "length").
def decode_fm3(path):
    return decode_fm2(path)


# MCM -- Mednafen.
# https://tasvideos.org/EmulatorResources/Mednafen/MCM (retrieved 12 October
# 2026) for the header and frame layout: one command byte, then the bytes of
# every input port. The bits of a port follow the order of the input
# descriptors in TASEmulators/mednafen-rr, src/pce/input.cpp (GamepadIDII)
# and src/lynx/system.cpp (IDII), master branch.
MCM_SYSTEMS = {
    b"pce": (5, 2, ["i", "ii", "select", "run", "up", "right", "down", "left",
                    "iii", "iv", "v", "vi", "mode_select"]),
    b"lynx": (1, 2, ["a", "b", "option_2", "option_1", "left", "right", "up",
                     "down", "pause"]),
}


def decode_mcm(path):
    data = Path(path).read_bytes()
    if data[:8] != b"MDFNMOVI" or len(data) < 0x100:
        raise NotCovered("no MCM signature")
    system = data[0x74:0x79].split(b"\0")[0].lower()
    if system not in MCM_SYSTEMS:
        raise NotCovered("system " + system.decode("latin-1"))
    ports, size, names = MCM_SYSTEMS[system]
    width = 1 + ports * size
    body = data[0x100:]
    n = len(body) // width
    block = np.frombuffer(body, dtype="u1", count=n * width).reshape(n, width)
    players = []
    for port in range(ports):
        word = (block[:, 1 + 2 * port].astype("u2")
                | (block[:, 2 + 2 * port].astype("u2") << 8))
        players.append({name: _bit(word, 1 << j) for j, name in enumerate(names)})
    return {"n": n, "declared": None, "players": players,
            "numeric": [{} for _ in players],
            "flags": {"command": block[:, 0].astype("i8")}}


# JRSR -- JPC-RR.
# https://tasvideos.org/EmulatorResources/JPC/JRSRFormat (retrieved 12
# October 2026): line feeds and spaces, sections, the component encoding of
# a line, and the event classes. The events section holds one event per
# line: a time in nanoseconds, a class and its parameters. A key or mouse
# button event toggles that control, Pause is momentary, a joystick button
# event sets a state, an axis event sets a hold time that lasts until the
# next one, and mouse motion belongs to its event alone. One observation is
# decoded per event, holding the state after it.
_JRSR_LINES = re.compile("[\n\r\x1c-\x1e\x85 ]")
_JRSR_SPACE = frozenset(" \t ᠎  　"
                        + "".join(chr(c) for c in range(0x2000, 0x200B)))
_JRSR_KEYBOARD = "org.jpc.emulator.peripheral.Keyboard"
_JRSR_JOYSTICK = "org.jpc.modules.Joystick"
_JRSR_RESET = "org.jpc.emulator.PC$ResetButton"


def _jrsr_components(line):
    """Split a line into its components."""
    parts, token, depth, i = [], "", 0, 0
    while i < len(line):
        ch = line[i]
        if ch == "\\":
            i += 1
            if i == len(line):
                raise NotCovered("a backslash ends a line")
            token += line[i]
        elif ch == "(":
            if depth == 0:
                if token:
                    parts.append(token)
                token = ""
            else:
                token += ch
            depth += 1
        elif ch == ")":
            if depth == 0:
                raise NotCovered("unbalanced parenthesis")
            depth -= 1
            if depth == 0:
                if token:
                    parts.append(token)
                token = ""
            else:
                token += ch
        elif ch in _JRSR_SPACE and depth == 0:
            if token:
                parts.append(token)
            token = ""
        else:
            token += ch
        i += 1
    if depth:
        raise NotCovered("a line ends inside parentheses")
    if token:
        parts.append(token)
    return parts


def decode_jrsr(path):
    text = Path(path).read_bytes().decode("utf-8")
    lines = _JRSR_LINES.split(text)
    if lines[0] != "JRSR":
        raise NotCovered("no JRSR magic")
    events, section = [], None
    for line in lines[1:]:
        if line.startswith("!BEGIN") and line[6:7] in _JRSR_SPACE:
            section = line[6:].lstrip("".join(_JRSR_SPACE))
        elif line == "!END":
            section = None
        elif line.startswith("+") and section == "events":
            parts = _jrsr_components(line[1:])
            if parts:
                events.append(parts)
    n = len(events)
    held, moved = {}, {}
    state, axes = {}, {}
    times = np.zeros(n)
    reset = np.zeros(n, dtype="u1")
    relative, clock = False, 0

    def mark(table, name, i, value, fill):
        if name not in table:
            table[name] = np.full(n, fill, dtype="f8")
        table[name][i] = value

    for i, parts in enumerate(events):
        clock = int(parts[0]) + (clock if relative else 0)
        times[i] = clock
        kind = parts[1]
        what = parts[2] if len(parts) > 2 else ""
        value = parts[3] if len(parts) > 3 else ""
        momentary = None
        if kind == "OPTION":
            if what not in ("RELATIVE", "ABSOLUTE"):
                raise NotCovered("option " + what)
            relative = what == "RELATIVE"
        elif kind == _JRSR_KEYBOARD:
            if what == "KEYEDGE":
                state["key_" + str(int(value))] = not state.get("key_" + str(int(value)), False)
            elif what == "MOUSEBUTTON":
                state["mouse_" + str(int(value))] = not state.get("mouse_" + str(int(value)), False)
            elif what == "PAUSE":
                momentary = "pause"
            elif what in ("XMOUSEMOTION", "YMOUSEMOTION", "ZMOUSEMOTION"):
                mark(moved, what, i, int(value), 0)
            else:
                raise NotCovered("keyboard event " + what)
        elif kind == _JRSR_JOYSTICK:
            if what in ("BUTTONA", "BUTTONB", "BUTTONC", "BUTTOND"):
                state[what] = value != "0"
            elif what in ("AXISA", "AXISB", "AXISC", "AXISD"):
                axes[what] = int(value)
            else:
                raise NotCovered("joystick event " + what)
        elif kind == _JRSR_RESET:
            reset[i] = 1
        for name, on in state.items():
            if on or name in held:
                mark(held, name, i, on, 0)
        if momentary:
            mark(held, momentary, i, 1, 0)
        for name, hold in axes.items():
            mark(moved, name, i, hold, np.nan)
    second = {"BUTTONC", "BUTTOND", "AXISC", "AXISD"}
    players = [{k: v.astype("u1") for k, v in held.items() if k not in second}]
    numeric = [{k: v for k, v in moved.items() if k not in second}]
    if second & (set(held) | set(moved) | set(state)):
        players.append({k: v.astype("u1") for k, v in held.items() if k in second})
        numeric.append({k: v for k, v in moved.items() if k in second})
    return {"n": n, "declared": None, "players": players, "numeric": numeric,
            "flags": {"reset": reset}, "events": {"time": times}}


# DFT -- Dustmod Nexus scripts for Dustforce, packed as a gzip tar archive.
# https://dustkidblog.wordpress.com/2016/08/07/nexus-tasing-with-dustmod/
# (retrieved 12 October 2026) for the script lines: an input line gives one
# digit per action for a frame, and the commands INCLUDE (run another script
# at this point), MOUSE (position and buttons for the next input line), LOAD,
# STATS and SYNCLOAD. AlexMorson/dusted, src/dusted/nexus_script.py at
# revision af0a8f57a12f5b6986c9791c64bef7578e192acb, for the digit 2 of a
# double-tapped direction, which is also held. Later Dustmod versions add
# the columns taunt and restart. The script named main.txt is the entry;
# include paths are relative to the archive root.
DFT_ACTIONS = ["left", "right", "up", "down", "jump", "dash", "light",
               "heavy", "escape", "taunt", "restart"]
DFT_MOUSE = ["left click", "right click", "middle click", "scroll up",
             "scroll down"]


def decode_dft(path):
    with tarfile.open(path, "r:gz") as archive:
        scripts = {member.name: archive.extractfile(member).read().decode("utf-8-sig")
                   for member in archive.getmembers() if member.isfile()}
    entries = [name for name in scripts if name.rsplit("/", 1)[-1] == "main.txt"]
    if len(entries) != 1:
        raise NotCovered("no single main.txt")
    rows, pointed, waiting = [], {}, [None]

    def run(name, depth):
        if depth > 100 or name not in scripts:
            raise NotCovered("included script " + name)
        for line in scripts[name].split("\n"):
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            if line[0] in "012":
                rows.append("".join(line.split()))
                if waiting[0] is not None:
                    pointed[len(rows) - 1] = waiting[0]
                    waiting[0] = None
                continue
            parts = line.split(":")
            if parts[0] == "INCLUDE":
                run(parts[1], depth + 1)
            elif parts[0] == "MOUSE":
                waiting[0] = (float(parts[1]), float(parts[2]), parts[3])
            elif parts[0] not in ("LOAD", "STATS", "SYNCLOAD"):
                raise NotCovered("command " + parts[0])

    run(entries[0], 0)
    n = len(rows)
    held = {name: np.zeros(n, dtype="u1") for name in DFT_ACTIONS + DFT_MOUSE}
    place = {"mouse_x": np.full(n, np.nan), "mouse_y": np.full(n, np.nan)}
    for i, row in enumerate(rows):
        if len(row) > len(DFT_ACTIONS) or set(row) - set("012"):
            raise NotCovered("input line " + row)
        for j, digit in enumerate(row):
            if digit != "0":
                held[DFT_ACTIONS[j]][i] = 1
    for i, (x, y, buttons) in pointed.items():
        place["mouse_x"][i], place["mouse_y"][i] = x, y
        for j, digit in enumerate(buttons):
            held[DFT_MOUSE[j]][i] = digit == "1"
    return {"n": n, "declared": None, "players": [held], "numeric": [place],
            "flags": {}, "scripts": len(scripts)}


# FBM -- FB Alpha (FBA-rr).
# TASEmulators/fbarr at revision b679678de6b9f6548c46862d4c74ba4fb7cc1fdf,
# fbarr/src/burner/win32/replay.cpp (the chunks "FB1 ", "FS1 " and "FR1 ",
# the first values and the per-frame changes) and dynhuff.cpp with dynhuff.h
# (LoadCompressedFile, DecodeBuffer, BuildDHT, BuildNodeList, CorrectDHT,
# SwapNodes), whose adaptive Huffman code is followed step by step here.
# The input chunk holds one value for every entry of the game's input list,
# then for each frame the changed entries as index and value, ended by
# 0xFF; an analog entry takes two bytes. The lists come from
# fba-inputs.json, which fba_inputs.py reads from the driver sources. A
# digital input counts as held when bit 0 of its value is set, as the
# drivers of the recorded games read it (for example neo_run.cpp,
# cps_rw.cpp and sys16_run.cpp: "(value & 1) << i").
class _FbaNode:
    __slots__ = ("freq", "value", "left", "right", "parent", "index")

    def __init__(self, freq, value, parent):
        self.freq, self.value, self.parent = freq, value, parent
        self.left = self.right = None
        self.index = 0


def _fba_huffman(words, count):
    """Decode count bytes as DecodeBuffer and BuildDHT do."""
    size = 512
    nodes = [None] * size
    state = {"at": size - 1}
    root = _FbaNode(0, 0, None)
    table = [None] * 256
    null = root

    def listed(node):
        if state["at"] == size - 1:
            nodes[size - 1] = None
        for item in (node.parent, node):
            state["at"] -= 1
            nodes[state["at"]] = item
            item.index = state["at"]

    def swap(one, two):
        parent, index = one.parent, one.index
        if two.parent.left is two:
            two.parent.left = one
        else:
            two.parent.right = one
        if parent.left is one:
            one.parent.left = two
        else:
            one.parent.right = two
        one.parent, two.parent = two.parent, parent
        one.index, two.index = two.index, index
        change = one.freq - two.freq
        node = one
        while node.parent:
            node = node.parent
            node.freq += change
        node = two
        while node.parent:
            node = node.parent
            node.freq -= change

    def correct(current):
        while nodes[current + 1]:
            if nodes[current].freq > nodes[current + 1].freq:
                other = current + 1
                while nodes[other + 1]:
                    if nodes[other].freq < nodes[other + 1].freq:
                        lowest = state["at"]
                        pick = lowest if nodes[lowest].parent is nodes[current] else current
                        swap(nodes[pick], nodes[other])
                        nodes[pick], nodes[other] = nodes[other], nodes[pick]
                        if nodes[other].parent:
                            correct(nodes[other].parent.index)
                        return
                    other += 1
            if not nodes[current].parent:
                return
            current = nodes[current].parent.index

    def climb(node):
        """Count a use on the way to the root; first node now out of order."""
        first = None
        while node:
            node.freq += 1
            if first is None and node.parent and node.freq > nodes[node.index + 1].freq:
                first = node
            node = node.parent
        return first

    out = bytearray()
    word, used, at = int(words[0]), 8, 0
    data = word >> 24
    word = (word << 8) & 0xFFFFFFFF
    leaf = root.right = _FbaNode(1, data, root)
    root.freq = 1
    table[data] = leaf
    listed(leaf)
    out.append(data)
    for _ in range(count - 1):
        node = root
        while True:
            if used == 32:
                at += 1
                word, used = int(words[at]), 0
            node = node.right if word & 0x80000000 else node.left
            word = (word << 1) & 0xFFFFFFFF
            used += 1
            if node is None:
                data = 0
                for _ in range(8):
                    if used == 32:
                        at += 1
                        word, used = int(words[at]), 0
                    data = (data << 1) | (word >> 31)
                    word = (word << 1) & 0xFFFFFFFF
                    used += 1
                break
            if node.right is None:
                data = node.value
                break
        out.append(data)
        leaf = table[data]
        if leaf is not None:
            leaf.freq += 1
            first = None
            if leaf.parent is not null and leaf.freq > nodes[leaf.index + 1].freq:
                first = leaf
            later = climb(leaf.parent)
            first = first or later
            if first:
                correct(first.index)
        else:
            null.left = _FbaNode(1, 0, null)
            null = null.left
            leaf = null.right = _FbaNode(1, data, null)
            table[data] = leaf
            listed(leaf)
            if climb(null.parent):
                correct(state["at"])
    return bytes(out)


_FBA_TABLES = {}


def decode_fbm(path, game=None):
    data = Path(path).read_bytes()
    if data[:4] != b"FB1 ":
        raise NotCovered("no FBM signature")
    if not _FBA_TABLES:
        table = Path(__file__).with_name("fba-inputs.json")
        _FBA_TABLES.update(json.loads(table.read_text(encoding="utf-8")))
    if game not in _FBA_TABLES:
        raise NotCovered("no input list for " + str(game))
    inputs = _FBA_TABLES[game]["inputs"]
    pos = 5
    if data[pos:pos + 4] == b"FS1 ":
        pos += 8 + struct.unpack_from("<I", data, pos + 4)[0]
    if data[pos:pos + 4] != b"FR1 ":
        raise NotCovered("no input chunk")
    frames, = struct.unpack_from("<I", data, pos + 8)
    packed, count, resets, _ = struct.unpack_from("<4I", data, pos + 24)
    if resets:
        raise NotCovered("frequency counter resets")
    words = np.frombuffer(data, dtype="<u4", count=(packed - 16) // 4, offset=pos + 40)
    stream = _fba_huffman(words, count)
    wide = [bool(int(entry["type"] in ("BIT_ANALOG_REL", "BIT_ANALOG_ABS"))) for entry in inputs]

    def value(index, at):
        if wide[index]:
            number = (stream[at] << 8) | stream[at + 1]
            return number - 65536 if number >= 32768 else number, at + 2
        return stream[at], at + 1

    current, at = [], 0
    for index in range(len(inputs)):
        number, at = value(index, at)
        current.append(number)
    table = np.zeros((frames, len(inputs)), dtype="i4")
    for frame in range(frames):
        while True:
            index = stream[at]
            at += 1
            if index == 0xFF:
                break
            if index >= len(inputs):
                raise NotCovered("an input index beyond the game's list")
            current[index], at = value(index, at)
        table[frame] = current
    if at != len(stream):
        raise NotCovered("values remain after the last frame")
    players = {}
    for column, entry in enumerate(inputs):
        found = re.fullmatch(r"p(\d+) (up|down|left|right|start|select|fire \d+)", entry["info"])
        if found and not wide[column]:
            slot = players.setdefault(int(found.group(1)), {})
            # The drivers take bit 0 of a digital input's value.
            slot[found.group(2)] = (table[:, column] & 1).astype("u1")
    numbers = sorted(players) or [1]
    return {"n": frames, "declared": frames,
            "players": [players.get(p, {}) for p in numbers],
            "numeric": [{} for _ in numbers], "flags": {},
            "inputs": [(entry["info"], entry["name"], table[:, column])
                       for column, entry in enumerate(inputs)]}


# MAR -- MAME-rr.
# https://tasvideos.org/EmulatorResources/Mamerr/Mar (retrieved 12 October
# 2026) for the 64-byte header, and TASEmulators/mame-rr at revision
# 9b6b2f76a50994ca86f78610f6f5123a3ec9ebd8, mame-rr/src/emu/ioport.c
# (record_frame, record_port, set_bytes_per_frame, frame_update,
# input_condition_true) for a frame: the time, then for every input port its
# default word and the word of pressed digital inputs, each analog field
# adding its accumulator, previous value, sensitivity and reverse flag. The
# ports and fields of a game come from mame-ports.json, which mame_ports.py
# reads from the driver sources.
_MAR_PLAYER = re.compile(r"IPT_(JOYSTICK(LEFT|RIGHT)?_(UP|DOWN|LEFT|RIGHT)|BUTTON\d+)$")
_MAR_SYSTEM = re.compile(r"IPT_(COIN\d+|SERVICE\d*|TILT)$")
_MAR_TABLES = {}


def decode_mar(path):
    data = Path(path).read_bytes()
    if data[:8] != b"MAMETAS\0" or data[8] != 1:
        raise NotCovered("no MAR version 1 signature")
    if not _MAR_TABLES:
        table = Path(__file__).with_name("mame-ports.json")
        _MAR_TABLES.update(json.loads(table.read_text(encoding="utf-8")))
    game = data[12:24].split(b"\0")[0].decode("ascii")
    if game not in _MAR_TABLES:
        raise NotCovered("no port table for " + game)
    ports = _MAR_TABLES[game]["ports"]
    declared, = struct.unpack_from("<I", data, 56)
    width = 12 + sum(8 + 13 * sum(f["analog"] for f in p["fields"]) for p in ports)
    body = data[64:]
    if len(body) % width:
        raise NotCovered("the input does not divide into frames")
    n = len(body) // width
    block = np.frombuffer(body, dtype="u1").reshape(n, width)

    def word(at):
        return block[:, at:at + 4].copy().view("<u4")[:, 0].astype("i8")

    system = {"seconds": word(0), "attoseconds_low": word(4),
              "attoseconds_high": word(8)}
    defaults, digital, analog, at = {}, {}, [], 12
    for port in ports:
        defaults[port["tag"]] = word(at)
        digital[port["tag"]] = word(at + 4)
        system["default " + port["tag"]] = defaults[port["tag"]]
        system["digital " + port["tag"]] = digital[port["tag"]]
        at += 8
        for field in port["fields"]:
            if field["analog"]:
                analog.append((port["tag"], field, at))
                at += 13
    held, moved = {}, {}
    for port in ports:
        for field in port["fields"]:
            if field["condition"]:
                tag, mask, test, value = field["condition"]
                if test not in ("PORTCOND_EQUALS", "PORTCOND_NOTEQUALS") or not n:
                    raise NotCovered("field condition " + test)
                # Switch settings are part of the port's default word.
                if ((int(defaults[tag][0]) & mask) == value) != (test == "PORTCOND_EQUALS"):
                    continue
            if field["analog"]:
                continue
            kind = field["type"]
            pressed = ((digital[port["tag"]] & field["mask"]) != 0).astype("u1")
            if _MAR_SYSTEM.match(kind):
                system[kind] = system.get(kind, 0) | pressed
                continue
            start = re.match(r"IPT_START(\d+)$", kind)
            if start:
                player, name = int(start.group(1)), "START"
            elif _MAR_PLAYER.match(kind):
                player, name = field["player"], kind
            else:
                continue
            slot = held.setdefault(player, {})
            slot[name] = slot.get(name, 0) | pressed
    for tag, field, at in analog:
        slot = moved.setdefault(field["player"], {})
        signed = block[:, at:at + 8].copy().view("<i4").astype("i8")
        prefix = field["type"] + " " + tag + " "
        slot[prefix + "accum"] = signed[:, 0]
        slot[prefix + "previous"] = signed[:, 1]
        slot[prefix + "sensitivity"] = word(at + 8)
        slot[prefix + "reverse"] = block[:, at + 12].astype("i8")
    numbers = sorted(set(held) | set(moved)) or [1]
    return {"n": n, "declared": declared,
            "players": [held.get(p, {}) for p in numbers],
            "numeric": [moved.get(p, {}) for p in numbers],
            "flags": {}, "system": system, "game": game}


# ZMV -- ZSNES.
# https://tasvideos.org/OtherEmulators/ZMV (retrieved 12 October 2026) for
# the header and the layout of the file, and emillon/zsnes, src/zmovie.c
# (zmv_replay, replay_pad, pad_bit_decoder, bit_decoder,
# internal_chapter_length), master branch, for the stream. An event is a
# reset command, a run length (repeat the state up to a frame number), a
# chapter (skipped) or the new state of the controllers named in its flag
# byte. A pad state is 12 bits, taken from the most significant bit of each
# byte, in the order of the console's serial register.
ZMV_PAD = ["B", "Y", "Select", "Start", "Up", "Down", "Left", "Right", "A",
           "X", "L", "R"]


def decode_zmv(path):
    data = Path(path).read_bytes()
    if data[:3] != b"ZMV" or len(data) < 43:
        raise NotCovered("no ZMV signature")
    frames, = struct.unpack_from("<I", data, 0x09)
    chapters, author = struct.unpack_from("<HH", data, 0x1E)
    state_size = int.from_bytes(data[0x22:0x25], "little")
    enabled, = struct.unpack_from("<H", data, 0x25)
    if enabled & 0x0700:
        raise NotCovered("mouse or Super Scope")
    pos = 43 + (int.from_bytes(data[0x28:0x2B], "little") & 0x7FFFFF)
    external, = struct.unpack_from("<H", data, len(data) - author - 2)
    end = (len(data) - author - 2 - external * (state_size + 19) - chapters * 4)
    state = [[0] * 12 for _ in range(5)]
    rows, resets, pending = [], [], False
    while pos < end:
        flag = data[pos]
        pos += 1
        if flag & 1:
            if flag >> 1:
                raise NotCovered("command %d" % (flag >> 1))
            pending = True
            continue
        if flag & 2:
            until = int.from_bytes(data[pos:pos + 4], "little")
            pos += 4
            repeat = until - len(rows)
        elif flag & 4:
            pos += (int.from_bytes(data[pos:pos + 3], "little") & 0x7FFFFF) + 3 + 15
            continue
        else:
            changed = [pad for pad in range(5) if flag & (0x80 >> pad)]
            size = (12 * len(changed) + 7) // 8
            bits = int.from_bytes(data[pos:pos + size], "big") << (8 * (9 - size))
            pos += size
            for index, pad in enumerate(changed):
                word = (bits >> (72 - 12 * (index + 1))) & 0xFFF
                state[pad] = [(word >> (11 - j)) & 1 for j in range(12)]
            repeat = 1
        if repeat > 0:
            resets.append(len(rows) if pending else -1)
            pending = False
            rows.extend([sum(state, [])] * repeat)
    n = len(rows)
    table = np.array(rows, dtype="u1").reshape(n, 60)
    reset = np.zeros(n, dtype="u1")
    reset[[r for r in resets if r >= 0]] = 1
    players = [{name: table[:, 12 * pad + j] for j, name in enumerate(ZMV_PAD)}
               for pad in range(5) if enabled & (0x8000 >> pad)]
    return {"n": n, "declared": frames, "players": players,
            "numeric": [{} for _ in players], "flags": {"reset": reset},
            "pending": pending}


# GZM -- gz macro for The Legend of Zelda: Ocarina of Time.
# MrPancakeTurtle/gz, src/gz: gz_macro.c (do_import_macro), gz.h
# (struct movie_input), gz_movie.c (the reset flag in pad_delta) and z64.h
# (z64_controller_t), master branch retrieved 12 October 2026. The file is
# written on the console and is big-endian: the numbers of inputs and
# seeds, the controller state before the first input, then six bytes per
# input: the pad word, the stick position, and a word of edge flags whose
# bit 7 requests a reset.
GZM_PAD = [("a", 15), ("b", 14), ("z", 13), ("s", 12), ("du", 11), ("dd", 10),
           ("dl", 9), ("dr", 8), ("l", 5), ("r", 4), ("cu", 3), ("cd", 2),
           ("cl", 1), ("cr", 0)]


def decode_gzm(path):
    data = Path(path).read_bytes()
    inputs, seeds = struct.unpack_from(">II", data, 0)
    if 12 + 6 * inputs + 12 * seeds > len(data):
        raise NotCovered("fewer inputs than the file gives")
    block = np.frombuffer(data, dtype="u1", count=6 * inputs, offset=12).reshape(inputs, 6)
    pad = (block[:, 0].astype("u2") << 8) | block[:, 1]
    delta = (block[:, 4].astype("u2") << 8) | block[:, 5]
    held = {name: _bit(pad, 1 << bit) for name, bit in GZM_PAD}
    axes = {"x": block[:, 2].astype("i1").astype("i8"),
            "y": block[:, 3].astype("i1").astype("i8")}
    return {"n": inputs, "declared": inputs, "players": [held], "numeric": [axes],
            "flags": {"reset": _bit(delta, 0x0080)}}


# CTAS -- CoffeeTools for UFO 50.
# Blaizer/CoffeeTools, patches/CoffeeTools/code/
# gml_GlobalScript_CoffeeTools.gml (TAS_FILE, the file reader and writer,
# applyTasInputs), main branch retrieved 12 October 2026. A 1024-byte header
# gives the number of frames; a frame holds one 32-bit word per player, with
# three bits (held, pressed, released) for each of up, down, left, right and
# the two fire buttons, and bit 18 for a press of Start.
CTAS_HELD = [("up", 0), ("down", 3), ("left", 6), ("right", 9), ("fire1", 12),
             ("fire2", 15), ("start", 18)]


def decode_ctas(path):
    data = Path(path).read_bytes()
    if data[:4] != b"CTAS" or len(data) < 1024:
        raise NotCovered("no CTAS signature")
    version, frames = struct.unpack_from("<Ii", data, 4)
    if len(data) < 1024 + 8 * frames:
        raise NotCovered("fewer frames than the header gives")
    words = np.frombuffer(data, dtype="<u4", count=2 * frames, offset=1024).reshape(frames, 2)
    players = [{name: _bit(words[:, pad], 1 << bit) for name, bit in CTAS_HELD}
               for pad in range(2)]
    return {"n": frames, "declared": frames, "players": players,
            "numeric": [{}, {}], "flags": {}, "version": version}


# CTM -- Citra and Azahar.
# azahar-emu/azahar, src/core/movie.cpp (CTMHeader, ControllerStateType,
# ControllerState), master branch retrieved 12 October 2026. After a
# 256-byte header the file holds seven-byte records, each the poll of one
# device: a type byte and that device's fields.
CTM_PAD = ["a", "b", "select", "start", "right", "left", "up", "down", "r",
           "l", "x", "y", "debug", "gpio14"]


def decode_ctm(path):
    data = Path(path).read_bytes()
    if data[:4] != b"CTM\x1b" or len(data) < 256:
        raise NotCovered("no CTM signature")
    body = data[256:]
    if len(body) % 7:
        raise NotCovered("the input ends inside a record")
    n = len(body) // 7
    block = np.frombuffer(body, dtype="u1").reshape(n, 7)
    kind = block[:, 0]
    if (kind > 5).any():
        raise NotCovered("record type above 5")
    first = block[:, 1].astype("i8") | (block[:, 2].astype("i8") << 8)
    second = block[:, 3].astype("i8") | (block[:, 4].astype("i8") << 8)
    third = block[:, 5].astype("i8") | (block[:, 6].astype("i8") << 8)

    def signed(word):
        return np.where(word >= 32768, word - 65536, word).astype("f8")

    def only(rows, values):
        return np.where(rows, values, np.nan)

    pad, touch, motion, gyro, ir, extra = (kind == k for k in range(6))
    word = first | (second << 16)
    held = {name: (pad & ((first >> j) & 1 == 1)).astype("u1")
            for j, name in enumerate(CTM_PAD)}
    held["touch"] = (touch & (block[:, 5] != 0)).astype("u1")
    held["zl"] = ((ir & (block[:, 5] != 0)) | (extra & ((word >> 5) & 1 == 0))).astype("u1")
    held["zr"] = ((ir & (block[:, 6] != 0)) | (extra & ((word >> 6) & 1 == 0))).astype("u1")
    held["r"] |= (extra & ((word >> 7) & 1 == 0)).astype("u1")
    values = {
        "circle_pad_x": only(pad, signed(second)), "circle_pad_y": only(pad, signed(third)),
        "touch_x": only(touch, first), "touch_y": only(touch, second),
        "touch_valid": only(touch, block[:, 5]),
        "accelerometer_x": only(motion, signed(first)),
        "accelerometer_y": only(motion, signed(second)),
        "accelerometer_z": only(motion, signed(third)),
        "gyroscope_x": only(gyro, signed(first)), "gyroscope_y": only(gyro, signed(second)),
        "gyroscope_z": only(gyro, signed(third)),
        "ir_rst_x": only(ir, signed(first)), "ir_rst_y": only(ir, signed(second)),
        "battery_level": only(extra, word & 31),
        "c_stick_x": only(extra, (word >> 8) & 4095),
        "c_stick_y": only(extra, (word >> 20) & 4095),
    }
    return {"n": n, "declared": None, "players": [held], "numeric": [values],
            "flags": {},
            "poll_fields": {"pad": pad, "touch": touch, "ir_rst": ir, "extra_hid": extra}}


# LMP -- Doom-engine demo (Doom, Heretic, Hexen and their source ports).
# dsda-doom v0.29.4: prboom2/src/g_game.c (G_ReadDemoHeaderEx,
# G_ReadDemoTiccmd, G_ReadOneTick), prboom2/src/dsda/demo.c
# (dsda_StripDemoVersion255), dsda/excmd.c and excmd.h (dsda_ReadExCmd),
# dsda/options.c (dsda_ReadOptions21, dsda_GameOptionSize). Chocolate Doom
# 3.1.0: src/doom/d_event.h (BT_ATTACK, BT_USE, BT_CHANGE, BT_SPECIAL),
# src/heretic/p_user.c and src/hexen/p_user.c (look, fly and the artifact
# byte), src/hexen/h2def.h (AFLAG_JUMP, AFLAG_SUICIDE, AFLAG_MASK).
# Retrieved 13 October 2026.
#
# The file is read as the engine reads it: one field after another. A demo
# without a version byte does not name its game, and an early Heretic or
# Hexen port may store 16-bit turning without marking it; the engine is told
# both on its command line (-heretic, -hexen, -longtics), this reader through
# its arguments.
def decode_lmp(path, game=None, longtics=None):
    data = Path(path).read_bytes()
    size = len(data)
    p = 0
    version = data[p]
    p += 1
    extended = False
    if version == 255:
        if data[p:p + 6] == b"\x1dDSDA\xe6":
            level = data[p + 6]
            if not 1 <= level <= 3:
                raise NotCovered("dsda-doom header version %d" % level)
            p += 7
            flags = data[p + 8] if level >= 2 else 0
            p += (0, 8, 9, 10)[level]
            if flags & 0x01:
                raise NotCovered("the demo starts from a keyframe")
            extended = True
        elif data[p:p + 5] == b"PR+UM":
            # signature, version, extension count, name length, name, map lump
            if (data[p + 6] != 1 or data[p + 7:p + 9] != b"\x01\x00"
                    or data[p + 9] != 8 or data[p + 10:p + 18] != b"UMAPINFO"):
                raise NotCovered("unknown extended header")
            p += 26
        else:
            raise NotCovered("unknown extended header")
        version = data[p]
        p += 1
    inner = p - 1
    known = (version <= 4 or 104 <= version <= 111 or 200 <= version <= 214
             or version == 221)
    if not known:
        raise NotCovered("demo version %d" % version)
    if version <= 4 and game is None:
        raise NotCovered("no version byte; the game was not given")
    if version > 4:
        game = "doom"
    raven = game in ("heretic", "hexen")
    slots = 8 if game == "hexen" else 4
    wide = False
    if version < 200:
        if version >= 111:
            wide = True
        if version >= 100:
            p += 8   # skill, episode, map, deathmatch, respawn, fast, nomonsters, consoleplayer
        else:
            p += 2   # episode, map; the skill was the first byte
            if raven and (data[p] & 0x10 or longtics):
                wide = True
        if game == "hexen":
            present = [data[p + 2 * i] != 0 for i in range(8)]
            p += 16
        else:
            present = [data[p + i] != 0 for i in range(4)]
            p += 4
    else:
        maker = data[inner + 2]
        p += 6
        if version in (200, 201, 202):
            p += 1
        elif version == 203:
            if maker == ord("M"):
                p += 1
            elif maker != ord("B"):
                raise NotCovered("unknown signature for version 203")
        elif 210 <= version <= 214:
            p += 1
            wide = version == 214
        else:
            wide = True
        p += 5       # skill, episode, map, deathmatch, consoleplayer
        if version == 221:
            listed = data[p + 20]
            if listed > 25:
                raise NotCovered("unknown MBF21 options")
            p += 21 + listed
        else:
            p += 256 if version == 200 else 64
        present = [data[p + i] != 0 for i in range(4)]
        p += 32
    if p > size:
        raise NotCovered("the header is incomplete")
    ports = [i for i in range(slots) if present[i]]
    if not ports:
        raise NotCovered("no player in the game")
    names = ["forwardmove", "sidemove", "angleturn", "buttons", "look", "fly",
             "arti", "actions", "save_slot", "load_slot", "ex_look"]
    rows = {port: [] for port in ports}
    ended = False
    while not ended:
        for port in ports:
            if p >= size:
                raise NotCovered("no end marker")
            if data[p] == 0x80:
                if port != ports[0]:
                    raise NotCovered("the end marker falls inside a tic")
                ended = True
                break
            need = (5 if wide else 4) + (2 if raven else 0) + (1 if extended else 0)
            if p + need > size:
                raise NotCovered("the last command is incomplete")
            if version == 110:
                # TASDoom: buttons, forward, side, turn.
                buttons, forward, side = data[p], data[p + 1], data[p + 2]
                turn = data[p + 3] << 8
                p += 4
            else:
                forward, side = data[p], data[p + 1]
                p += 2
                if wide:
                    turn = data[p] | (data[p + 1] << 8)
                    p += 2
                else:
                    turn = data[p] << 8
                    p += 1
                buttons = data[p]
                p += 1
            look = fly = arti = 0
            if raven:
                look, fly, arti = data[p] & 15, data[p] >> 4, data[p + 1]
                p += 2
            actions = save_slot = load_slot = ex_look = 0
            if extended:
                actions = data[p]
                p += 1
                if p + bool(actions & 0x02) + bool(actions & 0x04) + 2 * bool(actions & 0x20) > size:
                    raise NotCovered("the last command is incomplete")
                if actions & 0x02:
                    save_slot = data[p]
                    p += 1
                if actions & 0x04:
                    load_slot = data[p]
                    p += 1
                if actions & 0x20:
                    ex_look = data[p] | (data[p + 1] << 8)
                    p += 2
            rows[port].append((forward, side, turn, buttons, look, fly, arti,
                               actions, save_slot, load_slot, ex_look))
    n = len(rows[ports[0]])
    special = np.zeros(n, dtype="i8")
    players, numeric = [], []
    for port in range(slots):
        if port not in rows:
            players.append({})
            numeric.append({})
            continue
        table = np.array(rows[port], dtype="i8").reshape(n, len(names))
        field = {name: table[:, i] for i, name in enumerate(names)}
        signed8 = lambda v: np.where(v >= 128, v - 256, v)
        signed16 = lambda v: np.where(v >= 32768, v - 65536, v)
        signed4 = lambda v: np.where(v >= 8, v - 16, v)
        buttons = field["buttons"]
        console = (buttons & 0x80) != 0
        special |= np.where(console, buttons, 0)
        held = {"attack": ((buttons & 1) != 0) & ~console,
                "use": ((buttons & 2) != 0) & ~console}
        change = ((buttons & 4) != 0) & ~console
        values = {"forwardmove": signed8(field["forwardmove"]),
                  "sidemove": signed8(field["sidemove"]),
                  "angleturn": signed16(field["angleturn"]),
                  "weaponselect": np.where(change, (buttons >> 3) & 7, np.nan),
                  "has_special": console.astype("i8")}
        jump = None
        if raven:
            values["look"] = signed4(field["look"])
            values["fly"] = signed4(field["fly"])
            if game == "hexen":
                values["artifact"] = field["arti"] & 0x3F
                values["suicide"] = (field["arti"] & 0x40) >> 6
                jump = (field["arti"] & 0x80) != 0
            else:
                values["artifact"] = field["arti"]
        if extended:
            leap = (field["actions"] & 0x01) != 0
            jump = leap if jump is None else jump | leap
            values["excmd_actions"] = field["actions"]
            values["excmd_save_slot"] = field["save_slot"]
            values["excmd_load_slot"] = field["load_slot"]
            values["excmd_look"] = signed16(field["ex_look"])
        if jump is not None:
            held["jump"] = jump
        players.append({name: state.astype("u1") for name, state in held.items()})
        numeric.append(values)
    return {"n": n, "declared": None, "players": players, "numeric": numeric,
            "flags": {"special": special}, "version": version}


# OMR -- openMSX replay, a gzip-compressed XML serialisation.
# openMSX at revision f07bee985b8e2102c47913c217ad0365638bf8ae:
# src/input/Keyboard.cc (KeyMatrixState, signalMSXEvent and the serialised
# userKeyMatrix), src/input/MSXJoystick.cc (MSXJoyState),
# src/input/JoystickDevice.hh (JOY_UP to JOY_BUTTONB) and src/EmuDuration.hh
# (MAIN_FREQ); src/input/KeyJoystick.cc at RELEASE_0_15_0 (KeyJoyState).
# Every event carries a time in units of 1 / (3579545 * 960) seconds. A
# keyboard or joystick event names the bits pressed and the bits released;
# the release is applied after the press. The first snapshot holds the
# keyboard matrix at the start, a cleared bit being a held key. One
# observation is decoded per event, holding the state after it.
_OMR_JOY = ["up", "down", "left", "right", "a", "b"]
OMR_FREQUENCY = 3579545 * 960


def decode_omr(path):
    with gzip.open(path, "rb") as source:
        root = ElementTree.parse(source).getroot()
    replay = root.find("replay")
    if replay is None:
        raise NotCovered("no replay element")
    events = replay.findall("events/item")
    n = len(events)
    state, held = {}, {}
    matrix = replay.find("snapshots/item//keyboard/userKeyMatrix")
    if matrix is not None:
        for row, item in enumerate(matrix.findall("item")):
            for bit in range(8):
                if not (int(item.text) >> bit) & 1:
                    state["key_r%d_b%d" % (row, bit)] = True
    for name in state:
        held[name] = np.zeros(n, dtype="u1")
    ticks = np.zeros(n)
    reset = np.zeros(n, dtype="u1")
    autofire, speed = {}, {}
    for i, event in enumerate(events):
        kind = event.get("type")
        ticks[i] = int(event.findtext("StateChange/time/time"))
        prefix = None
        if kind == "KeyMatrixState":
            prefix = ["key_r%d_b%d" % (int(event.findtext("row")), b) for b in range(8)]
        elif kind == "KeyJoyState":
            prefix = [event.findtext("name") + "_" + part for part in _OMR_JOY]
        elif kind == "MSXJoyState":
            prefix = ["joystick%s_%s" % (event.findtext("id"), part) for part in _OMR_JOY]
        elif kind == "AutofireStateChange":
            speed[event.findtext("name")] = int(event.findtext("value"))
        elif kind == "MSXCommandEvent":
            tokens = [item.text for item in event.findall("tokens/item")]
            reset[i] = bool(tokens) and tokens[0] == "reset"
        elif kind != "EndLog":
            raise NotCovered("event type " + str(kind))
        if prefix:
            press = int(event.findtext("press"))
            release = int(event.findtext("release"))
            for bit, name in enumerate(prefix):
                if (press >> bit) & 1:
                    state[name] = True
                if (release >> bit) & 1:
                    state[name] = False
                if name in state and name not in held:
                    held[name] = np.zeros(n, dtype="u1")
        for name, on in state.items():
            held[name][i] = on
        for name, value in speed.items():
            if name not in autofire:
                autofire[name] = np.zeros(n)
            autofire[name][i] = value
    return {"n": n, "declared": None, "players": [held],
            "numeric": [{"autofire_" + k: v for k, v in autofire.items()}],
            "flags": {"reset": reset},
            "events": {"ticks": ticks, "seconds": ticks / OMR_FREQUENCY}}


DECODERS = {"vbm": decode_vbm, "dsm": decode_dsm, "bkm": decode_bkm,
            "ltm": decode_ltm, "fmv": decode_fmv, "gmv": decode_gmv,
            "smv": decode_smv, "m64": decode_m64, "fcm": decode_fcm,
            "fm2": decode_fm2, "pxm": decode_pxm, "pjm": decode_pjm,
            "lsmv": decode_lsmv, "dtm": decode_dtm, "mmv": decode_mmv,
            "wtf": decode_wtf, "mc2": decode_mc2, "ymv": decode_ymv,
            "fm3": decode_fm3, "mcm": decode_mcm, "jrsr": decode_jrsr,
            "omr": decode_omr, "lmp": decode_lmp,
            "ctas": decode_ctas, "ctm": decode_ctm, "tas": decode_bkm,
            "gzm": decode_gzm, "zmv": decode_zmv, "mar": decode_mar,
            "fbm": decode_fbm, "dft": decode_dft}
