class_name RoadLayout
extends RefCounted
## The road down the mountain, as data and math (no nodes). s is metres along the road from the bus stop: negative is
## uphill, towards the resort, and the road starts at s = -200. `across` is metres to the left of the centreline,
## facing the way the road goes down; Malaysia drives on the left, so the couple's lane is at +LANE.
## The road is a list of straights and bends at a constant 6 % downhill, built once into a Curve3D.

const LANE := 1.8  # the centre of a lane, off the centreline
const WIDTH := 7.2  # edge line to edge line
const GRADE := 0.06  # metres down for every metre along the road
const START_S := -200.0  # the resort end
const LENGTH := 3200.0  # the road goes down this far (the curve runs on a little past it)
const BUS_STOP_S := 0.0
const BUS_STOP := Vector3(-4.6, 0.0, 0.0)  # point(BUS_STOP_S, 4.6): on the left verge, where he waits
const EXIT := Vector3(-5.0, 3.0, 49.91)  # point(-50, 5.0): the resort's staff exit, up the road from the stop
const TUNNEL := Vector2(260.0, 340.0)  # start_s, end_s, on the straight below the resort

## In order from START_S: ["straight", length] or ["bend", radius, degrees], positive degrees turning left. Lengths are
## along the road; radii are on the map. The road starts facing -Z, with s = 0 at the origin.
const SEGMENTS := [
	["straight", 260.0],  # the resort side: the staff exit at -50, the stop at 0
	["bend", 120.0, 20.0],
	["straight", 80.0],
	["bend", 100.0, -20.0],
	["straight", 170.0],  # the tunnel
	["bend", 60.0, -90.0],
	["straight", 150.0],
	["bend", 30.0, 180.0],  # switchback 1
	["straight", 150.0],
	["bend", 26.0, -180.0],  # switchback 2
	["straight", 150.0],
	["bend", 32.0, 180.0],  # switchback 3
	["straight", 150.0],
	["bend", 60.0, -90.0],
	["straight", 110.0],
	["bend", 90.0, 30.0],
	["straight", 100.0],
	["bend", 90.0, -30.0],
	["straight", 500.0],  # the long straight: the car dies here, and the light shows far down it
	["bend", 60.0, -90.0],
	["straight", 140.0],
	["bend", 28.0, 180.0],  # switchback 4
	["straight", 140.0],
	["bend", 24.0, -180.0],  # switchback 5
	["straight", 140.0],
	["bend", 34.0, 180.0],  # switchback 6
	["straight", 200.0],  # out of the hills
]

static var _curve: Curve3D


## The point on the road at s, `across` metres to the left of the centreline, at the road's height.
static func point(s: float, across := 0.0) -> Vector3:
	var p := _road().sample_baked(s - START_S)
	if across == 0.0:
		return p
	var t := tangent(s)
	return p + Vector3(t.z, 0.0, -t.x).normalized() * across


## The way the road goes at s: a unit vector, pointing 6 % down.
static func tangent(s: float) -> Vector3:
	var c := _road()
	return (c.sample_baked(s - START_S + 0.5) - c.sample_baked(s - START_S - 0.5)).normalized()


## The s of the road's centreline nearest to pos.
static func closest_s(pos: Vector3) -> float:
	return _road().get_closest_offset(pos) + START_S


## Metres to the left of the centreline at s that pos is (point's `across`).
static func across(pos: Vector3, s: float) -> float:
	var t := tangent(s)
	return (pos - point(s)).dot(Vector3(t.z, 0.0, -t.x).normalized())


static func min_radius() -> float:
	var r := INF
	for seg: Array in SEGMENTS:
		if seg[0] == "bend":
			r = minf(r, seg[1])
	return r


static func _road() -> Curve3D:
	if _curve == null:
		_curve = _build()
	return _curve


## A point every metre or so. A bend's step goes along the heading halfway through its turn: the points stay within
## millimetres of the arc, and every step is exactly its length along the road, so the curve's offset is s - START_S.
static func _build() -> Curve3D:
	var c := Curve3D.new()
	c.bake_interval = 1.0
	var flat := sqrt(1.0 - GRADE * GRADE)  # metres on the map for a metre along the road
	var s := START_S
	var at := Vector2(0.0, -START_S * flat)  # x, z
	var heading := 0.0  # 0 faces -Z; positive is to the left
	c.add_point(Vector3(at.x, -GRADE * s, at.y))
	for seg: Array in SEGMENTS:
		var length: float = seg[1] if seg[0] == "straight" else seg[1] * deg_to_rad(absf(seg[2])) / flat
		var steps := ceili(length)
		var turn := 0.0 if seg[0] == "straight" else deg_to_rad(seg[2]) / steps
		for i in steps:
			heading += turn * 0.5
			at += Vector2(-sin(heading), -cos(heading)) * (length / steps) * flat
			heading += turn * 0.5
			s += length / steps
			c.add_point(Vector3(at.x, -GRADE * s, at.y))
	return c
