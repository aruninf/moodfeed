# MoodFeed

**Your feed, your time.** A local-only Android app that decides which content rules you're under right now — and steps in when you open Instagram.

## The problem

Your recommendation algorithm learns what holds your attention, not whether that attention was wanted. One angry relationship reel watched to the end during a bad evening becomes a signal for weeks.

MoodFeed sits next to Instagram. It holds your rules, knows the time, and intervenes at the one moment it can: when you open the app.

## What it does

- **Time profiles** — Work, Public, Private, Relax. Scheduled per day and hour, switched automatically.
- **Emotional Protection** — one tap, two hours, conflict/breakup/anger content softened. Switches itself off. You activate it; the app never guesses your mood.
- **App-open gate** — a reminder of the active profile the moment Instagram or Facebook opens, with one tap to close it.

It does not change Meta's ranking. Nothing can, from outside. See the design doc for exactly why.

## Status

**Design phase.** No code yet. The Phase 1 contract is:

📄 [`docs/superpowers/specs/2026-11-16-moodfeed-design.md`](docs/superpowers/specs/2026-11-16-moodfeed-design.md)

## Planned stack

Flutter 3.47 · Dart 3 · Riverpod · local JSON storage (no database, no backend, no `INTERNET` permission) · one small Kotlin platform channel for usage-access events.

## Not in the MVP

AI classification, screen reading, overlays, iOS, accounts, cloud sync, family controls, analytics SDK. Each is deferred with a stated gate in §4 and §8 of the design.

## Privacy

All data stays on device. The app stores your profiles and schedules — never what you watched, and never which content appeared.
