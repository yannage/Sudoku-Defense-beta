"""Generate Steam's supported bulk-import CSVs from the in-game catalog."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
CATALOG = json.loads((ROOT / "godot/data/achievements.json").read_text(encoding="utf-8"))
assert len(CATALOG) == 26 and len({row["id"] for row in CATALOG}) == 26
DEFINITION_FIELDS = [
    "api_name (required, unique; the name your game passes to the API)",
    "setid (optional; the id of a set that already exists)",
    "permission (one of Client, GameServer, OfficialGameServer)",
    "spoiler (true or false)", "archived (true or false)",
    "progress_stat_name (optional; the name of a stat that already exists, blank for no progress bar)",
    "progress_stat_min (number, no lower than the stat's own min)",
    "progress_stat_max (number, above min and no higher than the stat's own max)",
]
with (OUT / "definitions.csv").open("w", encoding="utf-8", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(DEFINITION_FIELDS)
    for entry in CATALOG:
        writer.writerow([entry["id"], "", "Client", "false", "false", "", 0, 0])
with (OUT / "localization.csv").open("w", encoding="utf-8", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(["api_name (required; must match an api_name from the definitions CSV)",
                     "field (name or description)", "english"])
    for entry in CATALOG:
        writer.writerow([entry["id"], "name", entry["name"]])
        writer.writerow([entry["id"], "description", entry["description"]])
for entry in CATALOG:
    for suffix in ("ACHIEVED", "UNACHIEVED"):
        assert (OUT / "icons" / f"{entry['id']}_{suffix}.png").is_file()
print("Prepared 26 definitions, 52 English strings and 52 matching icon files.")
