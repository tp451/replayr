make_native_mixed_dtm <- function(records, revision, mask=17L) {
  h<-raw(256);h[1:4]<-as.raw(c(68,84,77,26));h[5:10]<-charToRaw('TEST01')
  h[11]<-as.raw(1);h[12]<-as.raw(mask);h[22:29]<-as.raw(floor(length(records)/256^(0:7))%%256)
  h[210:229]<-as.raw(strtoi(substring(revision,seq(1,39,2),seq(2,40,2)),16L))
  path<-tempfile(fileext='.dtm');writeBin(c(h,as.raw(unlist(records))),path);path
}

test_that('verified native mixed records include disconnected GameCube commands', {
  gc<-c(0,64,0,0,128,128,128,128)
  origin<-c(2,192,12,34,255,128,128,255)
  wii<-c(3,48,0,8)
  disconnected<-lapply(c(0,16,32,48),function(flag)c(0,flag,rep(0,6)))
  records<-c(list(gc,wii,origin),disconnected,list(wii))
  for(revision in .dtm_native_mixed_revisions) {
    path<-make_native_mixed_dtm(records,revision,19L)
    m<-read_dtm(path,analog='angle+magnitude');unlink(path)
    expect_identical(m$header$dtmVariant,'mixed-hid-nomarker')
    expect_identical(m$header$sourceRevision,revision)
    expect_null(m$header$framingAssumption)
    expect_match(m$header$framingRule,'native GameCube')
    expect_identical(polls(m)$device,c('gc','wii','gc',rep('gc',4),'wii'))
    expect_identical(polls(m)$physical_port,c(NA_integer_,1L,rep(NA_integer_,5),1L))
    expect_identical(polls(m)$gc_connected,c(TRUE,NA,TRUE,rep(FALSE,4),NA))
    expect_identical(polls(m)$gc_get_origin,c(FALSE,NA,TRUE,rep(FALSE,4),NA))
    expect_identical(m$commands,c(0L,0L,0L,0L,1L,2L,3L,0L))
    expect_identical(polls(m)$a,c(FALSE,TRUE,TRUE,rep(FALSE,4),TRUE))
    expect_equal(m$header$inputCount,nrow(polls(m)))
    expect_equal(m$header$pollCountDifference,'0')
    expect_identical(m$poll_lengths,as.integer(lengths(records)))
    reconstructed<-as.raw(unlist(lapply(seq_along(records),function(i)m$poll_bytes[i,seq_len(m$poll_lengths[i])])))
    expect_identical(reconstructed,as.raw(unlist(records)))
    expect_true(all(is.na(stick_channels(m)[4:7,,drop=FALSE])))
    expect_equal(unname(analog_channels(m)[3,c('ltrigger','rtrigger','lstick_x','lstick_y')]),c(12,34,255,128))
  }
})

test_that('native mixed framing rejects noncanonical and truncated records', {
  rev<-.dtm_native_mixed_revisions[1]
  for(record in list(c(1,0,rep(0,6)),c(0,0,1,rep(0,5)),c(0,1,rep(0,6)),
                     c(4,48,0,8,0),c(3,48,0),c(0,64,rep(0,5)))) {
    path<-make_native_mixed_dtm(list(record),rev)
    expect_error(read_dtm(path),'invalid HID|incomplete mixed');unlink(path)
  }
  # An unknown revision requires the caller to select the source format.
  path<-make_native_mixed_dtm(list(c(0,0,rep(0,6)),c(3,48,0,8)),strrep('0',40))
  on.exit(unlink(path))
  expect_error(read_dtm(path),'verified Dolphin revision')
  m<-read_dtm(path,wii_variant='mixed-hid-nomarker')
  expect_identical(polls(m)$gc_connected,c(FALSE,NA))
})

test_that('historical mixed HID marker remains independently recognised', {
  revision<-'7804f388aeb075266ae8c363e0932c355ba6ed5e'
  records<-list(c(2,0,0,0,128,128,128,128),c(4,161,48,0,8))
  path<-make_native_mixed_dtm(records,revision);on.exit(unlink(path))
  m<-read_dtm(path)
  expect_identical(m$header$dtmVariant,'mixed-hid')
  expect_identical(m$poll_lengths,c(8L,5L))
  expect_identical(polls(m)$device,c('gc','wii'))
  expect_true(all(polls(m)$a))
  expect_true(all(is.na(polls(m)$gc_connected)))
  expect_equal(sum(m$poll_lengths),sum(lengths(records)))
})
