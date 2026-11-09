class_name Mirror
extends Node3D
## The hatchback's rear-view mirror, on its mirror_mount (local +Z towards the back seat), and the fourth passenger
## that only it shows. Its own camera looks back at the rear seats into a small SubViewport, drawn on the glass and
## flipped left to right as a mirror is. She sits in the rear right seat on render layer 11, which the player's camera
## leaves out; her own fill light lights layer 11 alone. The viewport renders only while the mirror is on, from
## mirror_on to mirror_off (Mission 3). It shows her side of the back seat only, not his: no reflection of him to miss.

const SIZE := Vector2i(320, 112)
const FOV := 42.0  # degrees across (KEEP_WIDTH): her seat and her door, and his seat stays out of it
const LAYER := 1 << 10  # render layer 11: the mirror only
const GLASS := Vector2(0.24, 0.064)  # the model's mirror_glass, 2 mm behind the mount
const EYE := Vector3(0.0, 0.0, 0.01)  # the camera, just in front of the glass, so the glass is behind it
const AIM := Vector3(0.08, 0.55, 0.1)  # in her seat's space: what the camera looks at, her bowed head
## In her seat's space: her fill light, between the front seats and towards the mirror. Far enough that it falls
## evenly across her: her crown, the nearest of her to it, no longer glows.
const FILL := Vector3(0.3, 0.75, 0.95)
## In her seat's space: where her wet hair and back lay against the backrest (its face is 0.13 m behind the H-point
## and leans back 22 degrees). The mirror can't see down to the cushion.
const WET := Vector3(0.0, 0.42, -0.3)
const ENERGY := 1.4  # her fill: her dark hair over her paler skin and baju kurung, noticeable, not obvious
const SHINE := 0.05  # her fill's specular on her: low, so her crown has no hotspot, only streaks down her wet hair
const WET_ENERGY := 3.0  # and once she is gone, on the wet seat: brighter, or its sheen doesn't show
const WET_SHINE := 1.0  # the wet seat's sheen is all that shows of the wet

var viewport: SubViewport
var camera: Camera3D
var fourth: Node3D
var fill: OmniLight3D
var wet: MeshInstance3D  # the wet patch she leaves on her backrest

var _seat: Node3D
var _world: Environment  # the road's, for its fog
var _aim: Transform3D  # the camera, in the mirror's space
var _glass: MeshInstance3D


func _init(seat: Node3D) -> void:
	_seat = seat


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.positional_shadow_atlas_size = 0  # no shadow maps drawn twice: none show at 320x112
	add_child(viewport)
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = FOV
	camera.near = 0.02
	camera.far = 60.0
	viewport.add_child(camera)
	camera.current = true
	var target := to_local(_seat.to_global(AIM))
	_aim = Transform3D(Basis.looking_at(target - EYE, Vector3.UP), EYE)
	var picture := StandardMaterial3D.new()
	picture.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	picture.disable_fog = true
	picture.albedo_texture = viewport.get_texture()
	var crop := GLASS.y / GLASS.x * SIZE.x / SIZE.y  # the glass is wider than the picture: its middle rows
	picture.uv1_scale = Vector3(-1.0, crop, 1.0)  # and flipped left to right
	picture.uv1_offset = Vector3(1.0, (1.0 - crop) / 2.0, 0.0)
	var quad := QuadMesh.new()
	quad.size = GLASS
	_glass = _mesh(quad, picture)
	_glass.visible = false
	add_child(_glass)
	fourth = ApartmentBuilder.model(&"fourth")
	fourth.name = "Fourth"
	fourth.visible = false
	for v: VisualInstance3D in fourth.find_children("*", "VisualInstance3D", true, false):
		v.layers = LAYER
		if v is GeometryInstance3D:
			(v as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # no shadow of her
	_seat.add_child(fourth)
	fill = OmniLight3D.new()
	fill.light_color = Color(0.75, 0.8, 0.9)  # the fog's grey through the glass
	fill.light_energy = ENERGY
	fill.omni_range = 2.2
	fill.light_cull_mask = LAYER
	fill.light_specular = SHINE
	fill.position = FILL
	fill.visible = false
	_seat.add_child(fill)
	var patch := CylinderMesh.new()
	patch.top_radius = 0.11
	patch.bottom_radius = 0.11
	patch.height = 0.004
	patch.radial_segments = 14
	patch.rings = 1
	var soaked := StandardMaterial3D.new()
	soaked.albedo_color = Color(0.02, 0.022, 0.026)
	soaked.roughness = 0.22  # a broad sheen from her fill light (WET_SHINE): dark cloth alone reads as nothing
	wet = _mesh(patch, soaked)
	wet.layers = LAYER
	wet.position = WET
	wet.rotation.x = deg_to_rad(68.0)  # flat on the backrest
	wet.scale = Vector3(1.0, 1.0, 1.6)  # longer down the backrest, as it ran
	wet.visible = false
	_seat.add_child(wet)
	set_process(false)  # it follows the car only while on


func _process(_delta: float) -> void:
	_follow()
	if _world != null:
		camera.environment.fog_density = _world.fog_density


## The road's environment, for the mirror's own copy: the same fog and ambient light, but none of its grade (exposure,
## tonemap, glow, colour adjustment). The player's camera grades the glass with everything else, so the picture is
## graded once, and the Brightness setting scales it once. Its colour adjustment is on but changes nothing: with it on
## the renderer tonemaps in a pass after the scene, as for the player's camera, so the mirror draws with the same
## shaders as his camera instead of a set of its own that would compile the first time it is switched on.
func use_environment(world: Environment) -> void:
	_world = world
	camera.environment = world.duplicate()
	camera.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	camera.environment.tonemap_exposure = 1.0
	camera.environment.glow_enabled = false
	camera.environment.adjustment_enabled = true
	camera.environment.adjustment_brightness = 1.0
	camera.environment.adjustment_contrast = 1.0
	camera.environment.adjustment_saturation = 1.0
	camera.environment.adjustment_color_correction = null


## On: the viewport renders every frame, the glass shows it, and she sits in it. Off: none of them.
func set_on(on: bool) -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	_glass.visible = on
	fourth.visible = on
	fill.visible = on
	fill.light_energy = ENERGY
	fill.light_specular = SHINE
	wet.visible = false
	set_process(on)
	if on:
		_follow()


## She is gone: the mirror shows her seat empty, and wet.
func empty() -> void:
	fourth.visible = false
	wet.visible = true
	fill.light_energy = WET_ENERGY
	fill.light_specular = WET_SHINE


## The camera follows the car: it is in the viewport, outside the car's own transforms.
func _follow() -> void:
	camera.global_transform = global_transform * _aim


static func _mesh(mesh: Mesh, material: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = material
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m
