shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scenery_buffer : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 sample_center = vec2(0.5);
uniform vec2 sample_extent = vec2(0.09);

void fragment() {
	vec2 centered = UV - vec2(.5);
	float radius = length(centered);
	vec3 scene = texture(scenery_buffer, clamp(sample_center + centered * sample_extent, vec2(0.), vec2(1.))).rgb;
	float rim = smoothstep(.435,.472,radius);
	vec3 glass = mix(scene, scene * vec3(.83,.89,.89), rim*.42);
	COLOR = vec4(glass, 1.0-smoothstep(.469,.477,radius));
}
