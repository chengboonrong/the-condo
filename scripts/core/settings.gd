extends Node
## Player settings, saved to user://settings.cfg. The game itself is short enough to need no save slots.

signal changed

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"mouse_sensitivity": 0.0025,
	"invert_y": false,
	"brightness": 1.0,
	"reduced_flashing": false,
	"subtitles": true,
	"master_volume": 0.8,
}

var values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for key: String in DEFAULTS:
			values[key] = cfg.get_value("settings", key, DEFAULTS[key])
	_apply_volume()


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	values[key] = value
	_apply_volume()
	changed.emit()
	var cfg := ConfigFile.new()
	for k: String in values:
		cfg.set_value("settings", k, values[k])
	cfg.save(PATH)


func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(values["master_volume"]), 0.0001)))
