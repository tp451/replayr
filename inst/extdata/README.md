# Synthetic sample movie files

Every `sample.<ext>` file is deterministic synthetic controller input created
for replayr. None contains a ROM, savestate, memory-card image, cheat data,
audio, video, or data copied from a published movie. The fixtures and their
generator are part of replayr and are distributed under the package's GPL (>=
2) license.

| File | Synthetic duration | Controller layout |
|------|--------------------|-------------------|
| `sample.fm2` | 3,600 frames | two NES gamepads |
| `sample.bk2` | 3,600 frames | one NES gamepad |
| `sample.fcm` | 3,600 frames | one active NES port; four reserved ports |
| `sample.lsmv` | 3,600 frames | two SNES gamepads |
| `sample.gmv` | 3,600 frames | two Genesis six-button gamepads |
| `sample.vbm` | 3,600 frames | one Game Boy gamepad |
| `sample.m64` | 3,600 frames | one N64 gamepad with synthetic stick motion |
| `sample.smv` | 3,600 samples | one SNES gamepad |
| `sample.pxm` | 3,600 frames | two PlayStation digital gamepads |
| `sample.pjm` | 3,600 frames | two PlayStation digital gamepads |
| `sample.dtm` | 3,600 controller polls | one GameCube gamepad; left-stick circles and a horizontal right-stick sweep |
| `sample.lmp` | 2,100 tics | one active Doom player; four reserved slots |

The 3,600-frame streams are approximately one minute at 60 Hz. Doom records
input at 35 tics per second, so its one-minute stream contains 2,100 tics.

Regenerate all fixtures from the package root with:

```sh
Rscript tools/generate_sample_movies.R
```

Optional compatibility checks can use a separately obtained local corpus by
setting `REPLAYR_FIXTURE_DIR`. Such external files are never bundled with the
package.

Additional original examples are grouped by purpose:

- `paper/`: short movement and action sequences used in the article examples.
- `expanded/`: BizHawk keyboard, touchscreen, dual-stick, peripheral, and arcade gestures.
- `computers/`: libTAS, Hourglass, JPC-rr, openMSX, and CoffeeTools input sequences.
- `legacy/`: earlier emulator formats, Citra device polls, and ZSNES/GZ records.
- `tables/`: two short tables in the layouts of the Atari Grand Challenge
  data set and of Atari-HEAD, written by `tools/generate-atari-tables.R`. No
  row is taken from either data set.

The corresponding generators are `tools/generate_article_examples.R`,
`tools/generate-bizhawk-examples.py`, `tools/generate-mar-examples.py`,
`tools/generate-computer-fixtures.py`, and `tools/make-legacy-fixtures.py`.
`tools/generate-bk2-warning-fixtures.py` writes `bk2-variants/` and the
test-suite fixture `nes-unplugged.bk2`; `tools/generate-motion-examples.py`
and `tools/generate-omr-device-fixture.py` write the pointer, motion, and
openMSX peripheral examples; `tools/make-semantic-fixtures.py` writes
`semantic/`. Every generator uses only base R or the Python standard library
and reproduces the distributed files byte for byte.
Small malformed-input examples are also constructed inside the test suite.
`mar-layouts.json` contains game-specific port mappings, with source references;
it contains no recording of game play.

`tools/generate-import-examples.py` creates a short FCEUX editor movie with
three rightward movements, short A-button presses, and pauses, plus the HGM
extension alias of the original Hourglass keyboard example. The FM3 example
contains its input section and an empty editor-project section.

`tools/generate-fbm-examples.py` creates an arcade sequence with movement,
two action-button patterns, coin insertion, and a second player's start input.
Read `expanded/synthetic-arcade.fbm` with `game = "ghouls"`, which identifies
the input-field order used by the example. The accompanying analogue fixture
has an explicit schema and exercises signed coordinates and raw button bytes.
`fbm-layouts.json` records driver input layouts and their source references.

`tools/generate-goldsrc-fixture.R` creates `computers/goldsrc-moves.dem`, a
GoldSrc demo of two sections: a loading section without input, then 24
frames with forward movement, two jumps, a sidestep, a turn, ducking and an
attack, and the key actions as console commands. Every frame type of the
format occurs in it.

`tools/generate-dft-fixtures.py` creates `computers/menu-double-tap.dft`,
a short Dustmod script with menu navigation, movement, a directional double
tap, mouse input, and an included script. Its source lines are original.
