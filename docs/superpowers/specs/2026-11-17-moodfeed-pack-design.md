# MoodFeed — Pack Design (delta on the 2026-11-16 spec)

**Date:** 2026-11-17
**Status:** awaiting approval
**Amends:** [`2026-11-16-moodfeed-design.md`](2026-11-16-moodfeed-design.md)

Everything in the 2026-11-16 spec stands **except the delivery layer**. The concept does not
change: modes (Work · Public · Private · Relax), a schedule resolved from the clock, and
Emotional Protection as a user-activated, self-expiring modifier. What changes is that the
enforcement stops being a notification and becomes a real surface change inside Instagram.

---

## 1. Why

Spec v1 §4 states its own ceiling: "a controller you can dismiss". That ceiling exists because a
third-party app cannot stop another app from rendering. A **patched Instagram build** is not a
third party — it is the app. That removes the ceiling without touching Meta's ranking.

## 2. Two artifacts, one brain

| Artifact | What it is | Repo |
|---|---|---|
| **MoodFeed** | Flutter app. Owns modes, schedule, protection, settings, home. The only place the resolver lives. | this repo |
| **MoodFeed Pack** | Fork of FeurStagram (GPLv3). Instagram patched to obey MoodFeed. Holds no rules of its own. | `moodfeed-pack` |

The pack is deliberately dumb: MoodFeed pushes a resolved state, the pack applies it. No
duplicate resolver, no duplicated schedule logic, no second source of truth.

## 3. Decisions (builder calls)

1. **Flutter stays the brain.** The user asked for Flutter; the resolver remains one pure Dart
   function. The pack never computes a mode.
2. **Push a timeline, not a state.** MoodFeed writes the resolved state *and the next week of
   boundaries* to the pack through a signature-protected ContentProvider. Pull would need the
   resolver in Kotlin — forbidden by spec v1 §7.1. Alarms would need a second copy of the
   resolver in a `BroadcastReceiver`. A precomputed timeline needs neither: it is the same
   resolver sampled forward.
3. **Clone package.** The pack installs as `com.instagram.android.moodfeed` so stock Instagram
   survives. Trust first; "replace Instagram" is a later toggle.
4. **The pack is optional and additive.** The gate keeps watching stock Instagram and Facebook; the
   pack package is never in the watched list, so both mechanisms coexist and no setting is hidden.
5. **`reduce` now means something.** Spec v1 §5.3 said `reduce` and `hide` behave the same. With the
   pack, `hide` empties the surface and `reduce` keeps the surface but drops category-matched units.
6. **Category filtering is a keyword lexicon in v1.** On-device classifier is Phase 2 behind the
   spec's existing 85% precision gate.
7. **Protection expiry needs no alarm.** The expiry is a boundary, so the timeline already
   contains the post-expiry state at that instant. The pack also ignores any state whose
   `protection.expiresAt` has passed, so a stale timeline cannot keep protection alive.
8. **One matcher, one resolved set.** The pack never sees `categoryLevels`. MoodFeed resolves them
   into `filterCategories` — the union of the profile's `reduce`/`hide` categories and
   `protection.softened` — and the pack drops units whose caption matches that set, on any surface
   that is left on. A `hide` category therefore applies everywhere, not only under protection.
9. **The lexicon is a matcher, not a policy.** It ships inside the pack as an asset and is rebuilt
   with it. Which categories, which surfaces and for how long are MoodFeed's, and arrive in the
   payload. Tuning the lexicon means a pack rebuild; the classifier replaces it in Phase 4 anyway.
10. **One key, two APKs.** `moodfeed-release.jks` signs both, and testers receive prebuilt APKs.
    Anyone building from source generates their own pair and builds both, or the bridge stays
    silent. The release key is never published — publishing it would let anyone sign a "MoodFeed"
    that the pack would obey.

## 4. Data model amendment

`Profile` gains two fields. Everything else in spec v1 §7.2 is unchanged.

```dart
Profile { id, name, icon, color, categoryLevels: Map<Category, Level>, surfaces: Map<Surface, Level>, followingOnly: bool, isDefault }

enum Surface { feed, reels, explore, stories, suggested, ads, notes, instants, threadsButton }
```

`surfaces` is what the pack applies, and every one of the nine has an existing hook in the fork
(feed, reels, explore, stories, suggested, ads and notes via response filtering; instants and the
Threads button via view hiding). `followingOnly` is its own field, not a surface level, because it
restricts the feed to followed accounts rather than hiding anything.

The two maps compose: a surface at `hide` is emptied; at `allow` it renders; at `reduce` it renders
but drops units matching `filterCategories`. `categoryLevels` never reaches the pack — MoodFeed
resolves it (see §3.8).

Defaults: Work/Public = all `hide` except `stories`; Private = `feed: reduce`, `explore: hide`, rest
`allow`; Relax = `followingOnly: true` with `reels: hide`, `explore: hide`, `ads: hide`.

## 5. Bridge contract

- Authority: `com.instagram.android.moodfeed.state`
- Permission: `com.instagram.android.moodfeed.permission.STATE`, `protectionLevel="signature"`
- Both APKs are signed with the same key, so the permission is enforced by the OS.
- One call: `ContentResolver.call(uri, "set_state", null, bundle)` where `bundle` has key
  `json`, a UTF-8 string. The payload is a **timeline**, newest last:

```json
{
  "v": 1,
  "generatedAt": 1763409600000,
  "states": [
    {
      "effectiveAt": 1763409600000,
      "base": "relax",
      "reason": "scheduled",
      "protection": { "expiresAt": 1763416800000, "softened": ["relationshipConflict", "breakup", "angerAggression"] },
      "surfaces": { "feed": "reduce", "reels": "hide", "explore": "hide", "stories": "allow", "suggested": "hide", "ads": "hide", "notes": "allow", "instants": "allow", "threadsButton": "allow" },
      "followingOnly": true,
      "filterCategories": ["relationshipConflict", "breakup", "angerAggression"]
    },
    { "effectiveAt": 1763416800000, "base": "relax", "reason": "scheduled", "protection": null, "surfaces": { "...": "..." }, "followingOnly": true, "filterCategories": [] }
  ]
}
```

`surfaces` uses the same three level names as the Dart enum — `allow`, `reduce`, `hide`. Every
enum value in the payload is the Dart `name` (so `relationshipConflict`, not
`relationship_conflict`); one spelling, both sides.
`filterCategories` is the resolved set from §3.8; it is empty when the mode hides no category and no
protection is active. The pack stores the string verbatim in its own `SharedPreferences`
(`moodfeed_state`) and, on every response-filter call and every app resume, applies the **last state
whose `effectiveAt` is not in the future**. Unknown keys are ignored — the pack must never crash on a
newer payload.

> shortcut: the timeline is rebuilt on app open, on every settings change and on resume, and covers 32
> boundaries or 30 days, whichever comes first. A user who opens Instagram for a month without opening
> MoodFeed keeps the last entry. Accepted: a schedule that has not changed in a month resolves the same
> way. Revisit if a user reports a mode stuck after a long absence.

## 6. What dies from spec v1

| Removed | Why |
|---|---|
| §7.3 gate for the pack's own package | Nothing outside the pack can gate it. It obeys the pushed mode instead. The gate still runs for stock Instagram and Facebook. |
| §5.6 rule "we never change what renders" | Now false. Replaced by: we never change ranking, and the pack never reads what you watched. |
| §7.5 "no `INTERNET` permission" | False for the pack (it is Instagram). True for MoodFeed. Replaced by: patches public, SHA256 per release, build-from-source, no telemetry added, state local. |
| §7.4 "Stop content rendering — not possible" | True for stock apps; false for our own build. |

## 7. New risks

| Risk | Mitigation |
|---|---|
| Meta ToS / takedown of a redistributed modified APK | Companion mode still ships and works. Pack source is public (GPLv3 forces it anyway). |
| Account restriction on modified clients | Stated in the install copy, not buried. Clone package keeps stock Instagram as the fallback. |
| Trust: the pack can read DMs | Clone package, public patches, SHA256, build-from-source, no added network calls. |
| GPLv3 covers the whole APK | Free launch only. A paid closed fork is not available. |
| Per-release maintenance | Fingerprint patches; rebuild per Instagram release, 1–2 days when one breaks. |
| EU AI Act / DPDP exposure from inferring mood | Not inferring. Protection is one tap from the user. Content is classified, not the person. |

## 8. Phases

| Phase | Ships | Gate |
|---|---|---|
| 1 | MoodFeed Flutter app, spec v1 behaviour, pack bridge written and no-op | 5 testers, installs and runs |
| 2 | Pack: fork, bridge, mode → surfaces | Running patched Instagram on a tester's phone |
| 3 | Protection → content filter (keyword lexicon) | A conflict caption actually disappears |
| 4 | On-device classifier behind the lexicon | 85% precision on conflict/breakup (spec v1 §8) |

Phase 1 is the existing spec and is independently useful. Phase 2 is where the ceiling moves.
