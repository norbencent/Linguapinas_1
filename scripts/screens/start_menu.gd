extends Control
## NEW GAME / CONTINUE / SETTING (prototype screen 2).


func _ready() -> void:
	UI.background(self)
	var logo := UI.image(UI.tex.logo, Vector2.ZERO)
	add_child(logo)
	UI.place_on_background(self, logo, Rect2(17, 140, 242, 98))
	var buttons := [
		[UI.t("new_game"), "red", func(): Game.goto("new_game"), Rect2(38, 262, 206, 78)],
		[UI.t("continue"), "blue", func(): Game.goto("continue"), Rect2(38, 350, 206, 78)],
		[UI.t("setting"), "gold", func(): Game.open_settings("menu"), Rect2(38, 438, 206, 78)],
	]
	var new_game: Control
	for spec in buttons:
		var b := UI.gem_button(spec[0], spec[1], spec[2], 96, 44)
		if spec[1] == "red":
			new_game = b
		add_child(b)
		UI.place_on_background(self, b, spec[3])
		if spec[1] == "blue":
			b.disabled = DB.get_users().is_empty()
	var top := UI.top_bar("title")
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 20
	add_child(top)
	Tutorial.show_steps(self, [{"id": "menu_new", "target": new_game, "wait": true,
		"text": "First time here? Tap NEW GAME to create your Language Guardian."}])
