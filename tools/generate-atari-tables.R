# Writes two short tables in the layouts of the Atari Grand Challenge data
# set and of Atari-HEAD: inst/extdata/tables/atari-grand-challenge.txt and
# inst/extdata/tables/atari-head.txt. Every row was written for replayr; none
# is taken from either data set. Run from the package root:
#   Rscript tools/generate-atari-tables.R
write_table <- function(lines, name) {
  con <- file(file.path("inst", "extdata", "tables", name), "wb")
  on.exit(close(con))
  writeLines(lines, con, sep = "\n", useBytes = TRUE)
}
dir.create(file.path("inst", "extdata", "tables"), showWarnings = FALSE, recursive = TRUE)
# An episode of 18 frames: right, right with fire, fire, left, left with
# fire, up, up-right, up-right with fire, down, down-left, down-left with
# fire. Two rewards raise the score; the last row ends the game.
actions <- c(0, 0, 3, 3, 11, 11, 1, 0, 4, 4, 12, 2, 6, 14, 5, 9, 17, 0)
rewards <- c(0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 20, 0, 0, 0, 0, 0, 0)
frames <- seq_along(actions) - 1
write_table(c(
  "db traj id : 1", "frame,reward,score,terminal, action",
  sprintf("%d,%d, %d, %s, %d", frames, rewards, cumsum(rewards),
    ifelse(frames == max(frames), "True", "False"), actions)
), "atari-grand-challenge.txt")
# A trial of ten frames in two episodes. The first frame waits 900 ms for
# the player and the seventh 350 ms; two frames have no gaze positions; the
# last row has no values, as the last row of every trial of the data set.
write_table(c(
  "frame_id,episode_id,score,duration(ms),unclipped_reward,action,gaze_positions",
  "EX_1000_1,0,0,900,0,0,80.00,105.00,80.10,105.20",
  "EX_1000_2,0,0,50,0,3,81.00,104.00,82.50,103.10,84.00,102.00",
  "EX_1000_3,0,0,50,0,3,null",
  "EX_1000_4,0,0,51,0,11,90.20,98.00",
  "EX_1000_5,0,10,49,10,1,90.40,97.50,90.60,97.10",
  "EX_1000_6,0,10,50,0,4,88.00,97.00",
  "EX_1000_7,0,10,350,0,7,85.00,96.00,84.00,95.00",
  "EX_1000_8,1,0,50,0,15,null",
  "EX_1000_9,1,0,50,0,5,70.00,120.00",
  "EX_1000_10,null,null,null,null,null,null"
), "atari-head.txt")
