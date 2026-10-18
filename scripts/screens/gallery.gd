extends Control
## Culture Showcase Gallery. Clearing a level for the first time reveals one
## of that language's culture items; the rest can be unlocked with Phrase
## Crystals.

var list: VBoxContainer
var wallet_holder: VBoxContainer
var tabs: Dictionary = {}
var current := "luzon"


func _ready() -> void:
	var uid := Game.user_id()
	DB.sync_culture(uid)
	var content := UI.page(self, UI.t("gallery"), Game.BACK)
	var intro := UI.panel(Color("fff2c2"), UI.GOLD)
	var iv := UI.vbox(6)
	intro.add_child(iv)
	iv.add_child(UI.label("How to collect culture", 22, UI.RED, true, UI.font_body_black))
	iv.add_child(UI.label("Each time you clear a level for the first time, your Guiding Spirit reveals a cultural "
		+ "element of that language: its food, festivals, clothing, textiles, art, dances and music. "
		+ "You can also unlock any element now with %s." % DB.cost_text(DB.CULTURE_COST), 17, UI.INK, true))
	wallet_holder = UI.vbox(0)
	iv.add_child(wallet_holder)
	content.add_child(intro)

	var row := UI.hbox(8)
	content.add_child(row)
	for region in DB.get_regions():
		var b := UI.pill_button(region.name, UI.REGION_COLORS[region.code], _show.bind(region.code), 54, 20)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		tabs[region.code] = b
	list = UI.vbox(12)
	content.add_child(list)
	_show(Game.region_code if Game.region_code in tabs else "luzon")
	GuidePages.maybe_show(self, "gallery")

func _show(region_code: String) -> void:
	current = region_code
	var uid := Game.user_id()
	for c in wallet_holder.get_children():
		wallet_holder.remove_child(c)
		c.queue_free()
	wallet_holder.add_child(UI.wallet(uid))
	for code in tabs:
		tabs[code].modulate = Color.WHITE if code == region_code else Color(1, 1, 1, 0.55)
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	var unlocked := DB.get_unlocked_culture(uid)
	var items := DB.get_culture_items(region_code)
	var count := items.filter(func(c): return c.title in unlocked).size()
	var progress := UI.label("%d / %d collected" % [count, items.size()], 18, UI.INK_SOFT, true)
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(progress)
	for item in items:
		var title: String = item.title
		list.add_child(UI.culture_card(item, title in unlocked, func(): _buy(title)))


func _buy(title: String) -> void:
	var r := DB.unlock_culture(Game.user_id(), title)
	if r.ok:
		Sound.play("win")
		UI.toast("Unlocked: %s" % title)
	else:
		Sound.play("wrong")
		UI.toast(r.error)
	_show(current)
