"""Compare the text that follows the input of FinalBurn Alpha recordings, as
replayr returns it in movie$header$metadata, with a separate reading of the
same bytes: the chunk FRM1, its length, and two bytes per character.
Usage: python -I fbm-text-compare.py <folder with .fbm files> <replayr's result.csv> <comparison.csv>
The second file has the columns file and metadata (empty where there is no text)."""
import csv
import pathlib
import struct
import sys

folder = pathlib.Path(sys.argv[1])
with open(sys.argv[2], newline="", encoding="utf-8") as handle:
    ours = {row["file"]: row for row in csv.DictReader(handle)}
rows = []
for name in sorted(ours):
    data = (folder / name).read_bytes()
    at = 5
    if data[at:at + 4] == b"FS1 ":
        at += 8 + struct.unpack_from("<I", data, at + 4)[0]
    end = at + 8 + struct.unpack_from("<I", data, at + 4)[0]
    text = None
    if data[end:end + 4] == b"FRM1":
        size = struct.unpack_from("<I", data, end + 4)[0]
        text = data[end + 8:end + 8 + size].decode("utf-16-le")
    theirs = ours[name]["metadata"]
    theirs = None if theirs in ("", "NA") else theirs
    rows.append([name, len(data) - end, "" if text is None else text, "agrees" if text == theirs else "DISAGREES"])
with open(sys.argv[3], "w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle)
    writer.writerow(["file", "bytes_after_input", "text", "status"])
    writer.writerows(rows)
print("recordings:", len(rows), " with a text:", sum(1 for r in rows if r[2]), " agree:",
      sum(1 for r in rows if r[3] == "agrees"))
for row in rows:
    if any(ord(c) > 126 for c in row[2]):
        print("   outside ASCII:", row[0], ascii(row[2]))
