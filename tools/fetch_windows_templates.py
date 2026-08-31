from pathlib import Path
from remotezip import RemoteZip

URL = "https://ghfast.top/https://github.com/godotengine/godot/releases/download/4.6.1-stable/Godot_v4.6.1-stable_export_templates.tpz"
OUT = Path.home() / "AppData/Roaming/Godot/export_templates/4.6.1.stable"
WANTED = [
	"templates/windows_release_x86_64.exe",
	"templates/windows_release_x86_64_console.exe",
]

OUT.mkdir(parents=True, exist_ok=True)
(OUT / "version.txt").write_text("4.6.1.stable\n", encoding="utf-8")

with RemoteZip(URL) as zf:
	names = zf.namelist()
	print("entries", len(names))
	for wanted in WANTED:
		match = wanted if wanted in names else next((n for n in names if n.endswith(wanted.split("/")[-1])), None)
		if match is None:
			raise SystemExit(f"missing {wanted}")
		print("downloading", match, "...")
		data = zf.read(match)
		dest = OUT / Path(match).name
		dest.write_bytes(data)
		print("wrote", dest, len(data))

print("done", OUT)
