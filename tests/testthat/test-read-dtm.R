test_that("replayr:::.decode_dtm() parses the bundled synthetic GameCube movie", {
  mv <- replayr:::.decode_dtm(analog = "quantized", fixture_path("sample.dtm"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "dtm")
  expect_equal(n_frames(mv), 3600L)
  expect_equal(n_players(mv), 1L)
  expect_equal(n_buttons(mv), 28L)
  expect_gt(sum(press_counts(mv, 1L)[21:28]), 0L)
})

test_that("replayr:::.decode_dtm() parses an optional external GameCube movie", {
  fp <- external_fixture("raw_gc/luigis_mansion/2587.dtm")
  if (is.null(fp)) skip("set REPLAYR_FIXTURE_DIR to enable DTM test")
  mv <- replayr:::.decode_dtm(analog = "quantized", fp)
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "dtm")
  expect_gt(n_frames(mv), 0L)
  expect_equal(n_buttons(mv), 28L)
})

.mk_dtm <- function(button_word, controller_mask = 1L) {
  hdr <- raw(0x100L)
  hdr[1:4] <- charToRaw("DTM\x1a")
  hdr[5:10] <- charToRaw("TEST01")
  hdr[12] <- as.raw(controller_mask)
  hdr[14] <- as.raw(1L) # frameCount u64
  hdr[22] <- as.raw(1L) # inputCount u64
  record <- as.raw(c(bitwAnd(button_word, 0xffL),
                     bitwAnd(bitwShiftR(button_word, 8L), 0xffL),
                     0, 0, 128, 128, 128, 128))
  tf <- tempfile(fileext = ".dtm")
  writeBin(c(hdr, record), tf)
  tf
}

test_that("replayr:::.decode_dtm() uses packed button bits and preserves commands", {
  tf <- .mk_dtm(bitwOr(bitwShiftL(1L, 1L), bitwShiftL(1L, 13L)))
  on.exit(unlink(tf))
  mv <- replayr:::.decode_dtm(analog = "quantized", tf)
  expect_equal(n_frames(mv), 1L)
  expect_true(mv$inputs[1L, 1L, 8L])
  expect_equal(mv$commands, 2L)
})

test_that("multi-controller DTM preserves an unassigned poll and every byte", {
  tf <- .mk_dtm(0xffffL, controller_mask = 3L)
  on.exit(unlink(tf))
  bytes <- readBin(tf, "raw", n = file.info(tf)$size)
  bytes[259:264] <- as.raw(c(10, 20, 200, 160, 100, 80))
  writeBin(bytes, tf)
  for (mode in c("raw", "cardinal4", "cardinal8", "angle", "angle+magnitude")) {
    mv <- read_dtm(tf, analog = mode)
    expect_s3_class(mv, "replayr_poll_stream")
    expect_false(inherits(mv, "replayr_movie"))
    expect_identical(n_players(mv), NA_integer_)
    expect_identical(n_frames(mv), 1L)
    expect_identical(as.vector(t(mv$poll_bytes)), bytes[257:264])
    data <- polls(mv)
    expect_identical(data$port, NA_integer_)
    expect_true(data$is_connected)
    expect_true(data$get_origin)
    expect_identical(data$commands, 3L)
    expect_true(all(unlist(data[1, mv$button_keys[mv$button_ids %in% c(1:5,7:12,18)]])))
    expect_equal(unname(analog_channels(mv)[1, ]), c(10, 20, 200, 160, 100, 80))
    expect_error(player(mv), "use polls")
    expect_match(format(mv), "assignment=unassigned")
  }
})

test_that('DTM accepts only an explicit complete repeating controller order', {
  tf<-.mk_dtm(2L,controller_mask=3L);on.exit(unlink(tf))
  b<-readBin(tf,'raw',n=file.info(tf)$size)
  b[22]<-as.raw(2L)
  other<-b[257:264];other[1]<-as.raw(4L)
  writeBin(c(b,other),tf)
  mv<-replayr:::.decode_dtm(analog = "quantized", tf,controller_order=c(1L,2L))
  expect_equal(n_players(mv),2L)
  expect_equal(n_frames(mv),1L)
  expect_true(mv$inputs[1,1,8])
  expect_false(mv$inputs[1,1,7])
  expect_true(mv$inputs[1,2,7])
  expect_match(mv$header$controllerAssignment,'caller-supplied')
  swapped<-replayr:::.decode_dtm(analog = "quantized", tf,controller_order=c(2L,1L))
  expect_true(swapped$inputs[1,2,8])
  expect_error(replayr:::.decode_dtm(analog = "quantized", tf,controller_order=c(1,1)),'every enabled port')
  expect_error(replayr:::.decode_dtm(analog = "quantized", tf,controller_order=c(1,3)),'every enabled port')
  b[22]<-as.raw(1L);writeBin(b,tf)
  expect_error(replayr:::.decode_dtm(analog = "quantized", tf,controller_order=c(1,2)),'incomplete')
})

test_that("DTM chunk boundaries preserve polls, flags, and both sticks", {
  count <- 65538L
  tf <- .mk_dtm(0L, controller_mask = 3L)
  on.exit(unlink(tf))
  header <- readBin(tf, "raw", n = 256L)
  header[22:25] <- writeBin(count, raw(), size = 4L, endian = "little")
  records <- matrix(rep(c(0L, 0L, 0L, 0L, 128L, 128L, 128L, 128L), count),
                    ncol = 8L, byrow = TRUE)
  selected <- c(1L, 65536L, 65537L, 65538L)
  records[selected, ] <- rbind(c(2L, 64L, 0L, 255L, 192L, 128L, 128L, 192L),
                               c(4L, 16L, 255L, 0L, 128L, 192L, 64L, 128L),
                               c(8L, 32L, 0L, 0L, 64L, 128L, 128L, 64L),
                               c(16L, 128L, 0L, 0L, 128L, 64L, 192L, 128L))
  writeBin(c(header, as.raw(as.vector(t(records)))), tf)
  for (mode in c("raw", "cardinal4", "cardinal8", "angle", "angle+magnitude")) {
    movie <- read_dtm(tf, analog = mode)
    expect_identical(n_frames(movie), count)
    expect_s3_class(movie, "replayr_poll_stream")
    expect_equal(unname(analog_channels(movie)), records[, 3:8])
    expect_identical(as.vector(t(movie$poll_bytes)), as.raw(as.vector(t(records))))
    data <- polls(movie)[selected, ]
    expect_identical(data$commands, c(0L, 1L, 2L, 0L))
    expect_identical(data$is_connected, c(TRUE, FALSE, FALSE, FALSE))
    expect_identical(data$get_origin, c(FALSE, FALSE, FALSE, TRUE))
    expect_equal(as.matrix(data[, c("a", "b", "x", "y")]),
                 unname(diag(TRUE, 4L)), ignore_attr = TRUE)
    if (mode %in% c("angle", "angle+magnitude")) {
      expect_equal(data$left_angle, c(0, 90, 180, 270))
      expect_equal(data$right_angle, c(90, 180, 270, 0))
    }
  }
  assigned <- read_dtm(tf, controller_order = c(2L, 1L), analog = "angle+magnitude")
  expect_equal(n_frames(assigned), count / 2L)
  expect_true(tail(player(assigned, 1L)[, "y"], 1L))
  expect_true(tail(player(assigned, 2L)[, "x"], 1L))
  expect_equal(tail(stick_channels(assigned, 1L)[, "left_angle"], 1L), 270)
  expect_equal(tail(stick_channels(assigned, 2L)[, "left_angle"], 1L), 180)
  projected <- replayr:::.decode_dtm(tf, analog = "quantized")
  expect_true(projected$inputs[1L, 1L, 21L])
  expect_true(projected$inputs[65536L, 1L, 23L])
  expect_true(projected$inputs[65537L, 1L, 25L])
  expect_true(projected$inputs[65538L, 1L, 27L])
})

test_that("DTM imports complete stored polls when its input statistic differs", {
  tf <- .mk_dtm(2L)
  on.exit(unlink(tf))
  bytes <- readBin(tf, "raw", n = file.info(tf)$size)
  for (declared in c(0L, 3L, 66L, 97L)) {
    bytes[22:25] <- writeBin(declared, raw(), size = 4L, endian = "little")
    writeBin(bytes, tf)
    expect_warning(movie <- read_dtm(tf), NA)
    expect_identical(n_frames(movie), 1L)
    expect_identical(movie$header$inputCount, as.character(declared))
    expect_identical(movie$header$availablePollCount, "1")
    expect_identical(movie$header$pollCountDifference, as.character(declared - 1L))
    expect_identical(movie$header$inputCountRole, "emulator input statistic")
    expect_true(player(movie)[1L, "A"])
  }
  bytes[22:25] <- writeBin(1L, raw(), size = 4L, endian = "little")
  second <- bytes[257:264]
  second[1L] <- as.raw(4L)
  writeBin(c(bytes, second), tf)
  expect_warning(movie <- read_dtm(tf), NA)
  expect_identical(n_frames(movie), 2L)
  expect_true(player(movie)[2L, "B"])
  writeBin(head(bytes, -1L), tf)
  expect_error(read_dtm(tf), "partial final DTM poll")
})

.mk_zelda_dtm <- function(controller_mask = 1L, known_revision = TRUE) {
  tf <- .mk_dtm(2L, controller_mask)
  hdr <- readBin(tf, "raw", n = 256L)
  hdr[22] <- as.raw(4L)
  if (known_revision) {
    revision <- "a6e66c227c592d09ff09ef9b238d15ff52dd9632"
    hdr[210:229] <- as.raw(strtoi(substring(revision, seq(1, 39, 2), seq(2, 40, 2)), 16L))
  }
  record <- function(word, left_x, left_y, right_x, right_y, event, x, z) {
    c(as.raw(c(bitwAnd(word, 255L), bitwShiftR(word, 8L), 0, 255,
               left_x, left_y, right_x, right_y, event)),
      writeBin(c(x, z), raw(), size = 4L, endian = "little"))
  }
  body <- c(record(16386L, 192, 128, 128, 192, 3, 1.25, -2.5),
            record(4L, 128, 192, 64, 128, 0, -128.5, 256.25),
            record(32776L, 64, 128, 128, 64, 255, 0, 4096.5),
            record(49168L, 128, 64, 192, 128, 1, -0.25, 0))
  writeBin(c(hdr, body), tf)
  tf
}

test_that("Zelda Edition imports source controls and typed extra poll fields", {
  tf <- .mk_zelda_dtm()
  on.exit(unlink(tf))
  body <- readBin(tf, "raw", n = file.info(tf)$size)[-(1:256)]
  expected <- data.frame(loading = c(TRUE, FALSE, FALSE, TRUE),
                         tuner_event = c(3L, 0L, 255L, 1L),
                         link_x = c(1.25, -128.5, 0, -0.25),
                         link_z = c(-2.5, 256.25, 4096.5, 0))
  for (mode in c("raw", "cardinal4", "cardinal8", "angle", "angle+magnitude")) {
    movie <- read_movie(tf, analog = mode)
    expect_s3_class(movie, "replayr_movie")
    expect_identical(n_frames(movie), 4L)
    expect_identical(movie$header$dtmVariant, "zelda")
    expect_identical(movie$header$bytesPerPoll, "17")
    expect_identical(movie$poll_fields, expected)
    expect_identical(as.vector(t(movie$poll_bytes)), body)
    expect_equal(player(movie)[, c("A", "B", "x", "y")], unname(diag(TRUE, 4)), ignore_attr = TRUE)
    expect_equal(unname(analog_channels(movie)[, 3:6]),
                 rbind(c(192, 128, 128, 192), c(128, 192, 64, 128),
                       c(64, 128, 128, 64), c(128, 64, 192, 128)))
    if (mode %in% c("angle", "angle+magnitude")) {
      expect_equal(stick_channels(movie)[, "left_angle"], c(0, 90, 180, 270))
      expect_equal(stick_channels(movie)[, "right_angle"], c(90, 180, 270, 0))
    }
  }
  expect_error(read_dtm(tf, dtm_variant = "standard"), "partial final DTM poll")
  bytes <- readBin(tf, "raw", n = file.info(tf)$size)
  bytes[12] <- as.raw(3L)
  writeBin(bytes, tf)
  stream <- read_dtm(tf)
  expect_s3_class(stream, "replayr_poll_stream")
  data <- polls(stream)
  expect_identical(data[names(expected)], expected)
  expect_false(any(c("is_connected", "get_origin") %in% names(data)))
  grouped <- read_dtm(tf, controller_order = c(2L, 1L))
  expect_identical(n_frames(grouped), 2L)
  expect_identical(grouped$poll_fields, expected)
  expect_true(player(grouped, 1L)[1L, "B"])
  expect_true(player(grouped, 2L)[1L, "A"])
  expect_identical(as.vector(t(grouped$poll_bytes)), body)
  writeBin(head(bytes, -1L), tf)
  expect_error(read_dtm(tf), "partial final DTM poll")
})

test_that("DTM layout is selected from source evidence rather than divisibility", {
  tf <- .mk_zelda_dtm(known_revision = FALSE)
  on.exit(unlink(tf))
  expect_error(read_dtm(tf), "partial final DTM poll for standard")
  movie <- read_dtm(tf, dtm_variant = "zelda")
  expect_identical(movie$header$dtmVariant, "zelda")
  expect_identical(movie$poll_fields$link_x, c(1.25, -128.5, 0, -0.25))
  expect_error(read_dtm(tf, dtm_variant = "unknown"), "arg")
  # An empty known-layout recording has correctly typed, zero-length fields.
  bytes <- readBin(tf, "raw", n = 256L)
  bytes[22:29] <- raw(8L)
  writeBin(bytes, tf)
  empty <- read_dtm(tf, dtm_variant = "zelda")
  expect_identical(dim(empty$poll_bytes), c(0L, 17L))
  expect_identical(nrow(empty$poll_fields), 0L)
})

test_that("the article fixture contains a moving right stick with known values", {
  path <- fixture_path("sample.dtm")
  raw_movie <- read_dtm(path)
  xy <- analog_channels(raw_movie)
  anchors <- c(1L, 901L, 1801L, 2701L)
  expect_equal(unname(xy[anchors, "rstick_x"]), c(128, 198, 128, 58))
  expect_equal(unname(xy[, "rstick_y"]), rep(128, 3600))
  for (mode in c("cardinal4", "cardinal8", "angle", "angle+magnitude")) {
    movie <- read_dtm(path, analog = c(left = "angle", right = mode))
    channels <- stick_channels(movie)
    field <- if (startsWith(mode, "cardinal")) "right_direction" else "right_angle"
    expect_equal(unname(channels[anchors, field]), c(NA, 0, NA, 180))
    expect_identical(analog_channels(movie), xy)
    if (mode == "angle+magnitude")
      expect_equal(unname(channels[anchors, "right_magnitude"]), c(0, 70/128, 0, 70/128))
  }
})
