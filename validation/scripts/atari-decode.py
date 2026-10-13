"""A separate decoder of the tables of the Atari Grand Challenge data set and
of Atari-HEAD, for comparison with what replayr returns. It shares no code
with replayr: the controls of an action are taken from the name the Arcade
Learning Environment gives it (for example UPLEFTFIRE), where replayr holds
the action numbers of each control. For every table it writes one row per
row of the table: the five controls as 0 or 1, the action number and what
gives the row its place and time (the frame, and for Atari-HEAD the duration
and the time at which the frame appeared), with an empty field for a value
the table gives as null. Score, reward and episode are states of the game;
replayr does not return them, and they are not compared.
Usage: python -I atari-decode.py <folder of the data> <sources.csv> <folder for the output>"""
import csv
import pathlib
import sys

# The action names of the Arcade Learning Environment in the order of their numbers.
NAMES = ["NOOP", "FIRE", "UP", "RIGHT", "LEFT", "DOWN", "UPRIGHT", "UPLEFT", "DOWNRIGHT", "DOWNLEFT", "UPFIRE",
         "RIGHTFIRE", "LEFTFIRE", "DOWNFIRE", "UPRIGHTFIRE", "UPLEFTFIRE", "DOWNRIGHTFIRE", "DOWNLEFTFIRE"]
CONTROLS = ["RIGHT", "LEFT", "DOWN", "UP", "FIRE"]


def controls(action):
    if action == "":
        return ["0"] * 5
    name = NAMES[int(action)]
    return ["1" if control in name else "0" for control in CONTROLS]


def value(text):
    return "" if text == "null" else text


def grand_challenge(lines):
    if not lines[0].startswith("db traj id") or [c.strip() for c in lines[1].split(",")] != [
            "frame", "reward", "score", "terminal", "action"]:
        raise ValueError("not a trajectory")
    yield ["right", "left", "down", "up", "fire", "action", "frame"]
    for line in lines[2:]:
        frame, reward, score, terminal, action = (field.strip() for field in line.split(","))
        yield controls(action) + [action, frame]


def atari_head(lines):
    if not lines[0].startswith("frame_id,episode_id,score,duration(ms),unclipped_reward,action"):
        raise ValueError("not a trial")
    yield ["right", "left", "down", "up", "fire", "action", "duration_ms", "start_ms", "frame_id"]
    elapsed = 0
    for line in lines[1:]:
        frame_id, episode, score, duration, reward, action = line.split(",", 6)[:6]
        action = value(action)
        yield controls(action) + [action, value(duration), str(elapsed), frame_id]
        elapsed += int(duration) if duration != "null" else 0


root = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[3])
with open(sys.argv[2], newline="", encoding="utf-8") as handle:
    sources = list(csv.DictReader(handle))
done = 0
for source in sources:
    path = root / source["file"]
    if not path.exists():
        continue
    lines = path.read_text(encoding="utf-8").split("\n")
    while lines and lines[-1] == "":
        lines.pop()
    rows = grand_challenge(lines) if source["data_set"].startswith("Atari Grand Challenge") else atari_head(lines)
    target = out / (source["file"] + ".csv")
    target.parent.mkdir(parents=True, exist_ok=True)
    with open(target, "w", newline="", encoding="utf-8") as handle:
        csv.writer(handle).writerows(rows)
    done += 1
print("tables decoded:", done, "of", len(sources))
