import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const dist = path.resolve(root, "dist");

function copyDirSync(src, dest) {
  if (!fs.existsSync(src)) return;
  fs.mkdirSync(dest, { recursive: true });
  const entries = fs.readdirSync(src, { withFileTypes: true });
  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDirSync(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

console.log("Building production artifacts...");

// 0. Build Video.js 10 bundles and React App
execSync("node scripts/build-videojs10.mjs", { stdio: "inherit", cwd: root });

// Clean previous build
if (fs.existsSync(dist)) {
  fs.rmSync(dist, { recursive: true, force: true });
}
fs.mkdirSync(dist, { recursive: true });

// Copy web-app to dist/web-app
const distWebApp = path.join(dist, "web-app");
copyDirSync(path.join(root, "web-app"), distWebApp);
console.log(`✓ Bundled web-app -> ${path.relative(root, distWebApp)}`);

// Copy tv-web to dist/tv-web
const distTvWeb = path.join(dist, "tv-web");
copyDirSync(path.join(root, "tv-web"), distTvWeb);
console.log(`✓ Bundled tv-web  -> ${path.relative(root, distTvWeb)}`);

// Copy Cloudflare Pages Functions to dist/functions and sub-apps
const functionsDir = path.join(root, "functions");
if (fs.existsSync(functionsDir)) {
  copyDirSync(functionsDir, path.join(dist, "functions"));
  copyDirSync(functionsDir, path.join(distWebApp, "functions"));
  copyDirSync(functionsDir, path.join(distTvWeb, "functions"));
  console.log("✓ Bundled Cloudflare Pages edge functions");
}

// Generate root preview portal in dist/index.html
const portalHtml = `<!doctype html>
<html lang="zh-Hant">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>dTVSteams - Production Portal</title>
  <style>
    body {
      background: #141414;
      color: #fff;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      padding: 2rem;
      box-sizing: border-box;
    }
    h1 {
      color: #e50914;
      font-size: 3rem;
      letter-spacing: -0.03em;
      margin-bottom: 0.5rem;
    }
    p {
      color: #8c8c8c;
      font-size: 1.25rem;
      margin-bottom: 3rem;
    }
    .cards {
      display: flex;
      gap: 2rem;
      flex-wrap: wrap;
      justify-content: center;
      max-width: 900px;
    }
    .card {
      background: #202020;
      border: 2px solid transparent;
      border-radius: 12px;
      padding: 2.5rem 2rem;
      width: 320px;
      text-decoration: none;
      color: inherit;
      transition: all 0.25s ease;
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
    }
    .card:hover {
      border-color: #e50914;
      transform: translateY(-6px);
      box-shadow: 0 16px 32px rgba(0,0,0,0.8);
    }
    .card h2 {
      font-size: 1.6rem;
      margin: 1rem 0 0.5rem;
    }
    .card p {
      font-size: 1rem;
      color: #aaa;
      margin-bottom: 1.5rem;
    }
    .btn {
      background: #e50914;
      color: #fff;
      padding: 0.75rem 1.75rem;
      border-radius: 6px;
      font-weight: 700;
      font-size: 1.1rem;
    }
  </style>
</head>
<body>
  <h1>dTVSteams</h1>
  <p>Production Distribution Preview Portal</p>
  <div class="cards">
    <a href="./web-app/index.html" class="card">
      <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#ff0000" stroke-width="2"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"></rect><line x1="8" y1="21" x2="16" y2="21"></line><line x1="12" y1="17" x2="12" y2="21"></line></svg>
      <h2>Desktop Web App</h2>
      <p>YouTube-style theater player & simple episode list with direct Part 1/2/3 playback.</p>
      <span class="btn">開啟網頁版</span>
    </a>
    <a href="./web-app/react/index.html" class="card">
      <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#61dafb" stroke-width="2"><circle cx="12" cy="12" r="3"></circle><ellipse cx="12" cy="12" rx="10" ry="4.5" transform="rotate(0 12 12)"></ellipse><ellipse cx="12" cy="12" rx="10" ry="4.5" transform="rotate(60 12 12)"></ellipse><ellipse cx="12" cy="12" rx="10" ry="4.5" transform="rotate(120 12 12)"></ellipse></svg>
      <h2>React v10 Player</h2>
      <p>Official Video.js 10 React component implementation from videojs.org with VideoPlayer & VideoSkin.</p>
      <span class="btn" style="background:#0088cc;">開啟 React 版</span>
    </a>
    <a href="./tv-web/index.html" class="card">
      <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#ff0000" stroke-width="2"><rect x="2" y="7" width="20" height="15" rx="2" ry="2"></rect><polyline points="17 2 12 7 7 2"></polyline></svg>
      <h2>10-Foot TV Web App</h2>
      <p>Leanback TV UI with Video.js, D-pad remote navigation, and quick 1/2/3 Part keys.</p>
      <span class="btn">開啟電視版</span>
    </a>
  </div>
</body>
</html>`;

fs.writeFileSync(path.join(dist, "index.html"), portalHtml, "utf-8");
console.log(`✓ Generated portal -> dist/index.html`);

console.log("Production build successfully completed in ./dist/");
