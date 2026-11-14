extends Control
## Galeria de finais: mostra os descobertos e "???" nos que faltam.

const UI := preload("res://scripts/ui/ui_kit.gd")
const StoryRunner := preload("res://scripts/story/story_runner.gd")

const KIND_COLOR := {
	"morte": Color(0.85, 0.1, 0.1),
	"sobreviveu": Color(0.4, 0.85, 0.45),
	"agridoce": Color(0.9, 0.7, 0.3),
	"secreto": Color(0.7, 0.45, 1.0),
}


func _ready() -> void:
	UI.full_rect(self)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.02)
	UI.full_rect(bg)
	add_child(bg)

	var runner := StoryRunner.new()
	runner.load_file(GameState.current_campaign)
	var ids := runner.ending_ids()

	var root := VBoxContainer.new()
	root.anchor_left = 0.05
	root.anchor_right = 0.95
	root.anchor_top = 0.04
	root.anchor_bottom = 0.96
	root.add_theme_constant_override("separation", 16)
	add_child(root)
	root.add_child(UI.label("FINAIS", 64, UI.RED, true))
	root.add_child(UI.label("%d / %d descobertos" % [GameState.count_discovered(runner.campaign_id), ids.size()], 36, UI.DIM))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)

	for id in ids:
		var e := runner.ending(id)
		var known := GameState.is_discovered(runner.campaign_id, id)
		var kind: String = e.get("kind", "morte")
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UI.panel_style(Color(1, 1, 1, 0.05), 10, KIND_COLOR.get(kind, Color.WHITE) * Color(1, 1, 1, 0.6 if known else 0.15)))
		var v := VBoxContainer.new()
		panel.add_child(v)
		var title := UI.label(String(e["title"]).to_upper() if known else "???", 34, KIND_COLOR.get(kind, Color.WHITE) if known else UI.DIM, true)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(title)
		var desc := UI.label(e.get("text", "") if known else _hint(kind), 32, UI.WHITE if known else UI.DIM)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(desc)
		list.add_child(panel)

	var back := UI.button("VOLTAR", 40)
	back.custom_minimum_size.y = 90
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	root.add_child(back)


func _hint(kind: String) -> String:
	match kind:
		"secreto":
			return "Um final secreto. Talvez você precise fazer... nada."
		"sobreviveu":
			return "Alguém sobrevive."
		"agridoce":
			return "Sobreviver tem um preço."
	return "Uma morte que você ainda não viu."
