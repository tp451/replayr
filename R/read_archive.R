.movie_archive_listing <- function(path) {
  listing <- zip::zip_list(path)
  formats <- tolower(tools::file_ext(listing$filename))
  supported <- c("fm2", "fm3", "bk2", "bkm", "tas", "tasproj", "gbmv", "fcm", "lsmv", "gmv",
    "vbm", "m64", "smv", "pxm", "pjm", "dtm", "lmp", "fmv", "mmv", "dsm", "mc2", "mcm", "ymv",
    "ltm", "wtf", "hgm", "jrsr", "omr", "ctm", "ctas", "fbm", "mar", "zmv", "gzm", "dft")
  take <- formats %in% supported
  data.frame(member = listing$filename[take], format = formats[take],
    bytes = listing$uncompressed_size[take], type = listing$type[take],
    stringsAsFactors = FALSE)
}

#' List input recordings in a ZIP archive
#'
#' Some published downloads contain several recordings. Inspect their member
#' names, then pass one as `member` to [read_movie()]. ZIP-based emulator formats
#' such as BK2 use their normal extension and format-specific reader.
#' @param path ZIP archive path.
#' @return Data frame with member, format, and uncompressed byte count.
#' @export
movie_members <- function(path) {
  .movie_archive_listing(path)[c("member", "format", "bytes")]
}

.read_movie_archive <- function(path, analog, deadzone, triggers, member = NULL, ...) {
  listing <- .movie_archive_listing(path)
  if (is.null(member)) {
    if (nrow(listing) != 1L) stop("Archive contains ", nrow(listing),
      " recording members. Use movie_members(path), then read_movie(path, member = ...).", call. = FALSE)
    member <- listing$member[1L]
  }
  if (!is.character(member) || length(member) != 1L || is.na(member) ||
      !nzchar(member) || !member %in% listing$member)
    stop("member must name an input recording returned by movie_members()", call. = FALSE)
  # miniz locates member names without case sensitivity. Reject collisions so
  # a selected regular file cannot resolve to a different member or a symlink.
  if (sum(tolower(listing$member) == tolower(member)) != 1L)
    stop("Duplicate archive member names are ambiguous, including case-only differences", call. = FALSE)
  chosen <- listing[match(member, listing$member), , drop = FALSE]
  if (is.na(chosen$type) || chosen$type != "file")
    stop("The selected archive member must be a regular file", call. = FALSE)

  # ZIP paths use forward slashes. Flatten them before extraction, and exclude
  # names that could denote a Windows device or alternate data stream.
  leaf <- basename(member)
  if (grepl("\\\\", member) || !nzchar(leaf) || leaf %in% c(".", "..") ||
      grepl("[[:cntrl:]:]", leaf) ||
      grepl("^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])([.]|$)", leaf, ignore.case = TRUE))
    stop("The selected archive member has an unsafe file name", call. = FALSE)
  scratch <- tempfile("replayr-archive-")
  if (!dir.create(scratch, mode = "0700")) stop("Cannot create archive extraction directory", call. = FALSE)
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
  scratch <- normalizePath(scratch, winslash = "/", mustWork = TRUE)
  # Unlike unz() and utils::unzip(), this extractor verifies each member's CRC.
  # It can leave a partial file on error; the private directory is always removed.
  extracted <- zip::unzip(path, files = member, junkpaths = TRUE,
    exdir = scratch, overwrite = FALSE)
  if (nrow(extracted) != 1L || extracted$type != "file")
    stop("Archive extraction did not produce one regular file", call. = FALSE)
  target <- normalizePath(extracted$path, winslash = "/", mustWork = TRUE)
  if (dirname(target) != scratch || basename(target) != leaf ||
      isTRUE(file.info(target)$isdir) || file.info(target)$size != chosen$bytes)
    stop("Archive extraction produced an unexpected file", call. = FALSE)
  movie <- read_movie(target, analog = analog, deadzone = deadzone, triggers = triggers, ...)
  movie$source_path <- path
  movie$source_member <- member
  movie
}
