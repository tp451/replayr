# replayr 0.4.0

Initial release.

* Import console and computer input recordings from current and historical
  emulator formats, including TAS editor projects and ZIP members.
* Store digital controls in compact logical arrays, with stable control IDs,
  readable labels, source metadata, and separate numeric channels.
* Name button columns and numeric channels by key in every accessor, so that
  `"a"` and `"left_x"` select the same control and stick axis in every format;
  `button_layout()` and `channel_layout()` list the labels of the recording.
* Name the controls of the console or cabinet by key as well:
  `system_channels()` has `reset`, `power`, `pause` and `coin_1` in every
  format that records them, and `system_layout()` lists the labels of the
  recording.
* List the formats with their readers and emulators through
  `supported_formats(details = TRUE)`: 37 file extensions in 33 formats, with
  the format whose file structure an extension has. `recording_format()`
  says as which format a file is read, and so which files of a folder are
  recordings.
* Read a recording under another extension: `read_movie()` recognises the
  formats that have a signature by their content, and `format` names the
  format in every other case.
* Report platform, video standard, frame rate, duration and rerecord count
  under one name each with `recording_info()`, and the time of each
  observation with `observation_time()`.
* Provide `summary()`, `as.data.frame()` and `[` methods for recordings:
  held observations and activations per control, one row per observation, and
  selection of observations that keeps the class.
* Support independent left and right stick representations: four directions,
  eight directions, angle, or angle and magnitude. Source X/Y values remain
  available in every mode.
* Take the default `deadzone` from the controller and not from the file
  format: 0.125 for the sticks of Nintendo's consoles, 0.25 for other sticks.
* Retain stick clicks, light-gun controls, mouse movement, keypad controls,
  touchscreens, keyboards, motion sensors, and separately recorded emulator
  and cabinet controls.
* Read the BK2 recordings of Gym Retro with `read_bk2()`.
* Return the text that the author of a FinalBurn Alpha recording entered
  when recording, in `movie$header$metadata`.
* Keep in the header what a recording says about the ROM or disc it was
  made with: the CRC32 and internal name of a Snes9x or ZSNES ROM, with the
  katakana of Japanese names; the header and global checksums of a Game Boy
  ROM and the game code of a Game Boy Advance ROM; the header CRC, country
  code and version of a Nintendo 64 ROM; the MD5 of a Dolphin disc image;
  and the IDs of the PlayStation discs played, in the order they were
  inserted. `header$SHA1Kind` says whether the hash BizHawk wrote under
  `SHA1` is a SHA1, an MD5 or a CRC32.
* Read the demonstration files of the Atari Grand Challenge and Atari-HEAD
  data sets (Atari 2600) with `read_txt()`. Each frame's
  action becomes the five controls of the joystick. The states of the game
  that the files also hold (score, reward, episode) are not input and are
  not read. Both are `.txt` files, which
  `read_movie()` tells apart by their first line; a trial of Atari-HEAD can
  be read out of the archive of its game.
* Read GoldSrc demos (Half-Life, Counter-Strike 1.x and other games of the
  engine, from the engine versions of 2001 on) with `read_dem()`: the
  16 actions of each command, the movement and the view angles it asks for,
  and the console commands of the demo.
* Read Doom-engine demos of Doom, Heretic and Hexen, from Doom 1.2 to MBF21
  and dsda-doom, with their game actions under IDs of their own.
* Preserve multi-controller M64 and DTM files as ordered poll streams when port labels
  are unavailable; accept a verified repeating port order for player assignment.
* Refuse a file that is not of a reader's format, with a message that names
  the problem; the FM2 reader requires the `version 3` line that FCEUX
  requires. A path that is no file is reported as "File not found".
* Include original artificial samples, source-defined regression fixtures, article
  examples, and their deterministic generators.
