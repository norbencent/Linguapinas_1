extends Control
## CONTINUE: pick a saved player (and type the password if it has one).

var list: VBoxContainer
var password_box: VBoxContainer
var password_edit: LineEdit
var status: Label
var chosen: Dictionary = {}


func _ready() -> void:
	UI.background(self)
	var top := UI.top_bar("menu")
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 20
	add_child(top)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	var sb := UI._box(UI.PARCHMENT, 18, Color("c99a2e"), 8, 30)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 18
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(620, 0)
	center.add_child(card)
	var v := UI.vbox(14)
	card.add_child(v)
	v.add_child(UI.heading(UI.t("choose_player"), UI.INK, 34))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	list = UI.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var users := DB.get_users()
	if users.is_empty():
		list.add_child(UI.label(UI.t("no_players"), 22, UI.INK, true))
	for u in users:
		var row := UI.row_panel()
		var h := UI.hbox(14)
		row.add_child(h)
		var face := UI.image(UI.character_texture("luzon", u.avatar), Vector2(64, 64))
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		h.add_child(face)
		var info := UI.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		info.add_child(UI.label(u.display_name, 26, UI.INK, true, UI.font_body_black))
		info.add_child(UI.label("Score %d" % DB.get_total_score(u.id), 18, UI.INK_SOFT))
		var go := UI.pill_button(UI.t("continue"), UI.BLUE, _choose.bind(u), 56, 22)
		go.custom_minimum_size.x = 170
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(go)
		list.add_child(row)

	password_box = UI.vbox(10)
	password_box.visible = false
	v.add_child(password_box)
	password_edit = UI.line_edit(UI.t("password"), true)
	password_edit.text_submitted.connect(func(_t): _login())
	password_box.add_child(password_edit)
	password_box.add_child(UI.gem_button(UI.t("continue"), "blue", _login, 80, 30))
	status = UI.label("", 20, UI.RED, true)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(status)


func _choose(u: Dictionary) -> void:
	chosen = u
	if int(u.has_password) == 0:
		_login()
		return
	status.text = "%s: %s" % [u.display_name, UI.t("password")]
	password_box.visible = true
	password_edit.grab_focus()


func _login() -> void:
	if chosen.is_empty():
		return
	var result := DB.login_user(chosen.username, password_edit.text)
	if result.ok:
		Game.login(result.user)
	else:
		status.text = result.error
