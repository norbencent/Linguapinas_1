extends Control
## System evaluation survey (database/survey.json): every statement is rated
## 1-5 and the answers are saved in SQLite for the current survey round.

var who_picker: OptionButton
var comment_input: LineEdit
var answers := {}  # item code -> 1..5
var error_label: Label


func _ready() -> void:
	var content := UI.page(self, "EVALUATION", "settings")
	var s := DB.survey()
	content.add_child(UI.heading(s.get("title", "Evaluation"), UI.RED, 26))
	content.add_child(UI.label("Survey round %d%s" % [DB.survey_round(), "  (re-survey)" if DB.survey_round() > 1 else ""],
		18, UI.INK_SOFT, true, UI.font_body_black))
	content.add_child(UI.label(s.get("instructions", ""), 18, UI.INK, true))
	var legend := UI.panel(Color("fffaf0"))
	var lv := UI.vbox(2)
	legend.add_child(lv)
	for sc in s.get("scale", []):
		lv.add_child(UI.label("%d - %s" % [int(sc.value), sc.label], 17, UI.INK, false, UI.font_body_black))
	content.add_child(legend)

	content.add_child(UI.label("I am a:", 20, UI.INK, false, UI.font_body_black))
	who_picker = OptionButton.new()
	who_picker.name = "respondent"
	who_picker.add_item("(choose one)")
	for t in s.get("respondent_types", []):
		who_picker.add_item(t)
	content.add_child(who_picker)

	for c in s.get("criteria", []):
		var head := UI.heading("%s. %s" % [c.code, c.name], UI.RED, 22)
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(head)
		for item in c.items:
			content.add_child(_statement(item))

	content.add_child(UI.label("Comments or suggestions (optional):", 18, UI.INK, true, UI.font_body_black))
	comment_input = UI.line_edit("Type here")
	comment_input.name = "comment"
	content.add_child(comment_input)
	error_label = UI.label("", 18, UI.RED, true, UI.font_body_black)
	content.add_child(error_label)
	var submit := UI.gem_button("SUBMIT", "green", submit_survey, 80, 30)
	submit.name = "submit"
	content.add_child(submit)
	var results := UI.pill_button("VIEW RESULTS", UI.INK_SOFT, func(): Game.goto("survey_results"), 52, 20)
	results.name = "results"
	content.add_child(results)


static func node_name(code: String, value: int) -> String:
	return "rate_%s_%d" % [code.replace(".", "_"), value]


func _statement(item: Dictionary) -> Control:
	var p := UI.panel()
	var v := UI.vbox(8)
	p.add_child(v)
	v.add_child(UI.label("%s  %s" % [item.code, item.text], 18, UI.INK, true))
	var row := UI.hbox(8)
	var group := ButtonGroup.new()
	for value in range(1, 6):
		var b := Button.new()
		b.name = node_name(item.code, value)
		b.text = str(value)
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var chosen := UI._box(UI.GOLD, 14, Color("6b3d12"), 3, 8)
		b.add_theme_stylebox_override("pressed", chosen)
		b.add_theme_stylebox_override("hover_pressed", chosen)
		b.add_theme_color_override("font_pressed_color", UI.INK)
		b.add_theme_color_override("font_hover_pressed_color", UI.INK)
		b.add_theme_constant_override("outline_size", 0)
		b.toggled.connect(func(on):
			if on:
				Sound.click()
				answers[item.code] = value
				error_label.text = "")
		row.add_child(b)
	v.add_child(row)
	return p


func submit_survey() -> void:
	var who := who_picker.get_item_text(who_picker.selected) if who_picker.selected > 0 else ""
	var r := DB.save_survey(Game.user_id(), who, answers, comment_input.text)
	if not r.ok:
		error_label.text = r.error
		return
	UI.message(self, "Salamat po!", "Your evaluation was saved (survey round %d). Thank you for helping improve LINGUAPINAS." % DB.survey_round())
	_reset()


func _reset() -> void:
	answers.clear()
	comment_input.text = ""
	who_picker.select(0)
	for b in find_children("rate_*", "Button", true, false):
		b.set_pressed_no_signal(false)
