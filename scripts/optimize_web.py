"""Keep the unchanged Godot runtime reusable across game updates."""
import hashlib
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
html_path = root / "index.html"
html = html_path.read_text()
match = re.search(r"const GODOT_CONFIG = (.*?);", html)
config = json.loads(match[1])
old = config["executable"]
runtime_files = sorted(p for p in root.glob(old + ".*") if p.suffix in (".wasm", ".js"))
digest = hashlib.sha256()
for p in runtime_files:
    digest.update(p.read_bytes())
runtime = "engine-" + digest.hexdigest()[:16]
pack_path = root / (old + ".pck")
pack = "cards-" + hashlib.sha256(pack_path.read_bytes()).hexdigest()[:16] + ".pck"
for p in runtime_files:
    p.rename(root / p.name.replace(old, runtime, 1))
pack_path.rename(root / pack)
html = html.replace(old + ".js", runtime + ".js")
config["executable"] = runtime
config["mainPack"] = pack
config["fileSizes"] = {runtime + ".wasm": (root / (runtime + ".wasm")).stat().st_size,
                       pack: (root / pack).stat().st_size}
html = html.replace(match[0], "const GODOT_CONFIG = " + json.dumps(config) + ";")
html = html.replace('<html lang="en">', '<html lang="pt-BR">')
# Cache only immutable, content-addressed game downloads. Storage failures must
# never prevent play (private browsing, quota limits, unsupported Cache API).
cache_script = """
<script>
(() => {
  if (!window.caches) return;
  const originalFetch = window.fetch.bind(window);
  const names = ASSET_NAMES;
  const urls = new Set(names.map(name => new URL(name, location.href).href));
  const cacheName = 'dungeon-downloads-v1';
  const writes = [];
  window.dungeonDownloadsReady = Promise.resolve();
  window.fetch = async function(input, options) {
    const url = new URL(typeof input === 'string' ? input : input.url, location.href).href;
    if (!urls.has(url) || (options && options.method && options.method !== 'GET'))
      return originalFetch(input, options);
    let cache;
    try {
      cache = await caches.open(cacheName);
      const saved = await cache.match(url);
      if (saved) return saved;
    } catch (_) {}
    const response = await originalFetch(input, options);
    if (cache && response.ok) {
      const write = cache.put(url, response.clone()).then(async () => {
        // Keep the current pack/runtime; remove stale versions after replacement.
        for (const key of await cache.keys())
          if (!urls.has(key.url)) await cache.delete(key);
      }).catch(() => {});
      writes.push(write);
      window.dungeonDownloadsReady = Promise.all(writes);
    }
    return response;
  };
})();
</script>
""".replace("ASSET_NAMES", json.dumps([runtime + ".wasm", pack]))
html = html.replace('<script src="', cache_script + '\n<script src="', 1)
html = html.replace('</style>', '''
#status { background: radial-gradient(ellipse at center, #38251c, #100c16 75%); }
#status-splash { display: none; }
#loading-title { color: #f2cf85; font: bold 28px Georgia, serif; text-align: center; }
#loading-detail { color: #d2c3ac; font: 14px system-ui, sans-serif; text-align: center; max-width: 290px; line-height: 1.6; }
#status-progress { position: static; width: 65%; max-width: 320px; margin-top: 24px; accent-color: #dba94c; }
</style>''', 1)
html = html.replace('<progress id="status-progress">', '<h1 id="loading-title">DUNGEON CARDS</h1><p id="loading-detail" role="status">Abrindo a taverna…<br>A primeira abertura precisa baixar o jogo.</p><progress id="status-progress">')
html = html.replace('statusProgress.max = total;', '''statusProgress.max = total;
          const percent = Math.min(100, Math.floor(current / total * 100));
          const detail = document.getElementById('loading-detail');
          if (detail) detail.textContent = percent >= 100
            ? 'Preparando o tabuleiro…' : 'Carregando o jogo… ' + percent + '%';''')
html_path.write_text(html)
print(json.dumps({"runtime": runtime, "pack": pack, "packBytes": config["fileSizes"][pack]}))
