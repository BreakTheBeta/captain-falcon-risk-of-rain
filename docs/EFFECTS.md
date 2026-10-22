# Original Melee flame particles

The importer reads `EfCaData.dat` from the owner's Melee disc. Seven texture groups and seventeen particle definitions are decoded locally with the vendored HSDRaw library. No textures, scripts, atlases or disc files are distributed in this repository.

`FalconImport --effects` exports the original particle textures, generator parameters, bytecode, effect-joint animation and particle KEY tracks. The offline baker decodes each particle KEY, including tracks with multiple IDs and negative start offsets. It evaluates the particle texture/size/color commands, generator lifetimes and emission rates. The original fighter commands supply the on/off gates: Punch 1–65, ground Kick 1–33, air Kick 1–34. Particle visibility starts later inside each effect: Punch at effect frame 50 and Kick at frame 14.

Gameplay draws precomputed sprites for Falcon Punch, Falcon Kick, and the distinct ground/air Raptor Boost hit effects. Kick follows the original animated foot joint. Animation time controls playback, so hitstop freezes the flames and death/recovery clears them. Generic hit feedback remains separate.

This is a particle billboard adaptation for RoR's 2D renderer. The separate polygon effect meshes (including Punch's bird-shaped mesh and its ring), full GX blending/alpha comparison, native generator cone orientation and AppSRT group transforms are not reproduced. Random seeds are deterministic for baking. This imports real particle assets; it does not reproduce every detail of Melee's complete visual-effects engine.

The native behavior was checked against [doldecomp/melee](https://github.com/doldecomp/melee/tree/f0cdbb0a7046aea44c7177fd72abf33c3d2af4d4): `ftcaptainspecialn.c`, `ftcaptainspeciallw.c`, `ftcaptainspecials.c`, `efalt.c`, and `sysdolphin/baselib/{particle,generator,fobj,psdisptev}.c`. The MIT HSDRaw dependency is credited in THIRD_PARTY.md.

Existing builds need a local asset reimport for this update. Close the game and run `.venv/bin/python scripts/import-melee.py --source "/path/to/Melee.iso" --mod-root "/path/to/play/mods/CaptainFalcon"` from the repository root. Fresh setup includes the effects. Generated `melee_effect_data.lua`, `melee-effect-audit.json` and PNG atlases stay in the private play folder. The audit records the source archive hash, particle events and generated atlas hashes.
