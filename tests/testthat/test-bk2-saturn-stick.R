saturn_stick_wire <- function() {
  # Original inputs: neutral, cardinal/diagonal, deadzone boundaries, and
  # the byte-cast boundary used by SaturnusControllerDeck.UpdateAnalogs.
  xy <- rbind(c(128,128), c(192,128), c(192,64), c(128,64), c(64,128),
              c(128,192), c(159,128), c(160,128), c(255,128), c(256,128))
  rows <- apply(xy, 1, function(row)
    paste0('|..|', row[1], ',', row[2], ',32,224,A.|'))
  text <- paste(c('[Input]',
    'LogKey:#Power|Reset|#P1 Stick Horizontal|P1 Stick Vertical|P1 Left Shoulder|P1 Right Shoulder|P1 A|P1 B|',
    rows, '[/Input]'), collapse='\n')
  replayr:::.parse_bk2_input_log(text,
    list('_format'='bk2', Platform='SAT', emuVersion='Version 2.2.1'))
}

test_that('Saturn 3D-pad angles use source centre, range, and Y direction', {
  wire <- saturn_stick_wire()
  raw <- replayr:::.configure_movie(wire)
  full <- replayr:::.configure_movie(wire,'angle+magnitude')
  angle <- replayr:::.configure_movie(wire,'angle')
  expected_angle <- c(NA,0,45,90,180,270,NA,0,0,180)
  expected_magnitude <- c(0,.5,sqrt(.5),.5,.5,.5,31/128,.25,127/128,1)
  expect_identical(raw$stick_available[[1]], 'left')
  expect_equal(stick_channels(full)[,'left_angle'], expected_angle)
  expect_equal(stick_channels(full)[,'left_magnitude'], expected_magnitude)
  expect_equal(stick_channels(angle)[,1], expected_angle)
  expect_identical(analog_channels(full),analog_channels(raw))
  expect_equal(analog_channels(raw)[,3:4], cbind(rep(32,10),rep(224,10)),ignore_attr=TRUE)
  expect_equal(player(angle),player(raw))
})

test_that('Saturn cardinal modes and deadzones preserve physical buttons', {
  wire <- saturn_stick_wire()
  for (mode in c('cardinal4','cardinal8')) {
    movie <- replayr:::.configure_movie(wire,mode)
    layout <- button_layout(movie)
    directions <- player(movie)[,layout$kind=='left_direction',drop=FALSE]
    expect_equal(rowSums(directions),c(0,1,1,1,1,1,0,1,1,1))
    expect_true(all(player(movie)[,layout$key=='a']))
    expect_false(any(player(movie)[,layout$key=='b']))
    expected <- c(NA,0,if(mode=='cardinal4') 90 else 45,90,180,270,NA,0,0,180)
    expect_equal(stick_channels(movie)[,1],expected)
  }
  tight <- replayr:::.configure_movie(wire,'cardinal8',deadzone=.5)
  expect_true(all(is.na(stick_channels(tight)[c(1,7,8),1])))
  expect_equal(unname(stick_channels(tight)[2,1]),0)
})
