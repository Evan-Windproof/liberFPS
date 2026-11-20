# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Damageable = preload("res://src/combat/damageable.gd")
const WORLD_LAYER := 1
const DAMAGEABLE_LAYER := 4

## Return true when the first collider actually accepts damage.
static func hitscan(space: PhysicsDirectSpaceState3D, origin: Vector3, direction: Vector3,
		reach: float, damage: float, source: RID) -> bool:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * reach,
		WORLD_LAYER | DAMAGEABLE_LAYER, [source])
	query.hit_from_inside = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider := hit["collider"] as Node
	var receiver := collider.get_node_or_null("Damageable") as Damageable if collider else null
	return receiver != null and receiver.apply_damage(damage)
