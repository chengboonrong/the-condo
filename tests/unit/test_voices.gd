extends TestCase
## Every spoken line has its voice: a quoted line anywhere in scripts/ (a line, a choice, a call) is in Voices.LINES,
## so a changed line fails here until its voice is made again; and every voice file is one of those lines'.

const NOT_SPOKEN := ["A stack of folded notes"]  # the notes under the door: read, not heard


func test_every_quoted_line_has_a_voice() -> bool:
	var quoted := RegEx.create_from_string("\"((?:[^\"\\\\\\n]|\\\\.)*\\\\\"(?:[^\"\\\\\\n]|\\\\.)*)\"")
	var letters := RegEx.create_from_string("[A-Za-z]{2}")
	var found := 0
	for path: String in _scripts("res://scripts"):
		for m: RegExMatch in quoted.search_all(FileAccess.get_file_as_string(path)):
			var text := m.get_string(1).c_unescape()
			if letters.search(text) == null or NOT_SPOKEN.any(func(s: String) -> bool: return text.begins_with(s)):
				continue
			found += 1
			check(Voices.LINES.has(text), "%s: no voice for %s" % [path.get_file(), text])
	check(found >= Voices.LINES.size(), "%d quoted lines found, Voices has %d" % [found, Voices.LINES.size()])
	return true


func test_every_voice_is_a_file_and_every_file_a_voice() -> bool:
	var ids: Array = Voices.LINES.values()
	for id: StringName in ids:
		check(Voices.stream(Voices.LINES.find_key(id)) is AudioStreamMP3, "%s.mp3 loads" % id)
	for file in DirAccess.get_files_at("res://assets/voice"):
		if file.ends_with(".mp3"):
			check(ids.has(StringName(file.get_basename())), "%s is no line's voice" % file)
	eq(Voices.stream("[The line goes dead.]"), null, "a sound caption has no voice")
	return true


func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out
