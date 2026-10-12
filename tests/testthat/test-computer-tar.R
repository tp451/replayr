test_that("native libTAS rejects linked configuration and input members", {
  for (type in c("1", "2")) {
    for (linked in c("config.ini", "inputs")) {
      scripts <- list("config.ini" = "[General]\nnb_controllers=0\n", "inputs" = "|\n")
      types <- c("0", "0"); types[match(linked, names(scripts))] <- type
      scripts[[linked]] <- ""
      path <- .computer_test_tar(scripts, types)
      on.exit(unlink(path), add = TRUE)
      expect_error(.decode_ltm(path), "member type")
    }
  }
})

test_that("tar parsing checks later members before returning selected text", {
  path <- .computer_test_tar(list("config.ini" = "[General]\n", "inputs" = "|\n",
    "unselected" = ""), c("0", "0", "2"))
  on.exit(unlink(path))
  expect_error(.computer_tar_text(path, c("config.ini", "inputs")), "member type")
  path2 <- .computer_test_tar(list("./config.ini" = "[General]\r\n", "./inputs" = "|\r\n"))
  on.exit(unlink(path2), add = TRUE)
  expect_identical(.computer_tar_text(path2, c("config.ini", "inputs")),
    list("config.ini" = "[General]", "inputs" = "|"))
  path3 <- .computer_test_tar(list("config.ini" = "", "./config.ini" = "", "inputs" = ""))
  on.exit(unlink(path3), add = TRUE)
  expect_error(.computer_tar_text(path3, c("config.ini", "inputs")), "Duplicate")
})

test_that("tar parsing validates gzip CRC rather than accepting corrupt text", {
  path <- .computer_test_tar(list("config.ini" = "[General]\n", "inputs" = "|\n"))
  on.exit(unlink(path))
  data <- readBin(path, "raw", file.info(path)$size)
  index <- length(data) - 7L
  data[index] <- as.raw(bitwXor(as.integer(data[index]), 1L))
  writeBin(data, path)
  expect_error(.computer_tar_text(path, c("config.ini", "inputs")), "compressed|Truncated")
})

test_that("tar root directory entries coexist with regular selected members", {
  path <- .computer_test_tar(list("./" = "", "./config.ini" = "[General]\n", "./inputs" = "|\n"),
    c("5", "0", "0"))
  on.exit(unlink(path))
  expect_identical(.computer_tar_text(path, c("config.ini", "inputs")),
    list("config.ini" = "[General]", "inputs" = "|"))
})
