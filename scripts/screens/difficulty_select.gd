extends Control
## EASY / MEDIUM / HARD for one language (prototype difficulty screen).

const ACTIVITY := {
	1: ["Maramihang Pagpipilian", "Multiple Choice"],
	2: ["Pagbuo ng Pangungusap", "Sentence Building"],
	3: ["Pakikipag-usap sa Konteksto", "Conversation in Context"],
}
const DESCRIPTION := {
	1: "Vocabulary and recognition.",
	2: "Build sentences and pick the right dialogue.",
	3: "Choose what to say in real situations, build sentences with decoy words, and recall words.",
}
var COLORS := {1: UI.GREEN, 2: UI.BLUE, 3: UI.RED}

var category_codes: Array = [""]


var easy_start: Button


func _ready() -> void:
	var lang := DB.get_language(Game.language_code)
	if lang.is_empty():
		Game.goto("map")
		return
	if not DB.is_language_unlocked(Game.user_id(), lang.code):
		Game.region_code = lang.region_code
		Game.goto("language")
		return
	var content := UI.page(self, lang.name, "language")
	var uid := Game.user_id()

	var cat_row := UI.hbox(10)
	cat_row.add_child(UI.label("Category:", 20, UI.INK, false, UI.font_body_black))
	var picker := OptionButton.new()
	picker.add_item("All")
	for c in DB.get_categories(lang.code):
		picker.add_item(c.name)
		category_codes.append(c.code)
	picker.select(maxi(0, category_codes.find(Game.category_code)))
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.item_selected.connect(func(i): Game.category_code = category_codes[i])
	picker.fit_to_longest_item = false
	cat_row.add_child(picker)
	content.add_child(cat_row)

	var progress := DB.get_progress(uid, lang.code)
	for d in [DB.EASY, DB.MEDIUM, DB.HARD]:
		var unlocked := DB.is_difficulty_unlocked(uid, lang.code, d)
		var color: Color = COLORS[d] if unlocked else UI.LOCKED
		var box := UI.vbox(6)
		var top := UI.hbox(10)
		top.add_child(UI.pill(Game.difficulty_name(d), color, 24))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(spacer)
		if progress[d].completed:
			top.add_child(UI.label("Best %d" % progress[d].best_score, 18, UI.GREEN, false, UI.font_body_black))
		box.add_child(top)
		box.add_child(UI.label(ACTIVITY[d][0 if UI.lang == "fil" else 1], 22, color.darkened(0.15), true, UI.font_body_black))
		box.add_child(UI.label(DESCRIPTION[d], 17, UI.INK_SOFT, true))
		box.add_child(UI.label("%s +%d" % [UI.t("points"), Game.POINTS_PER_CORRECT * d], 18, UI.INK))
		var buttons := UI.hbox(10)
		var lesson := UI.button(UI.t("lesson"), func(): _open(d, "lesson"), 0, 22)
		lesson.disabled = not unlocked
		buttons.add_child(lesson)
		var p: Dictionary = progress[d]
		var start := UI.pill_button(UI.t("start") if unlocked else UI.t("locked"), color,
			func(): _open(d, "quiz" if p.lesson_done else "lesson"), 60, 26)
		start.disabled = not unlocked
		start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if d == DB.EASY:
			easy_start = start
		buttons.add_child(start)
		box.add_child(buttons)
		content.add_child(box)
		var line := ColorRect.new()
		line.color = Color("6b3d12")
		line.custom_minimum_size.y = 3
		content.add_child(line)


	_grammar_section(content, lang, progress)
	Tutorial.show_steps(self, [{"id": "level_easy", "target": easy_start, "wait": true,
		"text": "Every language has three levels: EASY, MEDIUM and HARD. Begin with EASY: tap START to open its lesson."}])


## Grammar quiz: opens after Easy, rewards Phrase Crystals.

func _grammar_section(content: VBoxContainer, lang: Dictionary, progress: Dictionary) -> void:
	var unlocked: bool = progress[DB.EASY].completed
	var color := Color("6b3fa0") if unlocked else UI.LOCKED
	var box := UI.vbox(6)
	box.name = "grammar"
	box.add_child(UI.pill("GRAMMAR", color, 24))
	box.add_child(UI.label("Grammar quiz with a grammar checker", 22, color.darkened(0.15), true, UI.font_body_black))
	box.add_child(UI.label("Pick the correct sentence, fill in the missing word, and write sentences that the "
		+ "grammar checker marks: it tells you about spelling, missing or extra words and word order. Earns %s."
		% DB.REWARD_NAMES.phrase_crystal, 17, UI.INK_SOFT, true))
	var tips := DB.get_tips(lang.code)
	for t in tips:
		box.add_child(UI.label("• " + t.tip, 16, UI.INK, true))
	var start := UI.pill_button(UI.t("start") if unlocked else "%s · clear Easy first" % UI.t("locked"), color, func():
		Game.category_code = Game.GRAMMAR
		Game.difficulty = DB.MEDIUM
		Game.goto("quiz"), 60, 24)
	start.name = "start_grammar"
	start.disabled = not unlocked
	box.add_child(start)
	content.add_child(box)


func _open(d: int, screen: String) -> void:
	Game.difficulty = d
	if Game.category_code == Game.GRAMMAR:
		Game.category_code = ""
	Game.goto(screen)
