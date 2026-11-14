// Pós-processamento da tela 3D (aplicado no SubViewportContainer):
// cores de 15 bits com dithering Bayer, granulado de vídeo, vinheta e
// um flash vermelho para sustos. A UI fica por cima, sem esse filtro.
shader_type canvas_item;

uniform float color_levels = 32.0;          // 32 = 5 bits por canal (PS1)
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;
uniform float grain : hint_range(0.0, 0.3) = 0.07;
uniform float vignette : hint_range(0.0, 1.5) = 0.3;
// Levanta as sombras para telas de celular (sem estourar os claros).
uniform float lift : hint_range(0.0, 0.3) = 0.06;
uniform float exposure : hint_range(0.5, 2.0) = 1.25;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float blackout : hint_range(0.0, 1.0) = 0.0;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV) * COLOR;
	col.rgb = 1.0 - exp(-col.rgb * exposure * 1.6);  // tonemap suave
	col.rgb = col.rgb * (1.0 - lift) + lift * sqrt(col.rgb);
	ivec2 px = ivec2(UV / TEXTURE_PIXEL_SIZE);
	float threshold = BAYER[(px.y % 4) * 4 + (px.x % 4)] / 16.0 - 0.5;
	vec3 c = col.rgb + threshold * dither_strength / color_levels;
	c = floor(c * color_levels + 0.5) / color_levels;
	float n = hash(vec2(px) + fract(TIME * 7.0) * 100.0) - 0.5;
	c += n * grain;
	vec2 d = UV - 0.5;
	c *= 1.0 - dot(d, d) * vignette * 2.0;
	c = mix(c, vec3(0.7, 0.0, 0.0), flash * 0.6);
	c *= 1.0 - blackout;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
