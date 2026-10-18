extends Node
## Headless integration test for LinguaPinas.
## Run:  godot --headless --path . res://tests/test_runner.tscn
## Uses a separate database file so real player data is untouched.

const TEST_DB := "user://linguapinas_test.db"

var failures := 0
var checks := 0


func _ready() -> void:
	if has_meta("is_runner"):
		_run.call_deferred()
		return
	# Run from a copy attached to the root so the game's scene changes
	# (which replace this scene) don't free the test.
	var runner := Node.new()
	runner.set_meta("is_runner", true)
	runner.set_script(get_script())
	get_tree().root.add_child.call_deferred(runner)


func check(condition: bool, what: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", what)


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DB))
	check(DB.open(TEST_DB), "database opens")
	_test_seed()
	_test_accounts()
	_test_quiz_generation()
	_test_progression()
	await _test_spirit()
	await _test_screens()
	await _test_back_navigation()
	await _test_back_button_clicks()
	await _test_delete_player()
	await _test_battle_stage()
	await _test_culture()
	await _test_reward_economy()
	_test_pronunciation_and_grammar()
	await _test_new_screens()
	await _test_play_quiz_through_ui()
	DB.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DB))
	print("%d checks, %d failures" % [checks, failures])
	print("ALL TESTS PASSED" if failures == 0 else "TESTS FAILED")
	get_tree().quit(1 if failures > 0 else 0)
	queue_free()


func _test_seed() -> void:
	check(DB.get_regions().size() == 3, "3 regions")
	var total := 0
	for r in DB.get_regions():
		var langs := DB.get_languages(r.code)
		check(langs.size() == 10, "10 languages in %s" % r.code)
		total += langs.size()
	check(total == 30, "30 languages")
	check(DB.get_playable_languages().size() == 10, "10 playable languages")
	check(DB.get_culture_items().size() > 10, "culture items seeded")
	check(DB.get_stories().size() == 4, "4 stories")
	# Re-opening must not duplicate content.
	var words_before := DB.get_words("tl").size()
	DB.open(TEST_DB)
	check(DB.get_words("tl").size() == words_before, "re-open does not duplicate words")


func _test_accounts() -> void:
	var r := DB.register_user("juan", "secret1", "Juan")
	check(r.ok, "register juan")
	check(not DB.register_user("JUAN", "x12345").ok, "usernames are case-insensitive unique")
	check(not DB.register_user("a", "secret1").ok, "short name rejected")
	check(not DB.register_user("bad!name", "secret1").ok, "name with symbols rejected")
	check(not DB.register_user("maria", "123").ok, "short password rejected")
	var guest := DB.register_user("Ana  Dela Cruz", "", "", "girl")
	check(guest.ok and guest.user.username == "Ana Dela Cruz", "name with spaces, no password")
	check(guest.ok and guest.user.avatar == "girl" and int(guest.user.has_password) == 0, "avatar and passwordless flag")
	check(DB.login_user("ana dela cruz", "").ok, "passwordless login")
	check(not DB.login_user("juan", "").ok, "password required when set")
	check(DB.get_users().size() == 2, "saved player list")
	check(DB.login_user("juan", "secret1").ok, "login ok")
	check(not DB.login_user("juan", "wrong").ok, "wrong password rejected")
	check(not DB.login_user("nobody", "secret1").ok, "unknown user rejected")
	check(DB.register_user("maria", "secret2", "Maria").ok, "register maria")


func _test_quiz_generation() -> void:
	for lang in DB.get_playable_languages():
		for d in [1, 2, 3]:
			var qs := Game.build_quiz(lang.code, d)
			check(qs.size() >= 4, "%s difficulty %d has questions (%d)" % [lang.code, d, qs.size()])
			check(qs.size() <= Game.QUESTIONS_PER_QUIZ, "quiz length capped")
			for q in qs:
				check(Game.check_answer(q, q.answer), "%s answer accepted: %s" % [lang.code, q.prompt])
				match q.type:
					"choice":
						check(q.answer in q.options, "answer among options: %s" % q.prompt)
						check(q.options.size() >= 2, "at least 2 options: %s" % q.prompt)
					"build":
						for t in q.answer.split(" ", false):
							check(t in q.tokens, "tile present for %s" % t)
		for c in DB.get_categories(lang.code):
			check(Game.build_quiz(lang.code, 1, c.code).size() > 0, "%s category %s quiz" % [lang.code, c.code])
	check(Game.check_answer({"type": "typed", "answer": "Ina'"}, "  ina "), "typed answers are lenient")


func _test_progression() -> void:
	var uid: int = DB.login_user("juan", "secret1").user.id
	check(not DB.is_difficulty_unlocked(uid, "tl", 2), "medium locked at start")
	DB.record_quiz(uid, "tl", 1, "", 50, 5, 10, 0, false)
	check(not DB.is_difficulty_unlocked(uid, "tl", 2), "failed quiz does not unlock")
	DB.record_quiz(uid, "tl", 1, "numbers", 80, 3, 3, 5, true)
	check(not DB.is_difficulty_unlocked(uid, "tl", 2), "category practice does not unlock")
	DB.record_quiz(uid, "tl", 1, "", 120, 9, 10, 4, true)
	check(DB.is_difficulty_unlocked(uid, "tl", 2), "medium unlocked after easy")
	DB.record_quiz(uid, "tl", 1, "", 90, 8, 10, 3, true)
	check(DB.get_progress(uid, "tl")[1].best_score == 120, "best score kept")
	DB.record_quiz(uid, "tl", 2, "", 200, 9, 10, 4, true)
	var s := DB.record_quiz(uid, "tl", 3, "", 300, 9, 10, 4, true)
	check("core_luzon" in s.new_badges, "luzon core restored")
	check(DB.get_restored_cores(uid) == ["luzon"], "only luzon restored")
	DB.record_quiz(uid, "ceb", 1, "", 100, 9, 10, 4, true)
	DB.record_quiz(uid, "ceb", 2, "", 100, 9, 10, 4, true)
	DB.record_quiz(uid, "ceb", 3, "", 100, 9, 10, 4, true)
	DB.record_quiz(uid, "cbk", 1, "", 100, 9, 10, 4, true)
	DB.record_quiz(uid, "cbk", 2, "", 100, 9, 10, 4, true)
	s = DB.record_quiz(uid, "cbk", 3, "", 100, 9, 10, 4, true)
	check("core_mindanao" in s.new_badges and "pearl" in s.new_badges, "pearl unlocked")
	check(DB.get_badges(uid).size() == 4, "4 badges")
	var rewards := DB.get_rewards(uid)
	# First clears pay in full; category practice (3 -> 2) and replays (8 -> 4) pay half.
	check(rewards.word_fragment == 2 + 9 + 4 + 9 + 9, "word fragments counted (%d)" % rewards.word_fragment)
	var maria: int = DB.login_user("maria", "secret2").user.id
	DB.record_quiz(maria, "hil", 1, "", 150, 10, 10, 5, true)
	var board := DB.get_leaderboard()
	check(board.size() == 2 and board[0].display_name == "Juan", "leaderboard ordered")
	DB.add_playtime(uid, 125)
	check(int(DB.get_user(uid).playtime) == 125, "playtime saved")
	check(DB.get_last_language(uid).code == "cbk", "last language")
	check(int(board[0].total_score) == 120 + 200 + 300 + 600, "juan total score")
	var visayas := DB.get_leaderboard(20, "visayas")
	check(visayas.size() == 2 and int(visayas[0].total_score) == 300, "region leaderboard")


func _test_spirit() -> void:
	var r: Dictionary = await Spirit.translate("tl", "salamat", "to_english")
	check(r.source == "dictionary" and r.text == "Thank you", "dictionary translation")
	r = await Spirit.translate("ceb", "Thank you very much", "from_english")
	check(r.text == "Daghang salamat.", "english -> cebuano sentence")
	r = await Spirit.translate("tl", "tubig isda", "to_english")
	check(r.source in ["gloss", "marian"], "unknown phrase falls back (%s)" % r.source)
	if r.source == "gloss":
		check(r.text == "Water Fish", "gloss text (%s)" % r.text)


func _frames(n := 3) -> void:
	for i in n:
		await get_tree().process_frame


func _test_screens() -> void:
	Game.user = DB.login_user("juan", "secret1").user
	Game.region_code = "visayas"
	Game.language_code = "tl"
	Game.difficulty = 2
	Game.last_result = {"passed": true, "score": 100, "correct": 8, "total": 10, "hearts": 3,
		"summary": {"new_badges": ["core_luzon"], "reward_kind": "phrase_crystal", "reward_amount": 8, "counts": true}}
	for screen in Game.SCENES:
		Game.goto(screen)
		await _frames()
		var current := get_tree().current_scene
		check(current != null and current.scene_file_path == Game.SCENES[screen], "screen %s loads" % screen)
		check(current != null and current.get_child_count() > 0, "screen %s builds its UI" % screen)


func _scene_is(screen: String) -> bool:
	var cur := get_tree().current_scene
	return cur != null and cur.scene_file_path == Game.SCENES[screen]


func _test_back_navigation() -> void:
	# Every screen except the title has a back target, and pressing it
	# (back button, Esc or Android back all call handle_back) opens a screen.
	for screen in Game.SCENES:
		Game.history.clear()
		Game.goto(screen)
		await _frames()
		if screen == "title":
			check(Game.back_action == null, "title has no back target")
			continue
		check(Game.back_action != null, "screen %s has a back button" % screen)
		Game.handle_back()
		await _frames()
		var cur := get_tree().current_scene
		check(cur != null and cur.scene_file_path != Game.SCENES[screen] or screen == "map",
			"back from %s leaves the screen" % screen)
	# Fixed targets along the learning path.
	var expected := {"menu": "title", "new_game": "menu", "continue": "menu", "map": "menu",
		"island": "map", "language": "island", "difficulty": "language", "lesson": "difficulty",
		"quiz": "difficulty", "results": "difficulty"}
	for screen in expected:
		Game.goto(screen)
		await _frames()
		Game.handle_back()
		await _frames()
		check(_scene_is(expected[screen]), "back from %s goes to %s" % [screen, expected[screen]])
	# Shared screens return to wherever they were opened from.
	Game.goto("results")
	await _frames()
	Game.goto("leaderboard")
	await _frames()
	Game.goto("profile")
	await _frames()
	Game.goto("gallery")
	await _frames()
	for want in ["profile", "leaderboard", "results"]:
		Game.handle_back()
		await _frames()
		check(_scene_is(want), "history back reaches %s" % want)
	# Settings goes back to where it was opened.
	Game.goto("island")
	await _frames()
	Game.open_settings("island")
	await _frames()
	Game.handle_back()
	await _frames()
	check(_scene_is("island"), "settings back returns to island")
	# The back key closes a pop-up before leaving the screen.
	Game.region_code = "luzon"
	Game.goto("language")
	await _frames()
	get_tree().current_scene._show_map("luzon")
	await _frames()
	Game.handle_back()
	await _frames()
	check(_scene_is("language") and Game.overlays.is_empty(), "back closes the map pop-up first")
	# The island map previews a region's language map on hover.
	Game.goto("map")
	await _frames()
	var map := get_tree().current_scene
	map.find_child("visayas", true, false).mouse_entered.emit()
	await _frames()
	check(map._preview.visible and map._preview_map.texture == UI.tex.lang_map_visayas, "hover shows the Visayas map")
	map.find_child("visayas", true, false).mouse_exited.emit()
	await _frames(20)
	check(not map._preview.visible, "preview hides after hover ends")


## Clicks a control like a player would (mouse press + release at its centre).
func _click(c: Control) -> void:
	# Scroll the control into view first, like a player would.
	var p := c.get_parent()
	while p != null and not p is ScrollContainer:
		p = p.get_parent()
	if p is ScrollContainer:
		p.ensure_control_visible(c)
		await _frames(2)
	var pos := c.get_global_rect().get_center()
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		get_viewport().push_input(e, true)
		await _frames(1)


func _back_button() -> TextureButton:
	for n in get_tree().current_scene.find_children("*", "TextureButton", true, false):
		if n.texture_normal == UI.tex.back:
			return n
	return null


func _test_back_button_clicks() -> void:
	# The on-screen back button must actually receive the click on every
	# screen that has one (a full-screen container on top would block it).
	var expected := {"menu": "title", "new_game": "menu", "continue": "menu", "settings": "map",
		"map": "menu", "island": "map", "language": "island", "difficulty": "language",
		"gallery": "map", "profile": "map", "leaderboard": "map", "stories": "map", "spirit": "map"}
	Game.region_code = "luzon"
	Game.language_code = "tl"
	Game.difficulty = 1
	for screen in expected:
		Game.history.clear()
		Game.goto("map")
		await _frames()
		if screen == "settings":
			Game.open_settings("map")
		else:
			Game.goto(screen)
		await _frames(4)
		var b := _back_button()
		check(b != null, "%s shows a back button" % screen)
		if b == null:
			continue
		await _click(b)
		await _frames(3)
		check(_scene_is(expected[screen]), "clicking back on %s opens %s" % [screen, expected[screen]])


func _row(uid: int) -> Node:
	return get_tree().current_scene.find_child("player_%d" % uid, true, false)


func _test_delete_player() -> void:
	var sample := DB.register_user("Sample Player", "").user.id as int
	var locked := DB.register_user("Locked Player", "pass1234").user.id as int
	DB.add_reward(sample, "word_fragment", 5)
	DB.record_quiz(sample, "tl", 1, "", 100, 10, 10, 5, true)
	Game.user = {}
	Game.goto("continue")
	await _frames(4)
	check(_row(sample) != null and _row(locked) != null, "continue lists the sample players")

	# One tap on DELETE removes the player straight away.
	await _click(_row(sample).find_child("delete", true, false))
	await _frames(3)
	check(DB.get_user(sample).is_empty(), "sample player deleted")
	for table in ["quiz_attempts", "progress", "rewards", "badges"]:
		var left: int = DB._select("SELECT COUNT(*) AS n FROM %s WHERE user_id = ?;" % table, [sample])[0].n
		check(left == 0, "deleted player's %s removed" % table)
	check(_row(sample) == null, "deleted player leaves the list")

	# No password is asked, even for a player who has one.
	await _click(_row(locked).find_child("delete", true, false))
	await _frames(3)
	check(DB.get_user(locked).is_empty(), "player with a password deleted without it")
	check(_row(locked) == null, "list refreshed")
	check(not DB.delete_user(locked), "deleting a missing player fails cleanly")


func _test_battle_stage() -> void:
	# Every language (playable or not) gets an animated warrior at each level.
	for region in DB.get_regions():
		for lang in DB.get_languages(region.code):
			for level in [1, 2, 3]:
				var st := BattleStage.new()
				add_child(st)
				st.setup(lang.code, level, region.code, "girl")
				var sf := st.enemy.sprite_frames
				check(sf != null and sf.get_frame_count("idle") >= 3 and sf.get_frame_count("attack") >= 3,
					"%s level %d has warrior animations" % [lang.code, level])
				st.queue_free()
	# The quiz shows the duel and reacts to answers.
	Game.user = DB.login_user("juan", "secret1").user
	Game.language_code = "ceb"
	Game.difficulty = 2
	Game.category_code = ""
	Game.goto("quiz")
	await _frames(3)
	var quiz := get_tree().current_scene
	check(quiz.stage != null and quiz.stage.enemy_code == "ceb", "quiz shows the Cebuano warrior")
	quiz._answer(quiz.questions[0].answer)
	await get_tree().create_timer(0.25).timeout
	check(quiz.stage.enemy.animation == "hurt", "right answer hurts the warrior")
	quiz._next()
	await _frames(2)
	quiz._answer("definitely wrong")
	await _frames(2)
	check(quiz.stage.enemy.animation == "attack", "wrong answer makes the warrior attack")


func _test_culture() -> void:
	var items := DB.get_culture_items()
	check(items.size() >= 40 and items.all(func(c): return c.kind != "Landmark"), "culture items seeded without landmarks (%d)" % items.size())
	for region in DB.get_regions():
		for lang in DB.get_languages(region.code):
			check(items.any(func(c): return c.language_code == lang.code), "%s has a culture item" % lang.code)
	for c in items:
		check(ResourceLoader.exists("res://assets/culture/%s.png" % c.image), "%s has a picture" % c.title)
	check(Game.hide_name("Sisig comes from Pampanga.", "Sisig") == "_____ comes from Pampanga.", "culture name hidden")
	# Full quizzes include culture questions; category practice does not.
	for d in [1, 2, 3]:
		var qs := Game.build_quiz("war", d)
		var culture := qs.filter(func(q): return q.kind == "Culture")
		check(culture.size() == Game.CULTURE_QUESTIONS[d], "level %d has %d culture questions" % [d, Game.CULTURE_QUESTIONS[d]])
		check(qs.size() <= Game.QUESTIONS_PER_QUIZ, "level %d quiz size" % d)
		for q in culture:
			check(q.answer in q.options and q.options.size() == 4, "culture question has 4 options with the answer")
			check(not q.answer.to_lower() in q.detail.to_lower(), "culture description hides the answer")
	check(Game.build_quiz("tl", 1, "food").all(func(q): return q.kind != "Culture"), "category practice has no culture questions")
	# The gallery shows pictures once a region is unlocked.
	Game.user = DB.login_user("juan", "secret1").user
	Game.region_code = "visayas"
	Game.goto("gallery")
	await _frames(3)
	var pics := get_tree().current_scene.find_children("*", "TextureRect", true, false).filter(
		func(t): return t.texture != null and t.texture.resource_path.begins_with("res://assets/culture/"))
	check(pics.size() == DB.get_culture_items("visayas").size(), "gallery shows a picture for every Visayas item")


func _test_reward_economy() -> void:
	var uid := DB.register_user("shopper", "").user.id as int
	check(DB.is_language_unlocked(uid, "tl") and DB.is_language_unlocked(uid, "ceb") and DB.is_language_unlocked(uid, "bis"),
		"first language of each island is free")
	check(not DB.is_language_unlocked(uid, "ilo"), "other languages start locked")
	check(not DB.unlock_language(uid, "ilo").ok, "cannot unlock without fragments")
	# A first clear pays in full and reveals a culture item; a replay pays half and reveals nothing.
	var s := DB.record_quiz(uid, "tl", 1, "", 100, 10, 10, 5, true)
	check(s.first_clear and s.reward_amount == 10, "first clear pays 10 fragments")
	check(not s.revealed.is_empty() and s.revealed.language_code == "tl" and DB.is_culture_unlocked(uid, s.revealed.title),
		"first clear reveals a Tagalog culture item")
	s = DB.record_quiz(uid, "tl", 1, "", 100, 10, 10, 5, true)
	check(not s.first_clear and s.reward_amount == 5 and s.revealed.is_empty(), "replay pays half, no reveal")
	s = DB.record_quiz(uid, "tl", 1, "", 100, 10, 10, 5, true)
	check(DB.get_rewards(uid).word_fragment == 20, "20 fragments collected")
	check(DB.unlock_language(uid, "ilo").ok and DB.is_language_unlocked(uid, "ilo"), "Ilocano bought")
	check(DB.get_rewards(uid).word_fragment == 0, "fragments spent")
	check(not DB.unlock_language(uid, "pag").ok, "coming-soon languages can't be bought")
	# Culture with crystals, hints with relics.
	var locked := DB.get_culture_items().filter(func(c): return not DB.is_culture_unlocked(uid, c.title))
	check(not DB.unlock_culture(uid, locked[0].title).ok, "culture needs crystals")
	DB.add_reward(uid, "phrase_crystal", 5)
	check(DB.unlock_culture(uid, locked[0].title).ok and DB.get_rewards(uid).phrase_crystal == 0, "culture bought with 5 crystals")
	check(not DB.spend(uid, DB.HINT_COST), "no relic, no extra hint")
	DB.add_reward(uid, "cultural_relic", 1)
	check(DB.spend(uid, DB.HINT_COST) and DB.get_rewards(uid).cultural_relic == 0, "relic spent on a hint")
	# Players from before the shop keep what they earned.
	var old := DB.register_user("veteran", "").user.id as int
	DB._exec("INSERT INTO progress(user_id, language_code, difficulty, completed) VALUES(?, 'war', 1, 1);", [old])
	check(DB.is_language_unlocked(old, "war"), "languages already played stay unlocked")
	DB.sync_culture(old)
	check(DB.get_unlocked_culture(old).size() == 1, "cleared levels give their culture items")
	check(DB.delete_user(uid) and DB.get_unlocked_culture(uid).is_empty(), "deleting a player removes unlocks")


func _test_pronunciation_and_grammar() -> void:
	check(Pronounce.guide("salamat") == "sa·LA·mat", "salamat syllables (%s)" % Pronounce.guide("salamat"))
	check(Pronounce.syllables("pangalan") == ["pa", "nga", "lan"], "ng is one consonant")
	check(Pronounce.syllables("nag-aaral") == ["nag", "a", "a", "ral"], "hyphen and double vowel split")
	check(Pronounce.tips("Gusto ko ng tubig", "tl").any(func(t): return "nang" in t), "ng marker tip")
	var tips := DB.get_tips("tl")
	var r := GrammarChecker.check("Gusto ko ng tubig", "Gusto ko ng tubig.")
	check(r.ok, "correct sentence passes")
	r = GrammarChecker.check("gusto ko tubig", "Gusto ko ng tubig.", tips)
	check(not r.ok and r.issues[0].begins_with("Missing word: \"ng\"") and "Tip:" in r.issues[0], "missing marker found with its tip")
	r = GrammarChecker.check("Gusto ko ng tubg", "Gusto ko ng tubig.")
	check(not r.ok and "Spelling" in r.issues[0], "spelling mistake found")
	r = GrammarChecker.check("Ko gusto ng tubig", "Gusto ko ng tubig.")
	check(not r.ok and "Word order" in r.issues[0], "word order found")
	r = GrammarChecker.check("Gusto ko ang ng tubig", "Gusto ko ng tubig.")
	check(not r.ok and "Extra word" in r.issues[0], "extra word found")
	check(not GrammarChecker.check_free("The cat sleeps", DB.get_sentences("tl")).known, "unknown sentence is not judged")
	for lang in DB.get_playable_languages():
		var qs := Game.grammar_quiz(lang.code)
		check(qs.size() >= 6 and qs.size() <= Game.QUESTIONS_PER_QUIZ, "%s grammar quiz has 6-10 questions (%d)" % [lang.code, qs.size()])
		check(qs.any(func(q): return q.type == "grammar"), "%s grammar quiz has a sentence to write" % lang.code)
		for q in qs:
			if q.type == "choice":
				check(q.answer in q.options and q.options.size() >= 3, "%s grammar options" % lang.code)
			else:
				check(Game.check_answer(q, q.answer), "%s written answer passes the checker" % lang.code)


func _test_new_screens() -> void:
	var uid := DB.register_user("newbie", "").user.id as int
	Game.user = DB.get_user(uid)
	# Language shop: Ilocano is locked; with 20 fragments the UNLOCK button buys it.
	Game.region_code = "luzon"
	Game.goto("language")
	await _frames(3)
	var row := get_tree().current_scene.find_child("locked_ilo", true, false)
	check(row != null and row.find_child("unlock", true, false).disabled, "Ilocano locked, button off without fragments")
	Game.language_code = "ilo"
	Game.goto("difficulty")
	await _frames(3)
	check(_scene_is("language"), "a locked language can't be opened")
	DB.add_reward(uid, "word_fragment", 20)
	Game.goto("language")
	await _frames(3)
	await _click(get_tree().current_scene.find_child("locked_ilo", true, false).find_child("unlock", true, false))
	await _frames(3)
	check(_scene_is("difficulty") and DB.is_language_unlocked(uid, "ilo"), "UNLOCK buys the language and opens it")
	check(get_tree().current_scene.find_child("start_grammar", true, false).disabled, "grammar quiz opens after Easy")
	# Results show the revealed culture item.
	DB.record_quiz(uid, "ilo", 1, "", 100, 10, 10, 5, true)
	Game.difficulty = 1
	Game.category_code = ""
	Game.last_result = {"passed": true, "score": 100, "correct": 10, "total": 10, "hearts": 5,
		"summary": DB.record_quiz(uid, "ilo", 2, "", 100, 10, 10, 5, true)}
	Game.goto("results")
	await _frames(3)
	check(get_tree().current_scene.find_child("revealed", true, false) != null, "results show the revealed culture item")
	Game.goto("difficulty")
	await _frames(3)
	check(not get_tree().current_scene.find_child("start_grammar", true, false).disabled, "grammar quiz open after Easy")
	# Grammar quiz through the real quiz screen, with the pronunciation helper.
	Game.category_code = Game.GRAMMAR
	Game.difficulty = DB.MEDIUM
	Game.goto("quiz")
	await _frames(3)
	var quiz := get_tree().current_scene
	check(quiz.questions.all(func(q): return q.kind.begins_with("Grammar")), "grammar quiz screen")
	for i in quiz.questions.size():
		var q: Dictionary = quiz.questions[quiz.index]
		if q.type == "grammar":
			check(not q.answer in quiz.pronunciation_texts(), "pronunciation never shows the answer early")
		quiz._answer(q.answer if i != 0 else "zzz")
		if i == 0 and q.type == "grammar":
			check("Grammar check" in quiz.feedback_label.text, "checker feedback shown")
		if i == 0:
			await _click(quiz.find_child("pronounce", true, false))
			await _frames(2)
			check(quiz.get_node_or_null("PronouncePanel") != null, "Guiding Spirit pronunciation panel opens")
			Game.handle_back()
			await _frames(2)
			check(quiz.get_node_or_null("PronouncePanel") == null, "back key closes the panel")
		quiz._next()
		await _frames(1)
	await _frames(3)
	check(_scene_is("results") and Game.last_result.summary.reward_kind == "phrase_crystal", "grammar quiz pays crystals")
	# Gallery: buy a locked item with crystals.
	DB.add_reward(uid, "phrase_crystal", 5)
	Game.region_code = "visayas"
	Game.goto("gallery")
	await _frames(3)
	var buy := get_tree().current_scene.find_child("unlock", true, false)
	check(buy != null and not buy.disabled, "gallery unlock button on")
	var before := DB.get_unlocked_culture(uid).size()
	await _click(buy)
	await _frames(3)
	check(DB.get_unlocked_culture(uid).size() == before + 1, "gallery unlock buys an item")


func _test_play_quiz_through_ui() -> void:
	var uid := DB.register_user("tester", "secret3").user.id as int
	Game.user = DB.get_user(uid)
	Game.language_code = "war"
	Game.category_code = ""
	for d in [1, 2, 3]:
		Game.difficulty = d
		Game.goto("quiz")
		await _frames()
		var quiz := get_tree().current_scene
		var total: int = quiz.questions.size()
		for i in total:
			var q: Dictionary = quiz.questions[quiz.index]
			if i == 0:
				quiz._use_hint()
			if i == 1:
				quiz._answer("definitely wrong")
			else:
				quiz._answer(q.answer)
			quiz._next()
			await _frames(1)
		await _frames()
		check(get_tree().current_scene.scene_file_path == Game.SCENES.results, "difficulty %d ends on results" % d)
		check(Game.last_result.passed and Game.last_result.hearts == 4, "difficulty %d passed with 4 hearts" % d)
		check(Game.last_result.correct == total - 1, "difficulty %d correct count" % d)
	check(DB.get_mastered_language_count(uid, "visayas") == 1, "waray mastered through the UI")
	check("core_visayas" in DB.get_badges(uid), "visayas core badge from UI play")
	# Losing all hearts fails the quiz.
	Game.difficulty = 1
	Game.goto("quiz")
	await _frames()
	var quiz := get_tree().current_scene
	for i in Game.MAX_HEARTS:
		quiz._answer("wrong")
		quiz._next()
		await _frames(1)
	await _frames()
	check(not Game.last_result.passed, "quiz failed after losing all hearts")
