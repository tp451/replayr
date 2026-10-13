# Do the actions of GoldSrc commands follow the key actions that the same
# demos record as console commands (+attack, -attack and so on)? A console
# command names its action in words; replayr reads the actions of a command
# by the place of their bits. For every demo that holds commands of a player
# and key actions among its console commands, each observation is given the
# state of each key as the last key action before it left it, and that state
# is compared with the action of the observation. The two cannot agree in
# every observation: a key can go down and up between two commands, and the
# game sets some actions itself (the score board of a dead player).
# Usage: Rscript goldsrc-key-actions.R <folder with demos> <result.csv>
# replayr comes from the library paths of the session (R_LIBS).
args <- commandArgs(trailingOnly = TRUE)
suppressMessages(library(replayr))
# Console command of each action, as the Half-Life client names them
# (cl_dll/input.cpp). The client has no key for the actions cancel and run.
spoken <- c(attack = "attack", jump = "jump", duck = "duck", forward = "forward", back = "back", use = "use",
  turn_left = "left", turn_right = "right", move_left = "moveleft", move_right = "moveright",
  attack2 = "attack2", reload = "reload", alt1 = "alt1", score = "showscores")
totals <- matrix(0, length(spoken), 5L, dimnames = list(names(spoken),
  c("demos", "observations", "agreeing", "held_by_key", "held_by_action")))
used <- 0L
for (path in list.files(args[1], pattern = "[.]dem$", full.names = TRUE)) {
  movie <- tryCatch(suppressWarnings(read_dem(path)), error = function(e) NULL)
  if (is.null(movie) || !isTRUE(movie$header$playerCommands)) next
  commands <- movie$console_commands[movie$console_commands$key_action, ]
  if (!nrow(commands)) next
  used <- used + 1L
  states <- player(movie)
  # Sections count their seconds anew; the order is by section, then by time.
  place <- movie$timing$section * 1e7 + movie$timing$section_seconds
  named <- sub("^[+-]", "", sub(" .*$", "", commands$command))
  for (action in names(spoken)) {
    mine <- commands[named == spoken[[action]], ]
    if (!nrow(mine)) next
    last <- findInterval(place, mine$section * 1e7 + mine$section_seconds)
    down <- substr(mine$command, 1L, 1L) == "+"
    held <- last > 0L & down[pmax(last, 1L)]
    acted <- states[, paste0("action_", action)]
    totals[action, ] <- totals[action, ] + c(1, length(acted), sum(held == acted), sum(held), sum(acted))
  }
}
result <- data.frame(action = rownames(totals), console_command = paste0("+", spoken), totals, row.names = NULL)
result$agreement <- round(result$agreeing / result$observations, 4)
# The number of demos that were checked, the same in every row.
result$demos_with_key_actions <- used
write.csv(result, args[2], row.names = FALSE)
cat("demos with key actions among their console commands:", used, "\n")
print(result, row.names = FALSE)
