# Phase 2.1 verification

Tested in Codex Cloud on Debian 13 x86_64 using Godot 4.7.2 stable and its matching official Windows template.

| Check | Result |
| --- | --- |
| Editor import and headless project startup | Passed without import or startup errors. |
| Phase 1 regression suite | 40/40 headless checks passed, with one mouse-capture check skipped. 44/44 graphical checks passed. |
| Phase 2.1 smoke suite | 36/36 headless checks passed, with one graphical input group skipped. 39/39 graphical checks passed. The graphical run sent LMB and R input events through Godot and captured the hit marker, ammo HUD, and reload pose. |
| JSON Schema Draft 2020-12 | All five schemas and their starter records passed independent validation. |
| Cold starts with alternate JSON | A fresh process loaded edited magazine and reserve values and dealt the edited damage. A broken ammo reference disabled arena entry and displayed an error. The original Phase 1 level, weapon, and ammo loaded together with compatible defaults. |
| Windows x86_64 release export | Produced a PE32+ x86-64 executable and its companion PCK in `dist/phase-2.1/`. Running both headless suites against the exported PCK from an isolated directory on Linux passed 40/40 and 36/36 checks, respectively, with one graphical group skipped in each suite. |
| Native Windows execution | Phase 2.1 remains untested on native Windows. |

The Phase 2.1 suite checks validated loadouts, semi-auto and automatic cadence, ammunition consumption and reload timing, the HUD, hitscan reach, solid-wall blocking, damage, target reset, recoil, and pause/capture transitions. The virtual graphical run used Xvfb and Mesa llvmpipe and reported an unsupported VSync mode. It did not measure frame rate or validate hardware drivers.

## Reproduce

From the project root after installing Godot using the [README](../README.md):

```sh
./tools/godot-cloud --headless --editor --path . --import
./tools/godot-cloud --headless --path . --script tests/phase1_smoke.gd
./tools/godot-cloud --headless --path . --script tests/phase21_smoke.gd
```

On Linux with a graphical display, run the same suites without `--headless`. To include the screenshot checks:

```sh
mkdir -p /tmp/liberfps-captures/{phase1,phase21}
./tools/godot-cloud --audio-driver Dummy --path . \
  --script tests/phase1_smoke.gd -- --capture-dir=/tmp/liberfps-captures/phase1
./tools/godot-cloud --audio-driver Dummy --path . \
  --script tests/phase21_smoke.gd -- --capture-dir=/tmp/liberfps-captures/phase21
```

## Current limits

Gameplay uses one starter loadout, instantaneous hitscan, and viewmodel-only recoil. Source JSON edits require a restart, and distributing them in the Windows build requires re-export. This phase has no in-game switching, mod importing, enemy AI, survival waves, or multiplayer.
