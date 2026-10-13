"""Generate original pointer and motion examples for replayr.

Run from any directory. These programmed inputs illustrate recorded fields;
they were not copied from a game recording or measured from a physical device.
Wii layout: Dolphin DesiredWiimoteState.cpp, SerializeDesiredState.
https://github.com/dolphin-emu/dolphin/blob/e2ad09306e6d371f7272205bdc363da9fe05fe08/Source/Core/Core/HW/WiimoteEmu/DesiredWiimoteState.cpp
Mouse fields: BizHawk Saturnus mouse, named BK2 LogKey columns.
"""

from pathlib import Path
import csv
import struct
import zipfile

root = Path(__file__).resolve().parents[1] / "inst" / "extdata" / "paper"
root.mkdir(parents=True, exist_ok=True)


def camera_point(x, y, size):
    return bytes((x & 255, y & 255, (size & 15) | ((x >> 8) << 4) | ((y >> 8) << 6)))


def gyro_axis(value, slow):
    return bytes((value & 255, (value >> 8) | (128 if slow else 0)))


body = bytearray()
expected = []
for i in range(180):
    # Pointing starts after a stationary interval; A is held during the sweep.
    sweep = 60 <= i < 120
    a = int(sweep)
    accel_x = 512 + (
        4 * (i - 120) if 120 <= i < 140 else 4 * (160 - i) if 140 <= i < 160 else 0
    )
    accel_y, accel_z = 512, 616
    ir_x = 256 if i < 60 else 256 + 8 * (i - 60) if sweep else 728
    ir_y = 384
    pitch = 8192 + (8 * (i - 120) if 120 <= i < 150 else 0)
    roll = 8192 - (4 * (i - 120) if 120 <= i < 150 else 0)
    yaw = 8600 if sweep else 8192
    # All three axes use the slow range throughout this example.
    low = (accel_x & 3) | (((accel_y >> 1) & 1) << 2) | (((accel_z >> 1) & 1) << 3)
    packet = bytearray((15, a, low << 4, accel_x >> 2, accel_y >> 2, accel_z >> 2))
    packet += camera_point(ir_x, ir_y, 4) + camera_point(ir_x + 32, ir_y, 4)
    packet += bytes([255] * 6)  # Points 3 and 4 are absent.
    packet += gyro_axis(pitch, True) + gyro_axis(roll, True) + gyro_axis(yaw, True)
    assert len(packet) == 24
    body += bytes([len(packet)]) + packet
    expected.append(
        (i + 1, a, accel_x, accel_y, accel_z, ir_x, ir_y, pitch, roll, yaw, 1, 1, 1)
    )

header = bytearray(256)
header[:4] = b"DTM\x1a"
header[4:10] = b"ARTW01"
header[10:12] = bytes((1, 16))
struct.pack_into("<Q", header, 13, 180)
struct.pack_into("<Q", header, 21, 180)
(root / "wii-motion.dtm").write_bytes(header + body)
with (root / "wii-motion-expected.csv").open(
    "w", newline="", encoding="ascii"
) as stream:
    writer = csv.writer(stream)
    writer.writerow(
        (
            "poll",
            "a",
            "accel_x",
            "accel_y",
            "accel_z",
            "ir1_x",
            "ir1_y",
            "gyro_pitch",
            "gyro_roll",
            "gyro_yaw",
            "gyro_pitch_slow",
            "gyro_roll_slow",
            "gyro_yaw_slow",
        )
    )
    writer.writerows(expected)

rows = []
for i in range(240):
    if i < 60:
        dx, dy, left = 2, i % 2, False
    elif i < 120:
        dx, dy, left = 1, -(i % 2), True
    elif i < 180:
        dx, dy, left = -2, 0, False
    else:
        dx, dy, left = 0, 0, False
    rows.append(f'|..|{dx},{dy},{"L" if left else "."}...|')
members = {
    "Header.txt": "\n".join(
        (
            "MovieVersion BizHawk synthetic",
            "Platform SAT",
            "Core Saturnus",
            "GameName Artificial mouse drag",
            "Author Thorben Pelzer",
        )
    )
    + "\n",
    "Input Log.txt": "\n".join(
        (
            "[Input]",
            "LogKey:#Power|Reset|#P1 Motion Left / Right|P1 Motion Up / Down|P1 Left Button|P1 Middle Button|P1 Right Button|P1 Start|",
            *rows,
            "[/Input]",
        )
    )
    + "\n",
}
with zipfile.ZipFile(root / "mouse-drag.bk2", "w") as archive:
    for name, text in members.items():
        info = zipfile.ZipInfo(name, (2020, 1, 1, 0, 0, 0))
        archive.writestr(info, text)
(root / "motion-examples.txt").write_text(
    """Original mouse and Wii motion examples

These inputs were authored for replayr and are licensed under GPL (>= 2).
No third-party recording was used to generate them.

mouse-drag.bk2 has 240 observations in the Saturnus mouse layout: movement
with the button released, a 60-observation left-button drag, a return with
the button released, and a pause. The numeric fields are relative increments.

wii-motion.dtm has 180 serialized Wii Remote observations: two infrared
points move horizontally while A is held, then an acceleration pulse and
separate pitch/roll changes illustrate motion channels. Gyroscope fields
are counts in the slow range. The values specify an input sequence, with
no claim to reproduce a physical gesture or a game's response.
wii-motion-expected.csv gives the expected decoded values. Y/Z acceleration
is stored in nine bits and widened to ten as Dolphin widens it, by repeating
the lowest stored bit.
Infrared points 3 and 4 are absent, encoded as 1023, 1023, and size 15.

Regenerate from the package root:
  python tools/generate-motion-examples.py
""",
    encoding="ascii",
)
print("Generated original Wii motion and mouse-drag examples.")
