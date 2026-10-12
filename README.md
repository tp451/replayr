# replayr <img src="man/figures/logo.svg" align="right" height="139" alt="replayr hex logo" />

[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)

`replayr` imports emulator recordings into R. It reads the buttons, keys,
analogue sticks, pointer movement, touch, and motion-sensor values recorded
during play, together with their timing and emulator metadata.

## Getting started

Install from a source checkout:

```r
# install.packages("remotes")
remotes::install_local("path/to/replayr")
```

Read a recording and extract one controller:

```r
library(replayr)

path <- system.file("extdata", "sample.fm2", package = "replayr")
movie <- read_movie(path)
input <- player(movie, 1L)

n_frames(movie)
press_counts(movie)
button_layout(movie)
```

`input` is a logical matrix: rows are observations, columns are controls, and
`TRUE` means active. `button_layout()` identifies each column. For another
recording, pass its path to `read_movie()`; the file extension selects the reader.
`movie_members()` lists recordings inside a ZIP download, and
`read_movie(path, member = ...)` selects one of them.

## Controllers and control identities

Each S3 object contains digital inputs, numeric channels, commands, and
metadata. A `replayr_movie` stores its digital input in an array indexed by
observation, controller, and control. Event-based formats retain the key and
device fields present in the events; fixed gamepad layouts include unused
buttons as well as pressed ones.

Columns are compact within each recording. Stable IDs and keys identify
controls across layouts: a stick click, a direction derived from that stick,
and an N64 C-button each have their own identity. `button_layout(movie)` gives
the column-to-control mapping; `button_layout()` lists the shared registry.
Keyboard identities retain the source convention, such as X KeySyms or
Windows virtual keys.

The registry contains 53 consecutive IDs. Buttons with comparable roles
share an ID across devices. The main mappings are:

| Source controls | Shared control and ID |
|---|---|
| Arcade Attack, Punch, or button 1; Doom Attack | A (8) |
| Arcade buttons 5–8 | L1, R1, L2, R2 (11–14) |
| Arcade D or button 4 | Y (10) |
| Arcade Jump, Jump/Start, or button 2; Doom Use; missile | B (7) |
| Arcade Kick or button 3 | X (9) |
| GunCon trigger, side A, side B, and offscreen shot | A, B, X, Y (8, 7, 9, 10) |
| Intellivision Top | X (9) |
| Joystick buttons 1–8 | A, B, X, Y, L1, R1, L2, R2 (8, 7, 9–14) |
| Keypad Clear and Enter | Select (6) and Start (5) |
| Keypad digits 0–9 and Power Pad sensors 1–12 | Equal numbers share `numbered_0`–`numbered_12` (40–52) |
| Mouse buttons 4 and 5 | L1 and R1 (11 and 12) |
| Mouse left, right, and middle buttons | A, B, X (8, 7, 9) |
| Neo Geo A, B, C, and D | A, B, X, Y (8, 7, 9, 10) |
| Super Scope trigger, cursor, turbo, and pause | A, B, Mode, Start (8, 7, 19, 5) |
| View change | Select (6) |
| Wii Remote 1/2, +/−, and Home | X/Y (9/10), Start/Select (5/6), and Mode (19) |

Wii Remote D-pad and A/B buttons use the gamepad IDs. Nunchuk C/Z use
17/18, Classic Controller buttons use the corresponding gamepad IDs, and
libTAS Guide uses Mode. The microphone uses ID 53. Genesis and Saturn C
retain ID 17 because those controllers have separate C and X buttons.

These mappings align controller roles; the action performed by a button
still depends on the game. Keyboard keys, keypad Star/Pound, and controls
without a defined counterpart retain qualified source IDs. For example,
an arcade D button uses Y (10), while a libTAS keyboard D keeps
`control:keysym_64`. openMSX device-qualified controls also remain separate,
because its recordings can combine several devices in one input stream.

When multiple source buttons share an ID, the column is active if either
is pressed. `source_inputs` and `source_layout` preserve the separate
states and their mapping whenever aliases are combined. Wii device states
also appear in `poll_fields` as `wii_remote_*` and `wii_classic_*` columns,
which `polls()` includes for unassigned streams.

![Universal button IDs for gamepads, both sticks, keypads, and peripherals, with named controls and numeric channels](man/figures/universal_buttons_layout.svg)

```r
aligned <- align_buttons(list(movie1, movie2))
```

The aligned matrices have matching columns, with absent controls filled by
`FALSE`. Comparing game actions also requires a mapping from controls to their
in-game meanings, such as Jump or Attack.

## Analogue and positional input

`analog_channels()` returns recorded numeric values. By default,
`analog = "raw"` leaves stick coordinates in this form. Four options add
directions or angles: `cardinal4`, `cardinal8`, `angle`, and
`angle+magnitude`. Settings can be chosen independently for each stick:

```r
path <- system.file("extdata", "sample.dtm", package = "replayr")
movie <- read_movie(path,
  analog = c(left = "angle+magnitude", right = "cardinal8"))
head(analog_channels(movie))
head(stick_channels(movie))
```

Cardinal modes add logical direction columns. Angles increase counterclockwise
from right: 0 degrees right, 90 up, 180 left, and 270 down. `deadzone` sets the
radial threshold for an active direction. Magnitude measures displacement
after applying the controller's centre and scale; diagonal values can exceed
one. The original coordinates remain available in every mode.

Mouse movement, light-gun aim, touch coordinates, dials, and motion sensors
also appear in `analog_channels()`, with names and units determined by the
recording format. Wii input can include accelerometer values, infrared points,
and MotionPlus readings. Sensor calibration is needed to convert these counts
to physical units. The package vignette demonstrates mouse
dragging and Wii motion with original examples; open it with
`vignette("replayr", package = "replayr")`.

For BK2 recordings, `system_channels()` returns cabinet and emulator controls,
such as coins, reset, disk selection, and input timing.

## Timing and multiple controllers

Rows may represent video frames, controller polls, or timestamped events.
`n_frames()` counts imported observations. The reader documentation describes the observation unit and any timing
information stored in the file. LSMV also records input changes within video
frames; `movie$subframes` identifies each observation's frame and position.

M64 and DTM can contain multiple controllers without identifying the source
port of each poll. These recordings return a `replayr_poll_stream`:

```r
path <- system.file("extdata", "paper", "unassigned.dtm", package = "replayr")
stream <- read_dtm(path)
polls(stream)
```

The polls retain their source order. A `controller_order` established from the
emulator can assign them to players. Wii and 3DS formats also distinguish
reports from different devices; their observation flags identify which input
fields each report supplies. See `?read_dtm` and `?read_ctm` for these fields.

## Formats and platforms

The package reads 34 format families, with HGM as an alias for Hourglass WTF.
The [compatibility catalogue](COMPATIBILITY.md) describes their versions,
controller variants, and platform coverage.

| Recording family | Emulator or recorder | Systems represented |
|------------------|----------------------|---------------------|
| BK2, BKM, TAS, TASPROJ | BizHawk | Consoles, handhelds, arcade machines, and home computers |
| CTAS | CoffeeTools | *UFO 50* |
| CTM | Citra | Nintendo 3DS |
| DFT | Dustmod | *Dustforce* input scripts and their dependencies |
| DSM | DeSmuME | Nintendo DS |
| DTM | Dolphin | GameCube, Wii |
| FBM | FinalBurn Alpha | Arcade games with an explicit driver input layout |
| FM2, FM3, FCM, FMV | FCEUX, FCEU, Famtasia | NES, Famicom Disk System |
| GBMV | GBAHawk | Game Boy Advance |
| GMV | Gens | Mega Drive, Sega CD, 32X |
| JRSR | JPC-rr | DOS PC |
| LMP | Doom, Boom | Doom 1.9 and Boom demo versions 200–202 |
| LSMV, SMV, ZMV | lsnes, Snes9x, enhanced ZSNES | SNES, Game Boy, Super Game Boy |
| LTM | libTAS | Linux applications, including emulated systems |
| M64, GZM | Mupen64, GZ | Nintendo 64 |
| MAR | MAME-rr | Arcade games with known or supplied port schemas |
| MC2 | PCEjin, VBjin | PC Engine, Virtual Boy |
| MCM | Mednafen-rr | PC Engine, PC-FX, Lynx, WonderSwan, Neo Geo Pocket, NES, Master System |
| MMV | Dega | Master System, Game Gear |
| OMR | openMSX | MSX, Spectravideo SVI-318/328 |
| PXM, PJM | PCSX-rr, PSXjin | PlayStation |
| VBM | VBA | Game Boy, Game Boy Color, Game Boy Advance |
| WTF, HGM | Hourglass | Windows applications |
| YMV | Yabause-rr | Saturn |

The supported recording formats cover the following platforms. Some desktop
and browser entries use input recorded by a host application through libTAS
or Hourglass; the catalogue identifies those combinations.

| Family | Platforms |
|---|---|
| Arcade and application platforms | Adobe Flash; Android; Arcade; IBM PC compatible; IBM PC DOS; Java 2 Platform, Micro Edition (J2ME); Mac OS / macOS; PICO-8; TIC-80; Web. |
| Atari | Atari 2600; Atari 7800; Atari Jaguar; Atari Jaguar CD; Atari Lynx. |
| Home computers and calculators | Amiga; Apple II; Commodore 64; MSX Home Computer System; Spectravideo SVI-318/328; Texas Instruments TI-83 Series; ZX Spectrum. |
| NEC | NEC PC-98; PC Engine / TurboGrafx-16; PC Engine CD / TurboGrafx-CD; PC-FX; SuperGrafx. |
| Nintendo | Famicom Disk System; Game Boy; Game Boy Advance; Game Boy Color; Nintendo 3DS; Nintendo 64; Nintendo 64DD; Nintendo DS; Nintendo DSi; Nintendo Entertainment System / Famicom; Nintendo GameCube; Satellaview; Super Game Boy; Super Nintendo / Super Famicom; Virtual Boy; Wii. |
| Other consoles | 3DO; CD-i; ColecoVision; Fairchild Channel F; Intellivision; Neo Geo Pocket; Odyssey 2 / Videopac; Sony PlayStation; Uzebox; Vectrex; WonderSwan. |
| Sega | Game Gear; Sega 32X; Sega CD / Mega-CD; Sega Genesis / Mega Drive; Sega Master System; Sega Saturn; Sega SG-1000. |

Arcade FBM recordings require a `game` identifier or `input_schema`, since
their fields follow the game driver's order. Decoding legacy Wii extension controls
requires the extension type and, when encrypted, its key. Reader help pages
describe the arguments needed for each variant.

## Large recordings

For BK2 logs that are too large to hold in memory, use a callback on successive
chunks:

```r
counts <- read_bk2_chunks("long-recording.bk2", press_counts)
Reduce(`+`, counts)
```

The input log is checked and extracted once. Temporary disk space must hold
the expanded log; the callback determines how much output is retained.
`read_bk2()` and `read_lsmv()` limit full imports to 256 MiB of expanded input
by default. `max_input_bytes` can raise this limit when memory permits.

## Tests and examples

The package includes original artificial recordings and their generators.
They exercise individual controls, movement patterns, device combinations,
and malformed input. Run the tests with `devtools::test("path/to/replayr")`.
Optional external tests use separately obtained TASVideos recordings through
`REPLAYR_FIXTURE_DIR`.

## Author and license

Thorben Pelzer (<thorben@pelzer.blog>). GPL version 2 or later.
Format documentation and emulator source references are listed in
[`inst/COPYRIGHTS`](inst/COPYRIGHTS).
