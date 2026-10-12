# Yabause-rr uses 13 positions, LRUDSABCXYZWE. The older wiki example omits
# one dot. Source: https://github.com/adelikat/yabause-rr/blob/master/src/windows/movie.cpp
.decode_ymv <- function(path) {
  source <- .legacy_text(path, "ymv")
  header <- source$header
  if (!identical(header$version, "1")) stop(path, ": unsupported YMV version ", header$version)
  keys <- c("dpad_left", "dpad_right", "dpad_up", "dpad_down", "start", "a", "b", "c", "x", "y", "z", "l1", "r1")
  if (identical(header$binary, "1")) {
    body <- if (length(source$body)) source$body[-1L] else raw()
    if (length(body) %% 3L) stop(path, ": YMV has a partial binary record")
    packets <- matrix(as.integer(body), ncol = 3L, byrow = TRUE)
    commands <- packets[, 1L]
    states <- .legacy_bits(packets[, 2L] + 256L * packets[, 3L], 12:0)
  } else {
    fields <- .legacy_fields(.legacy_rows(source$body, "ymv"), 2L, "ymv")
    commands <- .legacy_commands(fields[, 1L], "ymv")
    states <- .legacy_chars(fields[, 2L], 13L, "ymv")
  }
  header$system <- "SATURN"
  .new_named_movie(header, commands, array(states, c(nrow(states), 1L, length(keys))), keys, path)
}
