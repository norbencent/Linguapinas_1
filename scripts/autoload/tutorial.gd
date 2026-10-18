extends Node
## First-time tutorial (autoload "Tutorial").
##
## An animated hand points at what to tap next and the Guiding Spirit
## explains it in a speech bubble. Screens call [method show_steps] with
## their steps; a step is shown only while the tutorial is running and the
## step has not been done yet. The overlay never blocks the screen: the
## player taps the real button under the hand.
##
## The welcome story pages and the Guide screen (GABAY) are in
## scripts/ui/guide_pages.gd; the hand tour starts after the welcome pages.
##
## Before anyone has played, the guest steps (title, menu, name) run once.
## A new player then gets the player steps (map -> island -> language ->
## level -> lesson -> quiz -> results). Progress is saved in the settings
## table, so it survives restarts. SKIP stops it; the Guide (GABAY) can
## replay it.

const HAND_TIP := Vector2(60, 4)   # fingertip position in tutorial_hand.png (128x128)
const HAND_SIZE := 96.0
const GUEST := "tutorial:guest"

## Player steps in order. The last one ends the tutorial.
const PLAYER_STEPS := ["map_island", "island_languages", "language_pick", "level_easy", "lesson_study",
	"lesson_start", "quiz_answer", "quiz_spirit", "quiz_warrior", "results_rewards"]

var _layer: CanvasLayer
var _queue: Array = []
var _steps_screen: Node
var _hand: TextureRect
var _ring: Control
var _bubble: PanelContainer
var _target: Variant = null    # Control or Callable returning a global Rect2
var _current := ""
var _hand_tween: Tween


# ---------------------------------------------------------------- state

func _key() -> String:
	return "tutorial:%d" % Game.user_id() if Game.is_logged_in() else GUEST


func _state(key := "") -> Dictionary:
	var raw := DB.get_setting(key if key != "" else _key(), "")
	var parsed = JSON.parse_string(raw) if raw != "" else null
	return parsed if parsed is Dictionary else {}


func _save(state: Dictionary, key := "") -> void:
	DB.set_setting(key if key != "" else _key(), JSON.stringify(state))


## Is the tutorial running for the current player (or the first-time guest)?
func is_active() -> bool:
	if not Game.is_logged_in():
		var s := _state(GUEST)
		return not s.get("finished", false) and DB.get_users().is_empty()
	return _state().get("active", false)


func is_done(step: String) -> bool:
	return step in _state().get("done", [])


func mark_done(step: String) -> void:
	var s := _state()
	var done: Array = s.get("done", [])
	if not step in done:
		done.append(step)
	s["done"] = done
	if step == PLAYER_STEPS[PLAYER_STEPS.size() - 1] and Game.is_logged_in():
		s["active"] = false
		s["finished"] = true
	_save(s)


## Starts the player tutorial (new players, or "Replay tutorial").
func start_for_player() -> void:
	_save({"active": true, "done": []})
	# The guest part is over once someone has a profile.
	_save({"finished": true}, GUEST)


func skip() -> void:
	if Game.is_logged_in():
		_save({"active": false, "finished": true, "done": PLAYER_STEPS})
	else:
		_save({"finished": true}, GUEST)
	_clear()


# ---------------------------------------------------------------- showing steps

## Shows the first step of [param steps] that is not done yet.
## Each step: {"id", "text", "target": the Control to point at, optional
## "rect": Callable returning the global Rect2 to point at instead (for
## buttons bigger than what they show), "wait": true to finish when the
## target button is pressed (otherwise the bubble has a GOT IT button)}.
func show_steps(screen: Node, steps: Array) -> void:
	if not is_active():
		return
	_queue = steps.filter(func(s): return not is_done(s.id))
	_steps_screen = screen
	_next_step.call_deferred()


func _next_step() -> void:
	_clear()
	if _queue.is_empty() or not is_instance_valid(_steps_screen) or not _steps_screen.is_inside_tree():
		return
	var step: Dictionary = _queue.pop_front()
	_current = step.id
	_target = step.get("rect", step.get("target"))
	_build_overlay(_steps_screen, step)
	var button = step.get("target")
	if step.get("wait", false) and button is BaseButton:
		var id: String = step.id
		button.pressed.connect(func():
			mark_done(id)
			_clear(), CONNECT_ONE_SHOT)


func current_step() -> String:
	return _current if is_instance_valid(_layer) and _layer.is_inside_tree() else ""


func _clear() -> void:
	if _hand_tween:
		_hand_tween.kill()
	if is_instance_valid(_layer):
		if _layer.get_parent():
			_layer.get_parent().remove_child(_layer)  # detach now so the next step can take its place
		_layer.queue_free()
	_layer = null
	_current = ""


func _build_overlay(screen: Node, step: Dictionary) -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 40
	_layer.name = "Tutorial"
	screen.add_child(_layer)

	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	_layer.add_child(_ring)

	_hand = TextureRect.new()
	_hand.name = "Hand"
	_hand.texture = load("res://assets/ui/tutorial_hand.png")
	_hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hand.size = Vector2(HAND_SIZE, HAND_SIZE)
	_hand.pivot_offset = HAND_TIP * HAND_SIZE / 128.0
	_hand.rotation_degrees = -18
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand.visible = _target != null
	_layer.add_child(_hand)

	_bubble = _make_bubble(step)
	_layer.add_child(_bubble)

	if step.get("target") is Control:
		_scroll_when_ready(step.target)
	_animate()


## Containers finish their layout a frame or two after the screen opens, so
## scroll to the target only then.
func _scroll_when_ready(c: Control) -> void:
	for i in 3:
		await get_tree().process_frame
	if is_instance_valid(c) and c.is_inside_tree():
		_scroll_into_view(c)


func _make_bubble(step: Dictionary) -> PanelContainer:
	var b := PanelContainer.new()
	b.name = "Bubble"
	var sb := UI._box(Color("fffaf0"), 20, Color("8a63c2"), 5, 16)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 12
	b.add_theme_stylebox_override("panel", sb)
	var v := UI.vbox(8)
	b.add_child(v)
	var row := UI.hbox(10)
	var region: String = Game.region_code if Game.region_code in UI.GUIDES else "luzon"
	var face := UI.image(UI.tex["guide_" + region], Vector2(70, 70))
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(face)
	var text := UI.label(step.text, 20, UI.INK, true, UI.font_body_black)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	v.add_child(row)
	var buttons := UI.hbox(10)
	var skip_b := UI.pill_button("SKIP TUTORIAL", UI.INK_SOFT, skip, 44, 15)
	skip_b.name = "skip"
	buttons.add_child(skip_b)
	if not step.get("wait", false):
		var ok := UI.pill_button("GOT IT", Color("6b3fa0"), func():
			mark_done(step.id)
			_next_step(), 44, 17)
		ok.name = "got_it"
		ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(ok)
	v.add_child(buttons)
	return b


func _scroll_into_view(c: Control) -> void:
	var p := c.get_parent()
	while p != null and not p is ScrollContainer:
		p = p.get_parent()
	if p is ScrollContainer:
		(p as ScrollContainer).ensure_control_visible(c)


func _target_rect() -> Rect2:
	if _target is Callable:
		return _target.call()
	if _target is Control and is_instance_valid(_target) and _target.is_visible_in_tree():
		return _target.get_global_rect()
	return Rect2()


## The hand taps the target: it glides in, presses, and lifts again.
func _animate() -> void:
	if _hand_tween:
		_hand_tween.kill()
	_hand_tween = create_tween().set_loops()
	_hand_tween.tween_method(_place_hand, 1.0, 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hand_tween.tween_property(_hand, "scale", Vector2(0.85, 0.85), 0.12)
	_hand_tween.tween_property(_hand, "scale", Vector2.ONE, 0.12)
	_hand_tween.tween_interval(0.35)


func _place_hand(lift: float) -> void:
	if not is_instance_valid(_hand):
		return
	var r := _target_rect()
	if r.size == Vector2.ZERO:
		_hand.visible = false
		return
	_hand.visible = true
	var tip := r.get_center() + Vector2(r.size.x * 0.12, r.size.y * 0.18)
	_hand.position = tip - _hand.pivot_offset + Vector2(40, 60) * lift


func _process(_delta: float) -> void:
	if not is_instance_valid(_layer) or not _layer.is_inside_tree():
		return
	var r := _target_rect()
	var view := _layer.get_viewport().get_visible_rect().size
	# Bubble on the half of the screen away from the target.
	var w := minf(view.x - 40, 640)
	_bubble.size = Vector2(w, 0)
	_bubble.reset_size()
	_bubble.size.x = w
	var below := r.size == Vector2.ZERO or r.get_center().y < view.y * 0.5
	_bubble.position = Vector2((view.x - w) / 2, view.y - _bubble.size.y - 150 if below else 110)
	_ring.queue_redraw()


func _draw_ring() -> void:
	var r := _target_rect()
	if r.size == Vector2.ZERO:
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
	var grow := 6.0 + 6.0 * pulse
	_ring.draw_rect(r.grow(grow), Color(1, 0.85, 0.2, 0.55 + 0.4 * pulse), false, 5.0)
