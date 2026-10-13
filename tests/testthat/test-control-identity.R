# One rule decides which identity a control gets, whichever format recorded
# it: lettered buttons by their letter, PlayStation shapes by their place on
# the SNES diamond, numbered buttons in order.
layout_of <- function(file) {
  path <- system.file("extdata", file, package = "replayr", mustWork = TRUE)
  button_layout(suppressWarnings(read_movie(path)))
}
keys_by_name <- function(file) {
  layout <- layout_of(file)
  stats::setNames(layout$key, layout$name)
}
bizhawk_keys <- function(names, platform) {
  unname(vapply(names, function(name) {
    .bk2_control_key(paste("P1", name), platform, paste("P1", names), FALSE)
  }, character(1)))
}
test_that("lettered buttons are matched by their letter", {
  files <- c(
    "sample.fm2", "sample.smv", "sample.vbm", "sample.gmv", "sample.m64", "sample.dtm",
    "legacy/saturn.ymv", "legacy/touch-v2.dsm", "legacy/ngp.mcm", "legacy/lynx.mcm",
    "legacy/wswan.mcm", "legacy/devices.ctm"
  )
  for (file in files) {
    keys <- keys_by_name(file)
    lettered <- intersect(c("A", "B", "C", "X", "Y", "Z"), names(keys))
    expect_gte(length(lettered), 2L)
    expect_identical(unname(keys[lettered]), tolower(lettered), info = file)
  }
})
test_that("an SDL game controller in a libTAS recording is matched by letter", {
  # Its A is the lower button, where a Nintendo pad has B; the letter decides.
  layout <- layout_of("computers/dual-stick-menu.ltm")
  expect_true(all(c("a", "b", "x", "y") %in% layout$key))
  # The pad's A and the mouse's left button share the column; it names both.
  expect_identical(layout$name[match(c("a", "y"), layout$key)], c("Mouse left / A", "Y"))
})
test_that("PlayStation shapes take the SNES button in the same place", {
  expected <- c(Cross = "b", Circle = "a", Triangle = "x", Square = "y")
  for (file in c("sample.pxm", "sample.pjm")) {
    expect_identical(keys_by_name(file)[names(expected)], expected, info = file)
  }
  # BizHawk writes the shapes as words or as glyphs.
  expect_identical(bizhawk_keys(names(expected), "PSX"), unname(expected))
  expect_identical(bizhawk_keys(c("\u2715", "\u25CB", "\u25B3", "\u25A1"), "PSX"), unname(expected))
})
test_that("numbered buttons take the lettered identities in order, in every reader", {
  six <- c("I", "II", "III", "IV", "V", "VI")
  ordered <- c("a", "b", "x", "y", "l1", "r1")
  expect_identical(unname(keys_by_name("legacy/sms.mmv")[c("1", "2")]), ordered[1:2])
  expect_identical(unname(keys_by_name("legacy/gg.mmv")[c("1", "2")]), ordered[1:2])
  expect_identical(unname(keys_by_name("legacy/sms.mcm")[c("Fire 1", "Fire 2")]), ordered[1:2])
  expect_identical(unname(keys_by_name("expanded/legacy-sms.tas")[c("B1", "B2")]), ordered[1:2])
  expect_identical(unname(keys_by_name("legacy/pce.mc2")[six[1:2]]), ordered[1:2])
  expect_identical(unname(keys_by_name("legacy/pce.mcm")[six]), ordered)
  expect_identical(unname(keys_by_name("legacy/pcfx.mcm")[six]), ordered)
  expect_identical(bizhawk_keys(six, "PCE"), ordered)
  expect_identical(bizhawk_keys(c("B1", "B2"), "SMS"), ordered[1:2])
  expect_identical(bizhawk_keys(paste("Button", 1:6), "ARCADE"), ordered)
})
test_that("a console has the same identities in every format that records it", {
  pad <- c("a", "b", "dpad_up", "dpad_down", "dpad_left", "dpad_right")
  for (file in c("legacy/sms.mmv", "legacy/sms.mcm", "expanded/legacy-sms.tas")) {
    expect_true(all(pad %in% layout_of(file)$key), info = file)
  }
  # Of two direction pads, the left one is the direction pad (IDs 1-4) and
  # the right one has the IDs of the N64's C-buttons (20-23).
  pads <- as.vector(outer(c("dpad_", "c_"), c("right", "left", "down", "up"), paste0))
  for (file in c("legacy/vboy.mc2", "expanded/dual-digital-pad.bk2", "legacy/wswan.mcm")) {
    layout <- layout_of(file)
    expect_true(all(pads %in% layout$key), info = file)
    expect_identical(sort(as.integer(layout$id[match(pads, layout$key)])), c(1:4, 20:23), info = file)
  }
  expect_identical(bizhawk_keys(c("L_Up", "R_Up", "L_Left", "R_Right"), "VB"),
    c("dpad_up", "c_up", "dpad_left", "c_right"))
  # The WonderSwan's crosses are numbered clockwise from the top.
  expect_identical(bizhawk_keys(c("X1", "X2", "X3", "X4", "Y1", "Y2", "Y3", "Y4"), "WSWAN"),
    c("dpad_up", "dpad_right", "dpad_down", "dpad_left", "c_up", "c_right", "c_down", "c_left"))
  expect_identical(unname(keys_by_name("legacy/wswan.mcm")[c("X1", "X4", "Y2", "Y3")]),
    c("dpad_up", "dpad_left", "c_right", "c_down"))
  # The Master System's Pause is on the console, in every format.
  for (file in c("legacy/sms.mmv", "legacy/sms.mcm", "expanded/legacy-sms.tas")) {
    movie <- suppressWarnings(read_movie(system.file("extdata", file, package = "replayr")))
    expect_true("pause" %in% names(system_channels(movie)), info = file)
    expect_false("start" %in% button_layout(movie)$key, info = file)
  }
  # Run and a handheld's Pause are its Start.
  expect_identical(keys_by_name("legacy/pce.mcm")[["Run"]], "start")
  expect_identical(keys_by_name("legacy/pce.mc2")[["Run"]], "start")
  expect_identical(keys_by_name("legacy/lynx.mcm")[["Pause"]], "start")
  # Settings and option buttons take Start, Select and Mode.
  expect_identical(bizhawk_keys(c("A", "B", "Option 1", "Option 2", "Pause"), "LYNX"),
    c("a", "b", "select", "mode", "start"))
  expect_identical(unname(keys_by_name("legacy/lynx.mcm")[c("Option 1", "Option 2")]),
    c("select", "mode"))
  expect_identical(keys_by_name("legacy/ngp.mcm")[["Option"]], "start")
  expect_identical(bizhawk_keys(c("A", "B", "Option"), "NGP"), c("a", "b", "start"))
  expect_identical(bizhawk_keys(c("A", "B", "C", "Pause", "Option"), "JAGUAR"), c("a", "b", "c", "start", "mode"))
  expect_identical(bizhawk_keys(c("A", "B", "C", "X", "P", "L", "R"), "3DO"), c("a", "b", "c", "x", "start", "l1", "r1"))
  expect_identical(.canonical_control_keys(bizhawk_keys(c("Mode 1", "Mode 2"), "PCFX")), c("mode", "mode"))
  expect_identical(keys_by_name("legacy/pce.mcm")[["2/6 Mode Select"]], "mode")
  expect_identical(
    .canonical_control_keys(bizhawk_keys(c("Mode: Set 2-button", "Mode: Set 6-button"), "PCE")),
    c("mode", "mode")
  )
})
test_that("an arcade cabinet's two joysticks are the two analogue sticks", {
  # One rule for the platform, whatever the cabinet: the switches of the left
  # joystick are N, E, S and W of the left stick, those of the right joystick
  # N, E, S and W of the right stick.
  layout <- layout_of("expanded/arcade-dual-joysticks.mar")
  sticks <- c("left_n", "left_e", "left_s", "left_w", "right_n", "right_e", "right_s", "right_w")
  expect_true(all(sticks %in% layout$key))
  expect_identical(as.integer(layout$id[match(sticks, layout$key)]), c(26L, 24L, 30L, 28L, 34L, 32L, 38L, 36L))
  expect_false(any(c("dpad_up", "c_up") %in% layout$key))
  expect_identical(
    bizhawk_keys(c("Left Stick/Up", "Left Stick/Right", "Right Stick/Down", "Right Stick/Left"), "ARCADE"),
    c("left_n", "left_e", "right_s", "right_w")
  )
  # Analogue joysticks are recorded as raw values; the file does not hold
  # their centre and range, which differ from cabinet to cabinet.
  header <- list("_format" = "bk2", Platform = "Arcade", Core = "MAME")
  text <- paste(c(
    "[Input]",
    "LogKey:#AD Stick Y 2|AD Stick Y|AD Stick X 2|AD Stick X|Coin 1|",
    "|127,16,239,127,.|", "|239,127,127,16,.|", "|127,127,127,127,.|",
    "[/Input]"
  ), collapse = "\n")
  expect_no_warning(raw <- .configure_movie(.parse_bk2_input_log(text, header)))
  expect_equal(ncol(analog_channels(raw)), 4L)
  # Asked for directions, the reader estimates both from the recording (here
  # 16 to 239: centre 127.5, reach 111.5) and says so.
  expect_warning(
    movie <- .configure_movie(.parse_bk2_input_log(text, header), analog = "cardinal8"),
    "estimated from its values as centre 127.5 and reach 111.5"
  )
  layout <- button_layout(movie)
  held <- function(row) layout$key[which(player(movie)[row, ])]
  expect_identical(movie$stick_available[[1L]], c("left", "right"))
  expect_setequal(held(1L), c("left_n", "right_e"))
  expect_setequal(held(2L), c("left_w", "right_s"))
  expect_length(held(3L), 0L)
  # One chunk of a recording cannot give the estimate.
  header$firstObservation <- 1
  expect_error(
    suppressWarnings(.configure_movie(.parse_bk2_input_log(text, header), analog = "cardinal8")),
    "estimated from the whole recording"
  )
})
test_that("the agreed counterparts of less common controls hold", {
  # Keypad Star and Pound sit where Clear and Enter do: Select and Start.
  expect_identical(
    .canonical_control_keys(bizhawk_keys(c("Star", "Pound", "Clear", "Enter"), "COLECO")),
    c("select", "start", "select", "start")
  )
  expect_identical(.canonical_control_keys(bizhawk_keys(c("Asterisk", "Pound"), "JAGUAR")), c("select", "start"))
  # The Atari 7800's triggers are its first and second button.
  expect_identical(bizhawk_keys(c("Trigger", "Trigger 2"), "A78"), c("a", "b"))
  # The Channel F stick.
  expect_identical(
    bizhawk_keys(c("Forward", "Back", "Left", "Right", "CCW", "CW", "Push", "Pull"), "CHANNELF"),
    c("dpad_up", "dpad_down", "dpad_left", "dpad_right", "l1", "r1", "a", "b")
  )
  # A mouse wheel turned up or down, and a touch.
  expect_identical(.canonical_control_keys(c("mouse_scroll_up", "mouse_scroll_down")), c("c_up", "c_down"))
  expect_identical(bizhawk_keys("Touch", "NDS"), "l3")
  # Not on a pad: console controls.
  console <- function(name, platform) .bk2_system_control(tolower(name), platform, TRUE, FALSE)
  expect_true(console("LidOpen", "NDS"))
  expect_true(console("LidClose", "NDS"))
  expect_true(console("Tilt", "3DS"))
  expect_true(console("Debug", "3DS"))
  expect_true(console("GPIO14", "3DS"))
  expect_true(console("Toggle Link Connection", "GBL"))
  expect_true(console("BW", "A7800"))
  expect_true(console("Mouse Relative Toggle", "TIC80"))
  expect_false(console("Touch", "NDS"))
})
test_that("no two columns of a layout share a name", {
  # A GunCon has a side button marked A beside its trigger: the trigger is
  # the shared A, the side button the shared B. Each column keeps the label
  # of the device, so the names differ.
  gun <- read_movie(system.file("extdata", "paper", "light-gun.bk2", package = "replayr"))
  layout <- button_layout(gun)
  expect_identical(layout$key, c("b", "a", "y"))
  expect_identical(layout$name, c("A", "Trigger", "Offscreen Shot"))
  expect_identical(names(press_counts(gun)), layout$key)
  expect_identical(attr(player(gun), "button_names"), layout$name)
  # Every bundled recording: unique, non-empty names, IDs and keys.
  folder <- system.file("extdata", package = "replayr")
  files <- list.files(folder, recursive = TRUE, full.names = TRUE)
  files <- files[!grepl("[.](md|json|csv|txt)$", files)]
  for (file in files) {
    movie <- tryCatch(suppressWarnings(read_movie(file)), error = function(e) NULL)
    if (is.null(movie)) next
    layout <- button_layout(movie)
    expect_false(anyDuplicated(layout$name) > 0L, info = basename(file))
    expect_false(anyDuplicated(layout$key) > 0L, info = basename(file))
    expect_true(all(nzchar(layout$name)), info = basename(file))
  }
  # Several controls of a recording under one ID: their labels are joined.
  jaguar <- .configure_movie(.new_named_movie(
    list(`_format` = "bk2"), integer(1), array(FALSE, c(1L, 1L, 3L)),
    c("start", "keypad_pound", "keypad_star")
  ))
  expect_identical(button_layout(jaguar)$name, c("Start / Pound", "Star"))
  # Two controls of a device with the same label are told apart.
  twins <- .configure_movie(.new_named_movie(
    list(`_format` = "bk2"), integer(1), array(FALSE, c(1L, 1L, 2L)), c("b", "a"),
    names = c("Fire", "Fire")
  ))
  expect_identical(button_layout(twins)$name, c("Fire (B)", "Fire (A)"))
})
test_that("columns show the labels of their device", {
  expect_true(all(c("Cross", "Circle", "Triangle", "Square") %in% layout_of("sample.pxm")$name))
  expect_true(all(c("I", "II", "Run") %in% layout_of("legacy/pce.mcm")$name))
  expect_true(all(c("Fire 1", "Fire 2") %in% layout_of("legacy/sms.mcm")$name))
  expect_true(all(c("Left pad Up", "Right pad Up") %in% layout_of("legacy/vboy.mc2")$name))
  expect_true(all(c("X1", "Y1") %in% layout_of("legacy/wswan.mcm")$name))
})
