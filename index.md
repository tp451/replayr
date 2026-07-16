# replayr

Pure-R parsers for 12 emulator movie (“input log”) file formats used by
the speedrun and tool-assisted-speedrun communities.

| Format | Emulator | Platforms |
|----|----|----|
| .fm2 | FCEUX | NES |
| .bk2 | BizHawk (multi-system) | NES, SNES, Genesis, Master System, GB/GBC/GBA, N64, PSX, Saturn, Atari 2600, PC Engine, Intellivision, ColecoVision, Arcade |
| .fcm | FCEU | NES |
| .lsmv | lsnes | SNES, Game Boy, Super Game Boy |
| .gmv | Gens-rerecording | Sega Genesis / Mega Drive |
| .vbm | VBA-rerecording | Game Boy / GBC / GBA |
| .m64 | Mupen64 | N64 |
| .smv | Snes9x-rerecording | SNES |
| .pxm | PSXjin (binary body) | PSX |
| .pjm | PSXjin (text body) | PSX |
| .dtm | Dolphin | GameCube |
| .lmp | Doom (vanilla 1.9) | DOS / PC |

Every parser produces the same in-memory shape: a `replayr_movie` S3
object with a `(n_frames, n_players, n_buttons)` logical input array
indexed against a single 40-slot universal-button layout, plus the
file’s header metadata and a per-frame commands vector.

![replayr universal-button
layout](reference/figures/universal_buttons_layout.svg)

replayr universal-button layout

Slots 1–30 cover the gamepad family (d-pad, Start/Select/Mode, six face
buttons, two shoulders, two triggers, four C-buttons, and the eight
stick directions). Slots 31–40 cover the Intellivision / ColecoVision
numeric keypad. INTV’s Enter / Clear and Coleco’s Star / Pound fold into
Start (slot 5) and Select (slot 6) — they’re pressed once at boot, not
as gameplay verbs, so they share semantics with console Start/Select
rather than getting their own slots.

## Quick start

``` r

library(replayr)

# Use a bundled sample (one is shipped per format).
fp <- system.file("extdata", "sample.fm2", package = "replayr")
mv <- read_movie(fp)
mv
#> <replayr_movie [fm2] frames=1748 players=2 buttons=8 source=sample.fm2>

n_frames(mv)            # frame count
press_counts(mv)        # named vector of per-button hold counts
p1 <- player(mv, 1L)    # logical matrix (frames x buttons)
```

`system.file("extdata", package = "replayr")` lists every bundled
sample. To parse your own movie file, just pass the path:

``` r

mv <- read_movie("/path/to/your/movie.bk2")
```

## Universal button layout

The 40-slot universal-button alphabet is documented in
[`?universal_buttons`](https://tp451.github.io/replayr/reference/universal_buttons.md).
Slots 1..8 are NES-shaped (R, L, D, U, Start, Select, B, A); higher
slots cover SNES face/shoulder buttons, the N64 C-buttons, an
8-direction quantisation of any analog stick, and PSX- specific L2/R2.
`n_buttons(mv)` tells you how many slots a particular movie actually
uses (8 NES, 12 SNES, 15 Genesis, 28 N64/GameCube, 30 PSX).

## Install

From GitHub:

``` r

# install.packages("remotes")
remotes::install_github("tp451/replayr")
```

From a local clone:

``` r

# install.packages("devtools")
devtools::install("path/to/replayr")
```

## Test

``` r

devtools::test("path/to/replayr")
```

The test suite is self-contained against the bundled fixtures. The .pxm,
.pjm, and .dtm tests skip by default because their typical fixtures are
large (~0.3-0.7 MB each); set `REPLAYR_FIXTURE_DIR` to a folder
containing `raw_psx/<game>/<n>.pxm` etc. to enable them.

## Author

Thorben Pelzer (<thorben@pelzer.blog>).

## License

`replayr` is licensed under the [GNU General Public License version 2 or
later](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html). Six of
the twelve format readers were developed with reference to the upstream
emulator’s source tree (named in those files’ headers); those upstreams
are themselves GPL-2+, so the package as a whole is GPL.

## Acknowledgements

The format-specific readers build on documentation and reference
implementations from the speedrunning / TAS community. We are grateful
to the authors of these projects for keeping their formats open enough
to be re-implemented:

- **[Dolphin Emulator Project](https://github.com/dolphin-emu/dolphin)**
  – the `.dtm` GameCube movie format reader (`R/read_dtm.R`) was
  developed with reference to `Source/Core/Core/Movie.cpp`.
- **[id Software’s Doom source](https://github.com/id-Software/DOOM)** –
  the `.lmp` demo format reader (`R/read_lmp.R`) was developed with
  reference to `linuxdoom-1.10/g_game.c` and the [DoomWiki demo
  spec](https://doomwiki.org/wiki/Demo).
- **PSXjin** – the `.pjm` (text body) and `.pxm` (binary body) movie
  format readers were developed with reference to the PSXjin source
  tree.
- **[lsnes](https://github.com/Ilari-Pihlajisto/lsnes)** – the `.lsmv`
  movie format reader was developed with reference to the lsnes source
  tree.
- **[VBA-rerecording](https://github.com/TASEmulators/vba-rerecording)**
  – the `.vbm` movie format reader was developed with reference to
  `movie.h`.
- **TASVideos** – the
  [EmulatorResources](https://tasvideos.org/EmulatorResources) wiki
  provides community-authored format documentation. Every reader cites
  at least one TASVideos page.
- **FCEUX** – the [`.fm2` format spec](https://fceux.com/web/FM2.html)
  is the canonical reference for the FCEUX movie format.

Per-file attribution comments name the specific upstream references for
each derivative reader. The full provenance manifest is in
[`inst/COPYRIGHTS`](https://tp451.github.io/replayr/inst/COPYRIGHTS).

The `.fm2`, `.bk2`, `.fcm`, `.gmv`, `.m64`, and `.smv` readers were
written from public format specifications and to our knowledge do not
draw on any GPL emulator source, but they are still covered by the
package’s GPL (\>= 2) license.
