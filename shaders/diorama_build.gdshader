// 展品模型的哑光材质 + 「搭积木」入场动画 + 常态微动。
//
// 每个顶点的 COLOR 不是颜色：rgb 是这件东西的基点（在 pivot_min / pivot_size 里归一化，
// Godot 坐标），a 是它开始弹出的时刻（占 build_span 的比例）。UV2 也不是贴图坐标：
// x 编这件东西的运动种类（floor(x*32)），y 编相位。这些都由 Blender 脚本
// （tools/diorama_kit.py finalize）写进顶点属性。
// mode 0 = 地形：整体从台面高度弹起（只动 y）；mode 1 = 道具：围着自己的基点弹出，
// 竖向比横向多过冲一点，像果冻。build 从 0 到 1 走完整个入场；build = 1 时几何完全到位。
// 运动种类：1 枝叶摇曳 · 2 停着的鸟点头 · 3 船/浮标摇晃 · 4 风车翼绕 z 转 · 5 水车绕 x 转 ·
// 6 悬挂物小钟摆 · 7 炊烟升腾 · 8 旗帆抖动 · 9 绕圈飞 · 10 绕圈游 · 11 水面漂浮。
shader_type spatial;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_albedo_tex = false;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.1;
// 未解锁的「泥胚」观感：抽色 + 整体染一层暖灰。
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint : source_color = vec3(1.0);
// 常态微动（摇曳 / 摆动 / 抖动）的总幅度；荒废态收小，枯枝不该随风乱摆。
uniform float motion_amount : hint_range(0.0, 1.5) = 1.0;

uniform float build : hint_range(0.0, 1.0) = 1.0;
uniform float build_total = 1.9;
uniform float build_span = 1.35;
uniform float piece_time = 0.55;
uniform float rise_time = 0.7;
uniform int mode = 1;
uniform float rise_from = -2.1;
uniform vec3 pivot_min = vec3(-16.0, -3.0, -12.0);
uniform vec3 pivot_size = vec3(32.0, 10.0, 24.0);

// 阻尼弹簧：0 起步，过冲后收敛到 1；t >= 1 精确等于 1。
float spring(float t, float damping, float freq) {
	if (t >= 1.0) {
		return 1.0;
	}
	if (t <= 0.0) {
		return 0.0;
	}
	return 1.0 - exp(-damping * t) * cos(freq * t);
}

vec3 rot_x(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(v.x, c * v.y - s * v.z, s * v.y + c * v.z);
}

vec3 rot_y(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(c * v.x + s * v.z, v.y, -s * v.x + c * v.z);
}

vec3 rot_z(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(c * v.x - s * v.y, s * v.x + c * v.y, v.z);
}

void vertex() {
	float now = build * build_total;
	float start = COLOR.a * build_span;
	if (mode == 0) {
		float t = clamp(now / rise_time, 0.0, 1.0);
		float s = spring(t, 5.0, 6.5);
		VERTEX.y = rise_from + (VERTEX.y - rise_from) * s;
	} else {
		vec3 pivot = pivot_min + COLOR.rgb * pivot_size;
		vec3 d = VERTEX - pivot;
		int kind = int(floor(UV2.x * 32.0));
		float phase = UV2.y * 6.2831853;
		float t = TIME;
		if (kind == 1) {
			float h = clamp(d.y / 2.5, 0.0, 1.0);
			h *= h;
			float sx = sin(t * 1.1 + phase) * 0.6 + sin(t * 2.3 + phase * 1.7) * 0.4;
			float sz = cos(t * 0.9 + phase) * 0.5;
			d.xz += vec2(sx, sz) * 0.09 * h * motion_amount;
		} else if (kind == 2) {
			d = rot_y(d, sin(t * 0.8 + phase) * 0.12);
			d.y += abs(sin(t * 2.6 + phase)) * 0.025;
		} else if (kind == 3) {
			d = rot_x(d, sin(t * 1.3 + phase) * 0.05);
			d = rot_z(d, sin(t * 0.9 + phase * 2.0) * 0.035);
			d.y += sin(t * 1.1 + phase) * 0.03;
		} else if (kind == 4) {
			d = rot_z(d, t * 0.55 + phase);
		} else if (kind == 5) {
			d = rot_x(d, -(t * 0.7 + phase));
		} else if (kind == 6) {
			d = rot_x(d, sin(t * 1.6 + phase) * 0.10 * motion_amount);
			d = rot_z(d, sin(t * 1.1 + phase * 1.3) * 0.06 * motion_amount);
		} else if (kind == 7) {
			float s = fract(t * 0.22 + phase);
			float grow = sin(s * 3.14159);
			d = d * (0.35 + 0.9 * grow) + vec3(sin(t * 0.7 + phase) * 0.25 * s, s * 1.7, cos(t * 0.5 + phase) * 0.2 * s);
		} else if (kind == 8) {
			float along = clamp(length(d.xz) / 0.6, 0.0, 1.0);
			d.y += sin(t * 7.0 + along * 5.0 + phase) * 0.06 * along * motion_amount;
			d.z += sin(t * 5.0 + along * 4.0 + phase) * 0.03 * along * motion_amount;
		} else if (kind == 9) {
			d = rot_y(d, t * 0.5 + phase);
			d.y += sin(t * 2.2 + phase) * 0.15;
		} else if (kind == 10) {
			d = rot_y(d, t * 0.35 + phase);
			d.y += sin(t * 1.9 + phase) * 0.01;
		} else if (kind == 11) {
			d.y += sin(t * 1.4 + phase) * 0.015;
		}
		float tt = clamp((now - start) / piece_time, 0.0, 1.0);
		float s = spring(tt, 5.0, 9.5);
		float base = min(s, 1.0);
		float over = max(s - 1.0, 0.0);
		vec3 scale = vec3(base + over * 0.55, base + over * 1.45, base + over * 0.55);
		VERTEX = pivot + d * scale;
	}
}

void fragment() {
	vec3 col = albedo.rgb;
	if (use_albedo_tex) {
		col *= texture(albedo_tex, UV).rgb;
	}
	float grey = dot(col, vec3(0.30, 0.59, 0.11));
	ALBEDO = mix(col, vec3(grey), desaturate) * tint;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = specular_amount;
}
