#' Import an emulator input recording
#'
#' Dispatches by extension to the format-specific reader. Every reader returns
#' compact digital columns, a stable cross-controller ID map, and original numeric
#' channels. A row may be a frame, poll, input event, or tic depending on the format.
#'
#' @param path Recording file path.
#' @param analog Stick representation: `"raw"` (default), `"cardinal4"`,
#'   `"cardinal8"`, `"angle"`, or `"angle+magnitude"`. A scalar applies to both
#'   sticks; `c(left = "cardinal8", right = "angle")` selects them independently.
#'   Cardinal modes add separate left/right logical direction columns. Continuous
#'   modes return numeric fields through [stick_channels()]. Original X/Y values
#'   remain in [analog_channels()] in every mode. Absent sticks add no columns.
#' @param deadzone Radial threshold in centred axis half-range units, from zero
#'   to one. One value applies to both sticks; named left/right values are allowed.
#'   `NULL` uses format defaults: 0.25 for BK2/PSX, 0.125 for M64/DTM.
#'   Neutral observations have no direction and an `NA` angle. Magnitude is kept.
#' @param triggers `"raw"` (default) or `"digital"`. For DTM, digital additionally
#'   projects each analogue trigger at 128/255 into separate L2/R2 columns.
#'   Hardware L/R click bits remain distinct from thresholded analogue triggers.
#' @param ... Reader-specific arguments, such as `controller_order` for M64 or DTM,
#'   or `member` for a recording inside a ZIP archive (see [movie_members()]).
#' @return A [replayr_movie], or a [replayr_poll_stream] for unassigned controller ports or
#'   heterogeneous device polls, as in CTM. Use [button_layout()] for column identities,
#'   [player()] for logical states, and [stick_channels()] for selected stick fields.
#' @export
#' @examples
#' path <- system.file("extdata", "sample.m64", package = "replayr")
#' movie <- read_movie(path, analog = "angle+magnitude")
#' button_layout(movie)
#' head(stick_channels(movie))
read_movie <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", ...) {
  .stick_modes(analog)
  ext <- tolower(tools::file_ext(path))
  if (ext == "zip") return(.read_movie_archive(path, analog, deadzone, triggers, ...))
  reader <- switch(ext,
    fm2 = read_fm2,
    mar = read_mar,
    fbm = read_fbm,
    dft = read_dft,
    zmv = read_zmv,
    gzm = read_gzm,
    ctas = read_ctas,
    ctm = read_ctm,
    tasproj = read_tasproj,
    tas = read_tas,
    fm3 = read_fm3,
    fmv = read_fmv,
    mmv = read_mmv,
    dsm = read_dsm,
    mc2 = read_mc2,
    ymv = read_ymv,
    mcm = read_mcm,
    ltm = read_ltm,
    wtf = read_wtf,
    jrsr = read_jrsr,
    omr = read_omr,
    bkm = read_bkm,
    gbmv = read_gbmv,
    hgm = read_wtf,
    bk2 = read_bk2,
    fcm = read_fcm,
    lsmv = read_lsmv,
    gmv = read_gmv,
    vbm = read_vbm,
    m64 = read_m64,
    smv = read_smv,
    pxm = read_pxm,
    pjm = read_pjm,
    dtm = read_dtm,
    lmp = read_lmp,
    stop(sprintf("unsupported movie format: .%s (%s)", ext, basename(path))))
  reader(path, analog = analog, deadzone = deadzone, triggers = triggers, ...)
}
