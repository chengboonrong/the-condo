extends Node
## Typed gameplay signals. Simulation code emits; presentation and story listen.

# Player and world
signal room_entered(room_id: StringName)
signal object_interacted(object_id: StringName)
signal sound_investigated(room_id: StringName)
signal door_changed(door_id: StringName, open: bool, source: StringName)
signal light_changed(room_id: StringName, on: bool)
signal variant_changed(area_id: StringName, variant: StringName)
signal entity_changed(room_id: StringName, state: StringName)

# Horror events
signal horror_event_started(event_id: StringName, room_id: StringName)
signal horror_event_finished(event_id: StringName, result: StringName)

# Presentation requests (no state change)
signal sound_requested(sound_id: StringName, position: Vector3, volume_db: float)
signal light_flicker_requested(room_id: StringName, duration: float)
signal silhouette_requested(anchor_id: StringName, duration: float)
signal silhouette_seen(anchor_id: StringName)
signal door_feet_requested(shown: bool)
signal subtitle_requested(text: String, duration: float)  # sound captions and lines that follow the captions setting
signal line_requested(text: String, duration: float)  # story lines, on the road and in the flat: always shown
signal inspect_requested(title: String, text: String)
signal peephole_requested(view: Camera3D)

# The road (RoadDirector emits, except choice_made, which the HUD or a bot sends)
signal choices_requested(choice_id: StringName, options: PackedStringArray)
signal choices_closed(choice_id: StringName)
signal choice_made(choice_id: StringName, index: int)
signal road_cue(cue: StringName)
signal road_line(speaker: StringName, seconds: float)  # who speaks, so the presentation can turn heads
signal road_ended(ending: StringName)

# Story
signal act_changed(act: int)
signal objective_changed(text: String)
signal clue_found(clue_id: StringName, count: int)
signal ending_reached(ending_id: StringName)
