shader_type spatial;
// 世界地图的卡通风格化渲染。
//
// KayKit 那套素材本身就是低模 + 一张色块图集，最适合的处理不是加细节，而是**把光照
// 压成几档**：受光面、过渡面、背光面各一个色阶，边界干净，读起来就是手绘立体书的味道。
// 再补一圈朝外的边缘光，让每块六边形从背景里跳出来。
//
// 走 `light()` 自己量化，而不是 `render_mode diffuse_toon`——后者的档位和过渡宽度都改
// 不了，低模上容易糊成两档。`specular_disabled` 是必须的：镜面高光会在平坦的六边形顶
// 面上拖出一道亮斑，直接破坏"色块"的手感。
render_mode cull_back, diffuse_toon, specular_disabled;

// 素材的原始色块图集。保留它，卡通化只动光照、不动固有色。
// Builder Pack 的地格/建筑是纯色 PBR、没有贴图，走 tint、关掉采样。
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool has_albedo_tex = true;

// 光照分几档。3 档 = 亮/中/暗，是低模最稳的数量；再多就看不出是卡通了。
uniform int bands : hint_range(2, 5) = 3;
// 档与档之间留多少过渡。0 是纯硬边，在斜面上会有阶梯锯齿；留一点点就顺了。
uniform float band_softness : hint_range(0.0, 0.5) = 0.10;
// 背光面靠环境光托住，**不在 light() 里加地板**：light() 每盏灯调一次，加地板等于
// 每盏灯都白送一份底光，三盏灯累加直接把画面冲爆。这个教训值一整轮返工。

// 边缘光：面向越偏离镜头越亮。给每块地格镶一道浅边，代替描边。
uniform vec4 rim_color : source_color = vec4(1.0, 0.98, 0.92, 1.0);
uniform float rim_width : hint_range(0.0, 1.0) = 0.42;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.10;

// 飘云在地面上的软斑。引擎阴影负责建筑/树干；这里再给六边顶面补一团更卡通的投影。
uniform vec4 cloud_shadows[8];
uniform int cloud_shadow_count = 0;


void fragment() {
	vec3 base = has_albedo_tex ? texture(albedo_tex, UV).rgb : vec3(1.0);
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
	ALBEDO = base * tint.rgb * mix(vec3(0.62, 0.68, 0.76), vec3(1.0), 1.0 - cloud_shade);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// 用 EMISSION 而不是 RIM 内置项：RIM 要走镜面链路，而我们已经把镜面关了。
	float facing = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = smoothstep(1.0 - rim_width, 1.0, facing);
	EMISSION = rim_color.rgb * rim * rim_strength * (1.0 - cloud_shade * 0.65);
}


// 光照走引擎自带的 diffuse_toon，这样 Compatibility 下树影和地格侧面才会吃到主光阴影。
// 自己写 light() 时 ATTENUATION 在 GLES3 上经常不带阴影，画面就会一整片一样亮。
