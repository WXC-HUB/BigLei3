/**
 * BigLei3 分关排行榜 — Cloudflare Worker + D1
 *
 * GET  /health
 * GET  /v1/stages/:stage_id/top?limit=100
 * GET  /v1/stages/:stage_id/qualify?score=N
 * POST /v1/submit  { stage_id, name, score }
 *
 * 线上 Worker：https://biglei-leaderboard.biglei3.workers.dev
 * D1：biglei-leaderboard (7bc716d4-a441-4b0b-9302-75e3b2fc8933)
 */

const TOP_LIMIT = 100;
const NAME_MAX = 16;
const STAGE_ID_RE = /^[a-z0-9_]{1,32}$/i;

export default {
	async fetch(request, env) {
		try {
			if (request.method === "OPTIONS") {
				return cors(new Response(null, { status: 204 }));
			}
			const url = new URL(request.url);
			const path = url.pathname.replace(/\/+$/, "") || "/";

			if (request.method === "GET" && path === "/health") {
				return json({ ok: true });
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

			return cors(json({ error: "not_found" }, 404));
		} catch (err) {
			console.error("leaderboard_error", String(err && err.message ? err.message : err));
			return cors(json({ error: "server_error" }, 500));
		}
	},
};

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
	const name = normalizeName(String(body?.name || ""));
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

function normalizeStageId(value) {
	const text = String(value || "").trim();
	return STAGE_ID_RE.test(text) ? text : "";
}

function normalizeName(value) {
	let text = String(value || "")
		.replace(/[\u0000-\u001f\u007f]/g, "")
		.replace(/\s+/g, " ")
		.trim();
	if (text.length > NAME_MAX) {
		text = text.slice(0, NAME_MAX).trim();
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
