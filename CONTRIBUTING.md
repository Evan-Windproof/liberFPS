# Contributing

Use Godot 4.7.2 and GDScript. Preserve the offline workflow and use the small scenes, scripts, and JSON examples as a starting point.

- Run the import and smoke-test commands in the [README](README.md) before submitting a change. Test visual changes in the Compatibility renderer and describe the platform and checks in your submission.
- Put new arena dimensions, positions, and surfaces in level JSON. Keep new gameplay logic out of the content loader. When extending a format, update its schema, examples, documentation, and validation checks together. Use a new schema version for incompatible changes.
- Submit original code under GPL-3.0-or-later. For assets, state the license, author, and provenance separately. Include required attribution and license text before adding any third-party material.
- Never commit `.godot/`, editor caches, downloaded engine binaries, packages, or Windows build output.
