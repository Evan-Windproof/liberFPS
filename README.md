# Open FPS Sandbox

An offline, single-player FPS sandbox built with Godot and GDScript. Phase 2.1 adds a playable shooting range with hitscan fire, semi-automatic and automatic weapon modes, reloading, and damageable targets. The arena, starter weapon, and ammunition load from validated JSON. Enemy AI, survival waves, and the in-game editor are future work.

## Play on Windows

Extract the release ZIP and run `OpenFPSSandbox.exe` with `OpenFPSSandbox.pck` in the same directory. Select **Enter training arena**. Use WASD to move, the mouse to look, Shift to sprint, Space to jump, left mouse button to fire, R to reload, and Esc to pause or resume. The lower-right HUD shows magazine and reserve ammunition. An orange hit marker confirms damage. Return to the main menu and re-enter the range to reset ammunition and targets.

## Run from source

Open `project.godot` in [Godot 4.7.2 stable](https://github.com/godotengine/godot/releases/tag/4.7.2-stable) and press F5 to run the game. The project uses the Compatibility renderer and requires the standard Godot build.

On Linux x86_64 in Codex Cloud, use the existing checkout:

```sh
./tools/install-godot-cloud
./tools/godot-cloud --headless --editor --path . --import
./tools/godot-cloud --headless --path . --script tests/phase1_smoke.gd
./tools/godot-cloud --headless --path . --script tests/phase21_smoke.gd
```

The installer verifies official SHA-512 checksums. Set `LIBERFPS_TOOL_DIR` to an absolute writable directory to override `/workspace/.liberfps-tools`. With a graphical display, run `./tools/godot-cloud --path .` to play.

## Tune the training loadout

From source, edit `content/starter/weapon.json` or `content/starter/ammo.json` and restart the game. For example, set `firing_mode` to `"semi"` for one shot per press or `"auto"` for continuous fire while held. Check the [content format](docs/content-format.md) for supported fields. Re-export to include edits in the Windows build.

## Export on Codex Cloud

```sh
./tools/install-godot-cloud --windows-template
mkdir -p dist/phase-2.1
./tools/godot-cloud --headless --editor --path . --import
./tools/godot-cloud --headless --path . --export-release "Windows x86_64" dist/phase-2.1/OpenFPSSandbox.exe
```

If using the graphical Godot editor, install the matching official templates from **Editor → Manage Export Templates** and use the **Windows x86_64** preset. For redistribution, include the PCK, license and notices, and corresponding project source. Include the Godot `LICENSE.txt` and `COPYRIGHT.txt` from the matching engine release.

## Project documentation

- [Runtime architecture](docs/architecture.md)
- [Versioned JSON and future content packages](docs/content-format.md)
- [Verification](docs/verification.md)
- [Contributing](CONTRIBUTING.md)
- [License and third-party notices](NOTICE.md)
