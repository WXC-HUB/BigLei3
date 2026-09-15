/**
 * 本地联调服务器：不依赖 wrangler / 登录，用 Node 24 内置 node:sqlite 模拟 D1，直接跑 src/index.js 的 Worker。
 *   node dev-server.mjs            → http://127.0.0.1:8788（内存库）
 *   PORT=8790 DB_FILE=./data/dev.sqlite node dev-server.mjs
 * 客户端把 localStorage['ttddp.lb.api'] 设成 http://127.0.0.1:8788 即可指向这里。
 */
import { createServer } from "node:http";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import worker from "./src/index.js";

const PORT = Number(process.env.PORT || 8788);
const db = new DatabaseSync(process.env.DB_FILE || ":memory:");
db.exec(readFileSync(new URL("./schema.sql", import.meta.url), "utf8"));

/** 最小 D1 兼容层：prepare().bind().first()/all()/run() */
const D1 = {
	prepare(sql) {
		const stmt = db.prepare(sql);
		let params = [];
		const api = {
			bind(...args) {
				params = args.map((v) => (v === undefined ? null : v));
				return api;
			},
			async first(col) {
				const row = stmt.get(...params) ?? null;
				return col && row ? row[col] : row;
			},
			async all() {
				return { results: stmt.all(...params), success: true };
			},
			async run() {
				const r = stmt.run(...params);
				return { success: true, meta: { changes: Number(r.changes) } };
			},
		};
		return api;
	},
};
const env = { DB: D1 };

createServer(async (req, res) => {
	const chunks = [];
	for await (const c of req) chunks.push(c);
	const url = `http://${req.headers.host || "localhost"}${req.url}`;
	const init = { method: req.method, headers: req.headers };
	if (req.method !== "GET" && req.method !== "HEAD") init.body = Buffer.concat(chunks);
	const request = new Request(url, init);
	let response;
	try {
		response = await worker.fetch(request, env);
	} catch (err) {
		console.error(err);
		response = new Response(JSON.stringify({ error: "server_error" }), { status: 500 });
	}
	res.writeHead(response.status, Object.fromEntries(response.headers));
	res.end(Buffer.from(await response.arrayBuffer()));
}).listen(PORT, "127.0.0.1", () => {
	console.log(`leaderboard dev server (node:sqlite) → http://127.0.0.1:${PORT}`);
});

if (process.argv.includes("--cron")) {
	worker.scheduled({}, env).then(() => console.log("scheduled() ran"));
}
