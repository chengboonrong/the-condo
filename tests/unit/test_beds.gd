extends TestCase
## The home sound beds' schedule: everything plays through act 1, then they stop one at a time.


func test_the_home_sounds_stop_one_at_a_time() -> bool:
	var b := AudioDirector.BEDS
	for id: StringName in b:
		check(not AudioDirector.bed_due(b[id], 1, 999.0), "%s plays all through act 1" % id)
	check(AudioDirector.bed_due(b[&"tv"], 2, 0.0), "the TV next door stops when the wall answers")
	check(not AudioDirector.bed_due(b[&"fridge"], 2, 74.0), "the fridge keeps going a while")
	check(AudioDirector.bed_due(b[&"fridge"], 2, 75.0), "then stops 75 s into act 2")
	check(AudioDirector.bed_due(b[&"fridge"], 3, 0.0), "or when act 3 begins")
	check(not AudioDirector.bed_due(b[&"fan"], 3, 14.0) and AudioDirector.bed_due(b[&"fan"], 3, 15.0), "the fan last, 15 s into act 3")
	return true
