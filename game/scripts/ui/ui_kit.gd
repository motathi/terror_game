extends RefCounted
## Fontes, cores e componentes de UI compartilhados (estilo legenda de TikTok
## + texto pixelado). Tudo criado em código para não depender de .tres.

const FONT_BODY_PATH := "res://assets/fonts/VT323-Regular.ttf"
const FONT_TITLE_PATH := "res://assets/fonts/Silkscreen-Regular.ttf"

const RED := Color(0.85, 0.08, 0.08)
const WHITE := Color(0.96, 0.96, 0.93)
const DIM := Color(0.6, 0.6, 0.6)
const PANEL := Color(0, 0, 0, 0.72)

static var _body: Font
static var _title: Font


static func body_font() -> Font:
	if _body == null:
		_body = _load_font(FONT_BODY_PATH)
	return _body


static func title_font() -> Font:
	if _title == null:
		_title = _load_font(FONT_TITLE_PATH)
	return _title


static func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var f = load(path)
		if f is FontFile:
			f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			f.hinting = TextServer.HINTING_NONE
			return f
	return ThemeDB.fallback_font


static func label(text: String, size: int, color := WHITE, title := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font() if title else body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func panel_style(color := PANEL, radius := 14, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	if border.a > 0.0:
		s.border_color = border
		s.set_border_width_all(3)
	return s


static func button(text: String, size := 40, accent := WHITE) -> Button:
	var b := Button.new()
	b.text = text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 104)
	b.add_theme_font_override("font", body_font())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", accent)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", RED)
	b.add_theme_stylebox_override("normal", panel_style(Color(0.05, 0.05, 0.05, 0.85), 12, Color(1, 1, 1, 0.35)))
	b.add_theme_stylebox_override("hover", panel_style(Color(0.15, 0.02, 0.02, 0.9), 12, RED))
	b.add_theme_stylebox_override("pressed", panel_style(Color(0.3, 0.0, 0.0, 0.95), 12, RED))
	b.add_theme_stylebox_override("focus", panel_style(Color(0, 0, 0, 0), 12, Color(1, 1, 1, 0.5)))
	return b


static func full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
