"""Generate seven original recordings for source-defined control identity tests.

Run with Python 3 from any directory. Only the standard library is required.
No emulator, ROM, downloaded recording, or replayr implementation is used.
The matching R tests state the expected physical controls independently.

Wire-format sources (bit positions are zero based):
FMV: https://tasvideos.org/EmulatorResources/Famtasia/FMV
FCM: FCEUX ce042d758a08f9434a6625580b2cc72495e8aa9a,
     src/oldmovie.cpp (event delays/toggles), src/fceu.h (JOY_* masks).
SMV: TASEmulators/snes9x-rr 450b6cba06996046f31ccc08561b258af75f4e35,
     snes9x.h (SNES_*_MASK), movie.cpp (controller word serialization).
GMV: TASEmulators/gens-rerecording 53601d3b2c601c367aacb6355fa1c0282174cf1e,
     Gens-rr/src/movie.cpp (ReadInControllers and WriteOutControllers).
M64: mupen64/mupen64-rr-lua d3e7a15745478084bb2feb76a2f8e990357d2a0f,
     src/Core/include/Core/Types.hpp (CoreButtons),
     src/Common.Win32/include/Common.Win32/JoystickControl.hpp (Y orientation).
PJM: Nitrofski/psxjin 534fd3856913c3198e649806a91db5c232e4d34a,
     psxjin/movie.cpp (MOV_WriteJoy), Win32/resource.h (button indices).
PXM: TASEmulators/pcsxrr 1b4c66d6a2938da55761280617d288f3c65870d7,
     pcsxrr/movie.cpp (binary controller words and stick coordinates).
"""

from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1] / "inst" / "extdata" / "semantic"


def u32(header, offset, value):
    struct.pack_into("<I", header, offset, value)


def write(extension, header, body):
    (ROOT / ("semantic-onehot." + extension)).write_bytes(header + body)


def main():
    ROOT.mkdir(parents=True, exist_ok=True)

    # FMV: right, left, up, down, B, A, Select, Start; then run + jump right.
    header = bytearray(144)
    header[:4] = b"FMV\x1a"
    header[5] = 128  # Only controller one is recorded.
    write("fmv", header, bytes([0] + [1 << bit for bit in range(8)] + [1 + 16 + 32]))

    # FCM: neutral, bits 0..7 separately, then A + B + right. A delta precedes
    # each new sample; subsequent toggles at the same sample have zero delay.
    words = [0] + [1 << bit for bit in range(8)] + [1 + 2 + 128]
    body = bytearray()
    previous = 0
    for sample, word in enumerate(words):
        changed = previous ^ word
        first_change = True
        for bit in range(8):
            if changed & (1 << bit):
                delayed = sample > 0 and first_change
                body += bytes([bit + (32 if delayed else 0)])
                if delayed:
                    body += bytes([1])
                first_change = False
        previous = word
    body += bytes([0xA0, 1])  # No-op command after the last sample.
    header = bytearray(64)
    header[:4] = b"FCM\x1a"
    u32(header, 4, 2)
    u32(header, 12, len(words))
    u32(header, 20, len(body))
    u32(header, 28, 64)
    write("fcm", header, body)

    # SMV: neutral, the twelve SNES controls in bits 4..15, then right + Y + B.
    words = (
        [0] + [1 << bit for bit in range(4, 16)] + [(1 << 8) | (1 << 14) | (1 << 15)]
    )
    header = bytearray(32)
    header[:4] = b"SMV\x1a"
    u32(header, 4, 1)
    header[20] = 1
    u32(header, 16, len(words) - 1)  # SMV includes the initial controller sample.
    u32(header, 28, 32)
    write("smv", header, struct.pack("<" + "H" * len(words), *words))

    # GMV is active low. Byte three contains separate X/Y/Z/Mode nibbles for
    # the two six-button pads. Finish with controller one's right + C chord.
    records = [(255, 255, 255)]
    records += [(255 ^ (1 << bit), 255, 255) for bit in range(8)]
    records += [(255, 255, 255 ^ (1 << bit)) for bit in range(8)]
    records += [(255 ^ 8 ^ 64, 255, 255)]
    header = bytearray(64)
    header[:16] = b"Gens Movie TESTA"
    header[20:22] = b"66"
    write("gmv", header, b"".join(bytes(record) for record in records))

    # M64: fourteen digital controls, then east, north, west, south, northeast.
    # Coordinates are signed bytes; positive Y points up. East also holds A+Z.
    records = [(0, 0, 0)] + [(1 << bit, 0, 0) for bit in range(14)]
    records += [(128 + 32, 80, 0), (0, 0, 80), (0, -80, 0), (0, 0, -80), (0, 60, 60)]
    header = bytearray(1024)
    header[:4] = b"M64\x1a"
    u32(header, 4, 3)
    header[20:22] = bytes([60, 1])
    header[32] = 1
    u32(header, 24, len(records))
    write("m64", header, b"".join(struct.pack("<Hbb", *record) for record in records))

    # PSX: all sixteen digital bits (including separate L3/R3), followed by
    # east/north/west/south on the left stick, then on the right stick.
    # Unlike N64, PSX positive Y points down; neutral coordinates are 128.
    records = [(0, 128, 128, 128, 128)]
    records += [(1 << bit, 128, 128, 128, 128) for bit in range(16)]
    records += [
        (0, 255, 128, 128, 128),
        (0, 128, 0, 128, 128),
        (0, 0, 128, 128, 128),
        (0, 128, 255, 128, 128),
        (0, 128, 128, 255, 128),
        (0, 128, 128, 128, 0),
        (0, 128, 128, 0, 128),
        (0, 128, 128, 128, 255),
    ]
    for extension in ("pjm", "pxm"):
        header = bytearray(64)
        header[:4] = (extension.upper() + " ").encode("ascii")
        u32(header, 4, 2)
        header[14] = 7  # Analog pad on port one; port two is disconnected.
        u32(header, 16, len(records))
        u32(header, 44, 64)
        body = b"".join(struct.pack("<HBBBBB", *record, 0) for record in records)
        write(extension, header, body)


if __name__ == "__main__":
    main()
