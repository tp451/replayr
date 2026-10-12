#' Align compact controller matrices by stable button identity
#'
#' Use this explicitly before comparing different controllers. Missing controls
#' are filled with `FALSE`, which makes an absent control equivalent to an
#' unpressed one for the subsequent analysis. This is a modelling choice.
#' For comparisons of game actions, map the aligned controls to an action
#' vocabulary instead of assuming the same physical button has the same role.
#'
#' @param movies Nonempty list of [replayr_movie] objects.
#' @param ids Numeric or character IDs from [button_layout()] to retain, in output order. Defaults to the
#'   union of controls present in the movies, with registered controls first. Controls outside this
#'   selection are omitted deliberately.
#' @param idx One-based player index, used for every movie.
#' @return List of logical matrices with matching columns and stable ID metadata.
#' @export
#' @examples
#' paths <- system.file("extdata", c("sample.fm2", "sample.smv"), package = "replayr")
#' movies <- lapply(paths, read_movie)
#' aligned <- align_buttons(movies)
#' vapply(aligned, ncol, integer(1))
align_buttons <- function(movies, ids = NULL, idx = 1L) {
  if (!is.list(movies) || !length(movies) ||
      !all(vapply(movies, inherits, logical(1), "replayr_movie"))) {
    stop("movies must be a nonempty list of replayr_movie objects.", call. = FALSE)
  }
  layouts <- lapply(movies, button_layout)
  registry <- .controller_registry()
  for (layout in layouts) {
    shared <- match(layout$id,registry$id)
    found <- which(!is.na(shared))
    if (length(found) && any(layout$key[found] != registry$key[shared[found]]))
      stop("Conflicting stable control identities",call.=FALSE)
    registry <- rbind(registry,layout[is.na(shared),names(registry),drop=FALSE])
  }
  if (is.null(ids)) {
    present <- unique(unlist(lapply(layouts, `[[`, "id")))
    ids <- registry$id[registry$id %in% present]
  }
  if ((!is.numeric(ids) && !is.character(ids)) || anyNA(ids) ||
      anyDuplicated(ids) || any(!ids %in% registry$id)) {
    stop("ids must be distinct stable button IDs from button_layout().", call. = FALSE)
  }
  selected <- registry[match(ids,registry$id),,drop=FALSE]
  result_list <- lapply(seq_along(movies), function(i) {
    source <- player(movies[[i]], idx)
    result <- matrix(FALSE, nrow(source), length(ids),
                     dimnames = list(rownames(source), selected$mnemonic))
    positions <- match(ids, layouts[[i]]$id)
    found <- which(!is.na(positions))
    if (length(found)) result[, found] <- source[, positions[found], drop = FALSE]
    attr(result, "button_ids") <- ids
    attr(result, "button_keys") <- selected$key
    attr(result, "button_names") <- selected$name
    result
  })
  stats::setNames(result_list, names(movies))
}
