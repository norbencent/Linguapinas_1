extends Control
## Title screen: logo, START and SETTING (prototype screen 1).


func _ready() -> void:
	UI.background(self)
	var logo := UI.image(UI.tex.logo, Vector2.ZERO)
	add_child(logo)
	UI.place_on_background(self, logo, Rect2(12, 156, 252, 102))
	var start := UI.gem_button(UI.t("start"), "green", func(): Game.goto("menu"), 96, 48)
	add_child(start)
	UI.place_on_background(self, start, Rect2(36, 294, 210, 84))
	var setting := UI.gem_button(UI.t("setting"), "gold", func(): Game.open_settings("title"), 96, 48)
	add_child(setting)
	UI.place_on_background(self, setting, Rect2(34, 404, 212, 88))
	_badge()


func _badge() -> void:
	var badge := UI.image(UI.tex.badge, Vector2(84, 84))
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -104
	badge.offset_right = -20
	badge.offset_top = 20
	badge.offset_bottom = 104
	add_child(badge)
