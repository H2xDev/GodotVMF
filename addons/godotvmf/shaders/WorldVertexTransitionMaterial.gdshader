// WorldVertexTransition shader implementation
// made by H2xDev and based on StandardMaterial3D

shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color,filter_linear_mipmap,repeat_enable;

uniform vec4 albedo_color2 : source_color = vec4(1.0);
uniform sampler2D albedo_texture2: source_color,filter_linear_mipmap,repeat_enable;

uniform float point_size : hint_range(0, 128);
uniform float roughness : hint_range(0, 1);

uniform float metallic;
uniform sampler2D metallic_texture : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform sampler2D metallic_texture2 : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform vec4 metallic_texture_channel;

uniform sampler2D roughness_texture : hint_roughness_r,filter_linear_mipmap,repeat_enable;
uniform sampler2D roughness_texture2 : hint_roughness_r,filter_linear_mipmap,repeat_enable;

uniform float specular;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
uniform vec3 uv2_scale = vec3(1.0);
uniform vec3 uv2_offset = vec3(0.0);


void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	UV2 = UV2 * uv2_scale.xy + uv2_offset.xy;
	COLOR.a = 1.0 - COLOR.a;
}

void fragment() {
	vec4 albedo_tex1 = texture(albedo_texture, UV);
	vec4 albedo_tex2 = texture(albedo_texture2, UV);
	vec4 albedo_tex = mix(albedo_tex1, albedo_tex2, COLOR.r);
	vec4 albedo = mix(albedo_color, albedo_color2, COLOR.r);

	ALBEDO = albedo_tex.rgb * albedo.rgb;

	float metallic_tex1 = dot(texture(metallic_texture, UV), metallic_texture_channel);
	float metallic_tex2 = dot(texture(metallic_texture2, UV), metallic_texture_channel);

	float metallic_tex = mix(metallic_tex1, metallic_tex2, COLOR.r);

	METALLIC = metallic_tex * metallic;

	vec4 roughness_texture_channel = vec4(1.0,0.0,0.0,0.0);

	float roughness_tex1 = dot(texture(roughness_texture, UV), roughness_texture_channel);
	float roughness_tex2 = dot(texture(roughness_texture2, UV), roughness_texture_channel);

	float roughness_tex = mix(roughness_tex1, roughness_tex2, COLOR.r);

	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
}
