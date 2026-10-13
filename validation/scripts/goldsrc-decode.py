"""A separate decoder of GoldSrc demos, written from the public layout: the
frame container as hldemo-rs documents it and the command of the Half-Life
SDK (common/usercmd.h, common/in_buttons.h). It shares no code with replayr.
For each demo it writes the values of every command frame and the console
commands, for comparison with what replayr returns.
Usage: python -I goldsrc-decode.py <folder with demos> <folder for the output>"""
import csv
import json
import pathlib
import struct
import sys

FIXED = {2: 0, 3: 64, 4: 32, 5: 0, 6: 84, 7: 8}


def frames(data, offset, ended=None):
    """The frames of one section: (type, seconds, frame number, place of the data).
    The place after a section that is closed is put into `ended`."""
    before_length = info_bytes(data) + 28
    at = offset
    while at + 9 <= len(data):
        kind, seconds, number = struct.unpack_from("<Bfi", data, at)
        if kind > 9:
            raise ValueError("frame type %d" % kind)
        payload = at + 9
        if kind in FIXED:
            size = FIXED[kind]
        elif kind == 8:
            if payload + 8 > len(data):
                return
            size = 24 + struct.unpack_from("<i", data, payload + 4)[0]
        elif kind == 9:
            if payload + 4 > len(data):
                return
            size = 4 + struct.unpack_from("<i", data, payload)[0]
        else:
            if payload + before_length + 4 > len(data):
                return
            message = struct.unpack_from("<i", data, payload + before_length)[0]
            if not 0 <= message <= 65536:  # the engine's limit
                raise ValueError("network message length %d" % message)
            size = before_length + 4 + message
        if payload + size > len(data):
            return
        yield kind, seconds, number, payload
        at = payload + size
        if kind == 5:
            if ended is not None:
                ended.append(at)
            return


def info_bytes(data):
    """The size of the block that a network-message frame holds before its
    seven sequence numbers: 436 bytes, and 532 in demos up to network
    protocol 43, whose engine writes the command and 13 movement variables
    twice (the size as in the compLexity Demo Player's parser)."""
    return 532 if struct.unpack_from("<i", data, 12)[0] <= 43 else 436


def decode(data):
    if data[:8] != b"HLDEMO\x00\x00":
        raise ValueError("no HLDEMO signature")
    protocol = struct.unpack_from("<i", data, 8)[0]
    if protocol != 5:
        raise ValueError("demo protocol %d" % protocol)
    if len(data) < 544:
        raise ValueError("header")
    directory = struct.unpack_from("<i", data, 540)[0]
    offsets = None
    if directory != 0:
        if directory < 544:
            raise ValueError("directory")
        if directory + 4 <= len(data):
            count = struct.unpack_from("<i", data, directory)[0]
            if not 1 <= count <= 1024:
                raise ValueError("directory")
            if directory + 4 + 92 * count <= len(data):
                offsets = [struct.unpack_from("<i", data, directory + 4 + 92 * i + 84)[0] for i in range(count)]
                if any(not 544 <= offset < len(data) for offset in offsets):
                    raise ValueError("section outside the file")
    if offsets is None:
        # A demo that was not closed names no directory, and a file that was
        # cut short does not hold all of it. Their sections follow one
        # another from the end of the header, up to where the directory
        # would begin.
        limit = min(directory, len(data)) if directory else len(data)
        offsets = [544]
        while True:
            ended = []
            for _ in frames(data, offsets[-1], ended):
                pass
            if not ended or ended[0] + 9 > limit:
                break
            offsets.append(ended[0])
    rows, spoken = [], []
    for index, offset in enumerate(offsets):
        for kind, seconds, number, payload in frames(data, offset):
            if kind == 3:
                text = data[payload:payload + 64].split(b"\0")[0].decode("latin-1")
                spoken.append([index + 1, repr(seconds), number, text])
            if kind < 2:
                # The command ends 16 bytes of view and the movement variables
                # (13 floats in the older block, 33 in the later one) before
                # the end of the block.
                older = info_bytes(data) == 532
                cmd = payload + info_bytes(data) - 16 - (13 if older else 33) * 4 - 52
                msec = data[cmd + 2]
                pitch, yaw, roll, forward, side, up = struct.unpack_from("<6f", data, cmd + 4)
                buttons, impulse, weapon = struct.unpack_from("<HBB", data, cmd + 30)
                rows.append([index + 1, repr(seconds), number, int(kind == 0), buttons] +
                            [repr(v) for v in (forward, side, up, pitch, yaw, roll)] + [impulse, weapon, msec])
    return rows, spoken


source = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
for path in sorted(source.glob("*.dem")):
    # What an earlier run wrote for this demo does not stay beside the new result.
    for ending in (".error", ".csv", ".commands.json"):
        (out / (path.name + ending)).unlink(missing_ok=True)
    try:
        rows, spoken = decode(path.read_bytes())
    except (ValueError, struct.error) as error:
        (out / (path.name + ".error")).write_text(str(error), encoding="utf-8")
        print("%-36s refused: %s" % (path.name, error))
        continue
    with open(out / (path.name + ".csv"), "w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["section", "seconds", "frame", "start", "buttons", "forwardmove", "sidemove", "upmove",
                         "view_pitch", "view_yaw", "view_roll", "impulse", "weaponselect", "msec"])
        writer.writerows(rows)
    (out / (path.name + ".commands.json")).write_text(json.dumps(spoken), encoding="utf-8")
    print("%-36s %6d command frames, %6d console commands" % (path.name, len(rows), len(spoken)))
