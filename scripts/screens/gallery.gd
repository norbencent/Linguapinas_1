extends Control
## Culture Showcase Gallery. A region's items unlock once the player
## completes any level in one of its languages.

var list: VBoxContainer
var tabs: Dictionary = {}


func _ready() -> void:
	var content := UI.page(self, UI.t("gallery"), Game.BACK)
	var row := UI.hbox(8)
	content.add_child(row)
	for region in DB.get_regions():
		var b := UI.pill_button(region.name, UI.REGION_COLORS[region.code], _show.bind(region.code), 54, 20)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		tabs[region.code] = b
	list = UI.vbox(12)
	content.add_child(list)
	var start: String = Game.region_code if Game.region_code != "" else "luzon"
	_show(start)


func _show(region_code: String) -> void:
	for code in tabs:
		tabs[code].modulate = Color.WHITE if code == region_code else Color(1, 1, 1, 0.55)
	for c in list.get_children():
		c.queue_free()
	var region := DB.get_region(region_code)
	var unlocked := DB.get_completed_level_count(Game.user_id(), region_code) > 0
	for item in DB.get_culture_items(region_code):
		var card := UI.panel(UI.CARD if unlocked else Color("d9d2c2"), Color("8a5a2b") if unlocked else Color("8d8170"))
		var v := UI.vbox(4)
		card.add_child(v)
		v.add_child(UI.pill(item.kind.to_upper(), UI.REGION_COLORS[region_code] if unlocked else Color("8d8170"), 16))
		if unlocked:
			v.add_child(UI.label(item.title, 26, UI.RED, true, UI.font_body_black))
			v.add_child(UI.label(item.description, 18, UI.INK, true))
		else:
			v.add_child(UI.label("%s · %s" % [UI.t("locked"), item.kind], 24, Color("5f5446"), true, UI.font_body_black))
			v.add_child(UI.label("Complete a level in %s to unlock." % region.name, 17, Color("5f5446"), true))
		list.add_child(card)
