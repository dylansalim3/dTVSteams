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

// Clean previous build first so build-videojs10 outputs into dist/react cleanly
if (fs.existsSync(dist)) {
  fs.rmSync(dist, { recursive: true, force: true });
}
fs.mkdirSync(dist, { recursive: true });

// 0. Build Video.js 10 bundles and React App -> dist/react
execSync("node scripts/build-videojs10.mjs", { stdio: "inherit", cwd: root });

const tvWebSrc = path.join(root, "tv-web");
const distReact = path.join(dist, "react");
const distTvWeb = path.join(dist, "tv-web");

// Hydrate dist/react with catalog, media thumbnails/samples, and favicons
for (const asset of ["catalog.json", "favicon.ico", "favicon.png"]) {
  const srcAsset = path.join(tvWebSrc, asset);
  if (fs.existsSync(srcAsset)) {
    fs.copyFileSync(srcAsset, path.join(distReact, asset));
  }
}
copyDirSync(path.join(tvWebSrc, "media"), path.join(distReact, "media"));
console.log(`✓ Bundled React v10 -> ${path.relative(root, distReact)}`);

// Copy tv-web to dist/tv-web
copyDirSync(tvWebSrc, distTvWeb);
console.log(`✓ Bundled tv-web  -> ${path.relative(root, distTvWeb)}`);

// Copy Cloudflare Pages Functions to dist/functions and sub-apps
const functionsDir = path.join(root, "functions");
if (fs.existsSync(functionsDir)) {
  copyDirSync(functionsDir, path.join(dist, "functions"));
  copyDirSync(functionsDir, path.join(distReact, "functions"));
  copyDirSync(functionsDir, path.join(distTvWeb, "functions"));
  console.log("✓ Bundled Cloudflare Pages edge functions");
}

// Generate root preview portal in dist/index.html (React v10 + TV Web only)
const portalHtml = `<!doctype html>
<html lang="zh-Hant">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>dTVSteams - Production Portal</title>
  <link rel="icon" type="image/png" href="./tv-web/favicon.png">
  <style>
    body {
      background: #121212;
      color: #fafafa;
      font-family: "Inter", "Noto Sans TC", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
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
      font-size: 2.75rem;
      letter-spacing: -0.03em;
      margin-bottom: 0.5rem;
    }
    p {
      color: #a3a3a3;
      font-size: 1.1rem;
      margin-bottom: 2.5rem;
    }
    .cards {
      display: flex;
      gap: 1.5rem;
      flex-wrap: wrap;
      justify-content: center;
      max-width: 780px;
    }
    .card {
      background: #171717;
      border: 1px solid #262626;
      border-radius: 16px;
      padding: 2rem 1.75rem;
      width: 320px;
      text-decoration: none;
      color: inherit;
      transition: all 0.2s ease;
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
    }
    .card:hover {
      border-color: #e50914;
      transform: translateY(-4px);
      box-shadow: 0 16px 32px rgba(0, 0, 0, 0.7);
    }
    .card h2 {
      font-size: 1.35rem;
      margin: 1rem 0 0.5rem;
    }
    .card p {
      font-size: 0.92rem;
      color: #a3a3a3;
      margin-bottom: 1.5rem;
    }
    .btn {
      background: #e50914;
      color: #ffffff;
      padding: 0.65rem 1.5rem;
      border-radius: 10px;
      font-weight: 700;
      font-size: 0.95rem;
    }
  </style>
</head>
<body>
  <h1>dTVSteams</h1>
  <p>React v10 Web App & 10-Foot TV Web Edition</p>
  <div class="cards">
    <a href="./react/index.html" class="card">
      <svg width="44" height="44" viewBox="0 0 24 24" fill="none" stroke="#e50914" stroke-width="2"><circle cx="12" cy="12" r="3"></circle><ellipse cx="12" cy="12" rx="10" ry="4.5" transform="rotate(0 12 12)"></ellipse><ellipse cx="12" cy="12" rx="10" ry="4.5" transform="rotate(60 12 12)"></ellipse><ellipse cx="12" cy="12" rx="10" ry="4.5" transform="rotate(120 12 12)"></ellipse></svg>
      <h2>React v10 Web App</h2>
      <p>BoardUI mobile-mirrored web interface powered by Video.js 10 React VideoPlayer &amp; VideoSkin.</p>
      <span class="btn">開啟 React 版</span>
    </a>
    <a href="./tv-web/index.html" class="card">
      <svg width="44" height="44" viewBox="0 0 24 24" fill="none" stroke="#e50914" stroke-width="2"><rect x="2" y="7" width="20" height="15" rx="2" ry="2"></rect><polyline points="17 2 12 7 7 2"></polyline></svg>
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
