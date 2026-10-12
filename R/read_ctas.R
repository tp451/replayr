# CoffeeTools/UFO 50 source format (versions 3 and 4):
# https://github.com/Blaizer/CoffeeTools/blob/main/patches/CoffeeTools/code/gml_GlobalScript_CoffeeTools.gml
.decode_ctas <- function(path) {
  data <- readBin(path, 'raw', n = file.info(path)$size)
  if (length(data) < 1024L || rawToChar(data[1:4]) != 'CTAS') stop('Invalid CoffeeTools header', call. = FALSE)
  version <- .read_u32_le(data, 4L)
  if (!version %in% c(3L, 4L)) stop('Unsupported CoffeeTools version: ', version, call. = FALSE)
  n <- .read_u32_le(data, 8L)
  nr <- .read_u32_le(data, 12L)
  needed <- 1024 + 8 * n + 12 * nr
  if (length(data) < needed) stop('Truncated CoffeeTools input or randomization table', call. = FALSE)
  if (length(data) > needed) warning('CoffeeTools has trailing bytes; they are retained in source_tail', call. = FALSE)
  bytes <- matrix(as.integer(if (n) data[1024 + seq_len(8 * n)] else raw()), nrow = n, ncol = 8, byrow = TRUE)
  words <- matrix(0, n, 2L)
  for (p in 1:2) words[, p] <- as.vector(bytes[, (p - 1L) * 4L + 1:4, drop = FALSE] %*% c(1, 256, 65536, 16777216))
  keys <- c('dpad_up', 'dpad_down', 'dpad_left', 'dpad_right', 'ufo50_fire1', 'ufo50_fire2', 'start')
  inputs <- array(FALSE, c(n, 2L, 7L))
  pressed <- released <- array(FALSE, c(n, 2L, 6L))
  bit <- function(x, b) (floor(x / 2^b) %% 2) != 0
  for (p in 1:2) {
    for (k in 1:6) {
      inputs[, p, k] <- bit(words[, p], (k - 1L) * 3L)
      pressed[, p, k] <- bit(words[, p], (k - 1L) * 3L + 1L)
      released[, p, k] <- bit(words[, p], (k - 1L) * 3L + 2L)
    }
    inputs[, p, 7L] <- bit(words[, p], 18L)
  }
  randomization <- data.frame(input_frame = integer(nr), seed = numeric(nr))
  if (nr) for (i in seq_len(nr)) {
    at <- 1024 + 8 * n + 12 * (i - 1L)
    frame <- .read_u32_le(data, at)
    if (frame >= 2^31) frame <- frame - 2^32
    randomization$input_frame[i] <- frame
    randomization$seed[i] <- readBin(data[at + 5:12], 'double', n = 1L, size = 8L, endian = 'little')
  }
  header <- list(
    format = 'ctas', emulator = 'CoffeeTools', game = 'UFO 50', version = version,
    frame_count = n, observation_unit = 'frame', rerecord_count = if (version >= 4L) .read_u32_le(data, 16L) else NA_real_,
    current_time = if (version >= 4L) .read_u32_le(data, 20L) else NA_real_, start_semantics = 'press event',
    action_semantics = 'Game input states; pressed and released events are also retained separately'
  )
  header[["_format"]] <- "ctas"
  movie <- .new_named_movie(header, integer(n), inputs, keys, path)
  dimnames(pressed)[[3L]] <- dimnames(released)[[3L]] <- keys[1:6]
  movie$pressed <- pressed
  movie$released <- released
  movie$randomization <- randomization
  movie$source_words <- words
  movie$source_header <- data[seq_len(1024L)]
  movie$source_tail <- if (length(data) > needed) data[seq.int(needed + 1, length(data))] else raw()
  movie
}
