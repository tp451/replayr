# Public readers separate decoding from layout configuration. Decoders retain
# source values and controller identities; .configure_movie() assigns compact
# columns, shared IDs, and the requested analogue representation.
#' Read a FM2 recording
#'
#' FCEUX text movies; NES and Famicom button states.
#' Digital columns are compact; [button_layout()] gives their stable IDs.
#' Numeric source channels are always retained in [analog_channels()].
#'
#' A position of a gamepad field is held unless it shows `.` or a space, as
#' FCEUX reads it; the letter written there is a convention. Controllers
#' follow the port declarations: a port declared empty is no controller, and
#' `header$controllerPorts` gives the port of each player. As in FCEUX, a
#' file is an FM2 movie only if it begins with `version 3`; any other file
#' is refused.
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and selected stick fields.
#' @export
#' @examples
#' path <- system.file("extdata", "sample.fm2", package = "replayr")
#' movie <- read_fm2(path)
#' movie
#' recording_info(movie)
read_fm2 <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_fm2(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a BK2 recording
#'
#' BizHawk ZIP movies. LogKey names determine digital controls and numeric channels. Known N64 and
#' PlayStation stick encodings can be transformed; other numeric channels remain raw.
#' The BK2 files that Gym Retro writes are read as well. Their input log names the controls
#' without the `LogKey:` prefix and its Reset and Power group; the reader restores both and notes
#' it in `movie$header$logKeyRestored`. Buttons 1 and 2 of a Master System or Game Gear pad, which
#' Gym Retro writes as B and A, are named `B1` and `B2` as in a BizHawk recording.
#' An arcade cabinet's analogue joysticks are its left and right analogue stick. MAME records their
#' raw values without centre or range, which differ from cabinet to cabinet; when directions or
#' angles are requested, both are estimated from the values of the recording, with a warning that
#' states the estimate.
#' Digital columns are compact; [button_layout()] gives their stable IDs.
#' Numeric source channels are always retained in [analog_channels()].
#' The full import defaults to a 256 MiB limit on the expanded input log to
#' avoid large temporary allocations. [read_bk2_chunks()] processes larger
#' recordings in bounded memory. The final movie and parsing buffers can use
#' substantially more memory than the text itself.
#'
#' Like BizHawk, the reader takes input rows and the LogKey only from lines
#' that start with them. If the LogKey line is indented, its control layout is
#' still used and a warning is given; indented input rows stay excluded and
#' are counted in `header$indentedInputLines`. A log without a LogKey is read
#' only when its header and every row match the standard two-pad NES layout;
#' any other log without a LogKey raises an error.
#' A digital control is held unless its character is `.`, as BizHawk reads
#' it; the letter written there is a convention.
#' @inheritParams read_movie
#' @param max_input_bytes Maximum expanded input-log size for a full import,
#'   in bytes. The default is `256 * 1024^2`. Increase this explicitly when
#'   sufficient memory is available, up to R's single-string limit of
#'   `2147483647` bytes. The limit is checked before extracting the input log.
#' @return A [replayr_movie] with compact digital columns and selected stick fields.
#' @export
#' @examples
#' movie <- read_bk2(system.file("extdata", "sample.bk2", package = "replayr"))
#' movie
#' head(system_channels(movie), 3)
#' # A mouse recorded by BizHawk: its buttons are controls, its movement
#' # is two numeric channels.
#' mouse <- read_bk2(system.file("extdata", "paper", "mouse-drag.bk2", package = "replayr"))
#' button_layout(mouse)[, c("key", "name")]
#' channel_layout(mouse)
read_bk2 <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE,
                     max_input_bytes = 256 * 1024^2, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(
    .decode_bk2(path, max_input_bytes = max_input_bytes, ...),
    analog, deadzone, triggers, aliases
  )
}
#' Read a FCM recording
#'
#' FCEU binary NES movies, including supported delta-stream versions.
#' Digital columns are compact; [button_layout()] gives their stable IDs.
#' Numeric source channels are always retained in [analog_channels()].
#'
#' `commands` holds one bit for every control code applied in a frame, bit
#' `code - 1`: 1 is a reset, 2 a power cycle, 64 a VS System coin, 8388608
#' an FDS disk insert, 16777216 an FDS eject and 33554432 an FDS side
#' select.
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and selected stick fields.
#' @export
#' @examples
#' movie <- read_fcm(system.file("extdata", "sample.fcm", package = "replayr"))
#' movie
#' n_players(movie)
read_fcm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_fcm(path, ...), analog, deadzone, triggers, aliases)
}
#' Read an lsnes LSMV recording
#'
#' Reads ZIP input logs with `controlsversion` 0: Game Boy/Game Boy Color pads,
#' SNES 12- and 16-button pads, multitaps, Y-cabled pads, and a declared
#' Super Scope on port 2. Super Game Boy movies retain their SNES controller
#' layout. The four spare bits of a 16-bit pad report are not buttons of the
#' pad; [system_channels()] returns them as `pad<n>_ext0` to `pad<n>_ext3`.
#'
#' Every non-empty input row is retained, including subframes between frame
#' starts. [n_observations()] counts these observations; `header$frameCount` counts
#' frame starts. `subframes` contains `source_line`, `frame_start`,
#' `source_frame`, and `subframe` (the row's one-based position within its
#' source frame). Player indices follow controller fields in the source log.
#'
#' `subframes` also retains `reset`, `hard_reset`, `reset_delay_high`, and
#' `reset_delay_low`. The encoded delay is `10000 * reset_delay_high +
#' reset_delay_low`. `commands` uses bit 0 for the reset flag and bit 1 for
#' the hard-reset flag. `source_input` preserves the complete input text,
#' including blank lines and original line endings.
#'
#' Super Scope controls use `a` (trigger), `b` (cursor), `mode` (turbo),
#' and `start` (pause). Their separate source keys remain in `source_layout`.
#' [analog_channels()] returns its signed source coordinates as `aim_x` and `aim_y`. [button_layout()] gives
#' stable control IDs. Mouse and Justifier port types raise an error.
#'
#' The input member's ZIP checksum is verified before parsing. Full imports
#' default to a 256 MiB expanded-input limit. Damaged controller metadata
#' raises an error; other complete metadata with an integrity defect is
#' retained with a warning.
#' @inheritParams read_movie
#' @inheritParams read_bk2
#' @return A [replayr_movie] with one observation per input subframe.
#' @export
#' @examples
#' movie <- read_lsmv(system.file("extdata", "sample.lsmv", package = "replayr"))
#' observation_unit(movie)
#' head(movie$subframes[, c("source_frame", "subframe", "reset")], 3)
read_lsmv <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE,
                      max_input_bytes = 256 * 1024^2, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_lsmv(path, max_input_bytes = max_input_bytes, ...), analog, deadzone, triggers, aliases)
}
#' Read a GMV recording
#'
#' Gens recordings with three- or six-button controllers. Controller capability comes from the
#' header, with older unspecified types retained explicitly.
#' Digital columns are compact; [button_layout()] gives their stable IDs.
#' Numeric source channels are always retained in [analog_channels()].
#'
#' A two-controller recording stores X, Y, Z and Mode for both controllers
#' whatever their declared type. For a controller declared as three-button
#' these four lie outside its layout; `commands` retains them as pressed
#' bits, 1, 2, 4 and 8 for controller 1 and 16, 32, 64 and 128 for
#' controller 2.
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and selected stick fields.
#' @export
#' @examples
#' movie <- read_gmv(system.file("extdata", "sample.gmv", package = "replayr"))
#' movie
#' button_layout(movie)[, c("id", "key", "name")]
read_gmv <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_gmv(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a VBM recording
#'
#' VBA recordings for Game Boy, Game Boy Color, Super Game Boy and Game Boy
#' Advance. Game Boy and Game Boy Color recordings have eight controls. Game
#' Boy Advance and Super Game Boy recordings add L and R: a Super Game Boy is
#' played with an SNES pad, and the format records both buttons.
#' Digital columns are compact; [button_layout()] gives their stable IDs.
#' Numeric source channels are always retained in [analog_channels()].
#'
#' Every stored controller record is imported; `header$declaredFrameCount`
#' keeps the header's count. `commands` retains the bits of each controller
#' word that lie outside the layout, with their original values: 1024 and
#' 2048 mark a reset (old timing, and the timing used since format version
#' 1.1), and 4096 to 32768 are the deprecated motion-sensor bits.
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and selected stick fields.
#' @export
#' @examples
#' movie <- read_vbm(system.file("extdata", "sample.vbm", package = "replayr"))
#' movie
#' recording_info(movie)
read_vbm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_vbm(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a M64 recording
#'
#' Mupen64 version 3 recordings. A single enabled controller returns a
#' [replayr_movie]. Multiple enabled controllers return a [replayr_poll_stream]
#' with all samples in source order, because M64 stores no per-sample port IDs.
#' Digital columns are compact; [button_layout()] gives their stable IDs.
#' Numeric source channels are always retained in [analog_channels()].
#'
#' An externally verified repeating polling order can be supplied to construct
#' per-player matrices. These use compact player indices in ascending physical
#' port order; `movie$header$controllerPorts` gives the physical port for each
#' player index. Enabled ports omitted from that order are treated as unpolled.
#' Each output row is one supplied polling cycle, not a video frame. The source
#' poll count and VI count remain in `header$inputSampleCount` and
#' `header$viCount`; `poll_bytes` retains four original bytes per source poll.
#' Import stops at the declared sample count, as Mupen playback does. Legacy
#' writers can leave an extra terminal record or an older file suffix; these
#' bytes remain in `source_tail`.
#'
#' @param controller_order Optional sequence of distinct enabled controller
#'   ports (1--4) in an externally verified repeating polling order. `NULL`
#'   preserves an unassigned stream when multiple ports are enabled.
#' @inheritParams read_movie
#' @return A [replayr_movie] for an assigned controller order, or a
#'   [replayr_poll_stream] for multiple controllers with unassigned ports.
#' @export
#' @examples
#' movie <- read_m64(system.file("extdata", "sample.m64", package = "replayr"))
#' observation_unit(movie)
#' head(analog_channels(movie), 3)
#' # The stick as eight directions beside the buttons.
#' directions <- read_m64(system.file("extdata", "sample.m64", package = "replayr"),
#'   analog = "cardinal8")
#' n_buttons(directions)
read_m64 <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE,
                     controller_order = NULL, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(
    .decode_m64(path, controller_order = controller_order, ...),
    analog, deadzone, triggers, aliases
  )
}
#' Read a SMV recording
#'
#' Supported Snes9x versions and joypad controllers.
#' Digital columns are compact; [button_layout()] gives their stable IDs.
#' Numeric source channels are always retained in [analog_channels()].
#'
#' Each row is an input sample. A recording holds one sample more than its
#' frame count. Version 4 and 5 files also declare a count of input samples;
#' when that count is larger and the samples are stored, all of them are
#' returned. Bytes after the declared range are left unread and counted in
#' `header$unusedTrailingBytes`.
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and selected stick fields.
#' @export
#' @examples
#' movie <- read_smv(system.file("extdata", "sample.smv", package = "replayr"))
#' movie
#' press_counts(movie)
read_smv <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_smv(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a PXM recording
#'
#' PCSX standard digital and analogue-controller records. Unsupported devices are rejected;
#' reserved standard-pad bits do not become stick clicks.
#' Digital columns are compact; [button_layout()] gives their stable IDs.
#' Cross, Circle, Triangle and Square keep their names and have the IDs of
#' the SNES buttons in the same places: B, A, X and Y.
#' Numeric source channels are always retained in [analog_channels()].
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and selected stick fields.
#' @export
#' @examples
#' movie <- read_pxm(system.file("extdata", "semantic", "semantic-onehot.pxm", package = "replayr"))
#' # Cross, Circle, Triangle and Square take the identities of the buttons
#' # in the same places on an SNES pad.
#' button_layout(movie)[7:10, c("key", "name")]
#' channel_layout(movie)
read_pxm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_pxm(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a PJM recording
#'
#' PSXjin text and binary recordings with standard or analogue controllers.
#' Every complete record is imported, following PSXjin's file-length rule.
#' The header retains declaredFrameCount, availableFrameCount, and their
#' signed frameCountDifference. Text fields follow the declared encoding and
#' controller types. Count differences remain metadata; incomplete records
#' are rejected.
#' Digital columns are compact; [button_layout()] gives their stable IDs.
#' Cross, Circle, Triangle and Square keep their names and have the IDs of
#' the SNES buttons in the same places: B, A, X and Y.
#' Numeric source channels are always retained in [analog_channels()].
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and selected stick fields.
#' @export
#' @examples
#' movie <- read_pjm(system.file("extdata", "sample.pjm", package = "replayr"))
#' movie
#' n_players(movie)
read_pjm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_pjm(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a DTM recording
#'
#' Dolphin GameCube and Wii recordings. Multiple enabled ports return an ordered
#' [replayr_poll_stream] with unassigned ports. An optional `controller_order`
#' constructs player streams using a caller-verified repeating port order.
#'
#' Every complete stored poll is imported. Dolphin's header input statistic is
#' retained as `header$inputCount`, alongside `header$availablePollCount` and
#' their signed difference in `header$pollCountDifference`. Dolphin uses the
#' input count as a statistic, so differences remain metadata.
#' `header$frameCount` retains the separate video-frame count.
#'
#' Zelda Edition extends each poll with a loading flag, a Tingle Tuner event
#' code, and Link's X/Z coordinates used by the emulator to detect desyncs.
#' These are available in `poll_fields`, with one row per original poll,
#' including when `controller_order` groups polls into player cycles.
#' Columns are `loading`, `tuner_event`, `link_x`, and `link_z`; coordinates
#' retain the game's source units. `poll_bytes` retains all original bytes.
#' Wii Remote recordings retain buttons, source motion values, and IR coordinates.
#' Wii Remote 1/2 use X/Y (IDs 9/10), +/- use Start/Select (5/6), and
#' Home uses Mode (19). Its D-pad and A/B buttons share the gamepad IDs.
#' Nunchuk C/Z use 17/18, Classic Controller buttons use the corresponding
#' gamepad IDs, and libTAS Guide uses Mode. Light-gun triggers use A (8);
#' GunCon side A/B and offscreen shot use B/X/Y (7/9/10). Mouse left, right,
#' and middle buttons use A/B/X. See [button_layout()] for shared identities.
#'
#' When multiple source buttons share an ID, the column is active if either
#' is pressed. `source_inputs` and `source_layout` preserve the separate
#' states and their mapping whenever aliases are combined. Wii device states
#' also appear in `poll_fields` as `wii_remote_*` and `wii_classic_*` columns,
#' which `polls()` includes for unassigned streams.
#' Legacy HID reports retain extension bytes; `wii_extension = "nunchuk"` or
#' `"classic"` decodes a caller-identified extension. Supply `wii_key` when its
#' reports are encrypted. The default retains the bytes because older DTM files
#' do not store an extension identity or encryption key. New serialised Dolphin
#' states include their extension type; Nunchuk and Classic Controller states
#' are decoded automatically. Other extension payloads remain source bytes.
#' Each row is a poll. `poll_lengths` gives valid bytes in the padded
#' `poll_bytes` matrix; historical eight-byte prefixes remain in `poll_prefix_bytes`.
#' Wii Remote acceleration is given on Dolphin's ten-bit scale. A report
#' stores nine bits for Y and Z, which are widened as Dolphin widens them,
#' by repeating the lowest stored bit.
#' Mixed GameCube/Wii streams from the verified legacy Dolphin layout retain
#' device family and physical port (when unique) on each poll. They stay in
#' source order and do not accept `controller_order`. Automatic mixed recognition
#' uses revision `7804f388aeb075266ae8c363e0932c355ba6ed5e`; select `mixed-hid`
#' explicitly only for a build with the same verified record layout.
#' An incomplete final Wii packet is retained in `source_tail`, with a warning.
#' Invalid reports retain their raw bytes and have `valid_report = FALSE`.
#' `poll_fields$report_issue` describes the problem, and `source_offset` gives
#' the zero-based byte position in the file. Filter digital fields using the
#' validity flag before analysis.
#' @param wii_variant `"auto"`, `"hid"`, `"hid-prefix8"`, `"hid-nomarker"`,
#'   `"serialized"`, `"mixed-hid"`, `"mixed-hid-nomarker"`, or
#'   `"mixed-hid-connected"`. Automatic selection uses packet structure and,
#'   for mixed recordings, verified Dolphin revision profiles.
#'   `"hid-nomarker"` handles reports starting with the Wii report ID.
#'   `"mixed-hid-nomarker"` implements the native encoder rule: connected
#'   GameCube reports set the connection flag, disconnected reports have
#'   zero controls (with optional disc/reset commands), and Wii reports
#'   carry a prescribed length and report ID. Noncanonical records are rejected.
#'   Profiles for Dolphin 5.0-20571 and 2407 are selected automatically from
#'   the stored revision. `header$framingRule` records the encoding rule.
#'   `"mixed-hid-connected"` remains available for externally verified files
#'   requiring the additional assumption that every GameCube poll is connected;
#'   that assumption is recorded in `header$framingAssumption`.
#'   `polls()` retains device family, connection flags, and source order.
#'   Individual ports remain unassigned when several same-family ports are enabled.
#' @param wii_extension Legacy extension interpretation: `"raw"` (default),
#'   `"nunchuk"`, or `"classic"`. A selected type assumes unencrypted reports
#'   unless an encryption key is supplied.
#' @param wii_key Optional 16-byte numeric vector: the eight `ft` bytes followed
#'   by the eight `sb` bytes of the verified Dolphin extension key.
#' @param dtm_variant `"auto"` (default), `"standard"` (8-byte records), or
#'   `"zelda"` (17-byte Dolphin Zelda Edition records). Automatic recognition
#'   uses the verified Zelda Edition revision
#'   `a6e66c227c592d09ff09ef9b238d15ff52dd9632`; other revisions default to the
#'   standard layout. Select `"zelda"` explicitly for another build whose
#'   extended layout has been verified from its source.
#' @param controller_order Optional integer sequence listing every enabled
#'   controller port once, in its verified repeating polling order.
#' Digital columns are compact; [button_layout()] gives their stable IDs.
#' Numeric source channels are always retained in [analog_channels()].
#' @inheritParams read_movie
#' @return A [replayr_movie] for assigned ports, or a [replayr_poll_stream]
#'   for a multi-controller recording with unassigned ports.
#' @export
#' @examples
#' movie <- read_dtm(system.file("extdata", "sample.dtm", package = "replayr"))
#' head(analog_channels(movie), 3)
#' # Polls of several controllers without a known order stay one stream.
#' stream <- read_dtm(system.file("extdata", "paper", "unassigned.dtm", package = "replayr"))
#' class(stream)
#' polls(stream)[, c("poll", "port", "a", "left_x", "left_y")]
read_dtm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, controller_order = NULL,
  dtm_variant = "auto", wii_variant = "auto", wii_extension = "raw", wii_key = NULL, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(
    .decode_dtm(
      path, controller_order = controller_order, dtm_variant = dtm_variant,
      wii_variant = wii_variant, wii_extension = wii_extension, wii_key = wii_key, aliases = aliases, ...
    ),
    analog, deadzone, triggers, aliases
  )
}
#' Read a Doom-engine demo
#'
#' Imports demos of Doom, Heretic and Hexen and of the source ports that keep
#' their demo format: Doom 1.2 and earlier, Doom 1.4 to 1.9 (versions
#' 104-109), TASDoom (110), Doom 1.91 (111), Boom (200-202), LxDoom and MBF
#' (203), PrBoom (210-214) and MBF21 (221), with or without the outer header
#' that dsda-doom or PrBoom+um put in front. Each row is a game tic at 35
#' tics per second. `header$enabledPorts` identifies the players whose
#' commands were stored.
#'
#' A demo stores what the game was asked to do in each tic, not the keys or
#' buttons behind it. [player()] returns the actions Attack and Use, and Jump
#' for Hexen and for demos with dsda-doom's header; [button_layout()] lists
#' them with IDs of their own (`action:attack`, `action:use`, `action:jump`).
#' [analog_channels()] returns signed `forwardmove`, `sidemove` and
#' `angleturn`: how fast the player asked to move forward and sideways, and
#' how far to turn in that tic, in 1/256 of a revolution. Demos with 16-bit
#' turning keep the finer steps as fractions of that unit. Heretic and Hexen
#' add `look` and `fly`, from -7 to 7; -8 asks to centre the view or to stop
#' flying. All of these are commands assembled from the input devices, so
#' stick options leave them unchanged.
#'
#' Weapon selection and special-command flags remain in `header$weaponselect`
#' and `header$has_special`; `commands` retains the special-command bytes.
#' Artifact commands of Heretic and Hexen are in `header$artifact`, Hexen's
#' player classes in `header$playerClass`, and dsda-doom's extended commands
#' in `header$extendedCommands`. Game options remain in `header$gameOptions`.
#'
#' Demos of Doom 1.2 and earlier, of Heretic and of Hexen begin with the
#' skill level and do not name their game, and the three layouts differ, so
#' `game` is required for them. Heretic and Hexen demos can store 16-bit
#' turning; later ports mark this in the header, Heretic+ and Hexen+ do not,
#' and `longtics = TRUE` reads such a demo. A demo that fits the file only
#' when read that way is refused with a message that says so.
#'
#' `source_header` and `source_packets` preserve the recorded bytes, and
#' `source_tail` preserves bytes after the demo-end marker:
#' `c(source_header, t(source_packets), as.raw(0x80), source_tail)` is the
#' file.
#' @param game `"doom"`, `"heretic"` or `"hexen"`. Required for a demo without
#'   a version byte; every other demo identifies its own layout.
#' @param longtics For Heretic and Hexen demos: `TRUE` if turning was
#'   recorded with 16 bits and the header does not say so, `FALSE` to rule
#'   that out, `NULL` (default) to follow the header.
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and source metadata.
#' @export
#' @examples
#' demo <- read_lmp(system.file("extdata", "sample.lmp", package = "replayr"))
#' button_layout(demo)
#' head(analog_channels(demo))
read_lmp <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, game = NULL,
                     longtics = NULL, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(
    .decode_lmp(path, game = game, longtics = longtics, ...),
    analog, deadzone, triggers, aliases
  )
}
#' Read a Famtasia recording
#'
#' Imports NES and Famicom Disk System input, with one row per recorded
#' frame and one player for each enabled controller port. [player()] returns
#' the pad buttons, and [button_layout()] identifies their columns.
#'
#' The `commands` component retains the Famicom Disk System command byte when
#' present. `source_packets` retains every complete packet. An incomplete final
#' packet produces a warning and remains available in `source_tail`.
#' The header preserves enabled ports, rerecord count, and movie metadata.
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and source metadata.
#' @export
#' @examples
#' movie <- read_fmv(system.file("extdata", "legacy", "buttons.fmv", package = "replayr"))
#' movie
#' press_counts(movie)
read_fmv <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_fmv(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a Dega recording
#'
#' Imports Master System and Game Gear input, including older MMV headers.
#' Each row represents one complete stored frame. Master System recordings
#' have two controller ports; Game Gear recordings have one player.
#' Buttons 1 and 2 have the IDs of A and B and keep their labels in
#' [button_layout()]. The Game Gear's Start is a button of the handheld. The
#' Master System's Pause sits on the console and is returned by
#' [system_channels()].
#'
#' The header includes `declaredFrameCount`, `availableFrameCount`,
#' `frameCountDifference`, `frameCount`, and region flags. Following Dega's
#' playback rule, all complete packets through the end of the file are imported.
#' `source_packets` retains packet bytes, including padding. An incomplete
#' final packet produces a warning and remains in `source_tail`.
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and source metadata.
#' @export
#' @examples
#' movie <- read_mmv(system.file("extdata", "legacy", "sms.mmv", package = "replayr"))
#' # Buttons 1 and 2 are A and B; Pause is a button of the console.
#' button_layout(movie)[, c("key", "name")]
#' system_channels(movie)
read_mmv <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_mmv(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a DeSmuME recording
#'
#' Imports Nintendo DS DSM versions 1 and 2 in text or binary form, with one
#' row per recorded frame. [player()] includes the pad buttons, touch state,
#' microphone activation, and lid state. [button_layout()] identifies the fields.
#'
#' [analog_channels()] returns `touch_x`, `touch_y`, and `touch_pressed`.
#' Touch coordinates use the screen's top-left origin, with a nominal extent
#' of 256 by 192. Text recordings with a fourth numeric field also provide
#' `microphone_sample`; absent samples are `NA`. The binary layout stores three
#' touch fields. Stick options leave these
#' source channels unchanged.
#'
#' The `commands` component retains the original byte: microphone activation
#' uses bit 0, reset uses bit 1, and lid state uses bit 2. Text records may be
#' adjacent or separated by whitespace.
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and source metadata.
#' @export
#' @examples
#' movie <- read_dsm(system.file("extdata", "legacy", "touch-v2.dsm", package = "replayr"))
#' movie
#' analog_channels(movie)
read_dsm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_dsm(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a PCEjin or VBjin recording
#'
#' Imports version-1 text and binary recordings from PCEjin and VBjin, with
#' one row per recorded frame. PC Engine recordings support up to five
#' controller ports; buttons I and II have the IDs of A and B, and Run that
#' of Start. VBjin recordings include both Virtual Boy direction pads: the
#' left one has the IDs of the direction pad and the right one those of the
#' N64's C-buttons.
#'
#' [player()] returns the buttons for a selected port. The original command
#' byte is retained in `commands`. Header fields identify the emulator and,
#' when recorded, PC Engine CD mode. Incomplete binary packets and inconsistent
#' controller fields produce an error.
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and source metadata.
#' @export
#' @examples
#' movie <- read_mc2(system.file("extdata", "legacy", "vboy.mc2", package = "replayr"))
#' # The Virtual Boy has two direction pads.
#' button_layout(movie)[, c("key", "name")]
read_mc2 <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_mc2(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a Yabause rerecording movie
#'
#' Imports enhanced YMV version-1 text and binary recordings for one Saturn
#' gamepad. Each row represents a recorded frame. The thirteen digital fields
#' include four directions, Start, six face buttons, and two shoulder buttons.
#'
#' [player()] returns button states, [button_layout()] identifies the controls,
#' and `commands` retains the source command byte. Earlier YMV layouts that
#' precede this version-1 format are unsupported.
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and source metadata.
#' @export
#' @examples
#' movie <- read_ymv(system.file("extdata", "legacy", "saturn.ymv", package = "replayr"))
#' movie
#' recording_info(movie)
read_ymv <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_ymv(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a Mednafen rerecording movie
#'
#' Imports MCM version 1 with fixed gamepad layouts for PC Engine, PC-FX,
#' Atari Lynx, WonderSwan, Neo Geo Pocket, NES, and Master System. Each row
#' represents one stored frame, with separate players for the format's
#' controller ports. Numbered buttons have the lettered IDs in order: PC
#' Engine and PC-FX I to VI are A, B, X, Y, L1 and R1, and Master System
#' Fire 1 and 2 are A and B; [button_layout()] keeps their labels. Run, the
#' Lynx's Pause and the Neo Geo Pocket's Option are Start; the Lynx's Option
#' 1 and 2 are Select and Mode; PC Engine's switch between two and six
#' buttons is Mode. The WonderSwan's X cross is the direction pad and its Y
#' cross has the IDs of the N64's C-buttons. The Master System's Pause sits
#' on the console and is returned by [system_channels()].
#'
#' [player()] returns the digital input. `commands` retains the command byte,
#' and `source_packets` retains complete packets. An incomplete final packet
#' produces a warning and remains in `source_tail`. The ROM checksum bytes are
#' preserved in `header$romMD5Bytes`. Peripheral layouts beyond these fixed
#' gamepads require a separate decoder.
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and source metadata.
#' @export
#' @examples
#' movie <- read_mcm(system.file("extdata", "legacy", "pce.mcm", package = "replayr"))
#' n_players(movie)
#' # The numbered buttons of the PC Engine take the lettered identities in order.
#' button_layout(movie)[, c("key", "name")]
read_mcm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_mcm(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a libTAS recording
#'
#' Reads native LTM archives containing `config.ini` and `inputs`. Supports
#' the positional input format through libTAS 1.3.5 and the later tagged
#' format, including ordered input events and up to four controllers.
#'
#' Each row is a recorded frame. `movie$timing` contains `framerate_num`,
#' `framerate_den`, `duration_seconds`, `realtime_sec`, and `realtime_nsec`.
#' Frame durations follow the recorded rate changes. `movie$input_events`
#' retains each frame's ordered events, and `movie$flags` retains emulator flags.
#'
#' `source_input_log` retains the original input lines and their row index.
#' Keyboard keys use their hexadecimal X KeySym in [button_layout()], such as
#' `keysym_ff53` for Right. Keyboard and mouse inputs occupy player 1 alongside
#' controller 1. Controller buttons retain gamepad identities, including L3
#' and R3. [analog_channels()] includes `left_x`, `left_y`, `right_x`,
#' `right_y`, `left_trigger`, and `right_trigger` as signed 16-bit source values.
#' Both sticks support the representations selected by `analog`.
#' Mouse channels are `mouse_x`, `mouse_y`, `mouse_wheel`, and `mouse_mode`;
#' mode 0 denotes absolute coordinates and mode 1 denotes relative movement.
#' The complete configuration remains in `movie$header$configuration`.
#' @inheritParams read_movie
#' @return A [replayr_movie] with frame timing, source inputs, and metadata.
#' @export
#' @examples
#' movie <- read_ltm(system.file("extdata", "computers", "dual-stick-menu.ltm", package = "replayr"))
#' movie
#' channel_layout(movie)
#' # Every frame has its own length.
#' observation_time(movie)
read_ltm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_ltm(path, ...), analog, deadzone, triggers, aliases)
}
#' Read an Hourglass recording
#'
#' Reads WTF files with the `66 54 77 02` signature and the equivalent HGM
#' extension. Each frame stores up to eight Windows virtual-key codes;
#' the first zero ends its list of held keys.
#'
#' Each row is a recorded frame. `movie$header$fps` contains the recorded
#' nominal frame rate; `initial_time` and `clock_checks` retain the emulator's
#' clock metadata. The header also includes the keyboard layout, executable
#' name, and Hourglass revision.
#'
#' [button_layout()] identifies keys by their hexadecimal virtual-key code:
#' for example, `windows_vk_25` is Left and `windows_vk_41` is A.
#' `movie$source_keycodes` retains all eight source bytes for every frame,
#' and `movie$source_header` retains the original 1024-byte header.
#' @inheritParams read_movie
#' @return A [replayr_movie] with keyboard states and source metadata.
#' @export
#' @examples
#' movie <- read_wtf(system.file("extdata", "computers", "keyboard-jump.wtf", package = "replayr"))
#' # Keyboard keys keep the codes of the recording.
#' button_layout(movie)[, c("id", "name")]
#' as.data.frame(movie)
read_wtf <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_wtf(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a JPC-RR recording
#'
#' Reads JRSR text archives containing an `events` section. Keyboard edges,
#' mouse buttons and movement, joystick events, and reset commands are decoded.
#' Other emulator events remain in `movie$events` with their arguments and
#' original source lines. Initialisation sections remain in
#' `movie$header$initialization` and `movie$event_sections`.
#'
#' Each row follows one timestamped event. `movie$events$timestamp_ns` gives
#' absolute time in nanoseconds after applying recorded `RELATIVE` and
#' `ABSOLUTE` options. `timestamp_source` retains the source timestamp text.
#' Keyboard and button states persist until the next relevant event;
#' mouse movement channels record the displacement at that event.
#'
#' Keyboard identities use `jpcrr_key_<number>`, preserving JPC-RR's key-code
#' namespace. The Pause event appears as a `jpcrr_pause` pulse. Keyboard and
#' mouse inputs occupy player 1. [analog_channels()] exposes `mouse_dx`,
#' `mouse_dy`, and `mouse_wheel`, and the joystick channels
#' `joystick_x_hold_ns` and `joystick_y_hold_ns`. Joystick values are recorded
#' game-port hold times in nanoseconds and remain `NA` before their first update.
#' @inheritParams read_movie
#' @return A [replayr_movie] with event times, reconstructed states, and source events.
#' @export
#' @examples
#' movie <- read_jrsr(system.file("extdata", "computers", "keyboard-mouse.jrsr", package = "replayr"))
#' observation_unit(movie)
#' observation_time(movie)
#' analog_channels(movie)[1:4, ]
read_jrsr <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_jrsr(path, ...), analog, deadzone, triggers, aliases)
}
#' Read an openMSX replay
#'
#' Reads gzip-compressed openMSX XML replay files. Supported event schemas
#' cover keyboard matrices, joysticks, mice, trackballs, paddles, touchpads,
#' light guns, and autofire settings. The initial keyboard state is read from
#' the first replay snapshot. Every device is one controller: the keyboard
#' first, then the devices on the joystick ports by name, as listed in
#' `movie$header$controllers`. Their controls have the same IDs as in every
#' other reader: a joystick is the direction pad with A and B, the buttons of
#' a mouse or trackball are A and B, the JoyMega pad adds C, Start, X, Y, Z
#' and Mode, a light-gun trigger and a paddle's button are A, and a touch on
#' the touchpad is L3. `openmsx_key_r8_b0` identifies a keyboard matrix row
#' and bit. All devices share one event stream, so each controller has a row
#' for every event.
#'
#' Each row follows one replay event. `movie$events$timestamp_ticks` retains
#' time in openMSX master-clock ticks (3,579,545 * 960 ticks per second), and
#' `timestamp_seconds` expresses the same event times in seconds.
#' `timestamp_source`, `event_type`, `source_device`, and `source_xml` retain
#' the event's original time, type, device, and XML.
#'
#' [analog_channels()] preserves the values of each device on its controller.
#' Examples include `mouse_dx` and `mouse_dy` for movement and
#' `touch_x` and `touch_y` for touch coordinates. A
#' recorded autofire setting, such as `openmsx_autofire_renshaturbo`, belongs
#' to the machine and is returned by [system_channels()].
#' Movement deltas apply to their event; coordinates and settings persist
#' until updated. The replay schema version and machine name remain in
#' `movie$header$replay_version` and `movie$header$machine`.
#' @inheritParams read_movie
#' @return A [replayr_movie] with event times, device controls, and source XML.
#' @export
#' @examples
#' movie <- read_omr(system.file("extdata", "computers", "keyboard-joystick.omr", package = "replayr"))
#' # Every device is a controller.
#' movie$header$controllers
#' observation_time(movie)
read_omr <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_omr(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a BKM recording
#'
#' Legacy BizHawk text recordings.
#' Digital controls have compact columns with stable identities. Numeric source
#' fields remain available through [analog_channels()].
#' @inheritParams read_movie
#' @return An imported recording with header metadata and original input fields.
#' @export
#' @examples
#' movie <- read_bkm(system.file("extdata", "expanded", "legacy-n64.bkm", package = "replayr"))
#' movie
#' analog_channels(movie)
read_bkm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_bkm(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a GBMV recording
#'
#' GBAHawk ZIP recordings.
#' Digital controls have compact columns with stable identities. Numeric source
#' fields remain available through [analog_channels()].
#' @inheritParams read_movie
#' @return An imported recording with header metadata and original input fields.
#' @export
#' @examples
#' movie <- read_gbmv(system.file("extdata", "expanded", "gba-input.gbmv", package = "replayr"))
#' movie
#' as.data.frame(movie)
read_gbmv <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_gbmv(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a FM3 recording
#'
#' FCEUX TAS Editor projects, with the movie length separating input records from editor data.
#' @inheritParams read_movie
#' @return An imported recording containing original input fields and metadata.
#' @export
#' @examples
#' movie <- read_fm3(system.file("extdata", "expanded", "movement-jumps.fm3", package = "replayr"))
#' summary(movie)
read_fm3 <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_fm3(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a TAS recording
#'
#' Early BizHawk text recordings.
#' @inheritParams read_movie
#' @return An imported recording containing original input fields and metadata.
#' @export
#' @examples
#' movie <- read_tas(system.file("extdata", "expanded", "legacy-sms.tas", package = "replayr"))
#' movie
#' system_channels(movie)
read_tas <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_tas(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a TASPROJ recording
#'
#' BizHawk TAS Studio projects.
#' @inheritParams read_movie
#' @return An imported recording containing original input fields and metadata.
#' @export
#' @examples
#' path <- system.file("extdata", "expanded", "editor-input.tasproj",
#'   package = "replayr")
#' movie <- read_tasproj(path)
#' movie
#' as.data.frame(movie)
read_tasproj <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_tasproj(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a Citra device-poll recording
#'
#' Imports Nintendo 3DS CTM recordings as ordered device polls. Pad and Circle
#' Pad, touch, accelerometer, gyroscope, IR C-stick, and extra-HID polls each
#' occupy their own rows. [polls()] exposes `event_type` and flags identifying
#' the observed device. `observed_inputs` marks the digital controls measured
#' at each poll; numeric fields for other devices are `NA`.
#'
#' [analog_channels()] retains the source coordinates, motion values, and
#' battery level. The Circle Pad and C-stick support the four stick modes
#' through `analog`, using their source-specific centres and scales.
#' `poll_bytes` retains the seven-byte records. Timing follows device-poll
#' order; CTM provides no video-frame assignment for these rows.
#' @inheritParams read_movie
#' @return A [replayr_poll_stream] containing ordered device polls and metadata.
#' @export
#' @examples
#' stream <- read_ctm(system.file("extdata", "legacy", "devices.ctm", package = "replayr"))
#' # Each row is the poll of one device: pad, touch screen or a sensor.
#' class(stream)
#' observation_unit(stream)
#' channel_layout(stream)$key
read_ctm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_ctm(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a CoffeeTools recording
#'
#' Reads CTAS versions 3 and 4 of CoffeeTools, a recording tool for the game
#' *UFO 50*. Each row contains one frame's
#' input for both players: four directions, `ufo50_fire1`, `ufo50_fire2`,
#' and Start. The Start column records a press event; the other six columns
#' record held states.
#'
#' `movie$pressed` and `movie$released` retain the six controls' separate
#' press and release flags as frame-by-player-by-control logical arrays.
#' For example, `movie$pressed[, 1, "ufo50_fire1"]` selects player 1's first
#' action-button press events. These flags are read from the file alongside
#' held states, allowing a game's press and hold behaviour to be compared.
#'
#' `movie$randomization` contains the recorded `input_frame` and `seed`
#' pairs in source units. `movie$source_words` retains both players' input
#' words, and `movie$source_header` retains the original header. Version 4
#' adds `rerecord_count` and `current_time` to `movie$header`; those fields
#' are `NA` for version 3. Rows use the file's frame index; randomisation
#' frame numbers are retained exactly as stored.
#' @inheritParams read_movie
#' @return A [replayr_movie] with held states, press/release flags, and randomisation data.
#' @export
#' @examples
#' path <- system.file("extdata", "computers", "two-player-actions.ctas",
#'   package = "replayr")
#' movie <- read_ctas(path)
#' movie
#' as.data.frame(movie, idx = 2L)
read_ctas <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_ctas(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a gz input macro
#'
#' Imports the macros of gz, a practice version of the Nintendo 64 game
#' *The Legend of Zelda: Ocarina of Time*, with one row per recorded game
#' update.
#' [player()] returns the N64 buttons. [analog_channels()] retains signed
#' `left_x` and `left_y`; `analog` selects a derived stick representation.
#'
#' `frame_fields` retains pad deltas and press/release masks. `system_events`
#' retains random-seed changes and any ocarina-input, audio-synchronisation,
#' or room-load records. The `commands` component marks reset events, and
#' `source_packets` retains the six-byte input records. Game updates provide
#' the observation order; elapsed time requires the game's update timing.
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and source metadata.
#' @export
#' @examples
#' movie <- read_gzm(system.file("extdata", "legacy", "buttons.gzm", package = "replayr"))
#' observation_unit(movie)
#' head(analog_channels(movie), 3)
read_gzm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_gzm(path, ...), analog, deadzone, triggers, aliases)
}
#' Read an enhanced ZSNES recording
#'
#' Imports enhanced ZMV recordings for up to five SNES gamepads. Repeat
#' records are expanded into frame rows. [player()] returns a selected pad,
#' and [button_layout()] identifies its twelve buttons.
#'
#' Reset commands are attached to the following frame. Chapter offsets and
#' counts remain in `chapter_offsets` and the header. A header frame-count
#' mismatch produces a warning, with complete stored frames retained. The
#' header also preserves the PAL flag and any reset after the last frame.
#' Mouse and Super Scope layouts require separate peripheral decoding.
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and source metadata.
#' @export
#' @examples
#' movie <- read_zmv(system.file("extdata", "legacy", "holds.zmv", package = "replayr"))
#' movie
#' as.data.frame(movie)
read_zmv <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_zmv(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a MAME recording
#'
#' Reads MAME-RR input-port records. Known games use the bundled port layouts;
#' other games require an explicit input schema. Original port words, timestamps,
#' and analogue accumulator fields remain available in `system_channels`.
#' @inheritParams read_movie
#' @param input_schema A game-specific port schema; see the bundled
#'   `extdata/mar-layouts.json` for the schema structure.
#' @return An imported recording with source port values and metadata.
#' @export
#' @examples
#' path <- system.file("extdata", "expanded", "arcade-dual-joysticks.mar",
#'   package = "replayr")
#' movie <- read_mar(path)
#' # The two joysticks of a cabinet are the left and the right stick.
#' button_layout(movie)[, c("key", "name")]
#' names(system_channels(movie))
read_mar <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE,
                     input_schema = NULL, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_mar(path, input_schema = input_schema, ...), analog, deadzone, triggers, aliases)
}
#' Read a FinalBurn Alpha recording
#'
#' Imports FinalBurn Alpha FBM input streams using an explicit game input
#' layout. FBM stores values in driver order, so the recording must be paired
#' with a verified ROM identifier or an ordered schema. Bundled game layouts
#' cite their driver sources in `extdata/fbm-layouts.json`.
#'
#' [player()] returns game controls, [analog_channels()] retains numeric
#' player inputs, and [system_channels()] returns cabinet and system inputs.
#' It also retains every raw field under `raw_pN_key` or `raw_system_key`,
#' including source bytes whose button interpretation uses only bit zero.
#' Rows follow the stored frame order. The header retains the frame count,
#' rerecord count, source flags, and input-schema reference, and in
#' `metadata` the text that the author of the recording entered when
#' recording, where the file has one (usually the author's name or a
#' comment).
#' @inheritParams read_movie
#' @param game A verified ROM identifier matching a bundled input layout,
#'   such as `"ghouls"`. Supply either `game` or `input_schema`.
#' @param input_schema An ordered schema with a `source` reference and a
#'   `fields` list. Each field gives `key`, `player` (zero for system inputs),
#'   `type` (`"button"`, `"byte"`, or `"analog"`), and an optional display
#'   `name`. Optional `button_encoding` is `"binary"` (default), `"bit0"`,
#'   or `"nonzero"`, according to the driver's interpretation of the byte.
#'   Field order must match the emulator driver exactly.
#' @return A [replayr_movie] with compact controls and the input schema.
#' @export
#' @examples
#' path <- system.file("extdata", "expanded", "synthetic-arcade.fbm",
#'                     package = "replayr")
#' movie <- read_fbm(path, game = "ghouls")
#' press_counts(movie)
read_fbm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE,
                     game = NULL, input_schema = NULL, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(
    .decode_fbm(path, game = game, input_schema = input_schema, ...),
    analog, deadzone, triggers, aliases
  )
}
#' Read a GoldSrc demo
#'
#' Reads the demos of the Half-Life engine (GoldSrc): *Half-Life*,
#' *Counter-Strike* 1.x and the other games built on it, demo protocol 5,
#' from the engine versions of 2001 (network protocols 42 and 43) to the current
#' one (48). A
#' demo stores, with every network message the client received, the command
#' the client was sending at that moment. Each such frame is one observation.
#'
#' [player()] returns the 16 actions of the command. They are what the game
#' was asked to do, not keys: which key or mouse button is bound to an action
#' is a setting of the player. The actions have `action:` identities of their
#' own, shared with other games that record the same action; attack, use and
#' jump are those of Doom-engine demos.
#'
#' [analog_channels()] returns the movement the command asks for
#' (`forwardmove`, `sidemove`, `upmove`), the view angles it asks for in
#' degrees (`view_pitch`, `view_yaw`, `view_roll`), the impulse number, the
#' selected weapon and the duration of the command in milliseconds (`msec`).
#' The view angles are the player's aim as the client sends it: their change
#' from one observation to the next is the turning asked for with the mouse
#' or the turn keys. The game can also set them, for example when the player
#' respawns.
#'
#' `movie$timing` gives for each observation its section, the seconds and
#' the frame number the demo stores (both count anew in every section), and
#' whether it is a start frame of the loading section. Two network messages
#' can arrive in one frame; they are two observations with one frame number.
#' [observation_time()] runs on from section to section. `movie$sections`
#' lists the sections of the demo, and `movie$console_commands` the console
#' commands it recorded, among them the key actions (`+jump`, `-jump`).
#'
#' A demo recorded by a broadcast proxy (HLTV) holds no commands of a
#' player: every command in it is empty. The reader says so in a warning and
#' in `movie$header$playerCommands`. A demo that was not closed or was cut
#' short is read up to its last complete frame, with a warning. Demos of demo
#' protocol 4, which the engines of early 2001 wrote, store no command with
#' their frames and are refused. Quake and Source engine demos share the
#' extension `.dem` and are other formats.
#' @inheritParams read_movie
#' @return A [replayr_movie] with one player.
#' @export
#' @examples
#' path <- system.file("extdata", "computers", "goldsrc-moves.dem", package = "replayr")
#' movie <- read_dem(path)
#' colSums(player(movie))
#' head(analog_channels(movie)[, c("forwardmove", "view_yaw")])
read_dem <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_dem(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a table of the Atari Grand Challenge data set or of Atari-HEAD
#'
#' Two published data sets of human play on the Atari 2600 give the input as
#' text tables with one row for each frame, in `.txt` files. The reader knows
#' by the first line which of the two a file is:
#'
#' * A trajectory of the Atari Grand Challenge data set, version 1 (Kurin et
#'   al. 2017, \doi{10.48550/arXiv.1705.10998}): one episode of play, recorded
#'   at 60 frames per second. The data set keeps the trajectories of each
#'   game in a folder of its own (`spaceinvaders`, `qbert`, `mspacman`,
#'   `pinball`, `revenge`); the file does not name its game.
#' * A trial of Atari-HEAD (Zhang et al. 2020,
#'   \doi{10.1609/aaai.v34i04.6161}; files at \doi{10.5281/zenodo.3451402}).
#'   The game waited for the player in every frame, and the table stores how
#'   long each frame was shown. The archive of each game holds the text files
#'   of its trials beside the archives of their screen images, and a trial
#'   can be read out of it: `read_movie("breakout.zip", member = ...)`, with
#'   the members that [movie_members()] lists. The file `meta_data.csv` of
#'   the data set names the game of each trial.
#'
#' Each row holds the action of its frame as one of the 18 action numbers of
#' the Arcade Learning Environment. These are the states of one joystick, so
#' [player()] returns its five controls: the four directions and the fire
#' button, under the IDs an Atari 2600 joystick has in every other
#' recording.
#'
#' [analog_channels()] returns the action number as the table writes it
#' (`action`) and, for a trial, how long each frame was shown
#' (`duration_ms`, the column `duration(ms)`). A field that the table gives
#' as `null` is `NA`; the last row of a trial has no action, so that no
#' control is held in it. [observation_time()] of a trial is the time at
#' which each frame appeared, the sum of the durations of the frames before
#' it. `movie$timing` holds the frame numbers of a trajectory (`frame`) or
#' the frame identifiers of a trial (`frame_id`), and
#' `movie$header$trajectoryId` the number in the first line of a
#' trajectory.
#'
#' Only the input is read. The tables also give states of the game (the
#' score, the reward of each frame, the episode and whether it ended) and,
#' for a trial, the gaze positions of each frame: the points on the screen
#' at which the player was looking, measured by an eye tracker. These are
#' not returned; `read.csv()` reads them from the same files.
#'
#' `recording_info(movie)$format` says which table was read: `"atari_gc"` or
#' `"atari_head"`. A text file that is neither is refused.
#' @inheritParams read_movie
#' @return A [replayr_movie] with one player.
#' @seealso [recording_format()] to tell the tables from other text files.
#' @export
#' @examples
#' trajectory <- system.file("extdata", "tables", "atari-grand-challenge.txt", package = "replayr")
#' movie <- read_txt(trajectory)
#' colSums(player(movie))
#' head(analog_channels(movie))
#' trial <- read_txt(system.file("extdata", "tables", "atari-head.txt", package = "replayr"))
#' recording_info(trial)$format
#' observation_time(trial)
read_txt <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_txt(path, ...), analog, deadzone, triggers, aliases)
}
#' Read a Dustmod input script archive
#'
#' Imports the DFT archives of Dustmod, a modified version of the game
#' *Dustforce DX*, by following their entry script and INCLUDE commands.
#' Each row represents one scripted input frame. Directional double taps are
#' preserved in `double_tapped`; `source_digits` and `source_values` retain
#' the original 0, 1, and 2 encoding. Optional taunt and restart columns are
#' retained when present.
#'
#' `source_locations` identifies the archive member and line for each row.
#' `source_commands` preserves loading, synchronisation, mouse, statistics,
#' and include commands in script order. MOUSE coordinates and button states
#' apply to the next scripted row, with observation masks identifying those
#' rows. SYNCLOAD can add runtime waiting whose duration requires execution
#' in the game; the imported rows retain script order.
#' @inheritParams read_movie
#' @param entry Entry script member. `NULL` selects the archive's unique
#'   `main.txt`; an explicit member resolves archives with several candidates.
#' @return A [replayr_movie] with source scripts, commands, and locations.
#' @export
#' @examples
#' movie <- read_dft(system.file("extdata", "computers", "menu-double-tap.dft", package = "replayr"))
#' # Jump, dash and the attacks are actions of the game, not buttons.
#' button_layout(movie)[, c("id", "key", "kind")]
#' head(analog_channels(movie), 3)
read_dft <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE,
                     entry = NULL, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  .configure_movie(.decode_dft(path, entry = entry, ...), analog, deadzone, triggers, aliases)
}
