# MoodFeed

**Your feed, your time.** A local-only Android app that decides which content rules you're under right now — and steps in when you open Instagram.

## The problem

Your recommendation algorithm learns what holds your attention, not whether that attention was wanted. One angry relationship reel watched to the end during a bad evening becomes a signal for weeks.

MoodFeed sits next to Instagram. It holds your rules, knows the time, and intervenes at the one moment it can: when you open the app.

## What it does

- **Time profiles** — Work, Public, Private, Relax. Scheduled per day and hour, switched automatically.
- **Emotional Protection** — one tap, two hours, conflict/breakup/anger content softened. Switches itself off. You activate it; the app never guesses your mood.
- **App-open gate** — a reminder of the active profile the moment Instagram or Facebook opens, with one tap to close it.
- **Pack bridge** — if the patched Instagram pack is installed, MoodFeed pushes the next 30 days of resolved states to it, so the pack enforces the same rules instead of only reminding you.

It does not change Meta's ranking. Nothing can, from outside. See the design doc for exactly why.

## Status

**Phase 1 app built.** All 12 tasks of the app plan are done and tested; the patched pack is the remaining work.

- 🧠 [The original idea and the problem](docs/original-idea.md) — why this exists, with diagrams
- 📄 [The Phase 1 contract](docs/superpowers/specs/2026-11-16-moodfeed-design.md) — what gets built, what doesn't
- 🔧 [The pack design delta](docs/superpowers/specs/2026-11-17-moodfeed-pack-design.md) — the payload contract and the fork
- 📣 [Reaching out](docs/reach-out.md) — the launch copy, the targets, the sequence

## Build

```bash
flutter pub get
flutter test
flutter build apk --release   # build/app/outputs/flutter-apk/app-release.apk
```

Release builds need a keystore. Create `android/key.properties` (git-ignored):

```properties
storePassword=…
keyPassword=…
keyAlias=moodfeed
storeFile=moodfeed-release.jks
```

and put `android/app/moodfeed-release.jks` next to it. Without the file the build falls back to the debug key.

**Want to test it?** Android 8+. [Open an issue titled "tester"](https://github.com/aruninf/moodfeed/issues/new?title=tester&body=Android%20version%3A%20%0ADevice%3A%20%0AThe%20moment%20I%27d%20want%20this%3A%20) and you'll get the signed APK.

## Stack

Flutter 3.47 · Dart 3 · Riverpod · local JSON in `SharedPreferences` (no database, no backend, no `INTERNET` permission) · one opt-in foreground service and a ~110-line Kotlin channel that reports which app is in the foreground.

Android 8+ (minSdk 26). Phase 1 ships as a signed APK, not a Play release.

## Not in the MVP

AI classification, screen reading, overlays, iOS, accounts, cloud sync, family controls, analytics SDK. Each is deferred with a stated gate in §4 and §8 of the design.

## Privacy

All data stays on device. The app stores your profiles and schedules — never what you watched, and never which content appeared.
