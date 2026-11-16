# MoodFeed — Design

**Date:** 2026-11-16
**Status:** approved for Phase 1 planning
**One line:** A local-only Android app that decides which content rules you are under right now, and steps in when you open the app.

---

## 1. Intent

Your feed algorithm knows what holds your attention. It does not know whether that attention was wanted. One angry relationship reel you watched to the end during a bad evening becomes a recommendation signal for weeks.

MoodFeed sits *next to* Instagram, not inside it. It holds your rules, knows what time it is, and intervenes at the one moment it can: when you open the app.

**We do not compete with Instagram. We do not promise to change its algorithm.** Meta's "Your Algorithm" (Nov 2026) already ships natural-language preference control. Every attempt to reverse-engineer ranking is a dead end and a Play Store ban.

## 2. The wedge

Time-based profiles are explainable but commoditised — Meta will ship scheduled preferences. The thing nobody ships is **Emotional Protection**: a user-activated, time-boxed layer that softens conflict, breakup and anger content for the next two hours, and switches itself off.

It is the only feature here with an emotional reason to open the app on the worst night of your month instead of the best one. Everything else exists to make that feature trustworthy.

## 3. Goals (MVP)

1. Define content profiles (Work, Public, Private, Relax).
2. Assign each profile a weekly schedule.
3. The app always shows the profile that is active *right now*, and when the next one starts.
4. Manual pin of a profile, ending at the next schedule boundary.
5. **Emotional Protection**: one tap, choose a duration, hardened categories soften on top of whatever profile is active, then reset themselves.
6. When Instagram or Facebook comes to the foreground, raise a notification naming the active profile, with one action to close the app.

## 4. Non-goals (MVP)

Explicitly **not** built. Adding any of these breaks the schedule.

| Not in MVP | Why |
|---|---|
| Any AI / ML model | No labelled dataset yet; unproven demand. Phase 3. |
| Reading the screen of another app | AccessibilityService scraping violates Play policy and is a ban risk. |
| Drawing over Instagram | Same policy risk. Also fragile against every UI update. |
| A full-screen interstitial over Instagram | Android 14 restricts `USE_FULL_SCREEN_INTENT` to calling/alarm apps. §7.4. |
| Changing Meta settings automatically | No API exists. User-initiated only. |
| Backend, accounts, sync | Nothing in the MVP needs a server. Local-first is a feature. |
| iOS | No content-visibility path and no app-open detection at all. Phase 5. |
| Family / multi-user | Wrong buyer, extra consent surface. Phase 6 at the earliest. |
| Analytics SDK | Nothing to measure yet. Local counters only, opt-in. |
| Hard app blocking | See §7.4. A dismissible notification is the honest maximum. |

## 5. Core behaviour

### 5.1 Active state (the only real logic in the MVP)

The active state is **derived, never stored**. One pure function, one test, one implementation in Dart (§7.1).

```
resolveActiveState(now, profiles, schedules, pin, protection) -> ActiveState

1. Expired inputs are ignored: pin.expiresAt <= now, protection.expiresAt <= now.
2. Base profile:
     a. An active pin wins.                    reason = pinned
     b. Else the matching schedule wins.       reason = scheduled   (§5.2)
     c. Else the user's default profile.       reason = default
3. Protection is a MODIFIER on top of the base profile, never a profile.
4. nextChangeAt = earliest of the next schedule boundary and any expiry above.
```

```dart
ActiveState {
  Profile baseProfile;
  Reason reason;                  // pinned | scheduled | default
  Protection? protection;         // {expiresAt, softenedCategories}
  DateTime? nextChangeAt;
}
```

Consequences, and they matter:

- Killing the app, changing the device clock, or rebooting cannot corrupt state.
- No scheduler is needed for the app's *own* state. The next switch is computed from the clock, so the app is correct the instant it is opened. Only the gate needs to run while backgrounded (§7.3).
- A profile switch is never lost or double-applied.

### 5.2 Schedules

- `daysOfWeek` set + `startMinute`/`endMinute`, in local time.
- `startMinute > endMinute` wraps past midnight (22:00–07:00 is one window, and the earlier weekday owns the pre-midnight part).
- Overlapping schedules are legal; highest `priority` wins, ties broken by most recently edited. Deterministic on every tick.
- Gaps are legal and fall through to the default profile.

### 5.3 Content categories (MVP = labels only)

The MVP classifies nothing. Categories exist so profiles carry meaning and the gate can name what is being softened.

`romantic`, `suggestive`, `relationship_conflict`, `breakup`, `anger_aggression`, `comedy`, `educational`, `news_tech`

Each category has a level per profile: `allow` / `reduce` / `hide`. In the MVP `reduce` and `hide` produce the same behaviour (wording in the gate) — the taxonomy must exist before any classifier, so it is written once, now.

### 5.4 Emotional Protection

A `Protection` is `{expiresAt, softenedCategories}`, layered over the base profile. The home screen reads **"Relax — protecting 3 topics"**, never a separate profile name.

Defaults: `relationship_conflict`, `breakup`, `anger_aggression`.
**Never**: `romantic`, `suggestive`. A rough evening is not a reason to remove affection. Those two are not rows in the sheet at all — absent, not disabled, so the app never appears to moralise.

Duration chips: 30m, 2h, 4h, until morning. Never auto-renews. Never auto-activates. Sheet checkboxes are per-session; only the *default set* is stored in Settings.

### 5.5 Pins

One pin slot. Pinning a second profile replaces the first — no stacking, no queue.

`Pin { profileId, startedAt, expiresAt }`, where `expiresAt` is the next schedule boundary after `startedAt` (null only if no boundary exists within 7 days). Pinning during protection is allowed; the pin holds the base profile and resumes its meaning when protection expires.

### 5.6 Rules that are non-negotiable

1. The app never infers mood from behaviour. Only the user activates protection.
2. The app never stores content, captions, or what you watched. It may store gate events: timestamp, package name, action taken, active profile id (§7.5).
3. No streak, score, guilt copy, or notification shaming a user for opening Instagram.
4. Turning protection off is always one tap from the home screen.
5. All data stays on device. Uninstall leaves nothing behind.

## 6. Screens (5)

1. **Home** — base profile name + reason, protection badge and countdown, countdown to next switch, "Protect my peace" button, quick profile switch.
2. **Profiles** — list + editor (name, icon, category levels).
3. **Schedule** — weekly blocks, per-block days/time/profile, priority.
4. **Protection sheet** — duration chips, softened-topic checkboxes (defaults only), confirm.
5. **Settings** — default profile, gate on/off, watched-apps list (fixed, §7.4), usage-access grant, notification permissions.

No onboarding flow. A default profile and a sane weekday schedule exist on first launch.

## 7. Architecture

### 7.1 Layers

```
UI (Flutter widgets)
  └─ ActiveState provider (clock tick + resolveActiveState)
       └─ Repositories (Profile, Schedule, Pin, Protection, Settings, GateEvent)
            └─ Local JSON via shared_preferences   ← swap for Drift at Phase 3

Background: flutter_foreground_task (Dart isolate, same resolver)
  └─ Platform channel (Kotlin, ~60 lines): foreground package from UsageStatsManager only
```

Flutter 3.47, Dart 3, minSdk 26, targetSdk 35. Dependencies: `flutter_riverpod`, `shared_preferences`, `flutter_local_notifications`, `flutter_foreground_task`, `android_intent_plus`. Five, no more.

The resolver exists **once**, in Dart. The Kotlin side answers exactly one question — "which package is in the foreground" — because duplicating the resolver in Kotlin guarantees the two copies diverge.

> shortcut: one JSON blob in shared_preferences instead of a database. Upgrade to Drift when history, per-event records, or >200 schedules exist.

### 7.2 Data model

```dart
Profile     { id, name, icon, color, categoryLevels: Map<Category, Level>, isDefault }
Schedule    { id, profileId, daysOfWeek: Set<int>, startMinute, endMinute, priority, enabled }
Pin         { profileId, startedAt, expiresAt? }          // single slot
Protection  { expiresAt, softenedCategories: Set<Category> }
GateEvent   { ts, packageName, action: continued | closed, profileId, protectionOn }
Settings    { defaultProfileId, gateEnabled, watchApps, protectionDefaults, counterOptIn }
```

Ten profiles and fifty schedules is the realistic ceiling. A flat JSON document is the correct store at this size.

### 7.3 The gate

UsageStatsManager is a log you **poll**; it pushes nothing. So the gate is an opt-in foreground service, not a clever trick.

| Step | Decision |
|---|---|
| Runs when | `gateEnabled` and at least one watched app, screen on, device unlocked |
| Service type | `specialUse` (Android 14+), with a low-importance persistent notification |
| Poll interval | 5s. Cheap enough to be honest about; a 15-min WorkManager tick cannot see an app open |
| Fires when | a watched package becomes foreground after ≥5 min in the background |
| Cooldown | 90 min per package, persisted |
| Suppressed when | base profile and protection together soften nothing (§5.3) |
| Presentation | high-priority notification, channel "profile reminders", actions **Close app** / **Continue** |
| Never | full-screen intent, overlay, or a background activity launch — all either restricted or ban-worthy |

Honour rate = gate events with action `closed` ÷ all gate events, per profile. That definition is fixed here so the Phase 1 gate metric in §8 is measurable.

**Degraded mode** is real and must be honest: if usage access is revoked or the service is killed, the app cannot detect an open at all. It falls back to a persistent low-importance notification showing the active profile, refreshed at schedule boundaries by `AlarmManager`. That is a reminder widget, not a gate, and the UI says so rather than silently pretending.

### 7.4 Platform constraints we design around

| Capability | How | Risk |
|---|---|---|
| Know a watched app opened | `UsageStatsManager.queryEvents` + user-granted Usage Access | Low — same API Digital Wellbeing uses |
| Check continuously | foreground service, `FOREGROUND_SERVICE_SPECIAL_USE` | Play review scrutiny; fine for APK distribution |
| Notify | notification channel + `POST_NOTIFICATIONS` (33+) | Low |
| Stop content rendering | not possible for third parties | — |
| Hard-block | only AccessibilityService or DevicePolicyManager | ban risk / needs device-owner |

Watched apps are a **fixed list** of known packages (Instagram, Facebook, and their Lite builds), not an arbitrary picker. An arbitrary picker needs `QUERY_ALL_PACKAGES`, which Play restricts — not worth it for five rows.

> shortcut: deep links into Instagram settings are unofficial and will break. Fall back to copyable instructions when the intent fails.

### 7.5 Privacy

No network permission. Ship without `INTERNET` in the manifest — verifiable, and a better asset than any privacy paragraph. Gate events are local, capped at 500 rows, and off with one toggle.

## 8. Phases

| Phase | Content | Gate to proceed |
|---|---|---|
| 1 (MVP) | §3 as written | 30–50 users, ≥40% still using a schedule at week 4, honour rate ≥30% |
| 2 | Register interest counters, weekly digest of profiles actually used; Play Store submission | Users ask for more intervention |
| 3 | On-device classifier for already-visible text/captions, taxonomy tuned on a labelled set | Precision >85% on conflict/breakup at user-chosen sensitivity |
| 4 | Instagram settings walkthroughs, per-topic "not interested" ladders | Real evidence preferences drift |
| 5 | iOS: preference engine + Screen Time schedules, no detection | Android retention proven |
| 6 | Family profiles with consent | Never before 5 |

**Phase 1 distribution:** signed APK via GitHub Releases, sideloaded to testers. Play submission waits for Phase 2, so Play's review of the foreground service and usage-access declaration cannot block validation.

## 9. Risks

| Risk | Mitigation |
|---|---|
| Meta ships scheduled preferences | Differentiator is Emotional Protection + the intervention moment, not the schedule. |
| Weak value: a notification is easy to dismiss | Measure honour rate; if <30%, the product is a reminder app and should be priced as one. |
| Play policy change on Usage Access / `specialUse` | Degrade to notification-only mode (§7.3); nothing else in the MVP depends on it. |
| Foreground-service battery complaints | Opt-in, screen-on only, 5s poll, persistent notification that states the cost. |
| "Another app to manage apps" fatigue | Zero-config default schedule on install. No onboarding. |
| Suggestive/romantic taxonomy seen as moralising | Categories are user-chosen labels; §5.4 hides them from protection entirely; §5.6 rule 3. |

## 10. Decisions deferred

- Drift vs JSON (revisit at Phase 3).
- Whether "until morning" means the next scheduled profile or a fixed 07:00.
- Poll interval tuning (5s vs 10s) based on Phase 1 battery reports.
- Pricing: free core + paid protection history, or paid-only. Not before retention data.

## 11. Builder calls made in this revision

Settled without asking, so the plan could start:

1. Protection is a modifier, not a profile (§5.1). Changes the resolver's return type and the home screen copy.
2. The gate is a notification, never a full-screen activity — Android 14 makes the interstitial option unavailable (§7.3).
3. One pin slot, expiring at the next boundary (§5.5).
4. Fixed watched-app list; no `QUERY_ALL_PACKAGES` (§7.4).
5. Phase 1 ships as an APK, not a Play release (§8).
6. Resolver lives once, in Dart, running in the foreground-task isolate (§7.1).
7. Gate events are stored; content is not (§5.6 rule 2, §7.5).
