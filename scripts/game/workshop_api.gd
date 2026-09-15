class_name WorkshopApi
extends RefCounted
## 创意工坊客户端：发布关卡包、按时间/点赞浏览、点赞。
##
## ## 总开关
## `ENABLED` 为 false 时，标题页不长出「创意工坊」按钮、编辑器不显示「发布」，
## 整套功能对玩家不可见。开发完成后把它改成 true 即可，不需要动别的地方。
##
## ## 为什么只连国内机
## 工坊接口只实现在 `services/leaderboard/src/standalone.mjs`（115.29.227.196）上，
## Cloudflare 那份 Worker 没有这组路由，而且它在国内被 DNS 污染本来就连不上。
## 排行榜那套双入口故障转移在这里没有意义，所以固定走一个地址，连不上就明说。
##
## ## 鉴权
## 按需求不做鉴权：公司内部小玩法，谁都能发、谁都能赞。点赞的去重只在本机记账
## （`user://workshop_likes.json`），换台机器能重复赞——这是有意接受的取舍。

const ENABLED := true

const BASE_URL := "http://115.29.227.196:8787"
const REQUEST_TIMEOUT_SEC := 8.0
const LIKES_PATH := "user://workshop_likes.json"
const NAME_MAX := 24
const AUTHOR_MAX := 16
const PAGE_SIZE := 30

const SORT_NEW := "new"
const SORT_LIKES := "likes"

static var _liked: Dictionary = {}
static var _liked_loaded := false


## ---- 本机点赞记账 ----

static func _load_liked() -> void:
	if _liked_loaded:
		return
	_liked_loaded = true
	if not FileAccess.file_exists(LIKES_PATH):
		return
	var file := FileAccess.open(LIKES_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_liked = parsed as Dictionary


static func _save_liked() -> void:
	var file := FileAccess.open(LIKES_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_liked))


static func has_liked(id: String) -> bool:
	_load_liked()
	return bool(_liked.get(id, false))


static func _set_liked(id: String, liked: bool) -> void:
	_load_liked()
	if liked:
		_liked[id] = true
	else:
		_liked.erase(id)
	_save_liked()


## ---- 文本清洗（和服务端同一套上限）----

static func normalize_name(value: String) -> String:
	return _clip(value, NAME_MAX)


static func normalize_author(value: String) -> String:
	return _clip(value, AUTHOR_MAX)


static func _clip(value: String, limit: int) -> String:
	var text := value.strip_edges().replace("\n", " ").replace("\t", " ")
	while text.find("  ") >= 0:
		text = text.replace("  ", " ")
	if text.length() > limit:
		text = text.substr(0, limit).strip_edges()
	return text


## ---- 接口 ----

static func fetch_list(
	http: HTTPRequest, sort: String = SORT_NEW, limit: int = PAGE_SIZE, offset: int = 0
) -> Dictionary:
	var path := "/v1/workshop/list?sort=%s&limit=%d&offset=%d" % [
		SORT_LIKES if sort == SORT_LIKES else SORT_NEW,
		clampi(limit, 1, PAGE_SIZE),
		maxi(offset, 0),
	]
	return await _request(http, HTTPClient.METHOD_GET, path, "")


static func fetch_item(http: HTTPRequest, id: String) -> Dictionary:
	return await _request(http, HTTPClient.METHOD_GET, "/v1/workshop/item/" + id.uri_encode(), "")


static func publish(
	http: HTTPRequest, pack_name: String, author: String, data: Dictionary
) -> Dictionary:
	var payload := JSON.stringify({
		"name": normalize_name(pack_name),
		"author": normalize_author(author),
		"data": data,
	})
	return await _request(http, HTTPClient.METHOD_POST, "/v1/workshop/publish", payload)


## 点赞/取消：本机记账决定方向，服务端只管加减。返回里带上 `liked` 方便直接刷 UI。
static func toggle_like(http: HTTPRequest, id: String) -> Dictionary:
	var want := not has_liked(id)
	var payload := JSON.stringify({"id": id, "delta": 1 if want else -1})
	var result := await _request(http, HTTPClient.METHOD_POST, "/v1/workshop/like", payload)
	if bool(result.get("ok", false)):
		_set_liked(id, want)
	result["liked"] = has_liked(id)
	return result


static func mark_play(http: HTTPRequest, id: String) -> Dictionary:
	return await _request(http, HTTPClient.METHOD_POST, "/v1/workshop/play", JSON.stringify({"id": id}))


## ---- 传输 ----

static func _request(http: HTTPRequest, method: int, path: String, body: String) -> Dictionary:
	if http == null:
		return {"ok": false, "error": "no_http"}
	http.timeout = REQUEST_TIMEOUT_SEC
	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		http.cancel_request()
	var headers: PackedStringArray = ["content-type: application/json"]
	var err := http.request(BASE_URL + path, headers, method, body)
	if err != OK:
		return {"ok": false, "error": "request_failed", "code": err}
	var result: Array = await http.request_completed
	var result_code: int = int(result[0])
	var response_code: int = int(result[1])
	var response_body := (result[3] as PackedByteArray).get_string_from_utf8()
	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "http_result", "result": result_code, "status": response_code}
	var parsed = JSON.parse_string(response_body)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "bad_response", "status": response_code}
	var data := parsed as Dictionary
	data["ok"] = response_code >= 200 and response_code < 300
	data["status"] = response_code
	return data
