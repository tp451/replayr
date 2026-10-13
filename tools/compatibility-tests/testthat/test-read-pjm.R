test_that("replayr:::.decode_pjm() parses real two-controller / analog / binary movies", {
  cases <- list(
    list("raw_psx/metal_gear_solid/2003.pjm", 2L), # 34-byte 2-port text
    list("raw_psx/spyro_2_ripto_s_rage/2603.pjm", 2L), # 52-byte analog text
    list("raw_psx/mega_man_x4/2032.pjm", 2L) # two configured digital ports
  )
  for (cs in cases) {
    fp <- external_fixture(cs[[1]])
    mv <- replayr:::.decode_pjm(analog = "quantized", fp)
    expect_s3_class(mv, "replayr_movie")
    expect_equal(mv$header[["_format"]], "pjm")
    expect_equal(n_players(mv), cs[[2]])
    expect_gt(n_observations(mv), 0L)
    expect_equal(n_buttons(mv), 42L)
    pc <- press_counts(mv, 1L)
    expect_true(all(pc <= n_observations(mv))) # nothing stuck above 100%
    expect_gt(sum(pc), 0L)
  }
})

