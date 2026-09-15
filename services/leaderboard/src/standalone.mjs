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
const STARTED_AT = Date.now();

// ---- 分数校验 ---------------------------------------------------------
// 2026-09-16 加：榜上混进过一批老计分模型的分（连击倍率那一版），普通关最高到了
// 上限的 3.2 倍。老版本还在外面跑，所以在服务端挡一道，别再让不可能的分进来。
//
// 两条判据，都来自客户端的计分口径（scripts/game/score_combo.gd）：
//   max  普通关每盘的用时奖励最多 1000 分，所以整关上限 = 盘数 × 1000。
//        盘数取自 scripts/game/stage_table.gd 的 boards 数组长度，**改关卡表要同步改这里**。
//        无尽关没有终点，max 记 0 表示不设上限。
//   step 计分粒度。普通关的用时奖励恒为 10 的倍数（1000 - 10×秒），所以总分必是 10 的
//        倍数；无尽关每枚雷 100 分，总分必是 100 的倍数。老模型那一版每笔是
//        100+28(n-1)，落不到这两个格子上，正好被这一条筛掉。
//
// 关卡表里没有的 id 一律放行：宁可漏，也不要在加新关时把正常成绩挡在门外。
const STAGE_RULES = {
	grass_1: { max: 8000, step: 10 },
	grass_2: { max: 10000, step: 10 },
	grass_3: { max: 11000, step: 10 },
	river_1: { max: 12000, step: 10 },
	river_2: { max: 13000, step: 10 },
	coast_1: { max: 14000, step: 10 },
	endless: { max: 0, step: 100 },
};

// 返回空串表示这个分数合法；否则返回拒收原因。
function checkScore(stage, score) {
	const rule = STAGE_RULES[String(stage).toLowerCase()];
	if (!rule) {
		return "";
	}
	if (rule.max > 0 && score > rule.max) {
		return "score_too_high";
	}
	if (score % rule.step !== 0) {
		return "score_not_aligned";
	}
	return "";
}
const STAGE_LABELS = [
	["grass_1", "青草坡"],
	["grass_2", "麦垄"],
	["grass_3", "老井村"],
	["river_1", "双桥"],
	["river_2", "深潭"],
	["coast_1", "尽头港"],
	["endless", "无尽远海"],
];
const DASH_TOP = 10;

// ---- 创意工坊 ----------------------------------------------------------
// 公司内部小玩法，按用户要求不做鉴权。存储沿用排行榜那套整文件 JSON，
// 量级是几十到几百个关卡包，重写一次几十 KB 没有任何压力。真到上万条再换 SQLite。
const WORKSHOP_FILE = join(DATA_DIR, "workshop.json");
const WORKSHOP_NAME_MAX = 24;
const WORKSHOP_AUTHOR_MAX = 16;
const WORKSHOP_LIST_MAX = 60;
const WORKSHOP_BYTES_MAX = 64 * 1024;
const WORKSHOP_MAPS_MAX = 20;

function loadWorkshop() {
	if (!existsSync(WORKSHOP_FILE)) {
		return { rows: [] };
	}
	try {
		const parsed = JSON.parse(readFileSync(WORKSHOP_FILE, "utf8"));
		if (!parsed || !Array.isArray(parsed.rows)) {
			return { rows: [] };
		}
		return { rows: parsed.rows };
	} catch {
		return { rows: [] };
	}
}

function saveWorkshop() {
	mkdirSync(DATA_DIR, { recursive: true });
	writeFileSync(WORKSHOP_FILE, JSON.stringify(workshop), "utf8");
}

let workshop = loadWorkshop();

function newWorkshopId() {
	for (let attempt = 0; attempt < 40; attempt += 1) {
		let id = "w";
		for (let i = 0; i < 8; i += 1) {
			id += "0123456789abcdef"[Math.floor(Math.random() * 16)];
		}
		if (!workshop.rows.some((row) => row.id === id)) {
			return id;
		}
	}
	return "w" + Date.now().toString(16).slice(-8);
}

function clipText(value, max) {
	let text = String(value == null ? "" : value)
		.replace(/[\u0000-\u001f\u007f]/g, "")
		.replace(/\s+/g, " ")
		.trim();
	if (text.length > max) {
		text = text.slice(0, max).trim();
	}
	return text;
}

// 只挡明显的垃圾：结构对不上、地图太多、整体太大。规则细节以客户端为准。
function checkPack(data) {
	if (!data || typeof data !== "object" || Array.isArray(data)) {
		return "数据不是对象";
	}
	const maps = data.maps;
	if (!Array.isArray(maps) || maps.length < 1) {
		return "缺少 maps 数组";
	}
	if (maps.length > WORKSHOP_MAPS_MAX) {
		return "地图最多 " + WORKSHOP_MAPS_MAX + " 张";
	}
	for (const one of maps) {
		if (!one || typeof one !== "object") {
			return "maps 里有一项不是对象";
		}
		if (!Array.isArray(one.map) || one.map.length < 1) {
			return "maps 里有一项缺少 map";
		}
	}
	if (JSON.stringify(data).length > WORKSHOP_BYTES_MAX) {
		return "关卡包过大";
	}
	return "";
}

// 列表页只要够画缩略图：第一张地图的尺寸和一串 0/1。
function previewOf(data) {
	const first = (data && Array.isArray(data.maps)) ? data.maps[0] : null;
	if (!first || !Array.isArray(first.map)) {
		return { w: 0, h: 0, cells: "" };
	}
	const rows = first.map;
	let cells = "";
	let width = 0;
	for (const row of rows) {
		if (Array.isArray(row)) {
			width = Math.max(width, row.length);
			for (const bit of row) {
				cells += (bit === 1 || bit === true || bit === "1" || bit === "#") ? "1" : "0";
			}
		} else if (typeof row === "string") {
			let line = "";
			for (const ch of row) {
				if (ch === " " || ch === ",") { continue; }
				line += (ch === "1" || ch === "#") ? "1" : "0";
			}
			width = Math.max(width, line.length);
			cells += line;
		}
	}
	return { w: width, h: rows.length, cells };
}

function mapsMineTotal(data) {
	let total = 0;
	for (const one of (data.maps || [])) {
		total += Math.max(0, Math.floor(Number(one.mines) || 0));
	}
	return total;
}

function workshopBrief(row) {
	return {
		id: row.id,
		name: row.name,
		author: row.author,
		maps: Array.isArray(row.data.maps) ? row.data.maps.length : 0,
		mines_total: mapsMineTotal(row.data),
		likes: row.likes,
		plays: row.plays,
		created_at: row.created_at,
		updated_at: row.updated_at,
		preview: previewOf(row.data),
	};
}

function handleWorkshopList(url) {
	const sort = url.searchParams.get("sort") === "likes" ? "likes" : "new";
	const limit = clampi(Number(url.searchParams.get("limit") || WORKSHOP_LIST_MAX), 1, WORKSHOP_LIST_MAX);
	const offset = clampi(Number(url.searchParams.get("offset") || 0), 0, 1000000);
	const rows = workshop.rows.slice().sort((a, b) => {
		if (sort === "likes" && b.likes !== a.likes) {
			return b.likes - a.likes;
		}
		return b.created_at - a.created_at;
	});
	return json({
		ok: true,
		sort,
		total: rows.length,
		items: rows.slice(offset, offset + limit).map(workshopBrief),
	});
}

function handleWorkshopItem(id) {
	const row = workshop.rows.find((one) => one.id === id);
	if (!row) {
		return json({ error: "not_found" }, 404);
	}
	return json({ ok: true, item: Object.assign(workshopBrief(row), { data: row.data }) });
}

async function handleWorkshopPublish(req) {
	let body;
	try {
		body = JSON.parse(await readBody(req));
	} catch {
		return json({ error: "bad_json" }, 400);
	}
	const name = clipText(body && body.name, WORKSHOP_NAME_MAX);
	const author = clipText(body && body.author, WORKSHOP_AUTHOR_MAX);
	if (!name) {
		return json({ error: "bad_name" }, 400);
	}
	const data = body ? body.data : null;
	const bad = checkPack(data);
	if (bad) {
		return json({ error: "bad_pack", detail: bad }, 400);
	}
	const now = Date.now();
	const row = {
		id: newWorkshopId(),
		name,
		author: author || "匿名",
		created_at: now,
		updated_at: now,
		likes: 0,
		plays: 0,
		data,
	};
	workshop.rows.push(row);
	saveWorkshop();
	return json({ ok: true, id: row.id, item: workshopBrief(row) });
}

async function handleWorkshopLike(req) {
	let body;
	try {
		body = JSON.parse(await readBody(req));
	} catch {
		return json({ error: "bad_json" }, 400);
	}
	const row = workshop.rows.find((one) => one.id === String(body && body.id));
	if (!row) {
		return json({ error: "not_found" }, 404);
	}
	const delta = Number(body && body.delta) < 0 ? -1 : 1;
	row.likes = Math.max(0, Math.floor(row.likes) + delta);
	saveWorkshop();
	return json({ ok: true, id: row.id, likes: row.likes });
}

async function handleWorkshopPlay(req) {
	let body;
	try {
		body = JSON.parse(await readBody(req));
	} catch {
		return json({ error: "bad_json" }, 400);
	}
	const row = workshop.rows.find((one) => one.id === String(body && body.id));
	if (!row) {
		return json({ error: "not_found" }, 404);
	}
	row.plays = Math.max(0, Math.floor(row.plays) + 1);
	saveWorkshop();
	return json({ ok: true, id: row.id, plays: row.plays });
}

async function handleWorkshopDelete(req) {
	let body;
	try {
		body = JSON.parse(await readBody(req));
	} catch {
		return json({ error: "bad_json" }, 400);
	}
	const id = String(body && body.id);
	const before = workshop.rows.length;
	workshop.rows = workshop.rows.filter((one) => one.id !== id);
	if (workshop.rows.length === before) {
		return json({ error: "not_found" }, 404);
	}
	saveWorkshop();
	return json({ ok: true, id });
}

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
	// 预判和提交用同一把尺：不然会出现「说你能上榜、真提交却被退回」。
	const shape = checkScore(stage, score);
	if (shape) {
		return json({ stage_id: stage, qualifies: false, rank: null, cutoff: 0, rejected: shape });
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
	const shape = checkScore(stage, score);
	if (shape) {
		// 打一行日志，便于回头看是谁的哪个版本还在发老分。
		console.log("reject_score", shape, stage, name, score);
		const rule = STAGE_RULES[String(stage).toLowerCase()] || {};
		return json({ error: shape, stage_id: stage, score, max: rule.max || 0, step: rule.step || 0 }, 400);
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

function handleStats() {
	const known = new Set(STAGE_LABELS.map((pair) => pair[0]));
	const order = STAGE_LABELS.slice();
	for (const row of store.rows) {
		if (!known.has(row.stage_id)) {
			known.add(row.stage_id);
			order.push([row.stage_id, row.stage_id]);
		}
	}
	let lastUpdate = 0;
	for (const row of store.rows) {
		if (Number(row.updated_at) > lastUpdate) {
			lastUpdate = Number(row.updated_at);
		}
	}
	const stages = order.map((pair) => {
		const rows = sortRows(stageRows(pair[0]));
		let stageLast = 0;
		for (const row of rows) {
			if (Number(row.updated_at) > stageLast) {
				stageLast = Number(row.updated_at);
			}
		}
		return {
			stage_id: pair[0],
			name: pair[1],
			count: rows.length,
			last_update: stageLast,
			top: rows.slice(0, DASH_TOP).map((row, index) => ({
				rank: index + 1,
				name: row.name,
				score: row.score,
				updated_at: row.updated_at,
			})),
		};
	});
	let likeTotal = 0;
	let workshopLast = 0;
	for (const row of workshop.rows) {
		likeTotal += Math.max(0, Math.floor(row.likes) || 0);
		if (Number(row.created_at) > workshopLast) {
			workshopLast = Number(row.created_at);
		}
	}
	return json({
		ok: true,
		server_time: Date.now(),
		started_at: STARTED_AT,
		uptime_sec: Math.floor((Date.now() - STARTED_AT) / 1000),
		total_entries: store.rows.length,
		last_update: lastUpdate,
		top_limit: TOP_LIMIT,
		stages,
		workshop: {
			count: workshop.rows.length,
			likes: likeTotal,
			last_publish: workshopLast,
		},
	});
}

function html(body) {
	return {
		status: 200,
		body,
		headers: {
			"content-type": "text/html; charset=utf-8",
			"cache-control": "no-store",
			"content-length": String(Buffer.byteLength(body)),
			connection: "close",
		},
	};
}

const DASHBOARD = `<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>咕咕啾啾 排行榜监控</title>
<style>
  :root{
    --bg:#161b13; --panel:#212a1c; --panel2:#1a2116; --line:#33402b;
    --gold:#ffd768; --body:#e8efd8; --muted:#95a487; --score:#f3e7b0;
    --r1:#ffd768; --r2:#d5deea; --r3:#e0b07a;
    --ok:#7dd67d; --bad:#e57373; --warn:#e0b07a;
  }
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg);color:var(--body);
    font:14px/1.6 "PingFang SC","Microsoft YaHei",-apple-system,Segoe UI,sans-serif;
    padding:18px 16px 40px;-webkit-font-smoothing:antialiased}
  .wrap{max-width:1080px;margin:0 auto}
  header{display:flex;flex-wrap:wrap;align-items:baseline;gap:12px;margin-bottom:4px}
  h1{font-size:22px;margin:0;color:var(--gold);letter-spacing:.04em;font-weight:600}
  .sub{color:var(--muted);font-size:12px}
  .bar{display:flex;flex-wrap:wrap;align-items:center;gap:10px;margin:14px 0 20px}
  .dot{width:9px;height:9px;border-radius:50%;background:var(--muted);flex:none}
  .dot.ok{background:var(--ok);box-shadow:0 0 8px rgba(125,214,125,.7)}
  .dot.bad{background:var(--bad);box-shadow:0 0 8px rgba(229,115,115,.7)}
  #state{font-size:13px}
  .spacer{flex:1}
  button{background:var(--panel);color:var(--body);border:1px solid var(--line);
    border-radius:7px;padding:6px 13px;font-size:12px;cursor:pointer;font-family:inherit}
  button:hover{border-color:var(--gold);color:var(--gold)}
  .cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(158px,1fr));gap:10px;margin-bottom:22px}
  .card{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:12px 14px}
  .card .k{color:var(--muted);font-size:11px;letter-spacing:.06em}
  .card .v{color:var(--score);font-size:21px;margin-top:3px;
    font-variant-numeric:tabular-nums;font-weight:600}
  .card .v small{font-size:12px;color:var(--muted);font-weight:400;margin-left:3px}
  .stages{display:grid;grid-template-columns:repeat(auto-fit,minmax(310px,1fr));gap:14px}
  .stage{background:var(--panel);border:1px solid var(--line);border-radius:10px;overflow:hidden}
  .stage h2{margin:0;font-size:15px;padding:11px 14px;background:var(--panel2);
    border-bottom:1px solid var(--line);display:flex;align-items:baseline;gap:8px;font-weight:600}
  .stage h2 .id{color:var(--muted);font-size:11px;font-weight:400}
  .stage h2 .n{margin-left:auto;color:var(--muted);font-size:11px;font-weight:400}
  table{width:100%;border-collapse:collapse}
  td{padding:6px 14px;border-bottom:1px solid rgba(51,64,43,.55);font-size:13px}
  tr:last-child td{border-bottom:none}
  .rk{width:38px;color:var(--muted);font-variant-numeric:tabular-nums;text-align:right}
  .rk.r1{color:var(--r1);font-weight:600}.rk.r2{color:var(--r2);font-weight:600}
  .rk.r3{color:var(--r3);font-weight:600}
  .nm{word-break:break-all}
  .sc{text-align:right;color:var(--score);font-variant-numeric:tabular-nums;white-space:nowrap}
  .ago{width:78px;text-align:right;color:var(--muted);font-size:11px;white-space:nowrap}
  .empty{padding:16px 14px;color:var(--muted);font-size:12px}
  footer{margin-top:26px;color:var(--muted);font-size:11px;line-height:1.9}
  code{background:var(--panel);border:1px solid var(--line);border-radius:4px;
    padding:1px 5px;font-size:11px;color:var(--body)}
  @media(max-width:520px){
    body{padding:14px 11px 30px}h1{font-size:19px}
    .card .v{font-size:18px}td{padding:5px 11px}
    .ago{display:none}
  }
</style>
</head>
<body>
<div class="wrap">

  <header>
    <h1>咕咕啾啾 · 排行榜监控</h1>
    <span class="sub">115.29.227.196:8787</span>
  </header>

  <div class="bar">
    <span class="dot" id="dot"></span>
    <span id="state">连接中…</span>
    <span class="spacer"></span>
    <span class="sub" id="tick"></span>
    <button id="refresh">立即刷新</button>
  </div>

  <div class="cards" id="cards"></div>
  <div class="stages" id="stages"></div>

  <footer>
    每 15 秒自动刷新。数据来自 <code>/v1/stats</code>，同机同端口。<br>
    服务以计划任务 <code>BigLeiLeaderboard</code> 运行，开机自启；日志在
    <code>C:\\biglei-leaderboard\\service.log</code>。
  </footer>

</div>

<script>
(function () {
  var REFRESH = 15;
  var left = REFRESH;
  var timer = null;

  function pad(n) { return n < 10 ? "0" + n : "" + n; }

  function fmtScore(n) {
    return String(n).replace(/\\B(?=(\\d{3})+(?!\\d))/g, ",");
  }

  function fmtUptime(sec) {
    var d = Math.floor(sec / 86400);
    var h = Math.floor((sec % 86400) / 3600);
    var m = Math.floor((sec % 3600) / 60);
    if (d > 0) { return d + " 天 " + h + " 小时"; }
    if (h > 0) { return h + " 小时 " + m + " 分"; }
    return m + " 分 " + (sec % 60) + " 秒";
  }

  function ago(ts, now) {
    if (!ts) { return "—"; }
    var s = Math.floor((now - ts) / 1000);
    if (s < 60) { return s + " 秒前"; }
    if (s < 3600) { return Math.floor(s / 60) + " 分前"; }
    if (s < 86400) { return Math.floor(s / 3600) + " 小时前"; }
    return Math.floor(s / 86400) + " 天前";
  }

  function clock(ts) {
    var d = new Date(ts);
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) +
      " " + pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds());
  }

  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  function card(k, v, unit) {
    return '<div class="card"><div class="k">' + k + '</div><div class="v">' +
      v + (unit ? '<small>' + unit + '</small>' : '') + '</div></div>';
  }

  function render(d) {
    var now = d.server_time;

    document.getElementById("cards").innerHTML =
      card("总记录数", d.total_entries, "条") +
      card("有人上榜的关卡", d.stages.filter(function (s) { return s.count > 0; }).length,
           "/ " + d.stages.length) +
      card("最近一次上榜", ago(d.last_update, now)) +
      card("服务已运行", fmtUptime(d.uptime_sec)) +
      card("服务器时间", clock(now).slice(11)) +
      (d.workshop ? card("工坊关卡包", d.workshop.count, "个 · " + d.workshop.likes + " 赞") : "");

    document.getElementById("stages").innerHTML = d.stages.map(function (s) {
      var head = '<h2>' + esc(s.name) +
        '<span class="id">' + esc(s.stage_id) + '</span>' +
        '<span class="n">' + s.count + ' / ' + d.top_limit + '</span></h2>';
      if (!s.top.length) {
        return '<div class="stage">' + head + '<div class="empty">还没有人上榜</div></div>';
      }
      var rows = s.top.map(function (e) {
        var cls = e.rank <= 3 ? " r" + e.rank : "";
        return '<tr><td class="rk' + cls + '">' + e.rank + '</td>' +
          '<td class="nm">' + esc(e.name) + '</td>' +
          '<td class="sc">' + fmtScore(e.score) + '</td>' +
          '<td class="ago">' + ago(e.updated_at, now) + '</td></tr>';
      }).join("");
      return '<div class="stage">' + head + '<table>' + rows + '</table></div>';
    }).join("");
  }

  function setState(ok, msg) {
    document.getElementById("dot").className = "dot " + (ok ? "ok" : "bad");
    document.getElementById("state").textContent = msg;
    document.getElementById("state").style.color = ok ? "" : "var(--bad)";
  }

  function load() {
    fetch("/v1/stats", { cache: "no-store" })
      .then(function (r) {
        if (!r.ok) { throw new Error("HTTP " + r.status); }
        return r.json();
      })
      .then(function (d) {
        render(d);
        setState(true, "服务正常 · 更新于 " + clock(Date.now()).slice(11));
        left = REFRESH;
      })
      .catch(function (e) {
        setState(false, "连不上服务 · " + e.message);
        left = REFRESH;
      });
  }

  function tick() {
    left -= 1;
    document.getElementById("tick").textContent = left + " 秒后刷新";
    if (left <= 0) { load(); }
  }

  document.getElementById("refresh").addEventListener("click", function () {
    left = REFRESH;
    load();
  });

  load();
  timer = setInterval(tick, 1000);
})();
</script>
</body>
</html>
`;

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

	if (req.method === "GET" && (path === "/" || path === "/dashboard")) {
		return withCors(html(DASHBOARD));
	}

	if (req.method === "GET" && path === "/v1/stats") {
		return withCors(handleStats());
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

	if (req.method === "GET" && path === "/v1/workshop/list") {
		return withCors(handleWorkshopList(url));
	}

	const itemMatch = path.match(/^\/v1\/workshop\/item\/([^/]+)$/);
	if (req.method === "GET" && itemMatch) {
		return withCors(handleWorkshopItem(decodeURIComponent(itemMatch[1])));
	}

	if (req.method === "POST" && path === "/v1/workshop/publish") {
		return withCors(await handleWorkshopPublish(req));
	}

	if (req.method === "POST" && path === "/v1/workshop/like") {
		return withCors(await handleWorkshopLike(req));
	}

	if (req.method === "POST" && path === "/v1/workshop/play") {
		return withCors(await handleWorkshopPlay(req));
	}

	if (req.method === "POST" && path === "/v1/workshop/delete") {
		return withCors(await handleWorkshopDelete(req));
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
