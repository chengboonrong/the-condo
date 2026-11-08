class_name Voices
extends RefCounted
## Every spoken line's voice, keyed by the text exactly as the game shows it (a line or a choice). Each id is a file,
## assets/voice/<id>.mp3: mesolitica/Malaysian-Podcast-Dia-1.6B's own voices (no real person's), made outside this
## repository; see README, "Licence". Changing a line's text drops its voice until it is made again (tests/unit/test_voices.gd).
## The id's prefix is the voice: rosnah_; you_ (him: his choices and the 12-07 call); hafiz_, mimic_ (the voice
## outside), call_hafiz_; mei_, call_mei_; din_ (Bang Din, remembered). rosnah_, you_call_ and call_ come through the
## intercom.

const LINES := {
	"\"Hello? Sorry ah, so late.\"": &"rosnah_hello",
	"\"This is Rosnah. Downstairs, 11-07.\"": &"rosnah_this_is",
	"\"Every night also the same. Knock, knock, knock. From your bedroom.\"": &"rosnah_every_night",
	"\"Please. Can you stop the knocking?\"": &"rosnah_please",
	"\"Hello? Sorry, so late. I just finished my shift at the mamak.\"": &"you_call_hello",
	"\"This is upstairs. 12-07.\"": &"you_call_upstairs",
	"\"Can you please stop the knocking?\"": &"you_call_please",
	"\"Eh, you going down ah? Jom, we got space.\"": &"call_mei_jom",
	"\"Wah, so late still working ah? Kesian, bro.\"": &"call_hafiz_kesian",
	"Hafiz: \"Bro, your friend all wet. Kena rain ah?\"": &"hafiz_wet",
	"Hafiz: \"Four people in this small car, also nobody talk.\"": &"hafiz_four_people",
	"Hafiz: \"Wah, so late still working ah? Kesian, bro.\"": &"hafiz_kesian",
	"Hafiz: \"Eh! Found this uncle, he's going down. Jom.\"": &"hafiz_uncle",
	"Hafiz: \"Mei? Bro?\"": &"hafiz_mei_bro",
	"Hafiz: \"Okay, hold tight! Potong!\"": &"hafiz_potong",
	"Hafiz: \"Aiyo, why so slow one? Can potong or not, bro?\"": &"hafiz_nag1",
	"Hafiz: \"Alamak, still crawling lah. Boleh potong now?\"": &"hafiz_nag2",
	"Hafiz: \"Weh, enough already! I potong now, okay?\"": &"hafiz_nag3",
	"Hafiz: \"Okay lah, okay lah. Follow only.\"": &"hafiz_give1",
	"Hafiz: \"Aiyo… fine. Slow slow also reach.\"": &"hafiz_give2",
	"Hafiz: \"Fine, fine! But my petrol also not free, you know.\"": &"hafiz_give3",
	"Hafiz: \"Alamak, dead already. Lights also gone, how can?\"": &"hafiz_dead",
	"Hafiz: \"No signal here. I jalan down a bit, find help. You two stay in the car, okay?\"": &"hafiz_no_signal",
	"[Behind you, Hafiz's voice: \"Mei! Wait for me!\"]": &"mimic_wait",
	"[Outside, in Hafiz's voice: \"Bro! Open the door, I found help!\"]": &"mimic_open_door",
	"\"Bro! Open the door, I found help!\"": &"mimic_open_door",  # B-11-07's call after saved (StoryDirector)
	"Mei: \"Eh, your friend so quiet one. Shy ah?\"": &"mei_shy",
	"Mei: \"Eh, how many of us ah? I want to buy drinks at the R&R.\"": &"mei_how_many",
	"Mei: \"Just answer lah. How many?\"": &"mei_answer",
	"Mei: \"Three? Then who's sitting—\"": &"mei_three",
	"Mei: \"Four meh? Wait, I count. One, two...\"": &"mei_counting",
	"Mei: \"Eh, you going down ah? Jom, we got space.\"": &"mei_jom",
	"Mei: \"We were at the theme park the whole day. So tired already.\"": &"mei_theme_park",
	"Mei: \"That's his phone…\"": &"mei_phone",
	"Mei: \"Eh… isn't that the same car?\"": &"mei_same_car",
	"Mei: \"That's him! I'm opening—\"": &"mei_opening",
	"Mei: \"Eh, look. Got a light down there.\"": &"mei_light",
	"[Bang Din: \"If they say there's one more in the car, don't turn to look. And don't count her.\"]": &"din_count",
	"[Bang Din: \"When it goes quiet, walk to the light. Whatever is behind you, don't look back.\"]": &"din_light",
	"[Bang Din: \"A slow car with nobody driving, you follow it. However long. Never potong.\"]": &"din_slow_car",
	"[Bang Din: \"If the car dies, stay inside. Don't open the door. Don't answer, even if it sounds like your own mother.\"]": &"din_car_dies",
	"\"Three.\"": &"you_three",
	"\"Four.\"": &"you_four",
	"\"Why you ask?\"": &"you_why",
	"\"Don't look. Hold my hand.\"": &"you_hold_hand",
	"\"Maybe it's him.\"": &"you_maybe_him",
	"\"Don't, bro. Just follow it.\"": &"you_dont_bro",
	"\"Eh… got nobody driving that car.\"": &"you_nobody_driving",
	"\"Ya lah, go.\"": &"you_ya_go",
	"\"Follow it lah. No rush.\"": &"you_follow_lah",
	"\"Bang Din says never potong a car like that.\"": &"you_bang_din_says",
	"\"Faster, go.\"": &"you_faster",
	"\"Bro, please. Stay behind it.\"": &"you_bro_please",
	"\"Look properly. Nobody at the wheel.\"": &"you_look_properly",
	"\"Okay, last time. Go.\"": &"you_last_time",
	"\"Hafiz? That you?\"": &"you_hafiz",
	"\"Mei, don't. That's not him.\"": &"you_mei_dont",
	"\"Okay, open.\"": &"you_okay_open",
}


static func stream(text: String) -> AudioStream:
	var id: StringName = LINES.get(text, &"")
	return null if id == &"" else load("res://assets/voice/%s.mp3" % id)
