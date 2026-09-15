// 世界地图卡通渲染的公共主体。被 hex_toon.gdshader（单面：地格/建筑/道具）与
// hex_toon_foliage.gdshader（双面 + 透明裁切：树叶/花草）两个入口 #include。
//
// 「陈列柜」画风的关键在这里：不加细节，而是把素材固有色**往灰、往奶油底靠一档**
// （desaturate / wash），再由引擎 diffuse_toon 压成几档光照。低饱和 + 软阴影 + 奶油底，
// 读起来就是一件摆在台面上的模型。

// 素材的原始色块图集。Builder Pack 的地格/建筑是纯色、没有贴图，走 tint、关掉采样。
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool has_albedo_tex = true;

// 固有色调色：先向灰靠（去饱和），再向奶油底色靠（罩色）。两者都为 0 就是原色。
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform vec4 wash_color : source_color = vec4(0.93, 0.91, 0.87, 1.0);
uniform float wash_amount : hint_range(0.0, 1.0) = 0.0;

// 边缘光：面向越偏离镜头越亮。陈列柜画风默认关掉（0），保留参数给其它场景。
uniform vec4 rim_color : source_color = vec4(1.0, 0.98, 0.92, 1.0);
uniform float rim_width : hint_range(0.0, 1.0) = 0.42;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;

// 飘云在地面上的软斑。引擎阴影负责建筑/树干；这里再给顶面补一团更卡通的投影。
uniform vec4 cloud_shadows[8];
uniform int cloud_shadow_count = 0;
uniform vec4 cloud_shade_color : source_color = vec4(0.78, 0.79, 0.80, 1.0);

// 仅树叶变体使用：贴图 alpha 低于此值的像素裁掉。
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.2;


void fragment() {
	vec4 sampled = has_albedo_tex ? texture(albedo_tex, UV) : vec4(1.0);
	vec3 base = sampled.rgb;
	float gray = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(base, vec3(gray), desaturate);
	base = mix(base, wash_color.rgb, wash_amount);

	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float cloud_shade = 0.0;
	for (int i = 0; i < 8; i++) {
		float live = step(float(i) + 0.5, float(cloud_shadow_count));
		vec4 blob = cloud_shadows[i];
		float dist = length(world_pos.xz - blob.xy);
		float inner = max(blob.z * 0.30, 0.05);
		float outer = max(blob.z, inner + 0.01);
		float cover = (1.0 - smoothstep(inner, outer, dist)) * blob.w * live;
		cloud_shade = max(cloud_shade, cover);
	}
	ALBEDO = base * tint.rgb * mix(vec3(1.0), cloud_shade_color.rgb, cloud_shade);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
#ifdef FOLIAGE
	// 双面叶片：背面法线翻回来，免得背光面一整片黑。
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALPHA = sampled.a * tint.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
#endif
	// 用 EMISSION 而不是 RIM 内置项：RIM 要走镜面链路，而我们已经把镜面关了。
	float facing = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = smoothstep(1.0 - rim_width, 1.0, facing);
	EMISSION = rim_color.rgb * rim * rim_strength * (1.0 - cloud_shade * 0.65);
}
