"""Download GoldSrc demos and write a table of their sources with size and
SHA-256: the demos that public repositories of demo parsers hold as test
material, and a sample from collections of the Internet Archive. The sample
is fixed: of a collection either every file is taken or, from a large zip
file, members at even distances in the order of their names; a large zip
file is not downloaded, its members are read by byte ranges. Archives inside
archives are unpacked; RAR and 7z need bsdtar (the tar of Windows 10 and
later). A downloaded file is kept and not downloaded a second time, so the
large zip files can be read side by side by runs that name one each, before
a last run without a name puts the whole set together.
Usage: python -I goldsrc-retrieve.py <folder for the demos> <sources.csv> <folder for the downloaded archives>
         [name of one large zip file]"""
import bz2
import csv
import fnmatch
import hashlib
import http.client
import io
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

AGENT = {"User-Agent": "replayr validation (demo files for testing)"}
PACKED = (".zip", ".rar", ".7z", ".bz2")
# Repository, its licence, host of the files (raw, or media for large files), folder, files.
REPOSITORIES = [
    ("YaLTeR/hldemo-rs", "Apache-2.0 or MIT", "raw", "test-demos", [
        "basic.dem", "frame-types.dem", "invalid-demo-protocol.dem", "invalid-directory-entry-count.dem",
        "invalid-frame-type.dem", "invalid-magic.dem", "invalid-netmsg-length.dem"]),
    ("khanghugo/dem", "LGPL-3.0", "raw", "src/tests", ["demotest.dem", "weapon.dem"]),
    ("skyrim/hlviewer.js", "MIT", "raw", "res/replays", ["kz_ea_highblock.dem"]),
    ("rndtrash/py-goldsrc-demo", "LGPL-3.0", "media", "demos", [
        "2008-de_inferno.dem", "bootcamp_test.dem", "bootcamp_test_short.dem"]),
]
# Collection, its files (a pattern), how many to take (None: all), largest packed size of one.
WHOLE = [
    ("kzmapscouk-demoarchive", "*.rar", None, None),
    ("counter-strike-classic-demos", "*.zip", None, None),
    ("speedrun-gmc-27-59", "gmcdq-demos.7z", None, None),
    ("fastcups-5v5-nostalgie-cup-finals-HLTV-demos", "*.7z", None, None),
    ("Counter-Strike-1.6-Online-Demos", "*.dem", 8, 30e6),
]
# Collection, one large zip file of it, and the year up to which every member is taken.
# Demos of 2001 are of the oldest engine versions that the format has.
OLDEST = [("ag_demos", "hutt_demos.zip", 2001)]
# Collection, one large zip file of it, how many members to take, largest packed size of one.
MEMBERS = [
    ("kzbaltic", "records_map_upload.zip", 60, 8e6),
    ("kzbaltic", "records_map_old.zip", 60, 8e6),
    ("ag_demos", "hutt_demos.zip", 40, 12e6),
    ("ag_demos", "k3ns4n_demos_p47.zip", 15, 12e6),
    ("ag_demos", "k3ns4n_demos_1v1.zip", 10, 12e6),
    ("cs-1.6-demos", "CS 1.6 Demos.zip", 30, 12e6),
    ("ensl_demos", "ensl_demos_ensl_1.zip", 5, 60e6),
]


def request(url, headers=None, method="GET"):
    """One request, repeated after a pause when the server or the line fails."""
    for attempt in range(10):
        try:
            asked = urllib.request.Request(url, headers=dict(AGENT, **(headers or {})), method=method)
            with urllib.request.urlopen(asked, timeout=120) as response:
                return response.geturl(), response.headers, (b"" if method == "HEAD" else response.read())
        except (http.client.IncompleteRead, urllib.error.URLError, TimeoutError, ConnectionError):
            if attempt == 9:
                raise
            time.sleep(10 * (attempt + 1))


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


def at_even_distances(candidates, wanted):
    if wanted is None or len(candidates) <= wanted:
        return candidates
    return [candidates[(2 * i + 1) * len(candidates) // (2 * wanted)] for i in range(wanted)]


def bsdtar():
    for program in ("bsdtar", "tar", os.path.join(os.environ.get("SystemRoot", ""), "System32", "tar.exe")):
        try:
            if "bsdtar" in subprocess.run([program, "--version"], capture_output=True, text=True).stdout:
                return program
        except OSError:
            pass
    raise SystemExit("RAR and 7z archives need bsdtar")


def kind_of(name, data):
    """What a file is, by its first bytes: some archives carry the extension of another kind."""
    for kind, start in ((".dem", b"HLDEMO"), (".zip", b"PK\x03\x04"), (".rar", b"Rar!"),
                        (".7z", b"7z\xbc\xaf\x27\x1c"), (".bz2", b"BZh")):
        if data.startswith(start):
            return kind
    return ".dem" if name.lower().endswith(".dem") else ""


def demos_in(name, data):
    """The demos in a file: itself, or what its archive holds, as (path inside, bytes)."""
    lower = kind_of(name, data)
    if lower.endswith(".dem"):
        yield "", data
    elif lower.endswith(".bz2"):
        for inner, found in demos_in(name[:-4] if name.lower().endswith(".bz2") else name, bz2.decompress(data)):
            yield inner, found
    elif lower.endswith(".zip"):
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            for member in sorted(archive.infolist(), key=lambda m: m.filename):
                if not member.is_dir() and member.filename.lower().endswith((".dem",) + PACKED):
                    for inner, found in demos_in(member.filename, archive.read(member)):
                        yield member.filename + (" > " + inner if inner else ""), found
    elif lower.endswith((".rar", ".7z")):
        # Unpacked into a folder of its own; bsdtar writes no path outside it.
        folder = pathlib.Path(tempfile.mkdtemp(prefix="unpack-"))
        try:
            packed = folder / ("archive" + lower[lower.rindex("."):])
            packed.write_bytes(data)
            inside = folder / "inside"
            inside.mkdir()
            subprocess.run([bsdtar(), "-xf", str(packed), "-C", str(inside)], check=True, capture_output=True)
            for path in sorted(p for p in inside.rglob("*") if p.is_file()):
                if path.name.lower().endswith((".dem",) + PACKED):
                    relative = path.relative_to(inside).as_posix()
                    for inner, found in demos_in(path.name, path.read_bytes()):
                        yield relative + (" > " + inner if inner else ""), found
        finally:
            shutil.rmtree(folder, ignore_errors=True)


out = pathlib.Path(sys.argv[1])
store = pathlib.Path(sys.argv[3])
if len(sys.argv) > 4:
    REPOSITORIES, WHOLE = [], []
    MEMBERS = [entry for entry in MEMBERS if entry[1] == sys.argv[4]]
out.mkdir(parents=True, exist_ok=True)
rows, seen, names = [], set(), set()


def kept(collection, container, member, data, licence):
    """Unpack one downloaded file and keep its demos."""
    url = "https://archive.org/download/%s/%s" % (collection, urllib.parse.quote(container))
    place = container + (" > " + member if member else "")
    try:
        found = list(demos_in(member or container, data))
    except (zipfile.BadZipFile, subprocess.CalledProcessError, OSError, EOFError, ValueError) as error:
        rows.append(["", collection, "", place, "", url, licence, len(data), "",
                     "not unpacked: %s" % type(error).__name__])
        print("   not unpacked:", place)
        return
    for inner, demo in found:
        digest = hashlib.sha256(demo).hexdigest()
        if digest in seen:
            continue
        seen.add(digest)
        base = re.sub(r"[^A-Za-z0-9._\[\]-]", "_", (inner or member or container).split(" > ")[-1].split("/")[-1])
        base = re.sub(r"(?i)([.]dem)?([.](bz2|zip|rar|7z))?$", "", base)
        name, count = "%s__%s.dem" % (collection.split("-")[0].lower()[:12], base), 1
        while name.lower() in names:
            count += 1
            name = "%s__%s-%d.dem" % (collection.split("-")[0].lower()[:12], base, count)
        names.add(name.lower())
        (out / name).write_bytes(demo)
        status = "GoldSrc demo" if demo[:6] == b"HLDEMO" else "no HLDEMO signature"
        rows.append([name, collection, "", place, inner, url, licence, len(demo), digest, status])


def stored(collection, relative, fetch):
    """A downloaded file, kept so that a second run does not download it again."""
    # A name that Windows does not allow gets other characters and a mark of its own.
    safe = re.sub(r'[<>:"|?*]', "_", relative)
    if safe != relative:
        safe += "~" + hashlib.sha1(relative.encode("utf-8")).hexdigest()[:8]
    path = store / collection / safe
    if path.exists():
        return path.read_bytes()
    data = fetch()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    time.sleep(1)
    return data


for repository, licence, host, folder, files in REPOSITORIES:
    revision = json.loads(request("https://api.github.com/repos/%s/commits?per_page=1" % repository)[2])[0]["sha"]
    for name in files:
        base = "raw.githubusercontent.com" if host == "raw" else "media.githubusercontent.com/media"
        url = "https://%s/%s/%s/%s/%s" % (base, repository, revision, folder, name)
        data = stored(repository.replace("/", "__"), revision + "/" + name, lambda: request(url)[2])
        digest = hashlib.sha256(data).hexdigest()
        seen.add(digest)
        names.add(name.lower())
        (out / name).write_bytes(data)
        rows.append([name, repository, revision, "", folder + "/" + name, url, licence, len(data), digest,
                     "GoldSrc demo" if data[:6] == b"HLDEMO" else "no HLDEMO signature"])
    print("%-48s %4d demos so far" % (repository, len(seen)))
licences = {}
for collection in dict.fromkeys(c for c, *_ in WHOLE + MEMBERS):
    item = json.loads(request("https://archive.org/metadata/" + collection)[2])
    licences[collection] = (item["metadata"].get("licenseurl") or "none stated", item["files"])
for collection, pattern, wanted, largest in WHOLE:
    licence, files = licences[collection]
    candidates = sorted(f["name"] for f in files if f.get("source") == "original"
                        and fnmatch.fnmatch(f["name"].split("/")[-1], pattern)
                        and (largest is None or int(f["size"]) <= largest))
    for name in at_even_distances(candidates, wanted):
        url = "https://archive.org/download/%s/%s" % (collection, urllib.parse.quote(name))
        kept(collection, name, "", stored(collection, name, lambda: request(url)[2]), licence)
    print("%-48s %4d demos so far" % (collection, len(seen)))
for collection, container, wanted, largest in MEMBERS:
    licence = licences[collection][0]
    remote = Ranged("https://archive.org/download/%s/%s" % (collection, urllib.parse.quote(container)))
    with zipfile.ZipFile(io.BufferedReader(remote, buffer_size=1 << 22)) as archive:
        candidates = sorted((m for m in archive.infolist() if not m.is_dir()
                             and m.filename.lower().endswith((".dem",) + PACKED) and m.compress_size <= largest),
                            key=lambda m: m.filename)
        early = [limit for c, f, limit in OLDEST if (c, f) == (collection, container)]
        chosen = at_even_distances(candidates, wanted)
        chosen += [m for m in candidates if early and m.date_time[0] <= early[0] and m not in chosen]
        for member in chosen:
            data = stored(collection, container + ".members/" + member.filename, lambda: archive.read(member))
            kept(collection, container, member.filename, data, licence)
    print("%-48s %4d demos so far" % (collection + "/" + container, len(seen)))
with open(sys.argv[2], "w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle)
    writer.writerow(["file", "source", "revision", "container", "member", "url", "licence", "bytes", "sha256",
                     "status"])
    writer.writerows(rows)
print("demos:", sum(1 for r in rows if r[9] == "GoldSrc demo"), " other files:",
      sum(1 for r in rows if r[9] != "GoldSrc demo"), " bytes:", sum(r[7] for r in rows if r[0]))
