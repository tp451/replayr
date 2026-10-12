make_fceux_binary <- function(ext = 'fm3', port0 = 1L, port1 = 0L, records, frames = NULL, tail = raw()) {
  path <- tempfile(fileext = paste0('.', ext))
  h <- paste0(
    'version 3\nport0 ', port0, '\nport1 ', port1, '\nfourscore 0\nbinary 1\n',
    if (!is.null(frames)) paste0('length ', frames, '\n'), '|'
  )
  writeBin(c(charToRaw(h), as.raw(records), tail), path)
  path
}
test_that('FM3 frame count bounds binary input before editor data', {
  path <- make_fceux_binary(records = c(1, 129, 0, 0), frames = 2, tail = as.raw(c(124, 255, 0, 9)))
  on.exit(unlink(path))
  m <- read_fm3(path)
  expect_identical(n_frames(m), 2L)
  expect_identical(m$commands, c(1L, 0L))
  expect_true(player(m)[1, 'A'])
  expect_true(player(m)[1, 'R'])
  expect_false(any(player(m)[2, ]))
  expect_identical(m$project_bytes, as.raw(c(124, 255, 0, 9)))
})
test_that('FM2 binary Zapper records preserve positions, flags, and hit timestamps', {
  record <- c(0, 10, 200, 3, 5, 1, 2, 0, 0, 0, 0, 0, 0)
  path <- make_fceux_binary(ext = 'fm2', port0 = 2L, records = record)
  on.exit(unlink(path))
  m <- read_fm2(path)
  expect_identical(n_frames(m), 1L)
  expect_equal(unname(analog_channels(m)[1, ]), c(10, 200, 3, 5, 513))
  expect_true(all(player(m)[1, ]))
  expect_identical(m$trailing_bytes, raw())
})
test_that('FM3 textual logs stop before binary project data', {
  path <- tempfile(fileext = '.fm3')
  on.exit(unlink(path))
  header <- paste0(
    'version 3\nport0 1\nport1 0\nlength 2\n',
    '|0|R......A|||\n|0|........|||\n'
  )
  writeBin(c(charToRaw(header), as.raw(c(0, 124, 10, 255))), path)
  m <- read_fm3(path)
  expect_identical(n_frames(m), 2L)
  expect_true(player(m)[1, 'R'])
  expect_true(player(m)[1, 'A'])
  expect_identical(m$project_bytes, as.raw(c(0, 124, 10, 255)))
})
test_that('command-only FCEUX logs have zero digital columns', {
  path <- make_fceux_binary(port0 = 0L, port1 = 0L, records = c(1, 2, 0), frames = 3)
  on.exit(unlink(path))
  m <- read_fm3(path)
  expect_identical(dim(m$inputs), c(3L, 1L, 0L))
  expect_identical(m$commands, c(1L, 2L, 0L))
  expect_identical(dim(player(m)), c(3L, 0L))
  expect_identical(ncol(align_buttons(list(m))[[1L]]), 0L)
})
