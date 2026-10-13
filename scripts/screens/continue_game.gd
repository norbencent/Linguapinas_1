extends Control
## CONTINUE: pick a saved player, or delete one.

var list: VBoxContainer
var status: Label


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
	card.custom_minimum_size = Vector2(640, 0)
	center.add_child(card)
	var v := UI.vbox(14)
	card.add_child(v)
	v.add_child(UI.heading(UI.t("choose_player"), UI.INK, 34))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	list = UI.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	status = UI.label("", 20, UI.RED, true)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(status)
	_fill()


func _fill() -> void:
	for c in list.get_children():
		c.queue_free()
	var users := DB.get_users()
	if users.is_empty():
		list.add_child(UI.label(UI.t("no_players"), 22, UI.INK, true))
	for u in users:
		var row := UI.row_panel()
		var h := UI.hbox(12)
		row.add_child(h)
		h.add_child(UI.image(UI.avatar_portrait(u.avatar), Vector2(72, 72)))
		var info := UI.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		info.add_child(UI.label(u.display_name, 26, UI.INK, true, UI.font_body_black))
		info.add_child(UI.label("Score %d" % DB.get_total_score(u.id), 18, UI.INK_SOFT))
		var go := UI.pill_button(UI.t("continue"), UI.BLUE, _choose.bind(u), 56, 20)
		go.custom_minimum_size.x = 150
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(go)
		var del := UI.pill_button(UI.t("delete"), UI.RED, _ask_delete.bind(u), 56, 20)
		del.custom_minimum_size.x = 120
		del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(del)
		list.add_child(row)


func _choose(u: Dictionary) -> void:
	var result := DB.login_user(u.username)
	if result.ok:
		Game.login(result.user)
	else:
		status.text = result.error


func _ask_delete(u: Dictionary) -> void:
	UI.confirm(self, UI.t("delete_title"), UI.t("delete_confirm") % u.display_name, func():
		DB.delete_user(int(u.id))
		status.text = ""
		if DB.get_users().is_empty():
			Game.goto("menu")
		else:
			_fill())
