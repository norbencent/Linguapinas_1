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
		"text": "I am Maelor, a Guiding Spirit. The three island pearls of the Philippines (the Luzon, Visayas and Mindanao Pearls) have gone dark. Learn their languages to make them shine again!", "title_fil": "Mabuhay, Guardian!", "text_fil": "Ako si Maelor, isang Gabay na Espiritu. Nawalan ng liwanag ang tatlong perlas ng mga isla ng Pilipinas (ang mga Perlas ng Luzon, Visayas at Mindanao). Pag-aralan ang kanilang mga wika para muli silang magningning!"},
	{"title": "Three islands, three guides", "image": "guide_visayas",
		"text": "Tap an island on the Main Island map. Maelor guides you in Luzon, Marea in the Visayas and Lanora in Mindanao. Hold your finger on (or point at) an island to see its language map and languages.", "title_fil": "Tatlong isla, tatlong gabay", "text_fil": "Pindutin ang isang isla sa mapa ng Pangunahing Isla. Si Maelor ang gabay mo sa Luzon, si Marea sa Visayas at si Lanora sa Mindanao. Diinan (o ituro) ang isang isla para makita ang mapa at mga wika nito."},
	{"title": "Choose a language", "image": "guide_mindanao",
		"text": "Each island has 10 languages. The first one is free: Tagalog, Cebuano or Bisaya. Unlock more with 5 Word Fragments, which you earn on Easy quizzes.", "title_fil": "Pumili ng wika", "text_fil": "May 10 wika ang bawat isla. Libre ang una: Tagalog, Cebuano o Bisaya. Magbukas ng iba pa gamit ang 5 Word Fragments, na makukuha mo sa mga pagsusulit na Madali."},
	{"title": "Lesson first, then the quiz", "image": "guide_luzon",
		"text": "Every language has Easy, Medium and Hard. Read the LESSON (ARALIN), then take the quiz. Pass a level to unlock the next one.", "title_fil": "Aralin muna, saka pagsusulit", "text_fil": "May Madali, Katamtaman at Mahirap ang bawat wika. Basahin ang ARALIN, saka sagutan ang pagsusulit. Ipasa ang isang antas para mabuksan ang susunod."},
	{"title": "Hearts, hints and BIGKAS", "image": "guide_visayas",
		"text": "You have 5 hearts: a wrong answer costs one. Tap your Guiding Spirit for a hint (2 per quiz). Tap SAY IT (BIGKAS) to see how the words are said. A right answer makes your hero strike the warrior!", "title_fil": "Puso, tulong at BIGKAS", "text_fil": "May 5 puso ka: isang puso ang nawawala sa bawat maling sagot. Pindutin ang iyong Gabay na Espiritu para sa tulong (2 bawat pagsusulit). Pindutin ang BIGKAS para makita kung paano binibigkas ang mga salita. Sa bawat tamang sagot, tinatamaan ng iyong bayani ang mandirigma!"},
	{"title": "Rewards you can spend", "image": "guide_mindanao",
		"text": "Easy gives Word Fragments (buy languages), Medium and Grammar give Phrase Crystals (unlock culture), Hard gives Cultural Relics (extra hints). Your first clear of a level pays the most.", "title_fil": "Mga gantimpalang magagamit", "text_fil": "Word Fragments ang bigay ng Madali (pambili ng wika), Phrase Crystals ang bigay ng Katamtaman at Gramatika (pambukas ng kultura), at Cultural Relics ang bigay ng Mahirap (dagdag na tulong). Pinakamalaki ang gantimpala sa unang pagpasa sa isang antas."},
	{"title": "Culture and grammar", "image": "guide_luzon",
		"text": "Clearing a level for the first time reveals a cultural element of that language: its food, festivals, clothing, art, dances and music. After Easy, try the Grammar quiz: the grammar checker shows exactly what to fix.", "title_fil": "Kultura at gramatika", "text_fil": "Sa unang pagpasa sa isang antas, may nabubuksang elemento ng kultura ng wikang iyon: pagkain, pista, kasuotan, sining, sayaw at musika. Pagkatapos ng Madali, subukan ang pagsusulit sa Gramatika: ipinapakita ng grammar checker kung ano mismo ang dapat ayusin."},
	{"title": "Your goal", "image": "guide_visayas",
		"text": "Master EVERY language of an island (pass Easy, Medium and Hard in each) to light up its pearl: the Luzon, Visayas and Mindanao Pearls. Light all three to unlock the Pearl of the Orient! You can read this guide again any time: tap GABAY on the map.", "title_fil": "Ang iyong layunin", "text_fil": "I-master ang BAWAT wika ng isang isla (ipasa ang Madali, Katamtaman at Mahirap sa bawat isa) para sumindi ang perlas nito: ang mga Perlas ng Luzon, Visayas at Mindanao. Sindihan ang tatlo para mabuksan ang Perlas ng Silangan! Mababasa mo muli ang gabay na ito anumang oras: pindutin ang GABAY sa mapa."},
]

## Tips shown the first time a screen opens.
const SCREEN_TIPS := {
	"map": [{"title": "The Main Island", "image": "guide_luzon",
		"text": "The four orbs at the top are the island pearls and the Pearl of the Orient. Each island pearl lights up when you master all of its languages; the numbers show your progress. Tap an island to begin. LEADERBOARD, STORIES, GUIDING SPIRIT, GABAY (this guide) and SETTINGS are below the map.", "title_fil": "Ang Pangunahing Isla", "text_fil": "Ang apat na bilog sa itaas ay ang mga perlas ng isla at ang Perlas ng Silangan. Sumisindi ang perlas ng isang isla kapag na-master mo ang lahat ng wika nito; ipinapakita ng mga numero ang iyong progreso. Pindutin ang isang isla para magsimula. Nasa ilalim ng mapa ang Leaderboard, Mga Kuwento, Gabay na Espiritu, GABAY (ang gabay na ito) at PAGSASAAYOS."}],
	"language": [{"title": "Languages of this island", "image": "guide_visayas",
		"text": "Tap the map to see where each language is spoken. Tap a language to study it. Locked ones show an UNLOCK button: it turns on when you have 5 Word Fragments.", "title_fil": "Mga wika ng islang ito", "text_fil": "Pindutin ang mapa para makita kung saan sinasalita ang bawat wika. Pindutin ang isang wika para pag-aralan ito. May UNLOCK na button ang mga nakakandado: gagana ito kapag may 5 Word Fragments ka na."}],
	"difficulty": [{"title": "Levels", "image": "guide_mindanao",
		"text": "Start with EASY. Read the LESSON, then START the quiz. Easy lets you practise one word category at a time. The GRAMMAR quiz at the bottom opens after you pass Easy.", "title_fil": "Mga antas", "text_fil": "Magsimula sa MADALI. Basahin ang ARALIN, saka SIMULAN ang pagsusulit. Sa Madali, maaari kang magsanay ng isang kategorya ng salita sa bawat pagkakataon. Nagbubukas ang pagsusulit sa GRAMATIKA sa ibaba pagkatapos mong maipasa ang Madali."}],
	"lesson": [{"title": "Lessons", "image": "guide_luzon",
		"text": "Say each word aloud before the quiz. The tips from your Guiding Spirit and the Culture corner at the bottom help you understand the language and its people.", "title_fil": "Mga aralin", "text_fil": "Bigkasin nang malakas ang bawat salita bago ang pagsusulit. Ang mga tip ng iyong Gabay na Espiritu at ang Sulok ng Kultura sa ibaba ay tutulong sa iyong maunawaan ang wika at ang mga taong nagsasalita nito."}],
	"quiz": [{"title": "Quiz time!", "image": "guide_visayas",
		"text": "Pick an answer and press CHECK. Tap your Guiding Spirit for a hint, and SAY IT to see how words are said. When your free hints run out, a Cultural Relic buys one more.", "title_fil": "Oras na ng pagsusulit!", "text_fil": "Pumili ng sagot at pindutin ang I-TSEK. Pindutin ang iyong Gabay na Espiritu para sa tulong, at ang BIGKAS para makita kung paano binibigkas ang mga salita. Kapag naubos ang libreng tulong, makakabili ka ng isa pa gamit ang isang Cultural Relic."}],
	"results": [{"title": "Results", "image": "guide_mindanao",
		"text": "Here are your score, rewards and the Word Fragments, Phrase Crystals and Cultural Relics you have. A new level or a cultural element may have been unlocked!", "title_fil": "Resulta", "text_fil": "Narito ang iyong iskor, mga gantimpala, at ang Word Fragments, Phrase Crystals at Cultural Relics na mayroon ka. Maaaring may nabuksang bagong antas o elemento ng kultura!"}],
	"gallery": [{"title": "Culture Gallery", "image": "guide_luzon",
		"text": "Every cultural element you uncover is kept here. Locked ones say how to reveal them, or unlock them now with 5 Phrase Crystals.", "title_fil": "Gallery ng Kultura", "text_fil": "Narito ang bawat elemento ng kultura na iyong natuklasan. Sinasabi ng mga nakakandado kung paano sila mabubuksan, o buksan na sila ngayon gamit ang 5 Phrase Crystals."}],
	"spirit": [{"title": "Your Guiding Spirit", "image": "guide_visayas",
		"text": "Ask your Guiding Spirit anything about the language in the chat: it answers in its own style. Below the chat: the translator, PRONOUNCE, and the GRAMMAR CHECKER that marks the sentences you write.", "title_fil": "Ang iyong Gabay na Espiritu", "text_fil": "Itanong sa iyong Gabay na Espiritu ang kahit ano tungkol sa wika sa chat: sasagot ito sa sarili nitong paraan. Sa ilalim ng chat: ang tagasalin, ang PRONOUNCE, at ang GRAMMAR CHECKER na nagsusuri ng mga pangungusap na isinulat mo."}],
	"grammar": [
		{"title": "Grammar quiz", "image": "guide_mindanao",
			"text": "The Grammar quiz opens after you pass Easy. You will choose the correct sentence, fill in the missing word, and write whole sentences in the language.", "title_fil": "Pagsusulit sa Gramatika", "text_fil": "Nagbubukas ang pagsusulit sa Gramatika pagkatapos mong maipasa ang Madali. Pipili ka ng tamang pangungusap, pupunan ang nawawalang salita, at susulat ng buong pangungusap sa wika."},
		{"title": "The grammar checker", "image": "guide_luzon",
			"text": "When you write a sentence, the grammar checker compares it with real sentences of the language and tells you exactly what to fix: a missing word, the wrong marker, or the word order. Grammar quizzes pay Phrase Crystals.", "title_fil": "Ang grammar checker", "text_fil": "Kapag sumulat ka ng pangungusap, ikinukumpara ito ng grammar checker sa mga totoong pangungusap ng wika at sinasabi kung ano mismo ang dapat ayusin: nawawalang salita, maling pananda, o maling pagkakasunod-sunod ng salita. Phrase Crystals ang gantimpala ng mga pagsusulit sa Gramatika."}],
	"leaderboard": [{"title": "Leaderboard", "image": "guide_mindanao",
		"text": "Every Guardian on this device is ranked by the total of their best scores. Pick an island to see who leads there. Replay levels with more hearts left to raise your best score.", "title_fil": "Leaderboard", "text_fil": "Niraranggo ang bawat Guardian sa device na ito ayon sa kabuuan ng kanilang pinakamataas na iskor. Pumili ng isla para makita kung sino ang nangunguna roon. Ulitin ang mga antas nang may mas maraming natitirang puso para tumaas ang iyong pinakamataas na iskor."}],
	"stories": [{"title": "Stories", "image": "guide_luzon",
		"text": "Legends of the islands. Each island's story unlocks when you light its pearl, and the last story unlocks when all three pearls shine.", "title_fil": "Mga Kuwento", "text_fil": "Mga alamat ng mga isla. Nabubuksan ang kuwento ng bawat isla kapag sinindihan mo ang perlas nito, at ang huling kuwento kapag nagningning ang tatlong perlas."}],
	"profile": [{"title": "Your profile", "image": "guide_visayas",
		"text": "Your hero, play time, rewards, badges and your progress on every island and language. GALLERY and SETTINGS are here too, and LOG OUT lets another player use the game.", "title_fil": "Ang iyong profile", "text_fil": "Ang iyong bayani, oras ng paglalaro, mga gantimpala, badge, at ang iyong progreso sa bawat isla at wika. Nandito rin ang GALLERY at PAGSASAAYOS, at ang MAG-LOG OUT para makapaglaro ang ibang manlalaro."}],
	"settings": [{"title": "Settings", "image": "guide_mindanao",
		"text": "Choose Filipino or English for the game, set the music and sound volume, and turn notices on or off, then tap SAVE. EXIT leaves without changing anything.", "title_fil": "Pagsasaayos", "text_fil": "Piliin ang Filipino o English para sa laro, itakda ang lakas ng musika at tunog, at buksan o isara ang mga abiso, saka pindutin ang I-SAVE. Ang LUMABAS ay aalis nang walang binabago."}],
	"controls": [
		{"title": "Moving around", "image": "guide_luzon",
			"text": "The bar at the bottom of most screens has HOME (the Main Island map), GALLERY, BACK and PROFILE. The arrow at the top left also goes back.", "title_fil": "Paggalaw sa laro", "text_fil": "Sa ibaba ng karamihan ng screen ay may HOME (ang mapa ng Pangunahing Isla), GALLERY, BACK at PROFILE. Bumabalik din ang palaso sa kaliwang itaas."},
		{"title": "The back key", "image": "guide_visayas",
			"text": "On a phone, the Android back button works the same as BACK. On a computer, press Esc. If a pop-up is open, the back key closes it first.", "title_fil": "Ang back button", "text_fil": "Sa telepono, katulad ng BACK ang back button ng Android. Sa computer, pindutin ang Esc. Kung may bukas na pop-up, iyon muna ang isinasara ng back button."}],
	"pronounce": [{"title": "BIGKAS: saying the words", "image": "guide_mindanao",
		"text": "Tap SAY IT (BIGKAS) under your Guiding Spirit in a quiz (or PRONOUNCE in the Guiding Spirit screen). It splits each word into syllables, shows the stressed one in CAPITALS, and gives sound tips.", "title_fil": "BIGKAS: pagbigkas ng mga salita", "text_fil": "Pindutin ang BIGKAS sa ilalim ng iyong Gabay na Espiritu sa pagsusulit (o ang PRONOUNCE sa screen ng Gabay na Espiritu). Hinahati nito ang bawat salita sa mga pantig, ipinapakita sa MALALAKING TITIK ang may diin, at nagbibigay ng mga tip sa pagbigkas."}],
	"rewards": [
		{"title": "Earning rewards", "image": "guide_luzon",
			"text": "Easy quizzes give Word Fragments, Medium and Grammar quizzes give Phrase Crystals, and Hard quizzes give Cultural Relics. Your first clear of a level pays the most; replays pay half.", "title_fil": "Pagkuha ng gantimpala", "text_fil": "Word Fragments ang bigay ng mga pagsusulit na Madali, Phrase Crystals ang sa Katamtaman at Gramatika, at Cultural Relics ang sa Mahirap. Pinakamalaki ang gantimpala sa unang pagpasa sa isang antas; kalahati lamang kapag inulit."},
		{"title": "Spending rewards", "image": "guide_visayas",
			"text": "5 Word Fragments unlock a new language. 5 Phrase Crystals unlock a cultural element in the Gallery. 1 Cultural Relic buys an extra hint when your free hints run out.", "title_fil": "Paggamit ng gantimpala", "text_fil": "Nagbubukas ng bagong wika ang 5 Word Fragments. Nagbubukas ng elemento ng kultura sa Gallery ang 5 Phrase Crystals. Bumibili ng dagdag na tulong ang 1 Cultural Relic kapag naubos na ang libreng tulong."}],
	"pearls": [{"title": "Island pearls", "image": "guide_mindanao",
		"text": "A pearl lights up only when EVERY language of its island is mastered (Easy, Medium and Hard passed). Watch it glow on the map! Light Luzon, Visayas and Mindanao to awaken the Pearl of the Orient.", "title_fil": "Mga perlas ng isla", "text_fil": "Sumisindi lamang ang isang perlas kapag na-master ang BAWAT wika ng isla nito (naipasa ang Madali, Katamtaman at Mahirap). Panoorin itong magningning sa mapa! Sindihan ang Luzon, Visayas at Mindanao para gisingin ang Perlas ng Silangan."}],
	"saving": [{"title": "Saving and players", "image": "guide_luzon",
		"text": "The game saves by itself after every lesson and quiz, and works without the internet. Each Guardian has their own progress. Use CONTINUE on the menu to pick your Guardian; the delete button there removes a Guardian and all of their progress.", "title_fil": "Pag-save at mga manlalaro", "text_fil": "Kusang nagse-save ang laro pagkatapos ng bawat aralin at pagsusulit, at gumagana ito kahit walang internet. May sariling progreso ang bawat Guardian. Gamitin ang MAGPATULOY sa menu para piliin ang iyong Guardian; ang BURAHIN doon ay nagtatanggal ng isang Guardian at ng lahat ng progreso nito."},
		{"title": "Backups", "image": "guide_visayas",
			"text": "A backup is made every day and before a Guardian is deleted. If the saved game is ever damaged, it is repaired from the newest backup when the game starts. After 30 minutes of play, your Guiding Spirit reminds you to take a short break.", "title_fil": "Mga backup", "text_fil": "May ginagawang backup araw-araw at bago burahin ang isang Guardian. Kung masira man ang naka-save na laro, inaayos ito mula sa pinakabagong backup pagbukas ng laro. Pagkatapos ng 30 minutong paglalaro, ipapaalala ng iyong Gabay na Espiritu na magpahinga sandali."}],
}

## Topics listed on the Guide screen: [English name, key, Filipino name].
const GUIDE_TOPICS := [
	["Welcome and the story", "welcome", "Pagbati at ang kuwento"], ["Moving around", "controls", "Paggalaw sa laro"], ["The Main Island", "map", "Ang Pangunahing Isla"],
	["Languages", "language", "Mga wika"], ["Levels", "difficulty", "Mga antas"], ["Lessons", "lesson", "Mga aralin"],
	["Quizzes and hints", "quiz", "Pagsusulit at tulong"], ["BIGKAS: pronunciation", "pronounce", "BIGKAS: pagbigkas"], ["Grammar quiz and checker", "grammar", "Pagsusulit sa Gramatika at checker"],
	["Results", "results", "Resulta"], ["Rewards: earning and spending", "rewards", "Gantimpala: pagkuha at paggamit"], ["Culture Gallery", "gallery", "Gallery ng Kultura"],
	["Guiding Spirit", "spirit", "Gabay na Espiritu"], ["Island pearls", "pearls", "Mga perlas ng isla"], ["Stories", "stories", "Mga Kuwento"],
	["Leaderboard", "leaderboard", "Leaderboard"], ["Your profile", "profile", "Ang iyong profile"], ["Settings", "settings", "Pagsasaayos"],
	["Saving and players", "saving", "Pag-save at mga manlalaro"],
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
	var back := UI.pill_button(UI.tx("BUMALIK", "BACK"), UI.INK_SOFT, func(): pass, 56, 20)
	back.name = "back"
	var skip := UI.pill_button(UI.tx("LAKTAWAN", "SKIP"), Color("8d8170"), func(): pass, 56, 20)
	skip.name = "skip"
	var next := UI.pill_button(UI.tx("SUSUNOD", "NEXT"), UI.GREEN, func(): pass, 56, 20)
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
		title.text = p.get("title_fil", p.title) if UI.lang == "fil" else p.title
		text.text = p.get("text_fil", p.text) if UI.lang == "fil" else p.text
		var d := ""
		for k in pages.size():
			d += "● " if k == state.page else "○ "
		dots.text = d.strip_edges() if pages.size() > 1 else ""
		back.disabled = state.page == 0
		back.visible = pages.size() > 1
		skip.visible = state.page < pages.size() - 1
		next.text = UI.tx("SUSUNOD", "NEXT") if state.page < pages.size() - 1 else UI.tx("TARA NA!", "LET'S GO!")
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
