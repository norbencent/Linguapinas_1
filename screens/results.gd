extends Control
## Evaluation, rewards and saved progress after a quiz.

const BADGE_TEXT := {
	"core_luzon": "The Luzon Core shines again!",
	"core_visayas": "The Visayas Core shines again!",
	"core_mindanao": "The Mindanao Core shines again!",
	"pearl": "All three cores are restored. You unlocked the Pearl of the Orient!",
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

	content.add_child(UI.ribbon("%s · %s" % [lang.name, Game.difficulty_name()], UI.REGION_COLORS[region]))
	content.add_child(UI.heading("Level complete!" if r.passed else "Out of hearts!", UI.GREEN if r.passed else UI.RED, 36))
	var guide := UI.hbox(12)
	guide.add_child(UI.image(UI.tex["guide_" + region], Vector2(90, 90)))
	var say := "%s: %s" % [UI.GUIDES[region], "Magaling, Tagapangalaga!" if r.passed
		else "Balikan natin ang aralin, then try again. Kaya mo 'yan!"]
	guide.add_child(UI.label(say, 20, UI.INK, true))
	content.add_child(guide)

	var card := UI.panel()
	var v := UI.vbox(8)
	card.add_child(v)
	v.add_child(UI.label("Score: %d" % r.score, 30, UI.RED, true, UI.font_body_black))
	v.add_child(UI.label("Correct: %d / %d" % [r.correct, r.total], 22, UI.INK, true))
	v.add_child(UI.hearts_row(r.hearts))
	if summary.reward_amount > 0:
		v.add_child(UI.label("+%d %s" % [summary.reward_amount, DB.REWARD_NAMES[summary.reward_kind]], 24, UI.GREEN, true, UI.font_body_black))
	if not summary.counts:
		v.add_child(UI.label("Category practice earns rewards, but only full quizzes unlock levels and count toward your score.", 16, UI.INK_SOFT, true))
	elif r.passed and Game.difficulty < DB.HARD:
		v.add_child(UI.label("%s unlocked!" % Game.difficulty_name(Game.difficulty + 1), 22, UI.GREEN, true))
	content.add_child(card)

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
