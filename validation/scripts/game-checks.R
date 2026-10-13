# The game-specific checks reported in the article, recomputed from the
# recordings themselves.
#
# Usage, from the folder validation of the repository, after retrieve-recordings.R:
#   Rscript scripts/game-checks.R
# Environment: REPLAYR_VALIDATION_ROOT (folder with the recordings),
#   REPLAYR_VALIDATION_MANIFEST (default tables/validation-manifest.csv).
#
# Super Mario Bros.: B makes Mario run, and the two "walkathon" recordings
# 314M and 1332M are played without it. The Legend of Zelda: Up and A on the
# second controller open the save menu, which recording 191M uses.
library(replayr)
root <- Sys.getenv("REPLAYR_VALIDATION_ROOT")
if (!nzchar(root) || !dir.exists(root)) stop("Set REPLAYR_VALIDATION_ROOT to the recording directory.")
manifest <- read.csv(Sys.getenv("REPLAYR_VALIDATION_MANIFEST", "tables/validation-manifest.csv"),
  stringsAsFactors = FALSE, fileEncoding = "UTF-8")
recording <- function(publication) {
  row <- manifest[manifest$publication_id == publication, ][1L, ]
  path <- file.path(root, row$relative_path)
  if (!file.exists(path)) stop("Recording ", publication, "M is not in the recording directory: ", row$relative_path)
  read_movie(path)
}
held <- function(movie, key, controller = 1L) sum(player(movie, controller)[, key])

walkathons <- vapply(c(`314M` = 314, `1332M` = 1332), function(publication) {
  movie <- recording(publication)
  c(A = held(movie, "a"), B = held(movie, "b"), observations = n_observations(movie))
}, numeric(3))
print(walkathons)
stopifnot(all(walkathons["B", ] == 0), identical(unname(walkathons["A", ]), c(3738, 3832)))

zelda <- recording(191)
second <- player(zelda, 2L)
gesture <- second[, "dpad_up"] & second[, "a"]
# An episode begins where the gesture is present and was not in the observation before.
episodes <- sum(gesture & !c(FALSE, gesture[-length(gesture)]))
cat("191M: Up and A together on the second controller in", sum(gesture), "observations,", episodes, "episodes\n")
stopifnot(sum(gesture) == 277, episodes == 7)
cat("The game-specific figures of the article are reproduced.\n")
