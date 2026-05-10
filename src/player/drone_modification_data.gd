# drone_modification_data.gd — Data class for drone modification configuration
class_name DroneModificationData
extends Resource

enum ComponentType {
	EMPTY,
	BATTERY,           # Increases max battery life
	FIRE_CONTROL,      # Enables fire control UI (takes 2 slots)
	EXPLOSIVE_CHARGE,  # Adds explode button, higher damage/AOE per module
}

const DRONE_MODIFICATION_SLOT_COUNT := 3
const BATTERY_HEALTH_PER_MODULE := 75
const FIRE_CONTROL_SLOT_SIZE := 2
const EXPLOSIVE_CHARGE_BASE_DAMAGE := 50
const EXPLOSIVE_CHARGE_DAMAGE_PER_MODULE := 25
const EXPLOSIVE_CHARGE_BASE_RADIUS := 50.0
const EXPLOSIVE_CHARGE_RADIUS_PER_MODULE := 30.0

@export var modification_layout: Array[ComponentType] = [ComponentType.EMPTY, ComponentType.EMPTY, ComponentType.EMPTY]
@export var has_fire_control: bool = false

func _init(p_layout: Array = []) -> void:
	if p_layout.is_empty():
		modification_layout = [ComponentType.EMPTY, ComponentType.EMPTY, ComponentType.EMPTY]
	else:
		modification_layout = []
		for component in p_layout:
			modification_layout.append(int(component) as ComponentType)


## Returns the total battery bonus from installed battery modules
func get_battery_bonus() -> float:
	var count := 0
	for component in modification_layout:
		if component == ComponentType.BATTERY:
			count += 1
	return count * BATTERY_HEALTH_PER_MODULE


## Returns true if fire control is installed
func has_fire_control_module() -> bool:
	if not modification_layout.has(ComponentType.FIRE_CONTROL):
		return false
	# Fire control takes 2 slots, so we need enough free space
	var fire_control_count := 0
	for component in modification_layout:
		if component == ComponentType.FIRE_CONTROL:
			fire_control_count += 1
	return fire_control_count >= 1


## Returns the number of explosive charge modules installed
func get_explosive_charge_count() -> int:
	var count := 0
	for component in modification_layout:
		if component == ComponentType.EXPLOSIVE_CHARGE:
			count += 1
	return count


## Returns the total explosion damage
func get_explosion_damage() -> int:
	var charge_count := get_explosive_charge_count()
	if charge_count == 0:
		return 0
	return EXPLOSIVE_CHARGE_BASE_DAMAGE + (EXPLOSIVE_CHARGE_DAMAGE_PER_MODULE * charge_count)


## Returns the total explosion radius
func get_explosion_radius() -> float:
	var charge_count := get_explosive_charge_count()
	if charge_count == 0:
		return 0.0
	return EXPLOSIVE_CHARGE_BASE_RADIUS + (EXPLOSIVE_CHARGE_RADIUS_PER_MODULE * charge_count)


## Attempts to place a component at the given slot
## Returns true if successful, false if slot is occupied or invalid
func try_place_component(slot_index: int, component_type: ComponentType) -> bool:
	if slot_index < 0 or slot_index >= DRONE_MODIFICATION_SLOT_COUNT:
		return false
	if modification_layout[slot_index] != ComponentType.EMPTY:
		return false
	
	# Special check for fire control which takes 2 slots
	if component_type == ComponentType.FIRE_CONTROL:
		if slot_index + 1 >= DRONE_MODIFICATION_SLOT_COUNT:
			return false  # Not enough space for fire control
		if modification_layout[slot_index + 1] != ComponentType.EMPTY:
			return false
		modification_layout[slot_index] = ComponentType.FIRE_CONTROL
		modification_layout[slot_index + 1] = ComponentType.FIRE_CONTROL
		return true
	
	modification_layout[slot_index] = component_type
	return true


## Clears a slot
func clear_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= DRONE_MODIFICATION_SLOT_COUNT:
		return
	
	var component = modification_layout[slot_index]
	modification_layout[slot_index] = ComponentType.EMPTY
	
	# If this is a fire control component, clear the next slot too
	if component == ComponentType.FIRE_CONTROL and slot_index + 1 < DRONE_MODIFICATION_SLOT_COUNT:
		if modification_layout[slot_index + 1] == ComponentType.FIRE_CONTROL:
			modification_layout[slot_index + 1] = ComponentType.EMPTY


## Clears all slots
func clear_all() -> void:
	modification_layout = [ComponentType.EMPTY, ComponentType.EMPTY, ComponentType.EMPTY]


## Returns true if all slots are empty
func is_empty() -> bool:
	for component in modification_layout:
		if component != ComponentType.EMPTY:
			return false
	return true


## Returns the slot cost (visual indicator of how many slots a component uses)
static func get_component_slot_cost(component_type: ComponentType) -> int:
	match component_type:
		ComponentType.BATTERY:
			return 1
		ComponentType.FIRE_CONTROL:
			return 2
		ComponentType.EXPLOSIVE_CHARGE:
			return 1
		_:
			return 0


## Returns the display name for a component
static func get_component_name(component_type: ComponentType) -> String:
	match component_type:
		ComponentType.BATTERY:
			return "Battery"
		ComponentType.FIRE_CONTROL:
			return "Fire Control"
		ComponentType.EXPLOSIVE_CHARGE:
			return "Explosive Charge"
		_:
			return "Empty"


## Returns the description for a component
static func get_component_description(component_type: ComponentType) -> String:
	match component_type:
		ComponentType.BATTERY:
			return "Extends drone battery life by 75 HP"
		ComponentType.FIRE_CONTROL:
			return "Enables fire control mode for weapon targeting"
		ComponentType.EXPLOSIVE_CHARGE:
			return "Adds explosive capabilities: +50 damage, +50 radius per module"
		_:
			return ""
