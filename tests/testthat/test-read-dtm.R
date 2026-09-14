test_that("read_dtm() parses the bundled synthetic GameCube movie", {
  mv <- read_dtm(fixture_path("sample.dtm"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "dtm")
  expect_equal(n_frames(mv), 3600L)
  expect_equal(n_players(mv), 1L)
  expect_equal(n_buttons(mv), 28L)
  expect_gt(sum(press_counts(mv, 1L)[21:28]), 0L)
})

test_that("read_dtm() parses an optional external GameCube movie", {
  fp <- external_fixture("raw_gc/luigis_mansion/2587.dtm")
  if (is.null(fp)) skip("set REPLAYR_FIXTURE_DIR to enable DTM test")
  mv <- read_dtm(fp)
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

test_that("read_dtm() uses packed button bits and preserves commands", {
  tf <- .mk_dtm(bitwOr(bitwShiftL(1L, 1L), bitwShiftL(1L, 13L)))
  on.exit(unlink(tf))
  mv <- read_dtm(tf)
  expect_equal(n_frames(mv), 1L)
  expect_true(mv$inputs[1L, 1L, 8L])
  expect_equal(mv$commands, 2L)
})

test_that("read_dtm() rejects ambiguous multiplayer poll streams", {
  tf <- .mk_dtm(0L, controller_mask = 3L)
  on.exit(unlink(tf))
  expect_error(read_dtm(tf), "multi-controller")
})

test_that('DTM accepts only an explicit complete repeating controller order', {
  tf<-.mk_dtm(2L,controller_mask=3L);on.exit(unlink(tf))
  b<-readBin(tf,'raw',n=file.info(tf)$size)
  b[22]<-as.raw(2L)
  other<-b[257:264];other[1]<-as.raw(4L)
  writeBin(c(b,other),tf)
  mv<-read_dtm(tf,controller_order=c(1L,2L))
  expect_equal(n_players(mv),2L)
  expect_equal(n_frames(mv),1L)
  expect_true(mv$inputs[1,1,8])
  expect_false(mv$inputs[1,1,7])
  expect_true(mv$inputs[1,2,7])
  expect_match(mv$header$controllerAssignment,'caller-supplied')
  swapped<-read_dtm(tf,controller_order=c(2L,1L))
  expect_true(swapped$inputs[1,2,8])
  expect_error(read_dtm(tf,controller_order=c(1,1)),'every enabled port')
  expect_error(read_dtm(tf,controller_order=c(1,3)),'every enabled port')
  b[22]<-as.raw(1L);writeBin(b,tf)
  expect_error(read_dtm(tf,controller_order=c(1,2)),'incomplete')
})

test_that('DTM records a bounded complete-poll shortfall without fabricated inputs', {
  tf<-.mk_dtm(2L);on.exit(unlink(tf))
  bytes<-readBin(tf,'raw',n=file.info(tf)$size);bytes[22]<-as.raw(3)
  writeBin(bytes,tf)
  expect_warning(mv<-read_dtm(tf),'no input invented')
  expect_equal(n_frames(mv),1L)
  expect_identical(mv$header$trailingPollShortfall,'2')
  bytes[22]<-as.raw(4);writeBin(bytes,tf)
  expect_error(read_dtm(tf),'truncated DTM')
  writeBin(head(bytes,-1L),tf)
  expect_error(read_dtm(tf),'partial final')
})
