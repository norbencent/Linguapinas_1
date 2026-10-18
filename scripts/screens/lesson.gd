extends Control
## Pre-quiz lesson. Content depends on the difficulty.


func _ready() -> void:
	var lang := DB.get_language(Game.language_code)
	if lang.is_empty():
		Game.goto("map")
		return
	var color: Color = UI.REGION_COLORS.get(lang.region_code, UI.RED)
	var content := UI.page(self, UI.t("lesson").capitalize(), "difficulty")
	content.add_child(UI.ribbon("%s · %s" % [lang.name, Game.difficulty_name()], color))

	match Game.difficulty:
		DB.EASY:
			content.add_child(_intro("Study these words. Say each one aloud before the quiz."))
			var categories := DB.get_categories(lang.code)
			if Game.category_code != "":
				categories = categories.filter(func(c): return c.code == Game.category_code)
			for c in categories:
				content.add_child(UI.heading(c.name, color.darkened(0.1), 24))
				var grid := GridContainer.new()
				grid.columns = 2
				grid.add_theme_constant_override("h_separation", 10)
				grid.add_theme_constant_override("v_separation", 10)
				content.add_child(grid)
				for w in DB.get_words(lang.code, c.code):
					var card := _card(w.native, w.english, w.note)
					card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					grid.add_child(card)
		DB.MEDIUM:
			content.add_child(_intro("Learn these sentences. You will rebuild them word by word."))
			for s in DB.get_sentences(lang.code):
				content.add_child(_card(s.native, s.english, "  |  ".join(s.native.split(" ", false))))
		DB.HARD:
			content.add_child(_intro("Learn what to say in each situation. You will also type words from memory."))
			for s in DB.get_sentences(lang.code):
				content.add_child(_card(s.native, s.english, (s.context) if s.context != "" else ""))
			content.add_child(UI.heading("Vocabulary", color.darkened(0.1), 24))
			var pairs: Array = []
			for w in DB.get_words(lang.code):
				pairs.append("%s = %s" % [w.native, w.english])
			content.add_child(UI.label("  •  ".join(pairs), 19, UI.INK, true))

	var tips := DB.get_tips(lang.code)
	if not tips.is_empty():
		var tip_panel := UI.panel(Color("efe0ff"), Color("8a63c2"))
		var tv := UI.vbox(6)
		tip_panel.add_child(tv)
		var head := UI.hbox(10)
		head.add_child(UI.image(UI.tex["guide_" + lang.region_code], Vector2(56, 56)))
		head.add_child(UI.label(UI.GUIDES.get(lang.region_code, "Guide") + "'s tips", 22, Color("5a3591"), false, UI.font_body_black))
		tv.add_child(head)
		for t in tips:
			tv.add_child(UI.label("• " + t.tip, 18, UI.INK, true))
		content.add_child(tip_panel)

	_culture_corner(content, lang)

	var start := UI.gem_button(UI.t("start_quiz"), "green", _start_quiz, 90, 30)
	content.add_child(start)
	Tutorial.show_steps(self, [
		{"id": "lesson_study", "text": "This is the lesson. Read each word and its meaning, and say it aloud. Scroll down to see them all."},
		{"id": "lesson_start", "target": start, "wait": true,
			"text": "Ready? Tap START QUIZ. The quiz asks about the words you just studied."}])


## The language's culture: unlocked items are shown in full, locked ones say
## how to reveal them.

func _culture_corner(content: VBoxContainer, lang: Dictionary) -> void:
	var items := DB.get_culture_items(lang.region_code).filter(func(c): return c.language_code == lang.code)
	if items.is_empty():
		return
	var unlocked := DB.get_unlocked_culture(Game.user_id())
	var box := UI.vbox(8)
	box.name = "culture_corner"
	box.add_child(UI.heading("Culture corner", UI.REGION_COLORS.get(lang.region_code, UI.RED).darkened(0.1), 24))
	var shown := 0
	for item in items:
		if item.title in unlocked:
			box.add_child(UI.culture_card(item, true))
			shown += 1
	var locked := items.size() - shown
	if locked > 0:
		box.add_child(UI.label("%d more %s culture item%s to discover: clear a level you haven't cleared yet, or unlock it in the Gallery."
			% [locked, lang.name, "" if locked == 1 else "s"], 17, UI.INK_SOFT, true))
	content.add_child(box)


func _intro(text: String) -> Label:
	var l := UI.label(text, 19, UI.INK_SOFT, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _card(native: String, english: String, note: String) -> PanelContainer:
	var card := UI.panel()
	var v := UI.vbox(2)
	card.add_child(v)
	v.add_child(UI.label(native, 24, UI.RED, true, UI.font_body_black))
	v.add_child(UI.label(english, 19, UI.INK, true))
	if note != "":
		v.add_child(UI.label(note, 15, UI.INK_SOFT, true))
	return card


func _start_quiz() -> void:
	DB.mark_lesson_done(Game.user_id(), Game.language_code, Game.difficulty)
	Game.goto("quiz")
