/**
 * BigLei3 排行榜 — Cloudflare Worker + D1
 *
 * 分关榜（BigLei3 扫雷）：
 *   GET  /health
 *   GET  /v1/stages/:stage_id/top?limit=100
 *   GET  /v1/stages/:stage_id/qualify?score=N
 *   POST /v1/submit  { stage_id, name, score }
 *
 * 每日榜（多游戏共用，TTDDP 猫猫对对碰用 game_id = "ttddp"）：
 *   GET  /v1/daily/:game_id/top?limit=50&day=YYYY-MM-DD&user_id=...
 *        → { game_id, day, now, resets_in, total, entries: [{ rank, user_id, name, score, runs, updated_at }], me }
 *   GET  /v1/daily/:game_id/me?user_id=...
 *        → { game_id, day, total, me: { rank, name, score, runs } | null }
 *   POST /v1/daily/submit  { game_id, user_id, name, score, avatar? }
 *        → { game_id, day, accepted, improved, best, rank, runs, total, resets_in }
 *   每日 00:00（北京时间）自动换榜；Cron 每天清理 30 天前的数据。
 *
 * 线上 Worker：https://biglei-leaderboard.biglei3.workers.dev
 * D1：biglei-leaderboard (7bc716d4-a441-4b0b-9302-75e3b2fc8933)
 */

const TOP_LIMIT = 100;
const NAME_MAX = 16;
const STAGE_ID_RE = /^[a-z0-9_]{1,32}$/i;

const DAILY_TOP = 50;
const DAILY_NAME_MAX = 24;
const DAILY_SCORE_MAX = 1_000_000;
const DAILY_KEEP_DAYS = 30;
const DAILY_GAME_RE = /^[a-z0-9_]{1,32}$/i;
const DAILY_USER_RE = /^[A-Za-z0-9_\-:.@]{1,80}$/;
const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;
const TZ_OFFSET_MS = 8 * 3600 * 1000; // Asia/Shanghai，无夏令时

export default {
	async fetch(request, env) {
		try {
			if (request.method === "OPTIONS") {
				return cors(new Response(null, { status: 204 }));
			}
			const url = new URL(request.url);
			const path = url.pathname.replace(/\/+$/, "") || "/";

			if (request.method === "GET" && path === "/health") {
				return cors(json({ ok: true, now: Date.now(), day: dayKey(Date.now()) }));
			}

			const topMatch = path.match(/^\/v1\/stages\/([^/]+)\/top$/);
			if (request.method === "GET" && topMatch) {
				return cors(await handleTop(env, topMatch[1], url));
			}

			const qualifyMatch = path.match(/^\/v1\/stages\/([^/]+)\/qualify$/);
			if (request.method === "GET" && qualifyMatch) {
				return cors(await handleQualify(env, qualifyMatch[1], url));
			}

			if (request.method === "POST" && path === "/v1/submit") {
				return cors(await handleSubmit(env, request));
			}

			const dailyTop = path.match(/^\/v1\/daily\/([^/]+)\/top$/);
			if (request.method === "GET" && dailyTop) {
				return cors(await handleDailyTop(env, dailyTop[1], url));
			}

			const dailyMe = path.match(/^\/v1\/daily\/([^/]+)\/me$/);
			if (request.method === "GET" && dailyMe) {
				return cors(await handleDailyMe(env, dailyMe[1], url));
			}

			if (request.method === "POST" && path === "/v1/daily/submit") {
				return cors(await handleDailySubmit(env, request));
			}

			return cors(json({ error: "not_found" }, 404));
		} catch (err) {
			console.error("leaderboard_error", String(err && err.message ? err.message : err));
			return cors(json({ error: "server_error" }, 500));
		}
	},

	async scheduled(_event, env) {
		const cutoff = dayKey(Date.now() - DAILY_KEEP_DAYS * 86400_000);
		const r = await env.DB.prepare("DELETE FROM daily_scores WHERE day < ?").bind(cutoff).run();
		console.log("daily_cleanup", cutoff, r?.meta?.changes ?? 0);
	},
};

/* ===================== 分关榜（原有） ===================== */

async function handleTop(env, stageId, url) {
	const stage = normalizeStageId(stageId);
	if (!stage) {
		return json({ error: "bad_stage" }, 400);
	}
	const limit = clampi(Number(url.searchParams.get("limit") || TOP_LIMIT), 1, TOP_LIMIT);
	const rows = await env.DB.prepare(
		"SELECT name, score, updated_at FROM scores WHERE stage_id = ? ORDER BY score DESC, updated_at ASC LIMIT ?"
	)
		.bind(stage, limit)
		.all();
	const entries = (rows.results || []).map((row, index) => ({
		rank: index + 1,
		name: row.name,
		score: row.score,
		updated_at: row.updated_at,
	}));
	return json({ stage_id: stage, entries });
}

async function handleQualify(env, stageId, url) {
	const stage = normalizeStageId(stageId);
	if (!stage) {
		return json({ error: "bad_stage" }, 400);
	}
	const score = clampi(Number(url.searchParams.get("score") || 0), 0, 2_000_000_000);
	if (score <= 0) {
		return json({ stage_id: stage, qualifies: false, rank: null, cutoff: 0 });
	}
	const count = Number(
		(await env.DB.prepare("SELECT COUNT(*) AS c FROM scores WHERE stage_id = ?").bind(stage).first())?.c || 0
	);
	const better = Number(
		(
			await env.DB.prepare("SELECT COUNT(*) AS c FROM scores WHERE stage_id = ? AND score > ?")
				.bind(stage, score)
				.first()
		)?.c || 0
	);
	const rank = better + 1;
	const cutoff = Number(
		(
			await env.DB.prepare(
				"SELECT score FROM scores WHERE stage_id = ? ORDER BY score DESC, updated_at ASC LIMIT 1 OFFSET ?"
			)
				.bind(stage, TOP_LIMIT - 1)
				.first()
		)?.score || 0
	);
	const qualifies = count < TOP_LIMIT || score > cutoff || (score === cutoff && rank <= TOP_LIMIT);
	return json({
		stage_id: stage,
		qualifies: Boolean(qualifies && rank <= TOP_LIMIT),
		rank: qualifies && rank <= TOP_LIMIT ? rank : null,
		cutoff,
	});
}

async function handleSubmit(env, request) {
	let body;
	try {
		body = await request.json();
	} catch {
		return json({ error: "bad_json" }, 400);
	}
	const stage = normalizeStageId(String(body?.stage_id || ""));
	const name = normalizeName(String(body?.name || ""), NAME_MAX);
	const score = clampi(Number(body?.score || 0), 0, 2_000_000_000);
	if (!stage) {
		return json({ error: "bad_stage" }, 400);
	}
	if (!name) {
		return json({ error: "bad_name" }, 400);
	}
	if (score <= 0) {
		return json({ error: "bad_score" }, 400);
	}

	const now = Date.now();
	const existing = await env.DB.prepare("SELECT score FROM scores WHERE stage_id = ? AND name = ?")
		.bind(stage, name)
		.first();
	if (existing && Number(existing.score) >= score) {
		return json({
			stage_id: stage,
			name,
			score: Number(existing.score),
			accepted: false,
			reason: "not_higher",
			rank: await rankFor(env, stage, Number(existing.score), name),
		});
	}

	await env.DB.prepare(
		`INSERT INTO scores (stage_id, name, score, updated_at)
		 VALUES (?, ?, ?, ?)
		 ON CONFLICT(stage_id, name) DO UPDATE SET
		   score = excluded.score,
		   updated_at = excluded.updated_at
		 WHERE excluded.score > scores.score`
	)
		.bind(stage, name, score, now)
		.run();

	await env.DB.prepare(
		`DELETE FROM scores
		 WHERE stage_id = ?
		   AND id NOT IN (
		     SELECT id FROM scores
		     WHERE stage_id = ?
		     ORDER BY score DESC, updated_at ASC
		     LIMIT ?
		   )`
	)
		.bind(stage, stage, TOP_LIMIT)
		.run();

	const kept = await env.DB.prepare("SELECT score FROM scores WHERE stage_id = ? AND name = ?")
		.bind(stage, name)
		.first();
	if (!kept) {
		return json({
			stage_id: stage,
			name,
			score,
			accepted: false,
			reason: "below_cutoff",
			rank: null,
		});
	}
	return json({
		stage_id: stage,
		name,
		score: Number(kept.score),
		accepted: true,
		rank: await rankFor(env, stage, Number(kept.score), name),
	});
}

async function rankFor(env, stage, score, name) {
	const better = Number(
		(
			await env.DB.prepare(
				"SELECT COUNT(*) AS c FROM scores WHERE stage_id = ? AND (score > ? OR (score = ? AND name < ?))"
			)
				.bind(stage, score, score, name)
				.first()
		)?.c || 0
	);
	return better + 1;
}

/* ===================== 每日榜 ===================== */

/** 北京时间的日期键 YYYY-MM-DD */
function dayKey(ts) {
	return new Date(ts + TZ_OFFSET_MS).toISOString().slice(0, 10);
}

/** 距离下一次换榜（北京时间次日 00:00）的毫秒数 */
function resetsIn(ts) {
	const shifted = ts + TZ_OFFSET_MS;
	const dayStart = Math.floor(shifted / 86400_000) * 86400_000;
	return dayStart + 86400_000 - shifted;
}

function resolveDay(url, now) {
	const q = String(url.searchParams.get("day") || "").trim();
	if (q && DAY_RE.test(q)) {
		return q;
	}
	return dayKey(now);
}

function normalizeGameId(value) {
	const text = String(value || "").trim();
	return DAILY_GAME_RE.test(text) ? text : "";
}

function normalizeUserId(value) {
	const text = String(value || "").trim();
	return DAILY_USER_RE.test(text) ? text : "";
}

function normalizeAvatar(value) {
	const text = String(value || "").trim();
	if (!text || text.length > 512 || !/^https:\/\//i.test(text)) {
		return null;
	}
	return text;
}

async function dailyTotal(env, game, day) {
	return Number(
		(await env.DB.prepare("SELECT COUNT(*) AS c FROM daily_scores WHERE game_id = ? AND day = ?").bind(game, day).first())
			?.c || 0
	);
}

async function dailyRank(env, game, day, score, updatedAt) {
	const better = Number(
		(
			await env.DB.prepare(
				"SELECT COUNT(*) AS c FROM daily_scores WHERE game_id = ? AND day = ? AND (score > ? OR (score = ? AND updated_at < ?))"
			)
				.bind(game, day, score, score, updatedAt)
				.first()
		)?.c || 0
	);
	return better + 1;
}

async function dailyMe(env, game, day, userId) {
	if (!userId) {
		return null;
	}
	const row = await env.DB.prepare(
		"SELECT name, score, runs, updated_at FROM daily_scores WHERE game_id = ? AND day = ? AND user_id = ?"
	)
		.bind(game, day, userId)
		.first();
	if (!row) {
		return null;
	}
	return {
		rank: await dailyRank(env, game, day, Number(row.score), Number(row.updated_at)),
		name: row.name,
		score: Number(row.score),
		runs: Number(row.runs),
		updated_at: Number(row.updated_at),
	};
}

async function handleDailyTop(env, gameId, url) {
	const game = normalizeGameId(gameId);
	if (!game) {
		return json({ error: "bad_game" }, 400);
	}
	const now = Date.now();
	const day = resolveDay(url, now);
	const limit = clampi(Number(url.searchParams.get("limit") || DAILY_TOP), 1, DAILY_TOP);
	const userId = normalizeUserId(url.searchParams.get("user_id"));

	const rows = await env.DB.prepare(
		"SELECT user_id, name, score, runs, updated_at FROM daily_scores WHERE game_id = ? AND day = ? ORDER BY score DESC, updated_at ASC LIMIT ?"
	)
		.bind(game, day, limit)
		.all();
	const entries = (rows.results || []).map((row, index) => ({
		rank: index + 1,
		user_id: row.user_id,
		name: row.name,
		score: Number(row.score),
		runs: Number(row.runs),
		updated_at: Number(row.updated_at),
	}));
	const total = await dailyTotal(env, game, day);
	const me = await dailyMe(env, game, day, userId);
	return json({ game_id: game, day, now, resets_in: resetsIn(now), total, entries, me });
}

async function handleDailyMe(env, gameId, url) {
	const game = normalizeGameId(gameId);
	if (!game) {
		return json({ error: "bad_game" }, 400);
	}
	const userId = normalizeUserId(url.searchParams.get("user_id"));
	if (!userId) {
		return json({ error: "bad_user" }, 400);
	}
	const now = Date.now();
	const day = resolveDay(url, now);
	const total = await dailyTotal(env, game, day);
	const me = await dailyMe(env, game, day, userId);
	return json({ game_id: game, day, now, resets_in: resetsIn(now), total, me });
}

async function handleDailySubmit(env, request) {
	let body;
	try {
		body = await request.json();
	} catch {
		return json({ error: "bad_json" }, 400);
	}
	const game = normalizeGameId(body?.game_id);
	const userId = normalizeUserId(body?.user_id);
	const name = normalizeName(body?.name, DAILY_NAME_MAX);
	const avatar = normalizeAvatar(body?.avatar);
	const score = clampi(Number(body?.score || 0), 0, DAILY_SCORE_MAX);
	if (!game) {
		return json({ error: "bad_game" }, 400);
	}
	if (!userId) {
		return json({ error: "bad_user" }, 400);
	}
	if (!name) {
		return json({ error: "bad_name" }, 400);
	}
	if (score <= 0) {
		return json({ error: "bad_score" }, 400);
	}

	const now = Date.now();
	const day = dayKey(now);
	const existing = await env.DB.prepare(
		"SELECT score FROM daily_scores WHERE game_id = ? AND day = ? AND user_id = ?"
	)
		.bind(game, day, userId)
		.first();
	const improved = !existing || score > Number(existing.score);

	// 同一天同一用户只保留最高分；每次提交 runs +1，昵称跟随最新一次提交
	await env.DB.prepare(
		`INSERT INTO daily_scores (game_id, day, user_id, name, avatar, score, runs, updated_at)
		 VALUES (?, ?, ?, ?, ?, ?, 1, ?)
		 ON CONFLICT(game_id, day, user_id) DO UPDATE SET
		   name = excluded.name,
		   avatar = COALESCE(excluded.avatar, daily_scores.avatar),
		   runs = daily_scores.runs + 1,
		   score = CASE WHEN excluded.score > daily_scores.score THEN excluded.score ELSE daily_scores.score END,
		   updated_at = CASE WHEN excluded.score > daily_scores.score THEN excluded.updated_at ELSE daily_scores.updated_at END`
	)
		.bind(game, day, userId, name, avatar, score, now)
		.run();

	const me = await dailyMe(env, game, day, userId);
	const total = await dailyTotal(env, game, day);
	return json({
		game_id: game,
		day,
		accepted: true,
		improved,
		best: me ? me.score : score,
		rank: me ? me.rank : null,
		runs: me ? me.runs : 1,
		total,
		resets_in: resetsIn(now),
	});
}

/* ===================== 通用 ===================== */

function normalizeStageId(value) {
	const text = String(value || "").trim();
	return STAGE_ID_RE.test(text) ? text : "";
}

function normalizeName(value, max) {
	let text = String(value || "")
		.replace(/[\u0000-\u001f\u007f]/g, "")
		.replace(/\s+/g, " ")
		.trim();
	if (text.length > max) {
		text = text.slice(0, max).trim();
	}
	return text;
}

function clampi(value, lo, hi) {
	if (!Number.isFinite(value)) {
		return lo;
	}
	return Math.max(lo, Math.min(hi, Math.floor(value)));
}

function json(data, status = 200) {
	return new Response(JSON.stringify(data), {
		status,
		headers: {
			"content-type": "application/json; charset=utf-8",
			"cache-control": "no-store",
		},
	});
}

function cors(response) {
	const headers = new Headers(response.headers);
	headers.set("access-control-allow-origin", "*");
	headers.set("access-control-allow-methods", "GET, POST, OPTIONS");
	headers.set("access-control-allow-headers", "content-type");
	headers.set("access-control-max-age", "86400");
	return new Response(response.body, {
		status: response.status,
		statusText: response.statusText,
		headers,
	});
}
