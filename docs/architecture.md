# Runtime architecture

At startup, `scenes/main.tscn` creates the menu, overview camera, and lighting. The coordinator in `src/app/main.gd` loads the bundled level and linked starter weapon and ammunition. A load failure disables arena entry and displays an error. A valid level goes to `LevelBuilder`, which creates solids, scenery, and training targets. Entering the range resets targets and spawns a fresh player and loadout.

| Ownership | Implementation | Future extension |
| --- | --- | --- |
| Application and UI | `src/app/main.gd` manages session and pause state. `src/app/weapon_hud.gd` listens for ammo and hit signals. | Loadout selection and custom range sessions |
| FPS movement and input | `src/player/player_controller.gd` owns movement, camera, and captured gameplay input. | Route weapon actions to the selected weapon |
| Weapon state | `src/weapons/weapon_controller.gd` owns trigger state, fire cadence, reload timing, and ammunition counts. It receives a validated loadout and an aim node. | Use the same controller with a different aim node and input source |
| Shot resolution | `src/combat/shot_resolver.gd` queries the physics world along the aim direction and dispatches damage to the first collider. | Introduce projectile travel using the same damage receiver |
| Damage and targets | `src/combat/damageable.gd` owns health. `src/levels/training_target.gd` maps health changes to target visuals. | Attach the damage component to enemies or destructible props |
| Viewmodel | `src/weapons/weapon_view.gd` animates the existing mesh from weapon signals. | Replace the model or improve animation independently of ballistics |
| Content | `src/content/content_loader.gd` validates and serializes records and resolves a weapon's typed ammunition reference. | Index validated records in a catalog |
| Editor, enemy AI, and survival | Enemy and game-mode records remain examples. | Reuse content validation and gameplay components as these systems are added |

The scene tree pauses world physics, weapon timers, and feedback while keeping the pause UI responsive. The player accepts weapon input only while the mouse is captured. Pause and capture loss clear pending fire and reload requests. An in-progress reload resumes with its remaining time, and automatic fire requires a fresh press after recapture. Holding automatic fire during an uninterrupted reload resumes firing after the reload completes. A semi-automatic press during cooldown or reload is discarded.

The ray uses the camera transform before viewmodel recoil and tests the World and Damageable collision layers. It excludes the firing body's RID. A solid wall terminates the query. For damageable bodies, the resolver looks for a direct child named `Damageable` with the damage component script. Targets that reach zero health stay solid, change color, and stop taking damage. Re-entering the range restores them.
