#' Read any supported movie file by extension
#'
#' Dispatches to the appropriate reader based on the file extension:
#' .fm2 -> [read_fm2()], .bk2 -> [read_bk2()], .fcm -> [read_fcm()],
#' .lsmv -> [read_lsmv()], .gmv -> [read_gmv()], .vbm -> [read_vbm()],
#' .m64 -> [read_m64()], .smv -> [read_smv()], .pxm -> [read_pxm()],
#' .pjm -> [read_pjm()], .dtm -> [read_dtm()], .lmp -> [read_lmp()].
#'
#' Returns a `replayr_movie` regardless of source format. The
#' `header[["_format"]]` field records which parser ran. The
#' `inputs` array is `(n_frames, n_players, n_buttons)`; `n_buttons`
#' varies per platform (8 NES, 12 SNES, 15 Genesis, 28 N64/GC, 30 PSX).
#'
#' @param path Path to a movie file.
#' @return A `replayr_movie` object.
#' @export
#' @seealso [supported_formats()]
read_movie <- function(path) {
  ext <- tolower(tools::file_ext(path))
  switch(ext,
    "fm2"  = read_fm2(path),
    "bk2"  = read_bk2(path),
    "fcm"  = read_fcm(path),
    "lsmv" = read_lsmv(path),
    "gmv"  = read_gmv(path),
    "vbm"  = read_vbm(path),
    "m64"  = read_m64(path),
    "smv"  = read_smv(path),
    "pxm"  = read_pxm(path),
    "pjm"  = read_pjm(path),
    "dtm"  = read_dtm(path),
    "lmp"  = read_lmp(path),
    stop(sprintf("unsupported movie format: .%s (%s)", ext, basename(path)))
  )
}
