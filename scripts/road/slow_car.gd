class_name SlowCar
extends Node3D
## The slow car (assets/models/old_sedan.glb): an old, faded yellow saloon with nobody at the wheel, one dim tail light
## lit and the other dead. It follows the core's slow_gap, ahead of the couple's car in their lane, and is hidden when
## there is none. On slow_car_gone it pulls into a lay-by (SlowCarMission has its numbers) and goes dark. The model's
## origin is the ground at the centre of the wheelbase, facing +Z, its left at +X.

const FAR := 150.0  # a parked car is hidden this far from the couple's car
const TAIL := Color(0.8, 0.05, 0.03)
const TAIL_ENERGY := 1.0  # dim: the hatchback's are 1.5 and its lamps are whole
## Metres left of the centreline it crawls at: in the couple's lane but edged towards the line, as a slow car wanders,
## so that from his seat behind Mei it shows between her and Hafiz. Presentation only: the core keeps it in the lane.
const ACROSS := RoadLayout.LANE - 1.0

var speed := 0.0  # m/s along the road: the engine runs while it moves

var _lamp: StandardMaterial3D  # its one working tail light
var _s := 0.0
var _from_s := 0.0
var _pull := -1.0  # seconds into pulling in; negative while it follows the core


func _ready() -> void:
	var model := ApartmentBuilder.model(&"old_sedan")
	add_child(model)
	var body: MeshInstance3D = model.get_node("old_sedan")
	for i in body.mesh.get_surface_count():
		var mat := body.mesh.surface_get_material(i)
		if mat != null and mat.resource_name == &"taillight_dim":  # the model's lens is plain gloss: a copy, lit
			_lamp = mat.duplicate() as StandardMaterial3D
			_lamp.emission_enabled = true
			_lamp.emission = TAIL
			_lamp.emission_energy_multiplier = TAIL_ENERGY
			body.set_surface_override_material(i, _lamp)
	visible = false


## Each frame: where the couple's car is and the core's gap to the slow car (NAN when there is none).
func place(car_s: float, gap: float) -> void:
	if _pull >= 0.0 and not is_nan(gap):  # pulled in, and the core has a slow car again (the tools reuse this one)
		_pull = -1.0
		_lamp.emission_energy_multiplier = TAIL_ENERGY
	if _pull < 0.0:
		visible = not is_nan(gap)
		if visible:
			_s = car_s + gap
			speed = SlowCarMission.SLOW_SPEED
			global_transform = CarRig.on_road(_s, ACROSS)
	else:
		visible = absf(car_s - _s) < FAR


## It leaves the road where it is: slows to a stop in the lay-by, and its tail light goes out.
func pull_in() -> void:
	_from_s = _s
	_pull = 0.0


func _process(delta: float) -> void:
	if _pull < 0.0 or _pull >= SlowCarMission.PULL_SECONDS:
		return
	_pull = minf(_pull + delta, SlowCarMission.PULL_SECONDS)
	var k := _pull / SlowCarMission.PULL_SECONDS
	speed = SlowCarMission.SLOW_SPEED * (1.0 - k)
	_s = _from_s + SlowCarMission.PULL_DISTANCE * (2.0 - k) * k  # slowing evenly to a stop
	# Across first, in 70 % of the time: the couple edge over towards its old line as they come on, and reach it then.
	global_transform = CarRig.on_road(_s, lerpf(ACROSS, SlowCarMission.LAY_BY, smoothstep(0.0, 0.7, k)))
	if _pull >= SlowCarMission.PULL_SECONDS:
		_lamp.emission_energy_multiplier = 0.0  # dark, not switched off: no new shader mid-game
