"""Compare replayr's BizHawk input-log values with the independent decoder.

Usage: python compare-bk2.py <export directory> <results.csv>
Environment: REPLAYR_VALIDATION_ROOT (recording directory).

export-bk2.R writes, for every LogKey control of a recording, the MD5 digest
of the values replayr holds, per block of observations. This script decodes
the same archive with bk2_decoder.py and computes the same digests: bytes 0/1
for buttons, little-endian int32 for axes. Equal digests mean equal values
for every observation of that control.
"""

from pathlib import Path
import csv
import hashlib
import json
import os
import sys

import numpy as np

from bk2_decoder import InputLog, NotCovered

FIELDS = ["sha256", "publication_id", "format", "observations", "controllers",
          "button_values", "button_differences", "numeric_values",
          "numeric_differences", "command_values", "command_differences",
          "status", "note"]


def encode(values):
    if values.dtype == np.uint8:
        return values.tobytes()
    return values.astype("<i4").tobytes()


def compare(meta, root):
    row = dict.fromkeys(FIELDS, 0)
    row.update(sha256=meta["sha256"], publication_id=meta["publication_id"],
               format=meta["format"], observations=meta["observations"],
               status="", note="")
    if meta.get("error"):
        row.update(status="differs", note="replayr: " + meta["error"])
        return row
    blocks = meta["blocks"]
    if not blocks:
        row.update(status="differs", note="no observations exported")
        return row
    theirs = blocks[0]
    ports = {name: port for name, port in zip(theirs["names"], theirs["ports"])}
    row["controllers"] = len({port for port in ports.values() if port})
    notes, differing = [], set()
    try:
        log = InputLog(root / meta["relative_path"])
        stream = log.blocks()
        pending = []            # decoded runs not yet consumed
        available = 0
        for block in blocks:
            need = block["n"]
            while available < need:
                run = next(stream, None)
                if run is None:
                    break
                pending.append(run)
                available += run[0]
            if available < need:
                notes.append(f"decoder has {available} of {need} observations "
                             f"from {block['first']}")
                differing.add("observation count")
                break
            # Cut exactly `need` observations off the front of the queue.
            parts, taken = [], 0
            while taken < need:
                n, columns = pending[0]
                use = min(n, need - taken)
                parts.append({name: v[:use] for name, v in columns.items()})
                if use == n:
                    pending.pop(0)
                else:
                    pending[0] = (n - use, {name: v[use:] for name, v in columns.items()})
                taken += use
            available -= need
            ours = {name: (np.concatenate([p[name] for p in parts]) if len(parts) > 1
                           else parts[0][name]) for name in parts[0]}
            listed = dict(zip(block["names"], zip(block["types"], block["md5"])))
            for name, values in ours.items():
                numeric = values.dtype != np.uint8
                counter = "numeric" if numeric else "button"
                if name not in listed:
                    if values.any() if not numeric else (values != values[0]).any():
                        row[counter + "_values"] += need
                        differing.add(name + " (absent from replayr)")
                    continue
                kind, digest = listed[name]
                row[counter + "_values"] += need
                if digest is None:
                    differing.add(name + " (replayr holds no values)")
                elif (kind != "logical") != numeric:
                    differing.add(name + " (button or axis)")
                elif hashlib.md5(encode(values)).hexdigest() != digest:
                    differing.add(name)
            for name in listed:
                if name not in ours:
                    differing.add(name + " (absent from the log)")
        else:
            extra = available + sum(run[0] for run in stream)
            if extra:
                notes.append(f"decoder has {extra} further observations")
                differing.add("observation count")
    except NotCovered as reason:
        row.update(status="not covered", note=str(reason))
        return row
    if log.layout_source != "LogKey":
        notes.append("layout from " + log.layout_source)
    if differing:
        row["status"] = "differs"
        notes.append("differing controls: " + ", ".join(sorted(differing)))
        row["button_differences"] = len(differing)
    else:
        row["status"] = "agrees"
    row["note"] = "; ".join(notes)
    return row


def main():
    export, target = Path(sys.argv[1]), Path(sys.argv[2])
    root = Path(os.environ["REPLAYR_VALIDATION_ROOT"])
    rows = []
    for description in sorted(export.glob("*.json")):
        meta = json.loads(description.read_text(encoding="utf-8"))
        rows.append(compare(meta, root))
    rows.sort(key=lambda r: (r["format"], int(r["publication_id"])))
    with target.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    for fmt in sorted({r["format"] for r in rows}):
        part = [r for r in rows if r["format"] == fmt]
        print(fmt, "recordings", len(part),
              "agree", sum(r["status"] == "agrees" for r in part),
              "differ", sum(r["status"] == "differs" for r in part),
              "not covered", sum(r["status"] == "not covered" for r in part),
              "values", sum(r["button_values"] + r["numeric_values"] for r in part))


if __name__ == "__main__":
    main()
