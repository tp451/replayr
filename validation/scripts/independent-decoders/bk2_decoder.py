"""Independent decoder for BizHawk BK2 input logs and their relatives.

Covers BK2, TASPROJ and GBMV archives, which store an input log in a ZIP
container. Written from BizHawk's own readers, with no replayr code:

  src/BizHawk.Client.Common/movie/bk2/Bk2Controller.cs at version 2.9.1
  (constructor and SetFromMnemonic) and at revision
  ab81ea25762af8ece499ba278e3f5cc3848ec742, and Bk2Movie.InputLog.cs at
  that revision.

A line is an input row only if it starts with a pipe, and a LogKey only if it
starts the line. The LogKey names the controls of all its groups in stored
order. BizHawk 2.9.1 removes every pipe from a row and then reads it control
by control: an axis up to the next comma, trimmed; any other control as one
character that is set unless it is ".". The later revision skips pipes only
before a control, which gives the same reading for regular rows.

Whether a control is an axis comes from the emulator core in BizHawk. This
decoder takes it from the log: an axis is optional padding, an optional
minus sign and digits, closed by a comma. The reading that most rows share
decides.
"""

from collections import Counter
import re
import zipfile

import numpy as np

MISSING = -2147483648  # stands for an absent numeric value
_DIGIT = np.zeros(256, dtype=bool)
_DIGIT[[ord(c) for c in "0123456789"]] = True
_AXIS = re.compile(rb" *-?\d+,")
# NesHawk's standard two-pad definition, used when a log has an empty LogKey.
NES_DEFAULT = ["Power", "Reset"] + [
    "P%d %s" % (pad, name) for pad in (1, 2)
    for name in ("Up", "Down", "Left", "Right", "Start", "Select", "B", "A")]
_NES_ROW = re.compile(rb"\|[^|]{2}\|[^|]{8}\|[^|]{8}\|")


class NotCovered(Exception):
    """The file uses a variant that this decoder does not describe."""


def log_key_names(line):
    """Control names of a LogKey line, in stored order."""
    text = line.split(":", 1)[1]
    return [name for group in text.split("#") for name in group.split("|") if name]


def _guess_kinds(line, count):
    """Kinds of the controls as one row suggests them.

    A row may hold fewer characters than the LogKey names (BizHawk 2.9.1
    skips names its controller definition lacks) or more (it ignores the
    rest). Controls past the end of the row count as buttons.
    """
    text = line.replace(b"|", b"")
    kinds, pos = [], 0
    for _ in range(count):
        match = _AXIS.match(text, pos)
        if match:
            kinds.append("axis")
            pos = match.end()
        else:
            kinds.append("button")
            pos += 1
    return tuple(kinds)


def _read_line(line, kinds):
    """One row read the way Bk2Controller.SetFromMnemonic (2.9.1) reads it."""
    text = line.replace(b"|", b"")
    values, pos, size = [], 0, len(text)
    for kind in kinds:
        if kind == "axis":
            comma = text.find(b",", pos)
            try:
                values.append(int(text[pos:comma].strip()) if comma >= 0 else MISSING)
            except ValueError:
                values.append(MISSING)
            pos = comma + 1 if comma >= 0 else size
        else:
            values.append(int(pos < size and text[pos] != 0x2E))
            pos += 1
    return values


def _spans(row, kinds):
    """Column span of each control in a regular row, or None."""
    spans, pos, size = [], 0, len(row)
    for kind in kinds:
        while pos < size and row[pos] == 0x7C:
            pos += 1
        if pos >= size:
            return None
        if kind == "axis":
            comma = row.find(b",", pos)
            if comma < 0 or b"|" in row[pos:comma]:
                return None
            spans.append((pos, comma))
            pos = comma + 1
        else:
            spans.append((pos, pos + 1))
            pos += 1
    return spans if not row[pos:].strip(b"|") else None


def _axis_values(block):
    """Right-aligned decimal integers of a fixed-width character block."""
    digits = _DIGIT[block]
    values = np.zeros(block.shape[0], dtype="i8")
    for column in range(block.shape[1]):
        values = values * 10 + np.where(digits[:, column], block[:, column] - 48, 0)
    minus = block == ord("-")
    signs = minus.sum(axis=1)
    values[signs > 0] = -values[signs > 0]
    # A regular field is padding, an optional sign, then digits to the end.
    run = np.cumprod(digits[:, ::-1], axis=1).sum(axis=1)
    filled = (block != ord(" ")).sum(axis=1)
    lead = block.shape[1] - run - 1
    rows = np.arange(block.shape[0])
    sign_leads = np.zeros(block.shape[0], dtype=bool)
    inside = lead >= 0
    sign_leads[inside] = minus[rows[inside], lead[inside]]
    regular = (run >= 1) & (filled == run + signs)
    regular &= (signs == 0) | ((signs == 1) & sign_leads)
    return values, regular


class InputLog:
    """Streams the decoded controls of one archive in blocks of observations."""

    def __init__(self, path, block_bytes=1 << 27):
        self.archive = zipfile.ZipFile(path)
        # Early BizHawk versions omit the extension; some archives add a folder.
        members = self.archive.namelist()
        logs = [m for m in members if m.rsplit("/", 1)[-1] in ("Input Log.txt", "Input Log")]
        if len(logs) != 1:
            raise NotCovered("no single input log member")
        heads = [m for m in members if m.rsplit("/", 1)[-1] in ("Header.txt", "Header")]
        try:
            header = self.archive.read(heads[0]) if heads else b""
        except zipfile.BadZipFile:
            # A damaged header member does not affect the input log.
            header = b""
        self.platform = (re.search(rb"^Platform (.*)$", header, re.M) or [b"", b""])[1]
        self.platform = self.platform.decode("latin1").strip()
        self.stream = self.archive.open(logs[0])
        self.block_bytes = block_bytes
        self.rest = b""
        self.names = None
        self.indented_key = None
        self.layout_source = "LogKey"
        self.kinds = None
        self.spans = None
        self.reference = None
        self.done = False

    def _lines(self):
        """Next batch of input rows, or None at the end of the log."""
        while not self.done:
            chunk = self.stream.read(self.block_bytes)
            if not chunk:
                self.done = True
                data, self.rest = self.rest, b""
            else:
                data = self.rest + chunk
                cut = data.rfind(b"\n")
                if cut < 0:
                    self.rest = data
                    continue
                data, self.rest = data[:cut + 1], data[cut + 1:]
            lines = []
            for line in data.split(b"\n"):
                line = line.rstrip(b"\r")
                if line.startswith(b"|"):
                    lines.append(line)
                elif self.names is None and line.startswith(b"LogKey:"):
                    self.names = log_key_names(line.decode("utf-8", "replace"))
                elif self.indented_key is None and line.lstrip().startswith(b"LogKey:"):
                    self.indented_key = line.lstrip().decode("utf-8", "replace")
            if lines:
                return lines
        return None

    def _layout(self, lines):
        """Settle the control names and kinds from the first rows."""
        if self.names is None and self.indented_key is not None:
            # BizHawk ignores an indented LogKey and uses the core's own
            # definition; the indented line states that layout.
            self.names = log_key_names(self.indented_key)
            self.layout_source = "indented LogKey"
        if self.names is None:
            raise NotCovered("no LogKey line")
        if not self.names:
            if self.platform != "NES" or not all(_NES_ROW.fullmatch(l) for l in lines):
                raise NotCovered("empty LogKey outside the standard NES layout")
            self.names = list(NES_DEFAULT)
            self.layout_source = "NES default"
        votes = Counter(_guess_kinds(line, len(self.names)) for line in lines[:5000])
        self.kinds = list(votes.most_common(1)[0][0])
        lengths = Counter(len(line) for line in lines[:5000])
        width = lengths.most_common(1)[0][0]
        for line in lines[:5000]:
            if len(line) == width and _guess_kinds(line, len(self.names)) == tuple(self.kinds):
                spans = _spans(line, self.kinds)
                if spans is not None:
                    self.reference = np.frombuffer(line, dtype="u1")
                    self.spans = spans
                    break

    def blocks(self):
        """Yield (count, {control name: array}) for consecutive observations."""
        while True:
            lines = self._lines()
            if lines is None:
                return
            if self.kinds is None:
                self._layout(lines)
            n = len(lines)
            columns = {}
            for name, kind in zip(self.names, self.kinds):
                columns[name] = (np.zeros(n, dtype="u1") if kind != "axis"
                                 else np.full(n, MISSING, dtype="i8"))
            slow = np.arange(n)
            if self.reference is not None:
                width = self.reference.size
                lengths = np.fromiter((len(line) for line in lines), dtype="i8", count=n)
                rows = np.flatnonzero(lengths == width)
                if rows.size:
                    matrix = np.frombuffer(
                        b"".join(lines) if rows.size == n
                        else b"".join(lines[i] for i in rows), dtype="u1")
                    matrix = matrix.reshape(rows.size, width)
                    # Rows that share the reference row's pipes and commas
                    # have every control in the same columns.
                    fits = ((matrix == 0x7C) == (self.reference == 0x7C)).all(axis=1)
                    fits &= ((matrix == 0x2C) == (self.reference == 0x2C)).all(axis=1)
                    decoded = {}
                    for name, kind, (start, end) in zip(self.names, self.kinds, self.spans):
                        if kind == "axis":
                            values, regular = _axis_values(matrix[:, start:end])
                            fits &= regular
                            decoded[name] = values
                        else:
                            decoded[name] = matrix[:, start] != 0x2E
                    good = rows[fits]
                    for name in self.names:
                        columns[name][good] = decoded[name][fits]
                    keep = np.ones(n, dtype=bool)
                    keep[good] = False
                    slow = np.flatnonzero(keep)
            for i in slow:
                for name, value in zip(self.names, _read_line(lines[i], self.kinds)):
                    columns[name][i] = value
            yield n, columns
