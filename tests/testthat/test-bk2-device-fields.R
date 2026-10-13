decode_device_fields <- function(key, rows, platform) {
  text <- paste(c("[Input]", key, rows, "[/Input]"), collapse = "\n")
  wire <- replayr:::.parse_bk2_input_log(
    text,
    list("_format" = "bk2", Platform = platform)
  )
  replayr:::.configure_movie(wire)
}
test_that("Power Pad sensor numbers are independent of their serial positions", {
  order <- c(2, 1, 5, 9, 6, 10, 11, 7, 4, 3, 12, 8)
  key <- paste0(
    "LogKey:#Power|Reset|#P1 Up|P1 Down|P1 Left|P1 Right|",
    "P1 Start|P1 Select|P1 B|P1 A|#",
    paste0("P2 PP", order, collapse = "|"), "|"
  )
  states <- vapply(seq_len(12), function(i) {
    x <- rep(".", 12)
    x[i] <- "X"
    paste0(x, collapse = "")
  }, character(1))
  movie <- decode_device_fields(key, paste0("|..|........|", states, "|"), "NES")
  layout <- button_layout(movie)
  pad <- layout$kind == "numbered"
  expect_identical(layout$key[pad], paste0("numbered_", 1:12))
  expect_identical(as.integer(layout$id[pad]), 41:52)
  expect_equal(player(movie, 2)[, pad], diag(12)[order, ] == 1,
    ignore_attr = TRUE
  )
  expect_false(any(player(movie, 1)))
})
test_that("NES Zapper fields retain positions and a primary-action trigger", {
  movie <- decode_device_fields(
    "LogKey:#Power|Reset|#P1 Up|P1 Down|P1 Left|P1 Right|P1 Start|P1 Select|P1 B|P1 A|#P2 Zapper X|P2 Zapper Y|P2 Fire|",
    c("|..|........|120,45,F|", "|..|........|0,239,.|"), "NES"
  )
  expect_identical(colnames(analog_channels(movie, 2)), c("aim_x", "aim_y"))
  expect_equal(analog_channels(movie, 2), rbind(c(120, 45), c(0, 239)), ignore_attr = TRUE)
  trigger <- which(button_layout(movie)$key == "a")
  expect_identical(unname(player(movie, 2)[, trigger]), c(TRUE, FALSE))
  expect_length(movie$stick_available[[2]], 0)
})
test_that("SNES mouse deltas and buttons consume the right stream fields", {
  movie <- decode_device_fields(
    "LogKey:#Reset|Power|#P1 Mouse X|P1 Mouse Y|P1 Mouse Left|P1 Mouse Right|",
    c("|..|12,-4,L.|", "|..|-3,2,.R|"), "SNES"
  )
  expect_equal(analog_channels(movie), rbind(c(12, -4), c(-3, 2)), ignore_attr = TRUE)
  expect_identical(button_layout(movie)$key, c("b", "a"))
  expect_equal(player(movie), (diag(2) == 1)[, 2:1], ignore_attr = TRUE)
})
test_that("Saturn 3D shoulder axes and ST-V system controls stay separate", {
  movie <- decode_device_fields(
    "LogKey:#Power|Reset|#P1 Stick Horizontal|P1 Stick Vertical|P1 Left Shoulder|P1 Right Shoulder|P1 A|P1 B|#P13 Smpc Reset|P13 St-V Test|P13 St-V Service|P13 St-V Pause|",
    c("|..|128,64,32,255,A.|.TS.|", "|R.|255,128,0,128,.B|S..P|"), "SAT"
  )
  expect_identical(n_players(movie), 1L)
  expect_equal(analog_channels(movie), rbind(c(128, 64, 32, 255), c(255, 128, 0, 128)), ignore_attr = TRUE)
  expect_identical(button_layout(movie)$key, c("b", "a"))
  expect_identical(system_channels(movie)[["st_v_test"]], c(TRUE, FALSE))
  expect_identical(system_channels(movie)[["st_v_pause"]], c(FALSE, TRUE))
})
test_that("arcade buttons shown under a name follow one table for the platform", {
  movie <- decode_device_fields(
    "LogKey:#Coin 1|#P1 Button 7|P1 Jump/Start|P1 Kick|P1 Punch|",
    c("|.|7...|", "|.|.J..|", "|.|..K.|", "|.|...P|"), "Arcade"
  )
  expect_identical(
    button_layout(movie)$key,
    c("b", "a", "x", "l2")
  )
  expect_identical(as.integer(button_layout(movie)$id), c(7L, 8L, 9L, 13L))
  expect_equal(player(movie), (diag(4) == 1)[, c(2, 4, 3, 1)], ignore_attr = TRUE)
  expect_identical(movie$source_layout$name[movie$source_layout$universal_key == "a"], "Punch")
})
test_that("arcade gun and viewport labels keep their source values", {
  movie <- decode_device_fields(
    "LogKey:#AD Stick Y 2|AD Stick Y|AD Stick X 2|AD Stick X|1 Player Start|2 Players Start|Coin 1|Coin 2|Service 1|Service Button|Gun Button|Missile Button|Viewport Change Button|",
    c("|1,2,3,4,......GM.|", "|4,3,2,1,......G.V|"), "Arcade"
  )
  expect_identical(button_layout(movie)$key, c("select", "b", "a"))
  expect_equal(analog_channels(movie), rbind(1:4, 4:1), ignore_attr = TRUE)
  expect_equal(player(movie), rbind(c(FALSE, TRUE, TRUE), c(TRUE, FALSE, TRUE)), ignore_attr = TRUE)
})
test_that("QuickNES and NesHawk microphone labels share a microphone identity", {
  for (label in c("M", "Microphone")) {
    movie <- decode_device_fields(
      paste0(
        "LogKey:#Power|Reset|#P2 Up|P2 Down|P2 Left|P2 Right|P2 B|P2 A|P2 ", label, "|"
      ),
      c("|..|......M|", "|..|.......|"), "NES"
    )
    microphone <- which(button_layout(movie)$key == "microphone")
    expect_identical(as.integer(button_layout(movie)$id[microphone]), 53L)
    expect_identical(unname(player(movie)[, microphone]), c(TRUE, FALSE))
  }
})
test_that("Game Boy input-cycle timing remains a numeric system channel", {
  movie <- decode_device_fields(
    "LogKey:#Input Cycle|#P1 Up|P1 Down|P1 Left|P1 Right|P1 Start|P1 Select|P1 B|P1 A|P1 Power|",
    c("|70224,|.......A.|", "|35112,|........P|"), "GB"
  )
  expect_identical(system_channels(movie)[["input_cycle"]], c(70224, 35112))
  expect_identical(system_channels(movie)[["power"]], c(FALSE, TRUE))
  expect_identical(unname(player(movie)[, which(button_layout(movie)$key == "a")]), c(TRUE, FALSE))
})
test_that("arcade lightgun coordinates without port prefixes retain their names", {
  movie <- decode_device_fields(
    "LogKey:#Lightgun X|Lightgun X 2|Lightgun Y|Lightgun Y 2|1 Player Start|2 Players Start|Coin 1|Coin 2|Service 1|#P1 Button 1|#P2 Button 1|",
    c("|128,120,64,90,.....|A|.|", "|64,90,128,120,.....|.|A|"), "Arcade"
  )
  expect_equal(as.matrix(system_channels(movie)[, 1:4]),
    rbind(c(128, 120, 64, 90), c(64, 90, 128, 120)),
    ignore_attr = TRUE
  )
  expect_identical(unname(player(movie, 1)[, 1]), c(TRUE, FALSE))
  expect_identical(unname(player(movie, 2)[, 1]), c(FALSE, TRUE))
})
test_that("SMS Light Phaser X and Y are numeric while gamepad X and Y remain buttons", {
  movie <- decode_device_fields(
    "LogKey:#Reset|Pause|#P1 X|P1 Y|P1 Trigger|#P2 X|P2 Y|P2 Trigger|",
    c("|..|64,96,T|32,48,.|", "|..|0,0,.|255,191,T|"), "SMS"
  )
  expect_equal(analog_channels(movie, 1), rbind(c(64, 96), c(0, 0)), ignore_attr = TRUE)
  expect_equal(analog_channels(movie, 2), rbind(c(32, 48), c(255, 191)), ignore_attr = TRUE)
  expect_identical(button_layout(movie)$key, "a")
  expect_identical(unname(player(movie, 1)[, 1]), c(TRUE, FALSE))
  pad <- decode_device_fields("LogKey:#Reset|#P1 X|P1 Y|", "|.|XY|", "SNES")
  expect_identical(button_layout(pad)$key, c("x", "y"))
  expect_equal(ncol(analog_channels(pad)), 0L)
})
test_that('GunCon trigger and side buttons stay distinct after normalization', {
  m <- decode_device_fields(
    'LogKey:#Power|#P1 X Axis|P1 Y Axis|P1 Trigger|P1 A|P1 B|P1 Offscreen Shot|',
    c('|.|100,80,T...|', '|.|101,81,.A..|', '|.|102,82,..B.|', '|.|103,83,TABO|'), 'PSX'
  )
  layout <- button_layout(m)
  expect_identical(layout$key, c('b', 'a', 'x', 'y'))
  values <- player(m)
  colnames(values) <- layout$key
  expect_equal(unname(values[, c('a', 'b', 'x')]), rbind(diag(TRUE, 3), c(TRUE, TRUE, TRUE)))
  expect_identical(as.integer(layout$id[match(c('a', 'b', 'x'), layout$key)]), c(8L, 7L, 9L))
  expect_true('gun_trigger' %in% m$source_layout$key)
  expect_identical(m$source_inputs[, 1, match('gun_trigger', m$source_layout$key)], c(TRUE, FALSE, FALSE, TRUE))
})
