# gz's GZM serialisation runs on the Nintendo 64's big-endian ABI.
# https://github.com/MrPancakeTurtle/gz/blob/master/src/gz/gz_macro.c
# Record structures and edge flags: gz.h, gz_movie.c, and z64.h in that directory.
.decode_gzm <- function(path) {
  data <- readBin(path, "raw", n = file.info(path)$size)
  if (length(data) < 12L) stop(path, ": GZM header is truncated")
  u32 <- function(offset) {
    if (offset < 0 || offset + 4 > length(data)) stop(path, ": truncated GZM section")
    sum(as.numeric(data[offset + 1:4]) * c(16777216, 65536, 256, 1))
  }
  ni <- u32(0L)
  ns <- u32(4L)
  required <- 12 + 6 * ni + 12 * ns
  if (required > length(data)) stop(path, ": GZM input or seed section is truncated")
  slice <- function(offset, size) if (size) data[offset + seq_len(size)] else raw()
  input_bytes <- slice(12L, 6 * ni)
  packets <- matrix(as.integer(input_bytes), ncol = 6L, byrow = TRUE)
  words <- 256L * packets[, 1] + packets[, 2]
  delta <- 256L * packets[, 5] + packets[, 6]
  signed8 <- function(x) ifelse(x >= 128L, x - 256L, x)
  keys <- c("a", "b", "z", "start", "dpad_up", "dpad_down", "dpad_left", "dpad_right", "l1", "r1", "c_up", "c_down",
    "c_left", "c_right")
  states <- .legacy_bits(words, c(15:8, 5:0))
  axes <- cbind(stick_x = signed8(packets[, 3]), stick_y = signed8(packets[, 4]))
  offset <- 12 + 6 * ni
  seed_bytes <- slice(offset, 12 * ns)
  offset <- offset + 12 * ns
  read_table <- function(bytes, width) {
    b <- matrix(as.integer(bytes), ncol = width * 4L, byrow = TRUE)
    ans <- matrix(0, nrow(b), width)
    for (j in seq_len(width))
      ans[, j] <- as.vector(b[, (4 * j - 3):(4 * j), drop = FALSE] %*% c(16777216, 65536, 256, 1))
    ans
  }
  signed32 <- function(x) ifelse(x >= 2147483648, x - 4294967296, x)
  seeds <- read_table(seed_bytes, 3L)
  seeds[, 1L] <- signed32(seeds[, 1L])
  colnames(seeds) <- c("frame", "old_seed", "new_seed")
  events <- list(seeds = seeds)
  if (offset < length(data)) {
    no <- u32(offset)
    ny <- u32(offset + 4L)
    nr <- u32(offset + 8L)
    offset <- offset + 12L
    if (offset + 8 * no + 8 * ny + 4 * nr > length(data)) stop(path, ": GZM synchronisation section is truncated")
    ob <- matrix(as.integer(slice(offset, 8 * no)), ncol = 8L, byrow = TRUE)
    offset <- offset + 8 * no
    events$ocarina_input <- data.frame(
      frame = as.vector(ob[, 1:4, drop = FALSE] %*% c(16777216, 65536, 256, 1)),
      pad = 256L * ob[, 5] + ob[, 6], adjusted_x = signed8(ob[, 7]), adjusted_y = signed8(ob[, 8])
    )
    events$ocarina_input$frame <- signed32(events$ocarina_input$frame)
    events$ocarina_sync <- read_table(slice(offset, 8 * ny), 2L)
    events$ocarina_sync[] <- signed32(events$ocarina_sync)
    offset <- offset + 8 * ny
    colnames(events$ocarina_sync) <- c("frame", "audio_frames")
    events$room_load <- read_table(slice(offset, 4 * nr), 1L)
    offset <- offset + 4 * nr
    events$room_load[] <- signed32(events$room_load)
    colnames(events$room_load) <- "frame"
  }
  header <- list(
    `_format` = "gzm", system = "N64", observationUnit = "game_update",
    inputCount = ni, initialControllerBytes = data[9:12], commandEncoding = "bit 0: reset (source pad_delta bit 7)"
  )
  if (offset < length(data)) {
    if (length(data) - offset != 8L) stop(path, ": unrecognised GZM footer length")
    header$rerecordCount <- u32(offset)
    header$lastRecordedFrame <- signed32(u32(offset + 4L))
  }
  movie <- .new_named_movie(header, as.integer(bitwAnd(delta, 128L) != 0L), array(states, c(ni, 1L, length(keys))),
    keys, path,
    analog = list(axes),
    stick_calibration = list(list(left = list(x = "stick_x", y = "stick_y", center = c(0, 0), scale = c(128, 128),
      sign = c(1, 1))))
  )
  prev <- c(256L * as.integer(data[9]) + as.integer(data[10]), utils::head(words, -1L))
  if (!ni) prev <- integer()
  edge_delta <- bitwAnd(delta, 65407L)
  movie$frame_fields <- data.frame(
    pad_delta = delta,
    pad_pressed = bitwOr(bitwAnd(words, bitwXor(prev, 65535L)), edge_delta),
    pad_released = bitwOr(bitwAnd(bitwXor(words, 65535L), prev), edge_delta)
  )
  movie$system_events <- events
  movie$source_packets <- matrix(input_bytes, ncol = 6L, byrow = TRUE)
  movie
}
