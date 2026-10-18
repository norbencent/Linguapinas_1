extends Control
## "Enter your name" card (prototype screen 4). Creates a player profile.

var name_edit: LineEdit
var password_edit: LineEdit
var status: Label
var avatar := "boy"
var avatar_buttons := {}


func _ready() -> void:
	_build_card(self, UI.t("enter_name"), UI.t("name_intro"))


func _build_card(root: Control, title: String, intro: String) -> void:
	UI.background(root)
	var top := UI.top_bar("menu")
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 20
	root.add_child(top)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE  # let clicks reach the back button
	root.add_child(center)
	var card := PanelContainer.new()
	var sb := UI._box(UI.PARCHMENT, 18, Color("c99a2e"), 8, 30)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 18
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(620, 0)
	center.add_child(card)
	var v := UI.vbox(16)
	card.add_child(v)
	v.add_child(UI.heading(title, UI.INK, 34))
	var intro_label := UI.label(intro, 20, UI.INK, true)
	intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(intro_label)

	name_edit = UI.line_edit(UI.t("name_hint"))
	name_edit.max_length = 20
	v.add_child(name_edit)
	password_edit = UI.line_edit(UI.t("password_hint"), true)
	v.add_child(password_edit)

	v.add_child(UI.heading(UI.t("choose_avatar"), UI.RED, 22))
	var row := UI.hbox(30)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for a in ["boy", "girl"]:
		var b := TextureButton.new()
		b.texture_normal = UI.tex["luzon_" + a]
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(170, 180)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.pressed.connect(_pick_avatar.bind(a))
		row.add_child(b)
		avatar_buttons[a] = b
	_pick_avatar("boy")

	status = UI.label("", 20, UI.RED, true)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(status)
	v.add_child(UI.gem_button(UI.t("start_adventure"), "red", _submit, 84, 30))
	name_edit.text_submitted.connect(func(_t): _submit())
	password_edit.text_submitted.connect(func(_t): _submit())
	Tutorial.show_steps(root, [{"id": "new_name", "target": name_edit,
		"text": "Type your name here, choose your hero (boy or girl), then tap START ADVENTURE. The password is optional."}])


func _pick_avatar(a: String) -> void:
	avatar = a
	for key in avatar_buttons:
		avatar_buttons[key].modulate = Color.WHITE if key == a else Color(1, 1, 1, 0.45)


func _submit() -> void:
	var result := DB.register_user(name_edit.text, password_edit.text, name_edit.text, avatar)
	if result.ok:
		Game.user = result.user
		Tutorial.start_for_player()  # every new Guardian gets the guided tour
		Game.login(result.user)
	else:
		status.text = result.error
