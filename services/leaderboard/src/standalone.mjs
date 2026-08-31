/**
 * BigLei3 排行榜 — 可放在香港/国内机器上的同款接口。
 * 不依赖 npm 包。Node 18+：node src/standalone.mjs
 *
 * GET  /health
 * GET  /v1/stages/:stage_id/top?limit=100
 * GET  /v1/stages/:stage_id/qualify?score=N
 * POST /v1/submit  { stage_id, name, score }
 *
 * 环境变量：PORT（默认 8787）、DATA_DIR（默认 ./data）
 */

import { createServer } from "node:http";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const TOP_LIMIT = 100;
const NAME_MAX = 16;
const STAGE_ID_RE = /^[a-z0-9_]{1,32}$/i;
const PORT = Number(process.env.PORT || 8787);
const DATA_DIR = process.env.DATA_DIR || join(dirname(fileURLToPath(import.meta.url)), "..", "data");
const DATA_FILE = join(DATA_DIR, "scores.json");

function loadStore() {
	if (!existsSync(DATA_FILE)) {
		return { next_id: 1, rows: [] };
	}
	try {
		const parsed = JSON.parse(readFileSync(DATA_FILE, "utf8"));
		if (!parsed || !Array.isArray(parsed.rows)) {
			return { next_id: 1, rows: [] };
		}
		return {
			next_id: Number(parsed.next_id) > 0 ? Number(parsed.next_id) : 1,
			rows: parsed.rows,
		};
	} catch {
		return { next_id: 1, rows: [] };
	}
}

function saveStore(store) {
	mkdirSync(DATA_DIR, { recursive: true });
	writeFileSync(DATA_FILE, JSON.stringify(store), "utf8");
}

let store = loadStore();

function json(data, status = 200) {
	const body = JSON.stringify(data);
	return {
		status,
		body,
		headers: {
			"content-type": "application/json; charset=utf-8",
			"cache-control": "no-store",
			"content-length": String(Buffer.byteLength(body)),
			connection: "close",
		},
	};
}

function withCors(response) {
	return {
		...response,
		headers: {
			...response.headers,
			"access-control-allow-origin": "*",
			"access-control-allow-methods": "GET, POST, OPTIONS",
			"access-control-allow-headers": "content-type",
			"access-control-max-age": "86400",
		},
	};
}

function clampi(value, lo, hi) {
	if (!Number.isFinite(value)) {
		return lo;
	}
	return Math.max(lo, Math.min(hi, Math.floor(value)));
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

function stageRows(stage) {
	return store.rows.filter((row) => row.stage_id === stage);
}

function sortRows(rows) {
	return rows.slice().sort((a, b) => {
		if (b.score !== a.score) {
			return b.score - a.score;
		}
		if (a.updated_at !== b.updated_at) {
			return a.updated_at - b.updated_at;
		}
		return String(a.name).localeCompare(String(b.name));
	});
}

function rankFor(stage, score, name) {
	const better = stageRows(stage).filter(
		(row) => row.score > score || (row.score === score && String(row.name) < String(name))
	).length;
	return better + 1;
}

function handleTop(stageId, url) {
	const stage = normalizeStageId(stageId);
	if (!stage) {
		return json({ error: "bad_stage" }, 400);
	}
	const limit = clampi(Number(url.searchParams.get("limit") || TOP_LIMIT), 1, TOP_LIMIT);
	const entries = sortRows(stageRows(stage))
		.slice(0, limit)
		.map((row, index) => ({
			rank: index + 1,
			name: row.name,
			score: row.score,
			updated_at: row.updated_at,
		}));
	return json({ stage_id: stage, entries });
}

function handleQualify(stageId, url) {
	const stage = normalizeStageId(stageId);
	if (!stage) {
		return json({ error: "bad_stage" }, 400);
	}
	const score = clampi(Number(url.searchParams.get("score") || 0), 0, 2_000_000_000);
	if (score <= 0) {
		return json({ stage_id: stage, qualifies: false, rank: null, cutoff: 0 });
	}
	const rows = sortRows(stageRows(stage));
	const count = rows.length;
	const better = rows.filter((row) => row.score > score).length;
	const rank = better + 1;
	const cutoff = count >= TOP_LIMIT ? Number(rows[TOP_LIMIT - 1]?.score || 0) : 0;
	const qualifies = count < TOP_LIMIT || score > cutoff || (score === cutoff && rank <= TOP_LIMIT);
	return json({
		stage_id: stage,
		qualifies: Boolean(qualifies && rank <= TOP_LIMIT),
		rank: qualifies && rank <= TOP_LIMIT ? rank : null,
		cutoff,
	});
}

async function handleSubmit(req) {
	let body;
	try {
		body = JSON.parse(await readBody(req));
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

	const existing = store.rows.find((row) => row.stage_id === stage && row.name === name);
	if (existing && Number(existing.score) >= score) {
		return json({
			stage_id: stage,
			name,
			score: Number(existing.score),
			accepted: false,
			reason: "not_higher",
			rank: rankFor(stage, Number(existing.score), name),
		});
	}

	const now = Date.now();
	if (existing) {
		existing.score = score;
		existing.updated_at = now;
	} else {
		store.rows.push({
			id: store.next_id++,
			stage_id: stage,
			name,
			score,
			updated_at: now,
		});
	}

	const kept = sortRows(stageRows(stage)).slice(0, TOP_LIMIT);
	const keptIds = new Set(kept.map((row) => row.id));
	store.rows = store.rows.filter((row) => row.stage_id !== stage || keptIds.has(row.id));
	saveStore(store);

	const stillThere = store.rows.find((row) => row.stage_id === stage && row.name === name);
	if (!stillThere) {
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
		score: Number(stillThere.score),
		accepted: true,
		rank: rankFor(stage, Number(stillThere.score), name),
	});
}

function readBody(req) {
	return new Promise((resolve, reject) => {
		const chunks = [];
		req.on("data", (chunk) => chunks.push(chunk));
		req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
		req.on("error", reject);
	});
}

async function route(req) {
	if (req.method === "OPTIONS") {
		return withCors({
			status: 204,
			body: "",
			headers: { "content-length": "0", connection: "close" },
		});
	}
	const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
	const path = url.pathname.replace(/\/+$/, "") || "/";

	if (req.method === "GET" && path === "/health") {
		return withCors(json({ ok: true }));
	}

	const topMatch = path.match(/^\/v1\/stages\/([^/]+)\/top$/);
	if (req.method === "GET" && topMatch) {
		return withCors(handleTop(topMatch[1], url));
	}

	const qualifyMatch = path.match(/^\/v1\/stages\/([^/]+)\/qualify$/);
	if (req.method === "GET" && qualifyMatch) {
		return withCors(handleQualify(qualifyMatch[1], url));
	}

	if (req.method === "POST" && path === "/v1/submit") {
		return withCors(await handleSubmit(req));
	}

	return withCors(json({ error: "not_found" }, 404));
}

const server = createServer(async (req, res) => {
	try {
		const response = await route(req);
		res.writeHead(response.status, response.headers);
		res.end(response.body);
	} catch (err) {
		console.error("leaderboard_error", err && err.message ? err.message : err);
		const response = withCors(json({ error: "server_error" }, 500));
		res.writeHead(response.status, response.headers);
		res.end(response.body);
	}
});

server.listen(PORT, "0.0.0.0", () => {
	console.log(`biglei-leaderboard listening on http://0.0.0.0:${PORT}`);
});
