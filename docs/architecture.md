# Phase 1 architecture

At startup, `scenes/main.tscn` creates the menu, camera, and lighting. Its coordinator in `src/app/main.gd` asks `ContentLoader` for the trusted bundled level path. A load failure disables entry and shows the error on the menu. A valid record goes to `LevelBuilder`, which maps blocks to box meshes and adds static bodies only for solid blocks. The coordinator puts the player at the validated spawn when play begins.

| Ownership | Phase 1 implementation | Future extension |
| --- | --- | --- |
| Application and UI | Main menu, arena session, pause and resume, focus-loss pause | Add playtest and package-selection entry points to the coordinator |
| FPS movement | `scenes/player.tscn` and `src/player/player_controller.gd` own camera, input, capsule movement, and respawn | Attach loadout and health components to the player |
| Weapons | `scenes/training_weapon.tscn` is a view-only mesh attached to the camera | Equip weapon instances from validated weapon and ammunition records |
| Projectile and damage | Ammunition schema describes projectile tuning | Add gameplay components for projectile simulation and damage resolution |
| Enemy and survival | Independent enemy and game-mode records | Instantiate enemies from validated presets and let a session controller schedule waves |
| Level loading | `src/levels/level_builder.gd` turns a validated record into nodes | Extend the versioned format and reuse the builder for playtesting |
| Validation and serialization | `src/content/content_loader.gd` parses, validates, and serializes records | Resolve package IDs in a catalog before starting a session |
| In-game editor | Planned | Edit plain document data, validate it, and use the existing level builder and gameplay session for playtests |

The scene tree pauses world processing while keeping the coordinator and UI responsive. Physics, input capture, and scene lifecycle are distinct from the content format. Godot scene and script loading is reserved for bundled game resources. Future user content should pass through the validator and a trusted factory before it can create nodes.
