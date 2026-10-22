# Controllers, Steam and Moonlight

The mod reads RoRML's canonical XInput buttons and axes. It works with the keyboard alongside the assigned gamepad. It does not use Steam Input's keyboard emulation.

1. In Sunshine, set **gamepad emulation to Xbox 360** (`gamepad = x360`). Reconnect the Moonlight session after applying the setting. This normalizes a remote PS4 controller to the layout expected by RoRML. Changing the host setting can affect other Moonlight games too.
2. Add this repository's `launch.sh` to Steam as a non-Steam game. Leave forced Proton compatibility off; the script already launches Gamescope fullscreen and Wine with its own prefix.
3. Use a normal Gamepad layout. Avoid layouts which turn the stick/buttons into mouse movement or keyboard presses. If Steam Input changes the layout, disable Steam Input for this shortcut and let the emulated XInput controller reach Wine directly.
4. Launch the shortcut from Steam inside Moonlight. Alternatively launch it from Moonlight's desktop session.
5. Open the controls guide with **Share/View**. Cross/A attacks, Circle/B uses specials, Square/X and Triangle/Y jump, and L2/LT or R2/RT shield.

Gently tilt the stick to walk; flick it to dash. Reverse sharply to dash dance. Flick+attack or the right stick smashes. Hold the attack button to charge a smash; right-stick smashes execute immediately. Special direction comes from your aimed direction. Directional aerials use facing to choose forward or back air.

Shield + left/right rolls. Shield + down spot-dodges. In the air, a trigger air-dodges along the stick angle. Dodge diagonally down into the floor to wavedash. A trigger just before landing an aerial attack performs an L-cancel.

The full-roll invulnerability is an intentional adaptation: all roll frames are protected, including startup/recovery. Shield has finite health, breaks when depleted and leaves Falcon stunned. Neither action grants permanent invulnerability.

A USB gamepad exposed as native DirectInput/PlayStation rather than XInput has not been validated. Button labels alone cannot correct a different axis/trigger layout.

The existing Steam/Moonlight shortcut can point to the launcher script directly; do not add a second Gamescope command in Steam launch options. Set the stream to 1920×1080 for the default output, or set the output-width/height environment variables described in INSTALL.md. Sunshine captures the fullscreen Gamescope surface on the host desktop. Its `x360` controller emulation remains required for remote PS4 clients.

Shield now uses RoR's native invincibility timer as well as damage callback cancellation. Its meter drains while held and breaks at zero. This protects against incoming damage paths that do not reach the callback. Jumping with Space or Square/Triangle while climbing clears the rope state and briefly prevents snapping straight back onto it.

For startup troubleshooting, the profile flag `falcon_input_trace` records the first 900 gameplay frames (about 15 seconds at 60 FPS) in the normal runtime log. It samples controller assignment, buttons, stick axes, movement and the fighter's blocking state, with extra samples on attack/special edges. It does not change controls or enable the gameplay QA flags. Remove the flag after collecting a run.
