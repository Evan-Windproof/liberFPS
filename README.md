# Open FPS Sandbox

An offline, single-player FPS sandbox built with Godot and GDScript. Phase 1 is a walkable military training range with sprinting, jumping, a pause menu, and a placeholder viewmodel. The range geometry and spawn come from validated JSON. Combat, enemy AI, wave execution, and the in-game editor are future work.

## Play on Windows

Extract the release ZIP and run `OpenFPSSandbox.exe` with `OpenFPSSandbox.pck` in the same directory. Select **Enter training arena**. Use WASD to move, the mouse to look, Shift to sprint, Space to jump, and Esc to pause or resume.

## Run from source

Open `project.godot` in [Godot 4.7.2 stable](https://github.com/godotengine/godot/releases/tag/4.7.2-stable) and press F5 to run the game. The project uses the Compatibility renderer and requires the standard Godot build.

On Linux x86_64 in Codex Cloud, use the existing checkout:

```sh
./tools/install-godot-cloud
./tools/godot-cloud --headless --editor --path . --import
./tools/godot-cloud --headless --path . --script tests/phase1_smoke.gd
```

The installer verifies official SHA-512 checksums. Set `LIBERFPS_TOOL_DIR` to an absolute writable directory to override `/workspace/.liberfps-tools`. With a graphical display, run `./tools/godot-cloud --path .` to play.

## Export on Codex Cloud

```sh
./tools/install-godot-cloud --windows-template
mkdir -p dist
./tools/godot-cloud --headless --editor --path . --import
./tools/godot-cloud --headless --path . --export-release "Windows x86_64" dist/OpenFPSSandbox.exe
```

If using the graphical Godot editor, install the matching official templates from **Editor → Manage Export Templates** and use the **Windows x86_64** preset. For redistribution, include the PCK, license and notices, and corresponding project source. Include the Godot `LICENSE.txt` and `COPYRIGHT.txt` from the matching engine release.

## Project documentation

- [Runtime architecture](docs/architecture.md)
- [Versioned JSON and future content packages](docs/content-format.md)
- [Phase 1 verification](docs/verification.md)
- [Contributing](CONTRIBUTING.md)
- [License and third-party notices](NOTICE.md)
