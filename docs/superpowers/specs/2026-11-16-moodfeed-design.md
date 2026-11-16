# MoodFeed — Design

**Date:** 2026-11-16
**Status:** draft for approval
**One line:** A local-only Android app that decides which Instagram/Facebook content rules you are under right now, and steps in when you open the app.

---

## 1. Intent

Your feed algorithm knows what holds your attention. It does not know whether that attention was wanted. One angry relationship reel you watched to the end during a bad evening becomes a recommendation signal for weeks.

MoodFeed sits *next to* Instagram, not inside it. It holds your rules, knows what time it is, and intervenes at the one moment it can: when you open the app.

**We do not compete with Instagram. We do not promise to change its algorithm.** Meta's "Your Algorithm" (Nov 2026) already ships natural-language preference control. Every attempt to reverse-engineer ranking is a dead end and a Play Store ban.

## 2. The wedge

Time-based profiles are explainable but commoditised — Meta will ship scheduled preferences. The thing nobody ships is **Emotional Protection**: a user-activated, time-boxed mode that softens conflict, breakup and anger content for the next two hours, and switches itself off.

It is the only feature here with an emotional reason to open the app on the worst night of your month instead of the best one. Everything else exists to make that feature trustworthy.

## 3. Goals (MVP)

1. Define content profiles (Work, Public, Private, Relax, Emotional Protection).
2. Assign each profile a weekly schedule.
3. The app always shows the profile that is active *right now*, and when the next one starts.
4. Manual override at any time, optionally with an expiry.
5. Emotional Protection: one tap, choose a duration, softened categories reset automatically.
6. On opening Instagram or Facebook, show a non-blocking reminder of the active profile, with the option to close the app.

## 4. Non-goals (MVP)

Explicitly **not** built. Adding any of these breaks the schedule.

| Not in MVP | Why |
|---|---|
| Any AI / ML model | No labelled dataset yet; unproven demand. Phase 3. |
| Reading the screen of another app | AccessibilityService scraping violates Play policy and is a ban risk. |
| Drawing over Instagram | Same policy risk. Also fragile against every UI update. |
| Changing Meta settings automatically | No API exists. User-initiated only. |
| Backend, accounts, sync | Nothing in the MVP needs a server. Local-first is a feature. |
| iOS | No content-visibility path at all. Phase 5. |
| Family / multi-user | Wrong buyer, extra consent surface. Phase 6 at the earliest. |
| Analytics SDK | Nothing to measure yet. Local counters only, opt-in. |
| Hard app blocking | See §7.3. A dismissible gate is the honest maximum. |

## 5. Core behaviour

### 5.1 Profile resolution (the only real logic in the MVP)

The active profile is **derived, never stored as state**. One pure function, one test.

```
activeProfile(now, profiles, schedules, overrides) -> (Profile, reason)

1. Expired overrides are ignored (expiresAt <= now).
2. An active Emotional Protection override wins.        (highest priority)
3. An active pinned override wins.
4. The matching schedule wins.                          (see 5.2)
5. Otherwise the user's default profile.
```

`reason` is one of `protection`, `pinned`, `scheduled`, `default` — the UI shows it under the profile name so the user is never surprised.

Consequences, and they matter:

- Killing the app, changing the device clock, or rebooting cannot corrupt state.
- No background scheduler is needed for the app's own state. The next switch is computed from the clock, so the app is always correct the instant it is opened.
- A profile switch is never lost or double-applied.

### 5.2 Schedules

- `daysOfWeek` set + `startMinute`/`endMinute`, in local time.
- `startMinute > endMinute` wraps past midnight (22:00–07:00 is one window, and the earlier weekday owns the pre-midnight part).
- Overlapping schedules are legal; highest `priority` wins, ties broken by most recently edited. Deterministic on every tick.
- Gaps are legal and fall through to the default profile.

### 5.3 Content categories (MVP = labels only)

The MVP does not classify anything. Categories exist so profiles carry meaning and reminders can name what is being softened.

`romantic`, `suggestive`, `relationship_conflict`, `breakup`, `anger_aggression`, `comedy`, `educational`, `news_tech`

Each category has a level per profile: `allow` / `reduce` / `hide`. In the MVP `hide` and `reduce` produce the same behaviour (phrasing in the reminder) — the taxonomy must exist before any classifier, so it is written once, now.

### 5.4 Emotional Protection defaults

Disabled by default: `relationship_conflict`, `breakup`, `anger_aggression`.
**Not** disabled: `romantic`. A rough evening is not a reason to remove affection. This separation is a product rule, not a setting.

Duration chips: 30m, 2h, 4h, until morning. Never auto-renews. Never auto-activates.

### 5.5 Rules that are non-negotiable

1. The app never infers mood from behaviour. Only the user activates protection.
2. The app never stores what the user watched, or which content appeared.
3. No streak, score, guilt copy, or notification shaming a user for opening Instagram.
4. Turning protection off is always one tap from the home screen.
5. All data stays on device. Uninstall leaves nothing behind.

## 6. Screens (5)

1. **Home** — active profile name + reason, countdown to next switch, "Protect my peace" button, quick profile switch.
2. **Profiles** — list + editor (name, icon, category levels).
3. **Schedule** — weekly grid, per-block day/time/profile, priority.
4. **Protection sheet** — duration chips, softened category checkboxes, confirm.
5. **Settings** — default profile, app-open reminder on/off, which apps to watch, usage-access grant, notifications.

No onboarding flow in the MVP. Default profile created on first launch with a sane weekday schedule.

## 7. Architecture

### 7.1 Layers

```
UI (Flutter widgets)
  └─ AppState (Riverpod: tick stream + resolvers)
       └─ Repositories (ProfileRepository, ScheduleRepository, OverrideRepository, SettingsRepository)
            └─ Local JSON via shared_preferences   ← swap for Drift at Phase 3
  Platform channel (Kotlin, ~60 lines)
       └─ Foreground app events (UsageStatsManager) + deep links
```

Flutter 3.47, Dart 3. `flutter_riverpod`, `shared_preferences`, `flutter_local_notifications`, `android_intent_plus`. Four dependencies, no more.

> shortcut: one JSON blob in shared_preferences instead of a database. Upgrade to Drift when history, per-event records, or >200 schedules exist.

### 7.2 Data model

```dart
Profile   { id, name, icon, color, categoryLevels: Map<Category, Level>, isDefault }
Schedule  { id, profileId, daysOfWeek: Set<int>, startMinute, endMinute, priority, enabled }
Override  { id, kind: pinned | protection, profileId, startedAt, expiresAt?, softenedCategories }
Settings  { defaultProfileId, watchApps: List<String>, gateEnabled, notificationPrefs }
```

Ten profiles and fifty schedules is the realistic ceiling. A flat JSON document is the correct store at this size.

### 7.3 Android integration — and its honest ceiling

| Capability | How | Play risk |
|---|---|---|
| Know Instagram was opened | `UsageStatsManager.queryEvents` + user-granted Usage Access | Low — same API Digital Wellbeing uses |
| Remind the user | Notification, plus our own full-screen activity | Low |
| Offer a way out | `Intent` with `ACTION_MAIN` to home | None |
| Open Instagram's own settings | Deep link, best-effort | None |
| Stop content from rendering | Not possible for third parties | — |
| Hard-block the app | Only via AccessibilityService or DevicePolicyManager | Accessibility = ban risk; DPC needs device-owner |

The MVP gate is **dismissible by design**. It costs the user one deliberate tap. That is the entire enforcement mechanism, and the doc should say so before anyone builds a promise on top of it.

> shortcut: deep links into Instagram settings are unofficial and will break. Fall back to copyable instructions when the intent fails.

### 7.4 Privacy

No network permission is required for the MVP. Ship without `INTERNET` in the manifest — that is a verifiable claim, and a better marketing asset than any privacy policy paragraph.

## 8. Phases

| Phase | Content | Gate to proceed |
|---|---|---|
| 1 (MVP) | §3 as written | 30–50 users, ≥40% still using a schedule at week 4 |
| 2 | Notification-first nudges, weekly digest of which profiles you actually used | Users ask for more intervention |
| 3 | On-device classifier for already-visible text/captions, taxonomy tuned on a labelled set | Precision >85% on conflict/breakup at user-chosen sensitivity |
| 4 | Instagram settings walkthroughs, per-topic "not interested" ladders | Real evidence preferences drift |
| 5 | iOS: preference engine + Screen Time schedules, no filtering | Android retention proven |
| 6 | Family profiles with consent | Never before 5 |

README lives at repo root; this document is the contract for Phase 1 only.

## 9. Risks

| Risk | Mitigation |
|---|---|
| Meta ships scheduled preferences | Differentiator is Emotional Protection + the intervention moment, not the schedule. |
| Weak value: soft gate is easy to dismiss | Measure honour rate; if <30%, the product is a reminder app and should be priced as one. |
| Play policy change on Usage Access | Degrade to notification-only mode; nothing else in the MVP depends on it. |
| "Another app to manage apps" fatigue | Zero-config default schedule on install. No onboarding. |
| Suggestive/romantic taxonomy seen as moralising | Categories are user-chosen labels, never judgements; §5.5 rule 3. |

## 10. Decisions deferred

- Drift vs JSON (revisit at Phase 3).
- Whether the gate uses a notification or a full-screen activity (test both in Phase 1).
- Pricing: free core + paid protection history, or paid-only. Not decided before retention data.
- Whether "until morning" means next scheduled profile or a fixed 07:00.
