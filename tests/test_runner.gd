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
	check(rewards.word_fragment == 3 + 9 + 8 + 9 + 9, "word fragments counted (%d)" % rewards.word_fragment)
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
