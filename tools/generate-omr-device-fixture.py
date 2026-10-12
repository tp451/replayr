"""Generate an original openMSX device demonstration and independent expectations.

Field names and bit identities follow openMSX commit
f07bee985b8e2102c47913c217ad0365638bf8ae, src/input/StateChange.hh,
JoyMega.cc, JoyHandle.cc, Trackball.cc, Paddle.cc, Touchpad.cc,
ArkanoidPad.cc, LightGun.hh, Gunstick.cc, TerminatorLaser.cc, and
JoystickDevice.hh. Source: https://github.com/openMSX/openMSX/tree/
f07bee985b8e2102c47913c217ad0365638bf8ae/src/input

The programmed actions and values below are original. No emulator source,
game content, or third-party recording is included. These are input event
semantics; emulator cursor smoothing and paddle limits are not simulated.
"""

from pathlib import Path
import gzip, json, xml.etree.ElementTree as ET

repo = Path(__file__).resolve().parents[1]
root = repo / "inst/extdata/computers"
root.mkdir(parents=True, exist_ok=True)
serial = ET.Element("serial")
replay = ET.SubElement(serial, "replay", version="4")
snap = ET.SubElement(ET.SubElement(replay, "snapshots"), "item")
ET.SubElement(snap, "name").text = "Artificial peripheral demonstration"
clock = ET.SubElement(ET.SubElement(snap, "scheduler"), "currentTime")
ET.SubElement(clock, "time").text = "0"
events = ET.SubElement(replay, "events")
expected = []


def event(kind, label, **fields):
    row = len(expected) + 1
    time = row * 1234567
    node = ET.SubElement(events, "item", type=kind)
    base = ET.SubElement(node, "StateChange")
    t = ET.SubElement(base, "time")
    ET.SubElement(t, "time").text = str(time)
    for key, value in fields.items():
        ET.SubElement(node, key).text = (
            str(value).lower() if isinstance(value, bool) else str(value)
        )
    expected.append({"row": row, "time": time, "type": kind, "action": label, **fields})


event(
    "TrackballState", "move northwest, hold A", deltaX=-7, deltaY=3, press=16, release=0
)
event("PaddleState", "turn paddle clockwise while trackball A remains held", delta=13)
event(
    "TrackballState",
    "reverse motion, exchange A for B",
    deltaX=2,
    deltaY=-5,
    press=32,
    release=16,
)
event("TrackballState", "release B", deltaX=0, deltaY=0, press=0, release=32)
event("PaddleState", "turn paddle back", delta=-9)
event("TouchpadState", "touch first coordinate", x=23, y=201, touch=True, button=False)
event("TouchpadState", "button without contact", x=211, y=47, touch=False, button=True)
event(
    "TouchpadState", "touch and button together", x=87, y=139, touch=True, button=True
)
event("TouchpadState", "release both", x=91, y=137, touch=False, button=False)

# JoyMega::signalMSXEvent emits a bit per binding in this exact order.
names = ["up", "down", "left", "right", "a", "b", "c", "start", "x", "y", "z", "mode"]
for bit, name in enumerate(names):
    event("JoyMegaState", "hold " + name, id=2, press=1 << bit, release=0)
    event("JoyMegaState", "release " + name, id=2, press=0, release=1 << bit)

# JoyHandle uses the standard six digital positions and an independent float.
for bit, (name, value) in enumerate(
    zip(["up", "down", "left", "right", "a", "b"], [-0.75, 0.25, 1, -1, 0.125, -0.5])
):
    event(
        "JoyHandleState",
        "hold " + name + " and set wheel",
        id=3,
        press=1 << bit,
        release=0,
        analog=value,
    )
    event(
        "JoyHandleState",
        "release " + name + " and centre wheel",
        id=3,
        press=0,
        release=1 << bit,
        analog=0,
    )

event(
    "ArkanoidState", "turn dial and hold button", delta=-17, press=True, release=False
)
event(
    "ArkanoidState",
    "turn dial back and release button",
    delta=5,
    press=False,
    release=True,
)

# Exact pin-derived statuses: Gunstick light is low, Terminator light is high.
for device, states in [(0, [63, 47, 61, 45, 63]), (1, [47, 15, 63, 31, 47])]:
    for label, status in zip(
        ["idle", "trigger", "light", "trigger and light", "idle"], states
    ):
        event("LightGunState", label, id=device, status=status)
event("EndLog", "end")
data = ET.tostring(serial, encoding="utf-8", xml_declaration=True)
(root / "peripheral-events.omr").write_bytes(gzip.compress(data, mtime=0))
(root / "peripheral-events-expected.json").write_text(
    json.dumps(expected, indent=2), encoding="utf-8"
)
print("Generated", len(expected), "original peripheral events.")
