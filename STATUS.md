# Hunter Swarm

- Repo: https://github.com/RobertBoettcherSF/hunter-swarm (public)
- Live: commit-pinned githack page (the URL is on the pull request). Pages is wired and not enabled.
- Test: `./run-tests.sh`. Local page: open `docs/index.html` after `./build.sh`. The stamp in that file matches `docs/version.txt`.
- What: self-playing maze chase. Rules and both AIs are plain Ada compiled to WebAssembly. The page draws, takes buttons, and downloads reports.
- Status (2026-11-25): round 4. Side tunnels wrap at mid-height and slow the ghosts. Corridors connect at both ends, on the hand-made maze and on generated ones. The ghosts start together in a central pen and leave one at a time; a caught ghost returns there. The eater treats tunnels and loops as escapes and avoids a single-exit corridor when a ghost is near. From tick 1500 the ghosts speed up, and from tick 2500 the whole team chases. Stamp is the string in `version.txt` (v0.4).
- SPARK: not started (D-008). No proof run.
- Gap: none recorded against D-005, D-007, D-025, or D-027. Wasm checks are off on purpose (D-027); `./run-tests.sh` runs the contracts.
- Next: none agreed. Open questions are below.
- Docs: `README.md`, `STATUS.md`

## Notes

- The maze is 19 by 21. A row at mid-height wraps from the left edge to the right, and ghosts move at half pace on that row. There is no dead-end corridor: wall stretches get an opening in the middle, and any cell with one exit is joined to another corridor. A pen in the centre holds all four ghosts. The eater is a rounded square. The ghosts are Wisp, Bramble, Cinder and Mote (diamond, triangle, hexagon, hollow square).
- Grid seed 0 paints the fixed maze, then applies the tunnels, the pen, and the open corridors. Any other grid seed carves a connected maze (rooms on the odd cells, a spanning set of corridors, a few extra loops) and then the same three fixes, with one power pellet in each quarter. Eater seed picks the opening cell and the eater's tie-break. Ghost seed is the 0..3 role bias. Ghost movement does not read the eater seed.
- The eater walks to the nearest pellet it can reach before a ghost. It paths around a power pellet unless a hostile ghost's path to the eater is within `danger_radius`, or the eater is cornered. It hunts a frightened ghost only when that ghost is closer than food and the eater has not gone too long without eating. On a tick when the ghosts move after the eater, it treats the cell a hostile ghost occupies, and every cell next to one, as closed if another open cell is safe. When it flees, a tunnel or a loop scores as an escape, and a corridor with no second exit is avoided while a ghost is within `threat_range`. The ghosts share the eater's cell, facing, and pellet counts. One chases, one aims ahead, two split across the quarters with the most food. While the eater is powered they scatter on different compass directions. They begin in the pen and walk out one every eight ticks. A caught ghost walks back to its seat, waits, and comes out again. From tick 1500 their stride drops by one and the two campers chase; from tick 2500 every ghost chases on every tick, still half pace inside a tunnel.
- Host parameters are the nine integers in `Swarm` (`danger_radius` through `ghost_stride`). Other knobs (`Pellet_Points`, `Initial_Lives`, `Tick_Cap`, `Log_Gap`) sit at the top of the private part of `swarm.ads` and are copied into every report.
- v0.3 scans, kept for the record. Hand-made maze: 36 / 160 wins, mean score 2334, mean pellets left 8, 8 tick-cap games. Generated mazes: 30 / 160 wins, mean score 6109, mean pellets left 19, 8 tick-cap games. Round 4 does not add another scan.
- Reports are `hunter-swarm-report` v1 JSON. Stop and game end each download an eater file and a ghost-team file. F9 / Debug pauses, asks what you expected, and downloads the full report. The eater report's `custom.why_died` lists each death: tick, killer, nearby ghosts, open exits, the decision the eater was committed to, and the killer's distance at the start of the tick three before. The summary lines `BUILD`, `TEST KEY`, and `SUMMARY` live in `custom.summary`.
- The browser build is `-gnatp` (D-027). `./run-tests.sh` is the native `-gnata -gnatwa -gnatwe` smoke, statically linked. It plays one game, checks the replay hash, and checks that all four report kinds contain the required fields.
- Last-chance handler is wasm-only (`src/wasm`), so it does not replace the native handler. A failed check in the smoke still prints file and line. The page keeps a crash notice across reload.

## Open questions

1. Ghosts speed up at tick 1500 and the whole team chases from tick 2500. Is that the right moment, or should it happen sooner?
2. Are Wisp, Bramble, Cinder, and Mote the names to keep?
3. `why_died` names the committed decision and the killer's distance a few ticks earlier. Is that the note to keep?
4. Five lives and the point values are still the round-1 guesses. The ghosts now leave the pen eight ticks apart.
