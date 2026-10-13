"""Download the BK2 recordings published for Gym Retro: the human
demonstrations of the Sonic benchmark (openai/retro-movies), the example
recording of the library (openai/retro) and that of its maintained successor
(Farama-Foundation/stable-retro). Writes a table of their sources with size
and SHA-256, and stores the numbers of steps that Gym Retro's own script
counted in the demonstrations (get_states.results of openai/retro-movies).
Usage: python -I gymretro-retrieve.py <folder for the recordings> <sources.csv> <file for the step counts>"""
import csv
import hashlib
import json
import pathlib
import sys
import time
import urllib.request

out = pathlib.Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
# Repository, revision, what its own licence file says.
SETS = [
    ("openai/retro-movies", "5f583c03a20c2e9bdb7df9200b131abdacec29d5", "none stated"),
    ("openai/retro", "094531b16221d9199c2e9b7913259ba448c57e37", "MIT"),
    ("Farama-Foundation/stable-retro", "e2fdb2a6d39f942d21d5b7f4b3b9929808739eab", "MIT"),
]


def get(url):
    request = urllib.request.Request(url, headers={"User-Agent": "replayr validation (recordings for testing)"})
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()


rows = []
for repo, revision, licence in SETS:
    tree = json.loads(get("https://api.github.com/repos/%s/git/trees/%s?recursive=1" % (repo, revision)))["tree"]
    for entry in tree:
        if not entry["path"].lower().endswith(".bk2"):
            continue
        name = entry["path"].split("/")[-1]
        if any(r[0] == name for r in rows):
            # Two repositories use one file name; the later one carries its repository's name.
            name = repo.split("/")[-1] + "-" + name
        url = "https://raw.githubusercontent.com/%s/%s/%s" % (repo, revision, entry["path"])
        data = get(url)
        (out / name).write_bytes(data)
        rows.append([name, repo, revision, entry["path"], url, licence, len(data), hashlib.sha256(data).hexdigest()])
        time.sleep(0.5)
    print(repo, ":", sum(1 for r in rows if r[1] == repo), "recordings")
if len({r[0] for r in rows}) != len(rows):
    raise SystemExit("two recordings share a file name")
with open(sys.argv[2], "w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle)
    writer.writerow(["file", "repository", "revision", "path", "url", "repository_licence", "bytes", "sha256"])
    writer.writerows(rows)
pathlib.Path(sys.argv[3]).write_bytes(get("https://raw.githubusercontent.com/%s/%s/get_states.results" % SETS[0][:2]))
print("recordings:", len(rows), " bytes:", sum(r[6] for r in rows))
