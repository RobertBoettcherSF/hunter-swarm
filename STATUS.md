# Hunter Swarm

- Repo: https://github.com/RobertBoettcherSF/hunter-swarm (public)
- Live: commit-pinned githack page (the URL is on the pull request). Pages is wired and not enabled.
- Test: `./run-tests.sh`. Local page: open `docs/index.html` after `./build.sh`. The stamp in that file matches `docs/version.txt`.
- What: self-playing maze chase. Rules and both AIs are plain Ada compiled to WebAssembly. The page draws, takes buttons, and downloads reports.
- Status (2026-11-25): round 3. The eater no longer steps into a ghost's reach when another exit is open, and it keeps a power pellet unless a ghost is close enough to catch or the eater is cornered. While the eater is powered, the four ghosts scatter in different directions. Stamp is the string in `version.txt` (v0.3).
- SPARK: not started (D-008). No proof run.
- Gap: none recorded against D-005, D-007, D-025, or D-027. Wasm checks are off on purpose (D-027); `./run-tests.sh` runs the contracts.
- Next: none agreed. Open questions are below.
- Docs: `README.md`, `STATUS.md`

## Notes

- The maze is a fixed 19 by 21 corridor map. It is not a cabinet layout. The eater is a rounded square. The ghosts are Wisp, Bramble, Cinder and Mote (diamond, triangle, hexagon, hollow square).
- Grid seed 0 paints the fixed maze. Any other grid seed carves a connected maze (rooms on the odd cells, a spanning set of corridors, a few extra loops, one power pellet in each quarter). Eater seed picks the opening cell and the eater's tie-break. Ghost seed is the 0..3 role bias. Ghost movement does not read the eater seed.
- The eater walks to the nearest pellet it can reach before a ghost. It paths around a power pellet unless a hostile ghost's path to the eater is within `danger_radius`, or the eater is cornered. It hunts a frightened ghost only when that ghost is closer than food and the eater has not gone too long without eating. On a tick when the ghosts move after the eater, it treats the cell a hostile ghost occupies, and every cell next to one, as closed if another open cell is safe. The ghosts share the eater's cell, facing, and pellet counts. One chases, one aims ahead, two split across the quarters with the most food. While the eater is powered they scatter on different compass directions instead of one corner. A caught ghost walks home and does not bite.
- Host parameters are the nine integers in `Swarm` (`danger_radius` through `ghost_stride`). Other knobs (`Pellet_Points`, `Initial_Lives`, `Tick_Cap`, `Log_Gap`) sit at the top of the private part of `swarm.ads` and are copied into every report.
- Same 160 games as v0.2, integer means. Hand-made maze (grid 0, eater seeds 1..40, ghost seeds 0..3): v0.2 won 4, mean score 2025, mean pellets left 40. v0.3 won 36, mean score 2334, mean pellets left 8, and 8 games hit the tick cap. Generated mazes (grid seeds 1..40, eater seed 1, ghost seeds 0..3): v0.2 won 0, mean score 2777, mean pellets left 64. v0.3 won 30, mean score 6109, mean pellets left 19, and 8 games hit the tick cap. Robert's v0.2 loss (grid 3437685755, eater 2389119185, ghosts 3742138053) is now a loss at score 5180 with 2 pellets left, tick 802, and 5 catches. v0.2 was score 2180, 26 pellets left, tick 334, and 2 catches.
- Reports are `hunter-swarm-report` v1 JSON. Stop and game end each download an eater file and a ghost-team file. F9 / Debug pauses, asks what you expected, and downloads the full report. The eater report's `custom.why_died` lists each death: tick, killer, nearby ghosts, open exits, the decision the eater was committed to, and the killer's distance at the start of the tick three before. The summary lines `BUILD`, `TEST KEY`, and `SUMMARY` live in `custom.summary`.
- The browser build is `-gnatp` (D-027). `./run-tests.sh` is the native `-gnata -gnatwa -gnatwe` smoke, statically linked. It plays one game, checks the replay hash, and checks that all four report kinds contain the required fields.
- Last-chance handler is wasm-only (`src/wasm`), so it does not replace the native handler. A failed check in the smoke still prints file and line. The page keeps a crash notice across reload.

## Open questions

1. The eater now wins 36 of 160 on the hand-made maze and 30 of 160 on generated mazes. Eight games in each scan run out the tick cap. Is that the balance to keep?
2. Are Wisp, Bramble, Cinder, and Mote the names to keep?
3. `why_died` now also names the committed decision and the killer's distance a few ticks earlier. Is that the note to keep?
4. Five lives and the point values are still the round-1 guesses.
