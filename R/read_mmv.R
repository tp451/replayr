# Dega format: https://tasvideos.org/EmulatorResources/MMV
.decode_mmv <- function(path) {
  data <- readBin(path, "raw", n = file.info(path)$size)
  if (length(data) < 96L || !identical(data[1:4], as.raw(c(77, 77, 86, 0)))) stop(path, ": not an MMV file")
  version <- .read_u32_le(data, 4L)
  offset <- .read_u32_le(data, 24L)
  width <- .read_u32_le(data, 28L)
  reset <- .read_u32_le(data, 16L) != 0L
  state_offset <- .read_u32_le(data, 20L)
  if (state_offset == 0L) state_offset <- 96L
  if (offset == 0L) offset <- if (reset) 96L else 25184L
  if (width == 0L) width <- 2L
  header_size <- if (reset) offset else state_offset
  if (offset < 96L || offset > length(data)) stop(path, ": invalid MMV input offset")
  if (width < 2L) stop(path, ": unsupported MMV input packet size ", width)
  body <- if (offset < length(data)) data[(offset + 1L):length(data)] else raw()
  tail_size <- length(body) %% width
  tail <- if (tail_size) utils::tail(body, tail_size) else raw()
  if (tail_size) {
    warning(path, ": MMV ends with ", tail_size, " byte(s) of an incomplete frame; retaining them in source_tail", call. = FALSE)
    body <- utils::head(body, length(body) - tail_size)
  }
  packets <- matrix(as.integer(body), ncol = width, byrow = TRUE)
  flags <- if (header_size >= 100L) .read_u32_le(data, 96L) else 0L
  gg <- bitwAnd(flags, 8L) != 0L
  ports <- if (gg) 1L else 1:2
  keys <- c("dpad_up", "dpad_down", "dpad_left", "dpad_right", "b", "a", "start")
  labels <- c("Up", "Down", "Left", "Right", "1", "2", if (gg) "Start" else "Pause")
  inputs <- array(FALSE, c(nrow(packets), length(ports), length(keys)))
  for (p in ports) inputs[, p, ] <- .legacy_bits(packets[, p], c(0:5, if (gg) 7L else 6L))
  header <- list(
    `_format` = "mmv", system = if (gg) "GG" else "SMS", emuVersion = version,
    declaredFrameCount = .read_u32_le(data, 8L), frameCount = nrow(packets),
    rerecordCount = .read_u32_le(data, 12L), startsFromReset = .read_u32_le(data, 16L) != 0L,
    stateOffset = .read_u32_le(data, 20L), inputOffset = offset,
    isPal = bitwAnd(flags, 2L) != 0L, isJapan = bitwAnd(flags, 4L) != 0L,
    author = .read_cstring(data, 32L, 64L), romFilename = if (header_size >= 228L) .read_cstring(data, 100L, 128L) else NULL,
    romMD5 = if (header_size >= 244L) paste(sprintf("%02x", as.integer(data[229:244])), collapse = "") else NULL
  )
  # Dega's MvidPreFrame reads until EOF rather than stopping at vidFrameCount.
  # Preserve the original count without warning about this accepted variant.
  header$availableFrameCount <- nrow(packets)
  header$frameCountDifference <- header$declaredFrameCount - nrow(packets)
  movie <- .new_named_movie(header, integer(nrow(packets)), inputs, keys, path, names = labels)
  movie$source_tail <- tail
  movie$source_packets <- packets
  movie
}
