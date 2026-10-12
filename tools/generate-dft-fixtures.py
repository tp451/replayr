"""Create original Dustmod scripts demonstrating movement and menu inputs."""

from pathlib import Path
import gzip
import io
import tarfile

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "inst" / "extdata" / "computers"
TARGET.mkdir(parents=True, exist_ok=True)

scripts = {
    "demo/main.txt": """# Artificial movement, attack, and menu sequence.
LOAD:0:sample:Nexus DX
STATS:4
INCLUDE:demo/move.txt
MOUSE:75:-25:10001
000000000
0000000000
SYNCLOAD
INCLUDE:demo/attack.txt
INCLUDE:demo/move.txt
MOUSE:1:2:01000
""",
    "demo/move.txt": """# Move and jump right, release, then double tap right and down.
0 1 0 0 1 0 0 0 0
000000000
0200000000
0002000000
""",
    "demo/attack.txt": """# Light and heavy attacks, taunt, and restart use separate controls.
0000001000
0000000100
0000000001
00000000001
""",
}
buf = io.BytesIO()
with tarfile.open(fileobj=buf, mode="w", format=tarfile.USTAR_FORMAT) as archive:
    for name, text in scripts.items():
        data = text.encode("utf-8")
        info = tarfile.TarInfo(name)
        info.size = len(data)
        info.mode = 0o644
        info.mtime = 0
        archive.addfile(info, io.BytesIO(data))
(TARGET / "menu-double-tap.dft").write_bytes(gzip.compress(buf.getvalue(), mtime=0))
