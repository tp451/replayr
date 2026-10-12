test_that("external Doom and Boom demos preserve their tic commands", {
  # Header versions identify these formats; the folder name is not reliable.
  cases <- list(
    list("barrel_assist.lmp", 202L, 353L),
    list("barrel_chain.lmp", 202L, 140L),
    list("cl01-022.lmp", 109L, 815L),
    list("crusher.lmp", 202L, 151L),
    list("damage.lmp", 202L, 93L)
  )
  for (case in cases) {
    f <- external_fixture(file.path("doom_demos/lmp/extended", case[[1L]]))
    mv <- read_lmp(f)
    expect_identical(mv$header$version, as.character(case[[2L]]))
    expect_equal(n_frames(mv), case[[3L]], info = case[[1L]])
    expect_identical(mv$header$enabledPorts, 1L)

    # Both layouts store signed movement bytes followed by button bits.
    # Boom 2.02 has a 109-byte header; Doom 1.9 has a 13-byte header.
    header_size <- if (case[[2L]] == 202L) 109L else 13L
    bytes <- readBin(f, "raw", n = file.info(f)$size)
    body <- bytes[header_size + seq_len(4L * case[[3L]])]
    wire <- matrix(as.integer(body), ncol = 4L, byrow = TRUE)
    movement <- wire[, 1:3, drop = FALSE]
    movement[movement >= 128L] <- movement[movement >= 128L] - 256L
    expect_equal(unname(analog_channels(mv, 1L)), movement)
    expect_identical(as.vector(t(mv$source_packets)), body)
    expect_identical(bytes[header_size + length(body) + 1L], as.raw(0x80))
    special <- bitwAnd(wire[, 4L], 0x80L) != 0L
    expect_identical(mv$commands, ifelse(special, wire[, 4L], 0L))
    expect_identical(unname(player(mv, 1L)[, match("a", mv$button_keys)]),
      !special & bitwAnd(wire[, 4L], 1L) != 0L)
    expect_identical(unname(player(mv, 1L)[, match("b", mv$button_keys)]),
      !special & bitwAnd(wire[, 4L], 2L) != 0L)
  }
})

test_that("read_lmp parses a vanilla Doom demo into the standard movie shape", {
  f <- external_fixture("doom_demos/lmp/doom-demo1.lmp")
  mv <- replayr:::.decode_lmp(analog = "quantized", f)
  expect_s3_class(mv, "replayr_movie")
  expect_equal(n_frames(mv), 1710L)
  expect_identical(mv$header[["_format"]], "lmp")
  # Skill must be a stringified 0..4
  expect_true(as.integer(mv$header$skill) %in% 0:4,
    info = paste("file:", basename(f))
  )
  # inputs is (n_frames, 4, 8) -- 4 player slots, 8-button NES-shape
  expect_equal(dim(mv$inputs)[2], 4L)
  expect_equal(dim(mv$inputs)[3], 8L)
  # forwardmove / sidemove / angleturn matrices are n_frames x 4
  expect_equal(dim(mv$header$forwardmove)[2], 4L)
  expect_equal(nrow(mv$header$forwardmove), n_frames(mv))
})

