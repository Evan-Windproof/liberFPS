# Content format v1

The game reads UTF-8 JSON. A document is a single object, limited to 128 KiB, with integer `schema_version: 1`, an `id`, and a display `name`. IDs use lowercase ASCII letters, digits, and underscores, start with a letter, and are at most 48 characters. Names allow up to 72 characters and exclude ASCII control characters. All declared fields are required. Extra fields, unsupported versions, and out-of-range values produce a validation error.

The caller selects the expected kind. Its schema is a bundled [JSON Schema Draft 2020-12 document](../content/schemas), and [starter examples](../content/starter) exercise every kind. The runtime implements the small subset used in these schemas. It uses Godot's JSON parser, which accepts some syntax such as trailing commas. Write portable, strict JSON for shared content.

| Kind | v1 payload |
| --- | --- |
| Level | Player `spawn` and up to 256 axis-aligned `blocks`. Spawn has a position and yaw in degrees. Each block has a center, positive size, a surface palette key, and a solid flag. |
| Weapon | `ammo_id`, magazine capacity, rounds per minute, and reload duration in seconds. |
| Ammunition | Projectile speed in meters per second, lifetime in seconds, and damage. |
| Enemy | Health, movement speed in meters per second, `weapon_id`, and an allowlisted behavior key. |
| Game mode | `level_id`, intermission duration in seconds, wave repetition flag, and waves of `enemy_id` and count groups. |

Vector order is `[x, y, z]`, in meters. Positive Y is up and yaw zero faces negative Z. A spawn indicates the player's feet and needs floor support and clearance from solid blocks. The level builder resolves surfaces to its own palette. Weapon, ammo, enemy, and game-mode documents currently serve as examples. The game loads only the level at startup. Tests validate all five records and their serialization round trips.

## Planned community packages

A future package manifest can declare package identity and version, compatible format versions, authorship, license information, and the document IDs it provides. An importer will stage files, apply size and count limits, validate each document, and resolve typed references inside the catalog before registration. A future editor can use the same validator and serializer to export data or run a local playtest.

Paths are absent from v1 documents. References such as `ammo_id` are typed IDs with no path separators. The current loader accepts file paths from trusted application code, never from a JSON field. Importer work should reject absolute paths, traversal, symlinks, and files that escape the staging directory before opening any package member. Packages should contain declarative data and any future explicitly supported asset formats. Scripts, arbitrary Godot resources, and executable behavior are outside the package contract. Package ingestion, cross-document reference resolution, migrations, and the asset pipeline are future work.
