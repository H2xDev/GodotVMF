shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color,filter_linear_mipmap,repeat_enable;

uniform vec4 albedo_color2 : source_color = vec4(1.0);
uniform sampler2D texture_albedo2: source_color,filter_linear_mipmap,repeat_enable; 

uniform float point_size : hint_range(0,128);
uniform float roughness : hint_range(0,1);

uniform float metallic;
uniform sampler2D texture_metallic : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform sampler2D texture_metallic2 : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform vec4 metallic_texture_channel;

uniform sampler2D texture_roughness : hint_roughness_r,filter_linear_mipmap,repeat_enable;
uniform sampler2D texture_roughness2 : hint_roughness_r,filter_linear_mipmap,repeat_enable;

uniform float specular;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
uniform vec3 uv2_scale = vec3(1.0);
uniform vec3 uv2_offset = vec3(0.0);


void vertex() {
	UV=UV*uv1_scale.xy+uv1_offset.xy;
}

void fragment() {
	vec2 base_uv = UV;
	vec4 albedo_tex1 = texture(texture_albedo, base_uv);
	vec4 albedo_tex2 = texture(texture_albedo2, base_uv);
	vec4 albedo_tex = albedo_tex2 * (1.0 - COLOR.a) + albedo_tex1 * (COLOR.a);
	vec4 albedo = albedo_color2 * (1.0 - COLOR.a) + albedo_color * (COLOR.a);
	
	ALBEDO = albedo.rgb * albedo_tex.rgb;

	float metallic_tex1 = dot(texture(texture_metallic,base_uv),metallic_texture_channel);
	float metallic_tex2 = dot(texture(texture_metallic2,base_uv),metallic_texture_channel);

	float metallic_tex = metallic_tex2 * (1.0 - COLOR.a) + metallic_tex1 * (COLOR.a);

	METALLIC = metallic_tex * metallic;
	vec4 roughness_texture_channel = vec4(1.0,0.0,0.0,0.0);

	float roughness_tex1 = dot(texture(texture_roughness, base_uv),roughness_texture_channel);
	float roughness_tex2 = dot(texture(texture_roughness2, base_uv),roughness_texture_channel);

	float roughness_tex = roughness_tex2 * (1.0 - COLOR.a) + roughness_tex1 * (COLOR.a);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
}

