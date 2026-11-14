extends Control
## Menu principal: título com glitch, jogar, galeria de finais, opções.

const UI := preload("res://scripts/ui/ui_kit.gd")
const StoryRunner := preload("res://scripts/story/story_runner.gd")
const POST_SHADER := preload("res://shaders/psx_post.gdshader")

var _title: Label
var _t := 0.0


func _ready() -> void:
	UI.full_rect(self)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.02)
	UI.full_rect(bg)
	var post := ShaderMaterial.new()
	post.shader = POST_SHADER
	post.set_shader_parameter("grain", 0.12)
	bg.material = post
	add_child(bg)

	var box := VBoxContainer.new()
	box.anchor_left = 0.08
	box.anchor_right = 0.92
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 26)
	add_child(box)

	_title = UI.label("ESCOLHA-ME", 78, UI.RED, true)
	box.add_child(_title)
	box.add_child(UI.label("Capítulo 1 — Surto", 40, UI.DIM))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 80
	box.add_child(spacer)

	var runner := StoryRunner.new()
	var total := 0
	if runner.load_file(GameState.current_campaign):
		total = runner.ending_ids().size()
	var found := GameState.count_discovered(runner.campaign_id)

	var play := UI.button("JOGAR", 48)
	play.pressed.connect(_on_play)
	box.add_child(play)
	var endings := UI.button("FINAIS  %d/%d" % [found, total], 40)
	endings.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/endings_gallery.tscn"))
	box.add_child(endings)
	var timers := UI.button(_timers_text(), 32, UI.DIM)
	timers.pressed.connect(func():
		GameState.settings["timers"] = not GameState.settings.get("timers", true)
		GameState.save()
		timers.text = _timers_text())
	box.add_child(timers)

	box.add_child(UI.label("Jogue com fone de ouvido.", 30, UI.DIM))
	Audio.play_ambience("tensao")
	play.grab_focus()
	if not GameState.debug_start_node.is_empty():
		_on_play.call_deferred()


func _timers_text() -> String:
	return "TEMPO PARA ESCOLHER: " + ("LIGADO" if GameState.settings.get("timers", true) else "DESLIGADO")


func _on_play() -> void:
	Audio.play_sfx("stinger_hit")
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _process(delta: float) -> void:
	_t += delta
	# glitch ocasional no título
	if randf() < 0.02:
		_title.position.x = randf_range(-6, 6)
		_title.modulate = Color(1, 1, 1, randf_range(0.5, 1.0))
	else:
		_title.position.x = lerpf(_title.position.x, 0.0, 0.3)
		_title.modulate = Color.WHITE
