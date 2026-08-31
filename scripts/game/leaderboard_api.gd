class_name LeaderboardApi
extends RefCounted
## 分关排行榜客户端。先走近的入口，连不上再换下一个。
## CN_URL：香港/国内机。空 = 还没部署，只用 Cloudflare。

const CN_URL := "http://115.29.227.196:8787"
const BASE_URL := "https://biglei-leaderboard.biglei3.workers.dev"
const TOP_LIMIT := 100
const NAME_MAX := 16
const REQUEST_TIMEOUT_SEC := 8.0
const PREFERRED_PATH := "user://leaderboard_endpoint.txt"

static var _preferred_url := ""
static var _preferred_loaded := false


static func normalize_name(value: String) -> String:
	var text := value.strip_edges()
	text = text.replace("\n", " ").replace("\t", " ")
	while text.find("  ") >= 0:
		text = text.replace("  ", " ")
	if text.length() > NAME_MAX:
		text = text.substr(0, NAME_MAX).strip_edges()
	return text


static func endpoint_list() -> PackedStringArray:
	_load_preferred()
	var raw: PackedStringArray = []
	var china := _clean_base(CN_URL)
	var cloudflare := _clean_base(BASE_URL)
	if china != "":
		raw.append(china)
	if cloudflare != "":
		raw.append(cloudflare)
	var ordered: PackedStringArray = []
	if _preferred_url != "" and raw.has(_preferred_url):
		ordered.append(_preferred_url)
	for url in raw:
		if not ordered.has(url):
			ordered.append(url)
	return ordered


static func fetch_top(http: HTTPRequest, stage_id: String, limit: int = TOP_LIMIT) -> Dictionary:
	var path := "/v1/stages/%s/top?limit=%d" % [stage_id.uri_encode(), clampi(limit, 1, TOP_LIMIT)]
	return await _request_json(http, HTTPClient.METHOD_GET, path, "")


static func qualify(http: HTTPRequest, stage_id: String, score: int) -> Dictionary:
	var path := "/v1/stages/%s/qualify?score=%d" % [stage_id.uri_encode(), maxi(score, 0)]
	return await _request_json(http, HTTPClient.METHOD_GET, path, "")


static func submit(http: HTTPRequest, stage_id: String, player_name: String, score: int) -> Dictionary:
	var payload := JSON.stringify({
		"stage_id": stage_id,
		"name": normalize_name(player_name),
		"score": maxi(score, 0),
	})
	return await _request_json(http, HTTPClient.METHOD_POST, "/v1/submit", payload)


static func _request_json(http: HTTPRequest, method: int, path: String, body: String) -> Dictionary:
	if http == null:
		return {"ok": false, "error": "no_http"}
	http.timeout = REQUEST_TIMEOUT_SEC
	var last := {"ok": false, "error": "no_endpoint"}
	for base in endpoint_list():
		var result := await _request_one(http, method, base + path, body)
		last = result
		if bool(result.get("ok", false)):
			_remember(base)
			return result
		# 服务端明确拒绝（参数错）不必换入口；连不上/超时才试下一个。
		if _is_client_error(result):
			return result
	return last


static func _request_one(http: HTTPRequest, method: int, url: String, body: String) -> Dictionary:
	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		http.cancel_request()
	var headers: PackedStringArray = ["content-type: application/json"]
	var err := http.request(url, headers, method, body)
	if err != OK:
		return {"ok": false, "error": "request_failed", "code": err}
	var result: Array = await http.request_completed
	var result_code: int = int(result[0])
	var response_code: int = int(result[1])
	var response_body := (result[3] as PackedByteArray).get_string_from_utf8()
	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"error": "http_result",
			"result": result_code,
			"status": response_code,
			"raw": response_body,
		}
	var parsed = JSON.parse_string(response_body)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "bad_response", "status": response_code, "raw": response_body}
	var data := parsed as Dictionary
	data["ok"] = response_code >= 200 and response_code < 300
	data["status"] = response_code
	return data


static func _is_client_error(result: Dictionary) -> bool:
	var status := int(result.get("status", 0))
	return status >= 400 and status < 500


static func _clean_base(value: String) -> String:
	return value.strip_edges().trim_suffix("/")


static func _load_preferred() -> void:
	if _preferred_loaded:
		return
	_preferred_loaded = true
	if not FileAccess.file_exists(PREFERRED_PATH):
		return
	var file := FileAccess.open(PREFERRED_PATH, FileAccess.READ)
	if file == null:
		return
	_preferred_url = _clean_base(file.get_as_text())


static func _remember(base: String) -> void:
	var url := _clean_base(base)
	if url == "" or _preferred_url == url:
		return
	_preferred_url = url
	var file := FileAccess.open(PREFERRED_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(url)
