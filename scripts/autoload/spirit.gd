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

# ---------------------------------------------------------------- personalities
#
# Each island has its own Guiding Spirit with a personality and lines
# (database/spirits.json). The spirits speak through text only.

const SPIRITS_PATH := "res://database/spirits.json"

var personas := {}          # region -> persona dictionary


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(SPIRITS_PATH))
	if data is Dictionary:
		personas = data.get("spirits", {})


## The spirit of [param region] ("luzon", "visayas", "mindanao").
func persona(region: String) -> Dictionary:
	return personas.get(region if personas.has(region) else "luzon", {})


func spirit_name(region: String) -> String:
	return persona(region).get("name", UI.GUIDES.get(region, "Spirit"))


## Region of a language, so its own island's spirit helps with it.
func region_of(lang_code: String) -> String:
	return DB.get_language(lang_code).get("region_code", "luzon")


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
