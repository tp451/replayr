# Public readers separate decoding from layout configuration. Decoders retain
# source values and controller identities; .configure_movie() assigns compact
# columns, shared IDs, and the requested analogue representation.
#' Read a FM2 recording
#'
#' FCEUX text movies; NES and Famicom button states.
#' Digital columns are compact; [button_layout()] gives their stable IDs.
#' Numeric source channels are always retained in [analog_channels()].
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and selected stick fields.
#' @export
read_fm2 <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_fm2(path, ...), analog, deadzone, triggers)
}
#' Read a BK2 recording
#'
#' BizHawk ZIP movies. LogKey names determine digital controls and numeric channels. Known N64 and PlayStation stick encodings can be transformed; other numeric channels remain raw.
#' Digital columns are compact; [button_layout()] gives their stable IDs.
#' Numeric source channels are always retained in [analog_channels()].
#' The full import defaults to a 256 MiB limit on the expanded input log to
#' avoid large temporary allocations. [read_bk2_chunks()] processes larger
#' recordings in bounded memory. The final movie and parsing buffers can use
#' substantially more memory than the text itself.
#' @inheritParams read_movie
#' @param max_input_bytes Maximum expanded input-log size for a full import,
#'   in bytes. The default is `256 * 1024^2`. Increase this explicitly when
#'   sufficient memory is available, up to R's single-string limit of
#'   `2147483647` bytes. The limit is checked before extracting the input log.
#' @return A [replayr_movie] with compact digital columns and selected stick fields.
#' @export
read_bk2 <- function(path, analog = "raw", deadzone = NULL, triggers = "raw",
                     max_input_bytes = 256 * 1024^2, ...) {
  .stick_modes(analog)
  .configure_movie(.decode_bk2(path, analog = "raw", max_input_bytes = max_input_bytes, ...), analog, deadzone, triggers)
}
#' Read a FCM recording
#'
#' FCEU binary NES movies, including supported delta-stream versions.
#' Digital columns are compact; [button_layout()] gives their stable IDs.
#' Numeric source channels are always retained in [analog_channels()].
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and selected stick fields.
#' @export
read_fcm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_fcm(path, ...), analog, deadzone, triggers)
}
#' Read an lsnes LSMV recording
#'
#' Reads ZIP input logs with `controlsversion` 0: Game Boy/Game Boy Color pads,
#' SNES 12- and 16-button pads, multitaps, Y-cabled pads, and a declared
#' Super Scope on port 2. Super Game Boy movies retain their SNES controller
#' layout. The four extra pad controls have keys `lsnes_ext0` to `lsnes_ext3`.
#'
#' Every non-empty input row is retained, including subframes between frame
#' starts. [n_frames()] counts these observations; `header$frameCount` counts
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
#' [analog_channels()] returns its signed source `gun_x` and `gun_y` coordinates. [button_layout()] gives
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
read_lsmv <- function(path, analog = "raw", deadzone = NULL, triggers = "raw",
                      max_input_bytes = 256 * 1024^2, ...) {
  .stick_modes(analog)
  .configure_movie(.decode_lsmv(path, max_input_bytes = max_input_bytes, ...), analog, deadzone, triggers)
}
#' Read a GMV recording
#'
#' Gens recordings with three- or six-button controllers. Controller capability comes from the header, with older unspecified types retained explicitly.
#' Digital columns are compact; [button_layout()] gives their stable IDs.
#' Numeric source channels are always retained in [analog_channels()].
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and selected stick fields.
#' @export
read_gmv <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_gmv(path, ...), analog, deadzone, triggers)
}
#' Read a VBM recording
#'
#' VBA recordings for Game Boy, Game Boy Color and Game Boy Advance.
#' Digital columns are compact; [button_layout()] gives their stable IDs.
#' Numeric source channels are always retained in [analog_channels()].
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and selected stick fields.
#' @export
read_vbm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_vbm(path, ...), analog, deadzone, triggers)
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
read_m64 <- function(path, analog = "raw", deadzone = NULL, triggers = "raw",
                     controller_order = NULL, ...) {
  .stick_modes(analog)
  .configure_movie(
    .decode_m64(path, analog = "raw", controller_order = controller_order, ...),
    analog, deadzone, triggers
  )
}
#' Read a SMV recording
#'
#' Supported Snes9x versions and joypad controllers.
#' Digital columns are compact; [button_layout()] gives their stable IDs.
#' Numeric source channels are always retained in [analog_channels()].
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and selected stick fields.
#' @export
read_smv <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_smv(path, ...), analog, deadzone, triggers)
}
#' Read a PXM recording
#'
#' PCSX standard digital and analogue-controller records. Unsupported devices are rejected; reserved standard-pad bits do not become stick clicks.
#' Digital columns are compact; [button_layout()] gives their stable IDs.
#' Numeric source channels are always retained in [analog_channels()].
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and selected stick fields.
#' @export
read_pxm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_pxm(path, analog = "raw", ...), analog, deadzone, triggers)
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
#' Numeric source channels are always retained in [analog_channels()].
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and selected stick fields.
#' @export
read_pjm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_pjm(path, analog = "raw", ...), analog, deadzone, triggers)
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
#' do not store an extension identity or encryption key. New serialized Dolphin
#' states include their extension type; Nunchuk and Classic Controller states
#' are decoded automatically. Other extension payloads remain source bytes.
#' Each row is a poll. `poll_lengths` gives valid bytes in the padded
#' `poll_bytes` matrix; historical eight-byte prefixes remain in `poll_prefix_bytes`.
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
read_dtm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", controller_order = NULL, dtm_variant = "auto", wii_variant = "auto", wii_extension = "raw", wii_key = NULL, ...) {
  .stick_modes(analog)
  .configure_movie(.decode_dtm(path, controller_order = controller_order, analog = "raw", dtm_variant = dtm_variant, wii_variant = wii_variant, wii_extension = wii_extension, wii_key = wii_key, ...), analog, deadzone, triggers)
}
#' Read a Doom or Boom demo
#'
#' Imports vanilla Doom 1.9 demos (version 109) and Boom 2.00-2.02 demos
#' (versions 200-202). Each row represents a game tic at 35 tics per second.
#' `header$enabledPorts` identifies the players whose commands were stored.
#'
#' [player()] exposes Use and Attack. [analog_channels()] returns signed
#' `forwardmove`, `sidemove`, and `angleturn`; the turning unit is 1/256 of a
#' revolution per tic. These are game commands assembled from the input
#' devices, so stick options leave them unchanged. Weapon selection and
#' special-command flags remain in `header$weaponselect` and
#' `header$has_special`; `commands` retains the special-command bytes.
#'
#' Boom options remain in `header$gameOptions`. `source_header` and
#' `source_packets` preserve the recorded bytes, and `source_tail` preserves
#' bytes after the demo-end marker. Later extended and longtics layouts are
#' outside the supported versions.
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and source metadata.
#' @export
read_lmp <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_lmp(path, analog = "raw", ...), analog, deadzone, triggers)
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
read_fmv <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_fmv(path, ...), analog, deadzone, triggers)
}
#' Read a Dega recording
#'
#' Imports Master System and Game Gear input, including older MMV headers.
#' Each row represents one complete stored frame. Master System recordings
#' have two controller ports; Game Gear recordings have one player.
#' [button_layout()] retains the source labels 1, 2, and Pause or Start.
#'
#' The header includes `declaredFrameCount`, `availableFrameCount`,
#' `frameCountDifference`, `frameCount`, and region flags. Following Dega's
#' playback rule, all complete packets through the end of the file are imported.
#' `source_packets` retains packet bytes, including padding. An incomplete
#' final packet produces a warning and remains in `source_tail`.
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and source metadata.
#' @export
read_mmv <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_mmv(path, ...), analog, deadzone, triggers)
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
read_dsm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_dsm(path, ...), analog, deadzone, triggers)
}
#' Read a PCEjin or VBjin recording
#'
#' Imports version-1 text and binary recordings from PCEjin and VBjin, with
#' one row per recorded frame. PC Engine recordings support up to five
#' controller ports. VBjin recordings include both Virtual Boy directional
#' pads; the second pad uses the `vboy_right_*` keys in [button_layout()].
#'
#' [player()] returns the buttons for a selected port. The original command
#' byte is retained in `commands`. Header fields identify the emulator and,
#' when recorded, PC Engine CD mode. Incomplete binary packets and inconsistent
#' controller fields produce an error.
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and source metadata.
#' @export
read_mc2 <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_mc2(path, ...), analog, deadzone, triggers)
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
read_ymv <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_ymv(path, ...), analog, deadzone, triggers)
}
#' Read a Mednafen rerecording movie
#'
#' Imports MCM version 1 with fixed gamepad layouts for PC Engine, PC-FX,
#' Atari Lynx, WonderSwan, Neo Geo Pocket, NES, and Master System. Each row
#' represents one stored frame, with separate players for the format's
#' controller ports. PC Engine six-button controls and platform-specific
#' buttons keep their own keys in [button_layout()].
#'
#' [player()] returns the digital input. `commands` retains the command byte,
#' and `source_packets` retains complete packets. An incomplete final packet
#' produces a warning and remains in `source_tail`. The ROM checksum bytes are
#' preserved in `header$romMD5Bytes`. Peripheral layouts beyond these fixed
#' gamepads require a separate decoder.
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and source metadata.
#' @export
read_mcm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_mcm(path, ...), analog, deadzone, triggers)
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
#' `right_y`, `trigger_left`, and `trigger_right` as signed 16-bit source values.
#' Both sticks support the representations selected by `analog`.
#' Mouse channels are `mouse_x`, `mouse_y`, `mouse_wheel`, and `mouse_mode`;
#' mode 0 denotes absolute coordinates and mode 1 denotes relative movement.
#' The complete configuration remains in `movie$header$configuration`.
#' @inheritParams read_movie
#' @return A [replayr_movie] with frame timing, source inputs, and metadata.
#' @export
read_ltm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_ltm(path, ...), analog, deadzone, triggers)
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
read_wtf <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_wtf(path, ...), analog, deadzone, triggers)
}
#' Read a JPC-RR recording
#'
#' Reads JRSR text archives containing an `events` section. Keyboard edges,
#' mouse buttons and movement, joystick events, and reset commands are decoded.
#' Other emulator events remain in `movie$events` with their arguments and
#' original source lines. Initialization sections remain in
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
read_jrsr <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_jrsr(path, ...), analog, deadzone, triggers)
}
#' Read an openMSX replay
#'
#' Reads gzip-compressed openMSX XML replay files. Supported event schemas
#' cover keyboard matrices, joysticks, mice, trackballs, paddles, touchpads,
#' light guns, and autofire settings. The initial keyboard state is read from
#' the first replay snapshot. Source device names qualify the control keys,
#' such as `openmsx_keyjoystick1_a`; `openmsx_key_r8_b0` identifies a keyboard
#' matrix row and bit. All devices share one event stream.
#'
#' Each row follows one replay event. `movie$events$timestamp_ticks` retains
#' time in openMSX master-clock ticks (3,579,545 * 960 ticks per second), and
#' `timestamp_seconds` expresses the same event times in seconds.
#' `timestamp_source`, `event_type`, `source_device`, and `source_xml` retain
#' the event's original time, type, device, and XML.
#'
#' [analog_channels()] preserves device-specific values. Examples include
#' `openmsx_mouse_dx` and `openmsx_mouse_dy` for movement,
#' `openmsx_touchpad_x` and `openmsx_touchpad_y` for touch coordinates, and
#' `openmsx_autofire_renshaturbo` for the recorded autofire setting.
#' Movement deltas apply to their event; coordinates and settings persist
#' until updated. The replay schema version and machine name remain in
#' `movie$header$replay_version` and `movie$header$machine`.
#' @inheritParams read_movie
#' @return A [replayr_movie] with event times, device controls, and source XML.
#' @export
read_omr <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_omr(path, ...), analog, deadzone, triggers)
}
#' Read a BKM recording
#'
#' Legacy BizHawk text recordings.
#' Digital controls have compact columns with stable identities. Numeric source
#' fields remain available through [analog_channels()].
#' @inheritParams read_movie
#' @return An imported recording with header metadata and original input fields.
#' @export
read_bkm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_bkm(path, ...), analog, deadzone, triggers)
}
#' Read a GBMV recording
#'
#' GBAHawk ZIP recordings.
#' Digital controls have compact columns with stable identities. Numeric source
#' fields remain available through [analog_channels()].
#' @inheritParams read_movie
#' @return An imported recording with header metadata and original input fields.
#' @export
read_gbmv <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_gbmv(path, ...), analog, deadzone, triggers)
}
#' Read a FM3 recording
#'
#' FCEUX TAS Editor projects, with the movie length separating input records from editor data.
#' @inheritParams read_movie
#' @return An imported recording containing original input fields and metadata.
#' @export
read_fm3 <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_fm3(path, ...), analog, deadzone, triggers)
}
#' Read a TAS recording
#'
#' Early BizHawk text recordings.
#' @inheritParams read_movie
#' @return An imported recording containing original input fields and metadata.
#' @export
read_tas <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_tas(path, ...), analog, deadzone, triggers)
}
#' Read a TASPROJ recording
#'
#' BizHawk TAS Studio projects.
#' @inheritParams read_movie
#' @return An imported recording containing original input fields and metadata.
#' @export
read_tasproj <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_tasproj(path, ...), analog, deadzone, triggers)
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
#' through `analog`, using their source-specific centers and scales.
#' `poll_bytes` retains the seven-byte records. Timing follows device-poll
#' order; CTM provides no video-frame assignment for these rows.
#' @inheritParams read_movie
#' @return A [replayr_poll_stream] containing ordered device polls and metadata.
#' @export
read_ctm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_ctm(path, ...), analog, deadzone, triggers)
}
#' Read a CoffeeTools recording
#'
#' Reads CTAS versions 3 and 4 for UFO 50. Each row contains one frame's
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
#' are `NA` for version 3. Rows use the file's frame index; randomization
#' frame numbers are retained exactly as stored.
#' @inheritParams read_movie
#' @return A [replayr_movie] with held states, press/release flags, and randomization data.
#' @export
read_ctas <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_ctas(path, ...), analog, deadzone, triggers)
}
#' Read a gz input macro
#'
#' Imports gz Nintendo 64 macros, with one row per recorded game update.
#' [player()] returns the N64 buttons. [analog_channels()] retains signed
#' `stick_x` and `stick_y`; `analog` selects a derived stick representation.
#'
#' `frame_fields` retains pad deltas and press/release masks. `system_events`
#' retains random-seed changes and any ocarina-input, audio-synchronization,
#' or room-load records. The `commands` component marks reset events, and
#' `source_packets` retains the six-byte input records. Game updates provide
#' the observation order; elapsed time requires the game's update timing.
#' @inheritParams read_movie
#' @return A [replayr_movie] with compact digital columns and source metadata.
#' @export
read_gzm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_gzm(path, ...), analog, deadzone, triggers)
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
read_zmv <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  .configure_movie(.decode_zmv(path, ...), analog, deadzone, triggers)
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
read_mar <- function(path, analog = "raw", deadzone = NULL, triggers = "raw",
                     input_schema = NULL, ...) {
  .stick_modes(analog)
  .configure_movie(.decode_mar(path, input_schema = input_schema, ...), analog, deadzone, triggers)
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
#' rerecord count, source flags, and input-schema reference.
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
read_fbm <- function(path, analog = "raw", deadzone = NULL, triggers = "raw",
                     game = NULL, input_schema = NULL, ...) {
  .stick_modes(analog)
  .configure_movie(
    .decode_fbm(path, game = game, input_schema = input_schema, ...),
    analog, deadzone, triggers
  )
}
#' Read a Dustmod input script archive
#'
#' Imports DFT archives by following their entry script and INCLUDE commands.
#' Each row represents one scripted input frame. Directional double taps are
#' preserved in `double_tapped`; `source_digits` and `source_values` retain
#' the original 0, 1, and 2 encoding. Optional taunt and restart columns are
#' retained when present.
#'
#' `source_locations` identifies the archive member and line for each row.
#' `source_commands` preserves loading, synchronization, mouse, statistics,
#' and include commands in script order. MOUSE coordinates and button states
#' apply to the next scripted row, with observation masks identifying those
#' rows. SYNCLOAD can add runtime waiting whose duration requires execution
#' in the game; the imported rows retain script order.
#' @inheritParams read_movie
#' @param entry Entry script member. `NULL` selects the archive's unique
#'   `main.txt`; an explicit member resolves archives with several candidates.
#' @return A [replayr_movie] with source scripts, commands, and locations.
#' @export
read_dft <- function(path, analog = "raw", deadzone = NULL, triggers = "raw",
                     entry = NULL, ...) {
  .stick_modes(analog)
  .configure_movie(.decode_dft(path, entry = entry, ...), analog, deadzone, triggers)
}
