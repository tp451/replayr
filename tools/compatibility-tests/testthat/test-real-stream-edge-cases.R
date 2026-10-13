test_that('whole-corpus edge-case originals decode without dropping records', {
  cases <- list(
    list('raw_genesis/tiny_toon_adventures_buster_s_hidden_treasure/1094.gmv', 'gmv', NULL),
    list('raw_nes/tmnt_1/4543.bk2', 'bk2', NULL),
    list('raw_nes/zelda_2/4367.bk2', 'bk2', NULL),
    list('raw_nes/circus_charlie/755.fcm', 'fcm', 12161L),
    list('raw_nes/super_mario_bros_2_usa/960.fcm', 'fcm', 31394L),
    list('raw_snes/aladdin/791.smv', 'smv', 56837L),
    list('raw_snes/mega_man_x/725.smv', 'smv', 107874L),
    list('raw_snes/super_mario_rpg_legend_of_the_seven_stars/308.smv', 'smv', 639262L),
    list('raw_gc/luigi_s_mansion/3090.dtm', 'dtm', 195700L),
    list('raw_psx/klonoa_door_to_phantomile/2396.pjm', 'pjm', 163548L),
    list('raw_psx/medievil/1832.pjm', 'pjm', 156741L),
    list('raw_psx/spyro_year_of_the_dragon/2711.pjm', 'pjm', 532449L)
  )
  for (case in cases) {
    fp <- external_fixture(case[[1]])
    mv <- suppressWarnings(get(paste0('read_', case[[2]]))(fp))
    expect_gt(n_observations(mv), 0L)
    if (!is.null(case[[3]])) expect_equal(n_observations(mv), case[[3]], info = case[[1]])
    if (case[[2]] == 'pjm') expect_gt(as.integer(mv$header$allNulRecordCount), 0L)
  }
})

