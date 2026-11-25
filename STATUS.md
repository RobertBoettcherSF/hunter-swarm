# Hunter Swarm

- Repo: https://github.com/RobertBoettcherSF/hunter-swarm (public)
- Live: commit-pinned githack page (the URL is on the pull request). Pages is wired and not enabled.
- Test: `./run-tests.sh`. Local page: open `docs/index.html` after `./build.sh`. The stamp in that file matches `docs/version.txt`.
- What: self-playing maze chase. Rules and both AIs are plain Ada compiled to WebAssembly. The page draws, takes buttons, and downloads reports.
- Status (2026-11-25): round 8. The page shows Level 1 at the start of a game, adds one when a level clears, and returns to Level 1 when a new game starts. That number is `custom.level` in the reports. Two ghosts closing on the eater's corridor, while a junction is still open, pull the eater toward a tunnel, a loop, or a power pellet. The dice still picks the step. Stamp is the string in `version.txt` (v0.8).
- SPARK: not started (D-008). No proof run.
- Gap: none recorded against D-005, D-007, D-025, or D-027. Wasm checks are off on purpose (D-027); `./run-tests.sh` runs the contracts.
- Next: none agreed. Open questions are below.
- Docs: `README.md`, `STATUS.md`

## Notes

- The maze is 19 by 21. A row at mid-height wraps left to right, and a column at mid-width wraps top to bottom. Ghosts move at half pace in either tunnel. There is no dead-end corridor. A pen in the centre holds all four ghosts. The eater is a rounded square. The ghosts are Wisp, Bramble, Cinder and Mote (diamond, triangle, hexagon, hollow square).
- Grid seed 0 paints the fixed maze, then applies the tunnels, the pen, and the open corridors. Any other grid seed carves a connected maze (rooms on the odd cells, a spanning set of corridors, a few extra loops) and then the same three fixes, with one power pellet in each quarter. Eater seed picks the opening cell and the eater's tie-break. Ghost seed is the 0..3 role bias. Ghost movement does not read the eater seed.
- Each tick the eater scores the open steps. The shortest path to the nearest ordinary pellet dominates, and the dice runs only for a near tie. If two ghosts are closing on the eater's corridor while a junction is still open, that exit outscores food and the dice takes it. If a ghost is near and a power pellet is closer than that ghost, that pellet is the step, and the eater then hunts. Ghosts hold their distance while the eater can still reach an uneaten power pellet. While the eater is powered they flee on different headings and avoid standing where a chain can catch them. Each level shortens the fright, adds a few extra ghost steps outside the tunnels, and raises the closing and blocking weights. Those three numbers are in the report. Lives are not refilled between levels. Once the ordinary pellets are gone the level clears and the score and the lives carry onto the next grid.
- Host parameters are the nine integers in `Swarm` (`danger_radius` through `ghost_stride`). Other knobs (`Pellet_Points`, `Initial_Lives`, `Tick_Cap`, `Log_Gap`) sit at the top of the private part of `swarm.ads` and are copied into every report.
- v0.3 scans, kept for the record. Hand-made maze: 36 / 160 wins, mean score 2334, mean pellets left 8, 8 tick-cap games. Generated mazes: 30 / 160 wins, mean score 6109, mean pellets left 19, 8 tick-cap games. Round 4 does not add another scan.
- Reports are `hunter-swarm-report` v1 JSON. Stop, level clear, and game end each download an eater file and a ghost-team file. F9 / Debug pauses, asks what you expected, and downloads the full report. Both reports number the level, the longest no-eat gap, and wasted steps per pellet to one decimal. `pellets_left` counts ordinary pellets. `powers_left` counts power pellets. There is no extra life between levels. The eater report's `custom.why_died` lists each death. Both reports list the dice weights and the level's fright, haste, and weight. If 80 ticks pass with no pellet and no death, both reports include `loop_detected` with the positions. The summary lines `BUILD`, `TEST KEY`, and `SUMMARY` live in `custom.summary`.
- The browser build is `-gnatp` (D-027). `./run-tests.sh` is the native `-gnata -gnatwa -gnatwe` smoke, statically linked. It plays one game, checks the replay hash, and checks that all four report kinds contain the required fields.
- Last-chance handler is wasm-only (`src/wasm`), so it does not replace the native handler. A failed check in the smoke still prints file and line. The page keeps a crash notice across reload.

## Open questions

1. The food-path weight, the ghost closing and blocking weights, and the 80-tick loop alarm are first guesses. Should any of them change?
2. Are Wisp, Bramble, Cinder, and Mote the names to keep?
3. `why_died` names the committed decision and the killer's distance a few ticks earlier. Is that the note to keep?
4. Five lives and the point values are still the round-1 guesses. The ghosts now leave the pen eight ticks apart.
