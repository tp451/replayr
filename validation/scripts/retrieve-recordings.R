# Download the recordings of the validation.
#
# Usage, from the folder validation of the repository:
#   Rscript scripts/retrieve-recordings.R [formats] [number]
#   Rscript scripts/retrieve-recordings.R doom [number]
#
# The first form retrieves the TASVideos recordings of
# tables/validation-manifest.csv, for example "fm2,smv 20" for the first twenty
# FM2 and SMV recordings. Without arguments every recording is retrieved:
# 7,385 files, 5.4 GB, about two and a half hours at one request per second.
# The second form retrieves the 352 Doom-engine demos of
# tables/doom-family-comparison.csv from the Doom Speed Demos Archive and
# writes doom-family-manifest.csv into the folder, a manifest of these demos
# for the scripts that compare values.
#
# Environment:
#   REPLAYR_VALIDATION_ROOT      folder to fill (required)
#   REPLAYR_VALIDATION_MANIFEST  default tables/validation-manifest.csv
#   REPLAYR_DOOM_LIST            default tables/doom-family-comparison.csv
#   REPLAYR_RETRIEVAL_INTERVAL   seconds between requests, default 1
#
# Each listed recording has the address of its download and the SHA-256 hash
# of the recording. A download is the recording itself or a ZIP archive
# around it. The file whose hash is the one listed is stored; a recording
# that is already there with the right hash is not requested again, so the
# script can be stopped and started. Nothing is stored that does not match
# its hash.
if (!requireNamespace("digest", quietly = TRUE)) stop("Install digest for SHA256 verification.")
args <- commandArgs(trailingOnly = TRUE)
root <- Sys.getenv("REPLAYR_VALIDATION_ROOT")
if (!nzchar(root)) stop("Set REPLAYR_VALIDATION_ROOT to the folder for the recordings.")
dir.create(root, recursive = TRUE, showWarnings = FALSE)
doom <- length(args) >= 1L && identical(tolower(args[1]), "doom")
if (doom) {
  listed <- read.csv(Sys.getenv("REPLAYR_DOOM_LIST", "tables/doom-family-comparison.csv"),
    stringsAsFactors = FALSE, fileEncoding = "UTF-8", colClasses = "character")
  # Archives of different demos hold members of the same name; the start of
  # the hash keeps the stored files apart.
  manifest <- data.frame(
    relative_path = file.path("doom-family", paste0(substr(listed$sha256, 1L, 12L), "-",
      gsub("[^A-Za-z0-9._-]", "_", listed$member))),
    publication_id = seq_len(nrow(listed)), format = "lmp", sha256 = listed$sha256,
    game = listed$game, longtics = listed$longtics, download_url = listed$source_url,
    stringsAsFactors = FALSE
  )
  if (length(args) >= 2L) manifest <- utils::head(manifest, as.integer(args[2]))
} else {
  manifest <- read.csv(Sys.getenv("REPLAYR_VALIDATION_MANIFEST", "tables/validation-manifest.csv"),
    stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  manifest <- manifest[!duplicated(manifest$sha256), ]
  if (length(args) >= 1L && nzchar(args[1])) {
    manifest <- manifest[manifest$format %in% strsplit(tolower(args[1]), ",", fixed = TRUE)[[1]], ]
  }
  if (length(args) >= 2L) manifest <- utils::head(manifest, as.integer(args[2]))
}
interval <- as.numeric(Sys.getenv("REPLAYR_RETRIEVAL_INTERVAL", "1"))
agent <- "replayr-validation-retrieval (https://github.com/tp451/replayr)"

sha256 <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)
destination <- function(i) file.path(root, manifest$relative_path[i])
present <- function(i) file.exists(destination(i)) && identical(sha256(destination(i)), manifest$sha256[i])
starts_with <- function(path, bytes) identical(readBin(path, "raw", length(bytes)), bytes)
is_zip <- function(path) starts_with(path, as.raw(c(0x50, 0x4b, 0x03, 0x04)))

last_request <- 0
fetch <- function(url, target) {
  for (attempt in 1:5) {
    Sys.sleep(max(0, last_request + interval - as.numeric(Sys.time())))
    last_request <<- as.numeric(Sys.time())
    status <- tryCatch(suppressWarnings(utils::download.file(url, target, mode = "wb", quiet = TRUE,
      headers = c("User-Agent" = agent))), error = function(e) conditionMessage(e))
    if (identical(status, 0L) && file.exists(target) && file.size(target) > 0) return(invisible(TRUE))
    # The site asks for patience when it is busy.
    Sys.sleep(10 * 2^(attempt - 1))
  }
  stop("the download failed five times")
}
# The files a download offers: the download itself and, where it is a ZIP
# archive, each of its members, extracted one by one into folders of their own.
offered <- function(download, scratch) {
  files <- download
  if (is_zip(download)) {
    members <- utils::unzip(download, list = TRUE)
    members <- members$Name[members$Length > 0 & !grepl("/$", members$Name)]
    for (k in seq_along(members)) {
      folder <- file.path(scratch, paste0("member-", k))
      dir.create(folder)
      extracted <- tryCatch(utils::unzip(download, files = members[k], exdir = folder, junkpaths = TRUE),
        warning = function(w) character(), error = function(e) character())
      files <- c(files, extracted)
    }
  }
  files
}

log <- data.frame(publication_id = manifest$publication_id, relative_path = manifest$relative_path,
  status = "", stringsAsFactors = FALSE)
log$status[vapply(seq_len(nrow(manifest)), present, logical(1))] <- "present"
cat(nrow(manifest), "recordings listed,", sum(log$status == "present"), "already present\n")
log_file <- file.path(root, if (doom) "doom-retrieval-log.csv" else "retrieval-log.csv")
urls <- unique(manifest$download_url[log$status == ""])
for (u in seq_along(urls)) {
  rows <- which(manifest$download_url == urls[u] & log$status == "")
  scratch <- tempfile("retrieval-")
  dir.create(scratch)
  outcome <- tryCatch({
    download <- file.path(scratch, "download")
    fetch(urls[u], download)
    start <- readBin(download, "raw", 64L)
    if (grepl("^\\s*<(!doctype|html)", rawToChar(start[start != as.raw(0)]), ignore.case = TRUE, useBytes = TRUE))
      stop("the download is a web page, not a recording")
    files <- offered(download, scratch)
    hashes <- vapply(files, sha256, character(1))
    for (i in rows) {
      match <- files[hashes == manifest$sha256[i]]
      if (!length(match)) {
        log$status[i] <- "no file with the listed hash in the download"
        next
      }
      dir.create(dirname(destination(i)), recursive = TRUE, showWarnings = FALSE)
      file.copy(match[1], destination(i), overwrite = TRUE)
      log$status[i] <- if (present(i)) "retrieved" else "could not be stored"
    }
    NULL
  }, error = function(e) conditionMessage(e))
  if (!is.null(outcome)) log$status[rows] <- outcome
  unlink(scratch, recursive = TRUE)
  if (u %% 25L == 0L || u == length(urls)) {
    utils::write.csv(log, log_file, row.names = FALSE)
    cat(u, "/", length(urls), "downloads;", sum(log$status == "retrieved"), "retrieved,",
      sum(!log$status %in% c("retrieved", "present", "")), "failed\n")
    flush.console()
  }
}
utils::write.csv(log, log_file, row.names = FALSE)
print(table(log$status))
if (doom) {
  stored <- log$status %in% c("retrieved", "present")
  utils::write.csv(manifest[stored, c("relative_path", "publication_id", "format", "sha256", "game", "longtics")],
    file.path(root, "doom-family-manifest.csv"), row.names = FALSE, na = "")
}
if (any(!log$status %in% c("retrieved", "present"))) {
  cat("Recordings that could not be retrieved are listed in", basename(log_file), "\n",
    "A file that was replaced on its site no longer has the listed hash.\n")
}
