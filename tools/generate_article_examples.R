# Original, deterministic inputs for the software articles. Run from replayr's
# package root. These timelines were designed for illustrating representations;
# they were not transcribed, sampled, or transformed from published recordings.
out <- file.path('inst', 'extdata', 'paper')
dir.create(out, recursive = TRUE, showWarnings = FALSE)
n <- 3600L
t <- seq_len(n)
labels <- strsplit('RLDUTSBA', '')[[1]]
names <- c('Hold', 'Taps', 'Bursts', 'Stops', 'Chords', 'Offset', 'Alternating', 'Variable')
for (j in seq_along(names)) {
  x <- matrix(FALSE, n, 8L)
  x[1, 5] <- TRUE
  x[, 1] <- switch(j,
    t >= 61 & t <= 3300,
    t >= 61 & t <= 3300 & t %% 12 < 6,
    t >= 61 & t <= 3300 & t %% 180 < 120,
    t >= 61 & t <= 3300 & t %% 600 < 480,
    t >= 61 & t <= 3300,
    t >= 61 & t <= 3300,
    t >= 61 & t <= 3300 & t %% 240 < 120,
    t >= 61 & t <= 3300 & t %% 480 < (120 + 30 * ((t %/% 480) %% 5))
  )
  x[, 2] <- j == 7 & t >= 61 & t <= 3300 & !x[, 1]
  x[, 7] <- if (j < 5) t >= 61 & t <= 3300 else t %% 90 < (10 + 4 * j)
  x[, 8] <- if (j == 5) x[, 7] else if (j == 6) (t + 45) %% 90 < 34 else
    t >= 61 & t <= 3300 & t %% (36 + 6 * j) < (3 + j)
  lines <- vapply(seq_len(n), function(i)
    paste0('|0|', paste(ifelse(x[i, ], labels, '.'), collapse = ''), '|||'), character(1))
  writeLines(
    c(
      'version 3', 'emuVersion 22020', 'rerecordCount 0', 'palFlag 0',
      'port0 1', 'port1 0', 'port2 0', 'romFilename artificial-example.nes',
      paste('comment Original artificial timeline:', names[j]), lines
    ),
    file.path(out, paste0(tolower(names[j]), '.fm2')),
    useBytes = TRUE
  )
}
write_zip <- function(path, members) {
  td <- tempfile('replayr-paper-')
  dir.create(td)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)
  for (name in names(members)) {
    fp <- file.path(td, name)
    writeLines(members[[name]], fp, useBytes = TRUE)
    Sys.setFileTime(fp, as.POSIXct('2020-01-01', tz = 'UTC'))
  }
  destination <- normalizePath(path, mustWork = FALSE)
  if (file.exists(destination)) unlink(destination)
  old <- setwd(td)
  on.exit(setwd(old), add = TRUE)
  status <- utils::zip(destination, names(members), flags = '-q -X')
  if (status != 0L) stop('ZIP creation failed')
}
write_zip(file.path(out, 'light-gun.bk2'), list(
  'Header.txt' = c(
    'MovieVersion BizHawk synthetic', 'Platform PSX', 'Core Nymashock',
    'GameName Artificial light-gun example', 'Author Thorben Pelzer'
  ),
  'Input Log.txt' = c(
    '[Input]',
    'LogKey:#Power|#P1 Y Axis|P1 X Axis|P1 Trigger|P1 A|P1 Offscreen Shot|',
    '|.|120,1000,T..|', '|.|128,1100,...|', '|.|136,1200,T..|', '|.|16,0,..O|', '[/Input]'
  )
))
write_zip(file.path(out, 'mouse.bk2'), list(
  'Header.txt' = c(
    'MovieVersion BizHawk synthetic', 'Platform SAT', 'Core Saturnus',
    'GameName Artificial mouse example', 'Author Thorben Pelzer'
  ),
  'Input Log.txt' = c(
    '[Input]',
    'LogKey:#Power|Reset|#P1 Motion Left / Right|P1 Motion Up / Down|P1 Left Button|P1 Middle Button|P1 Right Button|P1 Start|',
    '|..|12,-4,L...|', '|..|8,2,....|', '|..|-3,0,..R.|', '|..|0,0,....|', '[/Input]'
  )
))
# An odd number of polls intentionally rules out automatic two-port pairing.
header <- raw(256)
header[1:4] <- charToRaw('DTM\x1a')
header[5:10] <- charToRaw('ART001')
header[12] <- as.raw(3)
header[14:21] <- c(writeBin(2L, raw(), endian = 'little'), raw(4))
header[22:29] <- c(writeBin(3L, raw(), endian = 'little'), raw(4))
body <- as.raw(c(
  2, 64, 0, 0, 128, 128, 128, 128,
  4, 64, 10, 20, 200, 160, 100, 80,
  0, 192, 0, 0, 128, 128, 128, 128
))
writeBin(c(header, body), file.path(out, 'unassigned.dtm'))
writeLines(
  c(
    '# Artificial article examples', '',
    'These original timelines and peripheral records were created by Thorben',
    'Pelzer for the replayr and pisa software articles. They are distributed',
    'under replayr\'s GPL (>= 2) license. No published replay was used as input.', '',
    'The eight FM2 timelines contain 3,600 observations each. Their names describe',
    'their programmed patterns, rather than games, players, or completed runs.',
    'The BK2 files contain four original light-gun or mouse observations.',
    'The DTM file contains three polls with two enabled, unassigned ports.', '',
    'Regenerate from the package root with:', '',
    '```sh', 'Rscript tools/generate_article_examples.R', '```'
  ),
  file.path(out, 'README.md'),
  useBytes = TRUE
)
cat('Generated eight FM2 timelines, two BK2 peripheral examples, and one DTM poll stream.\n')
