extends Control
## How to play (GABAY): every tutorial topic, readable any time.


func _ready() -> void:
	var content := UI.page(self, "Gabay" if UI.lang == "fil" else "Guide", Game.BACK)
	var head := UI.hbox(12)
	head.add_child(UI.image(UI.tex.guide_luzon, Vector2(90, 90)))
	var intro := UI.label(UI.tx("Maelor: Pindutin ang isang paksa para basahin ito. Laging narito ang iyong mga Gabay na Espiritu para tumulong!",
		"Maelor: Tap a topic to read about it. Your Guiding Spirits are always here to help!"), 20, UI.INK, true)
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(intro)
	content.add_child(head)

	# Getting Started checklist: what to do next, in order.
	var steps := DB.getting_started(Game.user_id())
	var done := steps.filter(func(st): return st[1]).size()
	content.add_child(UI.heading(UI.tx("Pagsisimula", "Getting started"), UI.RED, 24))
	var check := UI.panel(Color("fffaf0"))
	check.name = "checklist"
	var cv := UI.vbox(6)
	check.add_child(cv)
	var bar := ProgressBar.new()
	bar.max_value = steps.size()
	bar.value = done
	bar.show_percentage = false
	bar.custom_minimum_size.y = 18
	cv.add_child(bar)
	cv.add_child(UI.label(UI.tx("%d sa %d ang tapos na", "%d of %d done") % [done, steps.size()], 17, UI.INK_SOFT, false, UI.font_body_black))
	var next_marked := false
	for st in steps:
		var is_next: bool = not st[1] and not next_marked
		next_marked = next_marked or is_next
		var step_name: String = st[2] if UI.lang == "fil" else st[0]
		var l := UI.label(("✔  " if st[1] else ("➜  " if is_next else "○  ")) + step_name
			+ (UI.tx("   (gawin ito susunod)", "   (do this next)") if is_next else ""),
			19, UI.GREEN if st[1] else (UI.RED if is_next else UI.INK), true, UI.font_body_black if is_next else null)
		cv.add_child(l)
	content.add_child(check)

	content.add_child(UI.heading(UI.tx("Mga paksa ng gabay", "Guide topics"), UI.RED, 24))
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
		info.add_child(UI.label(topic[2] if UI.lang == "fil" else topic[0], 24, UI.INK, true, UI.font_body_black))
		info.add_child(UI.label(UI.tx("%d pahina" % pages.size(), "%d page%s" % [pages.size(), "" if pages.size() == 1 else "s"]), 15, UI.INK_SOFT))
		h.add_child(info)
		UI.clickable(row, func(): GuidePages.show(self, GuidePages.pages_for(key)))
		content.add_child(row)

	content.add_child(UI.heading(UI.tx("Mga gantimpala", "Rewards"), UI.RED, 24))
	content.add_child(UI.reward_guide())
	var replay := UI.pill_button(UI.tx("ULITIN ANG TUTORIAL", "REPLAY TUTORIAL"), Color("6b3fa0"), func():
		Tutorial.start_for_player()
		Game.goto("map"), 56, 20)
	replay.name = "replay_tour"
	content.add_child(replay)
	var reset := UI.pill_button(UI.tx("IPAKITA MULI ANG MGA TIP", "SHOW ALL TIPS AGAIN"), UI.GREEN, func():
		DB.reset_tutorials(Game.user_id())
		DB.mark_tutorial_seen(Game.user_id(), "welcome")
		UI.toast(UI.tx("Lalabas muli ang mga tip sa bawat screen.", "Tips will show again on each screen.")), 56, 20)
	reset.name = "reset_tips"
	content.add_child(reset)
