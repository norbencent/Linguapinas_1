class_name Pronounce
extends RefCounted
## Pronunciation help used by the Guiding Spirit: syllables, the usual stress,
## sound tips for Philippine spelling, and reading words aloud with the
## device's text-to-speech voice.
##
## There are no native recordings yet, so the stress shown is the usual
## pattern (second-to-last syllable) unless the word has an accent mark, and
## the voice is whatever the device provides (an Indonesian, Malay or Spanish
## voice reads Philippine spelling better than an English one).

const VOWELS := "aeiouáéíóúàèìòùâêîôû"
const ACCENTED := "áéíóúàèìòùâêîôû"
## Consonant pairs that start a syllable together (mostly in Spanish loanwords).
const ONSET_CLUSTERS := ["bl", "br", "cl", "cr", "dr", "fl", "fr", "gl", "gr", "pl", "pr", "tr", "ts"]
## Voices to try, best first. Matched against the start of the voice language.
const VOICE_PREFERENCE := ["fil", "tl", "id", "ms", "es"]


## "salamat" -> ["sa", "la", "mat"]. "ng" counts as one consonant; a hyphen
## or apostrophe (a glottal stop) always ends a syllable.
static func syllables(word: String) -> Array:
	var out: Array = []
	var part := ""
	for ch in word.to_lower().strip_edges() + "-":
		if _is_letter(ch):
			part += ch
		elif part != "":
			out.append_array(_syllables_of(part))
			part = ""
	return out


static func _is_letter(ch: String) -> bool:
	return ch in VOWELS or ch == "ñ" or (ch >= "a" and ch <= "z")


static func _syllables_of(part: String) -> Array:
	var units: Array = []
	var i := 0
	while i < part.length():
		var two := part.substr(i, 2)
		units.append(two if two == "ng" else part[i])
		i += 2 if two == "ng" else 1
	var nuclei: Array = []
	for j in units.size():
		if units[j] in VOWELS:
			nuclei.append(j)
	if nuclei.size() <= 1:
		return [part]
	var cuts: Array = []  # unit index where each new syllable starts
	for k in range(1, nuclei.size()):
		var a: int = nuclei[k - 1] + 1
		var b: int = nuclei[k]
		match b - a:
			0:  # two vowels side by side: split between them
				cuts.append(b)
			1:  # one consonant goes with the next vowel
				cuts.append(a)
			_:
				var pair: String = units[b - 2] + units[b - 1]
				cuts.append(b - 2 if pair in ONSET_CLUSTERS else b - 1)
	var out: Array = []
	var start := 0
	for c in cuts + [units.size()]:
		out.append("".join(units.slice(start, c)))
		start = c
	return out


## Index of the stressed syllable: an accented vowel if there is one,
## otherwise the second-to-last syllable.
static func stress_index(sylls: Array) -> int:
	for k in sylls.size():
		for ch in str(sylls[k]):
			if ch in ACCENTED:
				return k
	return maxi(0, sylls.size() - 2)


## "salamat" -> "sa·LA·mat"
static func guide(word: String) -> String:
	var sylls := syllables(word)
	var s := stress_index(sylls) if sylls.size() > 1 else -1
	var parts: Array = []
	for k in sylls.size():
		parts.append(str(sylls[k]).to_upper() if k == s else str(sylls[k]))
	return "·".join(parts)


## A whole phrase, word by word.
static func phrase_guide(text: String) -> String:
	var words: Array = []
	for w in _words(text):
		words.append(guide(w))
	return "  ".join(words)


## Sound tips for the spellings that appear in [param text].
static func tips(text: String, language_code := "") -> Array:
	var t := " %s " % text.to_lower()
	var out: Array = []
	if " ng " in t:
		out.append("The little word 'ng' is said 'nang'.")
	if " mga " in t:
		out.append("'mga' is said 'ma-NGA'.")
	if "ng" in t.replace(" ng ", " "):
		out.append("'ng' is one sound, like the 'ng' in 'singer', even at the start of a word (nga = 'nga').")
	if "ts" in t:
		out.append("'ts' sounds like the 'ch' in 'church'.")
	for v in ["aa", "ee", "ii", "oo", "uu"]:
		if v in t:
			out.append("A double vowel ('%s') has a small catch in the throat between the two vowels." % v)
			break
	if "-" in t or "'" in t:
		out.append("A hyphen or apostrophe marks a short stop in the throat (glottal stop).")
	if "r" in t:
		out.append("'r' is tapped lightly with the tongue, like the 'tt' in American 'butter'.")
	if language_code == "cbk":
		if "ll" in t:
			out.append("In Chavacano 'll' sounds like 'ly' or 'y'.")
		if "j" in t:
			out.append("In Chavacano 'j' sounds like an 'h'.")
		if "qu" in t:
			out.append("'qu' sounds like 'k'.")
		if "ce" in t or "ci" in t or "z" in t:
			out.append("'c' before e or i, and 'z', sound like 's'.")
	if "ñ" in t:
		out.append("'ñ' sounds like 'ny' in 'canyon'.")
	out.append("Vowels are short and clear: a as in 'father', e as in 'bed', i as in 'machine', o as in 'more', u as in 'flute'.")
	out.append("Stress (the CAPITAL syllable) usually falls on the second-to-last syllable, but some words differ. Listen to native speakers when you can.")
	return out


static func _words(text: String) -> Array:
	var cleaned := ""
	for ch in text:
		cleaned += ch if (_is_letter(ch.to_lower()) or ch in "-' ") else " "
	return cleaned.split(" ", false)


# ---------------------------------------------------------------- voice

static func can_speak() -> bool:
	return DisplayServer.get_name() != "headless" and not DisplayServer.tts_get_voices().is_empty()


static func _voice() -> String:
	var voices := DisplayServer.tts_get_voices()
	for want in VOICE_PREFERENCE:
		for v in voices:
			if str(v.get("language", "")).to_lower().begins_with(want):
				return v.id
	return voices[0].id if not voices.is_empty() else ""


## Reads [param text] aloud slowly. Returns false if the device has no voice.
static func speak(text: String) -> bool:
	if not can_speak():
		return false
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, _voice(), clampi(int(Sound.sfx_volume), 10, 100), 1.0, 0.8)
	return true


# ---------------------------------------------------------------- panel

## The Guiding Spirit's pronunciation pop-up for [param texts] (words or
## phrases), added on top of [param parent]. Closed by tapping CLOSE or the
## back key.
static func show_panel(parent: Control, texts: Array, language_code: String, region: String) -> Control:
	var overlay := ColorRect.new()
	overlay.name = "PronouncePanel"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)
	Game.overlays.append(overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40 if side in ["left", "right"] else 120)
	overlay.add_child(margin)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI._box(Color("f6efff"), 18, Color("8a63c2"), 6, 22))
	margin.add_child(card)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	var v := UI.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	var head := UI.hbox(10)
	head.add_child(UI.image(UI.tex["guide_" + (region if region in UI.GUIDES else "luzon")], Vector2(72, 72)))
	var name: String = UI.GUIDES.get(region, "Spirit")
	var hl := UI.label("%s: %s" % [name, Spirit.line(region, "pronounce")], 21, Color("5a3591"), true, UI.font_body_black)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	v.add_child(head)
	var voice_ok := can_speak()
	if texts.is_empty():
		v.add_child(UI.label("There are no %s words to say yet. Answer the question, then ask me again to hear the answer."
			% DB.get_language(language_code).get("name", ""), 18, UI.INK, true))
	for text in texts:
		var entry := UI.panel(Color("fffaf0"), Color("c9a76b"))
		var ev := UI.vbox(4)
		entry.add_child(ev)
		var row := UI.hbox(8)
		var word := UI.label(str(text), 24, UI.RED, true, UI.font_body_black)
		word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(word)
		# The island's spirit says it in its own recorded voice; the device
		# voice is the fallback for words without a recording.
		var listen := UI.pill_button("LISTEN", Color("6b3fa0"), func():
			if not Spirit.say(region, str(text), language_code, true):
				speak(str(text)), 46, 16)
		listen.name = "listen"
		listen.disabled = not (voice_ok or Spirit.clip_path(region, language_code, str(text)) != "")
		row.add_child(listen)
		ev.add_child(row)
		ev.add_child(UI.label(phrase_guide(str(text)), 22, Color("5a3591"), true, UI.font_body_black))
		v.add_child(entry)
	var all_text := " ".join(texts.map(func(x): return str(x)))
	for tip in tips(all_text, language_code):
		v.add_child(UI.label("• " + tip, 16, UI.INK, true))
	if texts.size() > 0:
		Spirit.say(region, Spirit.line(region, "pronounce"), "fil" if UI.lang == "fil" else "en", true)
	var close := UI.pill_button("CLOSE", UI.INK_SOFT, func():
		Game.overlays.erase(overlay)
		overlay.queue_free(), 52, 20)
	close.name = "close"
	v.add_child(close)
	return overlay
