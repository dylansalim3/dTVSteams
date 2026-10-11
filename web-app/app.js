const rowsEl = document.getElementById("rows");
const tsEl = document.getElementById("ts");
const qEl = document.getElementById("q");
const player = document.getElementById("player");
const partsEl = document.getElementById("parts");
let catalog = { updatedAt: "", episodes: [] };

async function load() {
  try {
    const r = await fetch("./catalog.json", { cache: "no-store" });
    catalog = await r.json();
  } catch (e) {
    catalog = { updatedAt: "", episodes: [], error: String(e) };
  }
  render();
}

function render() {
  const q = (qEl.value || "").toLowerCase();
  tsEl.textContent = catalog.updatedAt ? "更新: " + catalog.updatedAt : "無快取";
  const eps = catalog.episodes.filter((e) => e.title.toLowerCase().includes(q));
  rowsEl.innerHTML = "";
  eps.forEach((ep) => {
    const d = document.createElement("div");
    d.className = "card";
    const a = document.createElement("a");
    a.href = "#";
    a.textContent = ep.title;
    a.onclick = (ev) => { ev.preventDefault(); playEpisode(ep); };
    d.appendChild(a);
    rowsEl.appendChild(d);
  });
  document.getElementById("meta").textContent = eps.length + " 集 (快取優先，失敗不清空)";
}

async function playEpisode(ep) {
  // App-only model: resolve Part URLs at play-time. Demo uses catalog parts if present.
  const parts = ep.parts && ep.parts.length ? ep.parts : [{ label: "Part 1", url: ep.url }];
  partsEl.innerHTML = "";
  parts.forEach((p, i) => {
    const b = document.createElement("button");
    b.textContent = p.label;
    b.style.marginRight = "8px";
    b.onclick = () => { player.src = p.url; player.play().catch(() => {}); };
    partsEl.appendChild(b);
    if (i === 0) { player.src = p.url; }
  });
}

document.getElementById("refresh").onclick = () => load();
qEl.oninput = () => render();
load();
