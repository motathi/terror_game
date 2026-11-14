extends Control
## Ferramenta de ajuste: abra scenes/location_preview.tscn e rode com F6.
## Toque/clique (ou setas) troca de cenário; mostra o elenco de teste nos
## slots para conferir enquadramento, luz e escala dos modelos.

const Stage := preload("res://scripts/stage/stage.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const POST_SHADER := preload("res://shaders/psx_post.gdshader")

const LOCATIONS := ["escritorio", "escritorio_escuro", "escada", "garagem", "carro", "rua", "casa"]
const CHARS := {
	"rafael": {"name": "Rafael", "model": "office_worker"},
	"marina": {"name": "Marina", "model": "nurse"},
	"zumbi": {"name": "", "model": "zombie_student"},
}
const CAST := {
	"left": {"char": "marina", "anim": "Idle"},
	"right": {"char": "rafael", "anim": "Talk"},
	"center": {"char": "zumbi", "anim": "ZombieIdle"},
}

var stage: Stage
var label: Label
var index := 0


func _ready() -> void:
	UI.full_rect(self)
	var svc := SubViewportContainer.new()
	UI.full_rect(svc)
	svc.stretch = true
	svc.stretch_shrink = 4
	svc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var post := ShaderMaterial.new()
	post.shader = POST_SHADER
	svc.material = post
	add_child(svc)
	var sv := SubViewport.new()
	svc.add_child(sv)
	stage = Stage.new()
	stage.title_font = UI.title_font()
	stage.body_font = UI.body_font()
	stage.post_material = post
	sv.add_child(stage)
	label = UI.label("", 40)
	label.anchor_right = 1.0
	label.offset_top = 40
	add_child(label)
	_show.call_deferred()


func _show() -> void:
	stage.set_location(LOCATIONS[index])
	stage.set_cast(CAST, CHARS)
	stage.set_pleads({"marina": "Por favor", "rafael": "Fica comigo"})
	label.text = "%s  (%d/%d)" % [LOCATIONS[index], index + 1, LOCATIONS.size()]


func _unhandled_input(event: InputEvent) -> void:
	var step := 0
	if event.is_action_pressed("ui_right") or (event is InputEventScreenTouch and event.pressed):
		step = 1
	elif event.is_action_pressed("ui_left"):
		step = -1
	if step != 0:
		index = wrapi(index + step, 0, LOCATIONS.size())
		_show()
