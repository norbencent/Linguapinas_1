extends Control
## CONTINUE: pick a saved player (and type the password if it has one),
## or delete a player (sample or old profiles) after confirming.

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
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE  # let clicks reach the back button
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
	_refresh_list()

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


func _refresh_list() -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	var users := DB.get_users()
	if users.is_empty():
		list.add_child(UI.label(UI.t("no_players"), 22, UI.INK, true))
	for u in users:
		var row := UI.row_panel()
		row.name = "player_%d" % int(u.id)
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
		var buttons := UI.vbox(6)
		buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(buttons)
		var go := UI.pill_button(UI.t("continue"), UI.BLUE, _choose.bind(u), 52, 20)
		go.custom_minimum_size.x = 170
		buttons.add_child(go)
		var del := UI.pill_button(UI.t("delete"), UI.RED, _ask_delete.bind(u), 40, 16)
		del.name = "delete"
		buttons.add_child(del)
		list.add_child(row)


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


# ---------------------------------------------------------------- delete

## Confirmation pop-up. Players with a password must type it to be deleted.
func _ask_delete(u: Dictionary) -> void:
	var needs_password := int(u.has_password) == 1
	var overlay := ColorRect.new()
	overlay.name = "DeletePopup"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	Game.overlays.append(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var card := PanelContainer.new()
	var sb := UI._box(UI.PARCHMENT, 18, UI.RED, 6, 26)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 16
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)
	var v := UI.vbox(14)
	card.add_child(v)
	v.add_child(UI.heading(UI.t("delete_title"), UI.RED, 30))
	v.add_child(UI.label(UI.t("delete_confirm") % u.display_name, 21, UI.INK, true))

	var pw: LineEdit = null
	if needs_password:
		v.add_child(UI.label(UI.t("delete_password") % u.display_name, 19, UI.INK_SOFT, true))
		pw = UI.line_edit(UI.t("password"), true)
		v.add_child(pw)
	var err := UI.label("", 19, UI.RED, true)
	v.add_child(err)

	var row := UI.hbox(12)
	v.add_child(row)
	var cancel := UI.pill_button(UI.t("cancel"), UI.INK_SOFT, func(): _close_popup(overlay), 60, 22)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	var confirm := func():
		if pw != null and not DB.check_password(int(u.id), pw.text):
			err.text = UI.t("wrong_password")
			Sound.play("wrong")
			return
		_delete(u)
		_close_popup(overlay)
	var ok := UI.pill_button(UI.t("delete"), UI.RED, confirm, 60, 22)
	ok.name = "confirm_delete"
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ok)
	if pw != null:
		pw.text_submitted.connect(func(_t): confirm.call())
		pw.grab_focus.call_deferred()


func _close_popup(overlay: Node) -> void:
	Game.overlays.erase(overlay)
	if is_instance_valid(overlay):
		overlay.queue_free()


func _delete(u: Dictionary) -> void:
	var id := int(u.id)
	if not DB.delete_user(id):
		status.text = DB.last_error
		return
	if Game.user_id() == id:
		Game.user = {}
	if int(chosen.get("id", -1)) == id:
		chosen = {}
		password_box.visible = false
	status.text = ""
	UI.toast(UI.t("deleted") % u.display_name)
	_refresh_list()
