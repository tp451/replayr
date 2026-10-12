warning_source_file <- function(format, body, count, mask=1L, revision=NULL) {
  h<-raw(if(format=="m64")1024L else 256L)
  h[1:4]<-charToRaw(paste0(toupper(format),"\x1a"))
  if(format=="m64") {
    h[5]<-as.raw(3);h[21]<-as.raw(60);h[22]<-as.raw(1);h[33]<-as.raw(mask)
    h[25:28]<-writeBin(as.integer(count),raw(),size=4,endian="little")
  } else {
    h[5:10]<-charToRaw("TEST01");h[11]<-as.raw(as.integer(mask>=16L));h[12]<-as.raw(mask)
    h[22:29]<-as.raw(floor(count/256^(0:7))%%256)
    if(!is.null(revision)) h[210:229]<-as.raw(strtoi(substring(revision,seq(1,39,2),seq(2,40,2)),16L))
  }
  path<-tempfile(fileext=paste0(".",format));writeBin(c(h,as.raw(body)),path);path
}

test_that("M64 zero sample counts do not turn unused bytes into gameplay", {
  for(tail in list(raw(),as.raw(c(128,0,127,128)),as.raw(c(255,0,127,128,7)))) {
    path<-warning_source_file("m64",tail,0);on.exit(unlink(path),add=TRUE)
    expect_warning(m<-read_m64(path),NA)
    expect_identical(n_frames(m),0L)
    expect_equal(nrow(m$poll_bytes),0)
    expect_identical(m$source_tail,tail)
    expect_identical(m$header$declaredInputSampleCount,"0")
  }
})

test_that("M64 terminal and stale suffix bytes are preserved outside playback", {
  first<-c(128,0,127,128);suffix<-c(64,0,7,249,255,13,10)
  path<-warning_source_file("m64",c(first,suffix),1);on.exit(unlink(path))
  expect_warning(m<-read_m64(path),NA)
  expect_identical(n_frames(m),1L)
  expect_true(player(m)[1,"A"]);expect_false(player(m)[1,"B"])
  expect_identical(m$source_tail,as.raw(suffix))
  expect_identical(c(as.vector(t(m$poll_bytes)),m$source_tail),as.raw(c(first,suffix)))
})

test_that("Wii and mixed DTM statistics do not truncate or extend polls", {
  for(count in c(0L,1L,8L)) {
    wii<-warning_source_file("dtm",c(4,161,48,0,8),count,16L)
    on.exit(unlink(wii),add=TRUE)
    expect_warning(m<-read_dtm(wii),NA)
    expect_identical(n_frames(m),1L)
    expect_identical(m$header$inputCount,as.character(count))
    expect_identical(m$header$pollCountDifference,as.character(count-1L))
    mixed<-warning_source_file("dtm",c(2,64,0,0,128,128,128,128,3,48,0,8),count,17L,
      "7eb02ecfa452578d9596501cc097d26b80a15931")
    on.exit(unlink(mixed),add=TRUE)
    expect_warning(m<-read_dtm(mixed),NA)
    expect_identical(n_frames(m),2L)
    expect_identical(m$header$pollCountDifference,as.character(count-2L))
  }
})

test_that("Wii damaged reports identify source locations without inventing controls", {
  # Original extended-IR values: x=400/500/390/510, y=300, size=10.
  ir<-c(144,44,90,244,44,90,134,44,90,254,44,90)
  overwritten<-c(rep(255,7),ir)
  body<-c(4,161,48,0,8,19,overwritten,7,rep(0,7),7,10)
  path<-warning_source_file("dtm",body,3,16L,"ac267a29405ae768037a8774b84b805a4180d1af")
  on.exit(unlink(path))
  warnings<-character()
  m<-withCallingHandlers(read_dtm(path),warning=function(w) {
    warnings<<-c(warnings,conditionMessage(w));invokeRestart("muffleWarning")
  })
  expect_equal(length(warnings),2)
  expect_true(any(grepl("incomplete final Wii poll",warnings)))
  expect_true(any(grepl("unrecognised Wii reports",warnings)))
  expect_identical(m$poll_fields$valid_report,c(TRUE,FALSE,FALSE))
  expect_identical(m$poll_fields$report_issue,c(NA_character_,"legacy_tas_ir_overwrite_pattern","zero_filled_report"))
  expect_equal(m$poll_fields$source_offset,c(256,261,281))
  expect_false(any(m$inputs[2:3,,,drop=FALSE]))
  expect_identical(m$source_tail,as.raw(c(7,10)))
  restored<-unlist(lapply(seq_len(n_frames(m)),function(i)c(as.raw(m$poll_lengths[i]),m$poll_bytes[i,seq_len(m$poll_lengths[i])])),use.names=FALSE)
  expect_identical(c(restored,m$source_tail),as.raw(body))
  # A matching byte pattern in an unidentified build remains a generic invalid report.
  b<-readBin(path,"raw",file.info(path)$size);b[210:229]<-raw(20);writeBin(b,path)
  m<-suppressWarnings(read_dtm(path))
  expect_identical(m$poll_fields$report_issue[2],"invalid_hid_report")
})
