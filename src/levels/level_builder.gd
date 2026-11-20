# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const ContentLoader = preload("res://src/content/content_loader.gd")
const PALETTE := {
	"asphalt": Color("#494e4c"),
	"concrete": Color("#8b928b"),
	"olive": Color("#4c5942"),
	"sand": Color("#938363"),
	"steel": Color("#323d42"),
	"amber": Color("#e4a94c"),
	"white": Color("#ddd9be"),
}

## Only validated level dictionaries may reach the builder.
func build(data: Dictionary) -> Node3D:
	var level := Node3D.new()
	level.name = "Arena"
	var materials := {}
	for surface: String in PALETTE:
		var material := StandardMaterial3D.new()
		material.albedo_color = PALETTE[surface]
		material.roughness = 0.92
		materials[surface] = material

	for block: Dictionary in data["blocks"]:
		var size := ContentLoader.vector3(block["size"])
		var center := ContentLoader.vector3(block["center"])
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh.material = materials[block["surface"]]
		visual.mesh = mesh
		if block["solid"]:
			var body := StaticBody3D.new()
			var collider := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = size
			collider.shape = shape
			body.position = center
			body.add_child(visual)
			body.add_child(collider)
			level.add_child(body)
		else:
			visual.position = center
			visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			level.add_child(visual)
	return level
