test_that('pre-TEST9 GMV retains recorded bits without invented pad metadata', {
  hdr<-raw(64);hdr[1:16]<-charToRaw('Gens Movie TEST6')
  tf<-tempfile(fileext='.gmv');on.exit(unlink(tf))
  writeBin(c(hdr,as.raw(c(239,255,254))),tf)
  mv<-replayr:::.decode_gmv(tf)
  expect_identical(which(mv$inputs[1,1,]),c(8L,9L))
  expect_identical(mv$header$p1PadType,'unspecified')
  expect_identical(mv$header$fps,'')
})

test_that('localized and empty NES LogKeys retain their actual columns', {
  hdr<-list(Platform='NES',Core='NesHawk')
  keys<-paste0('LogKey:#\u7535\u6e90|\u91cd\u8bbe|#P1 \u2191|P1 \u2193|P1 \u2190|P1 \u2192|',
               'P1 \u5f00\u59cb|P1 \u9009\u62e9|P1 B|P1 A|#P2 Up|P2 Down|P2 Left|P2 Right|P2 Start|P2 Select|P2 B|P2 A|')
  log<-paste(keys,'|..|U...S...|........|',sep='\r\r\n')
  mv<-.parse_bk2_input_log(analog = "quantized", log,hdr)
  expect_identical(which(mv$inputs[1,1,]),c(4L,5L))
  empty<-paste('LogKey:','|..|U...S...|........|',sep='\r\r\n')
  expect_identical(.parse_bk2_input_log(analog = "quantized", empty,hdr)$inputs,mv$inputs)
  expect_error(.parse_bk2_input_log(analog = "quantized", empty,list(Platform='PSX')),'verified NES')
  expect_error(.parse_bk2_input_log(analog = "quantized", 'LogKey:\n|..|......|........|',hdr),'verified NES')
})

test_that('overstated FCM byte length requires complete records and duration', {
  hdr<-raw(56);hdr[1:4]<-charToRaw('FCM\x1a');hdr[5]<-as.raw(2)
  hdr[13]<-as.raw(10);hdr[21]<-as.raw(6);hdr[29]<-as.raw(56)
  tf<-tempfile(fileext='.fcm');on.exit(unlink(tf))
  writeBin(c(hdr,as.raw(c(32,10))),tf)
  expect_warning(mv<-replayr:::.decode_fcm(tf),'complete records cover')
  expect_equal(n_frames(mv),10L)
  expect_false(any(mv$inputs[,1,8])) # A changes only at the end of the ten-frame wait
  writeBin(c(hdr,as.raw(c(32,9))),tf)
  expect_error(replayr:::.decode_fcm(tf),'does not cover')
  writeBin(c(hdr,as.raw(32)),tf)
  expect_error(replayr:::.decode_fcm(tf),'truncated FCM delta')
  hdr[21]<-as.raw(1);writeBin(c(hdr,as.raw(c(32,10))),tf)
  expect_warning(mv<-replayr:::.decode_fcm(tf),'complete final delta')
  expect_identical(mv$header$terminalDeltaBytesBeyondHeader,'1')
  expect_false(any(mv$inputs[,1,8]))
  writeBin(c(hdr,as.raw(c(32,9))),tf)
  expect_error(replayr:::.decode_fcm(tf),'does not complete')
})

test_that('whole-corpus edge-case originals decode without dropping records', {
  cases<-list(
    list('raw_genesis/tiny_toon_adventures_buster_s_hidden_treasure/1094.gmv','gmv',NULL),
    list('raw_nes/tmnt_1/4543.bk2','bk2',NULL),
    list('raw_nes/zelda_2/4367.bk2','bk2',NULL),
    list('raw_nes/circus_charlie/755.fcm','fcm',12161L),
    list('raw_nes/super_mario_bros_2_usa/960.fcm','fcm',31394L),
    list('raw_snes/aladdin/791.smv','smv',56837L),
    list('raw_snes/mega_man_x/725.smv','smv',107874L),
    list('raw_snes/super_mario_rpg_legend_of_the_seven_stars/308.smv','smv',639262L),
    list('raw_gc/luigi_s_mansion/3090.dtm','dtm',195700L),
    list('raw_psx/klonoa_door_to_phantomile/2396.pjm','pjm',163548L),
    list('raw_psx/medievil/1832.pjm','pjm',156741L),
    list('raw_psx/spyro_year_of_the_dragon/2711.pjm','pjm',532449L))
  for(case in cases) {
    fp<-external_fixture(case[[1]])
    if(is.null(fp))skip('set REPLAYR_FIXTURE_DIR for real-file edge cases')
    mv<-suppressWarnings(get(paste0('read_',case[[2]]))(fp))
    expect_gt(n_frames(mv),0L)
    if(!is.null(case[[3]]))expect_equal(n_frames(mv),case[[3]],info=case[[1]])
    if(case[[2]]=='pjm')expect_gt(as.integer(mv$header$allNulRecordCount),0L)
  }
})
