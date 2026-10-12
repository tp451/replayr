# Regenerate pkgdown favicon assets from the canonical package logo.
#
# Run from the package root after changing man/figures/logo.svg. pkgdown copies
# the generated files from pkgdown/favicon/ into docs/ during build_site().
if (!requireNamespace("rsvg", quietly = TRUE) ||
  !requireNamespace("magick", quietly = TRUE)) {
  stop("install the 'rsvg' and 'magick' packages before generating favicons")
}
source_svg <- file.path("man", "figures", "logo.svg")
out_dir <- file.path("pkgdown", "favicon")
if (!file.exists(source_svg) || !dir.exists(out_dir)) {
  stop("run this script from the package root")
}
invisible(file.copy(source_svg, file.path(out_dir, "favicon.svg"), overwrite = TRUE))
# Render once at high resolution, then fit it inside square transparent
# canvases without changing the hexagon's aspect ratio.
logo <- magick::image_read_svg(source_svg, width = 1200)
square_icon <- function(size, fill = 0.90) {
  scaled <- magick::image_scale(logo, paste0("x", floor(size * fill)))
  magick::image_extent(
    scaled,
    geometry = sprintf("%dx%d", size, size),
    gravity = "center",
    color = "none"
  )
}
png_assets <- c(
  "favicon-96x96.png" = 96L,
  "apple-touch-icon.png" = 180L,
  "web-app-manifest-192x192.png" = 192L,
  "web-app-manifest-512x512.png" = 512L
)
for (filename in names(png_assets)) {
  size <- unname(png_assets[[filename]])
  magick::image_write(
    square_icon(size),
    path = file.path(out_dir, filename),
    format = "png"
  )
}
# A multi-resolution ICO keeps browser tabs sharp at common Windows sizes.
ico <- do.call(c, lapply(c(16L, 32L, 48L), square_icon))
magick::image_write(
  ico,
  path = file.path(out_dir, "favicon.ico"),
  format = "ico"
)
message("Generated favicon assets in ", normalizePath(out_dir))
