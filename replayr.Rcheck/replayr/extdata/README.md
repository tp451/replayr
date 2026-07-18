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
| `sample.dtm` | 3,600 frames | one GameCube gamepad with synthetic stick motion |
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
