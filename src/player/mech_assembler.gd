# mech_assembler.gd — Shared mech assembly logic.
# Single source of truth for weapon mount offsets, sprite proportions,
# and preview layout.  Used by PlayerController (in-game) and
# WorkshopScreen (UI preview) so the mech is built identically everywhere.
class_name MechAssembler

## Native sprite dimensions (SVG viewBox sizes).
const TORSO_NATIVE_PX  := 64.0
const WEAPON_NATIVE_PX := 48.0
const LIGHT_WEAPON_NATIVE_PX := 32.0

## Torso mount offsets in sprite-local space.
## For dual-torso setups, torsos sit side-by-side along the hull length.
static func get_torso_offsets(slot_count: int) -> Array[Vector2]:
	if slot_count <= 1:
		return [Vector2.ZERO]
	if slot_count == 2:
		return [Vector2(-18.0, 0.0), Vector2(18.0, 0.0)]

	var offsets: Array[Vector2] = []
	for i in slot_count:
		var denom := maxf(float(slot_count - 1), 1.0)
		var t := float(i) / denom
		offsets.append(Vector2(lerpf(-18.0, 18.0, t), 0.0))
	return offsets

## Weapon mount offsets in sprite-local space (sprites face +X).
## X = forward (right), Y = lateral (positive Y = right flank).
static func get_weapon_offsets(torso_type: TorsoData.TorsoType) -> Array[Vector2]:
	match torso_type:
		TorsoData.TorsoType.HEAVY_ARMOUR:
			return [Vector2(4.0, 17.0), Vector2(4.0, -17.0)]
		TorsoData.TorsoType.STEALTH:
			return [Vector2(10.0, 0.0)]
		TorsoData.TorsoType.CARGO:
			return [Vector2(-17.0, 0.0)]
		TorsoData.TorsoType.NAVAL_TURRET:
			# Center, left flank, right flank — turret configuration
			return [Vector2(8.0, 0.0), Vector2(4.0, 16.0), Vector2(4.0, -16.0)]
		_:
			return [Vector2.ZERO]

## Light weapon mount offsets in sprite-local space.
## Stealth: one light slot on the right flank of the torso.
## Cargo: light slots on both flanks.
## Heavy: no light slots.
static func get_light_weapon_offsets(torso_type: TorsoData.TorsoType) -> Array[Vector2]:
	match torso_type:
		TorsoData.TorsoType.STEALTH:
			return [Vector2(0.0, 14.0)]
		TorsoData.TorsoType.CARGO:
			return [Vector2(0.0, 16.0), Vector2(0.0, -16.0)]
		_:
			return []

## Scale game-space offsets to preview-pixel offsets for a container of the
## given size.  The ratio maps 1 game pixel → (container_px / 64) preview px.
static func scale_offsets(offsets: Array[Vector2], container_px: float) -> Array[Vector2]:
	var s := container_px / TORSO_NATIVE_PX
	var result: Array[Vector2] = []
	for o in offsets:
		result.append(o * s)
	return result

## The side-length a weapon preview TextureRect should use so that the weapon
## sprite appears at the correct proportion relative to the torso.
static func weapon_rect_size(container_px: float) -> float:
	return container_px * (WEAPON_NATIVE_PX / TORSO_NATIVE_PX)

## The side-length for a light weapon preview TextureRect.
static func light_weapon_rect_size(container_px: float) -> float:
	return container_px * (LIGHT_WEAPON_NATIVE_PX / TORSO_NATIVE_PX)

## Utility slot count granted by a torso type.
## Cargo = 2, Stealth = 3, all others = 1.
static func get_utility_slots(torso_type: TorsoData.TorsoType) -> int:
	match torso_type:
		TorsoData.TorsoType.CARGO:
			return 2
		TorsoData.TorsoType.STEALTH:
			return 3
		_:
			return 1
