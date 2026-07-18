# Universal-button layout shared by every parser in this package.
#
# Slots 0..7 (one-based 1..8 in R) are NES-shaped: R, L, D, U, Start, Select,
# B, A. Higher slots cover SNES, Genesis, GBA, N64, PSX, GameCube. Each
# parser fills the prefix it needs; the dispatcher exposes whatever width
# was filled in via the `n_buttons` field.
#
# Single-character mnemonics keep the token-based downstream features
# producing readable strings. Lowercase letters in some slots are used to
# avoid colliding with the NES uppercase mnemonics.

#' Universal button mnemonics
#'
#' One-character symbol per universal-button slot. Length 40. Indexed by
#' slot number using one-based R semantics: slot 1 = "R" (Right),
#' slot 8 = "A", and so on. Slots 31..40 are the Intellivision /
#' ColecoVision numeric keypad (digits 0-9). INTV's Enter/Clear and
#' Coleco's Star/Pound do not have dedicated slots — they fold into
#' Start (slot 5) and Select (slot 6) since they're functionally
#' Start/Select on those platforms (pressed once at boot).
#'
#' \if{html}{\figure{universal_buttons_layout.svg}{options: width=720 alt="replayr universal-button layout: gamepad slots 1-30 plus INTV/Coleco numeric-keypad slots 31-40"}}
#'
#' @return Character vector of length 40.
#' @export
#' @seealso [universal_button_names()]
#' @examples
#' universal_buttons()
universal_buttons <- function() {
  c(
    "R", "L", "D", "U",      # 1-4   d-pad
    "T", "S",                # 5-6   Start, Select
    "B", "A",                # 7-8   primary action buttons
    "x", "y",                # 9-10  SNES X / Y face buttons + INTV "Top"
    "p", "q",                # 11-12 SNES / GBA shoulder L / R + INTV/Coleco side action
    "C", "Z",                # 13-14 Genesis C / N64 Z (and Saturn C/Z)
    "M", "#",                # 15-16 reserved (Mode etc.)
    ">", "<", "v", "^",      # 17-20 N64 C-Right / C-Left / C-Down / C-Up
    "e", "f", "n", "g",      # 21-24 stick quantised: E, NE, N, NW
    "w", "h", "s", "i",      # 25-28 stick quantised: W, SW, S, SE
    "[", "]",                # 29-30 PSX L2 / R2
    # Intellivision / ColecoVision numeric keypad (digits only).
    "0", "1", "2", "3", "4", # 31-35 keypad 0-4
    "5", "6", "7", "8", "9"  # 36-40 keypad 5-9
  )
}

#' Universal button friendly names
#'
#' Long, human-readable label per slot. Same length as
#' [universal_buttons()] and indexed identically.
#'
#' @return Character vector of length 40.
#' @export
universal_button_names <- function() {
  c(
    "Right", "Left", "Down", "Up", "Start", "Select", "B", "A",
    "X", "Y", "L-shoulder", "R-shoulder", "C", "Z", "Mode", "extra",
    "C-Right", "C-Left", "C-Down", "C-Up",
    "Stick-E", "Stick-NE", "Stick-N", "Stick-NW",
    "Stick-W", "Stick-SW", "Stick-S", "Stick-SE",
    "L2", "R2",
    "Keypad-0", "Keypad-1", "Keypad-2", "Keypad-3", "Keypad-4",
    "Keypad-5", "Keypad-6", "Keypad-7", "Keypad-8", "Keypad-9"
  )
}

#' Names of the supported movie file extensions
#'
#' @return Character vector of file-extensions (lowercase, with leading dot).
#' @export
#' @examples
#' supported_formats()
supported_formats <- function() {
  c(".fm2", ".bk2", ".fcm", ".lsmv", ".gmv", ".vbm",
    ".m64", ".smv", ".pxm", ".pjm", ".dtm", ".lmp")
}

# ----- Internal helpers -----------------------------------------------------

# Build a (frames, players, buttons) logical 3D array initialised to FALSE.
# R's array() with the same shape lets us index `inputs[fi, pi, slot]`.
.empty_inputs <- function(n_frames, n_players, n_buttons) {
  array(FALSE, dim = c(n_frames, n_players, n_buttons))
}

# Construct a `replayr_movie` S3 object. This is the canonical return type
# for every parser in the package.
#
# @param header   Named character vector / list of header key-value pairs.
# @param commands Integer vector, length `n_frames`. Per-frame commands byte.
# @param inputs   Logical 3D array, dim (n_frames, n_players, n_buttons).
# @param source_path Path that produced this movie, or NA_character_.
# @param button_mnemonics  Character vector, one per slot in `inputs`'s
#   third dimension. Length must equal `dim(inputs)[3]`.
# @param button_names Friendly names paired with `button_mnemonics`.
.new_movie <- function(header, commands, inputs, source_path = NA_character_,
                       button_mnemonics = NULL, button_names = NULL) {
  dims <- dim(inputs)
  if (!is.logical(inputs) || length(dims) != 3L) {
    stop("`inputs` must be a logical array with dimensions frames x players x buttons")
  }
  if (dims[2L] < 1L || dims[3L] < 1L) {
    stop("`inputs` must contain at least one player and one button slot")
  }
  if (dims[3L] > length(universal_buttons())) {
    stop("`inputs` has more button slots than the universal layout")
  }
  if (length(commands) != dims[1L]) {
    stop("`commands` length must equal the number of input frames")
  }
  if (is.null(button_mnemonics)) {
    button_mnemonics <- universal_buttons()[seq_len(dims[3L])]
  }
  if (is.null(button_names)) {
    button_names <- universal_button_names()[seq_len(dims[3L])]
  }
  if (length(button_mnemonics) != dims[3L] || length(button_names) != dims[3L]) {
    stop("button mnemonic and name vectors must match the input button dimension")
  }
  obj <- list(
    header = as.list(header),
    commands = as.integer(commands),
    inputs = inputs,
    source_path = source_path,
    button_mnemonics = as.character(button_mnemonics),
    button_names = as.character(button_names)
  )
  class(obj) <- "replayr_movie"
  obj
}
