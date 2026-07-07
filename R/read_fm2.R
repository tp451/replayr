# FCEUX .fm2 movie format. Reference: https://fceux.com/web/FM2.html
#
# An .fm2 file has two parts:
#
# 1. Header. ASCII text. Each line is a `key value` pair separated by the
#    first whitespace. Multi-valued keys (`comment`, `subtitle`) are
#    joined with newlines.
#
# 2. Input log. Every line that starts with `|` is a frame record:
#         |<commands>|<RLDUTSBA>|<RLDUTSBA>||
#    Each gamepad column has 8 character positions; position i shows the
#    mnemonic of button i if held, or a placeholder (`.`, ` `, `0`).
#
# Button column order is RLDUTSBA -- Right, Left, Down, Up, sTart, Select,
# B, A. We map straight onto universal slots 1..8 (R semantics).

# Canonical NES button column order. Single-letter mnemonics indexed
# positionally to match FM2 column character positions.
.NES_BUTTONS <- c("R", "L", "D", "U", "T", "S", "B", "A")

# Parse one 8-character button column into a length-8 logical vector.
# A position is "pressed" if its character matches the canonical NES
# mnemonic for that slot (case-insensitive). Anything else (`.`, ` `,
# `0`, mojibake) is treated as unpressed. The forgiving rule is intentional
# -- different recorders use different placeholders.
.parse_fm2_column <- function(col) {
  if (nchar(col) != 8L) {
    col <- substr(paste0(col, strrep(".", 8L)), 1L, 8L)
  }
  chars <- strsplit(col, "", fixed = TRUE)[[1]]
  toupper(chars) == .NES_BUTTONS
}

#' Read an FCEUX .fm2 movie file
#'
#' Parses the text header into a list and the input log into a logical
#' 3D array indexed `(frame, player, button)`. Buttons are positional in
#' RLDUTSBA order so the output's third dimension lines up with the first
#' eight slots of the universal layout.
#'
#' @param path Path to a .fm2 file.
#' @return A `replayr_movie` object.
#' @export
read_fm2 <- function(path) {
  text <- readLines(path, warn = FALSE, encoding = "UTF-8")
  mv <- .parse_fm2_text(text)
  mv$source_path <- path
  mv
}

# Body of the .fm2 parser: works on a character vector of lines so the
# tests can hit the parser without touching the filesystem.
.parse_fm2_text <- function(lines) {
  header <- list()
  cmd_list <- integer(0)
  # Pre-allocate; we'll trim at the end. Most .fm2 files are <500k frames.
  rows <- vector("list", length(lines))
  rows_n <- 0L
  n_players_seen <- NA_integer_

  for (raw in lines) {
    line <- sub("[\r\n]+$", "", raw)
    if (!nzchar(line)) next
    if (startsWith(line, "|")) {
      parts <- strsplit(line, "|", fixed = TRUE)[[1]]
      # `strsplit` on "|a|b||" gives c("", "a", "b", "", "") in R;
      # drop the leading empty (from the leading pipe) and any trailing
      # empties (from trailing pipes).
      if (length(parts) >= 1L && parts[1L] == "") parts <- parts[-1L]
      while (length(parts) > 0L && parts[length(parts)] == "") {
        parts <- parts[-length(parts)]
      }
      if (length(parts) == 0L) next
      cmd <- suppressWarnings(as.integer(parts[1L]))
      if (is.na(cmd)) cmd <- 0L
      cmd_list <- c(cmd_list, cmd)
      player_cols <- if (length(parts) >= 2L) parts[-1L] else character(0)
      if (is.na(n_players_seen)) {
        n_players_seen <- length(player_cols)
      } else if (length(player_cols) != n_players_seen) {
        # Pad / trim so the array stays rectangular even with malformed lines.
        if (length(player_cols) < n_players_seen) {
          player_cols <- c(player_cols,
                           rep(strrep(".", 8L), n_players_seen - length(player_cols)))
        } else {
          player_cols <- player_cols[seq_len(n_players_seen)]
        }
      }
      rows_n <- rows_n + 1L
      rows[[rows_n]] <- lapply(player_cols, .parse_fm2_column)
    } else {
      stripped <- sub("^[[:space:]]+", "", line)
      if (!nzchar(stripped)) next
      idx <- regexpr("[ \t]", stripped)
      if (idx[1L] == -1L) {
        key <- stripped
        value <- ""
      } else {
        key <- substr(stripped, 1L, idx[1L] - 1L)
        value <- substr(stripped, idx[1L] + 1L, nchar(stripped))
      }
      if (!is.null(header[[key]])) {
        header[[key]] <- paste(header[[key]], value, sep = "\n")
      } else {
        header[[key]] <- value
      }
    }
  }

  rows <- rows[seq_len(rows_n)]
  n_frames <- rows_n
  n_players <- if (is.na(n_players_seen)) 1L else n_players_seen
  inputs <- .empty_inputs(n_frames, n_players, 8L)
  if (n_frames > 0L) {
    for (fi in seq_len(n_frames)) {
      for (pi in seq_len(n_players)) {
        inputs[fi, pi, ] <- rows[[fi]][[pi]]
      }
    }
  }
  commands <- as.integer(cmd_list)
  if (length(commands) != n_frames) {
    # Defensive: clamp to frame count.
    length(commands) <- n_frames
    commands[is.na(commands)] <- 0L
  }
  .new_movie(header = header, commands = commands, inputs = inputs,
             button_mnemonics = .NES_BUTTONS,
             button_names = c("Right", "Left", "Down", "Up",
                              "Start", "Select", "B", "A"))
}
