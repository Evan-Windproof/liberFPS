# Phase 1 verification

Validated with the official Godot 4.7.2 stable editor and matching release template on Codex Cloud (Debian 13, Linux x86_64). Both archives matched the SHA-512 values provided with the official release.

| Check | Result |
| --- | --- |
| Headless editor import and project startup | Passed |
| Headless smoke suite | 40 passed, one skipped because the headless backend cannot capture the mouse |
| Graphical smoke suite | 44 passed, zero skipped using Xvfb and Mesa llvmpipe OpenGL. Captured and inspected the main menu, arena view, and pause menu. |
| JSON Schema Draft 2020-12 validation | All five schema documents and examples passed independent validation. IDs with trailing newlines were rejected. |
| Windows x86_64 release export | Godot produced a PE32+ x86-64 executable and a companion PCK. The PCK passed the same 40 headless checks from a separate directory using the Linux Godot editor binary, with mouse capture skipped. |
| Native Windows execution | Unrun. The cloud machine was Linux. |

The smoke suite exercises content parsing and serialization, rejection of malformed and out-of-range content, load-time arena generation, spawning, WASD, sprinting, jumping and landing, wall collision, pause/resume, and restarting the session. The graphical suite uses scripted input and additionally verifies captured mouse look and pitch limits. The virtual display reported that it could not change VSync mode. The graphical check did not measure frame rate or validate hardware drivers.

## Reproduce

From the project root on Codex Cloud after installing Godot with the README commands:

```sh
./tools/godot-cloud --headless --editor --path . --import
./tools/godot-cloud --headless --path . --script tests/phase1_smoke.gd
```

On Linux with an active graphical display:

```sh
mkdir -p /tmp/liberfps-captures
./tools/godot-cloud --audio-driver Dummy --path . \
  --script tests/phase1_smoke.gd -- --capture-dir=/tmp/liberfps-captures
```
