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
	"gallery": "res://scenes/gallery.tscn",
	"stories": "res://scenes/stories.tscn",
	"spirit": "res://scenes/guiding_spirit.tscn",
	"profile": "res://scenes/profile.tscn",
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
var return_to := ""              # where the Guiding Spirit's Back button goes
var settings_return := "title"   # where Settings' Exit button goes

## Screens that can be opened without a player.
const PUBLIC_SCREENS := ["title", "menu", "new_game", "continue", "settings"]
const PLAYTIME_SAVE_EVERY := 30.0
var _unsaved_playtime := 0.0


func _process(delta: float) -> void:
	if not is_logged_in():
		return
	_unsaved_playtime += delta
	if _unsaved_playtime >= PLAYTIME_SAVE_EVERY:
		save_playtime()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_playtime()


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
	goto("map")


func logout() -> void:
	save_playtime()
	user = {}
	region_code = ""
	language_code = ""
	goto("title")


func goto(screen: String) -> void:
	if not screen in PUBLIC_SCREENS and not is_logged_in():
		screen = "title"
	get_tree().change_scene_to_file(SCENES[screen])


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
	return questions.slice(0, QUESTIONS_PER_QUIZ)


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
	return normalize_answer(given) == normalize_answer(question.answer)


func score_for(correct_points: int, hearts_left: int, diff: int) -> int:
	return correct_points + hearts_left * POINTS_PER_HEART * diff
