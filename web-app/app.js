const rowsEl = document.getElementById("rows");
const tsEl = document.getElementById("ts");
const qEl = document.getElementById("q");
const player = document.getElementById("player");
const partsEl = document.getElementById("parts");
const alertEl = document.getElementById("alert");
let catalog = { updatedAt: "", episodes: [] };
let featured = null;

async function load() {
  alertEl.innerHTML = "";
  try {
    const r = await fetch("./catalog.json", { cache: "no-store" });
    if (!r.ok) throw new Error("HTTP " + r.status);
    catalog = await r.json();
  } catch (e) {
    // Fail-soft: keep old cache, show notice (never blank)
    const note = document.createElement("p");
    note.className = "notice";
    note.setAttribute("role", "alert");
    note.textContent = "更新失敗，顯示快取內容：" + String(e);
    alertEl.appendChild(note);
  }
  render();
}

function thumbInitial(title) {
  const m = (title || "?").trim();
  return m ? m[0] : "?";
}

function render() {
  const q = (qEl.value || "").toLowerCase();
  const eps = catalog.episodes.filter((e) => (e.title || "").toLowerCase().includes(q));
  tsEl.textContent = catalog.updatedAt ? "目錄更新: " + catalog.updatedAt : "無快取";
  document.getElementById("meta").textContent = eps.length + " 集 (快取優先，失敗不清空)";

  featured = eps[0] || null;
  document.getElementById("herotitle").textContent = featured ? featured.title : (q ? "沒有符合的集數" : "尚無內容");
  document.getElementById("herometa").textContent = featured ? (featured.date + " · 綜藝") : "";

  rowsEl.innerHTML = "";
  if (!eps.length) {
    const p = document.createElement("p");
    p.setAttribute("role", "status");
    p.textContent = q ? "沒有符合「" + qEl.value + "」的結果。" : "尚無集數，請按手動更新。";
    rowsEl.appendChild(p);
    return;
  }
  eps.forEach((ep) => {
    const card = document.createElement("div");
    card.className = "card";
    const btn = document.createElement("button");
    btn.className = "cardbtn";
    btn.setAttribute("aria-label", "播放 " + ep.title);
    const thumb = document.createElement("div");
    thumb.className = "thumb";
    thumb.textContent = thumbInitial(ep.title);
    const body = document.createElement("div");
    body.className = "cardbody";
    const t = document.createElement("p");
    t.className = "t";
    t.textContent = ep.title;
    const b = document.createElement("span");
    b.className = "badge";
    b.textContent = ep.date || "";
    body.appendChild(t);
    body.appendChild(b);
    btn.appendChild(thumb);
    btn.appendChild(body);
    btn.addEventListener("click", () => playEpisode(ep));
    card.appendChild(btn);
    rowsEl.appendChild(card);
  });
}

function playEpisode(ep) {
  const parts = ep.parts && ep.parts.length ? ep.parts : [{ label: "Part 1", url: ep.url }];
  partsEl.innerHTML = "";
  parts.forEach((p, i) => {
    const b = document.createElement("button");
    b.className = i === 0 ? "btn" : "btn secondary";
    b.style.marginRight = "0.5rem";
    b.textContent = p.label;
    b.addEventListener("click", () => { player.src = p.url; player.play().catch(() => {}); });
    partsEl.appendChild(b);
  });
  player.src = parts[0].url;
  player.focus();
  document.getElementById("ph").scrollIntoView();
}

document.getElementById("heroplay").addEventListener("click", () => { if (featured) playEpisode(featured); });
document.getElementById("heroinfo").addEventListener("click", () => { if (featured) alert(featured.title + "\n" + (featured.date || "")); });
document.getElementById("refresh").addEventListener("click", load);
qEl.addEventListener("input", render);
load();
