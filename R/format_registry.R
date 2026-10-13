# One row for each file extension and format: the reader that takes it, the
# emulator or program that writes such files, and the platform where the
# format serves one console. read_movie(), the listing of ZIP archives,
# supported_formats() and recording_info() take what they know about formats
# from this table, so a new format is entered here once. The extension txt
# has two rows: the tables of two published data sets, which are told apart
# by their first line (read_txt.R).
.FORMAT_REGISTRY <- data.frame(
  extension = c(
    "fm2", "bk2", "fcm", "lsmv", "gmv", "vbm", "m64", "smv", "pxm", "pjm", "dtm", "lmp",
    "fm3", "fmv", "bkm", "tas", "tasproj", "gbmv", "mmv", "dsm", "mc2", "mcm", "ymv",
    "ctm", "gzm", "zmv", "mar", "ltm", "wtf", "hgm", "jrsr", "omr", "ctas", "fbm", "dft",
    "dem", "txt", "txt"
  ),
  reader = c(
    "read_fm2", "read_bk2", "read_fcm", "read_lsmv", "read_gmv", "read_vbm", "read_m64",
    "read_smv", "read_pxm", "read_pjm", "read_dtm", "read_lmp",
    "read_fm3", "read_fmv", "read_bkm", "read_tas", "read_tasproj", "read_gbmv", "read_mmv",
    "read_dsm", "read_mc2", "read_mcm", "read_ymv",
    "read_ctm", "read_gzm", "read_zmv", "read_mar", "read_ltm", "read_wtf", "read_wtf",
    "read_jrsr", "read_omr", "read_ctas", "read_fbm", "read_dft", "read_dem",
    "read_txt", "read_txt"
  ),
  emulator = c(
    "FCEUX", "BizHawk", "FCEU", "lsnes", "Gens", "VisualBoyAdvance", "Mupen64", "Snes9x",
    "PCSX", "PSXjin", "Dolphin", "Doom engines",
    "FCEUX TAS Editor", "Famtasia", "BizHawk (legacy text)", "BizHawk (early text)",
    "BizHawk TAStudio", "GBAHawk", "Dega", "DeSmuME", "PCEjin and VBjin", "Mednafen", "Yabause",
    "Citra", "gz (The Legend of Zelda: Ocarina of Time)", "ZSNES", "MAME-RR", "libTAS",
    "Hourglass", "Hourglass",
    "JPC-RR", "openMSX", "CoffeeTools (UFO 50)", "FinalBurn Alpha", "Dustmod (Dustforce DX)",
    "GoldSrc engine", "Atari Grand Challenge data set", "Atari-HEAD data set"
  ),
  platform = c(
    "NES", NA, "NES", NA, "GEN", NA, "N64", "SNES", "PSX", "PSX", NA, "PC",
    "NES", "NES", NA, NA, NA, NA, NA, "NDS", NA, NA, "SAT",
    "3DS", "N64", "SNES", "Arcade", "PC", "PC", "PC", "PC", "MSX", "PC", "Arcade", "PC", "PC",
    "A26", "A26"
  ),
  stringsAsFactors = FALSE
)
# The extension that names the file structure. Five extensions have the
# structure of another format, whose reader reads their files too: TAStudio
# projects and GBAHawk recordings are BK2 archives, early BizHawk text
# recordings are BKM files, a TAS Editor project begins with an FM2
# recording, and HGM is the second extension of Hourglass. The two formats
# under txt have names of their own, which are no extensions.
.FORMAT_REGISTRY$structure <- .FORMAT_REGISTRY$extension
.FORMAT_REGISTRY$structure[match(c("tasproj", "gbmv", "tas", "fm3", "hgm"), .FORMAT_REGISTRY$extension)] <-
  c("bk2", "bk2", "bkm", "fm2", "wtf")
.FORMAT_REGISTRY$structure[.FORMAT_REGISTRY$extension == "txt"] <- c("atari_gc", "atari_head")
# The extensions that several formats share: the content of a file decides.
.shared_extension <- function(extension) sum(.FORMAT_REGISTRY$extension == extension) > 1L
# The structures a name stands for: that of an extension, each of those
# under an extension that formats share, or the structure the name is.
.format_structures <- function(name) {
  unique(.FORMAT_REGISTRY$structure[.FORMAT_REGISTRY$extension == name | .FORMAT_REGISTRY$structure == name])
}
# The reader of an extension, or of a format that is named by its structure;
# NULL where the name stands for none.
.format_reader <- function(name) {
  name <- tolower(name)
  rows <- which(.FORMAT_REGISTRY$extension == name)
  if (!length(rows)) rows <- which(.FORMAT_REGISTRY$structure == name)
  reader <- unique(.FORMAT_REGISTRY$reader[rows])
  if (length(reader) != 1L) return(NULL)
  get(reader, envir = asNamespace("replayr"), mode = "function")
}
# Formats whose files begin with a fixed signature, as their readers require
# it. FM3 projects begin as FM2 movies do.
.FORMAT_SIGNATURES <- list(
  fcm = charToRaw("FCM\x1a"), smv = charToRaw("SMV\x1a"), vbm = charToRaw("VBM\x1a"),
  m64 = charToRaw("M64\x1a"), dtm = charToRaw("DTM\x1a"), fmv = charToRaw("FMV\x1a"),
  gmv = charToRaw("Gens Movie TEST"), pxm = charToRaw("PXM "), pjm = charToRaw("PJM "),
  mmv = c(charToRaw("MMV"), as.raw(0L)), mcm = charToRaw("MDFNMOVI"), zmv = charToRaw("ZMV"),
  ctm = charToRaw("CTM\x1b"), ctas = charToRaw("CTAS"), wtf = as.raw(c(0x66, 0x54, 0x77, 0x02)),
  jrsr = charToRaw("JRSR"), mar = c(charToRaw("MAMETAS"), as.raw(0L)), fbm = charToRaw("FB1 "),
  dem = charToRaw("HLDEMO"),
  fm2 = charToRaw("version 3")
)
# Two names with one file structure: a file of one is read by the reader of
# the other. An extension that formats share is of the family of each.
.same_format_family <- function(a, b) {
  identical(a, b) || length(intersect(.format_structures(a), .format_structures(b))) > 0L
}
# The format a file shows by its content, or NA where it shows none. Only
# positive signs count: a signature at the start of the file, the members of
# a BizHawk or lsnes ZIP archive, the header lines of a BizHawk text movie,
# the document type of a compressed openMSX replay, and the first line of a
# table of the two Atari data sets. Formats without such
# a sign (Doom demos, gz macros, the text movies of DeSmuME, PCEjin, VBjin
# and Yabause, and the tar archives of libTAS and Dustmod) are not guessed.
.sniff_format <- function(path) {
  start <- readBin(path, "raw", 16L)
  for (format in names(.FORMAT_SIGNATURES)) {
    signature <- .FORMAT_SIGNATURES[[format]]
    if (length(start) >= length(signature) && identical(start[seq_along(signature)], signature)) return(format)
  }
  if (.is_zip_archive(path)) {
    members <- tryCatch(basename(zip::zip_list(path)$filename), error = function(e) character())
    if (any(members %in% c("Input Log.txt", "Input Log"))) return("bk2")
    if ("input" %in% members && any(c("gametype", "controlsversion") %in% members)) return("lsmv")
    return(NA_character_)
  }
  if (.is_gzip_file(path)) {
    con <- gzfile(path, "rb")
    on.exit(close(con))
    inner <- tryCatch(suppressWarnings(readBin(con, "raw", 256L)), error = function(e) raw())
    inner <- rawToChar(inner[inner != as.raw(0L)])
    if (grepl("openmsx-serialize|<serial", inner, useBytes = TRUE)) return("omr")
    return(NA_character_)
  }
  header <- readBin(path, "raw", 4096L)
  if (length(header) && !any(header == as.raw(0L))) {
    header <- rawToChar(header)
    if (grepl("(^|\n)MovieVersion BizHawk", header, useBytes = TRUE) &&
      grepl("(^|\n)Platform ", header, useBytes = TRUE)) return("bkm")
    return(.table_format(strsplit(header, "\r?\n")[[1L]][1L]))
  }
  NA_character_
}
# The `format` argument of read_movie(): an extension with or without its
# dot, or the name of a format under an extension that formats share.
.format_argument <- function(format) {
  valid <- is.character(format) && length(format) == 1L && !is.na(format)
  chosen <- if (valid) sub("^[.]", "", tolower(format)) else ""
  if (!chosen %in% c(.FORMAT_REGISTRY$extension, .FORMAT_REGISTRY$structure)) {
    stop("format must be one of the extensions of supported_formats(), such as \"fm2\", ",
      "or \"atari_gc\" or \"atari_head\".", call. = FALSE)
  }
  chosen
}
# The format read_movie() reads a file as: an extension, the name of a
# format under an extension that formats share, or "zip" for an archive that
# is searched for recordings. An error says why a file has none.
.chosen_format <- function(path, format = NULL) {
  ext <- tolower(tools::file_ext(path))
  if (!is.null(format)) {
    chosen <- .format_argument(format)
  } else {
    shown <- .sniff_format(path)
    # A ZIP file is searched for recordings unless it is itself one.
    if (ext == "zip" && !shown %in% c("bk2", "lsmv")) return("zip")
    if (ext %in% .FORMAT_REGISTRY$extension && !.shared_extension(ext)) {
      if (!is.na(shown) && !.same_format_family(ext, shown)) {
        stop(sprintf(
          "%s has the extension .%s but the signature of a .%s recording. Use format = \"%s\" to read it as one.",
          basename(path), ext, shown, shown
        ), call. = FALSE)
      }
      chosen <- ext
    } else if (!is.na(shown)) {
      chosen <- shown
    } else if (.shared_extension(ext)) {
      chosen <- ext
    } else {
      stop(sprintf(
        paste0(
          "unsupported movie format: .%s (%s). supported_formats() lists the extensions that are read; ",
          "for a recording under another extension, name its format with `format`."
        ),
        ext, basename(path)
      ), call. = FALSE)
    }
  }
  # An extension that formats share says too little: the content decides.
  if (.shared_extension(chosen)) {
    shown <- .sniff_format(path)
    if (is.na(shown) || !shown %in% .format_structures(chosen)) {
      stop(sprintf(
        "%s shows none of the formats that are read from .%s files: %s.", basename(path), chosen,
        paste(.FORMAT_REGISTRY$emulator[.FORMAT_REGISTRY$extension == chosen], collapse = ", ")
      ), call. = FALSE)
    }
    chosen <- shown
  }
  chosen
}
#' Supported recording formats
#'
#' The package reads 37 file extensions in 33 formats. Five extensions have
#' the file structure of another format. One extension, `.txt`, is that of
#' two formats: the tables of two published data sets of Atari 2600 play,
#' which [read_movie()] tells apart by their first line. Any other `.txt`
#' file is none of them; [recording_format()] says which files of a folder
#' are recordings.
#'
#' @param details `FALSE` (default) returns the file extensions. `TRUE` returns
#'   a table of the formats.
#' @return Character vector of file extensions in lower case with a leading
#'   dot. With `details = TRUE`, a data frame with one row per extension and
#'   format (two rows for `.txt`):
#'   `extension`, `structure` (the extension that names the file structure:
#'   the extension itself, except that TAStudio projects and GBAHawk
#'   recordings are BK2 archives, early BizHawk TAS recordings are BKM files,
#'   FCEUX TAS Editor projects begin with an FM2 recording, and HGM is a
#'   second extension of Hourglass WTF; the two formats under `.txt` have the
#'   names `atari_gc` and `atari_head`), `reader` (the function that reads
#'   it; [read_movie()] calls it for a file of that format), `emulator`
#'   (the emulator or program that writes such files, with its game in
#'   brackets where it serves a single game, or the data set whose tables
#'   they are) and `platform` (the
#'   platform code of [recording_info()] where the format serves one console,
#'   otherwise `NA`: the recording names its platform).
#' @export
#' @examples
#' supported_formats()
#' head(supported_formats(details = TRUE))
supported_formats <- function(details = FALSE) {
  if (!is.logical(details) || length(details) != 1L || is.na(details))
    stop("details must be TRUE or FALSE", call. = FALSE)
  extensions <- paste0(".", .FORMAT_REGISTRY$extension)
  if (!details) return(unique(extensions))
  # A structure that is no extension has no dot.
  dots <- ifelse(.FORMAT_REGISTRY$structure %in% .FORMAT_REGISTRY$extension, ".", "")
  data.frame(
    extension = extensions, structure = paste0(dots, .FORMAT_REGISTRY$structure),
    reader = .FORMAT_REGISTRY$reader,
    emulator = .FORMAT_REGISTRY$emulator, platform = .FORMAT_REGISTRY$platform,
    stringsAsFactors = FALSE
  )
}
