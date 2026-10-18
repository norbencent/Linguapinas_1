extends Node
## Look and feel of LinguaPinas (autoload "UI").
## Portrait (720x1280) layout built from the prototype art in assets/ui:
## tropical village background, ribbon title banner, gold-and-wood frame
## with parchment, gem buttons and the HOME / GALLERY / BACK / PROFILE bar.

# Parchment palette
const INK := Color("4a2511")          # body text on parchment
const INK_SOFT := Color("7a4a26")
const RED := Color("a3201b")
const GREEN := Color("3f8f2f")
const BLUE := Color("1f4f9c")
const GOLD := Color("e0a526")
const PARCHMENT := Color("f6ead0")
const CARD := Color("fbf3dc")
const ROW := Color("f3dc84")
const LOCKED := Color("b9ad96")
const WHITE := Color("fffaf0")
# Kept for older screens / tests
const ACCENT := GOLD
const TEXT := INK
const MUTED := INK_SOFT
const GOOD := GREEN
const BAD := RED

const REGION_COLORS := {"luzon": Color("c8231e"), "visayas": Color("1f56b3"), "mindanao": Color("e5a812")}
const GUIDES := {"luzon": "Maelor", "visayas": "Marea", "mindanao": "Lanora"}
const REGION_BUTTON_COLOR := {"luzon": "red", "visayas": "blue", "mindanao": "gold"}

var font_title: Font
var font_body: Font
var font_body_black: Font
var font_button: Font
var theme: Theme
var tex := {}

## UI language: "fil" (Filipino, like the prototype) or "en".
var lang := "fil"

const STRINGS := {
	"start": ["SIMULAN", "START"],
	"setting": ["SETTING", "SETTING"],
	"new_game": ["BAGONG LARO", "NEW GAME"],
	"continue": ["MAGPATULOY", "CONTINUE"],
	"save": ["I-SAVE", "SAVE"],
	"exit": ["LUMABAS", "EXIT"],
	"enter_name": ["Ilagay ang Iyong Pangalan", "Enter Your Name"],
	"name_intro": ["Sabihin ang iyong pangalan, bayani! Magsisimula na ang iyong paglalakbay sa LinguaPinas!",
		"Tell us your name, hero! Your journey in LinguaPinas begins now!"],
	"name_hint": ["Ilagay ang pangalan...", "Enter your name..."],
	"password_hint": ["Password (opsyonal)", "Password (optional)"],
	"password": ["Password", "Password"],
	"choose_avatar": ["Piliin ang iyong bayani", "Choose your hero"],
	"start_adventure": ["SIMULAN ANG PAKIKIPAGSAPALARAN", "START ADVENTURE"],
	"choose_player": ["Piliin ang Manlalaro", "Choose a Player"],
	"delete": ["BURAHIN", "DELETE"],
	"deleted": ["Nabura si %s.", "%s was deleted."],
	"no_players": ["Wala pang naka-save na laro. Pindutin ang Bagong Laro.", "No saved games yet. Tap New Game."],
	"language": ["WIKA", "LANGUAGE"],
	"music": ["LAKAS NG MUSIKA", "MUSIC VOLUME"],
	"sfx": ["LAKAS NG TUNOG", "SFX VOLUME"],
	"notification": ["ABISO", "NOTIFICATION"],
	"main_island": ["Pangunahing Isla", "Main Island"],
	"tap_island": ["Pumili ng isla", "Tap an island"],
	"question": ["TANONG", "QUESTION"],
	"check": ["I-TSEK", "CHECK"],
	"next": ["SUSUNOD", "NEXT"],
	"results_btn": ["RESULTA", "RESULTS"],
	"correct": ["Tama!", "Correct!"],
	"wrong": ["Mali. Ang sagot ay:", "Not quite. The answer is:"],
	"easy": ["MADALI", "EASY"],
	"medium": ["KATAMTAMAN", "MEDIUM"],
	"hard": ["MAHIRAP", "HARD"],
	"lesson": ["ARALIN", "LESSON"],
	"start_quiz": ["SIMULAN ANG PAGSUSULIT", "START QUIZ"],
	"points": ["PUNTOS", "POINTS"],
	"locked": ["NAKA-LOCK", "LOCKED"],
	"coming_soon": ["MALAPIT NA", "COMING SOON"],
	"home": ["HOME", "HOME"],
	"gallery": ["Gallery", "Gallery"],
	"profile": ["Profile", "Profile"],
	"leaderboard": ["Leaderboard", "Leaderboard"],
	"stories": ["Mga Kuwento", "Stories"],
	"spirit": ["Gabay na Espiritu", "Guiding Spirit"],
	"results": ["Resulta", "Results"],
	"settings_title": ["SETTING", "SETTING"],
	"hint": ["Tulong", "Hint"],
	"hearts": ["Puso", "Hearts"],
	"logout": ["MAG-LOG OUT", "LOG OUT"],
	"undo": ["BAWIIN", "UNDO"],
	"type_answer": ["Isulat ang sagot...", "Type your answer..."],
	"build_hint": ["Pindutin ang mga salita ayon sa tamang ayos...", "Tap the words in the right order..."],
}


func t(key: String) -> String:
	var pair: Array = STRINGS.get(key, [key, key])
	return pair[0] if lang == "fil" else pair[1]


func _ready() -> void:
	lang = DB.get_setting("ui_language", "fil")
	font_title = _font("CinzelDecorative-Black")
	font_body = _font("Cinzel-Bold")
	font_body_black = _font("Cinzel-Black")
	font_button = _font("LilitaOne-Regular")
	for n in ["bg_village", "logo", "badge", "back", "banner", "frame", "nav_bar", "quiz_scene",
			"btn_green", "btn_gold", "btn_red", "btn_blue", "btn_purple",
			"map_luzon", "map_visayas", "map_mindanao"]:
		tex[n] = _tex(n)
	for r in ["luzon", "visayas", "mindanao"]:
		for n in ["guide_%s", "btn_region_%s", "%s_boy", "%s_girl", "lang_map_%s"]:
			var key: String = n % r
			tex[key] = _tex(key)
	theme = _make_theme()
	get_tree().root.theme = theme


## Loads a font from assets/fonts; falls back to Godot's built-in font so a
## missing file never leaves a null font (which crashes the gem buttons).
func _font(name: String) -> Font:
	for ext in ["ttf", "otf", "woff2", "woff"]:
		var path := "res://assets/fonts/%s.%s" % [name, ext]
		if ResourceLoader.exists(path):
			return load(path)
	push_warning("Font missing: " + name)
	return ThemeDB.fallback_font


## Loads a picture from assets/ui; a missing file becomes a small placeholder.
func _tex(name: String) -> Texture2D:
	var path := "res://assets/ui/%s.png" % name
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("Picture missing: " + path)
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


func _box(color: Color, radius := 12, border := Color.TRANSPARENT, border_w := 2, pad := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	if border.a > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	return sb


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = font_body
	th.default_font_size = 24
	th.set_color("font_color", "Label", INK)
	# Plain buttons: small wooden buttons with a gold rim.
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c: Color = {"normal": Color("7b4a1e"), "hover": Color("8f5a27"), "pressed": Color("5e3714"),
			"disabled": Color("9c8f7a"), "focus": Color("7b4a1e")}[state]
		th.set_stylebox(state, "Button", _box(c, 14, GOLD, 3, 12))
	th.set_font("font", "Button", font_button)
	th.set_font_size("font_size", "Button", 26)
	th.set_color("font_color", "Button", WHITE)
	th.set_color("font_hover_color", "Button", Color("ffe08a"))
	th.set_color("font_pressed_color", "Button", WHITE)
	th.set_color("font_disabled_color", "Button", Color("eeeeee"))
	th.set_color("font_outline_color", "Button", Color("3b2208"))
	th.set_constant("outline_size", "Button", 6)
	th.set_stylebox("normal", "LineEdit", _box(WHITE, 10, Color("b08a55"), 3, 14))
	th.set_stylebox("focus", "LineEdit", _box(WHITE, 10, GOLD, 3, 14))
	th.set_color("font_color", "LineEdit", INK)
	th.set_color("font_placeholder_color", "LineEdit", Color("a08868"))
	th.set_color("caret_color", "LineEdit", INK)
	th.set_font("font", "LineEdit", font_body)
	th.set_font_size("font_size", "LineEdit", 24)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		th.set_stylebox(state, "OptionButton", _box(Color("4a2511"), 10, GOLD, 3, 12))
	th.set_color("font_color", "OptionButton", WHITE)
	th.set_color("font_hover_color", "OptionButton", Color("ffe08a"))
	th.set_font("font", "OptionButton", font_body_black)
	th.set_font_size("font_size", "OptionButton", 22)
	th.set_stylebox("panel", "PopupMenu", _box(PARCHMENT, 10, Color("8a5a2b"), 3, 10))
	th.set_color("font_color", "PopupMenu", INK)
	th.set_color("font_hover_color", "PopupMenu", RED)
	th.set_font_size("font_size", "PopupMenu", 26)
	th.set_stylebox("hover", "PopupMenu", _box(ROW, 6, Color.TRANSPARENT, 0, 6))
	th.set_stylebox("panel", "PanelContainer", _box(CARD, 14, Color("c9a76b"), 2, 16))
	th.set_stylebox("slider", "HSlider", _box(Color("4a2511"), 8, Color("2b1408"), 2, 6))
	th.set_stylebox("grabber_area", "HSlider", _box(Color("e8b923"), 8, Color("8a5a2b"), 2, 6))
	th.set_stylebox("grabber_area_highlight", "HSlider", _box(Color("f5cc3c"), 8, Color("8a5a2b"), 2, 6))
	th.set_icon("grabber", "HSlider", _diamond_icon(Color("f0c040"), 34))
	th.set_icon("grabber_highlight", "HSlider", _diamond_icon(Color("ffd860"), 34))
	th.set_stylebox("background", "ProgressBar", _box(Color("fffaf0"), 8, Color("b08a55"), 2, 0))
	th.set_stylebox("fill", "ProgressBar", _box(GREEN, 8, Color.TRANSPARENT, 0, 0))
	th.set_stylebox("panel", "AcceptDialog", _box(PARCHMENT, 16, GOLD, 4, 18))
	th.set_color("font_color", "CheckButton", INK)
	th.set_constant("v_grab_size", "VScrollBar", 0)
	th.set_stylebox("scroll", "VScrollBar", _box(Color(0, 0, 0, 0.06), 6, Color.TRANSPARENT, 0, 2))
	th.set_stylebox("grabber", "VScrollBar", _box(Color("b08a55"), 6, Color.TRANSPARENT, 0, 4))
	return th


func _diamond_icon(color: Color, s: int) -> ImageTexture:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := s / 2.0
	for y in s:
		for x in s:
			var d := absf(x - c + 0.5) + absf(y - c + 0.5)
			if d < c - 1:
				var shade := 1.0 - 0.35 * clampf((y - 2.0) / s, 0, 1)
				img.set_pixel(x, y, Color(color.r * shade, color.g * shade, color.b * shade))
			elif d < c:
				img.set_pixel(x, y, Color("6b3d12"))
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- layout

func background(root: Control) -> TextureRect:
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = tex.bg_village
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	return bg


## Round back button (left) and logo badge (right).
func top_bar(back: Variant = "") -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 84
	if back is Callable or (back is String and back != ""):
		Game.set_back(back)
		var b := TextureButton.new()
		b.texture_normal = tex.back
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(80, 80)
		b.pressed.connect(func(): _go_back(back))
		bar.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var badge := TextureRect.new()
	badge.texture = tex.badge
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.custom_minimum_size = Vector2(84, 84)
	bar.add_child(badge)
	return bar


func _go_back(back: Variant) -> void:
	Sound.click()
	Game.go(back)


## Ornate ribbon with a title written on it.
func banner(title: String, width := 600.0) -> Control:
	var holder := Control.new()
	var t: Texture2D = tex.banner
	var h := width * t.get_height() / t.get_width()
	holder.custom_minimum_size = Vector2(width, h)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var img := TextureRect.new()
	img.texture = t
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_SCALE
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(img)
	var l := Label.new()
	l.text = title
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font_title)
	var fs := 64
	while fs > 26 and font_title.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width * 0.76:
		fs -= 2
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Color("ffd23f"))
	l.add_theme_color_override("font_outline_color", Color("1b2a6b"))
	l.add_theme_constant_override("outline_size", 12)
	l.add_theme_color_override("font_shadow_color", Color(0.35, 0.12, 0.02, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.anchor_left = 0.1
	l.anchor_right = 0.9
	l.anchor_top = 0.30
	l.anchor_bottom = 0.82
	holder.add_child(l)
	return holder


## Gold pillar frame with parchment. Returns [frame, inner MarginContainer].
func frame() -> Array:
	var fr := NinePatchRect.new()
	fr.texture = tex.frame
	fr.patch_margin_left = 82
	fr.patch_margin_right = 82
	fr.patch_margin_top = 330
	fr.patch_margin_bottom = 120
	var inner := MarginContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("margin_left", 90)
	inner.add_theme_constant_override("margin_right", 90)
	inner.add_theme_constant_override("margin_top", 74)
	inner.add_theme_constant_override("margin_bottom", 78)
	fr.add_child(inner)
	return [fr, inner]


## HOME / GALLERY / BACK / PROFILE navigation bar.
func nav_bar(back: Variant) -> Control:
	var t: Texture2D = tex.nav_bar
	var bar := TextureRect.new()
	bar.texture = t
	bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.stretch_mode = TextureRect.STRETCH_SCALE
	bar.custom_minimum_size = Vector2(0, 720.0 * t.get_height() / t.get_width())
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	bar.add_child(row)
	if back is String and back == "":
		back = Game.BACK
	var targets: Array = ["map", "gallery", back, "profile"]
	for i in targets.size():
		var target: Variant = targets[i]
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, empty)
		b.add_theme_stylebox_override("hover", _box(Color(1, 1, 1, 0.12), 12, Color.TRANSPARENT, 0, 0))
		b.add_theme_stylebox_override("pressed", _box(Color(0, 0, 0, 0.2), 12, Color.TRANSPARENT, 0, 0))
		if i == 2:
			b.pressed.connect(func(): _go_back(target))
		else:
			b.pressed.connect(func():
				Sound.click()
				Game.goto(target))
		row.add_child(b)
	return bar


## Standard screen: background, top bar, banner, frame and nav bar.
## Returns the VBoxContainer inside the parchment for the screen content.
func page(root: Control, title: String, back: Variant = "map", opts := {}) -> VBoxContainer:
	background(root)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 6)
	root.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	margin.add_child(col)
	col.add_child(top_bar(back))
	# The banner overlaps the top of the frame, like in the prototype.
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(stack)
	var ban := banner(title)
	var bh: float = ban.custom_minimum_size.y
	var parts := frame()
	var fr: NinePatchRect = parts[0]
	fr.set_anchors_preset(Control.PRESET_FULL_RECT)
	fr.offset_top = bh - 50
	stack.add_child(fr)
	ban.anchor_left = 0.5
	ban.anchor_right = 0.5
	ban.offset_left = -ban.custom_minimum_size.x / 2
	ban.offset_right = ban.custom_minimum_size.x / 2
	ban.offset_bottom = bh
	stack.add_child(ban)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if opts.get("scroll", true):
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		parts[1].add_child(sc)
		sc.add_child(content)
	else:
		parts[1].add_child(content)
	if opts.get("nav", true):
		var nb := nav_bar(back)
		col.add_child(nb)
	return content


# ---------------------------------------------------------------- widgets

func label(text: String, size := 24, color := INK, wrap := false, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font != null:
		l.add_theme_font_override("font", font)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func heading(text: String, color := RED, size := 30) -> Label:
	var l := label(text, size, color, true, font_body_black)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Glossy gem button. color: green, gold, red, blue or purple.
func gem_button(text: String, color: String, on_pressed: Callable, height := 96, font_size := 36) -> GemButton:
	var b := GemButton.new()
	b.tex = tex["btn_" + color]
	b.label = text
	b.font_size = font_size
	b.custom_minimum_size = Vector2(0, height)
	b.pressed.connect(func():
		Sound.click()
		on_pressed.call())
	return b


## Simple wooden button (used where many small buttons are needed).
func button(text: String, on_pressed: Callable, min_width := 0, font_size := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = Vector2(min_width, 60)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		Sound.click()
		on_pressed.call())
	return b


## Flat rounded button in a solid color (like START / I-TSEK in the prototype).
func pill_button(text: String, color: Color, on_pressed: Callable, height := 64, font_size := 30) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", font_size)
	tint_button(b, color)
	b.pressed.connect(func():
		Sound.click()
		on_pressed.call())
	return b


func tint_button(b: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c := color
		if state == "hover":
			c = color.lightened(0.12)
		elif state == "pressed":
			c = color.darkened(0.2)
		var sb := _box(c, 32, color.darkened(0.35), 3, 10)
		sb.shadow_color = Color(0, 0, 0, 0.25)
		sb.shadow_size = 3
		sb.shadow_offset = Vector2(0, 3)
		b.add_theme_stylebox_override(state, sb)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(key, WHITE)
	b.add_theme_color_override("font_outline_color", color.darkened(0.55))
	b.add_theme_constant_override("outline_size", 6)


## Small rounded tag such as EASY / MEDIUM / HARD or TANONG 1.
func pill(text: String, color: Color, size := 22) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(color, 22, color.darkened(0.3), 2, 8))
	var l := label(text, size, WHITE, false, font_button)
	l.add_theme_color_override("font_outline_color", color.darkened(0.5))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return p


func panel(color := CARD, border := Color("c9a76b")) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(color, 14, border, 2, 16))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


## Yellow rounded row with a brown underline (language list style).
func row_panel(color := ROW) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _box(color, 30, Color.TRANSPARENT, 0, 14)
	sb.border_color = Color("6b3d12")
	sb.border_width_bottom = 5
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


func vbox(separation := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


func hbox(separation := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


func center(child: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.add_child(child)
	return c


func line_edit(placeholder: String, secret := false) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.custom_minimum_size = Vector2(0, 64)
	return e


func image(texture: Texture2D, size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = size
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return r


## A glowing orb used for the Language Cores, the Pearl and hearts.
func orb(color: Color, lit: bool, diameter := 56) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(diameter, diameter)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(diameter / 2)
	sb.bg_color = color if lit else Color("8d8170")
	sb.border_color = Color("f6d36b") if lit else Color("5f5446")
	sb.set_border_width_all(maxi(2, diameter / 12))
	if lit:
		sb.shadow_color = Color(color, 0.55)
		sb.shadow_size = maxi(3, diameter / 4)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


func hearts_row(hearts: int, max_hearts := 5) -> HBoxContainer:
	var row := hbox(6)
	for i in max_hearts:
		row.add_child(orb(Color("e0303a"), i < hearts, 30))
	return row


## Gem icons showing which difficulties are completed.
func level_gems(progress: Dictionary) -> HBoxContainer:
	var row := hbox(4)
	var colors := [GREEN, BLUE, RED]
	for d in [1, 2, 3]:
		var icon := TextureRect.new()
		icon.texture = _diamond_icon(colors[d - 1] if progress[d].completed else Color("cfc3a8"), 26)
		row.add_child(icon)
	return row


func character_texture(region: String, avatar: String) -> Texture2D:
	return tex["%s_%s" % [region if region in GUIDES else "luzon", avatar if avatar in ["boy", "girl"] else "boy"]]


func stat_lines(user_id: int) -> VBoxContainer:
	var v := vbox(4)
	var rewards := DB.get_rewards(user_id)
	for kind in DB.REWARD_NAMES:
		v.add_child(label("%s: %d" % [DB.REWARD_NAMES[kind], rewards[kind]], 22, RED, true))
	v.add_child(label("Score: %d" % DB.get_total_score(user_id), 22, RED, true))
	return v


const REWARD_COLORS := {"word_fragment": Color("2f6fb5"), "phrase_crystal": Color("7d3fa8"),
	"cultural_relic": Color("b5741a")}
const REWARD_SHORT := {"word_fragment": "Fragments", "phrase_crystal": "Crystals", "cultural_relic": "Relics"}
const REWARD_USE := {
	"word_fragment": "Earned on Easy. Spend %d to unlock a new language.",
	"phrase_crystal": "Earned on Medium and in Grammar quizzes. Spend %d to unlock a culture item in the Gallery.",
	"cultural_relic": "Earned on Hard. Spend %d for an extra hint from your Guiding Spirit during a quiz.",
}


## The player's three reward balances as coloured pills.
func wallet(user_id: int, size := 18) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	var have := DB.get_rewards(user_id)
	for kind in DB.REWARD_NAMES:
		var p := pill("%s %d" % [REWARD_SHORT[kind], have[kind]], REWARD_COLORS[kind], size)
		p.name = kind
		row.add_child(p)
	return row


## One line per reward explaining what it buys.
func reward_guide() -> VBoxContainer:
	var v := vbox(4)
	var costs := {"word_fragment": DB.LANGUAGE_COST.word_fragment, "phrase_crystal": DB.CULTURE_COST.phrase_crystal,
		"cultural_relic": DB.HINT_COST.cultural_relic}
	for kind in DB.REWARD_NAMES:
		var h := hbox(8)
		var p := pill(REWARD_SHORT[kind], REWARD_COLORS[kind], 15)
		p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(p)
		var l := label(REWARD_USE[kind] % costs[kind], 16, INK, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		v.add_child(h)
	return v


## A culture item's picture from assets/culture/, or null if there is none.
func culture_picture(item: Dictionary, height := 180) -> TextureRect:
	var image := str(item.get("image", ""))
	var path := "res://assets/culture/%s.png" % image
	if image == "" or not ResourceLoader.exists(path):
		return null
	var r := TextureRect.new()
	r.texture = load(path)
	# Full width of the card, height following the picture's shape.
	r.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.custom_minimum_size = Vector2(0, height)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Card for a culture item. Locked items show how to unlock them; pass
## [param on_buy] to add an unlock button.
func culture_card(item: Dictionary, unlocked: bool, on_buy := Callable()) -> PanelContainer:
	var region_color: Color = REGION_COLORS.get(item.region_code, RED)
	var card := panel(CARD if unlocked else Color("d9d2c2"), Color("8a5a2b") if unlocked else Color("8d8170"))
	card.name = "culture_" + str(item.get("image", ""))
	var v := vbox(4)
	card.add_child(v)
	var pic := culture_picture(item)
	if pic:
		if not unlocked:
			pic.modulate = Color(0.35, 0.33, 0.3)
		v.add_child(pic)
	var tags := hbox(6)
	v.add_child(tags)
	tags.add_child(pill(str(item.kind).to_upper(), region_color if unlocked else Color("8d8170"), 16))
	var lang := DB.get_language(str(item.get("language_code", "")))
	if not lang.is_empty():
		tags.add_child(pill(lang.name, INK_SOFT if unlocked else Color("8d8170"), 16))
	if unlocked:
		v.add_child(label(item.title, 26, RED, true, font_body_black))
		v.add_child(label(item.description, 18, INK, true))
	else:
		v.add_child(label("%s · %s" % [t("locked"), item.kind], 24, Color("5f5446"), true, font_body_black))
		var how := "Clear a level in %s to reveal it" % lang.name if not lang.is_empty() \
			else "Clear levels in %s to reveal it" % DB.get_region(item.region_code).get("name", "")
		v.add_child(label("%s, or unlock it now for %s." % [how, DB.cost_text(DB.CULTURE_COST)], 17, Color("5f5446"), true))
		if on_buy.is_valid():
			var b := pill_button("UNLOCK · %d %s" % [DB.CULTURE_COST.phrase_crystal, REWARD_SHORT.phrase_crystal],
				REWARD_COLORS.phrase_crystal, on_buy, 52, 18)
			b.name = "unlock"
			b.disabled = not DB.can_afford(Game.user_id(), DB.CULTURE_COST)
			v.add_child(b)
	return card


## Kept for compatibility with older screens.
func rewards_bar(user_id: int) -> Control:
	return stat_lines(user_id)


func message(parent: Node, title: String, text: String) -> void:
	var d := AcceptDialog.new()
	d.title = title
	d.dialog_text = text
	d.dialog_autowrap = true
	d.min_size = Vector2i(560, 0)
	parent.add_child(d)
	d.get_label().add_theme_color_override("font_color", INK)
	d.popup_centered()
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)


## Short notice at the top of the screen (respects the Notification setting).
func toast(text: String) -> void:
	if not Game.notifications_on():
		return
	var layer := CanvasLayer.new()
	layer.layer = 50
	get_tree().root.add_child(layer)
	var p := panel(Color("2a1608"), GOLD)
	p.set_anchors_preset(Control.PRESET_TOP_WIDE)
	p.offset_left = 40
	p.offset_right = -40
	p.offset_top = 110
	p.theme = theme
	var l := label(text, 24, Color("ffe08a"), true, font_body_black)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	layer.add_child(p)
	var tw := layer.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(layer.queue_free)


## Places [param node] over the rectangle [param img_rect] (in background
## image pixels of the 282x610 prototype screen) on a cover-scaled background.
func place_on_background(root: Control, node: Control, img_rect: Rect2) -> void:
	var src := Vector2(282, 610)
	var update := func():
		var view := root.size
		var s := maxf(view.x / src.x, view.y / src.y)
		var off := (view - src * s) / 2.0
		node.position = off + img_rect.position * s
		node.size = img_rect.size * s
	root.resized.connect(update)
	update.call_deferred()


## Makes a whole panel tappable by laying an invisible button over it.
func clickable(p: Control, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, empty)
	b.add_theme_stylebox_override("hover", _box(Color(1, 1, 1, 0.18), 28, Color.TRANSPARENT, 0, 0))
	b.add_theme_stylebox_override("pressed", _box(Color(0, 0, 0, 0.12), 28, Color.TRANSPARENT, 0, 0))
	b.pressed.connect(func():
		Sound.click()
		on_pressed.call())
	p.add_child(b)
	return b


## Ribbon header in a region color, like the "LANGUAGE" header in the prototype.
func ribbon(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _box(color, 8, Color("e8b923"), 3, 8)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	p.add_theme_stylebox_override("panel", sb)
	var l := label(text, 28, WHITE, false, font_body_black)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", color.darkened(0.6))
	l.add_theme_constant_override("outline_size", 6)
	p.add_child(l)
	return p
