# Hunter Swarm

- Repo: https://github.com/RobertBoettcherSF/hunter-swarm (private)
- Live: none yet (the repository stays private; Pages is wired but not enabled)
- Test: none yet (private repo; githack cannot serve it). Local: open `docs/index.html` after `./build.sh`. The stamp in that file matches `docs/version.txt`.
- What: self-playing maze chase. Rules and both AIs are plain Ada compiled to WebAssembly. The page draws, takes buttons, and downloads reports.
- Status (2026-11-25): first playable build. Games run themselves to a win, a loss, or the tick cap. Stamp `v0.1 b20261125-0944 a1280d0`.
- SPARK: not started (D-008). No proof run.
- Gap: none recorded against D-005, D-007, D-025, or D-027. Wasm checks are off on purpose (D-027); `./run-tests.sh` runs the contracts.
- Next: none agreed. Open questions are below.
- Docs: `README.md`, `STATUS.md`

## Notes

- The maze is a fixed 19 by 21 corridor map. It is not a cabinet layout. The eater is a rounded square. The ghosts are Wisp, Bramble, Cinder and Mote (diamond, triangle, hexagon, hollow square).
- World seed picks the eater's opening floor cell. AI seed is a 0..3 bias that rotates which ghost chases, which one cuts ahead, and which two cover the pellet-heavy quarters. Tie-breaks use that bias, not a fresh random draw each tick.
- The eater walks to the nearest pellet it can reach before a ghost, takes a power pellet when a ghost is close, hunts a frightened ghost only when that ghost is closer than food and the eater has not gone too long without eating, and steps away when a ghost is inside `danger_radius`. The ghosts share the eater's cell, facing, and pellet counts. One chases, one aims ahead, two split across the quarters with the most food. While the eater is powered they each take a different home corner. A caught ghost walks home and does not bite.
- Host parameters are the nine integers in `Swarm` (`danger_radius` through `ghost_stride`). Other knobs (`Pellet_Points`, `Initial_Lives`, `Tick_Cap`, `Log_Gap`) sit at the top of the private part of `swarm.ads` and are copied into every report.
- A 160-seed scan with the defaults (5 lives, ghost stride 2) ended in a loss every time, and never hit the tick cap. Seed 1 / AI 2 finished with 4 pellets left. The ghost team is the stronger side. Stride, danger radius, and lives are the first knobs.
- Reports are `poncelet-report` v1 JSON. Stop and game end each download an eater file and a ghost-team file. F9 / Debug pauses, asks what you expected, and downloads the full report. The summary lines `BUILD`, `TEST KEY`, and `SUMMARY` live in `custom.summary`. There is no second Markdown file.
- The browser build is `-gnatp` (D-027). `./run-tests.sh` is the native `-gnata -gnatwa -gnatwe` smoke, statically linked. It plays one game, checks the replay hash, and checks that all four report kinds contain the required fields.
- Last-chance handler is wasm-only (`src/wasm`), so it does not replace the native handler. A failed check in the smoke still prints file and line. The page keeps a crash notice across reload.

## Open questions

1. Should the default settings let the eater win some seeds, or is a ghost-favoured opening what you want to tune from?
2. Are Wisp, Bramble, Cinder, and Mote the names you want to keep?
3. Is JSON with the three summary lines enough, or do you also want a separate Markdown file per side?
4. The maze is fixed. Do you want a second, seed-built maze later, or is one hand-checked map enough?
5. Five lives and the point values (pellet 10, power 50, catch 200 then double up to 1600) are guesses. Say if you want different numbers before the next round.
