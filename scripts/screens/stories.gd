extends Control
## Regional stories, unlocked by lighting up each island pearl.


func _ready() -> void:
	var content := UI.page(self, UI.t("stories"), Game.BACK)
	var restored := DB.get_restored_cores(Game.user_id())
	var all_restored := restored.size() == DB.get_regions().size()
	for story in DB.get_stories():
		var region := DB.get_region(story.region_code)
		var unlocked: bool = all_restored if story.region_code == "pearl" else story.region_code in restored
		var color: Color = UI.REGION_COLORS.get(story.region_code, UI.GOLD)
		var card := UI.panel(UI.CARD if unlocked else Color("d9d2c2"), color if unlocked else Color("8d8170"))
		var v := UI.vbox(8)
		card.add_child(v)
		if story.region_code in UI.GUIDES:
			var head := UI.hbox(10)
			head.add_child(UI.image(UI.tex["guide_" + story.region_code], Vector2(64, 64)))
			head.add_child(UI.label(story.title if unlocked else UI.t("locked"), 24, color.darkened(0.1) if unlocked else Color("5f5446"), true, UI.font_body_black))
			v.add_child(head)
		else:
			v.add_child(UI.label(story.title if unlocked else UI.t("locked"), 24, UI.RED if unlocked else Color("5f5446"), true, UI.font_body_black))
		if unlocked:
			v.add_child(UI.label(story.body, 19, UI.INK, true))
		elif story.region_code == "pearl":
			v.add_child(UI.label("Light all three island pearls to unlock this story.", 18, Color("5f5446"), true))
		else:
			v.add_child(UI.label("Restore the %s to unlock this story." % region.core_name, 18, Color("5f5446"), true))
		content.add_child(card)
