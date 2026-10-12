test_that("replayr:::.decode_bk2() parses the bundled synthetic NES movie", {
  mv <- replayr:::.decode_bk2(analog = "quantized", fixture_path("sample.bk2"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "bk2")
  expect_equal(n_frames(mv), 3600L)
  expect_equal(n_players(mv), 1L)
  expect_equal(n_buttons(mv), 8L)
  pc <- press_counts(mv, 1L)
  expect_true(sum(pc) > 0L)
})
test_that("LogKey parser handles the NES single-group case correctly", {
  # Synthetic GB-shaped LogKey (single group, no P1 prefix).
  parsed <- replayr:::.parse_bk2_logkey(
    "LogKey:#Up|Down|Left|Right|Start|Select|B|A|Power|"
  )
  expect_length(parsed$btn_map, 1L)
  # All eight buttons map to slots 1..8 (in some order).
  slots <- vapply(parsed$btn_map[[1L]], function(e) e$slot, integer(1))
  expect_setequal(slots, 1:8)
})
test_that("LogKey parser separates command group from player groups", {
  # Multi-group NES LogKey (FCEUX-style).
  parsed <- replayr:::.parse_bk2_logkey(
    "LogKey:#Reset|Power|#P1 Up|P1 Down|P1 Left|P1 Right|P1 Start|P1 Select|P1 B|P1 A|"
  )
  expect_equal(parsed$commands, c("Reset", "Power"))
  expect_length(parsed$btn_map, 1L)
  slots <- vapply(parsed$btn_map[[1L]], function(e) e$slot, integer(1))
  expect_setequal(slots, 1:8)
})
test_that("LogKey parser disambiguates the Nymashock PSX face buttons", {
  # Mednafen-family PSX cores name the face buttons with Unicode glyphs
  # (Triangle/Square/Circle) plus an ASCII "X" for Cross. The glyphs mark the
  # LogKey as PSX so "X" resolves to Cross (slot 7), not the SNES X-face (slot 9).
  parsed <- replayr:::.parse_bk2_logkey(paste0(
    "LogKey:#Reset|Power|#P1 Up|P1 Down|P1 Left|P1 Right|P1 Select|P1 Start|",
    "P1 △|P1 X|P1 □|P1 ○|P1 L1|P1 R1|"
  ))
  slots <- vapply(parsed$btn_map[[1L]], function(e) e$slot, integer(1))
  expect_true(7L %in% slots) # Cross -> slot 7 (disambiguated, not SNES X=9)
  expect_true(9L %in% slots) # Triangle
  expect_true(10L %in% slots) # Square
  expect_true(8L %in% slots) # Circle
})
test_that("replayr:::.decode_bk2() decodes a Nymashock PSX movie via its UTF-8 LogKey", {
  # UTF-8 shape glyphs identify the PlayStation layout. Cross must map to
  # its PSX decoder slot rather than being interpreted as the SNES X button.
  td <- tempfile("nyma-")
  dir.create(td)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)
  writeLines(
    c("GameName SynthNyma", "Core Nymashock", "Platform PSX"),
    file.path(td, "Header.txt")
  )
  log <- paste0(
    "[Input]\n",
    "LogKey:#Reset|Power|#P1 Up|P1 Down|P1 Left|P1 Right|P1 Select|P1 Start|",
    "P1 △|P1 X|P1 □|P1 ○|P1 L1|P1 R1|\n",
    "|..|.......X....|\n", # column 8 = Cross pressed
    "|..|............|\n"
  )
  writeBin(charToRaw(enc2utf8(log)), file.path(td, "Input Log.txt"))
  bk2 <- tempfile(fileext = ".bk2")
  on.exit(unlink(bk2), add = TRUE)
  zip::zipr(bk2, c("Header.txt", "Input Log.txt"), root = td)
  mv <- replayr:::.decode_bk2(analog = "quantized", bk2)
  expect_true(mv$inputs[1, 1, 7]) # Cross on slot 7 (B)
  expect_false(mv$inputs[1, 1, 9]) # NOT the SNES X-face slot 9
})
test_that("BK2 PSX analog axes use unsigned 128-centred values", {
  log <- paste0(
    "[Input]\n",
    "LogKey:#Reset|Power|#P1 LStick X|P1 LStick Y|P1 Up|\n",
    "|..|0,128,.|\n"
  )
  mv <- replayr:::.parse_bk2_input_log(
    analog = "quantized",
    log,
    header = list("_format" = "bk2", Platform = "PSX", Core = "Nymashock")
  )
  expect_true(mv$inputs[1L, 1L, 25L]) # X=0 is full west, not neutral
})
test_that("BK2 does not reinterpret a sparse LogKey as NES columns", {
  log <- paste0(
    "[Input]\n",
    "LogKey:#Reset|Power|#P1 Unknown One|P1 Unknown Two|P1 Up|\n",
    "|..|..U|\n"
  )
  expect_error(replayr:::.parse_bk2_input_log(analog = "quantized", log), "too sparse")
})
test_that("NES paddle positions preserve Fire and represent signed motion", {
  log <- paste(c(
    '[Input]', 'LogKey:#Power|Reset|#P1 Paddle|P1 Fire|',
    '|..|80,F|', '|..|160,.|', '|..|160,F|', '|..|0,.|',
    '|..|1,.|', '|..|1,.|', '[/Input]'
  ), collapse = '\n')
  mv <- replayr:::.parse_bk2_input_log(analog = "quantized", log, header = list(Platform = 'NES'))
  expect_equal(which(mv$inputs[, 1, 8]), c(1L, 3L))
  expect_equal(which(mv$inputs[, 1, 21]), c(2L, 5L))
  expect_equal(which(mv$inputs[, 1, 25]), 4L)
  expect_false(any(mv$inputs[c(3L, 6L), 1, 21:28]))
  expect_error(replayr:::.parse_bk2_input_log(
    analog = "quantized", sub('160', '161', log),
    header = list(Platform = 'NES')
  ), 'outside 0..160')
  expect_error(
    replayr:::.parse_bk2_input_log(analog = "quantized", log, header = list(Platform = 'A26')),
    'unsupported bk2 paddle'
  )
})
test_that("BK2 cannot silently drop active unknown or undeclared numeric inputs", {
  log <- paste(c(
    '[Input]', 'LogKey:#Power|Reset|#P1 Up|P1 Down|P1 Other|',
    '|..|..X|'
  ), collapse = '\n')
  expect_error(replayr:::.parse_bk2_input_log(analog = "quantized", log), 'unmapped active bk2 control')
  log <- paste(c(
    '[Input]', 'LogKey:#Power|Reset|#P1 Up|P1 Fire|',
    '|..|80,F.|'
  ), collapse = '\n')
  expect_error(replayr:::.parse_bk2_input_log(analog = "quantized", log), 'columns disagree')
})
test_that('long-form PSX axes, stick buttons and Analog have distinct types', {
  key <- paste0(
    'LogKey:#Power|Reset|#P1 Left Stick Up / Down|P1 Left Stick Left / Right|',
    'P1 Right Stick Up / Down|P1 Right Stick Left / Right|P1 Up|P1 Down|',
    'P1 Left Stick, Button|P1 Right Stick, Button|P1 Analog|'
  )
  for (version in c('Version 2.8', 'Version 2.9', 'Version 2.10')) {
    center <- if (version == 'Version 2.8') 32768L else 128L
    row <- paste0('|..|', center, ',0,0,', center, ',..<>A|')
    mv <- replayr:::.parse_bk2_input_log(
      analog = "quantized", paste(key, row, sep = '\n'),
      header = list(Platform = 'PSX', Core = 'Nymashock', emuVersion = version)
    )
    expect_setequal(which(mv$inputs[1, 1, ]), c(15, 20, 25, 41, 42))
  }
  bad <- paste(key, '|..|32768,32768,32768,32768,.....|', sep = '\n')
  expect_error(
    replayr:::.parse_bk2_input_log(
      analog = "quantized", bad,
      header = list(Platform = 'PSX', Core = 'Nymashock', emuVersion = 'Version 2.10')
    ),
    'outside declared encoding'
  )
})
test_that('BK2 obeys ordered controls across irregular boundaries like BizHawk', {
  key <- paste0(
    'LogKey:#Disc Select|Open|Close|Reset|',
    '#P1 Up|P1 Down|P1 Left|P1 Right|#P2 Up|P2 Down|P2 Left|P2 Right|'
  )
  # The fifth P1 display character is actually consumed as P2 Up.
  log <- paste(key, '||    1,...|...RZ|...|', sep = '\n')
  expect_warning(
    mv <- replayr:::.parse_bk2_input_log(analog = "quantized", log, header = list(Platform = 'PSX')),
    'noncanonical boundaries'
  )
  expect_true(mv$inputs[1, 1, 1])
  expect_true(mv$inputs[1, 2, 4])
  expect_equal(sum(mv$inputs), 2)
  expect_equal(mv$commands, 0L)
  expect_equal(mv$header$logKeyStreamBoundarySamples, 1L)
})
test_that('BK2 trailing unbound controls are recorded as unconsumed, not invented players', {
  key <- paste0(
    'LogKey:#Power|Reset|#P1 Up|P1 Down|P1 Left|P1 Right|',
    'P1 A|P1 B|P1 C|P1 Start|'
  )
  log <- paste(key, '|..|...R..C...Z.|............|', '|..|...R..C.|', sep = '\n')
  expect_warning(
    mv <- replayr:::.parse_bk2_input_log(analog = "quantized", log, header = list(Platform = 'GEN')),
    '1 samples have active trailing'
  )
  expect_equal(n_players(mv), 1L)
  expect_equal(mv$inputs[1, 1, ], mv$inputs[2, 1, ])
  expect_setequal(which(mv$inputs[1, 1, ]), c(1, 13))
  expect_equal(mv$header$unconsumedTrailingActiveSamples, 1L)
})
test_that('no-prefix multiword controls keep their full name', {
  p <- replayr:::.parse_bk2_logkey('LogKey:#D-Pad Up|D-Pad Down|Left Stick, Button|')
  expect_setequal(vapply(p$btn_map[[1]], function(x) x$slot, integer(1)), c(4L, 3L, 41L))
})
test_that('numeric reset timing does not consume player button positions', {
  for (control in c('Reset Instruction', 'Reset Cycle')) {
    log <- paste0(
      'LogKey:#', control, '|Power|Reset|#P1 Up|P1 Down|\n',
      '|    0,..|U.|'
    )
    mv <- replayr:::.parse_bk2_input_log(analog = "quantized", log, header = list(Platform = 'NES'))
    expect_setequal(which(mv$inputs[1, 1, ]), 4L)
    expect_equal(mv$commands, 0L)
  }
})
test_that('a concatenated PSX suffix is flagged without inventing a second frame', {
  key <- 'LogKey:#Disc Select|Open|Close|Reset|#P1 Up|P1 Down|'
  log <- paste(key, '|    1,...|U.|..............||    1,...|.D|', sep = '\n')
  expect_warning(
    mv <- replayr:::.parse_bk2_input_log(analog = "quantized", log, header = list(Platform = 'PSX')),
    'active trailing'
  )
  expect_equal(n_frames(mv), 1L)
  expect_setequal(which(mv$inputs[1, 1, ]), 4L)
})
test_that('Octoshock follows its byte cast rather than clamping logged axes', {
  key <- 'LogKey:#Disc Select|Open|Close|Reset|#P1 LStick X|P1 LStick Y|P1 Cross|'
  log <- paste(key, '|    1,...|128,256,.|', '|    1,...|-1,128,X|', sep = '\n')
  expect_warning(
    mv <- replayr:::.parse_bk2_input_log(
      analog = "quantized", log,
      header = list(Platform = 'PSX', Core = 'Octoshock', emuVersion = 'Version 1.11.7')
    ),
    'byte conversion applied to 2'
  )
  expect_setequal(which(mv$inputs[1, 1, ]), 23L)
  expect_setequal(which(mv$inputs[2, 1, ]), c(7L, 21L))
  expect_equal(mv$header$octoshockByteWrappedAxisValues, 2L)
  expect_error(
    replayr:::.parse_bk2_input_log(
      analog = "quantized", log,
      header = list(Platform = 'PSX', Core = 'Nymashock', emuVersion = 'Version 2.10')
    ),
    'outside declared encoding'
  )
})
