# Sample movie files

Each `sample.<ext>` is a real publication from tasvideos.org. They are
included here so that the test suite can run without external data and
to give end-users one runnable example per format. The binary content
of each file is unchanged from its source.

| File | Source publication |
|------|---------------------|
| sample.fm2  | NES Tengen Tetris (#2581) — FCEUX text format |
| sample.bk2  | Atari 2600 Kangaroo (#3546) — BizHawk |
| sample.fcm  | NES Kung Fu (#340) — FCEU binary |
| sample.lsmv | SNES EarthBound (#2466) — lsnes |
| sample.gmv  | Genesis Sonic 3 & Knuckles (#1713) — Gens-rerecording |
| sample.vbm  | GB Zelda: Link's Awakening (#2076) — VBA-rerecording |
| sample.m64  | N64 Super Mario 64 (#3264) — Mupen64 |
| sample.smv  | SNES Tetris Attack (#1904) — Snes9x-rerecording |

Three formats (.pxm, .pjm, .dtm) have no bundled fixture because their
typical file sizes (≥0.5 MB) would inflate the package. To run the
optional tests for those formats, set the environment variable
`REPLAYR_FIXTURE_DIR` to the absolute path of the corpus's `data/`
folder before running `R CMD check` or `devtools::test()`. The tests
will then look for `data/raw_psx/<game>/<n>.pxm` and so on.
