make_wii_file <- function(packets, ports = 16L, prefix = FALSE) {
  path <- tempfile(fileext = '.dtm')
  header <- raw(256)
  header[1:4] <- charToRaw('DTM\x1a')
  header[5:10] <- charToRaw('TEST01')
  header[11] <- as.raw(1)
  header[12] <- as.raw(ports)
  header[22:29] <- as.raw(floor(length(packets) / 256^(0:7)) %% 256)
  body <- unlist(lapply(packets, function(p) c(if (prefix) raw(8), as.raw(length(p)), as.raw(p))))
  writeBin(c(header, as.raw(body)), path)
  path
}
test_that('Wii HID reports decode buttons, acceleration, and IR source coordinates', {
  # Extended IR: point 1=(0x156,0x278), size 3, plus three absent points.
  p <- c(161, 51, 8 + 32, 8 + 32, 128, 128, 154, 86, 120, 147, rep(255, 9))
  path <- make_wii_file(list(c(161, 48, 0, 0), p), prefix = TRUE)
  on.exit(unlink(path))
  m <- read_dtm(path)
  expect_identical(m$header$dtmVariant, 'wii-hid-prefix8')
  expect_identical(n_observations(m), 2L)
  expect_true(player(m)[2, 'a'])
  expect_true(player(m)[2, 'dpad_up'])
  a <- analog_channels(m)
  expect_equal(unname(a[2, c('accel_x', 'accel_y', 'accel_z')]), c(513, 515, 616))
  expect_equal(unname(a[2, c('ir1_x', 'ir1_y', 'ir1_size')]), c(342, 632, 3))
  expect_true(is.na(a[1, 'accel_x']))
  expect_identical(m$poll_prefix_bytes, matrix(as.raw(0), 2, 8))
  expect_identical(m$poll_lengths, c(4L, 19L))
  expect_identical(as.integer(m$poll_bytes[2, ]), as.integer(p))
})
test_that('serialized Wii states expose both Classic Controller sticks', {
  # Flags: buttons and Classic Controller; remote A/up. Left=(63,32), right=(0,16).
  p <- c(33, 1, 1, 63, 32, 16, 0, 255, 255)
  path <- make_wii_file(list(p, c(0)), ports = 48L)
  on.exit(unlink(path))
  m <- read_dtm(path, analog = c(left = 'cardinal4', right = 'angle+magnitude'))
  expect_s3_class(m, 'replayr_poll_stream')
  expect_identical(m$header$dtmVariant, 'wii-serialized')
  expect_true(polls(m)$a[1])
  expect_true(polls(m)$dpad_up[1])
  expect_equal(unname(stick_channels(m)[1, 'left_direction']), 0)
  expect_equal(unname(stick_channels(m)[1, 'right_angle']), 180)
  expect_equal(unname(stick_channels(m)[1, 'right_magnitude']), 1)
  expect_equal(unname(analog_channels(m)[2, 'accel_z']), 616)
  expect_identical(polls(m)$extension_type, c(2, 0))
})
test_that('legacy Wii extension interpretation is explicit and bytes are retained', {
  p <- c(161, 55, 0, 0, 128, 128, 154, rep(255, 10), 255, 128, 128, 128, 154, 253)
  path <- make_wii_file(list(p))
  on.exit(unlink(path))
  raw <- read_dtm(path)
  expect_false(any(grepl('nunchuk', button_layout(raw)$key)))
  m <- read_dtm(path, wii_extension = 'nunchuk', analog = 'angle+magnitude')
  expect_true(player(m)[1, 'c'])
  expect_equal(unname(stick_channels(m)[1, 'left_angle']), 0)
  expect_equal(unname(stick_channels(m)[1, 'left_magnitude']), 127 / 128)
  expect_equal(unname(analog_channels(m)[1, 'extension_byte6']), 253)
  data <- readBin(path, 'raw', file.info(path)$size)
  writeBin(data[-length(data)], path)
  expect_error(read_dtm(path), 'incomplete or unrecognised')
})
test_that('empty Wii logs accept a supplied controller order', {
  path <- make_wii_file(list(), ports = 48L)
  on.exit(unlink(path))
  m <- read_dtm(path, controller_order = c(1L, 2L))
  expect_identical(n_observations(m), 0L)
  expect_identical(n_players(m), 2L)
})
test_that('unobserved and partial Wii records retain source evidence', {
  path <- make_wii_file(list(c(161, 49, 0, 0, 128, 128, 154), rep(0, 7)))
  on.exit(unlink(path))
  data <- readBin(path, 'raw', file.info(path)$size)
  writeBin(c(data, as.raw(c(7, 10))), path)
  expect_warning(m <- suppressWarnings(read_dtm(path)), NA)
  expect_s3_class(m, 'replayr_poll_stream')
  expect_identical(m$source_tail, as.raw(c(7, 10)))
  expect_identical(polls(m)$valid_report, c(TRUE, FALSE))
  expect_identical(as.integer(m$poll_bytes[2, ]), rep(0L, 7))
  expect_true(is.na(analog_channels(m)[2, 'accel_x']))
})
test_that('legacy mixed DTM retains interleaved GC and Wii observations', {
  path <- make_wii_file(list(), ports = 17L)
  on.exit(unlink(path))
  h <- readBin(path, 'raw', 256)
  h[22] <- as.raw(3)
  gc <- c(2, 0, 0, 0, 255, 128, 128, 255)
  hid <- c(4, 161, 48, 0, 8)
  writeBin(c(h, as.raw(c(gc, hid, gc))), path)
  m <- read_dtm(path, wii_variant = 'mixed-hid', analog = 'angle+magnitude')
  expect_s3_class(m, 'replayr_poll_stream')
  expect_identical(polls(m)$device, c('gc', 'wii', 'gc'))
  expect_identical(polls(m)$physical_port, rep(1L, 3))
  expect_identical(m$poll_lengths, c(8L, 5L, 8L))
  expect_identical(as.integer(m$poll_bytes[2, 1:5]), as.integer(hid))
  expect_true(all(polls(m)$a))
  expect_equal(stick_channels(m)[c(1, 3), 'left_angle'], c(0, 0))
  expect_true(is.na(stick_channels(m)[2, 'left_angle']))
  expect_equal(m$header$pollCountDifference, '0')
  expect_error(read_dtm(path), 'verified Dolphin revision')
  expect_error(read_dtm(path, wii_variant = 'mixed-hid', controller_order = 1), 'cannot assign mixed')
})
test_that('markerless Wii packets preserve source bytes and decoded fields', {
  packet <- c(51, 8 + 32, 8 + 32, 128, 128, 154, 86, 120, 147, rep(255, 9))
  path <- make_wii_file(list(c(48, 0, 0), packet))
  on.exit(unlink(path))
  m <- read_dtm(path)
  expect_identical(m$header$dtmVariant, 'wii-hid-nomarker')
  expect_true(player(m)[2, 'a'])
  expect_equal(unname(analog_channels(m)[2, c('accel_x', 'accel_y', 'accel_z')]), c(513, 515, 616))
  expect_equal(unname(analog_channels(m)[2, c('ir1_x', 'ir1_y', 'ir1_size')]), c(342, 632, 3))
  expect_identical(m$poll_lengths, c(3L, 18L))
  expect_identical(as.integer(m$poll_bytes[2, ]), as.integer(packet))
})
test_that('modern mixed Wii framing requires the connected-pad assumption', {
  path <- make_wii_file(list(), ports = 31L)
  on.exit(unlink(path))
  h <- readBin(path, 'raw', 256)
  h[22] <- as.raw(3)
  gc <- c(2, 64, 0, 0, 255, 128, 128, 255)
  wii <- c(3, 48, 0, 8)
  writeBin(c(h, as.raw(c(gc, wii, gc))), path)
  expect_error(read_dtm(path), 'explicit mixed-hid-connected assumption')
  m <- read_dtm(path, wii_variant = 'mixed-hid-connected')
  expect_s3_class(m, 'replayr_poll_stream')
  expect_identical(polls(m)$device, c('gc', 'wii', 'gc'))
  expect_identical(polls(m)$physical_port, c(NA_integer_, 1L, NA_integer_))
  expect_true(all(polls(m)$a))
  expect_identical(m$poll_lengths, c(8L, 4L, 8L))
  expect_match(m$header$framingAssumption, 'caller confirms')
  expect_equal(m$header$pollCountDifference, '0')
})
test_that('Wii records with damaged report headers remain unobserved source data', {
  good <- c(161, 51, 0, 8, 128, 128, 154, rep(255, 12))
  damaged <- c(rep(255, 7), 128, 106, 100, 128, 106, 246, 128, 90, 110, 128, 106, 0)
  path <- make_wii_file(list(good, damaged, good))
  on.exit(unlink(path))
  expect_warning(m <- read_dtm(path), '1 unrecognised Wii reports')
  expect_identical(polls(m)$valid_report, c(TRUE, FALSE, TRUE))
  expect_false(any(m$inputs[2, 1, ]))
  expect_true(is.na(analog_channels(m)[2, 'accel_x']))
  expect_identical(as.integer(m$poll_bytes[2, ]), as.integer(damaged))
  expect_identical(m$poll_lengths, c(19L, 19L, 19L))
  expect_equal(m$header$pollCountDifference, '0')
})
test_that('Wii menu buttons use shared IDs in every report encoding', {
  # Hardware masks: Plus=0x0010, Minus=0x1000. Serialized states: bits 2, 3.
  packets <- list(
    list(c(161, 48, 16, 0), c(161, 48, 0, 16), c(161, 48, 16, 16)),
    list(c(48, 16, 0), c(48, 0, 16), c(48, 16, 16)),
    list(c(1, 4, 0), c(1, 8, 0), c(1, 12, 0))
  )
  expected <- cbind(T = c(TRUE, FALSE, TRUE), S = c(FALSE, TRUE, TRUE))
  for (i in seq_along(packets)) {
    path <- make_wii_file(packets[[i]])
    movie <- read_dtm(path)
    layout <- button_layout(movie)
    expect_identical(as.character(layout$id[match(c('start', 'select'), layout$key)]), c('5', '6'))
    expect_equal(unname(player(movie)[, c('start', 'select')]), unname(expected))
    expect_false(any(c('wii_plus', 'wii_minus') %in% layout$key))
    expect_identical(movie$poll_fields$wii_remote_start, expected[, 'T'])
    expect_identical(movie$poll_fields$wii_remote_select, expected[, 'S'])
    unlink(path)
  }
  path <- make_wii_file(packets[[1]], prefix = TRUE)
  on.exit(unlink(path))
  expect_equal(unname(player(read_dtm(path))[, c('start', 'select')]), unname(expected))
})
test_that('Classic Controller controls align without losing Remote states', {
  # One active-low Classic button per report, from the Dolphin wire mask.
  keys <- c(
    'r1', 'start', 'mode', 'select', 'l1', 'dpad_down', 'dpad_right',
    'dpad_up', 'dpad_left', 'r2', 'x', 'a', 'y', 'b', 'l2'
  )
  words <- bitwXor(65535L, bitwShiftL(1L, 1:15))
  packets <- lapply(words, function(w) c(33, 0, 0, 32, 32, 16, 0, w %% 256, w %/% 256))
  # The sixteenth report activates Remote Plus and Classic Minus together.
  packets[[16]] <- c(33, 4, 0, 32, 32, 16, 0, 239, 255)
  path <- make_wii_file(packets)
  on.exit(unlink(path))
  movie <- read_dtm(path)
  layout <- button_layout(movie)
  values <- player(movie)
  colnames(values) <- layout$key
  expect_equal(unname(values[1:15, keys]), diag(TRUE, 15))
  expect_true(all(values[16, c('start', 'select')]))
  expect_true(movie$poll_fields$wii_remote_start[16])
  expect_false(movie$poll_fields$wii_classic_start[16])
  expect_false(movie$poll_fields$wii_remote_select[16])
  expect_true(movie$poll_fields$wii_classic_select[16])
  known <- keys
  registry <- button_layout()
  expect_identical(
    as.character(layout$id[match(known, layout$key)]),
    as.character(registry$id[match(known, registry$key)])
  )
  # The same extension bytes in historical HID reports use the same IDs.
  hid <- lapply(words, function(w) c(161, 50, 0, 0, 32, 32, 16, 0, w %% 256, w %/% 256, 255, 255))
  old_path <- make_wii_file(hid)
  on.exit(unlink(old_path), add = TRUE)
  old <- read_dtm(old_path, wii_extension = 'classic')
  old_values <- player(old)
  colnames(old_values) <- button_layout(old)$key
  expect_equal(unname(old_values[, keys]), diag(TRUE, 15))
})
test_that('Nunchuk buttons share the C and Z identities', {
  path <- make_wii_file(list(
    c(16, 128, 128, 128, 128, 154, 253),
    c(16, 128, 128, 128, 128, 154, 254)
  ))
  on.exit(unlink(path))
  movie <- read_dtm(path)
  layout <- button_layout(movie)
  expect_identical(as.character(layout$id[match(c('c', 'z'), layout$key)]), c('17', '18'))
  expect_equal(unname(player(movie)[, c('c', 'z')]), diag(TRUE, 2))
})
test_that('mixed GameCube and Wii polls share Start and Select identities', {
  path <- make_wii_file(list(), ports = 17L)
  on.exit(unlink(path))
  header <- readBin(path, 'raw', 256)
  header[22] <- as.raw(3)
  # GC Start, Wii Plus, Wii Minus.
  body <- c(1, 0, 0, 0, 128, 128, 128, 128, 4, 161, 48, 16, 0, 4, 161, 48, 0, 16)
  writeBin(c(header, as.raw(body)), path)
  movie <- read_dtm(path, wii_variant = 'mixed-hid')
  p <- polls(movie)
  expect_identical(p$start, c(TRUE, TRUE, FALSE))
  expect_identical(p$select, c(FALSE, FALSE, TRUE))
  expect_identical(p$wii_remote_start, c(NA, TRUE, FALSE))
  expect_identical(p$wii_remote_select, c(NA, FALSE, TRUE))
})
test_that('every Wii Remote button has the intended universal identity', {
  # Independent single-bit reports exercise every hardware button.
  source_bits <- c(0:4, 8:12, 15)
  public_keys <- c(
    'dpad_left', 'dpad_right', 'dpad_down', 'dpad_up', 'start',
    'y', 'x', 'b', 'a', 'select', 'mode'
  )
  ids <- c(2L, 1L, 3L, 4L, 5L, 10L, 9L, 7L, 8L, 6L, 19L)
  words <- bitwShiftL(1L, source_bits)
  hid <- lapply(words, function(w) c(161, 48, w %% 256, w %/% 256))
  path <- make_wii_file(hid)
  on.exit(unlink(path))
  movie <- read_dtm(path)
  layout <- button_layout(movie)
  expect_identical(as.integer(layout$id[match(public_keys, layout$key)]), ids)
  values <- player(movie)
  colnames(values) <- layout$key
  expect_equal(unname(values[, public_keys]), diag(TRUE, 11))
  expect_equal(ncol(values), 11L)
  expect_false(any(grepl('^wii_', layout$key)))
  expect_true(all(c('wii_one', 'wii_two', 'wii_home') %in% movie$source_layout$key))
  serial_keys <- c(
    'a', 'b', 'start', 'select', 'x', 'y', 'mode',
    'dpad_up', 'dpad_down', 'dpad_left', 'dpad_right'
  )
  serial <- c(
    lapply(0:6, function(bit) c(1, 2^bit, 0)),
    lapply(0:3, function(bit) c(1, 0, 2^bit))
  )
  path2 <- make_wii_file(serial)
  on.exit(unlink(path2), add = TRUE)
  m <- read_dtm(path2)
  values <- player(m)
  colnames(values) <- button_layout(m)$key
  expect_equal(unname(values[, serial_keys]), diag(TRUE, 11))
})
test_that('simultaneous Remote and Classic X stay available individually', {
  # First poll: Remote 1. Second: Classic X. Third: both.
  p <- list(
    c(33, 16, 0, 32, 32, 16, 0, 255, 255),
    c(33, 0, 0, 32, 32, 16, 0, 255, 247),
    c(33, 16, 0, 32, 32, 16, 0, 255, 247)
  )
  path <- make_wii_file(p)
  on.exit(unlink(path))
  m <- read_dtm(path)
  expect_identical(unname(player(m)[, 'x']), c(TRUE, TRUE, TRUE))
  original <- m$source_inputs
  keys <- m$source_layout$key
  expect_identical(original[, 1, match('wii_one', keys)], c(TRUE, FALSE, TRUE))
  expect_identical(original[, 1, match('x', keys)], c(FALSE, TRUE, TRUE))
})
test_that('Wii accelerometer values are widened as Dolphin widens them', {
  # Nine-bit Y and Z take their lowest bit again as the tenth bit: Y is
  # 2 * 129 + 0 = 258 -> 516 and Z is 2 * 100 + 1 = 201 -> 403.
  packet <- c(161, 49, 0, 64, 128, 129, 100)
  path <- make_wii_file(list(packet))
  on.exit(unlink(path))
  a <- analog_channels(read_dtm(path))
  expect_equal(unname(a[1, c('accel_x', 'accel_y', 'accel_z')]), c(512, 516, 403))
})
