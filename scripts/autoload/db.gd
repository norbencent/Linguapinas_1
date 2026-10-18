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
const HASH_ROUNDS := 2000

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
## What rewards buy. Word Fragments unlock languages, Phrase Crystals unlock
## culture items in the Gallery, a Cultural Relic buys an extra quiz hint.
const LANGUAGE_COST := {"word_fragment": 20}
const CULTURE_COST := {"phrase_crystal": 5}
const HINT_COST := {"cultural_relic": 1}
## A level passed again (or category / grammar practice) pays half.
const REPLAY_REWARD_SHARE := 0.5

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
		_exec("ALTER TABLE users ADD COLUMN has_password INTEGER NOT NULL DEFAULT 1;")
	var culture_cols: Array = []
	for row in _select("PRAGMA table_info(culture_items);"):
		culture_cols.append(row.name)
	if not "language_code" in culture_cols:
		_exec("ALTER TABLE culture_items ADD COLUMN language_code TEXT NOT NULL DEFAULT '';")
	if not "image" in culture_cols:
		_exec("ALTER TABLE culture_items ADD COLUMN image TEXT NOT NULL DEFAULT '';")


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
		_exec("""INSERT INTO culture_items(region_code, language_code, kind, title, description, image)
			VALUES(?, ?, ?, ?, ?, ?);""",
			[c.region_code, c.get("language_code", ""), c.kind, c.title, c.description, c.get("image", "")])
	for s in data.stories:
		_exec("INSERT INTO stories(region_code, title, body) VALUES(?, ?, ?);", [s.region_code, s.title, s.body])
	set_setting("content_version", str(version))
	_exec("COMMIT;")


# ---------------------------------------------------------------- accounts

func _hash_password(password: String, salt: String) -> String:
	var digest := (salt + password).sha256_text()
	for i in HASH_ROUNDS:
		digest = (digest + salt).sha256_text()
	return digest


## Creates a player. The name is also the login name; the password is
## optional (an empty password makes a device-only profile).
## Returns {"ok": bool, "error": String, "user": Dictionary}.
func register_user(username: String, password: String, display_name := "", avatar := "boy") -> Dictionary:
	username = " ".join(username.strip_edges().split(" ", false))
	display_name = display_name.strip_edges()
	if username.length() < 2 or username.length() > 20:
		return {"ok": false, "error": "Name must be 2 to 20 characters."}
	if not _is_simple_name(username):
		return {"ok": false, "error": "Use only letters, numbers, spaces, - and _ in the name."}
	if password != "" and password.length() < 4:
		return {"ok": false, "error": "Password must be at least 4 characters (or leave it empty)."}
	if not _select_one("SELECT id FROM users WHERE username = ?;", [username]).is_empty():
		return {"ok": false, "error": "That name is already taken."}
	if display_name == "":
		display_name = username
	var salt := Crypto.new().generate_random_bytes(16).hex_encode()
	if not _exec("INSERT INTO users(username, display_name, password_hash, salt, avatar, has_password) VALUES(?, ?, ?, ?, ?, ?);",
			[username, display_name, _hash_password(password, salt), salt, avatar if avatar in ["boy", "girl"] else "boy",
			1 if password != "" else 0]):
		return {"ok": false, "error": "Could not create the player."}
	return {"ok": true, "error": "", "user": get_user(db.last_insert_rowid)}


func _is_simple_name(s: String) -> bool:
	var re := RegEx.create_from_string("^[\\p{L}0-9_\\- ]+$")
	return re.search(s) != null


## Returns {"ok": bool, "error": String, "user": Dictionary}.
func login_user(username: String, password: String) -> Dictionary:
	var row := _select_one("SELECT * FROM users WHERE username = ?;", [username.strip_edges()])
	if row.is_empty() or _hash_password(password, row.salt) != row.password_hash:
		return {"ok": false, "error": "Wrong username or password."}
	_exec("UPDATE users SET last_login = datetime('now') WHERE id = ?;", [row.id])
	return {"ok": true, "error": "", "user": get_user(row.id)}


func get_user(user_id: int) -> Dictionary:
	return _select_one("""SELECT id, username, display_name, created_at, last_login, avatar, playtime, has_password
		FROM users WHERE id = ?;""", [user_id])


## Players saved on this device, most recently played first.
func get_users() -> Array:
	return _select("""SELECT id, username, display_name, avatar, has_password, playtime FROM users
		ORDER BY COALESCE(last_login, created_at) DESC;""")


## Removes a player and everything saved for them (scores, progress,
## rewards, badges). Returns true if the player existed and was deleted.
func delete_user(user_id: int) -> bool:
	if get_user(user_id).is_empty():
		return false
	if not _exec("BEGIN;"):
		return false
	var ok := true
	for table in ["quiz_attempts", "progress", "rewards", "badges", "unlocked_languages", "unlocked_culture", "tutorial_seen"]:
		ok = ok and _exec("DELETE FROM %s WHERE user_id = ?;" % table, [user_id])
	ok = ok and _exec("DELETE FROM users WHERE id = ?;", [user_id])
	_exec("COMMIT;" if ok else "ROLLBACK;")
	return ok


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
	var first_clear: bool = category_code == "" and passed and not get_progress(user_id, language_code)[difficulty].completed
	_exec("BEGIN TRANSACTION;")
	_exec("""INSERT INTO quiz_attempts(user_id, language_code, difficulty, category_code, score, correct, total,
		hearts_left, passed) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?);""",
		[user_id, language_code, difficulty, category_code, score, correct, total, hearts_left, 1 if passed else 0])
	# Only full (all-category) quizzes count toward unlocking and the leaderboard.
	var counts := category_code == ""
	if counts:
		_exec("""INSERT INTO progress(user_id, language_code, difficulty, best_score, completed) VALUES(?, ?, ?, ?, ?)
			ON CONFLICT(user_id, language_code, difficulty) DO UPDATE SET
			best_score = max(best_score, excluded.best_score), completed = max(completed, excluded.completed);""",
			[user_id, language_code, difficulty, score if passed else 0, 1 if passed else 0])
	var reward_kind: String = REWARD_FOR_DIFFICULTY[difficulty]
	var reward_amount := 0
	if passed:
		reward_amount = correct if first_clear else maxi(1, int(ceil(correct * REPLAY_REWARD_SHARE)))
	if reward_amount > 0:
		add_reward(user_id, reward_kind, reward_amount)
	_exec("COMMIT;")
	# Clearing a level for the first time reveals one of the language's culture items.
	var revealed: Dictionary = reveal_culture(user_id, language_code) if first_clear else {}

	var new_badges: Array = []
	for region in get_restored_cores(user_id):
		if not (region in cores_before) and _award_badge(user_id, "core_" + region):
			new_badges.append("core_" + region)
	if get_restored_cores(user_id).size() == get_regions().size() and _award_badge(user_id, "pearl"):
		new_badges.append("pearl")
	return {"new_badges": new_badges, "reward_kind": reward_kind, "reward_amount": reward_amount, "counts": counts,
		"first_clear": first_clear, "revealed": revealed}


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


## True if the player has at least [param cost] ({kind: amount}).
func can_afford(user_id: int, cost: Dictionary) -> bool:
	var have := get_rewards(user_id)
	for kind in cost:
		if int(have.get(kind, 0)) < int(cost[kind]):
			return false
	return true


## Takes [param cost] from the player's rewards. False (and nothing spent) if
## they cannot afford it.
func spend(user_id: int, cost: Dictionary) -> bool:
	if not can_afford(user_id, cost):
		return false
	for kind in cost:
		_exec("UPDATE rewards SET amount = amount - ? WHERE user_id = ? AND kind = ?;", [int(cost[kind]), user_id, kind])
	return true


static func cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for kind in cost:
		parts.append("%d %s" % [cost[kind], REWARD_NAMES[kind]])
	return ", ".join(parts)


# ---------------------------------------------------------------- language shop

## The first playable language of each region is free.
func is_language_free(code: String) -> bool:
	var lang := get_language(code)
	if lang.is_empty():
		return false
	var first := _select_one("""SELECT code FROM languages WHERE region_code = ? AND playable = 1
		ORDER BY sort_order LIMIT 1;""", [lang.region_code])
	return first.get("code", "") == code


## Free, bought, or already played before the shop existed.
func is_language_unlocked(user_id: int, code: String) -> bool:
	if is_language_free(code):
		return true
	if not _select_one("SELECT 1 AS x FROM unlocked_languages WHERE user_id = ? AND language_code = ?;",
			[user_id, code]).is_empty():
		return true
	return not _select_one("SELECT 1 AS x FROM progress WHERE user_id = ? AND language_code = ?;",
		[user_id, code]).is_empty()


## Buys a language with Word Fragments. Returns {"ok": bool, "error": String}.
func unlock_language(user_id: int, code: String) -> Dictionary:
	var lang := get_language(code)
	if lang.is_empty() or int(lang.playable) != 1:
		return {"ok": false, "error": "This language is not available yet."}
	if is_language_unlocked(user_id, code):
		return {"ok": true, "error": ""}
	if not spend(user_id, LANGUAGE_COST):
		return {"ok": false, "error": "You need %s. Play quizzes to collect more." % cost_text(LANGUAGE_COST)}
	_exec("INSERT INTO unlocked_languages(user_id, language_code) VALUES(?, ?);", [user_id, code])
	return {"ok": true, "error": ""}


# ---------------------------------------------------------------- culture unlocks

func is_culture_unlocked(user_id: int, title: String) -> bool:
	return not _select_one("SELECT 1 AS x FROM unlocked_culture WHERE user_id = ? AND title = ?;",
		[user_id, title]).is_empty()


func get_unlocked_culture(user_id: int) -> Array:
	var out: Array = []
	for row in _select("SELECT title FROM unlocked_culture WHERE user_id = ?;", [user_id]):
		out.append(row.title)
	return out


## Reveals the next locked culture item of the language (or, when they are
## all unlocked, of its region). Returns the item, or {} if none is left.
func reveal_culture(user_id: int, language_code: String) -> Dictionary:
	var lang := get_language(language_code)
	if lang.is_empty():
		return {}
	var have := get_unlocked_culture(user_id)
	var items := get_culture_items(lang.region_code)
	var own := items.filter(func(c): return c.language_code == language_code and not c.title in have)
	var rest := items.filter(func(c): return c.language_code != language_code and not c.title in have)
	var pick: Dictionary = own[0] if not own.is_empty() else (rest[0] if not rest.is_empty() else {})
	if not pick.is_empty():
		_exec("INSERT OR IGNORE INTO unlocked_culture(user_id, title, source) VALUES(?, ?, ?);",
			[user_id, pick.title, "quiz:" + language_code])
	return pick


## Buys a culture item with Phrase Crystals. Returns {"ok": bool, "error": String}.
func unlock_culture(user_id: int, title: String) -> Dictionary:
	if is_culture_unlocked(user_id, title):
		return {"ok": true, "error": ""}
	if _select_one("SELECT 1 AS x FROM culture_items WHERE title = ?;", [title]).is_empty():
		return {"ok": false, "error": "Unknown culture item."}
	if not spend(user_id, CULTURE_COST):
		return {"ok": false, "error": "You need %s. Clear Medium levels to collect more." % cost_text(CULTURE_COST)}
	_exec("INSERT INTO unlocked_culture(user_id, title, source) VALUES(?, ?, 'bought');", [user_id, title])
	return {"ok": true, "error": ""}


## Players who cleared levels before culture was revealed by quizzes get one
## item per cleared level, so nobody loses what they had earned.
func sync_culture(user_id: int) -> void:
	for row in _select("""SELECT language_code, COUNT(*) AS n FROM progress
			WHERE user_id = ? AND completed = 1 GROUP BY language_code;""", [user_id]):
		var have := int(_select_one("SELECT COUNT(*) AS n FROM unlocked_culture WHERE user_id = ? AND source = ?;",
			[user_id, "quiz:" + row.language_code]).get("n", 0))
		for i in int(row.n) - have:
			if reveal_culture(user_id, row.language_code).is_empty():
				break


# ---------------------------------------------------------------- tutorial

func has_seen_tutorial(user_id: int, key: String) -> bool:
	return not _select_one("SELECT 1 AS x FROM tutorial_seen WHERE user_id = ? AND key = ?;", [user_id, key]).is_empty()


func mark_tutorial_seen(user_id: int, key: String) -> void:
	_exec("INSERT OR IGNORE INTO tutorial_seen(user_id, key) VALUES(?, ?);", [user_id, key])


## Shows every tip again (from the Guide screen).
func reset_tutorials(user_id: int) -> void:
	_exec("DELETE FROM tutorial_seen WHERE user_id = ?;", [user_id])


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


## Number of languages of the region that can be played (have lessons).
func get_playable_count(region_code: String) -> int:
	return int(_select_one("SELECT COUNT(*) AS n FROM languages WHERE region_code = ? AND playable = 1;",
		[region_code]).get("n", 0))


## {"mastered": n, "total": m}: how many of the island's playable languages
## the player has mastered (Easy, Medium and Hard passed).
func get_pearl_progress(user_id: int, region_code: String) -> Dictionary:
	return {"mastered": get_mastered_language_count(user_id, region_code), "total": get_playable_count(region_code)}


## An island's pearl (its Language Core) lights up only when the player has
## mastered EVERY playable language of the island.
func is_core_restored(user_id: int, region_code: String) -> bool:
	var p := get_pearl_progress(user_id, region_code)
	return p.total > 0 and p.mastered >= p.total


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


# ---------------------------------------------------------------- leaderboard

## Total points = sum of each player's best score on every level.
func get_leaderboard(limit := 20, region_code := "") -> Array:
	var where := "" if region_code == "" else "AND l.region_code = ?"
	var bindings: Array = [] if region_code == "" else [region_code]
	bindings.append(limit)
	return _select("""SELECT u.id, u.display_name, u.username,
		COALESCE(SUM(p.best_score), 0) AS total_score,
		COALESCE(SUM(p.completed), 0) AS levels_completed
		FROM users u JOIN progress p ON p.user_id = u.id
		JOIN languages l ON l.code = p.language_code
		WHERE p.completed = 1 %s
		GROUP BY u.id ORDER BY total_score DESC, levels_completed DESC, u.display_name LIMIT ?;""" % where, bindings)


func get_total_score(user_id: int) -> int:
	var row := _select_one("SELECT COALESCE(SUM(best_score), 0) AS s FROM progress WHERE user_id = ? AND completed = 1;", [user_id])
	return int(row.get("s", 0))
