# Changelog

## [1.5.0](https://github.com/dylansalim3/dTVSteams/compare/v1.4.1...v1.5.0) (2026-11-28)


### Features

* add settings light/dark mode switch and rounded borderless app icon ([babc86d](https://github.com/dylansalim3/dTVSteams/commit/babc86d9702a0daff96021cba3b8e92017649414))

## [1.4.1](https://github.com/dylansalim3/dTVSteams/compare/v1.4.0...v1.4.1) (2026-11-26)


### Bug Fixes

* live-sync Flutter theme across all views, keep only React v10 and TV web, and remove duplicate Video.js controls ([eb09330](https://github.com/dylansalim3/dTVSteams/commit/eb093304c0225fe15a8384cac98c230e02a8970d))

## [1.4.0](https://github.com/dylansalim3/dTVSteams/compare/v1.3.0...v1.4.0) (2026-11-26)


### Features

* **ui,web:** match web to mobile layout with header share, APK link, 21st.dev themes, and sleek switches ([f0a9a42](https://github.com/dylansalim3/dTVSteams/commit/f0a9a42cc37b709ce3842034419574da1e5c5bbe))

## [1.3.0](https://github.com/dylansalim3/dTVSteams/compare/v1.2.7...v1.3.0) (2026-11-26)


### Features

* **ui,player:** center play/pause, enable PiP playback controls, and redesign React & Flutter UI with BoardUI ([deb5379](https://github.com/dylansalim3/dTVSteams/commit/deb53795611e4a979ef4abe79047b40c0ff5381d))

## [1.2.7](https://github.com/dylansalim3/dTVSteams/compare/v1.2.6...v1.2.7) (2026-11-26)


### Bug Fixes

* **android,player:** prevent ForegroundServiceDidNotStartInTimeException during fast-forward seeks ([952efb3](https://github.com/dylansalim3/dTVSteams/commit/952efb32e1eda79f729c6d99345e0df9837231c7))

## [1.2.6](https://github.com/dylansalim3/dTVSteams/compare/v1.2.5...v1.2.6) (2026-11-25)


### Bug Fixes

* **player:** sync native system bars with OSD play/pause visibility ([0462812](https://github.com/dylansalim3/dTVSteams/commit/04628124161a11586bf03c7807a92dbeaf3d4902))

## [1.2.5](https://github.com/dylansalim3/dTVSteams/compare/v1.2.4...v1.2.5) (2026-11-25)


### Bug Fixes

* **downloads,player,ui:** handle download failures and retries, confirm and clean all deleted parts, and restore native system bars on player exit ([4778918](https://github.com/dylansalim3/dTVSteams/commit/4778918ff5753f51250e59ab78c2b9e3dee507a8))

## [1.2.4](https://github.com/dylansalim3/dTVSteams/compare/v1.2.3...v1.2.4) (2026-11-25)


### Bug Fixes

* **ui:** remove redundant show name from list item titles ([ac30c80](https://github.com/dylansalim3/dTVSteams/commit/ac30c80dbf716099163568582d5ff6fb8aa47b0a))

## [1.2.3](https://github.com/dylansalim3/dTVSteams/compare/v1.2.2...v1.2.3) (2026-11-25)


### Bug Fixes

* **android:** resolve relative release keystore paths from rootProject ([6e2363e](https://github.com/dylansalim3/dTVSteams/commit/6e2363e886802ac9b8ad046ecc03322422b652f0))

## [1.2.2](https://github.com/dylansalim3/dTVSteams/compare/v1.2.1...v1.2.2) (2026-11-25)


### Bug Fixes

* **android,ci:** enforce persistent release keystore signing and version update apk filename ([fca8367](https://github.com/dylansalim3/dTVSteams/commit/fca8367f4e851cdc872db64ee8e60108a702c8c4))

## [1.2.1](https://github.com/dylansalim3/dTVSteams/compare/v1.2.0...v1.2.1) (2026-11-25)


### Bug Fixes

* **ui:** align card action buttons, tokenize UI colors/spacing, and harden settings sheets ([4dc020f](https://github.com/dylansalim3/dTVSteams/commit/4dc020fef4514a04095cabd74f3852666edd19d5))

## [1.2.0](https://github.com/dylansalim3/dTVSteams/compare/v1.1.0...v1.2.0) (2026-11-25)


### Features

* **ui:** remove recent/hot search row and move favorites and history into downloads bottom bar ([8d99a8b](https://github.com/dylansalim3/dTVSteams/commit/8d99a8b04d2ecb0c866b5db33f1d3c35ae1157ae))

## [1.1.0](https://github.com/dylansalim3/dTVSteams/compare/v1.0.0...v1.1.0) (2026-11-25)


### Features

* **branding:** update app launcher icons, adaptive mipmaps, and web favicons with custom mascot ([b5c561a](https://github.com/dylansalim3/dTVSteams/commit/b5c561a601d1d05e6862c4c18b0ab59b2db6d0c0))
* implement Feature 10 - year chips, order switcher & search history ([bb88781](https://github.com/dylansalim3/dTVSteams/commit/bb8878189de8406cea9eab9fd65f480573585cb2))
* implement Feature 11 - audio-only radio mode with vinyl view & waveforms ([160467d](https://github.com/dylansalim3/dTVSteams/commit/160467dc311cdea3474a413bf366bf56fcd5c1d4))
* implement Feature 9 - auto-play next part/episode countdown HUD & toggle ([3a1e43b](https://github.com/dylansalim3/dTVSteams/commit/3a1e43b270c1505a88e688b02c9f9f5786d73bdb))
* in-app remote update, unified download card style, date descending sort, player immersive mode ([231ce35](https://github.com/dylansalim3/dTVSteams/commit/231ce35a0026d4be8c5311f67b2f0fb5f12cf746))
* **release:** v1.0.10 - fast-forward 2x, favorites, watch history screen, and screen lock OSD ([408c0aa](https://github.com/dylansalim3/dTVSteams/commit/408c0aa1092f10c393f868f73b0c32fdb35db06c))
* **release:** v1.0.11 - auto-play next countdown, year filter & sort, radio mode, skip intro and stall fallback ([b6c3e3c](https://github.com/dylansalim3/dTVSteams/commit/b6c3e3ccdaf051ad4ec82f3fedc5a7a66734f41b))
* **release:** v1.0.3 - isolate downloads across tv show channels and reduce bottom sheet bottom padding ([65ea1a7](https://github.com/dylansalim3/dTVSteams/commit/65ea1a77ed00891773f6a36e37360cda4727587a))
* **release:** v1.0.4 - background audio playback, lock screen media service, and screen wakelock with settings ([b7357c8](https://github.com/dylansalim3/dTVSteams/commit/b7357c854ae4ef0b40d63bf5c8ba7d349a2e4d95))
* **release:** v1.0.5 - custom download storage location, downloads page storage switcher, and responsive navbar overflow fixes ([0776114](https://github.com/dylansalim3/dTVSteams/commit/07761148f2c683074ec2adb987e85cae062c35dc))
* **release:** v1.0.6 - standard navbar button tap targets and generous bottom sheet padding ([f50e57a](https://github.com/dylansalim3/dTVSteams/commit/f50e57a9abe8729f1547d18965239f9ee7c2d6de))
* **release:** v1.0.7 - web video downloader and native mobile video sharing ([f328567](https://github.com/dylansalim3/dTVSteams/commit/f3285677382209f12b908cbc319877907a90aa07))
* **release:** v1.0.8 - unified share dialog with QR code, copy url, and deep link playback ([7d18629](https://github.com/dylansalim3/dTVSteams/commit/7d18629c1af5ffb2ce2ed6c3250592a4c01f4726))
* **release:** v1.0.9 - player double-tap seek, sleep timer, and vertical swipe brightness/volume gestures ([bce7ceb](https://github.com/dylansalim3/dTVSteams/commit/bce7ceb242fc885900e349287a605f3dd03e0070))
* **ui:** convert 3 concentric download rings to single 3-part segmented pie border ([60fc7f4](https://github.com/dylansalim3/dTVSteams/commit/60fc7f46e8c468cbcdc28fa3ee47c3c3184cdbf5))
* **version:** dynamically query native Android package version and sync with release 1.0.2+3 ([9245198](https://github.com/dylansalim3/dTVSteams/commit/9245198739f13bbe3f9f56591fd0b9d5c65a4cb1))


### Bug Fixes

* **player,update,ui:** harden double-tap seek, fix update version race and APK installer, compact settings sheets, and fix portrait OSD overflow ([b0c1058](https://github.com/dylansalim3/dTVSteams/commit/b0c1058e565fd33806fb2082f5fd1fc12c34d97d))
* **player:** completely terminate playback and silence audio when exiting via back button ([4df8dd1](https://github.com/dylansalim3/dTVSteams/commit/4df8dd1c47166c0826bab73279c78b8ffbd48a75))
* **ui,installer:** ensure settings sheet safe area padding and harden APK installer permissions ([71fdbce](https://github.com/dylansalim3/dTVSteams/commit/71fdbceb67ea1d11dd30c8ee8d9e30723f9bceaa))
