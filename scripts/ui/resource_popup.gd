class_name ResourcePopup
extends RefCounted
## "Not enough ..." reminder shown when the player taps UNLOCK without enough
## Word Fragments (languages) or Phrase Crystals (culture items).
## Nothing is spent here: the popup only explains what is missing.

const TEXT := {
	"word_fragment": {
		"title": ["Kulang ang Word Fragments!", "Not enough Word Fragments!"],
		"body": ["Kailangan mo pa ng Word Fragments para mabuksan ang wikang ito.",
			"You need more Word Fragments to unlock this language."],
		"earn": ["Tapusin ang mga aralin at pumasa sa mga pagsusulit na Madali (Easy) para makaipon pa.",
			"Complete lessons and pass Easy quizzes to earn more."],
	},
	"phrase_crystal": {
		"title": ["Kulang ang Phrase Crystals!", "Not enough Phrase Crystals!"],
		"body": ["Kailangan mo pa ng Phrase Crystals para mabuksan ang kulturang ito.",
			"You need more Phrase Crystals to unlock this cultural content."],
		"earn": ["Pumasa sa mga pagsusulit na Katamtaman (Medium) at Grammar para makaipon pa.",
			"Pass Medium and Grammar quizzes to earn more."],
	},
}


## True (and nothing shown) if the player can pay [param cost]; otherwise shows
## the reminder for the first reward they are short of and returns false.
static func check(parent: Control, cost: Dictionary, item_name: String) -> bool:
	var uid := Game.user_id()
	if DB.can_afford(uid, cost):
		return true
	var have := DB.get_rewards(uid)
	for kind in cost:
		if int(have.get(kind, 0)) < int(cost[kind]):
			show(parent, kind, int(have.get(kind, 0)), int(cost[kind]), item_name)
			break
	return false


static func show(parent: Control, kind: String, have: int, need: int, item_name: String) -> Control:
	var words: Dictionary = TEXT.get(kind, TEXT.word_fragment)
	var color: Color = UI.REWARD_COLORS.get(kind, UI.GOLD)
	Sound.play("wrong")

	var overlay := ColorRect.new()
	overlay.name = "ResourcePopup"
	overlay.color = Color(0, 0, 0, 0.62)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)
	Game.overlays.append(overlay)
	var close := func():
		Game.overlays.erase(overlay)
		if is_instance_valid(overlay):
			overlay.queue_free()

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	# Parchment card with a thick gold border (same look as the tutorial pop-up).
	var card := PanelContainer.new()
	var sb := UI._box(UI.PARCHMENT, 20, UI.GOLD, 6, 26)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	card.add_theme_stylebox_override("panel", sb)
	var width := minf(600.0, parent.get_viewport_rect().size.x - 32.0)
	card.custom_minimum_size = Vector2(maxf(width, 300.0), 0)
	center.add_child(card)

	var v := UI.vbox(12)
	card.add_child(v)

	# Close (X) in the top-right corner.
	var top := UI.hbox(0)
	v.add_child(top)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var x := UI.pill_button("X", UI.RED, close, 48, 22)
	x.name = "close"
	x.custom_minimum_size.x = 48
	x.tooltip_text = UI.tx("Isara", "Close")
	top.add_child(x)

	var icon := RewardIcon.make(kind, 104)
	icon.name = "icon"
	v.add_child(icon)
	var title := UI.label(UI.tx(words.title[0], words.title[1]), 30, UI.RED, true, UI.font_body_black)
	title.name = "title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	if item_name != "":
		var target := UI.label(UI.tx("Bubuksan: %s", "To unlock: %s") % item_name, 20, UI.INK_SOFT, true, UI.font_body_black)
		target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(target)

	# Balance vs. cost, side by side.
	var boxes := UI.hbox(10)
	boxes.name = "balance"
	v.add_child(boxes)
	boxes.add_child(_stat_box(UI.tx("Mayroon ka", "You have"), have, UI.RED if have < need else UI.GREEN, kind))
	boxes.add_child(_stat_box(UI.tx("Kailangan", "Required"), need, color, kind))

	var bar := ProgressBar.new()
	bar.name = "progress"
	bar.max_value = need
	bar.value = mini(have, need)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 18)
	bar.add_theme_stylebox_override("background", UI._box(Color("e4d3ab"), 9, Color("8a5a2b"), 2, 0))
	bar.add_theme_stylebox_override("fill", UI._box(color, 9))
	v.add_child(bar)
	var short := UI.label(UI.tx("Kulang pa ng %d %s", "%d more %s needed") % [need - have, DB.REWARD_NAMES[kind]],
		19, UI.INK, true, UI.font_body_black)
	short.name = "short"
	short.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(short)

	var body := UI.label("%s %s" % [UI.tx(words.body[0], words.body[1]), UI.tx(words.earn[0], words.earn[1])], 20, UI.INK, true)
	body.name = "message"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(body)

	var row := UI.hbox(10)
	v.add_child(row)
	var cancel := UI.pill_button(UI.tx("KANSELAHIN", "CANCEL"), Color("8d8170"), close, 60, 22)
	cancel.name = "cancel"
	var ok := UI.pill_button("OK", UI.GREEN, close, 60, 22)
	ok.name = "ok"
	for b in [cancel, ok]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)

	# Little pop-in so it feels like a game dialog.
	card.pivot_offset = card.custom_minimum_size / 2.0
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var tw := card.create_tween().set_parallel()
	tw.tween_property(card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.12)
	return overlay


static func _stat_box(caption: String, amount: int, amount_color: Color, kind: String) -> PanelContainer:
	var p := UI.panel(UI.CARD, Color("c9a76b"))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(2)
	p.add_child(v)
	var cap := UI.label(caption, 17, UI.INK_SOFT, true, UI.font_body_black)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cap)
	var h := UI.hbox(6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	h.add_child(RewardIcon.make(kind, 34))
	var n := UI.label(str(amount), 34, amount_color, false, UI.font_button)
	n.name = "amount"
	h.add_child(n)
	return p
