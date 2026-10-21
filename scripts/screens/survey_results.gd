extends Control
## Results of the evaluation survey: weighted mean and verbal interpretation
## per statement and per criterion, by round and respondent type. Exports the
## tables as CSV and starts a re-survey (a new round).

var round_picker: OptionButton
var who_picker: OptionButton
var rounds: Array = [0]
var types: Array = [""]
var table: VBoxContainer


func _ready() -> void:
	var content := UI.page(self, "RESULTS", "survey")
	content.add_child(UI.heading("Evaluation results", UI.RED, 26))
	content.add_child(UI.label("Weighted mean = (5×f5 + 4×f4 + 3×f3 + 2×f2 + 1×f1) / N", 16, UI.INK_SOFT, true))
	var scale := UI.vbox(0)
	for sc in DB.survey().get("scale", []):
		scale.add_child(UI.label("%.2f - %.2f  %s (%s)" % [sc.range[0], sc.range[1], sc.interpretation, sc.label], 16, UI.INK_SOFT))
	content.add_child(scale)
	round_picker = OptionButton.new()
	round_picker.name = "round"
	round_picker.add_item("All rounds")
	for r in DB.survey_rounds():
		round_picker.add_item("Round %d" % r)
		rounds.append(r)
	round_picker.item_selected.connect(func(_i): fill())
	content.add_child(round_picker)
	who_picker = OptionButton.new()
	who_picker.add_item("All respondents")
	for t in DB.survey().get("respondent_types", []):
		who_picker.add_item(t)
		types.append(t)
	who_picker.item_selected.connect(func(_i): fill())
	content.add_child(who_picker)
	table = UI.vbox(8)
	table.name = "table"
	content.add_child(table)
	var export := UI.gem_button("EXPORT CSV", "blue", _export, 72, 26)
	export.name = "export"
	content.add_child(export)
	var again := UI.pill_button("START RE-SURVEY", UI.RED, _confirm_new_round, 52, 20)
	again.name = "new_round"
	content.add_child(again)
	fill()


func fill() -> void:
	for c in table.get_children():
		table.remove_child(c)
		c.queue_free()
	var rep := DB.survey_report(rounds[round_picker.selected], types[who_picker.selected])
	var by := ", ".join(rep.by_type.keys().map(func(k): return "%s %d" % [k, rep.by_type[k]]))
	table.add_child(UI.label("Respondents: %d%s" % [rep.respondents, "  (%s)" % by if by != "" else ""], 20, UI.INK, true, UI.font_body_black))
	if rep.respondents == 0:
		table.add_child(UI.label("No answers yet. Open the survey to answer it.", 18, UI.INK_SOFT, true))
		return
	for c in rep.criteria:
		var p := UI.panel()
		var v := UI.vbox(4)
		p.add_child(v)
		v.add_child(UI.label("%s. %s" % [c.code, c.name], 20, UI.RED, true, UI.font_body_black))
		for it in c.items:
			var row := UI.hbox(8)
			var t := UI.label("%s  %s" % [it.code, it.text], 15, UI.INK, true)
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(t)
			var m := UI.label("%.2f" % it.mean, 18, UI.INK, false, UI.font_body_black)
			m.custom_minimum_size.x = 60
			row.add_child(m)
			v.add_child(row)
		v.add_child(UI.label("Mean %.2f  -  %s" % [c.mean, c.interpretation], 18, UI.GREEN, true, UI.font_body_black))
		table.add_child(p)
	var overall := UI.label("OVERALL MEAN %.2f  -  %s" % [rep.overall, rep.overall_interpretation], 22, UI.RED, true, UI.font_body_black)
	overall.name = "overall"
	table.add_child(overall)


func _export() -> void:
	var paths := DB.export_evaluation()
	UI.message(self, "Exported", "Saved for the manuscript:\n%s\n\nFolder: %s" % [
		"\n".join(paths.map(func(p): return str(p).get_file())),
		ProjectSettings.globalize_path("user://evaluation")])


func _confirm_new_round() -> void:
	var d := ConfirmationDialog.new()
	d.title = "Start a re-survey?"
	d.dialog_text = "New answers will be saved as round %d. The answers of earlier rounds are kept, so you can compare them." % (DB.survey_round() + 1)
	d.dialog_autowrap = true
	d.min_size = Vector2i(560, 0)
	add_child(d)
	d.confirmed.connect(func():
		DB.start_new_survey_round()
		UI.toast("Survey round %d started." % DB.survey_round())
		Game.goto("survey", false))
	d.canceled.connect(d.queue_free)
	d.popup_centered()
