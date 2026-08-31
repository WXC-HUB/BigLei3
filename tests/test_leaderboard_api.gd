extends SceneTree

const LeaderboardApi := preload("res://scripts/game/leaderboard_api.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	assert(LeaderboardApi.normalize_name("  飞鸟  一号  ") == "飞鸟 一号")
	assert(LeaderboardApi.normalize_name("abcdefghijklmnopqrstuvwxyz").length() == LeaderboardApi.NAME_MAX)
	assert(String(LeaderboardApi.BASE_URL).begins_with("https://"))
	assert(LeaderboardApi.TOP_LIMIT == 100)
	assert(LeaderboardApi.REQUEST_TIMEOUT_SEC >= 5.0)
	var endpoints := LeaderboardApi.endpoint_list()
	assert(endpoints.size() >= 1)
	assert(endpoints.has(LeaderboardApi.BASE_URL.trim_suffix("/")))
	for url in endpoints:
		assert(String(url) != "")
	print("Leaderboard API helpers: name normalize and constants passed")
	quit()
