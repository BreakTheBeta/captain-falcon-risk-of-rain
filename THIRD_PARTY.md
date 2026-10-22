# Credits and licenses

The original project source is MIT licensed (LICENSE). That grant covers this project's code, not either commercial game's assets or third-party software under its own license.

- **HSDRaw / HSDLib — Ploaj and contributors**, MIT. Vendored `tools/HSDLib/HSDRaw/*.cs` from [Ploaj/HSDLib](https://github.com/Ploaj/HSDLib), commit `85567e40797de3c820a55476eca54c704921a848`. License: `tools/HSDLib/LICENSE`. The .NET project compiles this source directly; the HSDRaw viewer and its dependencies are not bundled.
- **Pod — none and contributors**, MIT. Its [GameMaker resource extraction](https://gitlab.com/noneNA/pod/-/blob/master/src/data.cpp) informed `scripts/extract-ror.py`. License retained in `docs/POD-LICENSE`.
- **doldecomp/melee contributors**: [Melee decompilation](https://github.com/doldecomp/melee), consulted for motion/root translation, special physics, animation command and audio semantics. Its source files and game assets are not vendored.
- **BroccoliRaab/meleedb**: [character attributes](https://github.com/BroccoliRaab/meleedb), consulted for fighter movement constants.
- **RoRML / Saturnyoshi and contributors**: independently downloaded at setup from [Rainfusion](https://rainfusion.net/). [API documentation](https://saturnyoshi.gitlab.io/RoRML-Docs/). No loader binaries or patched game data are redistributed here.
- **DXVK — Philip Rebohle and contributors**: independently downloaded at setup from [doitsujin/dxvk](https://github.com/doitsujin/dxvk), version 2.7.1. No DXVK binaries are committed.
- **Microsoft .NET**, **Python**, **NumPy**, **Pillow**, **FFmpeg**, **Wine**, **DolphinTool** and **Lua** are used as separately installed/downloaded tools with their respective licenses. Their binaries are not part of this repository.

Risk of Rain and Super Smash Bros. Melee belong to their respective rights holders. This project is unofficial and unaffiliated. Users supply their own installed Risk of Rain copy and Melee disc dump. Imported assets and generated geometry/audio/pose tables stay local and are excluded from source releases.
