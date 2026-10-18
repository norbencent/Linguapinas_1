extends Control
## Evaluation, rewards and saved progress after a quiz.

const BADGE_TEXT := {
	"core_luzon": "The Luzon Pearl shines again!",
	"core_visayas": "The Visayas Pearl shines again!",
	"core_mindanao": "The Mindanao Pearl shines again!",
	"pearl": "All three island pearls are lit. You unlocked the Pearl of the Orient!",
}


func _ready() -> void:
	var r: Dictionary = Game.last_result
	if r.is_empty():
		Game.goto("map")
		return
	var lang := DB.get_language(Game.language_code)
	var region: String = lang.get("region_code", "luzon")
	var content := UI.page(self, UI.t("results"), "difficulty")
	var summary: Dictionary = r.summary
	Sound.play("win" if r.passed else "wrong")

	var level_name := "Grammar" if Game.category_code == Game.GRAMMAR else Game.difficulty_name()
	content.add_child(UI.ribbon("%s · %s" % [lang.name, level_name], UI.REGION_COLORS[region]))
	content.add_child(UI.heading("Level complete!" if r.passed else "Out of hearts!", UI.GREEN if r.passed else UI.RED, 36))
	var guide := UI.hbox(12)
	guide.add_child(UI.image(UI.tex["guide_" + region], Vector2(90, 90)))
	var say := "%s: %s" % [Spirit.spirit_name(region), Spirit.speak_line(region, "pass" if r.passed else "fail")]
	guide.add_child(UI.label(say, 20, UI.INK, true))
	content.add_child(guide)

	var card := UI.panel()
	var v := UI.vbox(8)
	card.add_child(v)
	v.add_child(UI.label("Score: %d" % r.score, 30, UI.RED, true, UI.font_body_black))
	v.add_child(UI.label("Correct: %d / %d" % [r.correct, r.total], 22, UI.INK, true))
	v.add_child(UI.hearts_row(r.hearts))
	if summary.reward_amount > 0:
		var kind: String = summary.reward_kind
		var got := UI.pill("+%d %s" % [summary.reward_amount, DB.REWARD_NAMES[kind]], UI.REWARD_COLORS[kind], 22)
		got.name = "reward"
		v.add_child(got)
		v.add_child(UI.label("First clear: full reward!" if summary.get("first_clear", false)
			else "Replays and practice earn half rewards. Clear a new level for the full amount.", 16, UI.INK_SOFT, true))
	v.add_child(UI.wallet(Game.user_id(), 16))
	if not summary.counts:
		v.add_child(UI.label("Category practice earns rewards, but only full quizzes unlock levels and count on the leaderboard.", 16, UI.INK_SOFT, true))
	elif r.passed and Game.difficulty < DB.HARD:
		v.add_child(UI.label("%s unlocked!" % Game.difficulty_name(Game.difficulty + 1), 22, UI.GREEN, true))
	content.add_child(card)

	var revealed: Dictionary = summary.get("revealed", {})
	if not revealed.is_empty():
		var reveal := UI.vbox(6)
		reveal.name = "revealed"
		var say2 := "%s: You uncovered a piece of %s culture!" % [UI.GUIDES[region], lang.name]
		reveal.add_child(UI.label(say2, 20, Color("5a3591"), true, UI.font_body_black))
		reveal.add_child(UI.culture_card(revealed, true))
		content.add_child(reveal)
		content.add_child(UI.gem_button(UI.t("gallery").to_upper(), "gold", func():
			Game.region_code = region
			Game.goto("gallery"), 84, 30))

	for badge in summary.new_badges:
		var bp := UI.panel(Color("fff2c2"), UI.GOLD)
		bp.add_child(UI.label(BADGE_TEXT.get(badge, badge) + " A new story is unlocked.", 22, UI.RED, true, UI.font_body_black))
		content.add_child(bp)
		UI.toast(BADGE_TEXT.get(badge, badge))

	if r.passed:
		if Game.difficulty < DB.HARD:
			content.add_child(UI.gem_button("%s: %s" % [UI.t("next"), Game.difficulty_name(Game.difficulty + 1)], "green", func():
				Game.difficulty += 1
				Game.goto("lesson"), 88, 30))
		content.add_child(UI.gem_button("PLAY AGAIN", "blue", func(): Game.goto("quiz"), 88, 30))
	else:
		content.add_child(UI.gem_button(UI.t("lesson"), "gold", func(): Game.goto("lesson"), 88, 30))
	if not summary.new_badges.is_empty():
		content.add_child(UI.gem_button(UI.t("stories").to_upper(), "purple", func(): Game.goto("stories"), 88, 30))
	content.add_child(UI.gem_button(UI.t("leaderboard").to_upper(), "red", func(): Game.goto("leaderboard"), 88, 30))
	var reward_pill := content.find_child("reward", true, false)
	Tutorial.show_steps(self, [{"id": "results_rewards", "target": reward_pill if reward_pill else card,
		"text": ("Well done! " if r.passed else "Out of hearts? No problem: review the lesson and try again. ")
			+ "Passing Easy quizzes earns Word Fragments: collect %s to unlock a new language. " % DB.cost_text(DB.LANGUAGE_COST)
			+ "Your first clear of each level also reveals a cultural element for the Gallery. Tap GABAY on the map any time for the full guide."}])
	_celebrate(summary.new_badges.duplicate())


## Plays the pearl animation for each newly lit pearl, one after another.
func _celebrate(badges: Array) -> void:
	if badges.is_empty():
		return
	var c := PearlCelebration.play(self, badges.pop_front())
	# Deferred: the finished animation is still being removed from the tree.
	c.finished.connect(func(): _celebrate(badges), CONNECT_DEFERRED)
