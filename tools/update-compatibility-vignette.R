# Run from the package root after editing COMPATIBILITY.md.
catalogue <- readLines("COMPATIBILITY.md", warn = FALSE, encoding = "UTF-8")
stopifnot(identical(catalogue[[1L]], "# Recording compatibility"))
catalogue <- catalogue[-1L]
catalogue <- sub(
  "Component-level provenance is recorded in [inst/COPYRIGHTS](inst/COPYRIGHTS).",
  "Component-level provenance is included in the installed package; locate it with `system.file(\"COPYRIGHTS\", package = \"replayr\")`.",
  catalogue,
  fixed = TRUE
)
# The validation folder is not part of the installed package.
catalogue <- sub(
  "](validation/README.md)",
  "](https://github.com/tp451/replayr/tree/main/validation)",
  catalogue,
  fixed = TRUE
)
stopifnot(!any(grepl("](validation/", catalogue, fixed = TRUE)))
header <- c(
  "---",
  'title: "Recording compatibility"',
  "output: rmarkdown::html_vignette",
  "vignette: >",
  "  %\\VignetteIndexEntry{Recording compatibility}",
  "  %\\VignetteEngine{knitr::rmarkdown}",
  "  %\\VignetteEncoding{UTF-8}",
  "---"
)
writeLines(c(header, catalogue), "vignettes/compatibility.Rmd", useBytes = TRUE)
