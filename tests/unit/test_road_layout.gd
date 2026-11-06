extends TestCase
## The road down the mountain as data: long enough, unbroken, drivable, and its places where the missions need them.


func test_the_road_is_long_enough() -> bool:
	check(RoadLayout.LENGTH >= 3000.0, "at least 3 km down (%.0f m)" % RoadLayout.LENGTH)
	near(RoadLayout.point(RoadLayout.LENGTH).distance_to(RoadLayout.point(RoadLayout.LENGTH - 1.0)), 1.0, 0.01, "the curve really goes on to LENGTH")
	return true


func test_the_road_is_continuous() -> bool:
	var worst := 0.0
	var s := -200.0
	while s < RoadLayout.LENGTH:
		worst = maxf(worst, RoadLayout.point(s).distance_to(RoadLayout.point(s + 1.0)))
		s += 1.0
	check(worst <= 1.05, "a metre along the road is never more than 1.05 m on the ground (worst %.3f)" % worst)
	return true


func test_bends_are_drivable() -> bool:
	check(RoadLayout.min_radius() >= 20.0, "no bend tighter than 20 m (%.0f)" % RoadLayout.min_radius())
	var switchbacks := RoadLayout.SEGMENTS.filter(func(seg: Array) -> bool:
		return seg[0] == "bend" and absf(seg[2]) >= 150.0 and seg[1] >= 22.0 and seg[1] <= 35.0).size()
	check(switchbacks >= 6, "at least six switchbacks of radius 22–35 m (%d)" % switchbacks)
	var s := -200.0
	while s + 10.0 <= RoadLayout.LENGTH:
		var drop := RoadLayout.point(s).y - RoadLayout.point(s + 10.0).y
		if drop < 0.0 or drop > 1.0:
			check(false, "s %.0f: the next 10 m drop %.2f m (downhill, at most 10 %%)" % [s, drop])
			break
		s += 10.0
	return true


func test_closest_s_round_trips() -> bool:
	var s := -200.0
	while s <= RoadLayout.LENGTH:
		for x: float in [-3.6, 0.0, 3.6]:
			var back := RoadLayout.closest_s(RoadLayout.point(s, x))
			if absf(back - s) >= 0.5:
				check(false, "point(%.0f, %.1f) comes back as s %.2f" % [s, x, back])
		s += 50.0
	return true


func test_places_are_in_order() -> bool:
	var exit_s := RoadLayout.closest_s(RoadLayout.EXIT)
	var stop_s := RoadLayout.closest_s(RoadLayout.BUS_STOP)
	near(stop_s, RoadLayout.BUS_STOP_S, 0.05, "the stop is at BUS_STOP_S")
	check(exit_s < stop_s and stop_s - exit_s >= 40.0 and stop_s - exit_s <= 60.0, "the staff exit is 40–60 m up the road from the stop (%.1f)" % (stop_s - exit_s))
	check(RoadLayout.EXIT.y > RoadLayout.BUS_STOP.y, "uphill of it")
	var centre := RoadLayout.point(RoadLayout.BUS_STOP_S)
	var left := RoadLayout.point(RoadLayout.BUS_STOP_S, 1.0) - centre
	var off := RoadLayout.BUS_STOP - centre
	check(off.dot(left) > RoadLayout.WIDTH / 2.0 and off.length() < RoadLayout.WIDTH / 2.0 + 2.5, "the stop is on the left verge (%.2f m out)" % off.length())
	var t := RoadLayout.TUNNEL
	check(200.0 <= t.x and t.x < t.y and t.y <= 1200.0, "the tunnel is near the top (%s)" % t)
	return true
