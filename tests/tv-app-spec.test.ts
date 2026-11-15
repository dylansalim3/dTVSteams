import { describe, it, expect } from "vitest";
import fs from "node:fs";
import path from "node:path";

describe("tv-app Android Architecture & Spec Compliance", () => {
  const root = path.resolve(__dirname, "../tv-app");

  it("verifies Android TV project structure exists", () => {
    expect(fs.existsSync(path.join(root, "src/main/AndroidManifest.xml"))).toBe(true);
    expect(fs.existsSync(path.join(root, "build.gradle.kts"))).toBe(true);
    expect(fs.existsSync(path.join(root, "src/main/java/com/dtvsteams/catalog/Parser.kt"))).toBe(true);
    expect(fs.existsSync(path.join(root, "src/main/java/com/dtvsteams/catalog/Cache.kt"))).toBe(true);
    expect(fs.existsSync(path.join(root, "src/main/java/com/dtvsteams/ui/HomeScreen.kt"))).toBe(true);
    expect(fs.existsSync(path.join(root, "src/main/java/com/dtvsteams/ui/DetailsScreen.kt"))).toBe(true);
    expect(fs.existsSync(path.join(root, "src/main/java/com/dtvsteams/ui/PlayerScreen.kt"))).toBe(true);
    expect(fs.existsSync(path.join(root, "src/main/res/values/themes.xml"))).toBe(true);
    expect(fs.existsSync(path.join(root, "src/main/res/values/strings.xml"))).toBe(true);
    expect(fs.existsSync(path.join(root, "src/main/res/drawable/tv_banner.xml"))).toBe(true);
    expect(fs.existsSync(path.join(root, "src/main/res/drawable/ic_launcher.xml"))).toBe(true);
    expect(fs.existsSync(path.join(root, "src/test/java/com/dtvsteams/catalog/ParserTest.kt"))).toBe(true);
    expect(fs.existsSync(path.join(root, "src/test/resources/fixtures/list.html"))).toBe(true);
    expect(fs.existsSync(path.join(root, "src/test/resources/fixtures/episode.html"))).toBe(true);
  });

  it("verifies AndroidManifest.xml contains Leanback TV requirements", () => {
    const manifest = fs.readFileSync(path.join(root, "src/main/AndroidManifest.xml"), "utf-8");
    expect(manifest).toContain("android.software.leanback");
    expect(manifest).toContain("android.hardware.touchscreen");
    expect(manifest).toContain("android.intent.category.LEANBACK_LAUNCHER");
    expect(manifest).toContain("android.permission.INTERNET");
  });

  it("verifies Parser.kt implements real selectors and not emptyList stubs", () => {
    const parserCode = fs.readFileSync(path.join(root, "src/main/java/com/dtvsteams/catalog/Parser.kt"), "utf-8");
    expect(parserCode).toContain("ul.lcp_catlist a");
    expect(parserCode).toContain("ul.contentlist li");
    expect(parserCode).toContain("Jsoup.parse");
    expect(parserCode).not.toContain("return emptyList() // wired in Android Studio");
  });

  it("verifies Compose for TV and ExoPlayer implementation in UI screens", () => {
    const homeCode = fs.readFileSync(path.join(root, "src/main/java/com/dtvsteams/ui/HomeScreen.kt"), "utf-8");
    expect(homeCode).toContain("TvLazyColumn");
    expect(homeCode).toContain("YouTubeEpisodeListItem");

    const playerCode = fs.readFileSync(path.join(root, "src/main/java/com/dtvsteams/ui/PlayerScreen.kt"), "utf-8");
    expect(playerCode).toContain("ExoPlayer");
    expect(playerCode).toContain("Player.Listener");
    expect(playerCode).toContain("onPlaybackStateChanged");
    expect(playerCode).toContain("resume_");
  });

  it("verifies Android TV build version configuration in build.gradle.kts", () => {
    const gradleCode = fs.readFileSync(path.join(root, "build.gradle.kts"), "utf-8");
    expect(gradleCode).toContain('applicationId = "com.dtvsteams.tv"');
    expect(gradleCode).toContain('versionCode = 1');
    expect(gradleCode).toContain('versionName = "0.1.0"');
    expect(gradleCode).toContain("minSdk = 31");
    expect(gradleCode).toContain("targetSdk = 34");
    expect(gradleCode).toContain("compileSdk = 34");
  });
});
