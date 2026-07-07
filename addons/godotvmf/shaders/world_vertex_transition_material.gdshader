shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform bool convert_to_srgb;
uniform sampler2D blendmodulatetexture : hint_default_white, filter_linear_mipmap, repeat_enable;

group_uniforms albedo;
uniform sampler2D basetexture       : source_color,          filter_linear_mipmap, repeat_enable;
uniform sampler2D basetexture2      : source_color,          filter_linear_mipmap, repeat_enable;

group_uniforms normal;
uniform sampler2D bumpmap           : hint_roughness_normal,  filter_linear_mipmap, repeat_enable;
uniform float bumpscale  : hint_range(-16.0, 16.0) = 10.0;

uniform sampler2D bumpmap2          : hint_roughness_normal,  filter_linear_mipmap, repeat_enable;
uniform float bumpscale2  : hint_range(-16.0, 16.0) = 1.0;

group_uniforms metallic;
uniform sampler2D metallictexture  : hint_default_white,    filter_linear_mipmap, repeat_enable;
uniform float metallic  : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float specular   : hint_range(0.0, 1.0, 0.01) = 0.5;

uniform sampler2D metallictexture2 : hint_default_white,    filter_linear_mipmap, repeat_enable;
uniform float metallic2  : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float specular2   : hint_range(0.0, 1.0, 0.01) = 0.5;

group_uniforms roughness;
uniform sampler2D roughnesstexture  : hint_roughness_r,      filter_linear_mipmap, repeat_enable;
uniform float roughness  : hint_range(0.0, 1.0) = 1.0;

uniform sampler2D roughnesstexture2 : hint_roughness_r,      filter_linear_mipmap, repeat_enable;
uniform float roughness2  : hint_range(0.0, 1.0) = 1.0;

group_uniforms height;
uniform sampler2D heighttexture       : hint_default_black,    filter_linear_mipmap, repeat_enable;
uniform sampler2D heighttexture2      : hint_default_black,    filter_linear_mipmap, repeat_enable;

group_uniforms uv_transform;
// --- UV transforms ---
uniform vec3 uv1_scale = vec3(1.0, 1.0, 1.0);
uniform vec3 uv1_offset = vec3(0.0, 0.0, 0.0);
uniform vec3 uv2_scale = vec3(1.0, 1.0, 1.0);
uniform vec3 uv2_offset = vec3(0.0, 0.0, 0.0);

void vertex() {
	UV  = UV  * uv1_scale.xy + uv1_offset.xy;
	UV2 = UV2 * uv2_scale.xy + uv2_offset.xy;
}

void fragment() {
	vec4 modulate_value = texture(blendmodulatetexture, UV);

	float minb = max(modulate_value.g - modulate_value.r, 0.0);
	float maxb = min(modulate_value.g + modulate_value.r, 1.0);

	float blend = 1.0 - COLOR.r;
	blend = smoothstep(minb, maxb, blend);

	// Layer 1
	vec4  alb1 = texture(basetexture,       UV);
	vec3  nrm1 = texture(bumpmap,           UV).rgb;
	float met1 = texture(metallictexture,  UV).r * metallic;
	float rgh1 = texture(roughnesstexture,  UV).r * roughness;

	// Layer 2
	vec4  alb2 = texture(basetexture2,      UV);
	vec3  nrm2 = texture(bumpmap2,          UV).rgb;
	float met2 = texture(metallictexture2, UV).r * metallic2;
	float rgh2 = texture(roughnesstexture2, UV).r * roughness2;

	vec3 albedo_col = mix(alb1.rgb, alb2.rgb, blend);
	if (convert_to_srgb) {
		albedo_col = pow(max(albedo_col, vec3(0.0)), vec3(1.0 / 2.2));
	}

	ALBEDO           = albedo_col;
	METALLIC         = mix(met1,       met2,       blend);
	SPECULAR         = mix(specular,   specular2,  blend);
	ROUGHNESS        = mix(rgh1,       rgh2,       blend);
	NORMAL_MAP       = mix(nrm1,       nrm2,       blend);
	NORMAL_MAP_DEPTH = mix(bumpscale, bumpscale2,  blend);
}
