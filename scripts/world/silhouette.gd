class_name Silhouette
extends Node3D
## The figure. Shown at an anchor on request; once the player has it on screen for a moment it plays a
## stinger, reports silhouette_seen and fades. It never blocks movement (no collision).

const SEEN_AFTER := 0.3
const VANISH_DISTANCE := 2.2

var stage: GameStage
var _anchor: StringName = &""
var _left := 0.0
var _seen_for := 0.0
var _fading := false
var _material := StandardMaterial3D.new()
var _apron := StandardMaterial3D.new()

# A person, not a pawn: [mesh, position, rotation z, scale]. Arms hang a little too low, the head is tipped.
# It wears the apron from the mamak (the window: "Someone in your apron is pulling teh tarik").
const BODY := [
	["capsule", 0.075, 0.86, Vector3(-0.1, 0.43, 0), 0.0, Vector3.ONE],  # legs
	["capsule", 0.075, 0.86, Vector3(0.1, 0.43, 0), 0.0, Vector3.ONE],
	["capsule", 0.17, 0.66, Vector3(0, 1.16, 0), 0.0, Vector3(1.15, 1.0, 0.62)],  # torso and shoulders
	["capsule", 0.05, 0.16, Vector3(0, 1.5, 0.01), 0.0, Vector3.ONE],  # neck
	["sphere", 0.105, 0.24, Vector3(0.015, 1.62, 0.02), 0.2, Vector3(0.9, 1.0, 1.0)],  # head, tipped
	["capsule", 0.045, 0.76, Vector3(-0.235, 1.05, 0), -0.05, Vector3.ONE],  # arms
	["capsule", 0.045, 0.76, Vector3(0.235, 1.05, 0), 0.05, Vector3.ONE],
]


func _ready() -> void:
	# Near-black but lit, so a room light finds its shoulders and head; in the dark it is a shape against
	# whatever is behind it.
	_material.albedo_color = Color(0.03, 0.03, 0.032, 0.95)
	_material.roughness = 0.95
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_apron.albedo_color = Color(0.52, 0.5, 0.45, 0.95)  # lit by the room: it shows only where there is light
	_apron.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_apron.roughness = 0.9
	# Drawn after the shades, which are see-through too, so a stain on the wall behind never paints over it.
	_material.render_priority = 1
	_apron.render_priority = 1
	for part: Array in BODY:
		var m := MeshInstance3D.new()
		if part[0] == "capsule":
			var c := CapsuleMesh.new()
			c.radius = part[1]
			c.height = part[2]
			m.mesh = c
		else:
			var s := SphereMesh.new()
			s.radius = part[1]
			s.height = part[2]
			m.mesh = s
		m.position = part[3]
		m.rotation.z = part[4]
		m.scale = part[5]
		_add(m, _material)
	for piece: Array in [[Vector3(0.22, 0.2, 0.012), Vector3(0, 1.31, 0.112)], [Vector3(0.4, 0.52, 0.012), Vector3(0, 0.9, 0.115)]]:  # bib, skirt
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = piece[0]
		m.mesh = b
		m.position = piece[1]
		_add(m, _apron)
	visible = false
	EventBus.silhouette_requested.connect(_on_requested)


func _add(m: MeshInstance3D, material: Material) -> void:
	m.material_override = material
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)


func _set_alpha(a: float) -> void:
	_material.albedo_color.a = a
	_apron.albedo_color.a = a


func _on_requested(anchor: StringName, duration: float) -> void:
	if duration <= 0.0:
		visible = false
		return
	_anchor = anchor
	global_position = ApartmentLayout.ANCHORS[anchor]["pos"]
	var p := stage.player_position()
	look_at(Vector3(p.x, global_position.y, p.z), Vector3.UP, true)
	_left = duration
	_seen_for = 0.0
	_fading = false
	_set_alpha(0.95)
	visible = true


## Shows the figure for a moment at pos without it counting as a sighting (no stinger, no signal), so its
## shader is compiled behind the start card and not on the first scare (a 110 ms hitch on an M1 Max).
func warm_up(pos: Vector3) -> void:
	global_position = pos
	_fading = true  # _process fades it out and hides it again
	visible = true


func _process(delta: float) -> void:
	if visible and _fading:
		_set_alpha(_material.albedo_color.a - delta * 2.5)
		if _material.albedo_color.a <= 0.0:
			visible = false


## Sightings feed the simulation, so they are decided on the fixed physics tick, not per rendered frame.
func _physics_process(delta: float) -> void:
	if not visible or _fading:
		return
	_left -= delta
	var head := global_position + Vector3.UP * 1.6
	var close := stage.distance_to(global_position) < VANISH_DISTANCE
	if stage.any_visible(SilhouetteEvent.body_points(global_position, stage.player_position())) or close:
		_seen_for += delta
	if _seen_for >= SEEN_AFTER or close:
		_fading = true
		EventBus.sound_requested.emit(&"stinger", head, 0.0)  # the loudest sound in the game
		EventBus.silhouette_seen.emit(_anchor)
	elif _left <= 0.0:
		visible = false
