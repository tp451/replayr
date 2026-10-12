legacy_fixture <- function(name) system.file('extdata','legacy',name,package='replayr',mustWork=TRUE)
legacy_read <- function(name) {
  ext <- tools::file_ext(name)
  raw <- get(paste0('.decode_',ext))(legacy_fixture(name))
  movie <- .configure_movie(raw)
  # Verify public layout identities, then inspect in source-field order.
  source_order <- match(raw$decoded_layout$key,movie$button_keys)
  expect_equal(unname(movie$inputs[,,source_order,drop=FALSE]),unname(raw$inputs))
  movie$inputs <- movie$inputs[,,source_order,drop=FALSE]
  movie$button_keys <- movie$button_keys[source_order]
  movie$button_ids <- movie$button_ids[source_order]
  movie$button_names <- movie$button_names[source_order]
  movie$button_mnemonics <- movie$button_mnemonics[source_order]
  movie$control_layout <- movie$control_layout[source_order,,drop=FALSE]
  movie
}

test_that('FMV ports, independent buttons, and FDS bytes retain their meaning', {
  m <- legacy_read('buttons.fmv')
  expect_equal(m$header$controllerPorts,1:2)
  expect_equal(m$commands,c(0L,1L,2L,0L,1L,2L,0L,1L))
  expect_equal(button_layout(m)$key,c('dpad_right','dpad_left','dpad_up','dpad_down','b','a','select','start'))
  expect_equal(unname(m$inputs[,1,]),diag(8)==1)
  expect_equal(unname(m$inputs[,2,]),(diag(8)==1)[8:1,])
})

test_that('MMV distinguishes Game Gear Start and Master System Pause', {
  sms <- legacy_read('sms.mmv'); old <- legacy_read('sms-old.mmv'); gg <- legacy_read('gg.mmv')
  expect_equal(sms$inputs,old$inputs)
  expect_equal(n_players(sms),2L); expect_equal(n_players(gg),1L)
  expect_true(sms$inputs[7,1,7]); expect_false(sms$inputs[8,1,7])
  expect_false(gg$inputs[7,1,7]); expect_true(gg$inputs[8,1,7])
  expect_equal(sms$button_names[5:7],c('1','2','Pause'))
  expect_equal(dim(gg$source_packets),c(8L,2L))
})

test_that('DSM preserves Select/Start positions and stylus, mic, and lid channels', {
  for (version in 1:2) {
    m <- legacy_read(paste0('touch-v',version,'.dsm')); keys <- button_layout(m)$key
    expect_true(m$inputs[1,1,match('select',keys)]); expect_false(m$inputs[1,1,match('start',keys)])
    expect_true(m$inputs[2,1,match('start',keys)]); expect_false(m$inputs[2,1,match('select',keys)])
    expect_equal(analog_channels(m)[,'touch_x'],seq(20,170,30))
    expect_equal(analog_channels(m)[,'touch_y'],seq(10,110,20))
    expect_equal(m$inputs[,1,match('touch',keys)],c(TRUE,TRUE,TRUE,TRUE,FALSE,FALSE))
    expect_equal(which(m$inputs[,1,match('microphone',keys)]),3L)
    expect_equal(which(m$inputs[,1,match('lid_closed',keys)]),4L)
    expect_equal(m$commands,c(0L,0L,1L,4L,2L,0L))
    if (version==2) expect_equal(analog_channels(m)[,'microphone_sample'],0:5)
  }
  binary <- legacy_read('touch-binary.dsm')
  expect_equal(analog_channels(binary)[,'touch_x'],c(40L,60L))
  expect_equal(binary$commands,c(1L,4L))
  expect_true(binary$inputs[1,1,5]); expect_true(binary$inputs[2,1,6])
})

test_that('MC2 differentiates PC Engine and Virtual Boy dual directional pads', {
  pce <- legacy_read('pce.mc2'); vb <- legacy_read('vboy.mc2')
  expect_equal(n_players(pce),2L)
  expect_equal(unname(pce$inputs[,1,]),diag(8)==1)
  expect_false(any(pce$inputs[,2,]))
  expect_equal(unname(vb$inputs[,1,]),diag(14)==1)
  expect_equal(button_layout(vb)$key[c(1,2,9,10)],c('vboy_right_down','vboy_right_left','vboy_right_right','vboy_right_up'))
  b <- legacy_read('pce-binary.mc2')
  expect_true(b$inputs[1,1,1]); expect_true(b$inputs[1,2,8])
  expect_true(b$inputs[2,1,5]); expect_true(b$inputs[2,2,6])
})

test_that('YMV maps all thirteen Saturn positions and binary records', {
  m <- legacy_read('saturn.ymv')
  expect_equal(unname(m$inputs[,1,]),diag(13)==1)
  expect_equal(button_layout(m)$key,c('dpad_left','dpad_right','dpad_up','dpad_down','start','a','b','c','x','y','z','l1','r1'))
  b <- legacy_read('saturn-binary.ymv')
  expect_true(b$inputs[1,1,1]);expect_true(b$inputs[2,1,13])
})

test_that('MCM preserves ports and platform-specific button bits', {
  expected <- list(pce=c(5L,13L),lynx=c(1L,9L),wswan=c(1L,11L),ngp=c(1L,7L),pcfx=c(2L,12L),sms=c(2L,7L),nes=c(4L,8L))
  for (system in names(expected)) {
    m <- legacy_read(paste0(system,'.mcm')); n <- expected[[system]][2]
    expect_equal(n_players(m),expected[[system]][1])
    expect_equal(unname(m$inputs[seq_len(n),1,]),diag(n)==1)
    if(n_players(m)>1L) expect_false(any(m$inputs[,2:n_players(m),]))
  }
  expect_equal(button_layout(legacy_read('lynx.mcm'))$key[3:4],c('lynx_option_2','lynx_option_1'))
})

test_that('legacy readers reject malformed fields and preserve incomplete binary tails', {
  f <- tempfile(); on.exit(unlink(f))
  writeLines(c('version 1','ports 1','|0|......|'),f)
  expect_error(.decode_mc2(f),'record width')
  writeLines(c('version 1','|0|.............bad|'),f)
  expect_error(.decode_dsm(f),'touch')
  writeLines(c('version 1','|0|LRUDSABCXYZWE'),f)
  expect_error(.decode_ymv(f),'truncated')
  for (ext in c('fmv','mmv','mcm')) {
    name <- switch(ext,fmv='buttons.fmv',mmv='sms.mmv',mcm='pce.mcm')
    raw <- readBin(legacy_fixture(name),'raw',n=file.info(legacy_fixture(name))$size)
    writeBin(c(raw,as.raw(99)),f)
    expect_warning(m <- get(paste0('.decode_',ext))(f),'incomplete frame')
    expect_equal(m$source_tail,as.raw(99))
    writeBin(raw[1:12],f)
    expect_error(get(paste0('.decode_',ext))(f),'not an')
  }
})


test_that('DSM accepts adjacent records without a line separator', {
  f <- tempfile(fileext='.dsm'); on.exit(unlink(f))
  records <- c('|0|R............000 000 0|', '|3|.....S.......108 124 1|')
  for (separator in c('', ' ', '\t', '\r\n')) {
    writeBin(charToRaw(paste0('version 1\n', paste(records, collapse=separator))), f)
    m <- .configure_movie(.decode_dsm(f))
    expect_identical(n_frames(m), 2L)
    expect_identical(m$commands, c(0L, 3L))
    expect_equal(unname(analog_channels(m)), matrix(c(0,0,0,108,124,1), ncol=3, byrow=TRUE))
    expect_identical(unname(m$inputs[,1,match('dpad_right',m$button_keys)]),c(TRUE,FALSE))
    expect_identical(unname(m$inputs[,1,match('start',m$button_keys)]),c(FALSE,TRUE))
    expect_identical(unname(m$inputs[,1,match('touch',m$button_keys)]),c(FALSE,TRUE))
  }
})


test_that('DSM detects microphone samples from stored fields', {
  f <- tempfile(fileext='.dsm'); on.exit(unlink(f))
  for (version in c(1L,2L)) {
    writeLines(c(paste('version',version), '|1|.............108 124 1 073|',
                 '|0|.......A.....000 000 0|', '|1|.............000 000 0 211|'),f)
    m <- .configure_movie(.decode_dsm(f))
    expect_identical(n_frames(m),3L)
    expect_identical(m$commands,c(1L,0L,1L))
    expect_equal(analog_channels(m)[,'microphone_sample'],c(73,NA,211))
    expect_equal(unname(analog_channels(m)[,1:3]),matrix(c(108,124,1,0,0,0,0,0,0),ncol=3,byrow=TRUE))
    expect_true(m$header$microphoneSampleStored)
  }
  writeLines(c('version 1','|0|.............000 000 0 nope|'),f)
  expect_error(.decode_dsm(f),'numeric channel')
})
