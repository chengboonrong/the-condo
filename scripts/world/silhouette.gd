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


## A person, not a pawn (art/figure): arms hanging a little too low, the head tipped, in the apron from the mamak
## (the window: "Someone in your apron is pulling teh tarik"). The model's "body" surfaces are drawn with _material,
## its "apron" ones with _apron, which keeps the apron's stains; both fade together (_set_alpha).
func _ready() -> void:
	# Near-black but lit, so a room light finds its shoulders and head; in the dark it is a shape against
	# whatever is behind it.
	_material.albedo_color = Color(0.03, 0.03, 0.032, 0.95)
	_material.roughness = 0.95
	_apron.albedo_color = Color(1, 1, 1, 0.95)  # the texture as it is: lit by the room, it shows only where there is light
	_apron.roughness = 0.9
	_apron.cull_mode = BaseMaterial3D.CULL_DISABLED  # the straps and ties are one layer of cloth, seen from both sides
	for m: StandardMaterial3D in [_material, _apron]:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Drawn after the shades, which are see-through too, so a stain on the wall behind never paints over it;
		# depth-tested against itself, so from behind the apron never shows through the body.
		m.render_priority = 1
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	var figure := ApartmentBuilder.model(&"figure")
	add_child(figure)
	for m: MeshInstance3D in figure.find_children("*", "MeshInstance3D", true, false):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in m.mesh.get_surface_count():
			var own := m.mesh.surface_get_material(s) as BaseMaterial3D
			if own and own.resource_name == "apron":
				_apron.albedo_texture = own.albedo_texture
				m.set_surface_override_material(s, _apron)
			else:
				m.set_surface_override_material(s, _material)
	visible = false
	EventBus.silhouette_requested.connect(_on_requested)


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
