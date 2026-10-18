class_name GuidePages
extends RefCounted
## First-time tutorial and the in-game guide.
##
## - WELCOME: a walkthrough shown the first time a player reaches the map.
## - Screen tips: a short page or two the first time each screen is opened.
## - The Guide screen (GABAY on the map) shows every topic again at any time.
## What each player has seen is saved in the tutorial_seen table.

## Tests turn tutorials off so pop-ups don't cover the screens they click.
static var enabled := true

const WELCOME := [
	{"title": "Mabuhay, Guardian!", "image": "guide_luzon",
		"text": "I am Maelor, a Guiding Spirit. The three Language Cores of the Philippines (Luzon, Visayas and Mindanao) have gone dark. Learn their languages to make them shine again!"},
	{"title": "Three islands, three guides", "image": "guide_visayas",
		"text": "Tap an island on the Main Island map. Maelor guides you in Luzon, Marea in the Visayas and Lanora in Mindanao. Hover over (or press) an island to preview its language map."},
	{"title": "Choose a language", "image": "guide_mindanao",
		"text": "Each island has 10 languages. The first one is free: Tagalog, Cebuano or Bisaya. Unlock more with 20 Word Fragments, which you earn on Easy quizzes."},
	{"title": "Lesson first, then the quiz", "image": "guide_luzon",
		"text": "Every language has Easy, Medium and Hard. Read the lesson (ARALIN), then take the quiz. Pass a level to unlock the next one."},
	{"title": "Hearts, hints and BIGKAS", "image": "guide_visayas",
		"text": "You have 5 hearts: a wrong answer costs one. Tap your Guiding Spirit for a hint (2 per quiz). Tap BIGKAS to see and hear how the words are said. A right answer makes your hero strike the warrior!"},
	{"title": "Rewards you can spend", "image": "guide_mindanao",
		"text": "Easy gives Word Fragments (buy languages), Medium and Grammar give Phrase Crystals (unlock culture), Hard gives Cultural Relics (extra hints). Your first clear of a level pays the most."},
	{"title": "Culture and grammar", "image": "guide_luzon",
		"text": "Clearing a level for the first time reveals a cultural element of that language: its food, festivals, clothing, art, dances and music. After Easy, try the Grammar quiz: the grammar checker shows exactly what to fix."},
	{"title": "Your goal", "image": "guide_visayas",
		"text": "Pass Easy, Medium and Hard in one language of an island to restore its Core. Restore all three to unlock the Pearl of the Orient! You can read this guide again any time: tap GABAY on the map."},
]

## Tips shown the first time a screen opens.
const SCREEN_TIPS := {
	"map": [{"title": "The Main Island", "image": "guide_luzon",
		"text": "The four orbs at the top are the Language Cores and the Pearl; they light up as you restore them. Tap an island to begin. LEADERBOARD, STORIES, GUIDING SPIRIT and GABAY (this guide) are below the map."}],
	"language": [{"title": "Languages of this island", "image": "guide_visayas",
		"text": "Tap the map to see where each language is spoken. Tap a language to study it. Locked ones show an UNLOCK button: it turns on when you have 20 Word Fragments."}],
	"difficulty": [{"title": "Levels", "image": "guide_mindanao",
		"text": "Start with EASY. Read the ARALIN (lesson), then SIMULAN (start) the quiz. Easy lets you practise one word category at a time. The GRAMMAR quiz at the bottom opens after you pass Easy."}],
	"lesson": [{"title": "Lessons", "image": "guide_luzon",
		"text": "Say each word aloud before the quiz. The tips from your Guiding Spirit and the Culture corner at the bottom help you understand the language and its people."}],
	"quiz": [{"title": "Quiz time!", "image": "guide_visayas",
		"text": "Pick an answer and press I-TSEK (check). Tap your Guiding Spirit for a hint, and BIGKAS to hear how words are said. When your free hints run out, a Cultural Relic buys one more."}],
	"results": [{"title": "Results", "image": "guide_mindanao",
		"text": "Here are your score, rewards and the Word Fragments, Phrase Crystals and Cultural Relics you have. A new level or a cultural element may have been unlocked!"}],
	"gallery": [{"title": "Culture Gallery", "image": "guide_luzon",
		"text": "Every cultural element you uncover is kept here. Locked ones say how to reveal them, or unlock them now with 5 Phrase Crystals."}],
	"spirit": [{"title": "Your Guiding Spirit", "image": "guide_visayas",
		"text": "Translate words and phrases, check how to PRONOUNCE them, and write sentences for the GRAMMAR CHECKER to mark."}],
}

## Topics listed on the Guide screen.
const GUIDE_TOPICS := [
	["Welcome and the story", "welcome"], ["The Main Island", "map"], ["Languages", "language"],
	["Levels and grammar quiz", "difficulty"], ["Lessons", "lesson"], ["Quizzes, hints and BIGKAS", "quiz"],
	["Results and rewards", "results"], ["Culture Gallery", "gallery"], ["Guiding Spirit", "spirit"],
]


static func pages_for(key: String) -> Array:
	return WELCOME if key == "welcome" else SCREEN_TIPS.get(key, [])


## Shows [param key]'s pages once per player. Returns the pop-up or null.
static func maybe_show(parent: Control, key: String, on_done := Callable()) -> Control:
	if not enabled or not Game.is_logged_in():
		return null
	var uid := Game.user_id()
	if DB.has_seen_tutorial(uid, key):
		return null
	# The welcome walkthrough comes first; screen tips wait until it is seen.
	if key != "welcome" and not DB.has_seen_tutorial(uid, "welcome"):
		return null
	DB.mark_tutorial_seen(uid, key)
	return show(parent, pages_for(key), on_done)


## A page-by-page pop-up with NEXT / BACK / SKIP (and the back key closes it).
static func show(parent: Control, pages: Array, on_done := Callable()) -> Control:
	if pages.is_empty():
		return null
	var overlay := ColorRect.new()
	overlay.name = "TutorialPopup"
	overlay.color = Color(0, 0, 0, 0.62)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)
	Game.overlays.append(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var card := PanelContainer.new()
	var sb := UI._box(UI.PARCHMENT, 20, UI.GOLD, 6, 26)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(600, 0)
	center.add_child(card)
	var v := UI.vbox(14)
	card.add_child(v)
	var image := UI.image(null, Vector2(0, 150))
	v.add_child(image)
	var title := UI.label("", 30, UI.RED, true, UI.font_body_black)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var text := UI.label("", 21, UI.INK, true)
	text.custom_minimum_size.y = 150
	v.add_child(text)
	var dots := UI.label("", 22, UI.INK_SOFT)
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(dots)
	var row := UI.hbox(10)
	v.add_child(row)
	var back := UI.pill_button("BACK", UI.INK_SOFT, func(): pass, 56, 20)
	back.name = "back"
	var skip := UI.pill_button("SKIP", Color("8d8170"), func(): pass, 56, 20)
	skip.name = "skip"
	var next := UI.pill_button("NEXT", UI.GREEN, func(): pass, 56, 20)
	next.name = "next"
	for b in [back, skip, next]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)

	var state := {"page": 0}
	var close := func():
		Game.overlays.erase(overlay)
		if overlay.get_parent():
			overlay.get_parent().remove_child(overlay)
		overlay.queue_free()
		if on_done.is_valid():
			on_done.call()
	var render := func():
		var p: Dictionary = pages[state.page]
		image.texture = UI.tex.get(p.get("image", ""), null)
		image.visible = image.texture != null
		title.text = p.title
		text.text = p.text
		var d := ""
		for k in pages.size():
			d += "● " if k == state.page else "○ "
		dots.text = d.strip_edges() if pages.size() > 1 else ""
		back.disabled = state.page == 0
		back.visible = pages.size() > 1
		skip.visible = state.page < pages.size() - 1
		next.text = "NEXT" if state.page < pages.size() - 1 else "LET'S GO!"
	back.pressed.connect(func():
		state.page = maxi(0, state.page - 1)
		render.call())
	next.pressed.connect(func():
		if state.page < pages.size() - 1:
			state.page += 1
			render.call()
		else:
			close.call())
	skip.pressed.connect(close)
	render.call()
	return overlay
