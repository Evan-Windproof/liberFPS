# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const VERSION := 1
const MAX_BYTES := 128 * 1024
const SCHEMAS := {
	"level": "res://content/schemas/level.v1.schema.json",
	"weapon": "res://content/schemas/weapon.v1.schema.json",
	"ammo": "res://content/schemas/ammo.v1.schema.json",
	"enemy": "res://content/schemas/enemy.v1.schema.json",
	"mode": "res://content/schemas/mode.v1.schema.json",
}

## The path comes from trusted application code. External JSON never supplies a file path.
func load_document(kind: String, path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("Could not open the %s document." % kind)
	var length := file.get_length()
	if length == 0 or length > MAX_BYTES:
		return _failure("Document must contain 1–%d bytes." % MAX_BYTES)
	var bytes := file.get_buffer(length)
	if bytes.size() != length:
		return _failure("Document could not be read in full.")
	var source := bytes.get_string_from_utf8()
	if source.to_utf8_buffer() != bytes:
		return _failure("Document must use valid UTF-8.")
	return parse_document(kind, source)

## Resolve a weapon's typed ammo ID against the supplied ammunition document.
## The file paths are selected by trusted application code.
func load_weapon_loadout(weapon_path: String, ammo_path: String) -> Dictionary:
	var weapon := load_document("weapon", weapon_path)
	if not weapon["ok"]:
		return _failure("Weapon: " + weapon["error"])
	var ammo := load_document("ammo", ammo_path)
	if not ammo["ok"]:
		return _failure("Ammunition: " + ammo["error"])
	if weapon["data"]["ammo_id"] != ammo["data"]["id"]:
		return _failure("Weapon references unknown ammunition ID '%s'." % weapon["data"]["ammo_id"])
	return {"ok": true, "weapon": weapon["data"], "ammo": ammo["data"]}

## Return {ok, data} on success or {ok, error} on failure.
func parse_document(kind: String, source: String) -> Dictionary:
	var size := source.to_utf8_buffer().size()
	if size == 0 or size > MAX_BYTES:
		return _failure("Document must contain 1–%d bytes." % MAX_BYTES)

	var parser := JSON.new()
	if parser.parse(source) != OK:
		return _failure("Invalid JSON on line %d: %s" % [
			parser.get_error_line(), parser.get_error_message()])
	if not parser.data is Dictionary:
		return _failure("Expected a JSON object.")
	return _validate_document(kind, parser.data)

## Return {ok, json} on success or {ok, error} without writing to disk.
func serialize_document(kind: String, data: Dictionary) -> Dictionary:
	var result := _validate_document(kind, data)
	if not result["ok"]:
		return result
	var source := JSON.stringify(data, "\t", true, true) + "\n"
	if source.to_utf8_buffer().size() > MAX_BYTES:
		return _failure("Serialized document exceeds %d bytes." % MAX_BYTES)
	return {"ok": true, "json": source}

func _validate_document(kind: String, data: Dictionary) -> Dictionary:
	if not SCHEMAS.has(kind):
		return _failure("Unknown content kind.")
	if data.get("schema_version") != VERSION:
		return _failure("Unsupported %s schema version. Expected %d." % [kind, VERSION])

	# Only bundled schemas participate in validation.
	var schema: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCHEMAS[kind]))
	if not schema is Dictionary:
		return _failure("The bundled %s schema could not be read." % kind)
	var error := _validate(data, schema, "$")
	if error.is_empty() and kind == "level":
		error = _validate_level(data)
	if not error.is_empty():
		return _failure(error)
	return {"ok": true, "data": data}

func _validate(value: Variant, schema: Dictionary, path: String) -> String:
	match schema["type"]:
		"object":
			if not value is Dictionary:
				return path + " must be an object."
			for key: String in schema.get("required", []):
				if not value.has(key):
					return path + "." + key + " is required."
			for key: Variant in value:
				if not key is String or not schema["properties"].has(key):
					return path + " contains an unknown property."
				var error := _validate(value[key], schema["properties"][key], path + "." + key)
				if not error.is_empty():
					return error
		"array":
			if not value is Array:
				return path + " must be an array."
			if value.size() < schema["minItems"] or value.size() > schema["maxItems"]:
				return path + " has an invalid item count."
			for index: int in value.size():
				var error := _validate(value[index], schema["items"], "%s[%d]" % [path, index])
				if not error.is_empty():
					return error
		"string":
			if not value is String:
				return path + " must be a string."
			if value.length() < schema["minLength"] or value.length() > schema["maxLength"]:
				return path + " has an invalid length."
			if schema.has("pattern"):
				var pattern := RegEx.create_from_string(schema["pattern"])
				var matched := pattern.search(value) if pattern.is_valid() else null
				if matched == null or matched.get_start() != 0 or matched.get_end() != value.length():
					return path + " has an invalid format."
			if schema.has("enum") and not schema["enum"].has(value):
				return path + " has an unsupported value."
		"boolean":
			if not value is bool:
				return path + " must be a boolean."
		"number", "integer":
			if not (value is float or value is int):
				return path + " must be a number."
			if not is_finite(value) or value < schema["minimum"] or value > schema["maximum"]:
				return path + " is outside the allowed range."
			if schema["type"] == "integer" and floor(value) != value:
				return path + " must be an integer."
		_:
			return path + " uses an unsupported schema type."
	return ""

func _validate_level(data: Dictionary) -> String:
	var feet := vector3(data["spawn"]["position"])
	# A conservative box around the player capsule keeps spawns clear of solid props.
	var clearance := AABB(feet + Vector3(-0.35, 0.01, -0.35), Vector3(0.7, 1.8, 0.7))
	var supported := false
	for block: Dictionary in data["blocks"]:
		if not block["solid"]:
			continue
		var size := vector3(block["size"])
		var bounds := AABB(vector3(block["center"]) - size * 0.5, size)
		if bounds.intersects(clearance):
			return "$.spawn intersects solid geometry."
		if absf(bounds.end.y - feet.y) <= 0.15:
			if (bounds.position.x <= clearance.position.x and bounds.end.x >= clearance.end.x
				and bounds.position.z <= clearance.position.z and bounds.end.z >= clearance.end.z):
				supported = true
	for target: Dictionary in data.get("targets", []):
		var size := vector3(target["size"])
		var bounds := AABB(vector3(target["center"]) - size * 0.5, size)
		if bounds.intersects(clearance):
			return "$.spawn intersects a training target."
	if not supported:
		return "$.spawn needs a solid floor under the player."
	return ""

static func vector3(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))

static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}
