decode_log <- function(key, rows, platform = "Arcade") {
  wire <- replayr:::.parse_bk2_input_log(paste(c("[Input]", key, rows, "[/Input]"), collapse = "\n"),
    list("_format" = "bk2", Platform = platform, Core = if (platform == "PSX") "Nymashock" else "MAME"))
  replayr:::.configure_movie(wire)
}

test_that("unprefixed arcade controls retain numeric channels and named buttons", {
  mv <- decode_log("LogKey:#AD Stick Y 2|AD Stick Y|AD Stick X 2|AD Stick X|Coin 1|Gun Trigger|Missile Button|View Change|",
    c("|127,127,0,255,C.G.|", "|1,2,3,4,.H.V|"))
  expect_equal(unname(analog_channels(mv)), rbind(c(127,127,0,255), c(1,2,3,4)))
  expect_identical(button_layout(mv)$key, c("select", "b", "a"))
  expect_equal(unname(player(mv)), rbind(c(FALSE,TRUE,FALSE),c(TRUE,FALSE,TRUE)), ignore_attr = TRUE)
  expect_identical(system_channels(mv)[["Coin 1"]], c(TRUE, FALSE))
})

test_that("global numeric controls stay outside compact gamepad columns", {
  mv <- decode_log("LogKey:#Dial|Dial 2|Reset|Coin 1|#P1 D|P1 Attack|P1 Jump|P1 Up|",
    c("|12,-3,.C|D.J.|", "|0,4,R.|.A.U|"))
  expect_identical(button_layout(mv)$key, c("dpad_up", "b", "a", "y"))
  expect_identical(system_channels(mv)$Dial, c(12, 0))
  expect_identical(system_channels(mv)[["Dial 2"]], c(-3, 4))
  expect_identical(system_channels(mv)$Reset, c(FALSE, TRUE))
  expect_equal(ncol(analog_channels(mv)), 0)
})

test_that("light gun coordinates are preserved without gamepad calibration", {
  mv <- decode_log("LogKey:#Power|#P1 Y Axis|P1 X Axis|P1 Trigger|P1 A|P1 Offscreen Shot|",
    c("|.|136,1433,T..|", "|.|16,0,.AO|"), "PSX")
  expect_identical(button_layout(mv)$key, c("b", "a", "y"))
  expect_equal(unname(analog_channels(mv)), rbind(c(136,1433),c(16,0)))
  expect_equal(ncol(stick_channels(mv)), 0)
  expect_length(mv$stick_available[[1]], 0)
})

test_that("mouse motion and trailing Saturn system controls keep stream order", {
  mv <- decode_log("LogKey:#Power|Reset|#P1 Motion Left / Right|P1 Motion Up / Down|P1 Left Button|P1 Middle Button|P1 Right Button|P1 Start|#P13 Smpc Reset|",
    c("|..|127,-50,L..S|R|", "|P.|0,20,.MR.|.|"), "SAT")
  expect_equal(n_players(mv), 1)
  expect_identical(button_layout(mv)$key, c("start", "b", "a", "x"))
  expect_equal(unname(analog_channels(mv)), rbind(c(127,-50),c(0,20)))
  expect_identical(system_channels(mv)[["P13 Smpc Reset"]], c(TRUE,FALSE))
  expect_identical(system_channels(mv)$Power, c(FALSE,TRUE))
})
