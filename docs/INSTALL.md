# Installation and troubleshooting

Start with the three steps in [README.md](../README.md). Linux/Wine is supported by the installer. Windows and macOS have not been packaged or validated; a Windows user cannot run the Bash/Linux installer directly.

## Find your files

In Steam, right-click **Risk of Rain → Properties → Installed Files → Browse**. Supply that directory using `--game-dir` if automatic detection fails. Both the original Linux installation (`assets/game.unx`) and a Windows installation (`data.win`) are accepted as resource sources. This does not accept Returns or RoR2.

Supply a disc dump from your own Melee copy with `--melee`. The importer reads it locally and never uploads it. ISO/GCM work directly. ZIP must contain one ISO/GCM/RVZ. RVZ needs Dolphin's command-line tool; alternatively convert your dump to ISO in Dolphin first. PAL GALP01 was used for testing; imports from other regions need validation.

## What setup does

1. Creates an isolated Python environment and installs NumPy/Pillow.
2. Checks Wine, winepath, FFmpeg, flock, liblua5.4 and Gamescope.
3. Downloads the tested RoRML 1.0.1 and DXVK 2.7.1 archives and checks pinned SHA-256 checksums.
4. Uses a system .NET SDK, `FALCON_DOTNET`, or installs .NET 8.0.426 under `.tools/` using Microsoft's installer.
5. Extracts sound resources from your original Risk of Rain data file.
6. Extracts Falcon's required files from your Melee disc, converts the model/animations/audio, removes visual root travel, and applies special-move travel to the collision body.
7. Builds a separate play directory, clean profile and local launcher configuration.

Files generated from either game are ignored by Git. Setup does not use or edit your Steam save. Its profile is under `build/play/profiles/FalconRain/`.

## Common fixes

- **Missing tools:** run `python3 scripts/setup.py --check`, then install the missing prerequisites. If Python says ensurepip is unavailable, install your distro's `python3-venv` package. Setup can also use an already installed `uv` to create its environment.
- **No Vulkan / very slow rendering:** install your GPU driver's Vulkan components, including 32-bit libraries. The launcher uses DXVK because the original Wine renderer was extremely slow on the development machine.
- **RVZ conversion unavailable:** install Dolphin's command-line tool or supply ISO/GCM instead.
- **.NET fails:** install the .NET 8 SDK from [Microsoft](https://learn.microsoft.com/dotnet/core/install/linux), or set `FALCON_DOTNET=/path/to/dotnet` before setup. The build requires the SDK, not just the runtime.
- **Download unavailable:** the upstream loader is hosted at Rainfusion. You can provide the same tested archive with `--rorml-zip /path/to/RoRML.zip`; DXVK supports `--dxvk-archive`. Checksums still apply. No loader/game binaries are mirrored by this project.
- **Setup stopped partway:** keep the log/error and rerun with a fresh directory, e.g. `./setup.sh --melee "/path/to/Melee.iso" --output "$PWD/build/retry/play"`. Existing output directories are never overwritten. Only delete an incomplete directory after confirming it contains no save you need.
- **Output already exists:** launch the existing installation. To deploy Lua edits after `git pull`, close the game and run `python3 scripts/update-mods.py`. If an update changes imported asset formats or adds animations, build a fresh output directory as above.
- **Controls wrong through Moonlight:** see [CONTROLLERS.md](CONTROLLERS.md). A PS4 exposed as a native PlayStation device can have different axis/trigger numbers from the canonical XInput layout this mod expects.
- **Character select is cropped:** use `./launch.sh`, which fixes the internal Gamescope display at 1280×720 and presents it fullscreen. Do not externally resize the child game window.
- **Locked launcher/deployment:** fully close the game; the launcher holds a lock for its lifetime.

The launcher writes its log under the configured play folder's parent, usually `build/logs/launch.log`. RoRML writes additional logs under `build/play/logs/`.

## Remove the installation

Delete the cloned repository and its generated play folder when finished. If you chose an external `--output`, remove that separately. Keep any saves you want first. The original Steam installation is unchanged.

## Fullscreen and Gamescope

The normal launcher always wraps the game in Gamescope (`-f`, internal 1280×720, output 1920×1080, 60 Hz). The game itself is the tracked child; no Wine Explorer desktop sits between Steam and the game. Closing the game should close Gamescope and release the launch lock. The launcher includes Gamescope's binary directory in PATH so packaged `gamescopereaper` is found even when Steam omits `/usr/games`.

Set `FALCON_OUTPUT_WIDTH` and `FALCON_OUTPUT_HEIGHT` to change the output resolution. Gamescope still runs fullscreen and keeps the game at 720p internally. Use `FALCON_GAMESCOPE=0` only for a diagnostic launch without Gamescope; `FALCON_GAMESCOPE_BACKEND=sdl` can force the nested SDL backend when troubleshooting. Gamescope logs are next to `launch.log`.

Version 0.4.8 adds an original Melee grounded knockdown animation for Falcon's corpse. Existing installations need their local assets reimported once to get this pose; copying Lua source alone keeps the older airborne death-pose fallback. Close the game, then run `python scripts/import-melee.py --source "/path/to/Melee.iso" --mod-root "/path/to/play/mods/CaptainFalcon"` in the setup Python environment. This updates imported assets without replacing profiles or saves. Fresh setup includes it automatically.

Version 0.4.9 imports original Falcon flame particles. Existing builds need another local asset import; see [effect setup and scope](EFFECTS.md).
