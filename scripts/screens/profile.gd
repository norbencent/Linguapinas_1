extends Control
## Player profile (prototype profile screen).


func _ready() -> void:
	Game.refresh_user()
	var uid := Game.user_id()
	var content := UI.page(self, UI.t("profile"), Game.BACK)
	var last := DB.get_last_language(uid)
	var region: String = last.get("region_code", Game.region_code if Game.region_code != "" else "luzon")

	var portrait := PanelContainer.new()
	var sb := UI._box(Color("fffaf0"), 120, Color("c99a2e"), 8, 8)
	portrait.add_theme_stylebox_override("panel", sb)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var face := UI.image(UI.character_texture(region, Game.user.get("avatar", "boy")), Vector2(210, 210))
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.add_child(face)
	content.add_child(portrait)

	var rewards := DB.get_rewards(uid)
	var secs := int(Game.user.get("playtime", 0))
	var lines := [
		["Name", Game.user.display_name],
		["Island", DB.get_region(region).get("name", "-")],
		["Language", last.get("name", "-")],
		["Fragment", str(rewards.word_fragment)],
		["Crystal", str(rewards.phrase_crystal)],
		["Relics", str(rewards.cultural_relic)],
		["Badge", str(DB.get_badges(uid).size())],
		["Score", str(DB.get_total_score(uid))],
		["Playtime", "%d:%02d" % [secs / 3600, (secs / 60) % 60]],
	]
	var card := UI.panel(Color("fdf6e3"), Color("c99a2e"))
	var v := UI.vbox(6)
	card.add_child(v)
	for l in lines:
		v.add_child(UI.label("%s: %s" % [l[0], l[1]], 24, Color("8b1a1a"), true, UI.font_body_black))
	content.add_child(card)

	_add_progress(content, uid)

	content.add_child(UI.heading("Rewards", UI.RED, 24))
	content.add_child(UI.wallet(uid))
	content.add_child(UI.reward_guide())
	var culture_count := DB.get_unlocked_culture(uid).size()
	content.add_child(UI.label("Culture collected: %d / %d" % [culture_count, DB.get_culture_items().size()], 20, UI.INK, true, UI.font_body_black))

	content.add_child(UI.gem_button(UI.t("gallery").to_upper(), "gold", func(): Game.goto("gallery"), 84, 30))
	content.add_child(UI.gem_button(UI.t("setting"), "blue", func(): Game.open_settings("profile"), 84, 30))
	content.add_child(UI.gem_button(UI.t("logout"), "red", Game.logout, 84, 30))
	GuidePages.maybe_show(self, "profile")


const LEVEL_COLORS := {1: UI.GREEN, 2: UI.BLUE, 3: UI.RED}
const LEVEL_SHORT := {1: "EASY", 2: "MEDIUM", 3: "HARD"}


## My Progress: overall, island pearls, every language level by level with
## best scores, the Grammar quiz, the Getting Started checklist and the
## last quizzes.
func _add_progress(content: VBoxContainer, uid: int) -> void:
	var fil := UI.lang == "fil"
	content.add_child(UI.heading("Aking Progreso" if fil else "My Progress", UI.RED, 26))
	var box := UI.vbox(10)
	box.name = "progress"
	content.add_child(box)

	# Overall
	var totals := DB.get_level_totals(uid)
	var overall := UI.panel(Color("fffaf0"))
	var ov := UI.vbox(6)
	overall.add_child(ov)
	var pct := int(round(100.0 * totals.passed / maxi(1, totals.total)))
	var head := UI.label("%s: %d / %d (%d%%)" % ["Mga antas na naipasa" if fil else "Levels passed", totals.passed, totals.total, pct],
		22, UI.INK, true, UI.font_body_black)
	head.name = "levels_passed"
	ov.add_child(head)
	ov.add_child(_bar(totals.passed, totals.total, UI.GREEN))
	var steps := DB.getting_started(uid)
	var done := steps.filter(func(st): return st[1]).size()
	ov.add_child(UI.label("%s: %d / %d" % ["Getting Started checklist", done, steps.size()], 17, UI.INK_SOFT, true))
	box.add_child(overall)

	# Island pearls
	var pearls := UI.panel(Color("fffaf0"))
	var pv := UI.vbox(6)
	pearls.add_child(pv)
	pv.add_child(UI.label("Island pearls" if not fil else "Mga perlas ng isla", 20, UI.RED, true, UI.font_body_black))
	for region in DB.get_regions():
		var pp := DB.get_pearl_progress(uid, region.code)
		var lit := DB.is_core_restored(uid, region.code)
		var row := UI.hbox(8)
		row.add_child(PearlOrb.make(UI.REGION_COLORS[region.code], lit, 26))
		var l := UI.label("%s: %d / %d %s%s" % [region.name, pp.mastered, pp.total, "mastered" if not fil else "na-master",
			("  · LIT" if not fil else "  · NAKASINDI") if lit else ""], 17, UI.INK, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		pv.add_child(row)
		pv.add_child(_bar(pp.mastered, pp.total, UI.REGION_COLORS[region.code]))
	box.add_child(pearls)

	# Every language, by island
	for region in DB.get_regions():
		box.add_child(UI.ribbon(region.name, UI.REGION_COLORS[region.code]))
		for lang in DB.get_languages(region.code):
			if int(lang.playable) != 1:
				continue
			box.add_child(_language_row(uid, lang, fil))

	# Last quizzes
	var recent := DB.get_recent_attempts(uid, 5)
	box.add_child(UI.label("Mga huling pagsusulit" if fil else "Last quizzes", 20, UI.RED, true, UI.font_body_black))
	if recent.is_empty():
		box.add_child(UI.label("Wala pa. Kumuha ng pagsusulit!" if fil else "None yet. Take a quiz!", 17, UI.INK_SOFT, true))
	for a in recent:
		var kind: String = "Grammar" if a.category_code == "grammar" else DB.DIFFICULTY_NAMES.get(int(a.difficulty), "")
		var line := "%s %s · %d pts · %d/%d · %s" % [a.language_name, kind, int(a.score), int(a.correct), int(a.total),
			("PASSED" if not fil else "PUMASA") if int(a.passed) == 1 else ("not passed" if not fil else "hindi pumasa")]
		box.add_child(UI.label("• " + line, 16, UI.GREEN if int(a.passed) == 1 else UI.INK_SOFT, true))


func _language_row(uid: int, lang: Dictionary, fil: bool) -> Control:
	var row := UI.row_panel()
	row.name = "progress_" + str(lang.code)
	var v := UI.vbox(4)
	row.add_child(v)
	var p := DB.get_progress(uid, lang.code)
	var unlocked := DB.is_language_unlocked(uid, lang.code)
	var passed := [1, 2, 3].filter(func(d): return p[d].completed).size()
	var top := UI.hbox(8)
	var title := UI.label(lang.name, 21, UI.INK, true, UI.font_body_black)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var status := ""
	if not unlocked:
		status = ("NAKA-LOCK · %s" if fil else "LOCKED · %s") % DB.cost_text(DB.LANGUAGE_COST)
	elif passed == 3:
		status = "NA-MASTER ✔" if fil else "MASTERED ✔"
	else:
		status = "%d / 3" % passed
	top.add_child(UI.label(status, 16, UI.GREEN if passed == 3 else (UI.RED if not unlocked else UI.INK_SOFT), false, UI.font_body_black))
	v.add_child(top)
	if not unlocked:
		return row
	var levels := HFlowContainer.new()
	levels.add_theme_constant_override("h_separation", 6)
	levels.add_theme_constant_override("v_separation", 6)
	for d in [1, 2, 3]:
		var text: String = LEVEL_SHORT[d]
		var color: Color = LEVEL_COLORS[d]
		if p[d].completed:
			text += " ✔ %d" % p[d].best_score
		elif d == 1 or p[d - 1].completed:
			text += " · " + ("susunod" if fil else "next")
			color = UI.INK_SOFT
		else:
			text += " · " + ("naka-lock" if fil else "locked")
			color = UI.LOCKED
		levels.add_child(UI.pill(text, color, 15))
	var g := DB.get_grammar_progress(uid, lang.code)
	var gtext := "GRAMMAR"
	var gcolor := Color("7d3fa8")
	if g.passed:
		gtext += " ✔ %d" % g.best_score
	elif p[1].completed:
		gtext += " · " + ("bukas na" if fil else "open")
		gcolor = UI.INK_SOFT
	else:
		gtext += " · " + ("naka-lock" if fil else "locked")
		gcolor = UI.LOCKED
	levels.add_child(UI.pill(gtext, gcolor, 15))
	v.add_child(levels)
	var lesson: bool = p[1].lesson_done or p[2].lesson_done or p[3].lesson_done
	v.add_child(UI.label(("Aralin: " if fil else "Lessons studied: ") + ", ".join([1, 2, 3].filter(func(d): return p[d].lesson_done)
		.map(func(d): return DB.DIFFICULTY_NAMES[d])) if lesson else ("Hindi pa nag-aaral ng aralin" if fil else "No lesson studied yet"),
		14, UI.INK_SOFT, true))
	return row


func _bar(value: int, total: int, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = maxi(1, total)
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size.y = 16
	bar.add_theme_stylebox_override("fill", UI._box(color, 8, Color.TRANSPARENT, 0, 0))
	return bar
