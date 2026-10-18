class_name SpiritBrain
extends RefCounted
## What a Guiding Spirit answers when the player talks to it. Works offline:
## it understands what is being asked (in English or Filipino) and answers
## from the game's own knowledge: the dictionary and sentences, the
## pronunciation helper, the grammar checker, the culture items and the
## player's progress and rewards. Each spirit answers in its own style.
##
## ask() returns {"text": String, "say": Array of [lang, text] to speak,
## "intent": String, "suggest": Array of follow-up questions}.

const OPENERS := {
	"luzon": ["Ah, apo. ", "Listen well, child. ", ""],
	"visayas": ["Ooh! ", "Easy one! ", "Wave hello to this: "],
	"mindanao": ["", "Gently now. ", "Here is the thread: "],
}
const OPENERS_FIL := {
	"luzon": ["Ah, apo. ", "Makinig ka, apo. ", ""],
	"visayas": ["Uy! ", "Madali lang 'yan! ", ""],
	"mindanao": ["", "Dahan-dahan. ", ""],
}

## Phrases that start a question, longest first. The rest is what is asked about.
const ASK_SAY := ["how do you say", "how do i say", "how to say", "paano sabihin ang", "paano sabihin", "paano mo sasabihin",
	"what is the word for", "word for", "translate"]
const ASK_MEAN := ["what does", "ano ang ibig sabihin ng", "ano ang kahulugan ng", "meaning of", "what is the meaning of", "ibig sabihin ng"]
const ASK_PRON := ["how do i pronounce", "how do you pronounce", "how to pronounce", "pronounce", "paano bigkasin ang",
	"paano bigkasin", "bigkas ng", "bigkasin", "say"]
const ASK_CHECK := ["is this correct", "is this right", "tama ba ang", "tama ba", "check my sentence", "check"]
const ASK_ABOUT := ["tell me about", "what is", "who is", "ano ang", "ikuwento mo ang", "sino si"]


static func _opener(region: String) -> String:
	var table: Dictionary = OPENERS_FIL if UI.lang == "fil" else OPENERS
	return table.get(region, [""]).pick_random()


static func _strip(text: String) -> String:
	var t := text.strip_edges()
	for ch in ["?", ".", "!"]:
		t = t.trim_suffix(ch)
	t = t.strip_edges()
	for q in ["\"", "'", "“", "”"]:
		t = t.trim_prefix(q).trim_suffix(q)
	return t.strip_edges()


## If [param q] starts with one of [param prefixes], returns the rest.
static func _after(q: String, prefixes: Array) -> String:
	for p in prefixes:
		if q.begins_with(p + " "):
			return _strip(q.substr(p.length()))
	return ""


## A language named in the question ("... in Cebuano"), removed from it.
static func _named_language(q: String) -> Array:
	for l in DB.get_playable_languages():
		for form in [" in " + l.name.to_lower(), " sa " + l.name.to_lower(), " " + l.name.to_lower()]:
			if q.ends_with(form):
				return [l.code, _strip(q.substr(0, q.length() - form.length()))]
	return ["", q]


static func ask(question: String, lang_code: String) -> Dictionary:
	var region := Spirit.region_of(lang_code)
	var lang_name: String = DB.get_language(lang_code).get("name", "")
	var raw := question.strip_edges()
	var q := _strip(" ".join(raw.to_lower().replace(":", " ").replace(",", " ").split(" ", false)))
	var named := _named_language(q)
	if named[0] != "":
		lang_code = named[0]
		lang_name = DB.get_language(lang_code).name
		q = named[1]
	var name := Spirit.spirit_name(region)

	if q == "" or q in ["hi", "hello", "hey", "kumusta", "kamusta", "mabuhay", "maayong adlaw", "magandang araw", "good morning"]:
		return _reply("greet", Spirit.line(region, "greet"), [[_own(), Spirit.line(region, "greet")]], region, lang_name)
	if q in ["who are you", "sino ka", "what are you", "about you", "introduce yourself"]:
		var about := Spirit.line(region, "about")
		return _reply("about", about, [[_own(), about]], region, lang_name)

	var x := _after(q, ASK_CHECK)
	if x != "" or q.ends_with(" correct") or q.ends_with(" tama"):
		if x == "":
			x = _strip(q.trim_suffix(" correct").trim_suffix(" is").trim_suffix(" tama"))
		return _check(x, lang_code, lang_name, region)
	x = _after(q, ASK_PRON)
	if x != "":
		return _pronounce(x, lang_code, region)
	x = _after(q, ASK_SAY)
	if x != "":
		return await _translate(x, lang_code, lang_name, region, "from_english")
	x = _after(q, ASK_MEAN)
	if x != "":
		x = _strip(x.trim_suffix(" mean").trim_suffix(" means"))
		return await _translate(x, lang_code, lang_name, region, "to_english")
	if q.ends_with(" meaning") or q.ends_with(" mean"):
		return await _translate(_strip(q.trim_suffix(" meaning").trim_suffix(" mean")), lang_code, lang_name, region, "to_english")

	for key in ["grammar", "tip", "tips", "payo"]:
		if key in q.split(" "):
			return _grammar_tip(lang_code, lang_name, region)
	for key in ["next", "help", "start", "tulong", "gagawin", "what should i do", "where do i start"]:
		if key in q:
			return _advice(lang_code, lang_name, region)
	for key in ["fragment", "crystal", "relic", "reward", "gantimpala"]:
		if key in q:
			return _rewards(region, lang_name)
	for key in ["pearl", "perlas", "core", "progress"]:
		if key in q:
			return _pearls(region, lang_name)

	var about_x := _after(q, ASK_ABOUT)
	var culture := _culture(about_x if about_x != "" else q, lang_code, region)
	if not culture.is_empty():
		return culture
	for key in ["culture", "kultura", "festival", "food", "pagkain", "dance", "sayaw"]:
		if key in q:
			return _culture_of(lang_code, lang_name, region, key)

	# A word or phrase on its own ("salamat", "what is tubig"): try both directions.
	var word := about_x if about_x != "" else q
	var r: Dictionary = await Spirit.translate(lang_code, word, "to_english")
	if r.source == "dictionary":
		return _translated(word, r.text, lang_code, lang_name, region, "to_english")
	r = await Spirit.translate(lang_code, word, "from_english")
	if r.source == "dictionary":
		return _translated(word, r.text, lang_code, lang_name, region, "from_english")
	var unknown := Spirit.line(region, "unknown")
	return _reply("unknown", unknown, [[_own(), unknown]], region, lang_name)


static func _own() -> String:
	return "fil" if UI.lang == "fil" else "en"


static func _reply(intent: String, text: String, say: Array, region: String, lang_name: String, suggest: Array = []) -> Dictionary:
	if suggest.is_empty():
		suggest = suggestions(lang_name)
	return {"intent": intent, "text": text, "say": say, "suggest": suggest, "region": region}


## Questions the player can tap.
static func suggestions(lang_name: String) -> Array:
	return ["How do I say thank you?", "What does kumusta mean?", "Pronounce salamat",
		"Is this correct: gusto ko tubig", "Tell me about Sinulog", "What should I do next?",
		"Give me a grammar tip", "Who are you?"]


static func _translate(text: String, lang_code: String, lang_name: String, region: String, direction: String) -> Dictionary:
	var r: Dictionary = await Spirit.translate(lang_code, text, direction)
	if r.text == "":
		var unknown := Spirit.line(region, "unknown")
		return _reply("unknown", "%s (\"%s\")" % [unknown, text], [[_own(), unknown]], region, lang_name)
	return _translated(text, r.text, lang_code, lang_name, region, direction, Spirit.source_label(r.source) if r.source != "dictionary" else "")


static func _translated(asked: String, answer: String, lang_code: String, lang_name: String, region: String,
		direction: String, note := "") -> Dictionary:
	var native := answer if direction == "from_english" else asked
	var english := asked if direction == "from_english" else answer
	native = native.split(" / ")[0]
	var text := ""
	if direction == "from_english":
		text = "%s\"%s\" in %s is \"%s\". Say it like this: %s" % [_opener(region), english, lang_name, native, Pronounce.phrase_guide(native)]
	else:
		text = "%s\"%s\" means \"%s\" in %s. Say it like this: %s" % [_opener(region), native, english, lang_name, Pronounce.phrase_guide(native)]
	if note != "":
		text += "\n(" + note + ")"
	return _reply("translate", text, [[lang_code, native]], region, lang_name,
		["Pronounce " + native, "How do I say water?", "What should I do next?"])


static func _pronounce(text: String, lang_code: String, region: String) -> Dictionary:
	var lang_name: String = DB.get_language(lang_code).get("name", "")
	var intro := Spirit.line(region, "pronounce")
	var tips := Pronounce.tips(text, lang_code)
	var body := "%s %s\n%s\n%s" % [intro, text, Pronounce.phrase_guide(text), "\n".join(tips.slice(0, 2).map(func(t): return "• " + t))]
	return _reply("pronounce", body, [[_own(), intro], [lang_code, text]], region, lang_name,
		["What does %s mean?" % text, "Give me a grammar tip"])


static func _check(sentence: String, lang_code: String, lang_name: String, region: String) -> Dictionary:
	var r := GrammarChecker.check_free(sentence, DB.get_sentences(lang_code), DB.get_tips(lang_code))
	var good := Spirit.line(region, "correct")
	if r.ok:
		return _reply("check", "%s \"%s\" means \"%s\"." % [good, r.match.native, r.match.english],
			[[_own(), good], [lang_code, r.match.native]], region, lang_name)
	if not r.get("known", false):
		return _reply("check", "%sI don't know that %s sentence yet, so I can't check it. Try one from the lessons." % [_opener(region), lang_name],
			[], region, lang_name)
	if r.score < 0.6:
		# Only loosely like a sentence I know: it may be fine, so don't call it wrong.
		return _reply("check", "%sI'm not sure about that one: it is not a sentence I know. The closest one I know is \"%s\" (\"%s\")." % [
			_opener(region), r.match.native, r.match.english], [[lang_code, r.match.native]], region, lang_name)
	var lines: Array = []
	for i in r.issues + r.notes:
		lines.append("• " + i)
	var soft := Spirit.line(region, "wrong")
	return _reply("check", "%s\n%s\nThe right way: %s (\"%s\")" % [soft, "\n".join(lines), r.match.native, r.match.english],
		[[_own(), soft], [lang_code, r.match.native]], region, lang_name)


static func _grammar_tip(lang_code: String, lang_name: String, region: String) -> Dictionary:
	var tips := DB.get_tips(lang_code)
	if tips.is_empty():
		return _reply("tip", "%sI have no %s grammar tips yet." % [_opener(region), lang_name], [], region, lang_name)
	var tip: String = tips.pick_random().tip
	return _reply("tip", "%s%s grammar tip: %s" % [_opener(region), lang_name, tip], [], region, lang_name,
		["Give me another grammar tip", "Is this correct: gusto ko tubig"])


static func _advice(lang_code: String, lang_name: String, region: String) -> Dictionary:
	var uid := Game.user_id()
	var text := _opener(region)
	if not DB.is_language_unlocked(uid, lang_code):
		text += "%s is still locked. Earn %s on Easy quizzes of a free language, then unlock it." % [lang_name, DB.cost_text(DB.LANGUAGE_COST)]
	else:
		var p := DB.get_progress(uid, lang_code)
		var next_level := 0
		for d in [DB.EASY, DB.MEDIUM, DB.HARD]:
			if not p[d].completed:
				next_level = d
				break
		if next_level != 0:
			text += "Your next step in %s: the %s level. Read its lesson first, then take the quiz." % [lang_name, Game.difficulty_name(next_level)]
		else:
			var pearl := DB.get_pearl_progress(uid, region)
			text += "You have mastered %s! Master the other languages of %s to light its pearl (%d/%d)." % [
				lang_name, DB.get_region(region).get("name", ""), pearl.mastered, pearl.total]
	var have := DB.get_rewards(uid)
	if have.word_fragment >= DB.LANGUAGE_COST.word_fragment:
		text += " You also have enough Word Fragments to unlock a new language!"
	return _reply("advice", text, [], region, lang_name)


static func _rewards(region: String, lang_name: String) -> Dictionary:
	var have := DB.get_rewards(Game.user_id())
	var text := "%sYou have %d Word Fragments, %d Phrase Crystals and %d Cultural Relics. Fragments unlock languages (%d), crystals unlock culture (%d), and a relic buys an extra hint." % [
		_opener(region), have.word_fragment, have.phrase_crystal, have.cultural_relic,
		DB.LANGUAGE_COST.word_fragment, DB.CULTURE_COST.phrase_crystal]
	return _reply("rewards", text, [], region, lang_name)


static func _pearls(region: String, lang_name: String) -> Dictionary:
	var uid := Game.user_id()
	var parts: Array = []
	for r in DB.get_regions():
		var p := DB.get_pearl_progress(uid, r.code)
		parts.append("%s %d/%d" % [r.core_name, p.mastered, p.total])
	return _reply("pearls", "%sAn island's pearl lights up when you master all of its languages. %s." % [_opener(region), ", ".join(parts)],
		[], region, lang_name)


## A culture item named in the question.
static func _culture(q: String, lang_code: String, region: String) -> Dictionary:
	if q.length() < 3:
		return {}
	for c in DB.get_culture_items():
		var title := str(c.title).to_lower()
		if q == title or (q.length() >= 4 and (title.begins_with(q) or q in title)):
			var unlocked := DB.is_culture_unlocked(Game.user_id(), c.title)
			var text := "%s%s (%s): %s" % [_opener(region), c.title, str(c.kind).to_lower(), c.description]
			if not unlocked:
				text += " It is still locked in your Gallery: clear a new level to reveal it, or unlock it with %s." % DB.cost_text(DB.CULTURE_COST)
			return _reply("culture", text, [], region, DB.get_language(lang_code).get("name", ""))
	return {}


static func _culture_of(lang_code: String, lang_name: String, region: String, key: String) -> Dictionary:
	var items := DB.get_culture_items(region)
	var own := items.filter(func(c): return c.language_code == lang_code)
	var pool := own if not own.is_empty() else items
	if key in ["festival", "food", "pagkain", "dance", "sayaw"]:
		var kind: String = {"pagkain": "food", "sayaw": "dance"}.get(key, key)
		var match := items.filter(func(c): return str(c.kind).to_lower() == kind)
		if not match.is_empty():
			pool = match
	var c: Dictionary = pool.pick_random()
	return _reply("culture", "%s%s (%s): %s" % [_opener(region), c.title, str(c.kind).to_lower(), c.description],
		[], region, lang_name, ["Tell me about another festival", "What should I do next?"])
