extends Control
## How to play (GABAY): every tutorial topic, readable any time.


func _ready() -> void:
	var content := UI.page(self, "Gabay" if UI.lang == "fil" else "Guide", Game.BACK)
	var head := UI.hbox(12)
	head.add_child(UI.image(UI.tex.guide_luzon, Vector2(90, 90)))
	var intro := UI.label("Maelor: Tap a topic to read about it. Your Guiding Spirits are always here to help!", 20, UI.INK, true)
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(intro)
	content.add_child(head)
	for topic in GuidePages.GUIDE_TOPICS:
		var key: String = topic[1]
		var row := UI.row_panel()
		row.name = "topic_" + key
		var h := UI.hbox(12)
		row.add_child(h)
		var pages := GuidePages.pages_for(key)
		h.add_child(UI.image(UI.tex.get(pages[0].get("image", "guide_luzon")), Vector2(56, 56)))
		var info := UI.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UI.label(topic[0], 24, UI.INK, true, UI.font_body_black))
		info.add_child(UI.label("%d page%s" % [pages.size(), "" if pages.size() == 1 else "s"], 15, UI.INK_SOFT))
		h.add_child(info)
		UI.clickable(row, func(): GuidePages.show(self, GuidePages.pages_for(key)))
		content.add_child(row)

	content.add_child(UI.heading("Rewards", UI.RED, 24))
	content.add_child(UI.reward_guide())
	var replay := UI.pill_button("REPLAY TUTORIAL", Color("6b3fa0"), func():
		Tutorial.start_for_player()
		Game.goto("map"), 56, 20)
	replay.name = "replay_tour"
	content.add_child(replay)
	var reset := UI.pill_button("SHOW ALL TIPS AGAIN", UI.GREEN, func():
		DB.reset_tutorials(Game.user_id())
		DB.mark_tutorial_seen(Game.user_id(), "welcome")
		UI.toast("Tips will show again on each screen."), 56, 20)
	reset.name = "reset_tips"
	content.add_child(reset)
