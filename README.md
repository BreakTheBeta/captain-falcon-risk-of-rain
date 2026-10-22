# Captain Falcon + Risk of Rain

Play Melee-inspired Captain Falcon in **Risk of Rain (2013)**, with a three-choice item mode: every normal item reward offers three random items of the same rarity.

Falcon has directional normals and specials, short hops, double jumps, wavedashing, analog walking/dashing, shield, and a fully invincible roll. His model, animation poses, movement curves and sound samples are imported **locally from your own Melee disc dump**.

**Current release: 0.4.7. Single player. Linux/Wine is the tested platform.** This is a fan-made adaptation, not the full Melee engine. Risk of Rain Returns and Risk of Rain 2 are not supported.

## Play in three steps

You need your installed Steam copy of Risk of Rain 1, a local Melee disc dump (`.iso`, `.gcm`, `.rvz`, or a ZIP containing one), and a Vulkan-capable graphics driver with 32-bit support. PAL `GALP01` is tested; other Melee regions are recognized but unverified. RVZ additionally needs Dolphin's `dolphin-tool`/`DolphinTool`.

On Debian/Ubuntu, install prerequisites once:

```sh
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install git python3 python3-venv ffmpeg liblua5.4-0 wine wine32:i386 libvulkan1 libvulkan1:i386 gamescope
```

Then:

```sh
# 1. Get the source.
git clone https://github.com/BreakTheBeta/captain-falcon-risk-of-rain.git
cd captain-falcon-risk-of-rain

# 2. Build your private game folder. Replace the path with YOUR disc dump.
./setup.sh --melee "/path/to/Melee.iso"

# 3. Play.
./launch.sh
```

Setup finds the usual Steam installation automatically. For another Steam library, add `--game-dir "/path/to/Risk of Rain"`. It downloads pinned RoRML and DXVK builds, installs a local .NET SDK if needed, extracts your game resources, and builds Falcon's assets. The first setup takes a few minutes. **Your Steam game and existing save are not modified.** The new play folder has its own save.

Choose **Single Player**, open the **second survivor page** using the right arrow beside Difficulty, select **Captain Falcon**, and press **Play**. Three-choice items work for every survivor.

See [setup and troubleshooting](docs/INSTALL.md) if anything fails.

## Controls

| Action | PS4 via Moonlight/XInput | Xbox layout | Keyboard |
|---|---|---|---|
| Move / aim | Left stick | Left stick | WASD |
| Walk / dash | Gentle tilt / flick | Gentle tilt / flick | Ctrl+WASD / WASD |
| Normal attack | Cross | A | J |
| Special | Circle | B | K |
| Jump / double jump | Square or Triangle | X or Y | Space |
| Smash / directional aerial | Right stick | Right stick | Shift+direction+J / direction+J in air |
| Shield / air dodge | L2 or R2 | LT or RT | L |
| Roll | Shield + left/right | Shield + left/right | L + A/D |
| Interact / take item | R1 | RB | E |
| Use equipment | L1 | LB | Q |
| Swap equipment | L3 | Left stick click | F |
| Full controls guide | Share | View | H |
| Pause | Options | Menu | Escape |

Direction + special gives **neutral: Falcon Punch; side: Raptor Boost; up: Falcon Dive; down: Falcon Kick**. Tap jump for a short hop. Down while falling fast-falls. Ground shield grants native immunity while held and drains until it breaks; roll protects throughout its animation. Jump also detaches from ropes/ladders. Air dodge diagonally into the floor to wavedash.

For **Moonlight**, configure Sunshine's gamepad emulation as **Xbox 360 / `x360`**, including when the client uses a PS4 controller. See [Steam and Moonlight](docs/CONTROLLERS.md).

## Steam and Moonlight

Add this repository's `launch.sh` to Steam as a **non-Steam game** and name it “Captain Falcon + Risk of Rain”. Launch that entry from Steam or Moonlight's Desktop/Steam session. The script runs Gamescope fullscreen and Wine itself: **leave Steam's forced Proton compatibility off**. Use a normal gamepad layout, rather than keyboard/mouse emulation. Close and reopen the game after mod updates.

## Source and development

The project code is MIT licensed. [Third-party credits and licenses](THIRD_PARTY.md) identify HSDRaw, Pod and the other tools. **Neither game, Melee disc files, extracted models/audio/textures, imported Lua geometry, RoRML binaries, saves, nor Wine prefixes are included in the repository or releases.** The code license does not license game assets. Keep generated assets local.

```sh
python3 scripts/test.py                         # Source tests; no game files needed
FALCON_MOD_ROOT="$PWD/build/play/mods/CaptainFalcon" python3 scripts/test.py --assets
python3 scripts/update-mods.py                  # Deploy code edits after closing the game
```

Open this repository folder as a **T3 Code project**. Its `t3.json` defines Check setup, Setup game, Test source, Deploy edits, and Play actions. [Development notes](docs/DEVELOPMENT.md) explain the source layout and silent testing.

Known limits: single player; 2D RoR collision/world; cached model poses during gameplay; simplified hitboxes and combat rules; initial Melee sound pitch/volume is reproduced, but dynamic SEM automation/reverb and the complete Melee audio mix are not. Controller feel and hardware support need more testing outside the original Linux/Wine setup.
