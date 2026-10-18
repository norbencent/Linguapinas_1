extends Node
## The Guiding Spirit: offline translation helper (autoload "Spirit").
##
## Translation order:
##   1. Exact match in the SQLite dictionary (words and sentences).
##   2. MarianNMT through the optional local server in tools/marian_server
##      (runs on this computer, so no internet is needed once models are
##      downloaded).
##   3. Word-by-word gloss from the SQLite dictionary.

const SERVER_URL := "http://127.0.0.1:5005"
const HEALTH_TIMEOUT := 2.0
const TRANSLATE_TIMEOUT := 60.0

## Languages that reuse another language's MarianNMT model.
const MODEL_ALIASES := {"bis": "ceb"}

var server_pairs: Array = []   # e.g. ["en-tl", "tl-en"] reported by the server
var server_checked := false

# ---------------------------------------------------------------- personalities and voice
#
# Each island has its own Guiding Spirit with a personality, lines and a
# voice (database/spirits.json). Their words are recorded clips in
# assets/voice/ (tools/voice/make_spirit_voices.py); text without a clip is
# read by the device's text-to-speech voice, tuned to the spirit.

const SPIRITS_PATH := "res://database/spirits.json"
const VOICE_MANIFEST := "res://assets/voice/manifest.json"

var personas := {}          # region -> persona dictionary
var clips := {}             # "region|lang|normalized text" -> clip path
var voice: AudioStreamPlayer
var _queue: Array = []      # streams waiting to be played
var last_said: Array = []   # [region, lang, text] of everything asked to be said (for tests)


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(SPIRITS_PATH))
	if data is Dictionary:
		personas = data.get("spirits", {})
	if FileAccess.file_exists(VOICE_MANIFEST):
		var m = JSON.parse_string(FileAccess.get_file_as_string(VOICE_MANIFEST))
		if m is Dictionary:
			clips = m
	voice = AudioStreamPlayer.new()
	voice.name = "SpiritVoice"
	add_child(voice)
	voice.finished.connect(_play_next)


## The spirit of [param region] ("luzon", "visayas", "mindanao").
func persona(region: String) -> Dictionary:
	return personas.get(region if personas.has(region) else "luzon", {})


func spirit_name(region: String) -> String:
	return persona(region).get("name", UI.GUIDES.get(region, "Spirit"))


## Region of a language, so its own island's spirit helps with it.
func region_of(lang_code: String) -> String:
	return DB.get_language(lang_code).get("region_code", "luzon")


func voice_on() -> bool:
	return DB.get_setting("spirit_voice", "1") == "1"


## One of the spirit's lines for [param kind] (greet, correct, wrong, hint,
## pass, fail, pronounce, unknown, thinking, about) in the player's language.
func line(region: String, kind: String) -> String:
	var p := persona(region)
	var pair: Array
	if kind == "about":
		pair = p.get("about", ["", ""])
	else:
		var options: Array = p.get("lines", {}).get(kind, [])
		if options.is_empty():
			return ""
		pair = options.pick_random()
	return pair[0] if UI.lang == "fil" else pair[1]


## Says one of the spirit's lines and returns its text.
func speak_line(region: String, kind: String) -> String:
	var text := line(region, kind)
	say(region, text, "fil" if UI.lang == "fil" else "en")
	return text


## Says [param text] in the spirit's voice. [param lang] is a language code
## for words of a language, or "fil" / "en" for the spirit's own lines.
## Several calls in a row are played one after another.
func say(region: String, text: String, lang: String, interrupt := false) -> bool:
	last_said.append([region, lang, text])
	if text.strip_edges() == "" or not voice_on():
		return false
	if interrupt:
		stop()
	var path := clip_path(region, lang, text)
	if path != "":
		_queue.append(load(path))
		if not voice.playing:
			_play_next()
		return true
	return _device_say(region, text)


## The recorded clip for a text, or "".
func clip_path(region: String, lang: String, text: String) -> String:
	var path: String = clips.get("%s|%s|%s" % [region, lang, Game.normalize_answer(text)], "")
	return path if path != "" and ResourceLoader.exists(path) else ""


## Says a word or sentence of a language with its island spirit's voice.
func say_word(lang_code: String, text: String) -> bool:
	return say(region_of(lang_code), text, lang_code)


func stop() -> void:
	_queue.clear()
	voice.stop()
	if DisplayServer.get_name() != "headless":
		DisplayServer.tts_stop()


func _play_next() -> void:
	if _queue.is_empty():
		return
	voice.stream = _queue.pop_front()
	voice.volume_db = linear_to_db(maxf(Sound.sfx_volume / 100.0, 0.0001)) + 2.0
	voice.play()


func _device_say(region: String, text: String) -> bool:
	if not Pronounce.can_speak():
		return false
	var v: Dictionary = persona(region).get("voice", {})
	DisplayServer.tts_speak(text, Pronounce._voice(), clampi(int(Sound.sfx_volume), 10, 100),
		float(v.get("device_pitch", 1.0)), float(v.get("device_rate", 1.0)))
	return true


func marian_code(lang_code: String) -> String:
	return MODEL_ALIASES.get(lang_code, lang_code)


func _http(method: int, path: String, body: Dictionary, timeout: float) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = timeout
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var payload := "" if body.is_empty() else JSON.stringify(body)
	if http.request(SERVER_URL + path, headers, method, payload) != OK:
		http.queue_free()
		return {}
	var res: Array = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		return {}
	var data = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return data if typeof(data) == TYPE_DICTIONARY else {}


## Asks the MarianNMT server which language pairs it can translate.
func check_server() -> bool:
	var data: Dictionary = await _http(HTTPClient.METHOD_GET, "/health", {}, HEALTH_TIMEOUT)
	server_pairs = data.get("pairs", [])
	server_checked = true
	return not server_pairs.is_empty()


func server_supports(src: String, tgt: String) -> bool:
	return "%s-%s" % [src, tgt] in server_pairs


## direction: "to_english" or "from_english".
## Returns {"text": String, "source": String, "matches": Array}.
func translate(lang_code: String, text: String, direction: String) -> Dictionary:
	text = text.strip_edges()
	if text == "":
		return {"text": "", "source": "none", "matches": []}

	var matches := DB.dictionary_lookup(lang_code, text, direction)
	var key := "english" if direction == "to_english" else "native"
	for m in matches:
		var column := "native" if direction == "to_english" else "english"
		if Game.normalize_answer(m[column]) == Game.normalize_answer(text):
			return {"text": m[key], "source": "dictionary", "matches": matches}

	if not server_checked:
		await check_server()
	var code := marian_code(lang_code)
	var src := code if direction == "to_english" else "en"
	var tgt := "en" if direction == "to_english" else code
	if server_supports(src, tgt):
		var data: Dictionary = await _http(HTTPClient.METHOD_POST, "/translate",
			{"text": text, "src": src, "tgt": tgt}, TRANSLATE_TIMEOUT)
		if data.has("translation"):
			return {"text": data.translation, "source": "marian", "matches": matches}

	var gloss := _gloss(lang_code, text, direction)
	if gloss != "":
		return {"text": gloss, "source": "gloss", "matches": matches}
	return {"text": "", "source": "none", "matches": matches}


## Word-by-word translation using the vocabulary table.
func _gloss(lang_code: String, text: String, direction: String) -> String:
	var from_key := "native" if direction == "to_english" else "english"
	var to_key := "english" if direction == "to_english" else "native"
	var lookup := {}
	for w in DB.get_words(lang_code):
		# "Sun / Day" -> both "sun" and "day" map to the word.
		for part in str(w[from_key]).split("/"):
			lookup[Game.normalize_answer(part)] = str(w[to_key]).split(" / ")[0]
	var out: Array = []
	var found := false
	for token in Game.normalize_answer(text).split(" ", false):
		if lookup.has(token):
			out.append(lookup[token])
			found = true
		else:
			out.append("[%s]" % token)
	return " ".join(out) if found else ""


func source_label(source: String) -> String:
	match source:
		"dictionary": return "From the LinguaPinas dictionary"
		"marian": return "Translated offline by MarianNMT"
		"gloss": return "Word-by-word guess ([brackets] = unknown words)"
	return "The Spirit does not know this yet."
