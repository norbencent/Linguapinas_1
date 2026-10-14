extends Control
## Leaderboard of every player on this device (sum of best scores).

var table: VBoxContainer
var region_codes: Array = [""]


func _ready() -> void:
	var content := UI.page(self, UI.t("leaderboard"), Game.BACK)
	var picker := OptionButton.new()
	picker.add_item("All regions")
	for r in DB.get_regions():
		picker.add_item(r.name)
		region_codes.append(r.code)
	picker.item_selected.connect(func(i): _fill(region_codes[i]))
	content.add_child(picker)
	table = UI.vbox(8)
	content.add_child(table)
	_fill("")


func _fill(region_code: String) -> void:
	for c in table.get_children():
		c.queue_free()
	var rows := DB.get_leaderboard(20, region_code)
	if rows.is_empty():
		table.add_child(UI.label("No completed levels yet. Be the first Language Guardian on the board!", 20, UI.INK_SOFT, true))
	var medal := [UI.GOLD, Color("a8a9ad"), Color("c07a3a")]
	for i in rows.size():
		var r: Dictionary = rows[i]
		var me := int(r.id) == Game.user_id()
		var row := UI.row_panel(Color("f7e3a1") if me else UI.ROW)
		var h := UI.hbox(12)
		row.add_child(h)
		var rank := UI.pill(str(i + 1), medal[i] if i < 3 else UI.INK_SOFT, 22)
		rank.custom_minimum_size.x = 52
		h.add_child(rank)
		var info := UI.vbox(0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UI.label(r.display_name, 24, UI.RED if me else UI.INK, true, UI.font_body_black))
		info.add_child(UI.label("%d levels" % r.levels_completed, 16, UI.INK_SOFT))
		h.add_child(info)
		h.add_child(UI.label(str(r.total_score), 26, UI.INK, false, UI.font_body_black))
		table.add_child(row)
