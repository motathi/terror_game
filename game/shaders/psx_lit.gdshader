// Material PSX: vértices "tremendo" (snap em grade de baixa resolução),
// textura com mapeamento afim (distorce como no PS1) e filtro nearest.
// Aplicado automaticamente em todos os modelos por AssetLib.psxify().
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform bool use_texture = false;
// Modelos com sombreamento pintado nos vértices (ex.: PSX Aliens).
uniform bool use_vertex_color = false;
uniform sampler2D emission_tex : source_color, filter_nearest, hint_default_black;
uniform float emission_strength = 0.0;
// Resolução da grade de snap (menor = mais tremido). ~ largura da tela PS1.
uniform float snap_resolution = 180.0;
uniform float affine_strength : hint_range(0.0, 1.0) = 0.85;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.5;

varying vec3 affine_uvw;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float aspect = VIEWPORT_SIZE.y / max(VIEWPORT_SIZE.x, 1.0);
	vec2 grid = vec2(snap_resolution, snap_resolution * aspect);
	clip.xy = floor(clip.xy / clip.w * grid + 0.5) / grid * clip.w;
	POSITION = clip;
	affine_uvw = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = mix(UV, affine_uvw.xy / affine_uvw.z, affine_strength);
	vec4 c = albedo_color;
	if (use_texture) {
		c *= texture(albedo_tex, uv);
	}
	if (use_vertex_color) {
		c.rgb *= COLOR.rgb;
	}
	if (c.a < alpha_scissor) {
		discard;
	}
	ALBEDO = c.rgb;
	EMISSION = texture(emission_tex, uv).rgb * emission_strength;
	ROUGHNESS = 1.0;
}
