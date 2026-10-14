# Recording compatibility

`replayr` reads 37 file extensions in 33 recording formats: TASPROJ and GBMV
files have the structure of BK2, TAS that of BKM, FM3 that of FM2, and HGM
that of Hourglass WTF; the extension TXT is that of two formats, those of
the Atari Grand Challenge and Atari-HEAD data sets, which are told apart by
their first line. A
format can serve several platforms and controller layouts.
For example, a BK2 file can contain a calculator keypad, a PlayStation pad,
or a computer keyboard; its named fields determine the imported controls.

The tables identify supported layouts, format versions, and the recordings
used to check them. External checks cover 7,385 distinct recordings obtained
from [TASVideos](https://tasvideos.org/Movies), including obsolete publications,
and further files for the formats that TASVideos holds few or none of.
These checks are documented in the repository's [validation folder](validation/README.md), which lists the source of every file and provides the scripts to repeat them.
The package includes original artificial examples for testing and demonstration.

## Platforms represented in the checked recordings

The names and codes follow the [TASVideos system list](https://tasvideos.org/Systems),
with familiar regional names added where useful. Numbers in parentheses count
distinct recordings in each platform–format combination. The format and device
qualifications below describe which fields have a decoded interpretation.

A platform label can describe a game's original release platform while the
recording captures input to another application. The Android-labelled example,
for instance, uses Ruffle through libTAS. The CD-i and some Mac OS recordings
use MAME through libTAS; PC-98 examples use Neko Project through libTAS or
Hourglass. Flash, PICO-8, and Web recordings likewise use host-level input logs.
Linux and Windows applications are represented under the archive's IBM PC
compatible label. These distinctions matter when interpreting key codes and
pointer coordinates.

| Platform | Archive code | Formats (recordings checked) |
|---|---|---|
| 3DO | `3DO` | BK2 (3) |
| Adobe Flash | `Flash` | LTM (269) |
| Amiga | `Amiga` | BK2 (14) |
| Android | `Android` | LTM (1) |
| Apple II | `AppleII` | BK2 (5) |
| Arcade | `Arcade` | BK2 (101), FBM (62), LTM (8), MAR (21) |
| Atari 2600 | `A2600` | BK2 (140), BKM (24) |
| Atari 7800 | `A7800` | BK2 (11), BKM (2) |
| Atari Jaguar | `Jaguar` | BK2 (1) |
| Atari Jaguar CD | `JaguarCD` | BK2 (2) |
| Atari Lynx | `Lynx` | BK2 (9), MCM (1) |
| CD-i | `CDi` | LTM (1) |
| ColecoVision | `Coleco` | BK2 (26), BKM (2) |
| Commodore 64 | `C64` | BK2 (169) |
| Fairchild Channel F | `ChannelF` | BK2 (2) |
| Famicom Disk System | `FDS` | BK2 (11), FCM (12), FM2 (21), FMV (10) |
| Game Boy | `GB` | BK2 (177), BKM (7), LSMV (3), VBM (106) |
| Game Boy Advance | `GBA` | BK2 (274), GBMV (36), VBM (224) |
| Game Boy Color | `GBC` | BK2 (186), BKM (14), LSMV (6), VBM (76) |
| Game Gear | `GG` | BK2 (28), BKM (1), MMV (3) |
| IBM PC compatible | `PC` | BK2 (18), CTAS (4), DFT (1), LMP (19), LTM (129), WTF (37) |
| IBM PC DOS | `DOS` | BK2 (37), JRSR (76), LTM (11) |
| Intellivision | `INTV` | BK2 (50) |
| Java 2 Platform, Micro Edition (J2ME) | `J2ME` | BK2 (1) |
| Mac OS / macOS | `MacOS` | LTM (3) |
| MSX Home Computer System | `MSX` | BK2 (4), OMR (29) |
| NEC PC-98 | `PC98` | LTM (1), WTF (1) |
| Neo Geo Pocket | `NGP` | BK2 (7) |
| Nintendo 3DS | `3DS` | BK2 (22), CTM (5) |
| Nintendo 64 | `N64` | BK2 (74), BKM (4), GZM (1), M64 (85) |
| Nintendo 64DD | `N64DD` | BK2 (1) |
| Nintendo DS | `DS` | BK2 (88), DSM (124) |
| Nintendo DSi | `DSi` | BK2 (7) |
| Nintendo Entertainment System / Famicom | `NES` | BK2 (505), BKM (10), FCM (479), FM2 (807), FM3 (19), FMV (232), TAS (1), TASPROJ (1) |
| Nintendo GameCube | `GC` | DTM (140) |
| Odyssey 2 / Videopac | `O2` | BK2 (8) |
| PC Engine / TurboGrafx-16 | `PCE` | BK2 (27), BKM (4), MC2 (7), MCM (5) |
| PC Engine CD / TurboGrafx-CD | `PCECD` | BK2 (8), MC2 (6) |
| PC-FX | `PCFX` | BK2 (1) |
| PICO-8 | `PICO8` | LTM (21) |
| Satellaview | `BSX` | BK2 (2), SMV (3) |
| Sega 32X | `32X` | BK2 (6), GMV (5) |
| Sega CD / Mega-CD | `SegaCD` | BK2 (20), GMV (9) |
| Sega Genesis / Mega Drive | `Genesis` | BK2 (227), BKM (4), GMV (364) |
| Sega Master System | `SMS` | BK2 (84), BKM (8), MMV (32), TAS (3) |
| Sega Saturn | `Saturn` | BK2 (24), BKM (1), YMV (2) |
| Sega SG-1000 | `SG1000` | BK2 (5), BKM (1) |
| Sony PlayStation | `PSX` | BK2 (252), PJM (59), PXM (51) |
| Spectravideo SVI-318/328 | `SVI3x8` | OMR (1) |
| Super Game Boy | `SGB` | BK2 (2), LSMV (1), VBM (22) |
| Super Nintendo / Super Famicom | `SNES` | BK2 (318), BKM (24), LSMV (83), SMV (410), ZMV (1) |
| SuperGrafx | `SGX` | BK2 (1), MC2 (1) |
| Texas Instruments TI-83 Series | `TI83` | BK2 (4) |
| TIC-80 | `TIC80` | BK2 (2) |
| Uzebox | `Uzebox` | BK2 (9) |
| Vectrex | `VEC` | BK2 (2) |
| Virtual Boy | `Vboy` | BK2 (13), MC2 (7) |
| Web | `Web` | LTM (2) |
| Wii | `Wii` | DTM (48) |
| WonderSwan | `WSWAN` | BK2 (11) |
| ZX Spectrum | `ZXS` | BK2 (72) |

## Format versions and variants

The version of a recording format and the version of its emulator are separate
facts. FCEUX 2.x recordings, for example, can use the same version-3 FM2 layout.
The table gives accepted structures and the variants found in the checked
publications. A range of emulator releases describes the collection; it does
not certify every intervening release or every optional device.

| Format / recorder | Implemented variants | Published-file evidence | Input scope |
|---|---|---|---|
| **BK2** — [BizHawk](https://github.com/TASEmulators/BizHawk/tree/ab81ea25762af8ece499ba278e3f5cc3848ec742) | Named LogKey fields in ZIP containers; Header and Input Log members with or without .txt; ordinary movies and embedded TAStudio input logs. The BK2 files of Gym Retro (`MovieVersion Retro`), whose control names lack the LogKey prefix. | 3,071; MovieVersion 0.0.1, 2.0, and 2.0.0; TAStudio 1.0 and 1.1 labels also occur. | Controller definitions determine Boolean and numeric fields. Linked Game Boy layouts, core-specific pad layouts, keyboards, and peripherals are included. Unknown calibration retains raw numeric values. |
| **BKM** — [BizHawk](https://github.com/TASEmulators/BizHawk/tree/ab81ea25762af8ece499ba278e3f5cc3848ec742/src/BizHawk.Client.Common/movie/import/bkm) | Legacy text layout, MovieVersion 0.0.1; fixed per-platform field order. | 106; legacy 0.0.1 headers, from several BizHawk 1.x releases. | Gamepads, ColecoVision keypads, and N64 axes; additional implemented layouts are described below. |
| **CTAS** — [CoffeeTools](https://github.com/Blaizer/CoffeeTools/blob/main/patches/CoffeeTools/code/gml_GlobalScript_CoffeeTools.gml) (*UFO 50*) | Format versions 3 and 4. | 4; one v3 and three v4. | Two-player *UFO 50* held states, press/release flags, Start press events, and randomisation seeds. |
| **CTM** — [Citra / Azahar](https://github.com/azahar-emu/azahar/blob/master/src/core/movie.cpp) | CTM 0x1B signature; 256-byte header and seven-byte tagged device polls (types 0–5). | 5; pad, touch, acceleration, gyroscope, and extra-HID polls. IR-RST C-stick polls have original-fixture coverage. | Pad/Circle Pad, touch, accelerometer, gyroscope, IR C-stick, and extra-HID fields. Device polls retain observation masks and source bytes. |
| **DEM** — [GoldSrc](https://github.com/YaLTeR/hldemo-rs/blob/cbc1efa212a4fc49c776304058efd07e0369caa7/src/types.rs) | Demo protocol 5 of the Half-Life engine, network protocols 42 to 48: sections, network-message frames with the command the client was sending (in the longer frames of protocols 42 and 43 as well), console commands. Demos that were not closed or were cut short are read up to their last complete frame. | Not in the TASVideos catalogue. 684 demos from the test material of four demo parsers and from nine collections of the Internet Archive: *Gunman Chronicles* (371), *Counter-Strike* (223), *Adrenaline Gamer* (64), *Half-Life* (15), *Natural Selection* (10), *Condition Zero* (1); network protocols 42 to 48; 96 of them recorded by a broadcast proxy. Eight demos of demo protocol 4 are refused: they store no command. | 16 game actions; the forward, side and up movement and the view angles a command asks for; impulse and weapon numbers; console commands with the key actions. A demo of a broadcast proxy (HLTV) holds no commands of a player, which the reader reports. Quake and Source demos, also `.dem`, are other formats. |
| **DFT** — [Dustmod](https://tasvideos.org/EmulatorResources/Dustmod) (*Dustforce DX*) | Gzip tar archives of input scripts, with INCLUDE and optional entry selection. | 1; Dustmod 27.6.1 publication. | Movement, actions, double taps, optional taunt/restart, mouse commands, and loading/synchronisation commands. Script rows provide an order; SYNCLOAD duration requires execution. |
| **DSM** — [DeSmuME](https://github.com/TASEmulators/desmume/blob/master/desmume/src/movie.cpp) | Versions 1 and 2; text and six-byte binary records; historical three- and four-field touch/microphone text records. | 124 text files: 119 v1 and five v2. Binary records have original-fixture coverage. | DS pad, touch coordinates/validity, microphone values, reset, and lid commands. Text-field variation follows the upstream parser. |
| **DTM** — [Dolphin](https://github.com/dolphin-emu/dolphin/tree/master/Source/Core/Core) | DTM 0x1A signature; standard eight-byte GameCube polls, 17-byte Zelda Edition polls, legacy Wii HID reports, newer serialised Wii states, and mixed device streams. | 188; GameCube, Wii, Zelda Edition, and mixed-device recordings, including source-verified Dolphin 5.0-20571 and 2407 framing. | GameCube buttons/sticks/triggers; Wii buttons, acceleration, IR, MotionPlus fields, and supported extensions. Device family and physical port are separate assignments; see the qualifications below. |
| **FBM** — [FinalBurn Alpha rerecording](https://tasvideos.org/EmulatorResources/Fbarr) | FB1/FR1 container with FGK adaptive Huffman input data and frame deltas; the text of the author after the input (FRM1). | 62; 42 verified driver layouts; 42 recordings with a text of their author. | An explicit game or input_schema supplies field identities and order. Digital, byte, and signed analogue fields retain their raw values. Streams requiring Huffman counter rescaling are outside the current decoder. |
| **FCM** — [FCEU](https://tasvideos.org/EmulatorResources/FCEU/FCM) | Binary format versions 1 and 2, with delta-coded controller changes. | 491; four v1 and 487 v2. | NES/FDS gamepads and emulator commands; version-specific header and metadata offsets. |
| **FM2** — [FCEUX](https://fceux.com/web/FM2.html) | Version-3 movie structure; text and binary input records. | 828; all version-3 headers, including Four Score and Zapper configurations. | NES/FDS pads, four-pad Four Score layouts, and Zapper trigger, coordinates, and light-hit fields. Famicom expansion-port devices need their own decoding. |
| **FM3** — [FCEUX TAS Editor](https://github.com/TASEmulators/fceux/blob/master/src/movie.cpp) | Version-3 movie section in a TAS Editor project; text and binary logs bounded by the declared movie length. | 19; 18 binary logs and one text log. | The FM2 controller layouts apply; trailing editor data is retained separately from the input log. |
| **FMV** — [Famtasia](https://tasvideos.org/EmulatorResources/Famtasia/FMV) | FMV 0x1A signature; 144-byte header, enabled-port flags, and optional FDS byte. | 242; Famtasia 5.1 publications. | One or two NES controllers and recorded disk-system values. |
| **GBMV** — [GBAHawk](https://github.com/alyosha-tas/GBAHawk) | BK2-style ZIP/LogKey container, including linked GBA controllers. | 36; GBAHawk MovieVersion 1.0 and 1.0.0; GBA, GBAL, GBAHawk, SubGBAHawk, and GBAHawkLink headers. | Game Boy Advance controls and any declared numeric/source timing fields. |
| **GMV** — [Gens](https://tasvideos.org/EmulatorResources/Gens/GMV) | Gens Movie TEST0–TEST9, TESTA, and TESTJ signatures; pad flags depend on the revision. | 378; TEST6 (7), TEST9 (51), TESTA (318), and TESTJ (2). | Three- and six-button pads; two- and three-player layouts. Earlier headers leave pad type unspecified while preserving the stored button bits. |
| **GZM** — [gz](https://github.com/MrPancakeTurtle/gz/blob/master/src/gz/gz_macro.c) (*The Legend of Zelda: Ocarina of Time*) | Big-endian input/seed sections, optional synchronisation sections, and footer; the format has no version signature. | 1; GZ 0.37 publication. | N64 buttons and signed stick axes per game update; press/release masks, reset, seeds, ocarina, and room-load records. |
| **JRSR** — [JPC-RR](https://tasvideos.org/EmulatorResources/JPC/JRSRFormat) | JRSR text archive with events and initialisation sections; absolute and relative timestamps. | 76; several JPC-RR 10.x and 11.x builds. | Keyboard transitions, mouse movement/buttons, joystick buttons and game-port hold times, and reset events. Additional emulator events retain their arguments. |
| **LMP** — [*Doom*, *Heretic*, *Hexen*](https://github.com/dsda-org/dsda-doom/blob/master/prboom2/src/g_game.c) | Doom 1.2 and earlier; Doom 1.4–1.9 (versions 104–109); TASDoom (110); Doom 1.91 (111); Boom (200–202); LxDoom and MBF (203); PrBoom (210–214); MBF21 (221); Heretic; Hexen. With or without the outer header of dsda-doom or PrBoom+um. | 19; version 109 (18) and version 202 (1). A further 352 demos from the [Doom Speed Demos Archive](https://dsdarchive.com) cover versions 106 (1), 109 (60), 202 (11), 203 (12), 214 (6) and 221 (238), Heretic (9) and Hexen (15). The other layouts are checked on FreeDoom's demos, rewritten in each layout and replayed in dsda-doom. | Attack, Use and Jump as game actions; signed forward/side movement and turning, stored with 8 or 16 bits; look, fly and artifact commands of Heretic and Hexen; weapon commands; dsda-doom's extended commands; multiplayer tic records. A demo without a version byte needs `game`. ZDoom, Doom Legacy and Doomsday write other formats. |
| **LSMV** — [lsnes](https://tasvideos.org/EmulatorResources/Lsnes/LSMV) | ZIP input logs with controlsversion 0; eight-column GB/GBC and 12-/16-column SNES/Super Game Boy pad masks; declared Super Scope on port 2. | 93; snes_ntsc, snes_pal, gdmg, ggbc, and gambatte_sgb_ntsc. All 18,898,751 input observations are checked, including 12,446,792 subframes between frame starts. | Every input row is preserved, with source frame/subframe positions and reset fields. Extended buttons ext0–ext3 and the full SGB source layout remain available. Gamepad ports share a mask width; declared Super Scope adds buttons and signed coordinates. Other non-gamepad port types require separate decoding. |
| **LTM** — [libTAS](https://github.com/clementgallet/libTAS/blob/master/src/program/movie/InputSerialization.cpp) | Native archives with config.ini and inputs; positional fields through 1.3.5 and later tagged fields, including ordered events. | 446; publications cite libTAS 1.3.1–1.4.8, with gaps between tested releases. | X KeySyms, absolute/relative mouse coordinates and wheel, up to four gamepads with six numeric axes each, rate changes, clocks, and event lists. |
| **M64** — [Mupen64 rerecording](https://tasvideos.org/EmulatorResources/Mupen/M64) | Format version 3; four-byte controller polls. | 85; all version 3. | N64 buttons and signed stick axes. Multiple enabled controllers retain unassigned polls unless a verified polling order is supplied. |
| **MAR** — [MAME rerecording](https://tasvideos.org/EmulatorResources/Mamerr/Mar) | MAMETAS version 1, including game-specific digital port words and analogue accumulators. | 21; MAME-rr 0.139 v0.1 alpha/beta, spanning 18 driver layouts. | The ROM identifier selects a bundled port schema; other drivers require input_schema. Source port words, timestamps, and analogue accumulator fields remain available. |
| **MC2** — [PCEjin / VBjin](https://github.com/TASEmulators/pcejin/blob/master/movie.cpp) | Version 1, text and binary records; PC Engine-family and Virtual Boy controller layouts. | 21 version-1 text files: 14 PCEjin and seven VBjin. Binary records have original-fixture coverage. | PC Engine, PC Engine CD, and SuperGrafx pads with up to five ports; Virtual Boy retains both directional pads. |
| **MCM** — [Mednafen rerecording](https://github.com/TASEmulators/mednafen-rr/blob/master/src/movie.cpp) | MDFNMOVI version 1; fixed pad descriptors for seven system codes. | 6; five pce and one lynx recording. | Implemented: pce, pcfx, lynx, wswan, ngp, nes, and sms. The five layouts absent from this archive are covered by original fixtures; arbitrary peripheral configurations are outside these fixed descriptors. |
| **MMV** — [Dega](https://github.com/Plombo/dega/blob/master/mast/video.cpp) | MMV signature, historical zero-offset defaults, and controller packets of at least two bytes. | 35; SMS/GG, Dega 1.14–1.16 variants. All use two-byte packets and input offset 244. | One Game Gear or two Master System pads. The header version is an emulator build number, rather than a separate accepted-format version list. |
| **OMR** — [openMSX](https://github.com/openMSX/openMSX/blob/f07bee985b8e2102c47913c217ad0365638bf8ae/src/input/StateChange.hh) | Gzip-compressed XML replay events and initial keyboard snapshot. | 30; XML replay version 4; keyboard, joystick, autofire, and command events. Original fixtures exercise mouse, trackball, paddle, touchpad, JoyMega, JoyHandle, Arkanoid dial, and both light-gun models. | Keyboard matrices and held buttons, relative movement, absolute touch coordinates, wheel values, and device-specific gun trigger/light states. Raw gun status, device names, master-clock timestamps, and original event XML remain available. |
| **PJM** — [PSXjin](https://github.com/Nitrofski/psxjin/blob/master/psxjin/movie.cpp) | Version 2; text and binary digital/analogue pad layouts, one or two ports, including savestate-start headers. | 59; standard pads and DualShock configurations. | Digital buttons, L3/R3 on analogue pads, and four stick axes. Mouse, neGcon, and light-gun layouts require separate decoding. |
| **PXM** — [PCSX rerecording](https://github.com/TASEmulators/pcsxrr) | Version 2 binary records; controller types 4 (digital), 5 (analogue joystick), and 7 (DualShock). | 51; standard pads and one DualShock/standard-pad pair. | Digital buttons, L3/R3 on analogue pads, and four stick axes. Mouse, neGcon, and light-gun layouts require separate decoding. |
| **SMV** — [Snes9x](https://tasvideos.org/EmulatorResources/Snes9x/SMV) | Format versions 1, 4, and 5; standard pads and multitaps. | 413; v1 (339), v4 (65), and v5 (9). | SNES/Satellaview pads and reset commands; sample counts remain distinct from video-frame counts. Mouse, Super Scope, and Justifier layouts require separate decoding. |
| **TAS** — [Early BizHawk](https://github.com/TASEmulators/BizHawk/tree/ab81ea25762af8ece499ba278e3f5cc3848ec742) | Legacy BKM-style text, MovieVersion 0.0.1. | 4; one NES and three Master System movies. | Uses the BKM field decoder. This extension identifies the early BizHawk layout here; unrelated .tas scripts need their own reader. |
| **TASPROJ** — [BizHawk TAStudio](https://github.com/TASEmulators/BizHawk/tree/ab81ea25762af8ece499ba278e3f5cc3848ec742) | BK2-style ZIP with a named input log; project metadata accompanies the movie. | 1 .tasproj; TAStudio 1.1 label. Additional TAStudio labels occur in BK2 files. | Imports the current input log using BK2 rules; editor history and branches remain outside the imported movie. |
| **TXT** — [Atari Grand Challenge data set](https://arxiv.org/abs/1705.10998), version 1 | Text table of one episode, known by its first line: a line with the number of the trajectory, the names of the columns, and rows of frame, reward, score, terminal and action. | 2,313; every trajectory of the release, in five games. | The 18 action numbers of the Arcade Learning Environment as the five controls of one joystick. Reward, score and the end of the episode are states of the game and are not read. |
| **TXT** — [Atari-HEAD data set](https://doi.org/10.5281/zenodo.3451402) | Text table of one trial, known by its first line: the names of the columns, then rows of frame identifier, episode, score, duration, reward, action and gaze positions (the points on the screen at which the player was looking, measured by an eye tracker), with `null` for a value that is missing. | 471; every trial of the release, in 20 games. | The same controls. The duration of each frame gives the time of each observation. Score, reward, episode and gaze positions are not read. |
| **VBM** — [VBA rerecording](https://github.com/TASEmulators/vba-rerecording) | Format version 1; Game Boy, Game Boy Color, Game Boy Advance, and Super Game Boy flags. | 428; all version 1. | Gamepads and emulator command bits for the selected system. |
| **WTF / HGM** — [Hourglass](https://tasvideos.org/EmulatorResources/Hourglass/WTF) | 66 54 77 02 signature; 1,024-byte header and eight-byte keyboard records. HGM is an extension alias. | 38 WTF recordings; HGM dispatch is tested with original data. | Windows virtual-key states, including mouse-button virtual keys when recorded. This layout supplies no pointer coordinates or movement. |
| **YMV** — [Yabause rerecording](https://github.com/adelikat/yabause-rr/blob/master/src/windows/movie.cpp) | Enhanced version 1; text or three-byte binary Saturn-pad records. | 2; version-1 text, Yabause-rr r245. Binary records have original-fixture coverage. | One 13-control Saturn pad, including shoulders. The earlier unrelated pure-C movie layout requires a separate reader. |
| **ZMV** — [Enhanced ZSNES](https://github.com/emillon/zsnes/blob/master/src/zmovie.c) | Enhanced 1.51-era ZMV structure, including packed pad changes, repeats, resets, and chapter tables. | 1; ZSNES 1.51 publication. | Up to five SNES pads; repeated states expand into frame rows. Mouse and Super Scope records require separate decoding. |

### BizHawk and linked systems

BK2 preserves the controller names in `LogKey`, including fields from cores
with different input conventions. Checked examples include NesHawk,
QuickNes/quickerNES, SubNESHawk, BSNES and Snes9x, Gambatte and GBHawk,
SameBoy, mGBA and VBA-Next, Genplus-gx and PicoDrive, Mupen64Plus and Ares64,
Octoshock and Nymashock, Saturnus, MelonDS, Encore, MAME, DOSBox-X, UAE,
and the platform-specific keyboard and keypad cores. The full platform table
above includes their less common systems as well as NES, SNES, and PlayStation.

The recording header may use a family code: `GEN` covers Mega Drive-family
hardware, `NDS` covers DS/DSi, and `N64` may accompany a Nintendo 64DD game.
Linked Game Boy recordings use `DGB` or `GBL`; GBAHawk uses `GBAL` for a
linked GBA layout. Player columns follow the declared controller groups, and
link toggles remain system controls. The `Core`, `Platform`, and emulator-version
header fields remain available for identifying these variants.

The BKM reader implements the fixed legacy layouts for Atari 2600 and 7800,
ColecoVision, Game Boy/Color, Game Boy Advance, linked Game Boy, NES, SNES,
Mega Drive, Master System/Game Gear/SG-1000, Nintendo 64, PC Engine, Saturn,
WonderSwan, and TI-83. GBA, linked GB, WonderSwan, and TI-83 BKM layouts follow
the upstream descriptors but have no dedicated fixture or published-file
coverage in this collection. MCM's PC-FX, WonderSwan, Neo Geo Pocket, NES, and
Master System layouts have original fixture coverage; the six published MCM
files cover PC Engine and Lynx.

The openMSX publications contain keyboard, joystick, autofire, and emulator
command events. Original examples additionally exercise mouse movement and
buttons, trackball and paddle deltas, absolute touchpad coordinates, each
JoyMega and JoyHandle button, the JoyHandle wheel, the Arkanoid dial, and both
light-gun models. These checks use distinct numeric values and individual
button presses derived from the serialised event definitions. Gunstick and
Terminator Laser use different trigger pins and light-sensor polarity; both
retain their complete port-status byte alongside the decoded trigger and
light state. The gun events record sensor responses rather than aim coordinates.

### Input observations within video frames

An lsnes movie can record several input observations within one video frame.
LSMV import retains all of them: `n_observations()` counts input observations, while
`header$frameCount` counts the rows marked as new video frames. The
`movie$subframes` table links each observation to its source line, video frame,
and position within that frame, and retains the reset fields.
The exact input text remains in `source_input`.

The 16-control SNES layout includes `lsnes_ext0` through `lsnes_ext3`.
Super Game Boy recordings retain the complete SNES-side control layout.
A declared Super Scope on port 2 supplies trigger, cursor, turbo, and pause
states, plus signed `aim_x` and `aim_y` coordinates. The source UI uses ranges
of −16 to 271 horizontally and −16 to 255 vertically; the reader preserves
the stored signed values without normalisation.

### Controls beyond standard gamepads

| Input family | Decoded representation and relevant readers |
|---|---|
| Arcade and system controls | BK2 cabinet controls, MAR port words/analogue accumulators, and FBM driver fields retain coins, service inputs, reset, and game-specific controls. FBM needs a verified driver layout; MAR uses the stored ROM identifier or an explicit schema. |
| Keyboards and calculator keys | BK2/BKM named keys, libTAS X KeySyms, Hourglass Windows virtual keys, JPC-RR key codes, and openMSX keyboard-matrix positions. Namespaces remain distinct until an explicit mapping is supplied. |
| Keypads and unusual digital controllers | ColecoVision, Intellivision, Jaguar, and TI-83 controls; all 16 named Intellivision disc directions; Channel F push/pull/twist contacts; Virtual Boy's two directional pads; WonderSwan X/Y controls; NES Power Pad's 12 sensors. Equal keypad digits and Power Pad sensor numbers share IDs; Star/Pound, disc directions, and device-specific contacts retain qualified identities. |
| Light guns and pointing | FCEUX Zapper, BK2 Zapper/PlayStation light-gun fields, and declared LSMV Super Scope inputs retain buttons and numeric coordinates. openMSX Gunstick and Terminator Laser events retain trigger/light states and raw port status. Wii IR reports retain individual camera-point coordinates and sizes. Coordinate systems differ across devices. |
| Mice, trackballs, paddles, and dials | BK2, LTM, JRSR, OMR, and DFT retain the fields their formats record. Absolute positions, relative movement, scroll values, and paddle/dial counts keep their source meaning. Hourglass supplies virtual keys only. |
| Motion and sensors | CTM accelerometer/gyroscope fields, BK2-declared tilt/acceleration/light sensors, and decoded Wii acceleration/MotionPlus counts retain source values. MotionPlus range flags accompany its counts. These channels do not by themselves provide physical acceleration, angular velocity, or reconstructed orientation. |
| Sticks | Source X/Y values are available independently of derived modes. Known N64, PlayStation, GameCube, Wii-extension, 3DS, Saturn 3D-pad, and libTAS layouts support cardinal4, cardinal8, angle, and angle+magnitude, independently for each stick. Calibration follows the recording's device/core layout. |
| Touchscreens and microphones | DSM, DS/DSi BK2, 3DS BK2, and CTM retain recorded touch fields. DS microphone activation/volume fields are preserved where present. CTM touch validity marks an observed touch; it does not imply that every adjacent device poll contains touch data. |

### Dolphin reports, observation masks, and port assignment

Standard GameCube DTM and M64 contain ordered controller polls without a port
label on each poll. With several enabled ports, `polls()` preserves the order
and leaves unknown ports as `NA`. A verified `controller_order` can establish
an assignment. GameCube and Wii device families can be distinguished in some
mixed streams while the physical port within a family remains unknown.

Legacy Wii HID reports and newer serialised Wii states use different field
layouts. Serialised states identify their extension type. HID recordings
require `wii_extension = "nunchuk"` or `"classic"` when that extension is known,
and `wii_key` for encrypted extension bytes. The default keeps those bytes
available. Nunchuk and Classic controls are decoded when the required context
is supplied; other extension payloads remain raw.

For modern mixed streams, the reader uses verified native encoding rules from
Dolphin 5.0-20571 and 2407 when the recording identifies the corresponding
revision. The `mixed-hid-nomarker` layout accepts connected GameCube polls and
the encoder's restricted disconnected state alongside Wii reports. The older
`mixed-hid` layout uses its recorded marker. An explicit
`mixed-hid-connected` choice remains available when the caller has established
that every GameCube poll is connected; the header records that assumption.
An unfamiliar revision with ambiguous framing requires additional context.

CTM provides `observed_inputs` to distinguish an unobserved control from an
observed released button. Wii polls instead identify `report_id` and
`valid_report`, with `core_present` where reports can omit the core buttons;
unobserved numeric channels use `NA`. Mixed DTM also supplies `observed_gc`
and `observed_wii`. Original reports remain in `poll_bytes`.

### Source integrity and recording size

Compressed input members are checked during extraction. A damaged input member
stops import; recoverable faults are reported with a warning. Format-specific
metadata records declared counts, observed counts, and unused source bytes.

`read_bk2()` limits the expanded input log to 256 MiB by default.
`max_input_bytes` can raise that limit when memory permits, below R's
single-string limit. `read_bk2_chunks()` verifies and extracts the input log
once, then processes bounded groups of rows; it therefore needs temporary
disk space for the expanded log. The callback determines how much output is
retained. `read_lsmv()` also has a 256 MiB default with an explicit override.

## Format references

The table links the relevant specifications and serialisation sources.
Component-level provenance is recorded in [inst/COPYRIGHTS](inst/COPYRIGHTS).
The original examples under `inst/extdata/` exercise supported layouts,
including device combinations absent from the published collection; their
generators are under `tools/` or alongside the unit tests. 
