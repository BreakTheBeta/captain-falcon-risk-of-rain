# Development

## Layout

- `mods/CaptainFalcon/`: input, fighter physics, attacks, defence, special motion, renderer and sound scheduling.
- `mods/ThreeChoiceCommand/`: independent per-crate three-item pools.
- `scripts/import-melee.py`: local disc extraction, asset conversion and import manifests.
- `scripts/build-melee-effects.py` and `scripts/melee_particles.py`: private particle atlases from original Falcon textures, scripts and animated emitters.
- `scripts/import-melee-motion.py`: native TransN deltas, special attributes and command-var gates.
- `tools/FalconImport/`: .NET HSD model/skeleton/animation importer.
- `tools/HSDLib/HSDRaw/`: pinned MIT upstream source; see THIRD_PARTY.md.
- `scripts/build-falcon-art.py`: procedural fallback sprite/mask generation.
- `scripts/bake-melee-poses.*` and `build-falcon-selection.*`: supersampled original-model animation strips and character selection artwork, generated locally.
- `tests/`: fast Lua input, physics, defence and asset regression checks. Lua 5.4 is run through Python ctypes; no game files are required for the seven core suites.

The original GameMaker world and collision remain 2D. Gameplay uses 40 precomputed pose strips from the original XYZ model. The software renderer remains available for baking and camera previews. Visual TransN translation is removed; special movement is applied exactly once to the collision actor. These are Melee-inspired RoR controls/combat, not a replacement implementation of every Melee rule.

## Build and test

Follow the README setup first for full asset tests. Run `python3 scripts/test.py` for core tests, or supply `FALCON_MOD_ROOT` pointing to your local imported mod and add `--assets`.

Edit the source under `mods/`, close the game, and run `python3 scripts/update-mods.py`. This copies only source files into the configured local play folder, preserving generated assets and saves. Open `t3.json` through T3 Code for the same actions. None of these commands update or reconfigure the T3 server.

## Silent gameplay testing

Keep all automated gameplay off the user's desktop. Start a virtual X display, then run the launcher there with disconnected audio:

```sh
Xvfb :97 -screen 0 1280x720x24 -nolisten tcp &
DISPLAY=:97 SDL_VIDEODRIVER=x11 FALCON_GAMESCOPE_BACKEND=sdl PULSE_SERVER=unix:/tmp/falcon-no-pulse PIPEWIRE_REMOTE=no-audio ./launch.sh
```

Install Xvfb/xdotool separately if needed. Scope automation and captures to that display. F4 cleanly exits the native test game. Keep gameplay fixtures and healing/invulnerability flags out of release profiles. Verify damage using an unprotected control hit before trusting shield/roll results. Do not overwrite a user's live installation or interrupt an active game.

## Publication

Run `python3 scripts/audit-source.py` after staging files and before publishing. Commit only source, docs, configuration, third-party license notices, reviewed gameplay screenshots under `docs/screenshots/`, and the explicitly allowlisted showcase exports under `docs/media/`. Screenshot PNGs must show gameplay or game menus; extracted textures, sprite sheets and other game assets remain excluded. Never publish a generated play directory, imported Lua mesh/motion tables, sound files, pose atlases, proprietary executables, disc dumps, save files, local logs, or local configuration. Release ZIPs must be source-only too.

Contributions should describe the input/trigger, changed behavior and verification. Report the OS/Wine/controller path and Melee disc region when filing a bug; do not attach a disc or game files.

## Optional CI

`docs/ci.yml.example` contains a GitHub Actions configuration for core Lua tests, Python compilation, the .NET importer build and the source audit. To enable it, copy it to `.github/workflows/ci.yml` and push using credentials with workflow-write permission. The initial publishing token did not have that permission, so no active workflow is shipped. The same checks were run locally.

For launcher-only checks, run `python3 tests/test-launcher.py`. These simulate the Gamescope/Wine process chain, verify one fullscreen wrapper, preserve paths containing spaces, propagate game failures and check lock release. During live Gamescope tests capture the **outer Gamescope window/display**, since native X11 window captures can contain stale images when Vulkan presents directly to Gamescope.

The launcher stops lingering Wine **service helpers** after the tracked game exits. Cleanup requires all of: a fixed Wine helper name, the same WINEPREFIX, and ancestry under this launch's gamescopereaper. It does not kill arbitrary Wine apps or unrelated prefixes. This handles Wine services that otherwise keep Gamescope/Steam marked running after the actual game has closed.
