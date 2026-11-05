class_name Decor
extends Node3D
## Set dressing for a lived-in Malaysian condo: door and window frames, iron grilles, fittings, laundry,
## the things on counters, and soft contact shadows where things meet the floor and ceiling. None of it is
## gameplay. Pieces are merged into one mesh per room, look and variant (colour per vertex), so a few
## hundred boxes cost a handful of draw calls; anything the player could walk into gets an invisible
## solid(). ApartmentBuilder adds the trim of each wall as it builds it, then calls dress() and finish().

enum Finish { MATTE, GLOSS, TILE, UNLIT, SHADE }

const WOOD := Color(0.4, 0.28, 0.19)
const WOOD_DARK := Color(0.24, 0.16, 0.11)
const STEEL := Color(0.6, 0.61, 0.62)
const CHROME := Color(0.8, 0.81, 0.82)
const PORCELAIN := Color(0.92, 0.92, 0.9)
const GRILLE := Color(0.74, 0.73, 0.68)  # painted mild steel, never quite white any more
const GATE := Color(0.1, 0.1, 0.1)
const BRONZE := Color(0.24, 0.2, 0.16)  # anodised aluminium window frames
const SKIRTING := Color(0.74, 0.69, 0.6)
const PLASTIC_WHITE := Color(0.88, 0.87, 0.83)

var builder: ApartmentBuilder
var _batches := {}  # key -> [SurfaceTool, Finish, requires]
var _looks := {}
var _led: MeshInstance3D  # standby light on the bedroom aircon, blinking although it is switched off
var _hands: Array[Node3D] = []  # living room clock: hour, minute; it follows the game clock, shifts and all
var _leak: Node3D  # corridor light under the front door, while the door is shut
var _leak_feet: Node3D  # the same strip with two gaps in it, while someone stands outside the door
var _feet := false
var _anchor: Variant = null  # while set, pieces join the batch of the room at this point, not at their own centre
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	EventBus.door_changed.connect(func(id: StringName, _open: bool, _source: StringName) -> void:
		if id == &"main_door":
			_show_leak())
	EventBus.door_feet_requested.connect(func(shown: bool) -> void:
		_feet = shown
		_show_leak())


func _show_leak() -> void:
	var shut := not WorldState.is_door_open(&"main_door")
	_leak.visible = shut and not _feet
	_leak_feet.visible = shut and _feet


func _process(_delta: float) -> void:
	_led.visible = Time.get_ticks_msec() % 1400 < 160
	var m := float(WorldState.clock_minutes())
	_hands[0].rotation.z = -TAU * fmod(m / 60.0, 12.0) / 12.0
	_hands[1].rotation.z = -TAU * fmod(m, 60.0) / 60.0


# --- building blocks ----------------------------------------------------------------------------

func box(center: Vector3, size: Vector3, color: Color, look := Finish.MATTE, requires := {}, yaw := 0.0) -> void:
	box_xf(Transform3D(Basis(Vector3.UP, yaw), center), size, color, look, requires)


func box_xf(xf: Transform3D, size: Vector3, color: Color, look := Finish.MATTE, requires := {}, into: SurfaceTool = null) -> void:
	var st := into if into else _st(xf.origin, look, requires)
	var h := size * 0.5
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for i in 3:
		var n: Vector3 = axes[i]
		var du: Vector3 = axes[(i + 1) % 3] * h
		var dv: Vector3 = axes[(i + 2) % 3] * h
		for s: float in [-1.0, 1.0]:
			var c := n * h * s
			var pts := [c - du - dv, c + du - dv, c + du + dv, c - du + dv].map(func(q: Vector3) -> Vector3: return xf * q)
			_poly(st, pts, (xf.basis * (n * s)).normalized(), color)


## Cylinder along the local y axis of xf, from its origin up `height`. A smaller top_radius makes a cone
## (shades, food covers); squash stretches it along local x (oval basins, the toilet bowl). cap colours the
## top (water in a pail).
func cylinder_xf(xf: Transform3D, radius: float, height: float, color: Color, look := Finish.GLOSS, requires := {}, top_radius := -1.0, cap := Color(0, 0, 0, 0), squash := 1.0) -> void:
	var st := _st(xf.origin, look, requires)
	var r2 := radius if top_radius < 0.0 else top_radius
	var sides := 14
	var bottom := []
	var top := []
	var normals := []
	for i in sides:
		var a := TAU * i / sides
		var d := Vector3(cos(a) * squash, 0, sin(a))
		bottom.append(xf * (d * radius))
		top.append(xf * (d * r2 + Vector3.UP * height))
		normals.append((xf.basis * Vector3(cos(a) / squash, (radius - r2) / height, sin(a))).normalized())
	for i in sides:
		var j := (i + 1) % sides
		_poly(st, [bottom[i], bottom[j], top[j], top[i]], (normals[i] + normals[j]).normalized(), color, [], [normals[i], normals[j], normals[j], normals[i]])
	var up := (xf.basis * Vector3.UP).normalized()
	_poly(st, top, up, color if cap.a == 0.0 else cap)
	_poly(st, bottom, -up, color)


func cylinder(base: Vector3, radius: float, height: float, color: Color, look := Finish.GLOSS, requires := {}, top_radius := -1.0, cap := Color(0, 0, 0, 0), squash := 1.0) -> void:
	cylinder_xf(Transform3D(Basis(), base), radius, height, color, look, requires, top_radius, cap, squash)


## A soft shadow (or stain, with a colour): full strength over the rect, fading to nothing over `margin`.
## Horizontal (n up or down): half = half sizes along x and z. On a wall: along the wall, then up.
## edges, when given, are the margins on the -u, +u, -v and +v sides instead.
func shade(center: Vector3, n: Vector3, half: Vector2, margin: float, color: Color, requires := {}, into: SurfaceTool = null, edges := Vector4(-1, -1, -1, -1)) -> void:
	var u := Vector3.RIGHT if absf(n.y) > 0.5 else n.cross(Vector3.UP).normalized()
	var v := Vector3.BACK if absf(n.y) > 0.5 else Vector3.UP
	var st := into if into else _st(center, Finish.SHADE, requires)
	var e := edges if edges.x >= 0.0 else Vector4(margin, margin, margin, margin)
	var us := [-half.x - e.x, -half.x, half.x, half.x + e.y]
	var vs := [-half.y - e.z, -half.y, half.y, half.y + e.w]
	var ts := [0.0, 0.5, 0.5, 1.0]  # nine patches: the middle samples the texture's full-strength centre
	for i in 3:
		for j in 3:
			if us[i + 1] - us[i] < 0.0001 or vs[j + 1] - vs[j] < 0.0001:
				continue
			var p := []
			var uv := []
			for c: Array in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				p.append(center + u * us[c[0]] + v * vs[c[1]])
				uv.append(Vector2(ts[c[0]], ts[c[1]]))
			_poly(st, p, n, color, uv)


## Contact shadow under something standing on the floor (footprint half sizes in x and z).
func foot(center: Vector3, half: Vector2, strength := 0.5, requires := {}) -> void:
	shade(Vector3(center.x, 0.012, center.z), Vector3.UP, half, 0.18, Color(0, 0, 0, strength), requires)


## Invisible collision for furniture standing on the floor. At most 0.3 m tall: the player's capsule (radius
## 0.3) meets that at its widest, so it still stops them, and anything taller would hide what the player can
## see past it, even crouching (GameStage.can_see casts rays).
func solid(center: Vector3, size: Vector3) -> void:
	var h := minf(size.y, 0.3)
	var body := StaticBody3D.new()
	body.position = Vector3(center.x, h * 0.5, center.z)
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(size.x, h, size.z)
	shape.shape = b
	body.add_child(shape)
	add_child(body)


## Commits every batch as one MeshInstance3D, gated like the rest of the condo.
func finish() -> void:
	for key: String in _batches:
		var b: Array = _batches[key]
		var mesh := MeshInstance3D.new()
		mesh.name = key.validate_node_name()  # room|look|variant: readable in the remote scene tree
		mesh.mesh = (b[0] as SurfaceTool).commit()
		mesh.material_override = _look(b[1])
		if b[1] == Finish.SHADE or b[1] == Finish.UNLIT:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
		builder.gate(mesh, b[2])
	_batches.clear()


## One polygon (convex, points in order around it) facing n. Godot draws clockwise triangles as front
## faces, so each triangle is flipped if it would face away. normals: per point, for smooth shading.
func _poly(st: SurfaceTool, p: Array, n: Vector3, color: Color, uv: Array = [], normals: Array = []) -> void:
	for i in range(1, p.size() - 1):
		var tri := [0, i, i + 1]
		if (p[i] - p[0]).cross(p[i + 1] - p[0]).dot(n) > 0.0:
			tri = [0, i + 1, i]
		for k: int in tri:
			st.set_normal(normals[k] if not normals.is_empty() else n)
			st.set_color(color)
			st.set_uv(uv[k] if not uv.is_empty() else Vector2.ZERO)
			st.add_vertex(p[k])


func _st(at: Vector3, look: Finish, requires: Dictionary) -> SurfaceTool:
	# One batch per room keeps each mesh's bounds small. The Compatibility renderer gives a mesh only the
	# first max_lights_per_object lights that reach it (in pairing order, not the nearest; project.godot),
	# and the phone light, which casts shadows, draws every mesh it reaches once more.
	var key := "%s|%d|%s" % [ApartmentLayout.room_at(at if _anchor == null else _anchor, requires), look, requires]
	if not _batches.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[key] = [st, look, requires]
	return _batches[key][0]


func _look(look: Finish) -> Material:
	if _looks.has(look):
		return _looks[look]
	var m: StandardMaterial3D
	if look == Finish.TILE:  # wall tiles, 60 x 30 cm laid landscape
		m = builder.tile_material(Color(0.86, 0.87, 0.86), Color(0.6, 0.61, 0.59), Vector2(0.6, 0.3))
	else:
		m = StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true  # colours here are picked like albedo colours
		m.roughness = 0.3 if look == Finish.GLOSS else 0.85
	if look == Finish.UNLIT:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if look == Finish.SHADE:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = _falloff()
		m.texture_repeat = false
		m.disable_fog = true
	_looks[look] = m
	return m


## White with alpha 1 at the centre falling to 0 at the edges and corners, squared like real occlusion.
static func _falloff() -> ImageTexture:
	# No mipmaps: seen at a grazing angle, the small ones flatten the falloff into a hard-edged rectangle.
	var img := Image.create(64, 64, false, Image.FORMAT_LA8)
	for y in 64:
		for x in 64:
			var d := minf(Vector2(absf(x - 31.5), absf(y - 31.5)).length() / 31.5, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, pow(1.0 - d, 2.0)))
	return ImageTexture.create_from_image(img)


## Size of a box `length` along a wall running along `along` (x or z), `depth` through it.
static func _sz(along: Vector3, length: float, height: float, depth: float) -> Vector3:
	return Vector3(length, height, depth) if absf(along.x) > 0.5 else Vector3(depth, height, length)


# --- walls (called by ApartmentBuilder) ---------------------------------------------------------

## Tile skirting and the soft shadows where a wall piece meets the floor and the ceiling. Each face is cut
## where the room beside it changes, and each part goes in that room's batch (the outside of the building
## gets nothing). A face can border a room that only exists in a later variant (the gap's long form behind
## the bathroom): that part is drawn for that variant only. The shadows fade out over a part's last 15 cm,
## so they stop at a doorway and inside a wall the piece runs into, not on the floor beyond it. The gap has
## no skirting. coping: the corridor's half wall gets a concrete cap.
func wall_piece(center: Vector3, size: Vector3, along: Vector3, requires: Dictionary, skirting: bool, coping := false) -> void:
	var length := size.x if absf(along.x) > 0.5 else size.z
	var t := size.z if absf(along.x) > 0.5 else size.x
	var across := Vector3(along.z, 0.0, along.x)  # horizontal, through the wall
	var mid := center.x if absf(along.x) > 0.5 else center.z
	var options: Array[Dictionary] = [requires]  # the piece's own variant first, then the later rooms'
	for room_id: StringName in ApartmentLayout.ROOMS:
		var room: Dictionary = ApartmentLayout.ROOMS[room_id]
		for form: StringName in ([&"default", &"long"] if room.has("long_rects") else [&""]):
			if form != &"" and requires.get(room_id, form) != form:
				continue  # never outside the piece's own variant
			var o := requires.merged(room.get("requires", {}))
			if form != &"":
				o[room_id] = form
			if not options.has(o):
				options.append(o)
	var cuts := [-length * 0.5, length * 0.5]  # along the piece, from its centre
	for o: Dictionary in options:
		for room_id: StringName in ApartmentLayout.ROOMS:
			for r: Rect2 in ApartmentLayout.room_rects(room_id, o):
				for edge: float in ([r.position.x, r.end.x] if absf(along.x) > 0.5 else [r.position.y, r.end.y]):
					if absf(edge - mid) < length * 0.5 - 0.01 and not cuts.has(edge - mid):
						cuts.append(edge - mid)
	cuts.sort()
	for s: float in [-1.0, 1.0]:
		var n := across * s
		var face := center + n * t * 0.5
		var parts := []  # [a, b, room, variant], neighbours in the same room and variant joined
		for i in cuts.size() - 1:
			var a: float = cuts[i]
			var b: float = cuts[i + 1]
			if b - a < 0.01:
				continue
			for o: Dictionary in options:
				var room := ApartmentLayout.room_at(face + along * (a + b) * 0.5 + n * 0.05, o)
				if room == &"":
					continue
				if not parts.is_empty() and parts[-1][1] == a and parts[-1][2] == room and parts[-1][3] == o:
					parts[-1][1] = b
				else:
					parts.append([a, b, room, o])
				break
		for part: Array in parts:
			var a: float = part[0]
			var b: float = part[1]
			var o: Dictionary = part[3]
			_anchor = face + along * (a + b) * 0.5 + n * 0.05
			# A cut lies on another wall's centre line or an open boundary: run on under that wall's half.
			var a2 := a - (t * 0.5 if a > cuts[0] else 0.0)
			var b2 := b + (t * 0.5 if b < cuts[-1] else 0.0)
			var fade := minf(0.15, (b2 - a2) * 0.5)
			var at := face + along * (a2 + b2) * 0.5
			if center.y - size.y * 0.5 < 0.01:
				if skirting and part[2] != &"gap":
					box(Vector3(face.x, 0.05, face.z) + along * (a + b) * 0.5 + n * 0.01, _sz(along, b - a, 0.1, 0.02), SKIRTING, Finish.GLOSS, o)
				_wall_shade(Vector3(at.x, 0.004, at.z), Vector3.UP, along, n, (b2 - a2) * 0.5 - fade, fade, 0.32, 0.5, o)
			if center.y + size.y * 0.5 > ApartmentLayout.CEILING - 0.01:
				_wall_shade(Vector3(at.x, ApartmentLayout.CEILING - 0.004, at.z), Vector3.DOWN, along, n, (b2 - a2) * 0.5 - fade, fade, 0.28, 0.35, o)
			if coping:
				box(center + Vector3.UP * (size.y * 0.5 + 0.025), _sz(along, length, 0.05, t + 0.08), Color(0.6, 0.59, 0.56))
				coping = false
			_anchor = null


## A strip of shadow along a wall face: `half` along the wall at full strength, `fade` at each end, `margin`
## out into the room on side n.
func _wall_shade(c: Vector3, n: Vector3, along: Vector3, side: Vector3, half: float, fade: float, margin: float, strength: float, requires: Dictionary) -> void:
	var out := Vector2(margin if side.x + side.z < 0.0 else 0.0, margin if side.x + side.z > 0.0 else 0.0)  # (-, +) across
	if absf(along.x) > 0.5:
		shade(c, n, Vector2(half, 0.0), 0.0, Color(0, 0, 0, strength), requires, null, Vector4(fade, fade, out.x, out.y))
	else:
		shade(c, n, Vector2(0.0, half), 0.0, Color(0, 0, 0, strength), requires, null, Vector4(out.x, out.y, fade, fade))


## Architrave around a doorway (c: middle of the opening on the wall's centre line, at the floor).
func door_frame(c: Vector3, along: Vector3, width: float, color: Color, requires: Dictionary) -> void:
	var h := ApartmentLayout.DOOR_HEIGHT
	var t := ApartmentLayout.WALL_T
	var across := Vector3(along.z, 0.0, along.x)
	_anchor = c + across * 0.3 if ApartmentLayout.room_at(c + across * 0.3, requires) != &"" else c - across * 0.3
	for s: float in [-1.0, 1.0]:
		box(c + along * s * (width * 0.5 + 0.035) + Vector3.UP * (h + 0.07) * 0.5, _sz(along, 0.07, h + 0.07, t + 0.03), color, Finish.MATTE, requires)
		box(c + along * s * (width * 0.5 - 0.01) + Vector3.UP * h * 0.5, _sz(along, 0.02, h, t + 0.006), color, Finish.MATTE, requires)
	box(c + Vector3.UP * (h + 0.035), _sz(along, width + 0.14, 0.07, t + 0.03), color, Finish.MATTE, requires)
	box(c + Vector3.UP * (h - 0.006), _sz(along, width, 0.012, t + 0.006), color, Finish.MATTE, requires)
	_anchor = null


## Aluminium frame, tiled sill and a painted iron grille on the room side of a window opening.
func window(c: Vector3, along: Vector3, inward: Vector3, width: float, height: float, requires: Dictionary) -> void:
	var t := ApartmentLayout.WALL_T
	_anchor = c + inward * 0.3
	for s: float in [-1.0, 1.0]:
		box(c + along * s * (width * 0.5 - 0.025), _sz(along, 0.05, height, 0.09), BRONZE, Finish.GLOSS, requires)
		box(c + Vector3.UP * s * (height * 0.5 - 0.025), _sz(along, width, 0.05, 0.09), BRONZE, Finish.GLOSS, requires)
	var panes := 3 if width > 2.0 else 2
	for i in range(1, panes):
		box(c + along * (width * (float(i) / panes - 0.5)), _sz(along, 0.04, height, 0.07), BRONZE, Finish.GLOSS, requires)
	box(c + inward * (t * 0.5 + 0.07) + Vector3.DOWN * (height * 0.5 + 0.015), _sz(along, width + 0.1, 0.03, 0.17), SKIRTING, Finish.GLOSS, requires)
	var g := c + inward * (t * 0.5 + 0.045)
	var bars := int(width / 0.12)
	for i in range(1, bars):
		box(g + along * (width * (float(i) / bars - 0.5)), _sz(along, 0.014, height - 0.02, 0.014), GRILLE, Finish.GLOSS, requires)
	for y: float in [-0.48, 0.0, 0.48]:
		box(g + Vector3.UP * y * (height - 0.06), _sz(along, width - 0.02, 0.02, 0.02), GRILLE, Finish.GLOSS, requires)
	_anchor = null


## Folding iron gate on the corridor side of a front door (x0..x1 along the wall at z); bunched when open.
func grille_gate(x0: float, x1: float, z: float, open: bool) -> void:
	if open:
		for i in 14:
			box(Vector3(x1 + 0.06 + i * 0.026, 1.06, z + 0.03 + (i % 2) * 0.012), Vector3(0.016, 2.06, 0.016), GATE, Finish.GLOSS)
		return
	for y: float in [0.05, 1.05, 2.07]:
		box(Vector3((x0 + x1) * 0.5, y, z), Vector3(x1 - x0 + 0.06, 0.03, 0.022), GATE, Finish.GLOSS)
	var n := int((x1 - x0) / 0.1)
	for i in n + 1:
		box(Vector3(x0 + (x1 - x0) * i / n, 1.06, z), Vector3(0.016, 2.06, 0.016), GATE, Finish.GLOSS)
	box(Vector3(x1 - 0.1, 1.05, z + 0.03), Vector3(0.08, 0.14, 0.04), GATE, Finish.GLOSS)  # lock box
	box(Vector3(x1 - 0.1, 0.96, z + 0.06), Vector3(0.045, 0.055, 0.02), Color(0.6, 0.5, 0.25), Finish.GLOSS)  # padlock


# --- the condo, room by room ----------------------------------------------------------------------

func dress() -> void:
	_rng.seed = 1147
	_living()
	_kitchen()
	_entrance()
	_bathroom()
	_bedroom()
	_corridor()
	_beyond()


## A 13 A switched socket, the square British kind, on a wall facing n.
func _socket(pos: Vector3, n: Vector3) -> void:
	var xf := Transform3D(Basis.looking_at(-n), pos + n * 0.005)
	box_xf(xf, Vector3(0.086, 0.086, 0.01), PLASTIC_WHITE)
	box_xf(xf.translated_local(Vector3(0.024, 0.0, 0.007)), Vector3(0.018, 0.03, 0.006), Color(0.75, 0.74, 0.7))


## Snake plant in a clay pot: the plant every corridor and living room here has.
func _snake_plant(base: Vector3) -> void:
	cylinder(base, 0.15, 0.3, Color(0.46, 0.27, 0.18), Finish.MATTE, {}, 0.18)
	for i in 8:
		var yaw := _rng.randf() * TAU
		var lean := _rng.randf_range(0.05, 0.28)
		var h := _rng.randf_range(0.45, 0.8)
		var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lean), base + Vector3(_rng.randf_range(-0.05, 0.05), 0.27, _rng.randf_range(-0.05, 0.05)))
		box_xf(xf.translated_local(Vector3.UP * h * 0.5), Vector3(0.065, h, 0.008), Color(0.16, 0.27, 0.15).lerp(Color(0.3, 0.33, 0.16), _rng.randf() * 0.4))
	solid(base + Vector3.UP * 0.45, Vector3(0.36, 0.9, 0.36))
	foot(base, Vector2(0.15, 0.15), 0.55)


## Clothes hung to dry on a line with pegs (garment flat along the line, which runs along z at x).
func _garment(x: float, z: float, top: float, w: float, h: float, color: Color, sleeves := false) -> void:
	var tilt := Basis(Vector3.RIGHT, _rng.randf_range(-0.04, 0.04))
	box_xf(Transform3D(tilt, Vector3(x, top - h * 0.5, z)), Vector3(0.012, h, w), color)
	if sleeves:
		for s: float in [-1.0, 1.0]:
			box_xf(Transform3D(Basis(Vector3.RIGHT, s * 0.5), Vector3(x, top - 0.12, z + s * (w * 0.5 + 0.06))), Vector3(0.01, 0.2, 0.16), color)
	for s: float in [-1.0, 1.0]:
		box(Vector3(x, top + 0.01, z + s * w * 0.35), Vector3(0.025, 0.05, 0.012), Color(0.3, 0.55, 0.75), Finish.GLOSS)


func _living() -> void:
	# Sofa cushions, worn into the shape of one person.
	for i in 3:
		var x := 5.73 + i * 0.77
		box(Vector3(x, 0.49 - (0.015 if i == 0 else 0.0), 9.39), Vector3(0.72, 0.1, 0.56), Color(0.33, 0.36, 0.41))
		box(Vector3(x, 0.78, 9.62), Vector3(0.72, 0.36, 0.14), Color(0.32, 0.35, 0.4))
	box_xf(Transform3D(Basis.from_euler(Vector3(-0.35, 0.4, 0.1)), Vector3(7.25, 0.67, 9.42)), Vector3(0.38, 0.38, 0.11), Color(0.56, 0.45, 0.24))
	# The TV corner (cabinet, TV, decoder with its light, router with its antennas and lights) is a model: art/tv_cabinet.
	box(Vector3(6.5, 2.165, 4.243), Vector3(0.85, 0.03, 0.008), Color(0.2, 0.2, 0.2))  # aircon vent
	_socket(Vector3(5.4, 0.3, 4.075), Vector3.BACK)
	_socket(Vector3(7.9, 0.3, 4.075), Vector3.BACK)
	_socket(Vector3(9.0, 0.3, 9.925), Vector3.FORWARD)
	_clock(Vector3(5.3, 2.05, 4.075))
	# Dining table (a model, with tonight's teh tarik still in its bag and the food cover over something): its collision
	# and shadow. The chairs are models too; they get their shadows here (the turned chair is a variant, so is its shadow).
	solid(Vector3(4.5, 0.38, 6.2), Vector3(1.1, 0.76, 0.75))
	foot(Vector3(4.5, 0, 6.2), Vector2(0.5, 0.33), 0.4)
	for c: Array in [[Vector3(4.5, 0, 6.85), {}], [Vector3(4.5, 0, 5.55), {&"living_chair": &"default"}], [Vector3(3.45, 0, 5.2), {&"living_chair": &"turned"}]]:
		foot(c[0], Vector2(0.18, 0.18), 0.35, c[1])
	# Laundry by the window: a T-shirt, the mamak apron (a model, the figure's own), a towel. In the dark they are the
	# right height.
	box(Vector3(9.3, 0.85, 6.0), Vector3(0.025, 1.7, 0.025), STEEL, Finish.GLOSS)
	box(Vector3(9.3, 0.85, 7.6), Vector3(0.025, 1.7, 0.025), STEEL, Finish.GLOSS)
	box(Vector3(9.3, 1.7, 6.8), Vector3(0.025, 0.025, 1.64), STEEL, Finish.GLOSS)
	for z: float in [6.0, 7.6]:
		box(Vector3(9.3, 0.012, z), Vector3(0.5, 0.024, 0.03), STEEL, Finish.GLOSS)
	_garment(9.3, 6.27, 1.69, 0.48, 0.62, Color(0.16, 0.2, 0.3), true)
	_garment(9.3, 7.35, 1.69, 0.38, 0.68, Color(0.33, 0.45, 0.39))
	solid(Vector3(9.3, 0.85, 6.8), Vector3(0.3, 1.7, 1.64))
	_snake_plant(Vector3(9.55, 0, 9.5))


## The wall clock (art/wall_clock), its back on the wall at `at`. Its hands follow the game clock (_process).
func _clock(at: Vector3) -> void:
	var clock := ApartmentBuilder.model(&"wall_clock")
	clock.position = at
	add_child(clock)
	builder.models[&"wall_clock"] = clock
	_hands.append(clock.get_node(^"HourHand") as Node3D)
	_hands.append(clock.get_node(^"MinuteHand") as Node3D)


func _kitchen() -> void:
	# Black granite top, with the sink set into it, and cabinet doors.
	box(Vector3(0.37, 0.915, 4.9), Vector3(0.66, 0.03, 3.02), Color(0.13, 0.13, 0.13), Finish.GLOSS)
	box(Vector3(0.35, 0.932, 4.2), Vector3(0.45, 0.006, 0.5), STEEL, Finish.GLOSS)
	box(Vector3(0.35, 0.936, 4.2), Vector3(0.37, 0.004, 0.41), Color(0.26, 0.27, 0.28), Finish.GLOSS)
	cylinder(Vector3(0.12, 0.93, 4.2), 0.016, 0.3, CHROME)
	box(Vector3(0.21, 1.22, 4.2), Vector3(0.19, 0.02, 0.02), CHROME, Finish.GLOSS)
	for z: float in [3.9, 4.4, 4.9, 5.4, 5.9]:
		box(Vector3(0.652, 0.45, z), Vector3(0.004, 0.86, 0.006), WOOD_DARK)
		box(Vector3(0.397, 2.0, z), Vector3(0.004, 0.66, 0.006), Color(0.4, 0.36, 0.31))
	for z: float in [3.65, 4.15, 4.65, 5.15, 5.65, 6.15]:
		box(Vector3(0.665, 0.8, z), Vector3(0.02, 0.012, 0.12), STEEL, Finish.GLOSS)
	box(Vector3(0.081, 1.29, 4.9), Vector3(0.012, 0.72, 3.0), Color.WHITE, Finish.TILE)  # backsplash
	_socket(Vector3(0.087, 1.1, 5.1), Vector3.RIGHT)
	# Rice cooker, kettle on the hob, oil and kicap by the stove.
	cylinder(Vector3(0.35, 0.93, 3.7), 0.14, 0.2, Color(0.92, 0.9, 0.85))
	cylinder(Vector3(0.35, 1.13, 3.7), 0.13, 0.05, Color(0.85, 0.83, 0.78), Finish.GLOSS, {}, 0.07)
	box(Vector3(0.47, 1.04, 3.7), Vector3(0.04, 0.03, 0.03), Color(0.2, 0.55, 0.3), Finish.UNLIT)  # "warm"
	cylinder(Vector3(0.35, 0.94, 5.6), 0.1, 0.17, STEEL, Finish.GLOSS, {}, 0.07)
	box_xf(Transform3D(Basis(Vector3.BACK, -0.6), Vector3(0.48, 1.0, 5.6)), Vector3(0.12, 0.025, 0.025), STEEL, Finish.GLOSS)
	cylinder(Vector3(0.2, 0.93, 6.12), 0.04, 0.26, Color(0.8, 0.62, 0.15), Finish.GLOSS)
	cylinder(Vector3(0.28, 0.93, 6.22), 0.03, 0.22, Color(0.1, 0.06, 0.04), Finish.GLOSS)
	# Gas cylinder at the end of the counter; the hose goes into the cabinet, to the hob.
	cylinder(Vector3(0.3, 0, 6.66), 0.16, 0.5, Color(0.6, 0.3, 0.18), Finish.GLOSS, {}, 0.14)
	cylinder(Vector3(0.3, 0.5, 6.66), 0.06, 0.06, Color(0.5, 0.5, 0.5))
	box(Vector3(0.3, 0.58, 6.66), Vector3(0.08, 0.06, 0.08), Color(0.15, 0.15, 0.15))
	box(Vector3(0.3, 0.62, 6.53), Vector3(0.02, 0.02, 0.22), Color(0.2, 0.2, 0.2))
	box(Vector3(0.3, 0.715, 6.41), Vector3(0.02, 0.21, 0.02), Color(0.2, 0.2, 0.2))
	solid(Vector3(0.3, 0.3, 6.66), Vector3(0.34, 0.6, 0.34))
	foot(Vector3(0.3, 0, 6.66), Vector2(0.15, 0.15), 0.5)


func _entrance() -> void:
	# The shoe rack (a model; the shoes on it are a variant) keeps its collision and shade here.
	solid(Vector3(0.25, 0.3, 8.0), Vector3(0.4, 0.6, 1.0))  # the rack's Interactable only collides while the shoes are on it
	foot(Vector3(0.25, 0, 8.0), Vector2(0.19, 0.5), 0.45)
	box(Vector3(1.5, 0.006, 9.65), Vector3(0.9, 0.012, 0.55), Color(0.42, 0.32, 0.2))  # coir mat
	box(Vector3(0.105, 2.05, 9.3), Vector3(0.06, 0.36, 0.3), Color(0.68, 0.68, 0.66), Finish.GLOSS)  # DB box
	_socket(Vector3(0.075, 0.3, 7.4), Vector3.RIGHT)
	# Light from the corridor under the front door; with someone standing outside it, two feet break it.
	var lm := (_look(Finish.SHADE) as StandardMaterial3D).duplicate() as StandardMaterial3D
	lm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_leak = _leak_strip("door_leak", lm, [[1.04, 1.96, 0.12, 0.12]])
	# Two gaps, each dark over 0.16 m and back to full strength 0.04 m either side, centred on x = 1.31 and 1.65: the strip is what is left between them.
	_leak_feet = _leak_strip("door_leak_feet", lm, [[1.04, 1.19, 0.12, 0.04], [1.43, 1.53, 0.04, 0.04], [1.77, 1.96, 0.04, 0.12]])
	_show_leak()


## The strip of corridor light on the floor inside the front door, as segments of [from x, to x, margin left,
## margin right] (full strength between from and to; shade() fades each side over its margin).
func _leak_strip(strip_name: String, material: Material, segments: Array) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s: Array in segments:
		shade(Vector3((s[0] + s[1]) * 0.5, 0.014, 9.925), Vector3.UP, Vector2((s[1] - s[0]) * 0.5, 0.0), 0.12, Color(0.75, 0.85, 0.95, 0.4), {}, st, Vector4(s[2], s[3], 0.12, 0.12))
	var strip := MeshInstance3D.new()
	strip.name = strip_name
	strip.mesh = st.commit()
	strip.material_override = material
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(strip)
	return strip


func _bathroom() -> void:
	# Walls tiled to 1.8 m, like every bathroom here.
	for p: Array in [[Vector3(3.081, 0.9, 0.25), Vector3(0.012, 1.8, 4.35)], [Vector3(5.419, 0.9, 0.25), Vector3(0.012, 1.8, 4.35)],
			[Vector3(4.25, 0.9, -1.919), Vector3(2.35, 1.8, 0.012)], [Vector3(3.5, 0.9, 2.419), Vector3(0.82, 1.8, 0.012)],
			[Vector3(5.06, 0.9, 2.419), Vector3(0.73, 1.8, 0.012)]]:
		box(p[0], p[1], Color.WHITE, Finish.TILE)
	# Toilet with the bidet spray, against the east wall.
	cylinder(Vector3(5.12, 0, 0.4), 0.15, 0.38, PORCELAIN, Finish.GLOSS, {}, 0.2, Color(0, 0, 0, 0), 1.3)
	cylinder(Vector3(5.12, 0.38, 0.4), 0.2, 0.025, Color(0.95, 0.95, 0.93), Finish.GLOSS, {}, -1.0, Color(0.55, 0.6, 0.6), 1.25)
	box(Vector3(5.37, 0.62, 0.4), Vector3(0.18, 0.36, 0.44), PORCELAIN, Finish.GLOSS)
	box(Vector3(5.29, 0.63, 0.4), Vector3(0.025, 0.42, 0.38), Color(0.95, 0.95, 0.93), Finish.GLOSS)  # lid, up
	box(Vector3(5.37, 0.805, 0.4), Vector3(0.06, 0.012, 0.06), CHROME, Finish.GLOSS)
	box(Vector3(5.4, 0.62, 0.74), Vector3(0.03, 0.06, 0.05), CHROME, Finish.GLOSS)
	box(Vector3(5.39, 0.6, 0.79), Vector3(0.03, 0.12, 0.035), PLASTIC_WHITE, Finish.GLOSS)
	box(Vector3(5.38, 0.33, 0.78), Vector3(0.012, 0.5, 0.012), Color(0.75, 0.75, 0.75), Finish.GLOSS)
	solid(Vector3(5.145, 0.4, 0.4), Vector3(0.55, 0.8, 0.46))  # seat rim to the tiles
	foot(Vector3(5.15, 0, 0.4), Vector2(0.24, 0.2), 0.45)
	# The basin (a model, with its tap, shelf, cup and toothbrush) keeps its collision and shade here.
	solid(Vector3(3.3, 0.46, 1.0), Vector3(0.38, 0.92, 0.48))
	foot(Vector3(3.3, 0, 1.0), Vector2(0.08, 0.08), 0.4)
	# Water heater (its light says it is on), the shower rail, the floor trap.
	box(Vector3(3.312, 1.86, -1.5), Vector3(0.004, 0.014, 0.014), Color(1.0, 0.15, 0.08), Finish.UNLIT)
	for z: float in [-1.44, -1.56]:
		box(Vector3(3.14, 1.58, z), Vector3(0.016, 0.4, 0.016), CHROME, Finish.GLOSS)
	box(Vector3(3.11, 1.3, -1.05), Vector3(0.02, 0.85, 0.02), CHROME, Finish.GLOSS)
	box_xf(Transform3D(Basis(Vector3.BACK, -0.3), Vector3(3.15, 1.72, -1.05)), Vector3(0.05, 0.15, 0.06), CHROME, Finish.GLOSS)
	box(Vector3(3.12, 1.15, -1.12), Vector3(0.012, 0.6, 0.012), Color(0.7, 0.7, 0.7), Finish.GLOSS)
	box(Vector3(4.2, 0.003, -1.4), Vector3(0.11, 0.005, 0.11), STEEL, Finish.GLOSS)
	shade(Vector3(4.2, 0.005, -1.4), Vector3.UP, Vector2(0.2, 0.15), 0.3, Color(0.1, 0.12, 0.12, 0.3))
	# The pail, full, with the gayung floating in it.
	cylinder(Vector3(5.2, 0, 1.25), 0.14, 0.34, Color(0.66, 0.13, 0.11), Finish.GLOSS, {}, 0.165, Color(0.2, 0.27, 0.3))
	cylinder(Vector3(5.2, 0.31, 1.22), 0.07, 0.06, Color(0.2, 0.42, 0.7))
	box(Vector3(5.2, 0.37, 1.34), Vector3(0.025, 0.02, 0.16), Color(0.2, 0.42, 0.7), Finish.GLOSS)
	foot(Vector3(5.2, 0, 1.25), Vector2(0.13, 0.13), 0.45)
	solid(Vector3(5.2, 0.17, 1.25), Vector3(0.28, 0.34, 0.28))
	shade(Vector3(4.25, ApartmentLayout.CEILING - 0.005, -1.3), Vector3.DOWN, Vector2(0.3, 0.2), 0.45, Color(0.4, 0.3, 0.12, 0.35))  # damp


func _bedroom() -> void:
	# Wardrobe doors with a cardboard box on top; dresser drawers.
	box(Vector3(6.153, 1.0, 1.4), Vector3(0.004, 1.96, 0.006), Color(0.2, 0.14, 0.1))
	for z: float in [1.34, 1.46]:
		box(Vector3(6.165, 1.0, z), Vector3(0.025, 0.18, 0.02), STEEL, Finish.GLOSS)
	box(Vector3(5.85, 2.12, 1.3), Vector3(0.45, 0.24, 0.5), Color(0.55, 0.42, 0.28), Finish.MATTE, {}, 0.1)
	for y: float in [0.27, 0.52]:
		box(Vector3(6.1, y, -0.973), Vector3(0.96, 0.006, 0.004), Color(0.2, 0.14, 0.1))
	for y: float in [0.4, 0.64]:
		box(Vector3(6.1, y, -0.965), Vector3(0.12, 0.015, 0.02), STEEL, Finish.GLOSS)
	box(Vector3(9.777, 2.165, 0.2), Vector3(0.006, 0.03, 0.8), Color(0.2, 0.2, 0.2))  # aircon vent
	# Same material as the other indicator lights: the warm-up may run while it is dark, and a material of
	# its own would then compile on its first blink, mid-game.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	box_xf(Transform3D(), Vector3(0.004, 0.012, 0.012), Color(0.3, 1.0, 0.4), Finish.UNLIT, {}, st)
	_led = MeshInstance3D.new()
	_led.mesh = st.commit()
	_led.material_override = _look(Finish.UNLIT)
	_led.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_led.position = Vector3(9.776, 2.2, -0.15)
	add_child(_led)
	_socket(Vector3(6.2, 0.3, -1.925), Vector3.BACK)
	# Curtains, pushed to the sides, hanging clear of the sill. They stay when the window is a door.
	box(Vector3(7.8, 2.25, -1.74), Vector3(2.3, 0.025, 0.025), STEEL, Finish.GLOSS)
	for x0: float in [6.9, 8.35]:
		for i in 4:
			box(Vector3(x0 + 0.035 + i * 0.07, 1.47, -1.72 + (i % 2) * 0.03), Vector3(0.075, 1.54, 0.03), Color(0.36, 0.2, 0.19))


func _corridor() -> void:
	grille_gate(1.0, 2.0, 10.12, true)
	grille_gate(-2.5, -1.5, 10.2, false)
	grille_gate(11.5, 12.5, 10.2, false)
	# B-12-06's red lantern from last Chinese New Year; B-12-08's delivery slip.
	box(Vector3(-2.68, (1.98 + ApartmentLayout.CEILING) * 0.5, 10.24), Vector3(0.006, ApartmentLayout.CEILING - 1.98, 0.006), Color(0.1, 0.1, 0.1))  # string from the ceiling
	cylinder(Vector3(-2.68, 1.76, 10.24), 0.09, 0.22, Color(0.62, 0.08, 0.06), Finish.MATTE, {}, 0.09)
	box(Vector3(-2.68, 1.66, 10.24), Vector3(0.012, 0.16, 0.012), Color(0.75, 0.6, 0.2))
	box(Vector3(12.2, 1.32, 10.215), Vector3(0.1, 0.14, 0.004), Color(0.92, 0.9, 0.84))
	# Shoes on the neighbours' racks, the fire extinguisher by the exit, a snake plant at the parapet.
	for spec: Array in [[-0.95, Color(0.12, 0.12, 0.13)], [13.05, Color(0.6, 0.6, 0.62)]]:
		for i in 2:
			for s: float in [-0.06, 0.06]:
				box(Vector3(spec[0] - 0.2 + i * 0.4 + s, 0.54, 10.35), Vector3(0.09, 0.08, 0.26), spec[1])
		box(Vector3(spec[0] + 0.1, 0.015, 10.6), Vector3(0.1, 0.03, 0.26), Color(0.2, 0.3, 0.55))
	cylinder(Vector3(-3.4, 0.12, 10.2), 0.075, 0.46, Color(0.68, 0.07, 0.05))
	cylinder(Vector3(-3.4, 0.58, 10.2), 0.03, 0.07, Color(0.12, 0.12, 0.12))
	box(Vector3(-3.4, 0.4, 10.11), Vector3(0.05, 0.6, 0.03), Color(0.2, 0.2, 0.2))
	_snake_plant(Vector3(5.5, 0, 12.15))
	box(Vector3(18.937, 1.05, 11.25), Vector3(0.004, 2.1, 0.008), Color(0.2, 0.2, 0.2))  # lift doors' seam


func _beyond() -> void:
	var gap := {&"bedroom": &"door"}
	# The gap: bare concrete, conduit along the ceiling.
	for variant: Array in [[ApartmentLayout.ROOMS[&"gap"]["rects"], gap.merged({&"gap": &"default"})], [ApartmentLayout.ROOMS[&"gap"]["long_rects"], gap.merged({&"gap": &"long"})]]:
		for r: Rect2 in variant[0]:
			var c := r.get_center()
			var along_x := r.size.x > r.size.y
			var off := Vector3(0, 0, r.size.y * 0.5 - 0.12) if along_x else Vector3(r.size.x * 0.5 - 0.12, 0, 0)
			box(Vector3(c.x, ApartmentLayout.CEILING - 0.018, c.y) + off, Vector3(r.size.x, 0.035, 0.035) if along_x else Vector3(0.035, 0.035, r.size.y), Color(0.45, 0.45, 0.43), Finish.MATTE, variant[1])
	for z: float in [-4.0, -7.5, -11.0]:
		shade(Vector3(7.0 + 0.08, 1.9, z), Vector3.RIGHT, Vector2(0.15, 0.6), 0.3, Color(0.25, 0.2, 0.1, 0.35), gap.merged({&"gap": &"default"}))
	# B-11-07: vacant since March. Newspapers on the floor, water stains, dust.
	for p: Array in [[Vector3(6.6, 0.004, -15.0), 0.3], [Vector3(7.1, 0.006, -14.8), -0.5], [Vector3(8.9, 0.004, -17.6), 1.2]]:
		box(p[0], Vector3(0.58, 0.004, 0.4), Color(0.78, 0.74, 0.62), Finish.MATTE, gap, p[1])
	shade(Vector3(8.2, ApartmentLayout.CEILING - 0.005, -15.4), Vector3.DOWN, Vector2(0.5, 0.35), 0.5, Color(0.35, 0.26, 0.1, 0.45), gap)
	shade(Vector3(10.0 - 0.08, 1.7, -16.8), Vector3.LEFT, Vector2(0.25, 0.9), 0.35, Color(0.3, 0.22, 0.1, 0.4), gap)
	shade(Vector3(7.75, 0.013, -16.2), Vector3.UP, Vector2(1.6, 1.6), 0.6, Color(0.18, 0.15, 0.1, 0.25), gap)
