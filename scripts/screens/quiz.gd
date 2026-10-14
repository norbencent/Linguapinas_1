extends Control
## The quiz (prototype quiz screen). Five hearts; a wrong answer costs one.
## Tap the guide's medallion for a hint (limited per quiz).

var questions: Array = []
var index := 0
var hearts := Game.MAX_HEARTS
var hints_left := Game.HINTS_PER_QUIZ
var correct_count := 0
var points := 0
var hint_used_on_question := false
var answered := false
var selected := ""

var progress_bar: ProgressBar
var hearts_holder: HBoxContainer
var hearts_box: HBoxContainer
var points_label: Label
var counter_pill: PanelContainer
var hint_label: Label
var prompt_label: Label
var detail_label: Label
var answer_area: VBoxContainer
var feedback_label: Label
var explain_label: Label
var action_button: Button
var mark: Control
var choice_grid: VBoxContainer
var option_buttons: Array = []

# build-question state
var built: Array = []
var built_label: Label
var tile_buttons: Array = []
var typed_edit: LineEdit


func _ready() -> void:
	var lang := DB.get_language(Game.language_code)
	if lang.is_empty():
		Game.goto("map")
		return
	questions = Game.build_quiz(Game.language_code, Game.difficulty,
		Game.category_code if Game.difficulty == DB.EASY else "")
	UI.background(self)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)
	var col := UI.vbox(0)
	margin.add_child(col)

	# Header: progress, hearts, points, badge
	var header := PanelContainer.new()
	var hsb := UI._box(Color("f3dc84"), 26, Color("b8862b"), 3, 10)
	header.add_theme_stylebox_override("panel", hsb)
	col.add_child(header)
	var hv := UI.vbox(6)
	header.add_child(hv)
	var hrow := UI.hbox(10)
	hv.add_child(hrow)
	var back := TextureButton.new()
	back.texture_normal = UI.tex.back
	back.ignore_texture_size = true
	back.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	back.custom_minimum_size = Vector2(56, 56)
	back.pressed.connect(func():
		Sound.click()
		Game.go("difficulty"))
	Game.set_back("difficulty")
	hrow.add_child(back)
	progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(0, 18)
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress_bar.max_value = maxi(1, questions.size())
	hrow.add_child(progress_bar)
	hrow.add_child(UI.image(UI.tex.badge, Vector2(60, 60)))
	var hrow2 := UI.hbox(10)
	hv.add_child(hrow2)
	hearts_holder = UI.hbox(0)
	hrow2.add_child(hearts_holder)
	hearts_box = UI.hearts_row(hearts)
	hearts_holder.add_child(hearts_box)
	points_label = UI.label("", 20, UI.INK, false, UI.font_body_black)
	points_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hrow2.add_child(points_label)

	# Story scene
	var scene_img := TextureRect.new()
	scene_img.texture = UI.tex.quiz_scene
	scene_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scene_img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scene_img.custom_minimum_size = Vector2(0, 230)
	scene_img.clip_contents = true
	col.add_child(scene_img)

	# Parchment frame
	var parts := UI.frame()
	var fr: NinePatchRect = parts[0]
	fr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts[1].add_theme_constant_override("margin_top", 56)
	col.add_child(fr)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts[1].add_child(scroll)
	var content := UI.vbox(12)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	var qrow := UI.hbox(10)
	content.add_child(qrow)
	counter_pill = UI.pill("", UI.GREEN, 26)
	counter_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	qrow.add_child(counter_pill)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qrow.add_child(spacer)
	var guide_box := UI.vbox(0)
	var guide := TextureButton.new()
	guide.texture_normal = UI.tex["guide_" + lang.region_code]
	guide.ignore_texture_size = true
	guide.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	guide.custom_minimum_size = Vector2(80, 80)
	guide.tooltip_text = "Ask %s for a hint" % UI.GUIDES[lang.region_code]
	guide.pressed.connect(_use_hint)
	guide_box.add_child(guide)
	hint_label = UI.label("", 15, Color("5a3591"), false, UI.font_body_black)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide_box.add_child(hint_label)
	qrow.add_child(guide_box)

	prompt_label = UI.label("", 26, UI.INK, true, UI.font_body_black)
	content.add_child(prompt_label)
	detail_label = UI.label("", 24, UI.RED, true)
	content.add_child(detail_label)

	var answer_holder := Control.new()
	answer_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	answer_holder.custom_minimum_size.y = 300
	content.add_child(answer_holder)
	answer_area = UI.vbox(10)
	answer_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	answer_holder.add_child(answer_area)
	mark = Control.new()
	mark.set_anchors_preset(Control.PRESET_CENTER)
	mark.custom_minimum_size = Vector2(150, 150)
	mark.offset_left = -75
	mark.offset_top = -75
	mark.offset_right = 75
	mark.offset_bottom = 75
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.visible = false
	mark.set_meta("ok", false)
	mark.draw.connect(_draw_mark)
	answer_holder.add_child(mark)

	feedback_label = UI.label("", 24, UI.GREEN, true, UI.font_body_black)
	content.add_child(feedback_label)
	explain_label = UI.label("", 19, UI.INK, true)
	content.add_child(explain_label)
	action_button = UI.pill_button(UI.t("check"), UI.GREEN, _on_action, 66, 32)
	content.add_child(action_button)

	col.add_child(UI.nav_bar("difficulty"))

	if questions.is_empty():
		UI.message(self, "No questions", "This language has no content for this level yet.")
		Game.goto("difficulty")
		return
	_show_question()


func _draw_mark() -> void:
	var c := mark.size / 2
	var r := minf(mark.size.x, mark.size.y) / 2 - 4
	var ok: bool = mark.get_meta("ok")
	mark.draw_circle(c, r, UI.GREEN if ok else Color("e0242c"))
	mark.draw_arc(c, r, 0, TAU, 48, Color.WHITE, 6, true)
	if ok:
		mark.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.45, 0), c + Vector2(-r * 0.1, r * 0.35),
			c + Vector2(r * 0.5, -r * 0.35)]), Color.WHITE, r * 0.22, true)
	else:
		var d := r * 0.42
		mark.draw_line(c + Vector2(-d, -d), c + Vector2(d, d), Color.WHITE, r * 0.25, true)
		mark.draw_line(c + Vector2(d, -d), c + Vector2(-d, d), Color.WHITE, r * 0.25, true)


func _refresh_bar() -> void:
	var new_hearts := UI.hearts_row(hearts)
	hearts_holder.add_child(new_hearts)
	hearts_box.queue_free()
	hearts_box = new_hearts
	progress_bar.value = index + (1 if answered else 0)
	points_label.text = "%s: %d" % [UI.t("points"), points]
	(counter_pill.get_child(0) as Label).text = "%s %d" % [UI.t("question"), mini(index + 1, questions.size())]
	hint_label.text = "%s x%d" % [UI.t("hint"), hints_left]


func _show_question() -> void:
	answered = false
	selected = ""
	hint_used_on_question = false
	mark.visible = false
	feedback_label.text = ""
	explain_label.text = ""
	action_button.text = UI.t("check")
	UI.tint_button(action_button, UI.GREEN)
	action_button.disabled = false
	for c in answer_area.get_children():
		answer_area.remove_child(c)
		c.queue_free()
	option_buttons = []
	var q: Dictionary = questions[index]
	prompt_label.text = q.prompt
	detail_label.text = q.detail
	detail_label.visible = q.detail != ""
	match q.type:
		"choice":
			choice_grid = UI.vbox(8)
			answer_area.add_child(choice_grid)
			var letters := "ABCD"
			for i in q.options.size():
				var option: String = q.options[i]
				var b := Button.new()
				b.text = "%s. %s" % [letters[i], option]
				b.alignment = HORIZONTAL_ALIGNMENT_LEFT
				b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				b.focus_mode = Control.FOCUS_NONE
				b.custom_minimum_size.y = 62
				b.add_theme_font_override("font", UI.font_body_black)
				b.add_theme_font_size_override("font_size", 22)
				b.set_meta("option", option)
				_style_option(b, "idle")
				b.pressed.connect(_select.bind(option))
				choice_grid.add_child(b)
				option_buttons.append(b)
		"build":
			built = []
			tile_buttons = []
			built_label = UI.label("", 24, UI.RED, true, UI.font_body_black)
			built_label.custom_minimum_size.y = 50
			var built_panel := UI.panel(Color("fffaf0"))
			built_panel.add_child(built_label)
			answer_area.add_child(built_panel)
			var tiles := HFlowContainer.new()
			tiles.add_theme_constant_override("h_separation", 8)
			tiles.add_theme_constant_override("v_separation", 8)
			answer_area.add_child(tiles)
			for token in q.tokens:
				var b := UI.button(token, func(): pass, 0, 24)
				b.pressed.connect(_add_tile.bind(b))
				tiles.add_child(b)
				tile_buttons.append(b)
			var undo := UI.button(UI.t("undo"), _undo_tile, 0, 20)
			undo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			answer_area.add_child(undo)
			_update_built()
		"typed":
			typed_edit = UI.line_edit(UI.t("type_answer"))
			typed_edit.text_submitted.connect(func(t): _answer(t))
			answer_area.add_child(typed_edit)
			typed_edit.call_deferred("grab_focus")
	_refresh_bar()


func _style_option(b: Button, state: String) -> void:
	var colors := {"idle": [Color("fffaf0"), Color("c9a76b"), UI.INK],
		"selected": [Color("f3dc84"), Color("8a5a2b"), UI.INK],
		"right": [Color("dff2d6"), UI.GREEN, UI.GREEN],
		"wrong": [Color("fbdcd9"), UI.RED, UI.RED]}
	var c: Array = colors[state]
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := UI._box(c[0] if s != "hover" else c[0].darkened(0.04), 14, c[1], 2, 12)
		b.add_theme_stylebox_override(s, sb)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(key, c[2])
	b.add_theme_constant_override("outline_size", 0)


func _select(option: String) -> void:
	if answered:
		return
	Sound.click()
	selected = option
	for b in option_buttons:
		_style_option(b, "selected" if b.get_meta("option") == option else "idle")


func _on_action() -> void:
	if answered:
		_next()
		return
	var q: Dictionary = questions[index]
	match q.type:
		"choice":
			if selected == "":
				return
			_answer(selected)
		"build":
			_answer(" ".join(built))
		"typed":
			_answer(typed_edit.text)


func _add_tile(b: Button) -> void:
	if answered:
		return
	built.append(b.text)
	b.disabled = true
	b.set_meta("order", built.size())
	_update_built()


func _undo_tile() -> void:
	if answered or built.is_empty():
		return
	for b in tile_buttons:
		if b.disabled and int(b.get_meta("order", -1)) == built.size():
			b.disabled = false
			b.set_meta("order", -1)
			break
	built.pop_back()
	_update_built()


func _update_built() -> void:
	built_label.text = " ".join(built) if not built.is_empty() else UI.t("build_hint")


func _use_hint() -> void:
	if hints_left <= 0 or answered:
		return
	Sound.click()
	var q: Dictionary = questions[index]
	match q.type:
		"choice":
			var removed := 0
			for b in option_buttons:
				if removed < 2 and b.get_meta("option") != q.answer and not b.disabled:
					b.disabled = true
					b.modulate = Color(1, 1, 1, 0.35)
					if selected == b.get_meta("option"):
						selected = ""
					removed += 1
		"build":
			var target: Array = Array(q.answer.split(" ", false))
			while not built.is_empty() and built != target.slice(0, built.size()):
				_undo_tile()
			if built.size() < target.size():
				for b in tile_buttons:
					if not b.disabled and b.text == target[built.size()]:
						_add_tile(b)
						break
		"typed":
			var reveal := mini(q.answer.length(), maxi(2, q.answer.length() / 2))
			typed_edit.placeholder_text = "%s..." % q.answer.substr(0, reveal)
	hints_left -= 1
	hint_used_on_question = true
	_refresh_bar()


func _answer(given: String) -> void:
	if answered:
		return
	answered = true
	var q: Dictionary = questions[index]
	var ok := Game.check_answer(q, given)
	if ok:
		correct_count += 1
		var earned := Game.POINTS_PER_CORRECT * Game.difficulty
		points += earned / 2 if hint_used_on_question else earned
		feedback_label.text = UI.t("correct")
		feedback_label.add_theme_color_override("font_color", UI.GREEN)
		Sound.play("correct")
	else:
		hearts -= 1
		feedback_label.text = "%s %s" % [UI.t("wrong"), q.answer]
		feedback_label.add_theme_color_override("font_color", UI.RED)
		Sound.play("wrong")
	explain_label.text = q.explain
	for b in option_buttons:
		b.disabled = true
		b.modulate = Color.WHITE
		if b.get_meta("option") == q.answer:
			_style_option(b, "right")
		elif b.get_meta("option") == given:
			_style_option(b, "wrong")
	mark.set_meta("ok", ok)
	mark.visible = true
	mark.queue_redraw()
	var finished := hearts <= 0 or index + 1 >= questions.size()
	action_button.text = UI.t("results_btn") if finished else UI.t("next")
	UI.tint_button(action_button, UI.GREEN if ok else UI.RED)
	_refresh_bar()


func _next() -> void:
	if hearts <= 0 or index + 1 >= questions.size():
		_finish()
		return
	index += 1
	_show_question()


func _finish() -> void:
	var passed := hearts > 0
	var score := Game.score_for(points, hearts, Game.difficulty) if passed else points
	var category := Game.category_code if Game.difficulty == DB.EASY else ""
	var summary := DB.record_quiz(Game.user_id(), Game.language_code, Game.difficulty, category,
		score, correct_count, questions.size(), maxi(hearts, 0), passed)
	Game.last_result = {
		"passed": passed, "score": score, "correct": correct_count, "total": questions.size(),
		"hearts": maxi(hearts, 0), "summary": summary,
	}
	Game.goto("results")
