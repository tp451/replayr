"""Compare replayr's exported values with the independent decoders.

Usage: python compare.py <export directory> <results.csv>
Environment: REPLAYR_VALIDATION_ROOT (recording directory).

The export directory is written by export-replayr.R. Every value of every
recording is compared: button states per controller, numeric channels, and
per-observation commands. The mapping tables below state which control of the
format description corresponds to which replayr control key.
"""

from pathlib import Path
import csv
import json
import os
import re
import sys

import numpy as np

from decoders import DECODERS, NotCovered

_PAD = {"Up": "dpad_up", "Down": "dpad_down", "Left": "dpad_left",
        "Right": "dpad_right"}
# Format control name -> replayr control key.
BUTTONS = {
    "vbm": {"A": "a", "B": "b", "Select": "select", "Start": "start",
            "Right": "dpad_right", "Left": "dpad_left", "Up": "dpad_up",
            "Down": "dpad_down", "R": "r1", "L": "l1"},
    "dsm": {"Right": "dpad_right", "Left": "dpad_left", "Down": "dpad_down",
            "Up": "dpad_up", "Select": "select", "Start": "start", "B": "b",
            "A": "a", "Y": "y", "X": "x", "L": "l1", "R": "r1"},
    # BizHawk control names of the eleven legacy controller definitions.
    "bkm": {"Up": "dpad_up", "Down": "dpad_down", "Left": "dpad_left",
            "Right": "dpad_right", "DPad U": "dpad_up", "DPad D": "dpad_down",
            "DPad L": "dpad_left", "DPad R": "dpad_right", "Select": "select",
            "Start": "start", "Run": "start", "A": "a", "B": "b", "C": "c",
            "X": "x", "Y": "y", "Z": "z", "Mode": "mode", "L": "l1", "R": "r1",
            "B1": "a", "B2": "b", "Button": "a", "Trigger": "a",
            "Trigger 2": "b", "C Up": "c_up", "C Down": "c_down",
            "C Left": "c_left", "C Right": "c_right", "Star": "select",
            "Pound": "start",
            **{f"Key{i}": f"numbered_{i}" for i in range(10)}},
    # libTAS: keyboard and mouse share the first controller's player. Mouse
    # buttons 1 to 5 are left, middle, right and the two side buttons.
    "ltm": {"A": "a", "B": "b", "X": "x", "Y": "y", "Back": "select",
            "Guide": "mode", "Start": "start", "LeftStick": "l3",
            "RightStick": "r3", "LeftShoulder": "l1", "RightShoulder": "r1",
            "DpadUp": "dpad_up", "DpadDown": "dpad_down",
            "DpadLeft": "dpad_left", "DpadRight": "dpad_right",
            "Mouse1": "a", "Mouse2": "x", "Mouse3": "b", "Mouse4": "l1",
            "Mouse5": "r1"},
    "fmv": dict(_PAD, Select="select", Start="start", A="a", B="b"),
    # A Zapper's trigger and its off-screen shot take replayr's a and y.
    "fm2": dict(_PAD, Select="select", Start="start", A="a", B="b",
                Trigger="a", Offscreen="y"),
    "fcm": dict(_PAD, Select="select", Start="start", A="a", B="b"),
    "gmv": dict(_PAD, Start="start", A="a", B="b", C="c", X="x", Y="y", Z="z",
                Mode="mode"),
    "smv": dict(_PAD, Start="start", Select="select", A="a", B="b", X="x",
                Y="y", L="l1", R="r1"),
    # PlayStation shapes follow replayr's documented positions.
    "pxm": dict(_PAD, Select="select", Start="start", L1="l1", R1="r1",
                L2="l2", R2="r2", L3="l3", R3="r3", Cross="b", Circle="a",
                Triangle="x", Square="y"),
    "pjm": dict(_PAD, Select="select", Start="start", L1="l1", R1="r1",
                L2="l2", R2="r2", L3="l3", R3="r3", Cross="b", Circle="a",
                Triangle="x", Square="y"),
    # lsnes: the Super Scope's trigger, cursor, turbo and pause take
    # replayr's a, b, mode and start.
    "lsmv": {"B": "b", "Y": "y", "select": "select", "start": "start",
             "up": "dpad_up", "down": "dpad_down", "left": "dpad_left",
             "right": "dpad_right", "A": "a", "X": "x", "L": "l1", "R": "r1",
             "trigger": "a", "cursor": "b",
             "turbo": "mode", "pause": "start"},
    # Dolphin: GameCube pad names, then the Wii Remote's, whose 1, 2 and
    # Home buttons take replayr's x, y and mode.
    "dtm": {"Start": "start", "A": "a", "B": "b", "X": "x", "Y": "y",
            "Z": "z", "DPadUp": "dpad_up", "DPadDown": "dpad_down",
            "DPadLeft": "dpad_left", "DPadRight": "dpad_right", "L": "l1",
            "R": "r1", "left": "dpad_left", "right": "dpad_right",
            "down": "dpad_down", "up": "dpad_up", "plus": "start",
            "two": "y", "one": "x", "b": "b", "a": "a", "minus": "select",
            "home": "mode"},
    # Dega: numbered buttons in order, so 1 and 2 are replayr's a and b. The
    # Master System's Pause is a console control and compared as such.
    "mmv": {"up": "dpad_up", "down": "dpad_down", "left": "dpad_left",
            "right": "dpad_right", "1": "a", "2": "b", "start": "start"},
    "wtf": {},
    # Dustforce: jump, dash, the two attacks, taunt and restart are game
    # actions; the mouse buttons share a, b and x and its wheel the two
    # vertical C-buttons.
    "dft": {"left": "dpad_left", "right": "dpad_right", "up": "dpad_up",
            "down": "dpad_down", "jump": "action_jump", "dash": "action_dash",
            "light": "action_light", "heavy": "action_heavy",
            "escape": "start", "taunt": "action_taunt",
            "restart": "action_restart", "left click": "a",
            "right click": "b", "middle click": "x",
            "scroll up": "c_up", "scroll down": "c_down"},
    # FB Alpha: fire buttons 1 to 8 take replayr's a, b, x, y, l1, r1, l2, r2.
    "fbm": {"up": "dpad_up", "down": "dpad_down", "left": "dpad_left",
            "right": "dpad_right", "start": "start", "select": "select",
            **{f"fire {i + 1}": key for i, key in enumerate(
                ["a", "b", "x", "y", "l1", "r1", "l2", "r2"])}},
    # MAME: buttons 1 to 8 take replayr's a, b, x, y, l1, r1, l2 and r2. A
    # cabinet's two joysticks have the direction keys of replayr's left and
    # right analogue stick (north, east, south, west).
    "mar": {"START": "start",
            **{f"IPT_JOYSTICK_{way}": f"dpad_{way.lower()}"
               for way in ("UP", "DOWN", "LEFT", "RIGHT")},
            **{f"IPT_JOYSTICK{side}_{way}": f"{side.lower()}_{letter}"
               for side in ("LEFT", "RIGHT")
               for way, letter in (("UP", "n"), ("DOWN", "s"), ("LEFT", "w"),
                                   ("RIGHT", "e"))},
            **{f"IPT_BUTTON{i + 1}": key for i, key in enumerate(
                ["a", "b", "x", "y", "l1", "r1", "l2", "r2"])}},
    "zmv": dict(_PAD, Start="start", Select="select", A="a", B="b", X="x",
                Y="y", L="l1", R="r1"),
    "gzm": {"a": "a", "b": "b", "z": "z", "s": "start", "du": "dpad_up",
            "dd": "dpad_down", "dl": "dpad_left", "dr": "dpad_right",
            "l": "l1", "r": "r1", "cu": "c_up", "cd": "c_down",
            "cl": "c_left", "cr": "c_right"},
    "ctas": {"up": "dpad_up", "down": "dpad_down", "left": "dpad_left",
             "right": "dpad_right", "fire1": "a", "fire2": "b",
             "start": "start"},
    "ctm": {"a": "a", "b": "b", "select": "select", "start": "start",
            "right": "dpad_right", "left": "dpad_left", "up": "dpad_up",
            "down": "dpad_down", "r": "r1", "l": "l1", "x": "x", "y": "y",
            "touch": "l3", "zl": "l2", "zr": "r2"},
    # Doom stores game actions; replayr keeps them apart from pad buttons.
    "lmp": {"attack": "action_attack", "use": "action_use",
            "jump": "action_jump"},
    # JPC-RR: mouse buttons 0 to 4 are left, right, middle and two side
    # buttons; joystick buttons A and C are the first of each stick.
    "jrsr": {"mouse_0": "a", "mouse_1": "b", "mouse_2": "x", "mouse_3": "l1",
             "mouse_4": "r1", "pause": "jpcrr_pause", "BUTTONA": "a",
             "BUTTONB": "b", "BUTTONC": "a", "BUTTOND": "b"},
    # PCEjin: I and II take replayr's a and b, Run takes start. VBjin: the
    # left pad is replayr's direction pad, the right pad has the keys of the
    # N64's C-buttons.
    "mc2": {"Up": "dpad_up", "Down": "dpad_down", "Left": "dpad_left",
            "Right": "dpad_right", "I": "a", "II": "b", "Run": "start",
            "Select": "select", "Start": "start", "L": "l1", "R": "r1",
            "A": "a", "B": "b", "LeftPad Up": "dpad_up",
            "LeftPad Down": "dpad_down", "LeftPad Left": "dpad_left",
            "LeftPad Right": "dpad_right", "RightPad Up": "c_up",
            "RightPad Down": "c_down", "RightPad Left": "c_left",
            "RightPad Right": "c_right"},
    "ymv": dict(_PAD, Start="start", A="a", B="b", C="c", X="x", Y="y", Z="z",
                L="l1", R="r1"),
    "fm3": dict(_PAD, Select="select", Start="start", A="a", B="b",
                Trigger="a", Offscreen="y"),
    # Mednafen: numbered buttons in order; settings and option buttons take
    # Start, Select and Mode (Run and Pause are start, the Lynx's Option 1
    # and 2 select and mode, the 2/6-button switch mode).
    "mcm": {"i": "a", "ii": "b", "select": "select", "run": "start",
            "up": "dpad_up", "right": "dpad_right", "down": "dpad_down",
            "left": "dpad_left", "iii": "x", "iv": "y",
            "v": "l1", "vi": "r1", "mode_select": "mode",
            "a": "a", "b": "b", "option_1": "select",
            "option_2": "mode", "pause": "start"},
    "m64": {"DPad Right": "dpad_right", "DPad Left": "dpad_left",
            "DPad Down": "dpad_down", "DPad Up": "dpad_up", "Start": "start",
            "Z": "z", "B": "b", "A": "a", "C Right": "c_right",
            "C Left": "c_left", "C Down": "c_down", "C Up": "c_up",
            "R": "r1", "L": "l1"},
}
# replayr control keys that the format stores outside the button field.
DERIVED = {
    "dsm": {"microphone": ("flag", "microphone"),
            "l3": ("numeric", "touch_pressed")},
}
# Format channel name -> replayr channel name; {player} counts from one.
NUMERIC = {
    "dsm": {"touch_x": "touch_x", "touch_y": "touch_y",
            "touch_pressed": "touch_pressed"},
    "bkm": {"X Axis": "P{player} X Axis", "Y Axis": "P{player} Y Axis"},
    "ltm": {name: name for name in [
        "left_x", "left_y", "right_x", "right_y", "trigger_left",
        "trigger_right", "mouse_x", "mouse_y", "mouse_wheel", "mouse_mode"]},
    "m64": {"X": "lstick_x", "Y": "lstick_y"},
    "dtm": {"TriggerL": "ltrigger", "TriggerR": "rtrigger",
            "AnalogStickX": "lstick_x", "AnalogStickY": "lstick_y",
            "CStickX": "rstick_x", "CStickY": "rstick_y",
            "accel_x": "accel_x", "accel_y": "accel_y", "accel_z": "accel_z",
            "id": "report_id", "core": "core_present",
            **{f"ir{k}_{part}": f"ir{k}_{part}" for k in range(1, 5)
               for part in ("x", "y", "size")},
            **{f"ext{j}": f"extension_byte{j}" for j in range(1, 22)}},
    "lsmv": {"xaxis": "gun_x", "yaxis": "gun_y", "xmotion": "mouse_x",
             "ymotion": "mouse_y"},
    "fm2": {"x": "gun_x", "y": "gun_y", "button": "gun_buttons",
            "bogo": "trigger_counter", "hit": "light_hit_ticks"},
    "jrsr": {"XMOUSEMOTION": "mouse_dx", "YMOUSEMOTION": "mouse_dy",
             "ZMOUSEMOTION": "mouse_wheel", "AXISA": "joystick_x_hold_ns",
             "AXISB": "joystick_y_hold_ns", "AXISC": "joystick_x_hold_ns",
             "AXISD": "joystick_y_hold_ns"},
    "lmp": {name: name for name in (
        "forwardmove", "sidemove", "angleturn", "look", "fly",
        "weaponselect", "has_special", "artifact", "suicide",
        "excmd_actions", "excmd_save_slot", "excmd_load_slot",
        "excmd_look")},
    "ctm": {"circle_pad_x": "circle_x", "circle_pad_y": "circle_y",
            "touch_x": "touch_x", "touch_y": "touch_y",
            "touch_valid": "touch_valid", "ir_rst_x": "ir_c_stick_x",
            "ir_rst_y": "ir_c_stick_y", "c_stick_x": "extra_c_stick_x",
            "c_stick_y": "extra_c_stick_y", "battery_level": "battery_level",
            **{f"{device}_{axis}": f"{device}_{axis}"
               for device in ("accelerometer", "gyroscope") for axis in "xyz"}},
    "gzm": {"x": "stick_x", "y": "stick_y"},
    "dft": {"mouse_x": "mouse_x", "mouse_y": "mouse_y"},
    "fm3": {"x": "gun_x", "y": "gun_y", "button": "gun_buttons",
            "bogo": "trigger_counter", "hit": "light_hit_ticks"},
    "pxm": {"left_x": "lstick_x", "left_y": "lstick_y", "right_x": "rstick_x",
            "right_y": "rstick_y"},
    "pjm": {"left_x": "lstick_x", "left_y": "lstick_y", "right_x": "rstick_x",
            "right_y": "rstick_y"},
}


# A .tas file is a BizHawk legacy text movie under another extension.
BUTTONS["tas"] = BUTTONS["bkm"]
NUMERIC["tas"] = NUMERIC["bkm"]


# Bits that replayr documents as retained in `commands` with their source value.
COMMAND_BITS = {
    "vbm": {"reset_old": 0x0400, "reset_new": 0x0800, "motion_left": 0x1000,
            "motion_right": 0x2000, "motion_down": 0x4000, "motion_up": 0x8000},
    "dsm": {"microphone": 1, "reset": 2, "lid": 4},
    "smv": {"reset": 1},
    "lsmv": {"reset": 1, "hard": 2},
    "dtm": {"disc": 1, "reset": 2},
    "jrsr": {"reset": 1},
    "omr": {"reset": 1},
    "gzm": {"reset": 1},
    "zmv": {"reset": 1},
}
# Format name -> replayr column name, for tables kept beside the controllers.
TABLE_COLUMNS = {
    "lsmv": {"subframes": {
        "line": "source_line", "framesync": "frame_start",
        "frame": "source_frame", "subframe": "subframe", "reset": "reset",
        "hard": "hard_reset", "rhigh": "reset_delay_high",
        "rlow": "reset_delay_low"}},
    "jrsr": {"events": {"time": "timestamp_ns"}},
    "omr": {"events": {"ticks": "timestamp_ticks",
                       "seconds": "timestamp_seconds"}},
    "ctm": {"poll_fields": {"pad": "observed_pad", "touch": "observed_touch",
                            "ir_rst": "observed_ir",
                            "extra_hid": "observed_extra_hid"}},
    "dtm": {"poll_fields": {
        "loading": "loading", "tunerEvent": "tuner_event", "LinkX": "link_x",
        "LinkZ": "link_z"}},
}
# replayr reports the stored high byte of Doom's 16-bit turning angle.
SCALES = {"lmp": {"angleturn": 256}}
# Formats whose channel names replayr keeps behind a fixed prefix.
PREFIXED = {"omr": "openmsx_"}
# A channel replayr leaves out holds this value throughout, or no value.
ABSENT_VALUES = {"dtm": {"core_present": 1}}
# Buttons that replayr keeps in `commands` when the controller lacks them.
BUTTON_COMMAND_BITS = {"vbm": {"r1": 0x0100, "l1": 0x0200}}


def slug(tag):
    """replayr's spelling of a port tag inside a column name."""
    out = "".join(c if c.isalnum() and c.isascii() else "_" if c in " _"
                  else "u%04x" % ord(c) for c in tag.strip().lower())
    return re.sub("_+", "_", out)


def mar_system(name):
    """replayr's column for a MAME-rr time, port word or system input."""
    if name == "seconds":
        return "time_seconds"
    if name.startswith("attoseconds_"):
        return "time_" + name
    if name.startswith(("default ", "digital ")):
        part, tag = name.split(" ", 1)
        return "port_%s_%s" % (slug(tag), part)
    found = re.fullmatch(r"IPT_COIN(\d+)", name)
    return "input_coin_" + found.group(1) if found else "input_" + name[4:].lower()


def mar_channel(name):
    kind, tag, part = name.split(" ")
    part = {"accum": "accumulator"}.get(part, part)
    return "%s_%s_%s" % (kind[4:].lower(), slug(tag), part)


def compare_fbm(row, notes, decoded, theirs, columns, m):
    """Compare every FB Alpha input with replayr's raw columns, in list order.

    replayr names a raw column after the owner and control it assigns; for
    a player's directions, fire buttons, Start and Select that name is
    checked as well. A column without the raw prefix repeats a raw one, as
    its value or, for a digital input, as the bit the drivers read.
    """
    raw = [c for c in columns if c.startswith("raw_")]
    listed = decoded["inputs"]
    if len(raw) != len(listed):
        notes.append(f"inputs differ: decoder {len(listed)}, replayr {len(raw)}")
        row["status"] = "differs"
    for (info, shown, values), column in zip(listed, raw):
        mine = theirs[:m, columns.index(column)]
        row["command_values"] += m
        row["command_differences"] += int((mine != values[:m]).sum())
        found = re.fullmatch(r"p(\d+) (up|down|left|right|start|select|fire (\d+))", info)
        if found:
            key = ("arcade_button_" + found.group(3) if found.group(3) else
                   found.group(2) if found.group(2) in ("start", "select")
                   else "dpad_" + found.group(2))
            if column != "raw_p%s_%s" % (found.group(1), key):
                notes.append(f"{info} is stored as {column}")
                row["status"] = "differs"
    for column in columns:
        if column.startswith("raw_"):
            continue
        source = "raw_system_" + column
        if source not in columns:
            notes.append(f"{column} has no raw column")
            row["status"] = "differs"
            continue
        mine = theirs[:m, columns.index(column)]
        base = theirs[:m, columns.index(source)]
        row["command_values"] += m
        # A switch keeps its value; a digital input is its bit 0.
        row["command_differences"] += int(
            min((mine != base).sum(), (mine != (base.astype("i8") & 1)).sum()))


def control_key(fmt, name):
    """replayr control key for a control named by the format description."""
    if name.startswith("keysym_"):
        return name
    if name.startswith("vk_"):
        return "windows_" + name
    if fmt == "jrsr" and name.startswith("key_"):
        return "jpcrr_" + name
    if fmt == "omr":
        return name
    return BUTTONS[fmt][name]


_OMR_PARTS = {"up": "dpad_up", "down": "dpad_down", "left": "dpad_left",
              "right": "dpad_right", "a": "a", "b": "b"}


def relocate(fmt, decoded, meta):
    """Arrange a decoder's controls as replayr arranges them.

    replayr returns controls that are not on a pad as console controls (the
    debug button and lid of a DS, two bits of the 3DS pad word, the spare
    bits of a 16-bit SNES pad report), and every openMSX device as a
    controller of its own with the control keys of its kind.
    """
    if fmt == "dsm":
        system = decoded.setdefault("system", {})
        system["debug"] = decoded["players"][0].pop("Debug")
        system["lid_closed"] = decoded["flags"]["lid"]
    elif fmt == "ctm":
        system = decoded.setdefault("system", {})
        for name in ("debug", "gpio14"):
            system[name] = decoded["players"][0].pop(name)
    elif fmt == "lsmv":
        for number, held in enumerate(decoded["players"], start=1):
            for bit in range(4):
                if "ext%d" % bit in held:
                    decoded.setdefault("system", {})["pad%d_ext%d" % (number, bit)] = held.pop("ext%d" % bit)
    elif fmt == "omr":
        held = decoded["players"][0]
        players, used = [], 0
        for device in meta.get("controllers", []):
            own = {}
            for name, values in held.items():
                if name.startswith("key_r"):
                    if device == "keyboard":
                        own["openmsx_" + name] = values
                    continue
                stem = ("joystick" + device.split("_")[1] if device.startswith("msxjoystate_")
                        else device)
                if name.startswith(stem + "_") and name[len(stem) + 1:] in _OMR_PARTS:
                    own[_OMR_PARTS[name[len(stem) + 1:]]] = values
            used += len(own)
            players.append(own)
        if used != len(held):
            raise NotCovered("a decoded openMSX control has no controller")
        decoded["system"] = {"openmsx_" + name: values
                             for name, values in decoded["numeric"][0].items()}
        decoded["players"] = players
        decoded["numeric"] = [{} for _ in players]


# Formats whose command value replayr keeps as recorded. For FCM replayr
# keeps one bit per control code of the frame.
COMMAND_VALUES = {"fm2": "command", "fcm": "controls", "gmv": "outside",
                  "mc2": "command", "ymv": "command", "fm3": "command",
                  "mcm": "command", "lmp": "special"}


def expected_commands(fmt, decoded):
    if fmt in COMMAND_VALUES:
        return decoded["flags"][COMMAND_VALUES[fmt]].astype("i8")
    if fmt not in COMMAND_BITS:
        return None
    total = np.zeros(decoded["n"], dtype="i8")
    for name, value in COMMAND_BITS[fmt].items():
        total += value * decoded["flags"][name].astype("i8")
    return total


def load_export(stem, meta):
    raw = np.fromfile(str(stem) + ".bin", dtype="u1")
    n, players, k = meta["n"], meta["players"], len(meta["keys"])
    # A controller without numeric channels is described by an empty list.
    listed = [c if isinstance(c, list) else [] for c in meta["channels"]]
    meta["channels"] = listed + [[] for _ in range(players - len(listed))]
    pos = 0
    states = []
    for _ in range(players):
        states.append(raw[pos:pos + n * k].reshape(k, n).T)
        pos += n * k
    numeric = []
    for p in range(players):
        c = len(meta["channels"][p])
        block = raw[pos:pos + 8 * n * c].view("<f8").reshape(c, n).T
        numeric.append(block)
        pos += 8 * n * c
    commands = raw[pos:pos + 4 * n].view("<i4")
    pos += 4 * n
    tables = {}
    for name in ("system", "timing", "subframes"):
        c = len(meta.get(name, []))
        tables[name] = raw[pos:pos + 8 * n * c].view("<f8").reshape(c, n).T
        pos += 8 * n * c
    # Per-poll fields keep source order, also where polls are grouped.
    c, polls = len(meta.get("poll_fields", [])), meta.get("poll_rows", 0)
    tables["poll_fields"] = raw[pos:pos + 8 * polls * c].view("<f8").reshape(c, polls).T
    pos += 8 * polls * c
    c, rows = len(meta.get("events", [])), meta.get("event_rows", 0)
    tables["events"] = raw[pos:pos + 8 * rows * c].view("<f8").reshape(c, rows).T
    pos += 8 * rows * c
    assert pos == raw.size, "export size does not match its description"
    return states, numeric, commands, tables


def compare_table(row, notes, label, expected, theirs, columns, m, strict=True):
    """Compare named per-observation columns outside the controllers.

    They are counted with the commands. A column replayr holds without a
    decoder source is expected to stay at zero, unless the table also keeps
    bookkeeping columns (strict is false).
    """
    for name, values in expected.items():
        if name not in columns:
            if np.asarray(values[:m]).any():
                notes.append(f"{label} {name} is absent")
                row["command_values"] += m
                row["command_differences"] += int((np.asarray(values[:m]) != 0).sum())
            continue
        mine = theirs[:m, columns.index(name)]
        row["command_values"] += m
        row["command_differences"] += int(
            (~np.isclose(mine, values[:m], equal_nan=True)).sum())
    for column, name in enumerate(columns):
        if strict and name not in expected:
            row["command_values"] += m
            row["command_differences"] += int((theirs[:m, column] != 0).sum())


def compare(meta, stem, root):
    fmt = meta["format"]
    row = {"sha256": meta["sha256"], "publication_id": meta["publication_id"],
           "format": fmt, "observations": meta["n"], "controllers": meta["players"],
           "button_values": 0, "button_differences": 0, "numeric_values": 0,
           "numeric_differences": 0, "command_values": 0,
           "command_differences": 0, "status": "", "note": ""}
    notes = []
    try:
        if fmt == "fbm":
            # The file does not name its game; the reader was given it.
            decoded = DECODERS[fmt](root / meta["relative_path"],
                                    meta["header"].get("game"))
        elif fmt == "lmp":
            # What the reader was told about a file that does not say it.
            told = meta.get("arguments") or {}
            decoded = DECODERS[fmt](root / meta["relative_path"],
                                    told.get("game"), told.get("longtics"))
        else:
            decoded = DECODERS[fmt](root / meta["relative_path"])
    except NotCovered as reason:
        row["status"] = "not covered"
        row["note"] = str(reason)
        return row
    try:
        relocate(fmt, decoded, meta)
    except NotCovered as reason:
        row["status"] = "not covered"
        row["note"] = str(reason)
        return row
    states, numeric, commands, tables = load_export(stem, meta)
    n = meta["n"]
    if decoded["n"] != n:
        if decoded["declared"] == n and n <= decoded["n"]:
            notes.append(f"header count {n} of {decoded['n']} stored records")
        else:
            notes.append(f"count differs: decoder {decoded['n']}, declared "
                         f"{decoded['declared']}, replayr {n}")
            row["status"] = "differs"
    m = min(n, decoded["n"])
    if len(decoded["players"]) != meta["players"]:
        notes.append(f"controllers differ: decoder {len(decoded['players'])}")
        row["status"] = "differs"
    keys = meta["keys"]
    checked = set()
    outside = np.zeros(decoded["n"], dtype="i8")
    for p in range(min(len(decoded["players"]), meta["players"])):
        # Controls that share a replayr key are combined, as replayr documents.
        expected = {}
        for name, values in decoded["players"][p].items():
            key = control_key(fmt, name)
            expected[key] = values if key not in expected else expected[key] | values
        for key, (kind, source) in DERIVED.get(fmt, {}).items():
            expected[key] = (decoded["flags"][source] if kind == "flag" else
                             (decoded["numeric"][p][source] != 0).astype("u1"))
        for key, values in expected.items():
            if key in keys:
                continue
            if key in BUTTON_COMMAND_BITS.get(fmt, {}):
                outside[:m] |= BUTTON_COMMAND_BITS[fmt][key] * values[:m].astype("i8")
            elif values[:m].any():
                row["button_values"] += m
                row["button_differences"] += int(values[:m].sum())
                notes.append(f"{key} is active but absent from the layout")
        # Every column of every controller is compared; a control the decoder
        # does not report for this controller is expected to stay unset.
        for column, key in enumerate(keys):
            values = expected.get(key)
            if values is None:
                values = np.zeros(decoded["n"], dtype="u1")
            else:
                checked.add(key)
            theirs = states[p][:m, column]
            row["button_values"] += m
            row["button_differences"] += int((theirs != values[:m]).sum())
        sourced = set()
        for name, values in decoded["numeric"][p].items():
            channel = (mar_channel(name) if fmt == "mar" else
                       PREFIXED[fmt] + name if fmt in PREFIXED else
                       NUMERIC[fmt][name].format(player=p + 1))
            mine = (np.asarray(values[:m], dtype="f8")
                    / SCALES.get(fmt, {}).get(name, 1))
            if channel not in meta["channels"][p]:
                # An absent device has no channels; its values must be defaults.
                default = ABSENT_VALUES.get(fmt, {}).get(channel, 0)
                if ((mine != default) & ~np.isnan(mine)).any():
                    notes.append(f"channel {channel} is absent")
                    row["status"] = "differs"
                continue
            sourced.add(channel)
            theirs = numeric[p][:m, meta["channels"][p].index(channel)]
            row["numeric_values"] += m
            # A value missing on both sides agrees.
            same = (theirs == mine) | (np.isnan(theirs) & np.isnan(mine))
            row["numeric_differences"] += int((~same).sum())
        unsourced = [c for c in meta["channels"][p] if c not in sourced]
        if unsourced and (fmt in NUMERIC or fmt in PREFIXED or fmt == "mar"):
            notes.append("channel never set in the file: " + " ".join(unsourced))
            # Such a channel was never set in the file: zero, or no value.
            for channel in unsourced:
                theirs = numeric[p][:m, meta["channels"][p].index(channel)]
                row["numeric_values"] += m
                row["numeric_differences"] += int(
                    ((theirs != 0) & ~np.isnan(theirs)).sum())
    unchecked = [key for key in keys if key not in checked]
    if unchecked:
        notes.append("control never set in the file: " + " ".join(unchecked))
    expected = expected_commands(fmt, decoded)
    if expected is not None:
        expected = expected | outside
        row["command_values"] = m
        row["command_differences"] = int((commands[:m] != expected[:m]).sum())
    # Console commands, frame timing, subframe structure and per-frame flags.
    if fmt == "fbm":
        compare_fbm(row, notes, decoded, tables["system"], meta.get("system", []), m)
    for label in ("system", "timing", "subframes", "poll_fields", "events"):
        if fmt == "fbm" and label == "system":
            continue
        if label in decoded or meta.get(label):
            source = decoded.get(label, {})
            names = TABLE_COLUMNS.get(fmt, {}).get(label)
            if names:
                source = {names[name]: values for name, values in source.items()}
            if fmt == "mar":
                source = {mar_system(name): values for name, values in source.items()}
            compare_table(row, notes, label, source, tables[label],
                          meta.get(label, []), min(m, tables[label].shape[0]),
                          strict=label not in ("poll_fields", "events"))
    if "flag_text" in decoded:
        theirs = [""] * n
        for position, value in zip(meta.get("flag_rows", []), meta.get("flag_values", [])):
            theirs[position - 1] = value
        row["command_values"] += m
        row["command_differences"] += sum(
            a != b for a, b in zip(theirs[:m], decoded["flag_text"][:m]))
    differences = (row["button_differences"] + row["numeric_differences"]
                   + row["command_differences"])
    if differences or row["status"] == "differs":
        row["status"] = "differs"
    else:
        row["status"] = "agrees"
    row["note"] = "; ".join(notes)
    return row


def main():
    export, target = Path(sys.argv[1]), Path(sys.argv[2])
    root = Path(os.environ["REPLAYR_VALIDATION_ROOT"])
    rows = []
    for description in sorted(export.glob("*.json")):
        meta = json.loads(description.read_text(encoding="utf-8"))
        if meta["format"] not in DECODERS:
            continue
        rows.append(compare(meta, description.with_suffix(""), root))
    rows.sort(key=lambda r: (r["format"], int(r["publication_id"])))
    with target.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    for fmt in sorted({r["format"] for r in rows}):
        part = [r for r in rows if r["format"] == fmt]
        print(fmt, "recordings", len(part),
              "agree", sum(r["status"] == "agrees" for r in part),
              "differ", sum(r["status"] == "differs" for r in part),
              "not covered", sum(r["status"] == "not covered" for r in part),
              "values", sum(r["button_values"] + r["numeric_values"]
                            + r["command_values"] for r in part))


if __name__ == "__main__":
    main()
