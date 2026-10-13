extends Node
## SQLite data layer for LinguaPinas (autoload "DB").
##
## Uses the godot-sqlite GDExtension (addons/godot-sqlite). The database file
## lives in user:// so it is writable on every platform, and it is created and
## seeded automatically on first launch from database/schema.sql and
## database/seed_data.json.

const SCHEMA_PATH := "res://database/schema.sql"
const SEED_PATH := "res://database/seed_data.json"
const DEFAULT_DB_PATH := "user://linguapinas.db"
## How many languages of a region must be mastered (all three difficulties
## passed) to restore that region's Language Core.
const LANGUAGES_TO_RESTORE_CORE := 1

const EASY := 1
const MEDIUM := 2
const HARD := 3
const DIFFICULTY_NAMES := {1: "Easy", 2: "Medium", 3: "Hard"}
const REWARD_FOR_DIFFICULTY := {1: "word_fragment", 2: "phrase_crystal", 3: "cultural_relic"}
const REWARD_NAMES := {
	"word_fragment": "Word Fragments",
	"phrase_crystal": "Phrase Crystals",
	"cultural_relic": "Cultural Relics",
}

var db: SQLite
var db_path := DEFAULT_DB_PATH
var last_error := ""


func _ready() -> void:
	open(DEFAULT_DB_PATH)


func _exit_tree() -> void:
	close()


## Opens (and creates/seeds if needed) the database at [param path].
func open(path: String) -> bool:
	close()
	db_path = path
	db = SQLite.new()
	db.path = path
	db.foreign_keys = true
	db.verbosity_level = SQLite.QUIET
	if not db.open_db():
		last_error = "Could not open database: %s" % db.error_message
		push_error(last_error)
		return false
	_create_schema()
	_migrate()
	_seed_content()
	return true


func close() -> void:
	if db != null:
		db.close_db()
		db = null


# ---------------------------------------------------------------- helpers

func _exec(sql: String, bindings: Array = []) -> bool:
	var ok: bool
	if bindings.is_empty():
		ok = db.query(sql)
	else:
		ok = db.query_with_bindings(sql, bindings)
	if not ok:
		last_error = db.error_message
		push_error("SQL error: %s\n%s" % [db.error_message, sql])
	return ok


func _select(sql: String, bindings: Array = []) -> Array:
	if not _exec(sql, bindings):
		return []
	return db.query_result.duplicate(true)


func _select_one(sql: String, bindings: Array = []) -> Dictionary:
	var rows := _select(sql, bindings)
	return rows[0] if rows.size() > 0 else {}


func _create_schema() -> void:
	var text := FileAccess.get_file_as_string(SCHEMA_PATH)
	# Strip comments, then split on statement-ending semicolons.
	var lines := PackedStringArray()
	for line in text.split("\n"):
		if not line.strip_edges().begins_with("--"):
			lines.append(line)
	for statement in "\n".join(lines).split(";\n"):
		var sql := statement.strip_edges().trim_suffix(";")
		if sql != "":
			_exec(sql)


## Adds columns introduced after the first release to existing databases.
func _migrate() -> void:
	var cols: Array = []
	for row in _select("PRAGMA table_info(users);"):
		cols.append(row.name)
	if not "avatar" in cols:
		_exec("ALTER TABLE users ADD COLUMN avatar TEXT NOT NULL DEFAULT 'boy';")
	if not "playtime" in cols:
		_exec("ALTER TABLE users ADD COLUMN playtime INTEGER NOT NULL DEFAULT 0;")
	if not "has_password" in cols:
		_exec("ALTER TABLE users ADD COLUMN has_password INTEGER NOT NULL DEFAULT 0;")
	# Players no longer have passwords: tapping a saved player continues it.
	_exec("UPDATE users SET password_hash = '', salt = '', has_password = 0 WHERE has_password != 0;")
	# The sample player "Ryu" from early builds is removed once, with all of
	# his progress, rewards and badges (ON DELETE CASCADE).
	if get_setting("sample_player_removed", "0") != "1":
		var ryu := _select_one("SELECT id FROM users WHERE username = 'Ryu';")
		if not ryu.is_empty():
			delete_user(int(ryu.id))
		set_setting("sample_player_removed", "1")


func get_setting(key: String, default_value := "") -> String:
	var row := _select_one("SELECT value FROM settings WHERE key = ?;", [key])
	return str(row.get("value", default_value))


func set_setting(key: String, value: String) -> void:
	_exec("INSERT INTO settings(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;", [key, value])


## Loads seed_data.json into the content tables. Runs again whenever the
## "version" in the JSON file is increased, without touching player data.
func _seed_content() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(SEED_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Invalid seed file: %s" % SEED_PATH)
		return
	var version := int(data.get("version", 1))
	if int(get_setting("content_version", "0")) >= version:
		return

	_exec("BEGIN TRANSACTION;")
	for r in data.regions:
		_exec("""INSERT INTO regions(code, name, core_name, description, color, sort_order) VALUES(?, ?, ?, ?, ?, ?)
			ON CONFLICT(code) DO UPDATE SET name = excluded.name, core_name = excluded.core_name,
			description = excluded.description, color = excluded.color, sort_order = excluded.sort_order;""",
			[r.code, r.name, r.core_name, r.description, r.color, int(r.sort_order)])
	for l in data.languages:
		_exec("""INSERT INTO languages(code, region_code, name, description, playable, sort_order) VALUES(?, ?, ?, ?, ?, ?)
			ON CONFLICT(code) DO UPDATE SET region_code = excluded.region_code, name = excluded.name,
			description = excluded.description, playable = excluded.playable, sort_order = excluded.sort_order;""",
			[l.code, l.region_code, l.name, l.description, int(l.playable), int(l.sort_order)])
	for c in data.categories:
		_exec("""INSERT INTO categories(code, name, sort_order) VALUES(?, ?, ?)
			ON CONFLICT(code) DO UPDATE SET name = excluded.name, sort_order = excluded.sort_order;""",
			[c.code, c.name, int(c.sort_order)])
	# Content nobody references can simply be replaced.
	for table in ["words", "sentences", "tips", "culture_items", "stories"]:
		_exec("DELETE FROM %s;" % table)
	for w in data.words:
		_exec("INSERT INTO words(language_code, category_code, native, english, note) VALUES(?, ?, ?, ?, ?);",
			[w.language_code, w.category_code, w.native, w.english, w.get("note", "")])
	for s in data.sentences:
		_exec("INSERT INTO sentences(language_code, native, english, context) VALUES(?, ?, ?, ?);",
			[s.language_code, s.native, s.english, s.get("context", "")])
	for t in data.tips:
		_exec("INSERT INTO tips(language_code, tip) VALUES(?, ?);", [t.language_code, t.tip])
	for c in data.culture_items:
		_exec("INSERT INTO culture_items(region_code, kind, title, description) VALUES(?, ?, ?, ?);",
			[c.region_code, c.kind, c.title, c.description])
	for s in data.stories:
		_exec("INSERT INTO stories(region_code, title, body) VALUES(?, ?, ?);", [s.region_code, s.title, s.body])
	set_setting("content_version", str(version))
	_exec("COMMIT;")


# ---------------------------------------------------------------- accounts

## Hero portraits a player can pick: one boy and one girl per main island.
const AVATARS := ["luzon_boy", "luzon_girl", "visayas_boy", "visayas_girl", "mindanao_boy", "mindanao_girl"]


## Creates a player. The name is also the login name (no password).
## Returns {"ok": bool, "error": String, "user": Dictionary}.
func register_user(username: String, display_name := "", avatar := "luzon_boy") -> Dictionary:
	username = " ".join(username.strip_edges().split(" ", false))
	display_name = display_name.strip_edges()
	if username.length() < 2 or username.length() > 20:
		return {"ok": false, "error": "Name must be 2 to 20 characters."}
	if not _is_simple_name(username):
		return {"ok": false, "error": "Use only letters, numbers, spaces, - and _ in the name."}
	if not _select_one("SELECT id FROM users WHERE username = ?;", [username]).is_empty():
		return {"ok": false, "error": "That name is already taken."}
	if display_name == "":
		display_name = username
	if not avatar in AVATARS:
		avatar = "luzon_boy"
	if not _exec("INSERT INTO users(username, display_name, password_hash, salt, avatar, has_password) VALUES(?, ?, '', '', ?, 0);",
			[username, display_name, avatar]):
		return {"ok": false, "error": "Could not create the player."}
	return {"ok": true, "error": "", "user": get_user(db.last_insert_rowid)}


func _is_simple_name(s: String) -> bool:
	var re := RegEx.create_from_string("^[\\p{L}0-9_\\- ]+$")
	return re.search(s) != null


## Continues a saved player. Returns {"ok": bool, "error": String, "user": Dictionary}.
func login_user(username: String) -> Dictionary:
	var row := _select_one("SELECT id FROM users WHERE username = ?;", [username.strip_edges()])
	if row.is_empty():
		return {"ok": false, "error": "Player not found."}
	_exec("UPDATE users SET last_login = datetime('now') WHERE id = ?;", [row.id])
	return {"ok": true, "error": "", "user": get_user(row.id)}


## Deletes a saved player with all their progress, attempts, rewards and badges.
func delete_user(user_id: int) -> bool:
	return _exec("DELETE FROM users WHERE id = ?;", [user_id])


func get_user(user_id: int) -> Dictionary:
	return _select_one("""SELECT id, username, display_name, created_at, last_login, avatar, playtime
		FROM users WHERE id = ?;""", [user_id])


## Players saved on this device, most recently played first.
func get_users() -> Array:
	return _select("""SELECT id, username, display_name, avatar, playtime FROM users
		ORDER BY COALESCE(last_login, created_at) DESC;""")


func add_playtime(user_id: int, seconds: int) -> void:
	if seconds > 0:
		_exec("UPDATE users SET playtime = playtime + ? WHERE id = ?;", [seconds, user_id])


## Language (and region) of the player's most recent quiz, or {}.
func get_last_language(user_id: int) -> Dictionary:
	return _select_one("""SELECT l.* FROM quiz_attempts a JOIN languages l ON l.code = a.language_code
		WHERE a.user_id = ? ORDER BY a.id DESC LIMIT 1;""", [user_id])


# ---------------------------------------------------------------- content

func get_regions() -> Array:
	return _select("SELECT * FROM regions ORDER BY sort_order;")


func get_region(code: String) -> Dictionary:
	return _select_one("SELECT * FROM regions WHERE code = ?;", [code])


func get_languages(region_code: String) -> Array:
	return _select("SELECT * FROM languages WHERE region_code = ? ORDER BY playable DESC, sort_order;", [region_code])


func get_playable_languages() -> Array:
	return _select("SELECT * FROM languages WHERE playable = 1 ORDER BY sort_order;")


func get_language(code: String) -> Dictionary:
	return _select_one("SELECT * FROM languages WHERE code = ?;", [code])


func get_categories(language_code := "") -> Array:
	if language_code == "":
		return _select("SELECT * FROM categories ORDER BY sort_order;")
	return _select("""SELECT DISTINCT c.* FROM categories c JOIN words w ON w.category_code = c.code
		WHERE w.language_code = ? ORDER BY c.sort_order;""", [language_code])


func get_words(language_code: String, category_code := "") -> Array:
	if category_code == "":
		return _select("SELECT * FROM words WHERE language_code = ? ORDER BY id;", [language_code])
	return _select("SELECT * FROM words WHERE language_code = ? AND category_code = ? ORDER BY id;",
		[language_code, category_code])


func get_sentences(language_code: String) -> Array:
	return _select("SELECT * FROM sentences WHERE language_code = ? ORDER BY id;", [language_code])


func get_tips(language_code: String) -> Array:
	return _select("SELECT * FROM tips WHERE language_code = ? ORDER BY id;", [language_code])


func get_culture_items(region_code := "") -> Array:
	if region_code == "":
		return _select("""SELECT c.* FROM culture_items c JOIN regions r ON r.code = c.region_code
			ORDER BY r.sort_order, c.id;""")
	return _select("SELECT * FROM culture_items WHERE region_code = ? ORDER BY id;", [region_code])


func get_stories() -> Array:
	return _select("SELECT * FROM stories ORDER BY id;")


## Looks up [param text] in the offline dictionary (words and sentences).
## direction is "to_english" or "from_english".
func dictionary_lookup(language_code: String, text: String, direction: String) -> Array:
	var column := "native" if direction == "to_english" else "english"
	var needle := text.strip_edges().to_lower().trim_suffix("?").trim_suffix(".").trim_suffix("!")
	var sql := """SELECT native, english, '' AS note FROM sentences WHERE language_code = ?1 AND
		(lower(%s) = ?2 OR lower(%s) LIKE ?3)
		UNION ALL SELECT native, english, note FROM words WHERE language_code = ?1 AND
		(lower(%s) = ?2 OR lower(%s) LIKE ?3);""" % [column, column, column, column]
	return _select(sql, [language_code, needle, needle + "%"])


# ---------------------------------------------------------------- progress

func get_progress(user_id: int, language_code: String) -> Dictionary:
	var result := {}
	for d in [EASY, MEDIUM, HARD]:
		result[d] = {"best_score": 0, "completed": false, "lesson_done": false}
	for row in _select("SELECT * FROM progress WHERE user_id = ? AND language_code = ?;", [user_id, language_code]):
		result[int(row.difficulty)] = {
			"best_score": int(row.best_score),
			"completed": int(row.completed) == 1,
			"lesson_done": int(row.lesson_done) == 1,
		}
	return result


func is_difficulty_unlocked(user_id: int, language_code: String, difficulty: int) -> bool:
	if difficulty == EASY:
		return true
	return get_progress(user_id, language_code)[difficulty - 1].completed


func mark_lesson_done(user_id: int, language_code: String, difficulty: int) -> void:
	_exec("""INSERT INTO progress(user_id, language_code, difficulty, lesson_done) VALUES(?, ?, ?, 1)
		ON CONFLICT(user_id, language_code, difficulty) DO UPDATE SET lesson_done = 1;""",
		[user_id, language_code, difficulty])


## Saves a finished quiz and hands out rewards. Returns a summary with
## "new_badges" (Array of codes) and "reward_kind"/"reward_amount".
func record_quiz(user_id: int, language_code: String, difficulty: int, category_code: String,
		score: int, correct: int, total: int, hearts_left: int, passed: bool) -> Dictionary:
	var cores_before := get_restored_cores(user_id)
	_exec("BEGIN TRANSACTION;")
	_exec("""INSERT INTO quiz_attempts(user_id, language_code, difficulty, category_code, score, correct, total,
		hearts_left, passed) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?);""",
		[user_id, language_code, difficulty, category_code, score, correct, total, hearts_left, 1 if passed else 0])
	# Only full (all-category) quizzes count toward unlocking levels and the score.
	var counts := category_code == ""
	if counts:
		_exec("""INSERT INTO progress(user_id, language_code, difficulty, best_score, completed) VALUES(?, ?, ?, ?, ?)
			ON CONFLICT(user_id, language_code, difficulty) DO UPDATE SET
			best_score = max(best_score, excluded.best_score), completed = max(completed, excluded.completed);""",
			[user_id, language_code, difficulty, score if passed else 0, 1 if passed else 0])
	var reward_kind: String = REWARD_FOR_DIFFICULTY[difficulty]
	var reward_amount := correct if passed else 0
	if reward_amount > 0:
		add_reward(user_id, reward_kind, reward_amount)
	_exec("COMMIT;")

	var new_badges: Array = []
	for region in get_restored_cores(user_id):
		if not (region in cores_before) and _award_badge(user_id, "core_" + region):
			new_badges.append("core_" + region)
	if get_restored_cores(user_id).size() == get_regions().size() and _award_badge(user_id, "pearl"):
		new_badges.append("pearl")
	return {"new_badges": new_badges, "reward_kind": reward_kind, "reward_amount": reward_amount, "counts": counts}


func add_reward(user_id: int, kind: String, amount: int) -> void:
	_exec("""INSERT INTO rewards(user_id, kind, amount) VALUES(?, ?, ?)
		ON CONFLICT(user_id, kind) DO UPDATE SET amount = amount + excluded.amount;""", [user_id, kind, amount])


func get_rewards(user_id: int) -> Dictionary:
	var result := {}
	for kind in REWARD_NAMES:
		result[kind] = 0
	for row in _select("SELECT kind, amount FROM rewards WHERE user_id = ?;", [user_id]):
		result[row.kind] = int(row.amount)
	return result


func _award_badge(user_id: int, code: String) -> bool:
	if not _select_one("SELECT code FROM badges WHERE user_id = ? AND code = ?;", [user_id, code]).is_empty():
		return false
	return _exec("INSERT INTO badges(user_id, code) VALUES(?, ?);", [user_id, code])


func get_badges(user_id: int) -> Array:
	var codes: Array = []
	for row in _select("SELECT code FROM badges WHERE user_id = ? ORDER BY earned_at;", [user_id]):
		codes.append(row.code)
	return codes


## Number of languages in the region where the player passed all three levels.
func get_mastered_language_count(user_id: int, region_code: String) -> int:
	var row := _select_one("""SELECT COUNT(*) AS n FROM (
		SELECT p.language_code FROM progress p JOIN languages l ON l.code = p.language_code
		WHERE p.user_id = ? AND l.region_code = ? AND p.completed = 1
		GROUP BY p.language_code HAVING COUNT(DISTINCT p.difficulty) = 3);""", [user_id, region_code])
	return int(row.get("n", 0))


## Number of completed (language, difficulty) levels in a region.
func get_completed_level_count(user_id: int, region_code: String) -> int:
	var row := _select_one("""SELECT COUNT(*) AS n FROM progress p JOIN languages l ON l.code = p.language_code
		WHERE p.user_id = ? AND l.region_code = ? AND p.completed = 1;""", [user_id, region_code])
	return int(row.get("n", 0))


## A region's Language Core is restored once the player masters
## LANGUAGES_TO_RESTORE_CORE of its languages (Easy, Medium and Hard).
func is_core_restored(user_id: int, region_code: String) -> bool:
	return get_mastered_language_count(user_id, region_code) >= LANGUAGES_TO_RESTORE_CORE


func get_restored_cores(user_id: int) -> Array:
	var restored: Array = []
	for region in get_regions():
		if is_core_restored(user_id, region.code):
			restored.append(region.code)
	return restored


func get_recent_attempts(user_id: int, limit := 10) -> Array:
	return _select("""SELECT a.*, l.name AS language_name FROM quiz_attempts a
		JOIN languages l ON l.code = a.language_code
		WHERE a.user_id = ? ORDER BY a.id DESC LIMIT ?;""", [user_id, limit])


# ---------------------------------------------------------------- score

## Total points = sum of the player's best score on every level.
func get_total_score(user_id: int) -> int:
	var row := _select_one("SELECT COALESCE(SUM(best_score), 0) AS s FROM progress WHERE user_id = ? AND completed = 1;", [user_id])
	return int(row.get("s", 0))
