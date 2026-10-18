extends Control
## Title screen: logo, START and SETTING (prototype screen 1).
## Laid out with anchors and a centered column so it fits any screen size or
## background picture, with a short fade-in and a gently floating logo.

const COLUMN_WIDTH := 480.0

var _logo: TextureRect


func _ready() -> void:
	UI.background(self)
	_badge()

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 24)
	add_child(column)

	# The logo sits inside a plain Control so the float tween can move it
	# without the container snapping it back.
	var logo_box := Control.new()
	logo_box.custom_minimum_size = Vector2(0, 230)
	column.add_child(logo_box)
	_logo = UI.image(UI.tex.logo, Vector2.ZERO)
	_logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_logo.offset_left = 30
	_logo.offset_right = -30
	logo_box.add_child(_logo)

	var tagline := UI.label(_tagline(), 26, UI.WHITE, true, UI.font_body_black)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_color_override("font_outline_color", Color("3b2208"))
	tagline.add_theme_constant_override("outline_size", 10)
	column.add_child(_centered(tagline, 660.0))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 90)
	column.add_child(gap)

	var start_button := UI.gem_button(UI.t("start"), "green", _on_start, 130, 50)
	column.add_child(_centered(start_button))
	column.add_child(_centered(UI.gem_button(UI.t("setting"), "gold", _on_settings, 130, 50)))

	var version := UI.label("v" + str(ProjectSettings.get_setting("application/config/version", "1.0")), 16, UI.WHITE)
	version.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	version.add_theme_constant_override("outline_size", 6)
	version.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	version.offset_left = 20
	version.offset_top = -44
	version.offset_bottom = -14
	add_child(version)

	_intro(column)
	Tutorial.show_steps(self, [{"id": "title_start", "target": start_button, "wait": true,
		"text": "Mabuhay! Welcome to LinguaPinas. Tap START to begin your adventure."}])


func _tagline() -> String:
	if UI.lang == "fil":
		return "Matuto ng mga wika ng Pilipinas!"
	return "Learn the languages of the Philippines!"


func _centered(c: Control, width := COLUMN_WIDTH) -> CenterContainer:
	c.custom_minimum_size.x = width
	var box := CenterContainer.new()
	box.add_child(c)
	return box


func _badge() -> void:
	var badge := UI.image(UI.tex.badge, Vector2(84, 84))
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -104
	badge.offset_right = -20
	badge.offset_top = 20
	badge.offset_bottom = 104
	add_child(badge)


func _intro(column: Control) -> void:
	column.modulate.a = 0.0
	create_tween().tween_property(column, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	var bob := create_tween().set_loops()
	bob.tween_property(_logo, "position:y", -10.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_logo, "position:y", 0.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_start() -> void:
	Game.goto("menu")


func _on_settings() -> void:
	Game.open_settings("title")


## Enter starts the game. Esc / the Android back key are handled by Game,
## which closes the game from the title screen.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		Sound.click()
		_on_start()
