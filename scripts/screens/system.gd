extends Control
## Settings > SYSTEM: display and comfort, the player's data (check, backups,
## restore), privacy and security, and information about the game.

var size_picker: OptionButton
var saver: CheckButton
var reminder: CheckButton
var backups_box: VBoxContainer
var check_result: VBoxContainer

const FEATURES := [
	"Lessons (ARALIN) for 10 playable Philippine languages in Luzon, the Visayas and Mindanao, at Easy, Medium and Hard levels",
	"Quizzes with hearts, hints, instant feedback and a battle animation",
	"BIGKAS pronunciation help with syllables, stress, sound tips and the Guiding Spirits' recorded voices",
	"Grammar quiz and a grammar checker that says exactly what to fix",
	"Cultural elements (food, festivals, clothing, art, dances, music) revealed by quizzes and kept in the Gallery",
	"Rewards with a purpose: Word Fragments unlock languages, Phrase Crystals unlock culture, Cultural Relics buy hints",
	"Guiding Spirits that chat, translate and speak, island pearls, stories and a leaderboard",
	"First-time tutorial with a pointing hand, and the GABAY guide",
	"Several players on one device, each with their own saved progress",
]
const LIMITS := [
	"Pronunciation voices are synthesized; native-speaker recordings can replace them (assets/voice).",
	"10 of the 30 listed languages have lessons so far; the others are shown on the language maps.",
	"Online translation (MarianNMT) is optional; without it the built-in dictionary is used.",
]


func _ready() -> void:
	var content := UI.page(self, "SYSTEM", "settings")

	# Interaction capability and performance efficiency
	content.add_child(UI.heading("Display and comfort", UI.RED, 24))
	var p1 := UI.panel()
	var v1 := UI.vbox(10)
	p1.add_child(v1)
	var srow := UI.hbox(10)
	var sl := UI.label("Text size", 20, UI.INK, false, UI.font_body_black)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(sl)
	size_picker = OptionButton.new()
	size_picker.name = "text_size"
	size_picker.add_item("Normal")
	size_picker.add_item("Large")
	size_picker.select(1 if Game.text_size() == "large" else 0)
	size_picker.item_selected.connect(func(_i): _save_display())
	srow.add_child(size_picker)
	v1.add_child(srow)
	saver = _toggle(v1, "battery_saver", "Battery saver (30 frames per second)", Game.battery_saver_on())
	reminder = _toggle(v1, "break_reminder", "Remind me to take a break every 30 minutes", Game.break_reminder_on())
	content.add_child(p1)

	# Reliability and safety
	content.add_child(UI.heading("Your saved data", UI.RED, 24))
	var p2 := UI.panel()
	var v2 := UI.vbox(10)
	p2.add_child(v2)
	v2.add_child(UI.label("Progress is saved automatically after every lesson and quiz, on this device only. A backup is made every day and before a player is deleted. If the saved data is ever damaged, the game restores the newest backup by itself when it starts.", 17, UI.INK, true))
	var check := UI.pill_button("CHECK GAME DATA", UI.GREEN, _check, 52, 18)
	check.name = "check_data"
	v2.add_child(check)
	check_result = UI.vbox(4)
	check_result.name = "check_result"
	v2.add_child(check_result)
	var backup := UI.pill_button("BACK UP NOW", UI.BLUE, func():
		var path := DB.backup_now()
		UI.toast("Backup saved." if path != "" else "Could not make a backup.")
		_list_backups(), 52, 18)
	backup.name = "backup_now"
	v2.add_child(backup)
	v2.add_child(UI.label("Backups (newest first):", 17, UI.INK_SOFT, false, UI.font_body_black))
	backups_box = UI.vbox(6)
	backups_box.name = "backups"
	v2.add_child(backups_box)
	content.add_child(p2)
	_list_backups()

	# Security
	content.add_child(UI.heading("Privacy and security", UI.RED, 24))
	var p3 := UI.panel()
	var v3 := UI.vbox(4)
	p3.add_child(v3)
	for line in [
		"The game asks only for a player name and a hero. No email, phone number, location, camera or contacts.",
		"Everything stays on this device. The game works fully offline and sends nothing to the internet.",
		"Passwords (optional) are never stored: only a salted hash (SHA-256, 2000 rounds).",
		"Other screens show only display names and scores, never passwords.",
		"Deleting a player removes all of their data, and it is overwritten on disk.",
	]:
		v3.add_child(UI.label("• " + line, 17, UI.INK, true))
	content.add_child(p3)

	# Functional suitability, maintainability and flexibility
	content.add_child(UI.heading("About LINGUAPINAS", UI.RED, 24))
	var p4 := UI.panel()
	var v4 := UI.vbox(4)
	p4.add_child(v4)
	var about := UI.label("Version %s  •  Godot %s  •  SQLite database" % [
		ProjectSettings.get_setting("application/config/version", "1.0"), Engine.get_version_info().string], 18, UI.INK, true, UI.font_body_black)
	about.name = "version"
	v4.add_child(about)
	v4.add_child(UI.label("What the game does:", 17, UI.INK_SOFT, false, UI.font_body_black))
	for f in FEATURES:
		v4.add_child(UI.label("• " + f, 16, UI.INK, true))
	v4.add_child(UI.label("Known limitations:", 17, UI.INK_SOFT, false, UI.font_body_black))
	for l in LIMITS:
		v4.add_child(UI.label("• " + l, 16, UI.INK, true))
	v4.add_child(UI.label("For developers: setup, structure, dependencies and how to update the lessons are in README.md and docs/MAINTENANCE.md.", 16, UI.INK_SOFT, true))
	content.add_child(p4)


func _toggle(parent: Control, id: String, text: String, on: bool) -> CheckButton:
	var row := UI.hbox(10)
	var l := UI.label(text, 18, UI.INK, true, UI.font_body_black)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var c := CheckButton.new()
	c.name = id
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(_on): _save_display())
	row.add_child(c)
	parent.add_child(row)
	return c


func _save_display() -> void:
	Game.save_display("large" if size_picker.selected == 1 else "normal", saver.button_pressed, reminder.button_pressed)


func _check() -> Dictionary:
	for c in check_result.get_children():
		check_result.remove_child(c)
		c.queue_free()
	var r := DB.verify_data()
	for item in r.checked:
		check_result.add_child(UI.label("✔ " + item, 16, UI.GREEN, true))
	if r.ok:
		check_result.add_child(UI.label("All game data is correct.", 18, UI.GREEN, true, UI.font_body_black))
	for p in r.problems:
		check_result.add_child(UI.label("✖ " + p + " Restore a backup below to fix it.", 17, UI.RED, true, UI.font_body_black))
	return r


func _list_backups() -> void:
	for c in backups_box.get_children():
		backups_box.remove_child(c)
		c.queue_free()
	var list := DB.list_backups()
	if list.is_empty():
		backups_box.add_child(UI.label("No backups yet.", 16, UI.INK_SOFT))
	for i in list.size():
		var row := UI.hbox(8)
		var l := UI.label(DB.backup_label(list[i]), 16, UI.INK, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b := UI.pill_button("RESTORE", UI.INK_SOFT, _confirm_restore.bind(list[i]), 44, 17)
		b.name = "restore_%d" % i
		b.custom_minimum_size.x = 130
		row.add_child(b)
		backups_box.add_child(row)


## Safety: restoring replaces the current progress, so it asks first.
func _confirm_restore(path: String) -> void:
	var d := ConfirmationDialog.new()
	d.name = "RestoreConfirm"
	d.title = "Restore this backup?"
	d.dialog_text = "All players' progress will go back to %s. The current progress is backed up first, so you can undo this." % DB.backup_label(path)
	d.dialog_autowrap = true
	d.min_size = Vector2i(560, 0)
	d.ok_button_text = "RESTORE"
	add_child(d)
	d.confirmed.connect(func(): restore(path))
	d.canceled.connect(d.queue_free)
	d.popup_centered()


func restore(path: String) -> bool:
	Game.user = {}  # players may differ in the backup: choose again
	var ok := DB.restore_backup(path)
	Game.history.clear()
	Game.goto("title", false)
	UI.toast("Backup restored. Choose your Guardian with CONTINUE." if ok else "That backup could not be restored.")
	return ok
