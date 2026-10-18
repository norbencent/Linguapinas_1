extends Control
## Settings (prototype screen 3): language, music, SFX, notifications.

var lang_picker: OptionButton
var music_slider: HSlider
var sfx_slider: HSlider
var music_value: Label
var sfx_value: Label
var notify: CheckButton
var spirit_voice: CheckButton


func _ready() -> void:
	UI.background(self)
	var top := UI.top_bar(_exit)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 20
	add_child(top)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE  # let clicks reach the back button
	add_child(center)
	var outer := PanelContainer.new()
	var osb := UI._box(Color("7a1414"), 24, Color("d9a43a"), 10, 14)
	osb.shadow_color = Color(0, 0, 0, 0.5)
	osb.shadow_size = 20
	outer.add_theme_stylebox_override("panel", osb)
	outer.custom_minimum_size = Vector2(620, 0)
	center.add_child(outer)
	var col := UI.vbox(10)
	outer.add_child(col)

	var title := UI.label(UI.t("settings_title"), 56, Color("ffe7a3"), false, UI.font_button)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("4a0a0a"))
	title.add_theme_constant_override("outline_size", 12)
	col.add_child(title)

	var parchment := PanelContainer.new()
	parchment.add_theme_stylebox_override("panel", UI._box(UI.PARCHMENT, 12, Color("b8862b"), 4, 26))
	col.add_child(parchment)
	var v := UI.vbox(22)
	parchment.add_child(v)

	v.add_child(_caption(UI.t("language")))
	lang_picker = OptionButton.new()
	lang_picker.add_item("FILIPINO")
	lang_picker.add_item("ENGLISH")
	lang_picker.select(0 if UI.lang == "fil" else 1)
	lang_picker.custom_minimum_size.y = 60
	v.add_child(lang_picker)

	var music_row := _slider_row(UI.t("music"), int(DB.get_setting("music_volume", "70")))
	music_slider = music_row[0]
	music_value = music_row[1]
	v.add_child(music_row[2])
	var sfx_row := _slider_row(UI.t("sfx"), int(DB.get_setting("sfx_volume", "80")))
	sfx_slider = sfx_row[0]
	sfx_value = sfx_row[1]
	v.add_child(sfx_row[2])
	music_slider.value_changed.connect(func(x):
		music_value.text = "%d%%" % x
		Sound.apply(int(x), int(sfx_slider.value)))
	sfx_slider.value_changed.connect(func(x):
		sfx_value.text = "%d%%" % x
		Sound.apply(int(music_slider.value), int(x)))

	var nrow := UI.hbox(10)
	var nl := _caption(UI.t("notification"))
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nrow.add_child(nl)
	notify = CheckButton.new()
	notify.button_pressed = Game.notifications_on()
	notify.focus_mode = Control.FOCUS_NONE
	nrow.add_child(notify)
	v.add_child(nrow)

	var vrow := UI.hbox(10)
	var vl := _caption("BOSES NG ESPIRITU" if UI.lang == "fil" else "SPIRIT VOICE")
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vrow.add_child(vl)
	spirit_voice = CheckButton.new()
	spirit_voice.name = "spirit_voice"
	spirit_voice.button_pressed = Spirit.voice_on()
	spirit_voice.focus_mode = Control.FOCUS_NONE
	vrow.add_child(spirit_voice)
	v.add_child(vrow)

	v.add_child(UI.gem_button(UI.t("save"), "green", _save, 84, 34))
	v.add_child(UI.gem_button(UI.t("exit"), "red", _exit, 84, 34))
	if Game.is_logged_in():
		v.add_child(UI.pill_button(UI.t("logout"), UI.INK_SOFT, Game.logout, 56, 22))


func _caption(text: String) -> Label:
	return UI.label(text, 24, UI.INK, false, UI.font_body_black)


func _slider_row(caption: String, value: int) -> Array:
	var box := UI.vbox(6)
	box.add_child(_caption(caption))
	var h := UI.hbox(14)
	box.add_child(h)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	h.add_child(slider)
	var lbl := UI.label("%d%%" % value, 24, UI.INK, false, UI.font_body_black)
	lbl.custom_minimum_size.x = 80
	h.add_child(lbl)
	return [slider, lbl, box]


func _save() -> void:
	Game.save_settings("fil" if lang_picker.selected == 0 else "en", int(music_slider.value),
		int(sfx_slider.value), notify.button_pressed)
	DB.set_setting("spirit_voice", "1" if spirit_voice.button_pressed else "0")
	Game.goto(Game.settings_return, false)


func _exit() -> void:
	# Discard changes.
	Sound.apply(int(DB.get_setting("music_volume", "70")), int(DB.get_setting("sfx_volume", "80")))
	Game.goto(Game.settings_return, false)
