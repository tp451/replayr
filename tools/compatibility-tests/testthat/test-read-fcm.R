test_that('documented Crystalis wild warps retain their cross-controller chord', {
  fp <- external_fixture('raw_nes/crystalis/348.fcm')
  mv <- replayr:::.decode_fcm(fp)
  # Publication 348 uses the P1 A+B / P2 A shortcut for its wild warps.
  expect_equal(sum(mv$inputs[, 1, 7] & mv$inputs[, 1, 8] & mv$inputs[, 2, 8]), 64L)
})

test_that("replayr:::.decode_fcm() parses a published version-1 movie", {
  fp <- external_fixture("raw_nes/power_blade/193.fcm")
  mv <- replayr:::.decode_fcm(fp)
  expect_equal(mv$header[["version"]], "1")
  expect_equal(n_observations(mv), 61842L)
  pc <- press_counts(mv, 1L)
  expect_true(all(pc <= n_observations(mv)))
  expect_gt(sum(pc), 0L)
})

