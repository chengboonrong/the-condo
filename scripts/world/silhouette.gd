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


func _ready() -> void:
	_material.albedo_color = Color(0.0, 0.0, 0.0, 0.95)
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.disable_fog = true
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.22
	capsule.height = 1.55
	body.mesh = capsule
	body.position.y = 0.78
	body.scale = Vector3(1.0, 1.0, 0.6)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.3
	head.mesh = sphere
	head.position.y = 1.68
	for m: MeshInstance3D in [body, head]:
		m.material_override = _material
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
	visible = false
	EventBus.silhouette_requested.connect(_on_requested)


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
	_material.albedo_color.a = 0.95
	visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	if _fading:
		_material.albedo_color.a -= delta * 2.5
		if _material.albedo_color.a <= 0.0:
			visible = false
		return
	var head := global_position + Vector3.UP * 1.6
	var close := stage.distance_to(global_position) < VANISH_DISTANCE
	if stage.can_see(head) or close:
		_seen_for += delta
	if _seen_for >= SEEN_AFTER or close:
		_fading = true
		EventBus.sound_requested.emit(&"stinger", head, -2.0)
		EventBus.silhouette_seen.emit(_anchor)
	elif _left <= 0.0:
		visible = false
