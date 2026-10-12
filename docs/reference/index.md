# Package index

## Import recordings

- [`read_movie()`](read_movie.md) : Import an emulator input recording
- [`supported_formats()`](supported_formats.md) : Names of the supported
  movie file extensions
- [`read_fm2()`](read_fm2.md) : Read a FM2 recording
- [`read_bk2()`](read_bk2.md) : Read a BK2 recording
- [`read_fcm()`](read_fcm.md) : Read a FCM recording
- [`read_lsmv()`](read_lsmv.md) : Read an lsnes LSMV recording
- [`read_gmv()`](read_gmv.md) : Read a GMV recording
- [`read_vbm()`](read_vbm.md) : Read a VBM recording
- [`read_m64()`](read_m64.md) : Read a M64 recording
- [`read_smv()`](read_smv.md) : Read a SMV recording
- [`read_pxm()`](read_pxm.md) : Read a PXM recording
- [`read_pjm()`](read_pjm.md) : Read a PJM recording
- [`read_dtm()`](read_dtm.md) : Read a DTM recording
- [`read_lmp()`](read_lmp.md) : Read a Doom or Boom demo
- [`read_fm3()`](read_fm3.md) : Read a FM3 recording
- [`read_fmv()`](read_fmv.md) : Read a Famtasia recording
- [`read_bkm()`](read_bkm.md) : Read a BKM recording
- [`read_tas()`](read_tas.md) : Read a TAS recording
- [`read_tasproj()`](read_tasproj.md) : Read a TASPROJ recording
- [`read_gbmv()`](read_gbmv.md) : Read a GBMV recording
- [`read_mmv()`](read_mmv.md) : Read a Dega recording
- [`read_dsm()`](read_dsm.md) : Read a DeSmuME recording
- [`read_mc2()`](read_mc2.md) : Read a PCEjin or VBjin recording
- [`read_mcm()`](read_mcm.md) : Read a Mednafen rerecording movie
- [`read_ymv()`](read_ymv.md) : Read a Yabause rerecording movie
- [`read_ctm()`](read_ctm.md) : Read a Citra device-poll recording
- [`read_gzm()`](read_gzm.md) : Read a gz input macro
- [`read_zmv()`](read_zmv.md) : Read an enhanced ZSNES recording
- [`read_mar()`](read_mar.md) : Read a MAME recording
- [`read_fbm()`](read_fbm.md) : Read a FinalBurn Alpha recording
- [`read_dft()`](read_dft.md) : Read a Dustmod input script archive
- [`read_ltm()`](read_ltm.md) : Read a libTAS recording
- [`read_wtf()`](read_wtf.md) : Read an Hourglass recording
- [`read_jrsr()`](read_jrsr.md) : Read a JPC-RR recording
- [`read_omr()`](read_omr.md) : Read an openMSX replay
- [`read_ctas()`](read_ctas.md) : Read a CoffeeTools recording
- [`movie_members()`](movie_members.md) : List input recordings in a ZIP
  archive
- [`read_bk2_chunks()`](read_bk2_chunks.md) : Process a BizHawk
  recording in bounded chunks

## Inspect observations and controllers

- [`replayr_movie`](replayr_movie.md) :

  The `replayr_movie` S3 class

- [`replayr_poll_stream`](replayr_poll_stream.md) : Ordered controller
  and device polls

- [`polls()`](polls.md) : Extract an unassigned controller-poll stream

- [`n_frames()`](n_frames.md) : Number of observations in an imported
  recording

- [`n_players()`](n_players.md) : Number of assigned input streams

- [`n_buttons()`](n_buttons.md) : Number of compact controller columns

- [`player()`](player.md) : Button states for one controller

- [`press_counts()`](press_counts.md) : Held-observation counts per
  control

- [`button_layout()`](button_layout.md) : Stable controller identities
  and compact movie columns

- [`align_buttons()`](align_buttons.md) : Align compact controller
  matrices by stable button identity

- [`analog_channels()`](analog_channels.md) : Numeric analogue channels
  for one player

- [`stick_channels()`](stick_channels.md) : Selected stick directions,
  angles and magnitudes

- [`system_channels()`](system_channels.md) : Global emulator and
  cabinet controls

## Stable controller registry

- [`universal_buttons()`](universal_buttons.md) : Universal controller
  mnemonics
- [`universal_button_names()`](universal_button_names.md) : Universal
  controller names

## Package

- [`replayr`](replayr-package.md)
  [`replayr-package`](replayr-package.md) : replayr: parsers for
  emulator movie ("input log") files
