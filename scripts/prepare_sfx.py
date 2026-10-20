"""Prepare CC0 recorded RPG sound effects for the static GitHub Pages build."""
import io
import os
import re
import urllib.request
import zipfile
from pathlib import Path

SOURCE = "https://opengameart.org/sites/default/files/80-CC0-RPG-SFX_0.zip"
DEST = Path("web/assets/sfx")
DEST.mkdir(parents=True, exist_ok=True)
print("Downloading CC0 RPG effects by rubberduck from OpenGameArt")
try:
    request = urllib.request.Request(SOURCE, headers={"User-Agent": "DungeonCards-build/1.0"})
    with urllib.request.urlopen(request, timeout=25) as response:
        archive = zipfile.ZipFile(io.BytesIO(response.read()))
    candidates = [(n, archive.read(n)) for n in archive.namelist()
                  if n.lower().endswith((".ogg", ".wav", ".mp3")) and not n.startswith("__MACOSX")]
    categories = {
        "steel": ("blade", "sword", "metal", "attack"),
        "fire": ("fire", "spell"),
        "ice": ("spell", "magic"),
        "lightning": ("spell", "magic"),
        "earth": ("stone", "rock", "wood"),
        "water": ("spell", "magic"),
        "heal": ("spell", "magic"),
        "ui": ("item", "coin", "book"),
    }
    selected = []
    for category, keys in categories.items():
        ranked = sorted(candidates, key=lambda item: (
            next((i for i, key in enumerate(keys) if key in item[0].lower()), 99),
            len(item[0]), item[0]))
        if not ranked or not any(key in ranked[0][0].lower() for key in keys):
            print("No suitable recording for", category)
            continue
        filename, data = ranked[0]
        suffix = Path(filename).suffix.lower()
        target = DEST / (category + suffix)
        target.write_bytes(data)
        selected.append(category)
        print(category, "<-", filename, len(data), "bytes")
    required = {"steel", "fire", "lightning"}
    missing = required - set(selected)
    if missing:
        raise RuntimeError("Missing essential recorded sounds: " + ", ".join(sorted(missing)))
except Exception as exc:
    raise RuntimeError("Cannot prepare verified recorded audio assets") from exc
