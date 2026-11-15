import esbuild from "esbuild";
import fs from "node:fs";
import path from "node:path";

async function build() {
  console.log("Building Video.js 10 standalone client bundles...");

  // Ensure output dirs exist
  fs.mkdirSync("dist", { recursive: true });
  fs.mkdirSync("web-app/vendor", { recursive: true });
  fs.mkdirSync("web-app/react", { recursive: true });
  fs.mkdirSync("tv-web/vendor", { recursive: true });

  // 1. Bundle Video.js 10 HTML elements for web-app and tv-web
  await esbuild.build({
    entryPoints: ["scripts/v10-entry.js"],
    bundle: true,
    minify: false,
    format: "esm",
    outfile: "dist/videojs10.bundle.js"
  });

  // 2. Copy bundle and skin CSS to web-app/vendor and tv-web/vendor
  const skinCssSource = "node_modules/@videojs/html/dist/default/define/video/skin.css";
  if (fs.existsSync(skinCssSource)) {
    fs.copyFileSync(skinCssSource, "web-app/vendor/videojs10-skin.css");
    fs.copyFileSync(skinCssSource, "tv-web/vendor/videojs10-skin.css");
    fs.copyFileSync(skinCssSource, "dist/videojs10-skin.css");
  }

  fs.copyFileSync("dist/videojs10.bundle.js", "web-app/vendor/videojs10.min.js");
  fs.copyFileSync("dist/videojs10.bundle.js", "tv-web/vendor/videojs10.min.js");

  // 3. Bundle React Video.js 10 App
  await esbuild.build({
    entryPoints: ["src/react/demo.tsx"],
    bundle: true,
    minify: false,
    format: "esm",
    outfile: "web-app/react/bundle.js",
    define: {
      "process.env.NODE_ENV": '"production"'
    },
    loader: {
      ".css": "css"
    }
  });

  // Create web-app/react/index.html
  const reactHtml = `<!doctype html>
<html lang="zh-Hant">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Video.js v10 React Player - 綜藝玩很大</title>
  <link rel="stylesheet" href="./bundle.css">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { background: #0f0f0f; color: #f3e7d2; font-family: Roboto, system-ui, sans-serif; min-height: 100vh; }
  </style>
</head>
<body>
  <div id="root"></div>
  <script type="module" src="./bundle.js"></script>
</body>
</html>`;
  fs.writeFileSync("web-app/react/index.html", reactHtml, "utf-8");

  console.log("✓ Successfully bundled Video.js 10 HTML & React into web-app and tv-web");
}

build().catch(err => {
  console.error("Build failed:", err);
  process.exit(1);
});
