extends Node
## Session state, navigation and quiz generation (autoload "Game").

const SCENES := {
	"title": "res://scenes/title.tscn",
	"menu": "res://scenes/start_menu.tscn",
	"new_game": "res://scenes/new_game.tscn",
	"continue": "res://scenes/continue_game.tscn",
	"settings": "res://scenes/settings.tscn",
	"map": "res://scenes/island_map.tscn",
	"island": "res://scenes/region_select.tscn",
	"language": "res://scenes/language_select.tscn",
	"difficulty": "res://scenes/difficulty_select.tscn",
	"lesson": "res://scenes/lesson.tscn",
	"quiz": "res://scenes/quiz.tscn",
	"results": "res://scenes/results.tscn",
	"leaderboard": "res://scenes/leaderboard.tscn",
	"gallery": "res://scenes/gallery.tscn",
	"stories": "res://scenes/stories.tscn",
	"spirit": "res://scenes/guiding_spirit.tscn",
	"profile": "res://scenes/profile.tscn",
	"guide": "res://scenes/guide.tscn",
}

const MAX_HEARTS := 5
const QUESTIONS_PER_QUIZ := 10
const HINTS_PER_QUIZ := 2
const POINTS_PER_CORRECT := 10
const POINTS_PER_HEART := 5

# Current session
var user: Dictionary = {}
var region_code := ""
var language_code := ""
var difficulty := 1
var category_code := ""          # "" means all categories
var last_result: Dictionary = {}  # filled by the quiz for the results screen
var settings_return := "title"   # where Settings' Exit button goes

## Screens that can be opened without a player.
const PUBLIC_SCREENS := ["title", "menu", "new_game", "continue", "settings"]
const PLAYTIME_SAVE_EVERY := 30.0
var _unsaved_playtime := 0.0

# ---------------------------------------------------------------- back navigation
#
# Every back button, the nav bar's BACK, Esc and the Android back key go
# through handle_back(). A screen's back target is registered by UI.top_bar()
# (or set_back() for screens with their own button). The special target
# BACK returns to the previous screen in the history, used by screens that
# can be opened from many places (gallery, profile, leaderboard, ...).

const BACK := "@back"
## Screens never returned to through the history (a quiz restarts if reopened).
const NO_RETURN := ["quiz", "settings"]
const MAX_HISTORY := 30

var current_screen := "title"
var history: Array[String] = []
var back_action: Variant = null          # String screen, BACK or Callable
var overlays: Array[Node] = []           # pop-ups closed first by the back key


func _process(delta: float) -> void:
	if not is_logged_in():
		return
	_unsaved_playtime += delta
	if _unsaved_playtime >= PLAYTIME_SAVE_EVERY:
		save_playtime()


func _ready() -> void:
	# The Android back key goes back a screen instead of closing the app.
	get_tree().quit_on_go_back = false
	_fit_window.call_deferred()


## On a PC, sizes the portrait window to the screen: as tall as fits above
## the taskbar, up to 800 px. The project's default window (315x560) is kept
## small so it also fits inside the editor's Game window on a 768 px laptop
## screen, where the game cannot resize its own window.
const MAX_WINDOW_HEIGHT := 800


func _fit_window() -> void:
	if OS.has_feature("mobile") or DisplayServer.get_name() == "headless":
		return
	if Engine.has_method("is_embedded_in_editor") and Engine.call("is_embedded_in_editor"):
		return  # the editor's Game window sizes itself
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	const TITLE_BAR := 40  # room for the window's title bar and border
	var h := mini(MAX_WINDOW_HEIGHT, usable.size.y - TITLE_BAR - 20)
	var w := int(h * 9.0 / 16.0)
	DisplayServer.window_set_size(Vector2i(w, h))
	DisplayServer.window_set_position(usable.position + Vector2i((usable.size.x - w) / 2, TITLE_BAR))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_playtime()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		handle_back()


func save_playtime() -> void:
	if is_logged_in() and _unsaved_playtime >= 1.0:
		DB.add_playtime(user_id(), int(_unsaved_playtime))
		_unsaved_playtime -= int(_unsaved_playtime)


func notifications_on() -> bool:
	return DB.get_setting("notifications", "1") == "1"


func save_settings(ui_language: String, music: int, sfx: int, notify: bool) -> void:
	DB.set_setting("ui_language", ui_language)
	DB.set_setting("music_volume", str(music))
	DB.set_setting("sfx_volume", str(sfx))
	DB.set_setting("notifications", "1" if notify else "0")
	UI.lang = ui_language
	Sound.apply(music, sfx)


func open_settings(from: String) -> void:
	settings_return = from
	goto("settings")


func is_logged_in() -> bool:
	return not user.is_empty()


func user_id() -> int:
	return int(user.get("id", 0))


func login(u: Dictionary) -> void:
	save_playtime()
	user = u
	_unsaved_playtime = 0.0
	history.clear()
	goto("map", false)


func logout() -> void:
	save_playtime()
	user = {}
	region_code = ""
	language_code = ""
	history.clear()
	goto("title", false)


## Opens a screen. remember=false skips the history (used when going back).
func goto(screen: String, remember := true) -> void:
	if not screen in PUBLIC_SCREENS and not is_logged_in():
		screen = "title"
	if screen == "title":
		history.clear()
	elif remember and screen != current_screen:
		history.append(current_screen)
		if history.size() > MAX_HISTORY:
			history.pop_front()
	current_screen = screen
	back_action = null
	overlays.clear()
	get_tree().change_scene_to_file(SCENES[screen])


## Registers where the current screen's back button goes.
func set_back(target: Variant) -> void:
	back_action = target


## Follows a back target: a screen name, BACK (history) or a Callable.
func go(target: Variant, fallback := "map") -> void:
	if target is Callable:
		target.call()
	elif target == BACK:
		go_back(fallback)
	elif target is String and target != "":
		goto(target, false)
	else:
		goto(fallback, false)


## Returns to the previous screen, skipping ones that can't be reopened.
func go_back(fallback := "map") -> void:
	while not history.is_empty():
		var prev: String = history.pop_back()
		if prev == current_screen or prev in NO_RETURN:
			continue
		if prev in PUBLIC_SCREENS or is_logged_in():
			goto(prev, false)
			return
	goto(fallback if is_logged_in() or fallback in PUBLIC_SCREENS else "title", false)


## Back key / Esc: close a pop-up, else press the screen's back button.
func handle_back() -> void:
	while not overlays.is_empty():
		var o: Node = overlays.pop_back()
		if is_instance_valid(o) and o.is_inside_tree():
			Sound.click()
			o.queue_free()
			return
	if back_action != null:
		Sound.click()
		go(back_action)
	elif current_screen == "title":
		get_tree().quit()
	else:
		Sound.click()
		go_back("title")


func refresh_user() -> void:
	if is_logged_in():
		save_playtime()
		user = DB.get_user(user_id())


func difficulty_name(d: int = -1) -> String:
	return UI.t(["easy", "medium", "hard"][(difficulty if d < 0 else d) - 1])


# ---------------------------------------------------------------- quizzes
#
# A question is a Dictionary:
#   type:     "choice" | "build" | "typed"
#   kind:     short label shown above the question
#   prompt:   main text
#   detail:   optional secondary text
#   options:  (choice) Array of answer strings
#   tokens:   (build) shuffled word tiles
#   answer:   the correct answer string
#   explain:  shown after answering

func build_quiz(lang_code: String, diff: int, category := "") -> Array:
	if category == GRAMMAR:
		return grammar_quiz(lang_code)
	var words := DB.get_words(lang_code)
	var sentences := DB.get_sentences(lang_code)
	var lang_name: String = DB.get_language(lang_code).get("name", "")
	var questions: Array = []
	match diff:
		DB.EASY:
			var pool := words if category == "" else DB.get_words(lang_code, category)
			pool = pool.duplicate()
			pool.shuffle()
			for i in pool.size():
				if i % 2 == 0:
					questions.append(_vocab_to_english(pool[i], words))
				else:
					questions.append(_vocab_from_english(pool[i], words, lang_name))
		DB.MEDIUM:
			var shuffled := sentences.duplicate()
			shuffled.shuffle()
			for i in shuffled.size():
				match i % 3:
					0: questions.append(_build_sentence(shuffled[i], sentences, lang_name, false))
					1: questions.append(_dialogue_choice(shuffled[i], sentences, lang_name))
					2: questions.append(_comprehension(shuffled[i], sentences))
			# Short sentence lists are topped up with vocabulary review.
			var extra := words.duplicate()
			extra.shuffle()
			for w in extra:
				if questions.size() >= QUESTIONS_PER_QUIZ:
					break
				questions.append(_vocab_from_english(w, words, lang_name))
		DB.HARD:
			var shuffled := sentences.duplicate()
			shuffled.shuffle()
			for i in shuffled.size():
				var s: Dictionary = shuffled[i]
				if i % 2 == 0 and s.context != "":
					questions.append(_context_choice(s, sentences, lang_name))
				else:
					questions.append(_build_sentence(s, sentences, lang_name, true))
			var extra := words.duplicate()
			extra.shuffle()
			for w in extra:
				if questions.size() >= QUESTIONS_PER_QUIZ:
					break
				questions.append(_typed_word(w, lang_name))
	questions.shuffle()
	# Full quizzes also ask about the language's and region's culture.
	var culture: Array = [] if category != "" else _culture_questions(lang_code, CULTURE_QUESTIONS.get(diff, 1))
	questions = questions.slice(0, QUESTIONS_PER_QUIZ - culture.size())
	questions.append_array(culture)
	questions.shuffle()
	return questions


# ---------------------------------------------------------------- grammar quiz

## Game.category_code for the grammar quiz (played at Medium, rewards Phrase Crystals).
const GRAMMAR := "grammar"
## Case markers of each playable language. A marker from another language,
## or a missing marker, is always wrong, which makes safe wrong options.
const LANGUAGE_MARKERS := {
	"tl": ["ang", "ng", "sa", "si", "ni", "kay", "mga"],
	"ceb": ["ang", "sa", "og", "ug", "si", "ni", "kang", "mga"],
	"bis": ["ang", "sa", "og", "ug", "si", "ni", "kang", "mga"],
	"hil": ["ang", "sang", "sa", "si", "ni", "kay", "mga"],
	"war": ["an", "han", "ha", "hin", "si", "ni", "mga"],
	"ilo": ["ti", "iti", "dagiti", "ni", "ken"],
	"bcl": ["an", "kan", "nin", "sa", "si", "ni", "ki", "mga"],
	"pam": ["ing", "ning", "king", "ni", "kang"],
	"tsg": ["in", "sin", "ha", "hi"],
	"cbk": ["el", "maga", "con"],
}
## Object / possessive markers. Leaving one out breaks the sentence, while a
## missing topic marker ("Ano pangalan mo?") is often fine in casual speech,
## so only these are dropped to make wrong options.
const DROPPABLE_MARKERS := ["ng", "og", "ug", "sang", "hin", "nin", "ning", "sin", "ti", "iti", "kan"]
## Personal pronouns. Swapping one for another changes who is meant, so the
## sentence no longer matches its English meaning.
const PRONOUNS := ["ako", "ko", "ka", "mo", "ikaw", "kami", "imong", "akong", "nimo", "nako", "aku", "ku", "mu",
	"kaw", "tu", "yo", "ta"]


## Markers and pronouns that appear in the language's sentences.
func grammar_words(lang_code: String) -> Array:
	var markers: Array = LANGUAGE_MARKERS.get(lang_code, [])
	var out: Array = []
	for s in DB.get_sentences(lang_code):
		for w in GrammarChecker.words(s.native):
			if (w in markers or w in PRONOUNS) and not w in out:
				out.append(w)
	return out


## Pronouns that are certainly not this language's: Spanish-based Chavacano
## pronouns for the other languages, and Philippine-type pronouns for
## Chavacano. (Similar Philippine languages share many pronouns, so those are
## never used as wrong options for each other.)
func foreign_pronouns(lang_code: String) -> Array:
	var own := _lesson_words(lang_code)
	var pool: Array = ["ko", "mo", "ka", "ako"] if lang_code == "cbk" else ["tu", "yo"]
	return pool.filter(func(p): return not p in own)


func _lesson_words(lang_code: String) -> Array:
	var out: Array = []
	for w in DB.get_words(lang_code):
		out.append_array(GrammarChecker.words(w.native))
	for s in DB.get_sentences(lang_code):
		out.append_array(GrammarChecker.words(s.native))
	return out


## Markers of other languages that never appear in this language's lessons.
func foreign_markers(lang_code: String) -> Array:
	var own: Array = LANGUAGE_MARKERS.get(lang_code, []) + _lesson_words(lang_code)
	var out: Array = []
	for code in LANGUAGE_MARKERS:
		for m in LANGUAGE_MARKERS[code]:
			if not m in own and not m in out and not m in PRONOUNS:
				out.append(m)
	return out


## Ten grammar questions: pick the correct sentence, fill in the missing
## grammar word, and write a sentence that the grammar checker marks.
func grammar_quiz(lang_code: String) -> Array:
	var sentences := DB.get_sentences(lang_code)
	var lang_name: String = DB.get_language(lang_code).get("name", "")
	var gwords := grammar_words(lang_code)
	var choose: Array = []
	var fill: Array = []
	var write: Array = []
	for s in sentences:
		var q := _grammar_choose(s, gwords)
		if not q.is_empty():
			choose.append(q)
		q = _grammar_fill(s, gwords)
		if not q.is_empty():
			fill.append(q)
		write.append(_grammar_write(s, lang_name))
	for list in [choose, fill, write]:
		list.shuffle()
	# A mix: about four of each kind, at least two sentences to write.
	var out: Array = []
	var pools := [choose, fill, write]
	var turn := 0
	while out.size() < QUESTIONS_PER_QUIZ and pools.any(func(p): return not p.is_empty()):
		var pool: Array = pools[turn % 3]
		if not pool.is_empty():
			out.append(pool.pop_back())
		turn += 1
	out.shuffle()
	return out


func _grammar_explain(s: Dictionary) -> String:
	var text := "%s = %s" % [s.native, s.english]
	var tip := GrammarChecker._tip_for_sentence(s.native, DB.get_tips(s.language_code))
	return text + ("\nTip: " + tip if tip != "" else "")


## "Which sentence is correct?" with versions that are certainly wrong:
## the first two words swapped, a case marker left out or replaced by another
## language's marker, or a pronoun swapped (which changes the meaning).
func _grammar_choose(s: Dictionary, gwords: Array) -> Dictionary:
	var w: Array = GrammarChecker.words(s.native)
	if w.size() < 2:
		return {}
	var markers: Array = LANGUAGE_MARKERS.get(s.language_code, [])
	var foreign := foreign_markers(s.language_code)
	foreign.shuffle()
	var pronouns := gwords.filter(func(x): return x in PRONOUNS)
	var punct := "?" if s.native.strip_edges().ends_with("?") else "."
	var wrong: Array = []
	var add := func(arr: Array):
		var t := _sentence_case(" ".join(arr)) + punct
		if GrammarChecker.words(t) != w and not t in wrong:
			wrong.append(t)
	var swapped := w.duplicate()
	swapped[0] = w[1]
	swapped[1] = w[0]
	add.call(swapped)
	for i in w.size():
		if w[i] in markers:
			if w.size() >= 3 and w[i] in DROPPABLE_MARKERS:
				var dropped := w.duplicate()
				dropped.remove_at(i)
				add.call(dropped)
			if not foreign.is_empty():
				var replaced := w.duplicate()
				replaced[i] = foreign[0]
				add.call(replaced)
		elif w[i] in PRONOUNS:
			for other in pronouns:
				if other != w[i]:
					var replaced := w.duplicate()
					replaced[i] = other
					add.call(replaced)
					break
	if wrong.size() < 2:
		return {}
	wrong.shuffle()
	var correct := _sentence_case(" ".join(w)) + punct
	var options: Array = [correct]
	options.append_array(wrong.slice(0, 3))
	options.shuffle()
	return {
		"type": "choice", "kind": "Grammar",
		"prompt": "Which sentence is correct?", "detail": "Meaning: \"%s\"" % s.english,
		"options": options, "answer": correct, "explain": _grammar_explain(s),
	}


## "Choose the missing word": a case marker (wrong options are other
## languages' markers) or a pronoun (wrong options are other pronouns).
func _grammar_fill(s: Dictionary, gwords: Array) -> Dictionary:
	var w: Array = GrammarChecker.words(s.native)
	var markers: Array = LANGUAGE_MARKERS.get(s.language_code, [])
	var pronouns := gwords.filter(func(x): return x in PRONOUNS)
	var slots: Array = []
	for i in w.size():
		if w[i] in markers or (w[i] in PRONOUNS and pronouns.size() >= 2):
			slots.append(i)
	if slots.is_empty() or w.size() < 2:
		return {}
	var i: int = slots.pick_random()
	var options: Array
	if w[i] in markers:
		options = _pick_options(w[i], foreign_markers(s.language_code))
	else:
		# The language's other pronouns first, then pronouns it never uses.
		var own := pronouns.filter(func(x): return x != w[i])
		own.shuffle()
		var foreign := foreign_pronouns(s.language_code)
		foreign.shuffle()
		options = [w[i]]
		options.append_array((own + foreign).slice(0, 3))
		options.shuffle()
	var shown := w.duplicate()
	shown[i] = "_____"
	return {
		"type": "choice", "kind": "Grammar",
		"prompt": "Choose the missing word.",
		"detail": "%s\n(\"%s\")" % [_sentence_case(" ".join(shown)), s.english],
		"options": options, "answer": w[i], "explain": _grammar_explain(s),
	}


## "Write in Tagalog" checked by the grammar checker.
func _grammar_write(s: Dictionary, lang_name: String) -> Dictionary:
	return {
		"type": "grammar", "kind": "Grammar check",
		"prompt": "Write in %s: \"%s\"" % [lang_name, s.english], "detail": "",
		"answer": s.native, "explain": _grammar_explain(s),
	}


static func _sentence_case(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1) if text != "" else text


## Culture questions per level (taken from the 10 questions of a quiz).
const CULTURE_QUESTIONS := {1: 1, 2: 2, 3: 2}  # Easy, Medium, Hard


## Questions about culture items: the language's own items first, then the
## rest of its region's.
func _culture_questions(lang_code: String, count: int) -> Array:
	var region: String = DB.get_language(lang_code).get("region_code", "")
	var all := DB.get_culture_items()
	if all.size() < 4 or region == "":
		return []
	var own := all.filter(func(c): return c.get("language_code", "") == lang_code)
	var regional := all.filter(func(c): return c.region_code == region and c.get("language_code", "") != lang_code)
	own.shuffle()
	regional.shuffle()
	var picks := (own + regional).slice(0, count)
	var out: Array = []
	for i in picks.size():
		out.append(_culture_describe(picks[i], all) if i % 2 == 0 else _culture_region(picks[i], all))
	return out


## "Which festival is this?" with the item's description, its name hidden.
func _culture_describe(item: Dictionary, all: Array) -> Dictionary:
	var same_kind := all.filter(func(c): return c.kind == item.kind)
	var candidates := _column(same_kind, "title")
	if candidates.size() < 4:
		candidates.append_array(_column(all, "title"))
	return {
		"type": "choice", "kind": "Culture",
		"prompt": "Which %s is this?" % str(item.kind).to_lower(),
		"detail": hide_name(item.description, item.title),
		"options": _pick_options(item.title, candidates),
		"answer": item.title, "explain": "%s: %s" % [item.title, item.description],
	}


## "Which of these is found in Visayas?" with three items from other regions.
func _culture_region(item: Dictionary, all: Array) -> Dictionary:
	var region_name: String = DB.get_region(item.region_code).get("name", "")
	var others := all.filter(func(c): return c.region_code != item.region_code)
	return {
		"type": "choice", "kind": "Culture",
		"prompt": "Which of these is found in %s?" % region_name, "detail": "",
		"options": _pick_options(item.title, _column(others, "title")),
		"answer": item.title, "explain": "%s (%s): %s" % [item.title, region_name, item.description],
	}


## Replaces the words of [param name] in [param text] with blanks.
static func hide_name(text: String, name: String) -> String:
	var words: Array = [name]
	for w in name.replace("'", "").split(" ", false):
		if w.length() >= 4:
			words.append(w)
	for w in words:
		var re := RegEx.create_from_string("(?i)\\b%s\\b" % _regex_escape(w))
		text = re.sub(text, "_____", true)
	return text


static func _regex_escape(s: String) -> String:
	var out := ""
	for ch in s:
		out += ("\\" + ch) if ch in ".^$*+?()[]{}|\\-" else ch
	return out


func _pick_options(correct: String, candidates: Array, count := 4) -> Array:
	var others: Array = []
	for c in candidates:
		if c != correct and not c in others:
			others.append(c)
	others.shuffle()
	var options: Array = [correct]
	options.append_array(others.slice(0, count - 1))
	options.shuffle()
	return options


func _column(rows: Array, key: String) -> Array:
	var out: Array = []
	for r in rows:
		out.append(r[key])
	return out


func _vocab_to_english(w: Dictionary, words: Array) -> Dictionary:
	return {
		"type": "choice", "kind": "Vocabulary",
		"prompt": "What does \"%s\" mean?" % w.native, "detail": "",
		"options": _pick_options(w.english, _column(words, "english")),
		"answer": w.english, "explain": _word_explain(w),
	}


func _vocab_from_english(w: Dictionary, words: Array, lang_name: String) -> Dictionary:
	return {
		"type": "choice", "kind": "Vocabulary",
		"prompt": "How do you say \"%s\" in %s?" % [w.english, lang_name], "detail": "",
		"options": _pick_options(w.native, _column(words, "native")),
		"answer": w.native, "explain": _word_explain(w),
	}


func _word_explain(w: Dictionary) -> String:
	var text := "%s = %s" % [w.native, w.english]
	if str(w.get("note", "")) != "":
		text += "\n" + w.note
	return text


func _typed_word(w: Dictionary, lang_name: String) -> Dictionary:
	return {
		"type": "typed", "kind": "Recall",
		"prompt": "Type the %s word for \"%s\"." % [lang_name, w.english], "detail": "",
		"answer": w.native, "explain": _word_explain(w),
	}


func _build_sentence(s: Dictionary, sentences: Array, lang_name: String, with_distractors: bool) -> Dictionary:
	var tokens: Array = Array(s.native.split(" ", false))
	var tiles := tokens.duplicate()
	if with_distractors:
		var spare: Array = []
		for other in sentences:
			if other.id != s.id:
				for t in other.native.split(" ", false):
					if not t in tokens and not t in spare:
						spare.append(t)
		spare.shuffle()
		tiles.append_array(spare.slice(0, 2))
	tiles.shuffle()
	return {
		"type": "build", "kind": "Sentence Building",
		"prompt": "Build this sentence in %s:" % lang_name, "detail": "\"%s\"" % s.english,
		"tokens": tiles, "answer": " ".join(tokens),
		"explain": "%s\n= %s" % [s.native, s.english],
	}


func _dialogue_choice(s: Dictionary, sentences: Array, lang_name: String) -> Dictionary:
	return {
		"type": "choice", "kind": "Dialogue",
		"prompt": "Which %s sentence means:" % lang_name, "detail": "\"%s\"" % s.english,
		"options": _pick_options(s.native, _column(sentences, "native")),
		"answer": s.native, "explain": "%s\n= %s" % [s.native, s.english],
	}


func _comprehension(s: Dictionary, sentences: Array) -> Dictionary:
	return {
		"type": "choice", "kind": "Comprehension",
		"prompt": "What does this sentence mean?", "detail": "\"%s\"" % s.native,
		"options": _pick_options(s.english, _column(sentences, "english")),
		"answer": s.english, "explain": "%s\n= %s" % [s.native, s.english],
	}


func _context_choice(s: Dictionary, sentences: Array, lang_name: String) -> Dictionary:
	return {
		"type": "choice", "kind": "In Context",
		"prompt": s.context, "detail": "What would you say in %s?" % lang_name,
		"options": _pick_options(s.native, _column(sentences, "native")),
		"answer": s.native, "explain": "%s\n= %s" % [s.native, s.english],
	}


## Lenient comparison for typed and built answers: ignores case,
## punctuation, apostrophes/glottal marks and extra spaces.
static func normalize_answer(text: String) -> String:
	var out := ""
	for ch in text.to_lower():
		if ch in "?!.,'’`-":
			continue
		out += ch
	return " ".join(out.split(" ", false))


func check_answer(question: Dictionary, given: String) -> bool:
	if question.type == "choice":
		return given == question.answer
	if question.type == "grammar":
		return GrammarChecker.check(given, question.answer).ok
	return normalize_answer(given) == normalize_answer(question.answer)


func score_for(correct_points: int, hearts_left: int, diff: int) -> int:
	return correct_points + hearts_left * POINTS_PER_HEART * diff
