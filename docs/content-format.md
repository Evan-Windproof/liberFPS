# Content format v1

The game reads UTF-8 JSON. A document is a single object, limited to 128 KiB, with integer `schema_version: 1`, an `id`, and a display `name`. IDs use lowercase ASCII letters, digits, and underscores, start with a letter, and are at most 48 characters. Names allow up to 72 characters and exclude ASCII control characters. The schema's `required` list identifies mandatory fields. Extra fields, unsupported versions, and out-of-range values produce a validation error.

The caller selects the expected kind. Its schema is a bundled [JSON Schema Draft 2020-12 document](../content/schemas), and [starter examples](../content/starter) exercise every kind. The runtime implements the small subset used in these schemas. It uses Godot's JSON parser, which accepts some syntax such as trailing commas. Write portable, strict JSON for shared content.

| Kind | v1 payload |
| --- | --- |
| Level | Player `spawn` and up to 256 axis-aligned `blocks`. Spawn has a position and yaw in degrees. Each block has a center, positive size, a surface palette key, and a solid flag. Optional `targets` define damageable plates. |
| Weapon | `ammo_id`, magazine capacity, rounds per minute, reload duration, and optional firing, reserve, range, and recoil settings. |
| Ammunition | Projectile speed in meters per second, lifetime in seconds, and damage. |
| Enemy | Health, movement speed in meters per second, `weapon_id`, and an allowlisted behavior key. |
| Game mode | `level_id`, intermission duration in seconds, wave repetition flag, and waves of `enemy_id` and count groups. |

Vector order is `[x, y, z]`, in meters. Positive Y is up and yaw zero faces negative Z. A spawn indicates the player's feet and needs floor support and clearance from solid blocks. The level builder resolves surfaces to its own palette. The game loads the level, weapon, and ammo at startup. Enemy and mode records remain examples. Tests validate all five record types and their serialization round trips.

## Weapon and ammunition

The starter loadout comes from [weapon.json](../content/starter/weapon.json) and [ammo.json](../content/starter/ammo.json). A weapon's `ammo_id` must equal the validated ammunition document's `id`. A broken reference or invalid record produces a menu error. Edits take effect at the next game launch. This phase loads a single paired loadout from application-selected paths.

| Weapon field | Effect | Default when omitted |
| --- | --- | --- |
| `magazine_capacity` | Initial rounds and refill capacity | Required |
| `rounds_per_minute` | Minimum time between semi-auto shots and sustained auto cadence at 60 Hz | Required |
| `reload_seconds` | Time before reserve transfers to the magazine | Required |
| `firing_mode` | `semi` fires once per press. `auto` continues while held. | `semi` |
| `starting_reserve` | Rounds available for reloads | Three times magazine capacity |
| `max_range_m` | Effective distance cap in meters | 100 |
| `recoil` | Viewmodel kick with `kick_m`, `pitch_degrees`, and `recovery_seconds` | 0.035 m, 3°, 0.10 s |

Ammunition fields are unchanged from Phase 1. `damage` controls health removed per hit. `projectile_speed_mps` times `projectile_lifetime_seconds` supplies a travel budget in meters. Hitscan is instantaneous and uses the smaller of that budget and the weapon's range cap. The optional weapon fields preserve compatibility with existing v1 documents.

## Training targets

The optional level `targets` array allows up to 64 axis-aligned plates. Each entry specifies `center`, positive `size`, and `max_health` (1–10,000). Omission creates zero interactive targets, so Phase 1 levels still load. A target cannot intersect the player's spawn.

## Planned community packages

A future package manifest can declare package identity and version, compatible format versions, authorship, license information, and the document IDs it provides. An importer will stage files, apply size and count limits, validate each document, and resolve typed references inside the catalog before registration. A future editor can use the same validator and serializer to export data or run a local playtest.

Paths are absent from v1 documents. References such as `ammo_id` are typed IDs with no path separators. The current loader accepts file paths from trusted application code, never from a JSON field. Importer work should reject absolute paths, traversal, symlinks, and files that escape the staging directory before opening any package member. Packages should contain declarative data and any future explicitly supported asset formats. Scripts, arbitrary Godot resources, and executable behavior are outside the package contract. Package ingestion, catalog-wide reference resolution, migrations, and the asset pipeline are future work.
