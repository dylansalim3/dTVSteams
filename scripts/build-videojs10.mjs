import esbuild from "esbuild";
import fs from "node:fs";
import path from "node:path";
import postcss from "postcss";
import tailwindcss from "@tailwindcss/postcss";

async function build() {
  console.log("Building Video.js 10 standalone client bundles...");
  const reactRoot = path.resolve("src/react");

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

  // 3. Compile BoardUI Tailwind v4 CSS + Bundle React Video.js 10 App
  const globalsCssPath = path.join(reactRoot, "styles", "globals.css");
  const globalsCss = fs.readFileSync(globalsCssPath, "utf-8");
  const tailwindResult = await postcss([
    tailwindcss({ base: reactRoot })
  ]).process(globalsCss, { from: globalsCssPath });

  await esbuild.build({
    entryPoints: ["src/react/demo.tsx"],
    bundle: true,
    minify: false,
    format: "esm",
    outfile: "web-app/react/bundle.js",
    alias: {
      "@": reactRoot
    },
    define: {
      "process.env.NODE_ENV": '"production"'
    },
    loader: {
      ".css": "css"
    }
  });

  const esbuildCssPath = "web-app/react/bundle.css";
  const videoJsCss = fs.existsSync(esbuildCssPath) ? fs.readFileSync(esbuildCssPath, "utf-8") : "";
  fs.writeFileSync(esbuildCssPath, `${tailwindResult.css}\n${videoJsCss}`, "utf-8");

  // Create web-app/react/index.html
  const reactHtml = `<!doctype html>
<html lang="zh-Hant" class="dark">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>dTVSteams — BoardUI React Player</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;600&display=swap">
  <style>
    :root {
      --font-inter: "Inter", "Noto Sans TC";
      --font-mono-source: "JetBrains Mono";
    }
  </style>
  <link rel="stylesheet" href="./bundle.css">
</head>
<body class="min-h-screen bg-background-full text-text-primary antialiased">
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
