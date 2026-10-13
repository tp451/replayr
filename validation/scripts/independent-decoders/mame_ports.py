"""Input-port tables of MAME-rr games, read from the driver sources.

Usage: python mame_ports.py <directory with driver sources> <output.json>
       [game name ...]

With game names, only the tables of those games are written.

A MAR recording stores, for every input port of the game, the port's default
word and the word of pressed digital inputs, followed by the state of each
analog field (src/emu/ioport.c: record_frame, record_port,
set_bytes_per_frame). Which ports a game has, in which order, and what each
bit means is defined by the INPUT_PORTS block of its driver. This script
reads those blocks from the sources of TASEmulators/mame-rr at revision
9b6b2f76a50994ca86f78610f6f5123a3ec9ebd8 (mame-rr/src/mame/drivers/*.c and
mame-rr/src/mame/includes/konamipt.h) and writes one table per game. It
follows ioport.h (the PORT_ macros and the list of analog types) and
ioport.c (field_config_insert: a new field takes its bits from earlier
fields of the same port and condition; fields are kept in order of their
lowest bit). No replayr file is read.
"""

import json
import re
import sys
from pathlib import Path

ANALOG = {"IPT_AD_STICK_X", "IPT_AD_STICK_Y", "IPT_AD_STICK_Z", "IPT_PADDLE",
          "IPT_PADDLE_V", "IPT_PEDAL", "IPT_PEDAL2", "IPT_PEDAL3",
          "IPT_LIGHTGUN_X", "IPT_LIGHTGUN_Y", "IPT_POSITIONAL",
          "IPT_POSITIONAL_V", "IPT_DIAL", "IPT_DIAL_V", "IPT_TRACKBALL_X",
          "IPT_TRACKBALL_Y", "IPT_MOUSE_X", "IPT_MOUSE_Y"}
# Macros that start a field: positions of mask and default, and the type.
FIELDS = {
    "PORT_BIT": (0, 1, None),
    "PORT_DIPNAME": (0, 1, "IPT_DIPSWITCH"),
    "PORT_DIPUNUSED": (0, 1, "IPT_DIPSWITCH"),
    "PORT_DIPUNUSED_DIPLOC": (0, 1, "IPT_DIPSWITCH"),
    "PORT_DIPUNKNOWN": (0, 1, "IPT_DIPSWITCH"),
    "PORT_DIPUNKNOWN_DIPLOC": (0, 1, "IPT_DIPSWITCH"),
    "PORT_CONFNAME": (0, 1, "IPT_CONFIG"),
    "PORT_SERVICE": (0, 1, "IPT_SERVICE"),
    "PORT_SERVICE_NO_TOGGLE": (0, 1, "IPT_SERVICE"),
    "PORT_SERVICE_DIPLOC": (0, 1, "IPT_SERVICE"),
}
_TOKEN = re.compile(r'"(?:\\.|[^"\\])*"|/\*.*?\*/|//[^\n]*', re.S)
_NUMBER = re.compile(r"^[0-9a-fA-FxX\s()|&~<>+*-]+$")


def clean(text):
    """Remove comments, keep string literals, join continued lines."""
    text = _TOKEN.sub(lambda m: m.group(0) if m.group(0).startswith('"') else " ", text)
    return text.replace("\\\r\n", " ").replace("\\\n", " ")


def arguments(text, start):
    """Arguments of a call whose opening parenthesis is at start."""
    depth, parts, piece, i, quoted = 0, [], "", start, False
    while True:
        ch = text[i]
        if quoted:
            piece += ch
            if ch == "\\":
                i += 1
                piece += text[i]
            elif ch == '"':
                quoted = False
        elif ch == '"':
            quoted = True
            piece += ch
        elif ch == "(":
            depth += 1
            if depth > 1:
                piece += ch
        elif ch == ")":
            depth -= 1
            if depth == 0:
                parts.append(piece.strip())
                return parts, i + 1
            piece += ch
        elif ch == "," and depth == 1:
            parts.append(piece.strip())
            piece = ""
        else:
            piece += ch
        i += 1


def definitions(text):
    """Macros whose body holds port macros: name -> (parameters, body)."""
    found = {}
    for match in re.finditer(r"^[ \t]*#define[ \t]+(\w+)(\(([^)]*)\))?[ \t]+(.*)$", text, re.M):
        name, call, parameters, body = match.groups()
        if "PORT_" in body or any(other in body for other in found):
            names = [p.strip() for p in parameters.split(",")] if call else None
            found[name] = (names, body)
    return found


def expand(text, macros):
    """Replace uses of the collected macros until none is left."""
    pattern = re.compile(r"\b(" + "|".join(map(re.escape, macros)) + r")\b") if macros else None
    for _ in range(20):
        if pattern is None:
            break
        out, pos, changed = [], 0, False
        for match in pattern.finditer(text):
            if match.start() < pos:
                continue
            names, body = macros[match.group(1)]
            end = match.end()
            if names is not None:
                rest = re.match(r"\s*\(", text[end:])
                if not rest:
                    continue
                values, end = arguments(text, end + rest.end() - 1)
                for name, value in zip(names, values):
                    body = re.sub(r"\b%s\b" % re.escape(name), value, body)
                # "##" joins the tokens on either side.
                body = re.sub(r"\s*##\s*", "", body)
            out.append(text[pos:match.start()])
            out.append(" " + body + " ")
            pos, changed = end, True
        out.append(text[pos:])
        text = "".join(out)
        if not changed:
            break
    return text


def number(text):
    text = text.replace("IP_ACTIVE_LOW", "0xffffffff").replace("IP_ACTIVE_HIGH", "0")
    if not _NUMBER.match(text):
        raise ValueError("not a number: " + text)
    return int(eval(text, {"__builtins__": {}})) & 0xFFFFFFFF


def low_bit(mask):
    return (mask & -mask).bit_length()


def insert(fields, field):
    """Add a field as ioport.c does."""
    for other in list(fields):
        if other["condition"] == field["condition"] and other["mask"] & field["mask"]:
            other["mask"] &= ~field["mask"]
            other["default"] &= other["mask"]
            if not other["mask"]:
                fields.remove(other)
    at = len(fields)
    for index, other in enumerate(fields):
        if low_bit(field["mask"]) < low_bit(other["mask"]):
            at = index
            break
    fields.insert(at, field)


def build(name, blocks, ports):
    """Interpret one INPUT_PORTS block into the ordered port table."""
    body = blocks[name]
    port, field = None, None
    for match in re.finditer(r"\bPORT_\w+\b", body):
        macro, after = match.group(0), body[match.end():]
        opened = re.match(r"\s*\(", after)
        values = arguments(body, match.end() + opened.end() - 1)[0] if opened else []
        if macro == "PORT_INCLUDE":
            build(values[0], blocks, ports)
            port, field = None, None
        elif macro in ("PORT_START", "PORT_MODIFY"):
            tag = values[0].strip('"')
            port = ports.setdefault(tag, [])
            field = None
        elif macro in FIELDS:
            at_mask, at_default, kind = FIELDS[macro]
            mask = number(values[at_mask])
            field = {"mask": mask, "default": number(values[at_default]) & mask,
                     "type": kind or values[2].strip(), "player": 1, "condition": None}
            if mask:
                insert(port, field)
        elif macro == "PORT_ADJUSTER":
            field = {"mask": 0xFF, "default": number(values[0]) & 0xFF,
                     "type": "IPT_ADJUSTER", "player": 1, "condition": None}
            insert(port, field)
        elif macro == "PORT_PLAYER" and field is not None:
            field["player"] = number(values[0])
        elif macro == "PORT_COCKTAIL" and field is not None:
            field["player"] = 2
        elif macro == "PORT_CONDITION" and field is not None:
            # The condition belongs to the field; test its overlaps again.
            if field in port:
                port.remove(field)
            field["condition"] = [values[0].strip('"'), number(values[1]),
                                  values[2].strip(), number(values[3])]
            insert(port, field)
    return ports


def main():
    source, target = Path(sys.argv[1]), Path(sys.argv[2])
    shared = ""
    for header in sorted(source.glob("*.h")):
        if header.name != "ioport.h":
            shared += clean(header.read_text(encoding="latin-1")) + "\n"
    tables = {}
    for driver in sorted(source.glob("*.c")):
        if driver.name == "ioport.c":
            continue
        text = clean(driver.read_text(encoding="latin-1"))
        text = expand(text, definitions(shared + text))
        blocks = {m.group(1): m.group(2) for m in re.finditer(
            r"INPUT_PORTS_START\(\s*(\w+)\s*\)(.*?)INPUT_PORTS_END", text, re.S)}
        for game in re.finditer(r"\bGAME[A-Z]*\(([^;]*?)\)\s*$", text, re.M):
            parts = [p.strip() for p in game.group(1).split(",")]
            if len(parts) < 6 or parts[4] not in blocks:
                continue
            ports = build(parts[4], blocks, {})
            tables[parts[1]] = {"source": driver.name, "ports": [
                {"tag": tag, "fields": [dict(f, analog=f["type"] in ANALOG) for f in fields]}
                for tag, fields in ports.items()]}
    wanted = sys.argv[3:]
    if wanted:
        tables = {game: tables[game] for game in wanted}
    target.write_text(json.dumps(tables, indent=1), encoding="utf-8")
    print(len(tables), "games")


if __name__ == "__main__":
    main()
