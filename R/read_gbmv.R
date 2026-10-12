# GBAHawk and TAStudio retain the BK2 ZIP members and LogKey encoding.
.decode_gbmv <- function(path) {
  movie <- .decode_bk2(path)
  movie$header[["_format"]] <- "gbmv"
  movie
}
.decode_tasproj <- function(path) {
  movie <- .decode_bk2(path)
  # Retain BK2 decoding rules for the selected platform's analogue axes.
  movie$header$sourceContainer <- "tasproj"
  movie
}
