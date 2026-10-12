test_that("source-defined controls keep stable identities across compact layouts", {
  make <- function(keys) {
    x <- array(FALSE,c(3L,1L,length(keys)))
    x[2L,1L,] <- TRUE
    .configure_movie(.new_named_movie(list(`_format`="custom"),integer(3),x,keys))
  }
  first <- make(c("key_a","a","key_return"))
  second <- make(c("key_return","b","key_a"))
  expect_identical(button_layout(first)$id,c("8","control:key_a","control:key_return"))
  expect_identical(button_layout(second)$id,c("7","control:key_return","control:key_a"))
  aligned <- align_buttons(list(first,second))
  expect_identical(attr(aligned[[1]],"button_keys"),c("b","a","key_a","key_return"))
  expect_identical(aligned[[1]][2,],c(B=FALSE,A=TRUE,`{key_a}`=TRUE,`{key_return}`=TRUE))
  expect_identical(aligned[[2]][2,],c(B=TRUE,A=FALSE,`{key_a}`=TRUE,`{key_return}`=TRUE))
  core <- make(c("a","b"))
  expect_identical(button_layout(core)$id,c(7L,8L))
  expect_error(.new_named_movie(list(),integer(3),array(FALSE,c(3,1,2)),c("a","a")),"uniquely")
})

test_that("source-calibrated sticks retain axes and select each stick independently", {
  axes <- cbind(cx=c(128,255,128),cy=c(128,128,0),rx=c(0,0,-100),ry=c(0,100,0))
  calibration <- list(list(left=list(x="cx",y="cy",center=c(128,128),scale=c(128,128),sign=c(1,-1)),
                           right=list(x="rx",y="ry",center=c(0,0),scale=c(100,100))))
  decoded <- .new_named_movie(list(`_format`="custom"),integer(3),array(FALSE,c(3,1,1)),
    "key_space",analog=list(axes),stick_calibration=calibration)
  movie <- .configure_movie(decoded,c(left="cardinal8",right="angle+magnitude"))
  expect_identical(analog_channels(movie),axes)
  expect_equal(unname(stick_channels(movie)[,"left_direction"]),c(NA,0,90))
  expect_equal(unname(stick_channels(movie)[,"right_angle"]),c(NA,90,180))
  expect_equal(unname(stick_channels(movie)[,"right_magnitude"]),c(0,1,1))
  expect_true(all(c("left_e","left_n","key_space") %in% button_layout(movie)$key))
  expect_identical(n_buttons(.configure_movie(decoded,"raw")),1L)
  expect_identical(n_frames(movie),3L)
})
