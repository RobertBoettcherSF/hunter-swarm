# Hunter Swarm

A self-playing maze chase. One eater plays for the highest score. Four ghosts
play as a team to keep that score low. The rules, the maze and the pieces are
original. The game logic is plain Ada, compiled to WebAssembly. The page only
draws, takes the buttons, and downloads reports.

The eater is a gold rounded square. The ghosts are Wisp, Bramble, Cinder and
Mote, each a different shape. They are not cabinet artwork.

AI assistance was used to write this project.

## Play

After a build, open `docs/index.html` in a browser. Nothing else is fetched
except a version check, which fails quietly while the repository is private.

- **Start**, **Stop**, **Speed**, **Reset**.
- The world seed picks the opening cell. The AI seed picks how the ghost roles
  rotate. Both are shown, so a game can be played again.
- **New seeds** fills both boxes. **Reset** builds that opening and waits.
  **Start** runs it, or resumes after Stop.
- **Stop**, and the end of a game, each download two files: an eater report
  and a ghost-team report. If a browser blocks the second file, the same
  names are buttons under the maze.
- **Debug** or **F9** pauses and asks what you expected, then downloads the
  full debug report. A crash notice offers the report from the previous visit.

## Reports

JSON, schema `poncelet-report` v1. Each file has the stamp, both seeds, the
test key (`stop`, `game-end`, `f9`, or `crash`), the action log, the state
hash, events, errors, and a `custom` object with the settings, the score, the
lives and the decisions for that side. `custom.summary` is three lines:
`BUILD`, `TEST KEY`, `SUMMARY`.

## Build and test

GNAT 12 (`gnatmake`) is enough for the smoke test. The WebAssembly compiler
is a separate download, once per machine, and only if you want it.

```sh
./run-tests.sh
```

```sh
sudo apt install rpm2cpio cpio lld libedit2
./tools/get-toolchain.sh
./build.sh
```

`./tools/get-toolchain.sh` installs AdaWebPack 24 under
`~/toolchains/adawebpack-24` (or `$ADAWEBPACK`). `./build.sh` never downloads
it. It stops with a message if the compiler is missing. `alr` is required
only when `libgnat-14.so` is not already on the machine.

The browser build uses `-gnatp` because that runtime cannot raise a failed
check. The contracts stay in the source. `./run-tests.sh` compiles the same
sources with checks on, and treats a warning as an error.

## When the repository is public

The page is one file, `docs/index.html`, with `docs/version.txt` beside it.
GitHub Pages can serve `/docs` on `main`:

```sh
gh api -X POST repos/RobertBoettcherSF/hunter-swarm/pages \
  -f build_type=legacy -f 'source[branch]=main' -f 'source[path]=/docs'
```

The live URL is then `https://robertboettchersf.github.io/hunter-swarm/`.
The workflow in `.github/workflows/pages.yml` deploys that same `docs/`
folder when you run it by hand, or when the repository variable
`ENABLE_PAGES` is `true`. Until then a push does not try to deploy.

A commit-pinned link, after the repository is public:

`https://rawcdn.githack.com/RobertBoettcherSF/hunter-swarm/<commit>/docs/index.html`

Githack cannot serve a private repository. Do not announce a `/main/` URL;
use the commit.

## Layout

```
src/swarm.ads swarm.adb           maze, both AIs, tick
src/swarm-report.ad?              poncelet-report v1
src/swarm-api.ad?                 integer functions the page calls
src/wasm/swarm-last_chance.ad?    browser last-chance handler
web/template.html                 drawing, buttons, languages, sound
tests/smoke.adb                   one native run with checks on
build.sh run-tests.sh             the commands above
docs/index.html                   the built page
```

The nine host parameters, in order: `danger_radius`, `power_seek`,
`threat_range`, `hunt_range`, `cutoff_lead`, `role_interval`,
`fright_ticks`, `starve_ticks`, `ghost_stride`. The page can change them
during a game. Defaults and the other knobs (pellet points, lives, tick cap)
are in each report.

## Licence

MIT. See `LICENSE`.
