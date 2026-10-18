extends Control
## The Guiding Spirit: talk to your island's spirit (it answers and speaks
## in its own voice), plus the translator, grammar checker and tips.

var lang_picker: OptionButton
var direction_picker: OptionButton
var input: LineEdit
var result_label: Label
var source_label: Label
var matches_box: VBoxContainer
var tips_box: VBoxContainer
var server_label: Label
var lang_codes: Array = []
var grammar_input: LineEdit
var grammar_box: VBoxContainer
var portrait: TextureRect
var spirit_title: Label
var chat_log: VBoxContainer
var chat_input: LineEdit
var chips: HFlowContainer


func _ready() -> void:
	var content := UI.page(self, UI.t("spirit"), Game.BACK)
	var head := UI.hbox(12)
	portrait = UI.image(null, Vector2(110, 110))
	head.add_child(portrait)
	spirit_title = UI.label("", 19, Color("5a3591"), true, UI.font_body_black)
	spirit_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spirit_title)
	content.add_child(head)

	lang_picker = OptionButton.new()
	lang_picker.name = "language"
	for l in DB.get_playable_languages():
		lang_picker.add_item(l.name)
		lang_codes.append(l.code)
	var start: String = Game.language_code if Game.language_code in lang_codes else \
		(DB.get_playable_languages().filter(func(l): return l.region_code == Game.region_code).map(func(l): return l.code) + ["tl"])[0]
	lang_picker.select(maxi(0, lang_codes.find(start)))
	lang_picker.item_selected.connect(func(_i):
		_show_tips()
		_meet_spirit())
	content.add_child(lang_picker)

	# Chat with the spirit.
	var chat := UI.panel(Color("f6efff"), Color("8a63c2"))
	chat_log = UI.vbox(8)
	chat_log.name = "chat_log"
	chat.add_child(chat_log)
	content.add_child(chat)
	var ask_row := UI.hbox(8)
	chat_input = UI.line_edit("Ask me anything about the language...")
	chat_input.name = "chat_input"
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.text_submitted.connect(func(t): ask(t))
	ask_row.add_child(chat_input)
	var ask_b := UI.pill_button("ASK", Color("6b3fa0"), func(): ask(chat_input.text), 56, 20)
	ask_b.name = "ask"
	ask_row.add_child(ask_b)
	content.add_child(ask_row)
	chips = HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	content.add_child(chips)
	_set_chips(SpiritBrain.suggestions(""))

	content.add_child(UI.heading("Translator", UI.RED, 24))
	direction_picker = OptionButton.new()
	direction_picker.add_item("Language -> English")
	direction_picker.add_item("English -> Language")
	content.add_child(direction_picker)

	input = UI.line_edit("e.g. Salamat / Thank you")
	input.text_submitted.connect(func(_t): _translate())
	content.add_child(input)
	content.add_child(UI.gem_button("TRANSLATE", "purple", _translate, 80, 30))

	var result_panel := UI.panel(Color("efe0ff"), Color("8a63c2"))
	var rv := UI.vbox(6)
	result_panel.add_child(rv)
	result_label = UI.label("...", 28, Color("5a3591"), true, UI.font_body_black)
	rv.add_child(result_label)
	source_label = UI.label("", 15, UI.INK_SOFT, true)
	rv.add_child(source_label)
	matches_box = UI.vbox(4)
	rv.add_child(matches_box)
	content.add_child(result_panel)

	var say := UI.pill_button("PRONOUNCE", Color("6b3fa0"), _pronounce, 52, 18)
	say.name = "pronounce"
	content.add_child(say)

	content.add_child(UI.heading("Grammar checker", UI.RED, 24))
	content.add_child(UI.label("Write a sentence in the language above. I compare it with the sentences I know and tell you what to fix.", 16, UI.INK_SOFT, true))
	grammar_input = UI.line_edit("e.g. Gusto ko ng tubig")
	grammar_input.text_submitted.connect(func(_t): _check_grammar())
	content.add_child(grammar_input)
	content.add_child(UI.gem_button("CHECK GRAMMAR", "green", _check_grammar, 80, 28))
	grammar_box = UI.vbox(4)
	grammar_box.name = "grammar_result"
	content.add_child(grammar_box)

	server_label = UI.label("Checking for the MarianNMT translator...", 15, UI.INK_SOFT, true)
	content.add_child(server_label)
	content.add_child(UI.heading("Grammar tips", UI.RED, 24))
	tips_box = UI.vbox(6)
	content.add_child(tips_box)
	_show_tips()
	_check_server()
	_meet_spirit()
	GuidePages.maybe_show(self, "spirit")


func _region() -> String:
	return Spirit.region_of(_current_lang())


## Shows the spirit of the chosen language's island; it greets you.
func _meet_spirit() -> void:
	var region := _region()
	portrait.texture = UI.tex["guide_" + region]
	var p := Spirit.persona(region)
	spirit_title.text = "%s, %s\n%s" % [p.get("name", ""), p.get("title", ""), p.get("personality", "")]
	for c in chat_log.get_children():
		chat_log.remove_child(c)
		c.queue_free()
	var hello := Spirit.line(region, "greet")
	_bubble(hello, false, [["fil" if UI.lang == "fil" else "en", hello]])
	Spirit.say(region, hello, "fil" if UI.lang == "fil" else "en", true)


## Asks the spirit; its answer appears in the chat and is spoken.
func ask(question: String) -> Dictionary:
	if question.strip_edges() == "":
		return {}
	chat_input.text = ""
	_bubble(question, true, [])
	var answer: Dictionary = await SpiritBrain.ask(question, _current_lang())
	if not is_inside_tree():
		return answer
	_bubble(answer.text, false, answer.say)
	_set_chips(answer.suggest)
	_speak(answer.say, true)
	return answer


func _speak(say: Array, interrupt: bool) -> void:
	var first := true
	for item in say:
		var lang: String = item[0]
		if lang in ["fil", "en"]:
			Spirit.say(_region(), item[1], lang, interrupt and first)
		else:
			if interrupt and first:
				Spirit.stop()
			Spirit.say_word(lang, item[1])
		first = false


func _bubble(text: String, mine: bool, say: Array) -> void:
	var row := UI.hbox(8)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", UI._box(Color("fff2c2") if mine else Color("ffffff"), 16,
		UI.GOLD if mine else Color("8a63c2"), 2, 12))
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(4)
	bubble.add_child(v)
	if not mine:
		v.add_child(UI.label(Spirit.spirit_name(_region()), 16, Color("5a3591"), false, UI.font_body_black))
	v.add_child(UI.label(text, 18, UI.INK, true))
	if not say.is_empty():
		var again := UI.pill_button("LISTEN", Color("6b3fa0"), func(): _speak(say, true), 40, 14)
		again.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(again)
	if mine:
		var pad := Control.new()
		pad.custom_minimum_size.x = 60
		row.add_child(pad)
		row.add_child(bubble)
	else:
		var face := UI.image(UI.tex["guide_" + _region()], Vector2(48, 48))
		face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(face)
		row.add_child(bubble)
	row.name = "me" if mine else "spirit"
	chat_log.add_child(row)
	_scroll_to.call_deferred(row)
	while chat_log.get_child_count() > 12:
		var old := chat_log.get_child(0)
		chat_log.remove_child(old)
		old.queue_free()


func _set_chips(list: Array) -> void:
	for c in chips.get_children():
		chips.remove_child(c)
		c.queue_free()
	for s in list.slice(0, 6):
		var b := UI.pill_button(str(s), UI.INK_SOFT, func(): ask(str(s)), 40, 14)
		chips.add_child(b)

func _current_lang() -> String:
	return lang_codes[lang_picker.selected] if not lang_codes.is_empty() else ""


func _check_server() -> void:
	var ok: bool = await Spirit.check_server()
	if not is_inside_tree():
		return
	if ok:
		server_label.text = "MarianNMT translator connected (%s)." % ", ".join(Spirit.server_pairs)
	else:
		server_label.text = "MarianNMT translator not running: using the built-in dictionary."


func _show_tips() -> void:
	for c in tips_box.get_children():
		c.queue_free()
	for t in DB.get_tips(_current_lang()):
		tips_box.add_child(UI.label("• " + t.tip, 18, UI.INK, true))


func _translate() -> void:
	var direction := "to_english" if direction_picker.selected == 0 else "from_english"
	result_label.text = "..."
	source_label.text = ""
	var res: Dictionary = await Spirit.translate(_current_lang(), input.text, direction)
	if not is_inside_tree():
		return
	result_label.text = res.text if res.text != "" else "(no translation found)"
	source_label.text = Spirit.source_label(res.source)
	for c in matches_box.get_children():
		c.queue_free()
	for m in res.matches.slice(0, 5):
		var line := "%s = %s" % [m.native, m.english]
		if str(m.get("note", "")) != "":
			line += "  (%s)" % m.note
		matches_box.add_child(UI.label(line, 17, UI.INK, true))


## Pronunciation of the translation (or of what was typed, when it is in the language).
func _pronounce() -> void:
	var text := result_label.text if direction_picker.selected == 1 else input.text
	if text.strip_edges() == "" or text.begins_with("(") or text == "...":
		text = input.text
	Pronounce.show_panel(self, [text] if text.strip_edges() != "" else [], _current_lang(), _region())


func _check_grammar() -> void:
	for c in grammar_box.get_children():
		grammar_box.remove_child(c)
		c.queue_free()
	var r := GrammarChecker.check_free(grammar_input.text, DB.get_sentences(_current_lang()), DB.get_tips(_current_lang()))
	if r.ok:
		grammar_box.add_child(UI.label("Correct! \"%s\" means \"%s\"." % [r.match.native, r.match.english], 20, UI.GREEN, true, UI.font_body_black))
	elif r.get("known", false):
		grammar_box.add_child(UI.label("Did you mean: %s (\"%s\")?" % [r.match.native, r.match.english], 19, UI.INK, true, UI.font_body_black))
	for line in r.issues + r.notes:
		grammar_box.add_child(UI.label("• " + line, 18, UI.RED if not r.ok else UI.INK_SOFT, true))


func _scroll_to(c: Control) -> void:
	await get_tree().process_frame
	var p := c.get_parent()
	while p != null and not p is ScrollContainer:
		p = p.get_parent()
	if p is ScrollContainer and is_instance_valid(c):
		(p as ScrollContainer).ensure_control_visible(c)
