class_name RoadMission
extends RefCounted
## One of the road's missions: a chain of beats that the director ticks while it is the current mission.
##
## Hooks, called by RoadDirector:
##   begin()                when it becomes the current mission
##   tick(delta) -> bool    every step after that; true when it is done
##   set_up_skipped()       by start_at(): put the director in the state this mission starts in, as if every
##                          earlier mission was kept (seated or not, car_s, light_s and so on)
##   interacted(id)         he used something (EventBus.object_interacted), passed on only while this is the current
##                          mission. Missions never connect to EventBus themselves.
##   leave()                when it stops being the current mission, finished or skipped by start_at(): clear
##                          whatever presentation it put up (a card, prompts, its objective)

## The director that runs it. Held weakly: the director holds its missions, and a strong reference back would keep
## both, and their EventBus connections, alive for ever.
var d: RoadDirector:
	get:
		return _d.get_ref() as RoadDirector if _d != null else null
	set(value):
		_d = weakref(value)
var beat: StringName = &""
var beat_t := 0.0  # seconds in the current beat; the director adds each step's delta before tick()
var _d: WeakRef


func begin() -> void:
	pass


func tick(_delta: float) -> bool:
	return true


func set_up_skipped() -> void:
	pass


func interacted(_id: StringName) -> void:
	pass


func leave() -> void:
	pass


func go(next: StringName) -> void:
	beat = next
	beat_t = 0.0
	d.progress.append({"t": snappedf(WorldState.time, 0.1), "mission": d.mission_index, "beat": next})
