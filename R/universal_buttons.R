.legacy_buttons <- function() {
  c(
    "R", "L", "D", "U", # 1-4   d-pad
    "T", "S", # 5-6   Start, Select
    "B", "A", # 7-8   primary action buttons
    "x", "y", # 9-10  SNES X / Y face buttons + INTV "Top"
    "p", "q", # 11-12 SNES / GBA shoulder L / R + INTV/Coleco side action
    "C", "Z", # 13-14 Genesis C / N64 Z (and Saturn C/Z)
    "M", "#", # 15-16 reserved (Mode etc.)
    ">", "<", "v", "^", # 17-20 N64 C-Right / C-Left / C-Down / C-Up
    "e", "f", "n", "g", # 21-24 stick quantised: E, NE, N, NW
    "w", "h", "s", "i", # 25-28 stick quantised: W, SW, S, SE
    "[", "]", # 29-30 PSX L2 / R2
    # Intellivision / ColecoVision numeric keypad (digits only).
    "0", "1", "2", "3", "4", # 31-35 keypad 0-4
    "5", "6", "7", "8", "9", # 36-40 keypad 5-9
    "j", "k", # 41-42 L3 / R3 stick clicks
    "E", "F", "G", "H", "I", "J", "K", "N", "O", "P", # 43-52 named peripheral controls
    "Q", "V", "W", "X", "Y", "t", "u", "z", "$", "%", "&", "*", "(", ")", "?", "=", "~" # 53-69 additional named controls
  )
}
.legacy_button_names <- function() {
  c(
    "Right", "Left", "Down", "Up", "Start", "Select", "B", "A",
    "X", "Y", "L-shoulder", "R-shoulder", "C", "Z", "Mode", "extra",
    "C-Right", "C-Left", "C-Down", "C-Up",
    "Stick-E", "Stick-NE", "Stick-N", "Stick-NW",
    "Stick-W", "Stick-SW", "Stick-S", "Stick-SE",
    "L2", "R2",
    "Keypad-0", "Keypad-1", "Keypad-2", "Keypad-3", "Keypad-4",
    "Keypad-5", "Keypad-6", "Keypad-7", "Keypad-8", "Keypad-9",
    "L3", "R3", "D", "Attack", "Jump", "Gun trigger", "Offscreen shot",
    "Mouse left", "Mouse middle", "Mouse right", "Missile", "View change",
    paste("Power Pad", 1:12), "Arcade button 7", "Jump/Start", "Kick", "Punch", "Microphone"
  )
}
#' Names of the supported movie file extensions
#'
#' @return Character vector of file-extensions (lowercase, with leading dot).
#' @export
#' @examples
#' supported_formats()
supported_formats <- function() {
  c(
    ".fm2", ".bk2", ".fcm", ".lsmv", ".gmv", ".vbm",
    ".m64", ".smv", ".pxm", ".pjm", ".dtm", ".lmp",
    ".fm3", ".fmv", ".bkm", ".tas", ".tasproj", ".gbmv", ".mmv", ".dsm",
    ".mc2", ".mcm", ".ymv", ".ctm", ".gzm", ".zmv", ".mar",
    ".ltm", ".wtf", ".hgm", ".jrsr", ".omr", ".ctas", ".fbm", ".dft"
  )
}
# ----- Internal helpers -----------------------------------------------------
# Build a (frames, players, buttons) logical 3D array initialised to FALSE.
# R's array() with the same shape lets us index `inputs[fi, pi, slot]`.
.empty_inputs <- function(n_frames, n_players, n_buttons) {
  array(FALSE, dim = c(n_frames, n_players, n_buttons))
}
# Construct the internal movie representation. Public readers finish it with
# .configure_movie(), which assigns compact layouts or an ordered poll stream.
#
# @param header   Named character vector / list of header key-value pairs.
# @param commands Integer vector, length `n_frames`. Per-frame commands byte.
# @param inputs   Logical 3D array, dim (n_frames, n_players, n_buttons).
# @param source_path Path that produced this movie, or NA_character_.
# @param button_mnemonics  Character vector, one per slot in `inputs`'s
#   third dimension. Length must equal `dim(inputs)[3]`.
# @param button_names Friendly names paired with `button_mnemonics`.
.new_movie <- function(header, commands, inputs, source_path = NA_character_,
                       button_mnemonics = NULL, button_names = NULL,
                       analog = NULL, analog_mode = "raw", decoded_button_slots = NULL) {
  dims <- dim(inputs)
  if (!is.logical(inputs) || length(dims) != 3L) {
    stop("`inputs` must be a logical array with dimensions frames x players x buttons")
  }
  if (dims[2L] < 1L || dims[3L] < 1L) {
    stop("`inputs` must contain at least one player and one button slot")
  }
  if (dims[3L] > length(.legacy_buttons())) {
    stop("`inputs` has more button slots than the universal layout")
  }
  if (length(commands) != dims[1L]) {
    stop("`commands` length must equal the number of input frames")
  }
  if (is.null(button_mnemonics)) {
    button_mnemonics <- .legacy_buttons()[seq_len(dims[3L])]
  }
  if (is.null(button_names)) {
    button_names <- .legacy_button_names()[seq_len(dims[3L])]
  }
  if (length(button_mnemonics) != dims[3L] || length(button_names) != dims[3L]) {
    stop("button mnemonic and name vectors must match the input button dimension")
  }
  if (is.null(analog)) analog <- .empty_analog(dims[1L], dims[2L])
  if (!is.list(analog) || length(analog) != dims[2L] ||
    any(!vapply(analog, function(x) is.matrix(x) && is.numeric(x) &&
      nrow(x) == dims[1L] &&
      (ncol(x) == 0L || !is.null(colnames(x))), logical(1)))) {
    stop("analog must contain one named numeric matrix per player and input row")
  }
  analog_mode <- match.arg(analog_mode, c("raw", "quantized"))
  obj <- list(
    header = as.list(header),
    commands = as.integer(commands),
    inputs = inputs,
    source_path = source_path,
    button_mnemonics = as.character(button_mnemonics),
    button_names = as.character(button_names),
    analog = analog,
    analog_mode = analog_mode,
    decoded_button_slots = decoded_button_slots
  )
  class(obj) <- "replayr_movie"
  obj
}
# Numeric channels retain their source units; absent channels have zero columns.
.empty_analog <- function(n_frames, n_players, channels = character()) {
  lapply(seq_len(n_players), function(i) {
    matrix(NA_real_, n_frames, length(channels),
      dimnames = list(NULL, channels)
    )
  })
}
