"""Download the tables of player actions of two published data sets of Atari
2600 play, without their screen images, and write a table of the files with
size and SHA-256:
  the Atari Grand Challenge data set, version 1 (Kurin et al. 2017): the
    archive of its trajectories;
  Atari-HEAD (Zhang et al. 2020, Zenodo record 3451402): the text file of
    every trial, read out of the archive of each game by byte ranges.
A file that is already there with the listed size is not downloaded again.
Zenodo answers slowly; the games of Atari-HEAD can be shared out among
several runs by naming them, and a last run without names lists everything.
Usage: python -I atari-retrieve.py <folder for the data> <sources.csv> [both|grand-challenge|atari-head] [game,game,...]"""
import csv
import hashlib
import http.client
import io
import json
import pathlib
import sys
import tarfile
import time
import urllib.error
import urllib.request
import zipfile

AGENT = {"User-Agent": "replayr validation (published input tables)"}
GRAND_CHALLENGE = "https://omnomnom.vision.rwth-aachen.de/data/atari_v1_release/trajectories.tar.gz"
ATARI_HEAD = "https://zenodo.org/records/3451402/files/"
GAMES = ["alien", "asterix", "bank_heist", "berzerk", "breakout", "centipede", "demon_attack", "enduro", "freeway",
         "frostbite", "hero", "montezuma_revenge", "ms_pacman", "name_this_game", "phoenix", "riverraid",
         "road_runner", "seaquest", "space_invaders", "venture"]


def request(url, headers=None, method="GET"):
    """One request, repeated after a pause when the server or the line fails.
    The pauses grow to five minutes, and the run waits out an outage of
    about ten hours before it gives up."""
    for attempt in range(130):
        try:
            asked = urllib.request.Request(url, headers=dict(AGENT, **(headers or {})), method=method)
            with urllib.request.urlopen(asked, timeout=120) as response:
                return response.geturl(), response.headers, (b"" if method == "HEAD" else response.read())
        except (http.client.IncompleteRead, urllib.error.URLError, TimeoutError, ConnectionError) as error:
            if attempt == 129:
                raise
            print("    waiting after: %s" % error, flush=True)
            time.sleep(min(15 * (attempt + 1), 300))


class Ranged(io.RawIOBase):
    """A file on the web that is read in byte ranges."""

    def __init__(self, url):
        self.url, headers, _ = request(url, method="HEAD")
        self.size = int(headers["Content-Length"])
        self.position = 0

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.position

    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else self.position + offset if whence == 1 else self.size + offset
        return self.position

    def readinto(self, buffer):
        if not len(buffer) or self.position >= self.size:
            return 0
        last = min(self.position + len(buffer), self.size) - 1
        data = request(self.url, {"Range": "bytes=%d-%d" % (self.position, last)})[2]
        buffer[:len(data)] = data
        self.position += len(data)
        return len(data)


root = pathlib.Path(sys.argv[1])
which = sys.argv[3] if len(sys.argv) > 3 else "both"
rows = []


def listed(path, data_set, source, member):
    data = path.read_bytes()
    rows.append([path.relative_to(root).as_posix(), data_set, source, member, len(data),
                 hashlib.sha256(data).hexdigest()])


if which in ("both", "grand-challenge"):
    folder = root / "atari-grand-challenge"
    folder.mkdir(parents=True, exist_ok=True)
    packed = folder / "trajectories.tar.gz"
    if not packed.exists():
        packed.write_bytes(request(GRAND_CHALLENGE)[2])
    with tarfile.open(packed) as archive:
        for member in sorted((m for m in archive.getmembers() if m.isfile() and m.name.endswith(".txt")),
                             key=lambda m: m.name):
            game, name = member.name.split("/")[-2:]
            target = folder / game / name
            if not (target.exists() and target.stat().st_size == member.size):
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(archive.extractfile(member).read())
            listed(target, "Atari Grand Challenge v1", GRAND_CHALLENGE, member.name)
    print("Atari Grand Challenge: %d trajectories" % len(rows))
if which in ("both", "atari-head"):
    folder = root / "atari-head"
    folder.mkdir(parents=True, exist_ok=True)
    before = len(rows)
    for small in ("meta_data.csv", "action_enums.txt"):
        if not (folder / small).exists():
            (folder / small).write_bytes(request(ATARI_HEAD + small + "?download=1")[2])
    for game in (sys.argv[4].split(",") if len(sys.argv) > 4 else GAMES):
        if game not in GAMES:
            raise SystemExit("not a game of Atari-HEAD: " + game)
        url = ATARI_HEAD + game + ".zip?download=1"
        # The names and sizes of a game's tables are kept once they are known,
        # so that a second run asks the server only for what is missing.
        known = folder / "members" / (game + ".json")
        archive = None
        if known.exists():
            members = json.loads(known.read_text(encoding="utf-8"))
        else:
            archive = zipfile.ZipFile(io.BufferedReader(Ranged(url), buffer_size=1 << 22))
            members = sorted([m.filename, m.file_size] for m in archive.infolist()
                             if not m.is_dir() and m.filename.endswith(".txt")
                             and not m.filename.split("/")[-1].startswith("."))
            known.parent.mkdir(parents=True, exist_ok=True)
            known.write_text(json.dumps(members), encoding="utf-8")
        for name, size in members:
            target = folder / name
            if not (target.exists() and target.stat().st_size == size):
                if archive is None:
                    archive = zipfile.ZipFile(io.BufferedReader(Ranged(url), buffer_size=1 << 22))
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(archive.read(name))
                print("   ", name, flush=True)
                time.sleep(1)
            listed(target, "Atari-HEAD", url, name)
        if archive is not None:
            archive.close()
        print("Atari-HEAD %-18s %4d trials so far" % (game, len(rows) - before), flush=True)
with open(sys.argv[2], "w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle)
    writer.writerow(["file", "data_set", "source", "member", "bytes", "sha256"])
    writer.writerows(rows)
print("files:", len(rows), " bytes:", sum(r[4] for r in rows))
