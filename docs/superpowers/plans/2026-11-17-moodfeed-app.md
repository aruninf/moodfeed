# MoodFeed App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the MoodFeed Android app: four content modes on a weekly schedule, a user-activated Emotional Protection layer, and a pack bridge that pushes the resolved timeline to the patched Instagram build.

**Architecture:** One pure Dart resolver derives the active state from the clock — never stored. A timeline builder samples that resolver forward across every boundary. Riverpod exposes the active state to five screens. A thin Kotlin channel answers two questions (which package is in the foreground; is the pack installed) and receives the timeline.

**Tech Stack:** Flutter 3.47, Dart 3, Riverpod, shared_preferences, flutter_local_notifications, flutter_foreground_task, android_intent_plus, one Kotlin plugin.

**Spec:** `docs/superpowers/specs/2026-11-16-moodfeed-design.md` (v1) and `docs/superpowers/specs/2026-11-17-moodfeed-pack-design.md` (delta)

## Global Constraints

- Flutter 3.47 / Dart 3; `minSdk 26`, `targetSdk 35`.
- Exactly five dependencies: `flutter_riverpod`, `shared_preferences`, `flutter_local_notifications`, `flutter_foreground_task`, `android_intent_plus`. No more, no fewer.
- The release manifest declares **no** `android.permission.INTERNET`.
- The resolver exists **once**, in `lib/domain/resolver.dart`. No second copy in Kotlin or in a widget.
- Four modes, fixed ids: `work`, `public`, `private`, `relax`. Eight categories, fixed ids: `romantic`, `suggestive`, `relationship_conflict`, `breakup`, `anger_aggression`, `comedy`, `educational`, `news_tech`.
- Protection default categories: `relationship_conflict`, `breakup`, `anger_aggression`. `romantic` and `suggestive` never appear in the protection sheet.
- Copy rules: no streaks, no scores, no shaming. Protection is never auto-activated and never auto-renewed.
- All data local. Gate events capped at 500 rows, off by one toggle.

## Review Focus

1. **Overnight schedule wrap** — a window `22:00–07:00` on Monday must match Tuesday 02:00 and must *not* match a Tuesday-owned `22:00–07:00`. (Task 1)
2. **Device clock change / DST** — the resolver uses wall-clock minutes, so a 23- or 25-hour day must not throw or skip a switch. (Task 1)
3. **Corrupt or partial store** — a half-written JSON blob must never wipe profiles; fall back to defaults. (Task 3)
4. **Protection expiring while the app is closed** — opening the app after expiry shows the base mode, and the pushed timeline contains the post-expiry state. (Tasks 2, 5)
5. **Overlapping schedules** — two windows matching at the same minute must resolve deterministically: priority first, then most recently edited. (Task 1)

---

### Task 1: Scaffold and the resolver

**Files:**
- Create: `pubspec.yaml`, `lib/models.dart`, `lib/domain/resolver.dart`, `test/domain/resolver_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `enum Category { romantic, suggestive, relationshipConflict, breakup, angerAggression, comedy, educational, newsTech }`, `enum Level { allow, reduce, hide }`, `enum Surface { feed, reels, explore, stories, suggested, ads, notes, instants, threadsButton }`, `enum Reason { pinned, scheduled, defaultProfile }`, `class Profile { String id; String name; int icon; int color; Map<Category,Level> categoryLevels; Map<Surface,Level> surfaces; bool isDefault; }`, `class Schedule { String id; String profileId; Set<int> daysOfWeek; int startMinute; int endMinute; int priority; bool enabled; DateTime updatedAt; }`, `class Pin { String profileId; DateTime startedAt; DateTime? expiresAt; }`, `class Protection { DateTime expiresAt; Set<Category> softenedCategories; }`, `class ActiveState { Profile baseProfile; Reason reason; Protection? protection; DateTime? nextChangeAt; }`, `ActiveState resolveActiveState({required DateTime now, required List<Profile> profiles, required List<Schedule> schedules, required String defaultProfileId, Pin? pin, Protection? protection})`.

- [ ] **Step 1: Scaffold the project**

Run: `flutter create --org com.moodfeed --project-name moodfeed --platforms=android .`
Then replace `pubspec.yaml` dependencies with the five listed in Global Constraints, run `flutter pub get`.

- [ ] **Step 2: Write the failing tests**

`test/domain/resolver_test.dart` — helper builds a profile and a schedule; `now` values are local `DateTime`s. 2026-11-16 is a Monday.

```dart
test('falls through to the default profile when nothing matches', () { ... });
// expect(state.reason, Reason.defaultProfile); expect(state.nextChangeAt, isNull);

test('matches a same-day window', () { ... });
// now = DateTime(2026,11,16,9,0); schedule Mon 540..1020 -> Reason.scheduled

test('matches the pre-midnight part of a wrapping window', () { ... });
// now = DateTime(2026,11,16,23,0); schedule Mon 1320..420 -> Reason.scheduled

test('matches the post-midnight part of a wrapping window', () { ... });
// now = DateTime(2026,11,17,2,0); schedule Mon 1320..420 -> Reason.scheduled

test('does not match a window owned by the current weekday after midnight', () { ... });
// now = DateTime(2026,11,17,2,0); schedule Tue 1320..420 -> Reason.defaultProfile

test('higher priority wins an overlap', () { ... });
test('most recently edited wins a priority tie', () { ... });
test('an active pin beats the schedule', () { ... });
test('an expired pin is ignored', () { ... });
test('protection is a modifier, not a profile', () { ... });
// expect(state.baseProfile.id, 'relax'); expect(state.protection, isNotNull);

test('expired protection is ignored', () { ... });
test('nextChangeAt is the next boundary', () { ... });
// now = DateTime(2026,11,16,9,0), window 540..1020 -> DateTime(2026,11,16,17,0)

test('resolves on both sides of a DST jump without throwing', () { ... });
// DateTime(2026,3,29,1,30) and DateTime(2026,3,29,3,30) both return a state
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/domain/resolver_test.dart`
Expected: FAIL — `resolveActiveState` is not defined.

- [ ] **Step 4: Implement models and `resolveActiveState`**

Rules, in order: expired `pin` and `protection` are ignored (strict `isAfter(now)`); an active pin wins, else the highest-priority enabled schedule whose window contains `now`, else the default profile. A schedule's window contains `now` when `startMinute < endMinute` and `startMinute <= minute < endMinute` and the weekday is in `daysOfWeek`, or when it wraps and (`minute >= startMinute` with today's weekday, or `minute < endMinute` with yesterday's weekday). Tie-break by `priority`, then by the later `updatedAt`. `nextChangeAt` is the earliest future instant among every enabled schedule's next start or end (scan 8 days), the pin expiry and the protection expiry; `null` if none.

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/domain/resolver_test.dart`
Expected: PASS, 13 tests.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml lib/models.dart lib/domain/resolver.dart test/domain/resolver_test.dart
git commit -m "feat: clock-derived resolver with overnight and overlap rules"
```

---

### Task 2: Timeline builder

**Files:**
- Create: `lib/domain/timeline.dart`, `test/domain/timeline_test.dart`

**Interfaces:**
- Consumes: `resolveActiveState` (Task 1), all Task 1 models.
- Produces: `class TimelineEntry { DateTime effectiveAt; ActiveState state; }`, `List<TimelineEntry> buildTimeline({required DateTime now, required List<Profile> profiles, required List<Schedule> schedules, required String defaultProfileId, Pin? pin, Protection? protection})`, `Set<Category> resolveFilterCategories(ActiveState state)` returning the union of the base profile's `reduce`/`hide` categories and `protection.softenedCategories`, and `Map<String, dynamic> timelineToJson(List<TimelineEntry> entries)` producing the payload shape in spec delta §5.

- [ ] **Step 1: Write the failing tests**

```dart
test('starts at now and stops when no boundary remains', () { ... });
// no schedules -> 1 entry, effectiveAt == now

test('adds one entry per boundary across a week', () { ... });
// Mon/Wed 540..1020 -> entries at now, 17:00, Wed 09:00, Wed 17:00, ... capped at 32

test('includes the post-expiry state when protection ends', () { ... });
// protection expires 18:00, window 540..1020 -> the entry at 18:00 has protection == null

test('filter categories are the profile levels plus protection', () { ... });
// profile hides breakup, protection softens anger_aggression -> {'breakup', 'anger_aggression'}

test('filter categories are empty when nothing is reduced or hidden', () { ... });

test('serialises to the spec payload shape', () { ... });
// jsonDecode(jsonEncode(timelineToJson(...)))['states'][0]['surfaces']['feed'] == 'hide'
// ...['states'][0]['filterCategories'] == ['breakup']
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/domain/timeline_test.dart`
Expected: FAIL — `buildTimeline` not defined.

- [ ] **Step 3: Implement**

Loop: resolve at `t` (starting at `now`), append, stop if `nextChangeAt` is null, if `t` would exceed `now + 30 days`, or after 32 entries; otherwise `t = nextChangeAt`. `timelineToJson` writes `{v: 1, generatedAt, states: [...]}` with `effectiveAt` as epoch millis, `protection` as `{expiresAt, softened}` or `null`, `surfaces` as level names (`allow`/`reduce`/`hide`), `followingOnly` from the winning profile, and `filterCategories` from `resolveFilterCategories`.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/domain/timeline_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/timeline.dart test/domain/timeline_test.dart
git commit -m "feat: sample the resolver forward into a pushed timeline"
```

---

### Task 3: Store

**Files:**
- Create: `lib/data/store.dart`, `test/data/store_test.dart`

**Interfaces:**
- Consumes: Task 1 models.
- Produces: `class MoodData { List<Profile> profiles; List<Schedule> schedules; Pin? pin; Protection? protection; Settings settings; List<GateEvent> gateEvents; }`, `class Settings { String defaultProfileId; bool gateEnabled; Set<Category> protectionDefaults; bool counterOptIn; }`, `class GateEvent { DateTime ts; String packageName; String action; String profileId; bool protectionOn; }`, `class Store { Future<MoodData> load(); Future<void> save(MoodData data); }` over `SharedPreferences` key `moodfeed.v1`, plus `MoodData MoodData.defaults()`.

- [ ] **Step 1: Write the failing tests**

```dart
test('first launch returns a default profile and a weekday schedule', () { ... });
// profiles.length == 4, names Work/Public/Private/Relax, exactly one isDefault

test('round-trips profiles, schedules, pin and protection', () { ... });

test('corrupt JSON returns defaults and does not throw', () { ... });
// prefs.setString('moodfeed.v1', '{not json') -> load() returns MoodData.defaults()

test('partial JSON keeps what it can and fills the rest', () { ... });
// '{"profiles":[]}' -> schedules and settings from defaults, no throw
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/data/store_test.dart`
Expected: FAIL — `Store` not defined.

- [ ] **Step 3: Implement**

One JSON document, `toJson`/`fromJson` per model. Every `fromJson` takes a default value for a missing key; `load()` catches `FormatException` and any `TypeError` and returns `MoodData.defaults()`. `defaults()` = four profiles, `relax` default, one schedule Mon–Fri 09:00–17:00 → `work`, protection defaults = the three conflict categories.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/store_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/data/store.dart test/data/store_test.dart
git commit -m "feat: single-document local store with corrupt-blob fallback"
```

---

### Task 4: Providers and app shell

**Files:**
- Create: `lib/state/providers.dart`, `lib/main.dart`, `lib/app.dart`

**Interfaces:**
- Consumes: `Store`, `MoodData`, `resolveActiveState`, `buildTimeline`.
- Produces: `final storeProvider`, `final dataProvider` (`NotifierProvider<DataNotifier, MoodData>` with `Future<void> update(MoodData Function(MoodData) change)`), `final clockProvider` (`StreamProvider<DateTime>`, one tick per second), `final activeStateProvider` (`Provider<ActiveState>`), `final packInstalledProvider` (`FutureProvider<bool>`).

- [ ] **Step 1: Write the failing test**

`test/state/providers_test.dart`: override `clockProvider` with a fixed `DateTime`, override `storeProvider` with an in-memory store, assert `activeStateProvider` returns `Reason.scheduled` and that `dataProvider.notifier.update` persists through the store.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/state/providers_test.dart`
Expected: FAIL — providers not defined.

- [ ] **Step 3: Implement**

`clockProvider` emits `DateTime.now()` on a 1s `Stream.periodic`. `activeStateProvider` reads `dataProvider`, `clockProvider` and calls `resolveActiveState` — nothing cached, nothing stored. `app.dart` builds a `MaterialApp` with `ThemeMode.dark`, and a `NavigationBar` of Home / Profiles / Schedule / Settings.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/state/providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/state/providers.dart lib/main.dart lib/app.dart test/state/providers_test.dart
git commit -m "feat: riverpod shell with derived active state"
```

---

### Task 5: Home screen

**Files:**
- Create: `lib/ui/home_screen.dart`, `test/ui/home_screen_test.dart`

**Interfaces:**
- Consumes: `activeStateProvider`, `dataProvider`, `buildTimeline`.
- Produces: `class HomeScreen extends ConsumerWidget`.

- [ ] **Step 1: Write the failing widget tests**

```dart
testWidgets('shows the base mode and why it is active', ...);
// clock fixed at Mon 09:00 -> finds 'Work' and 'Scheduled'

testWidgets('shows the protection countdown on the base mode', ...);
// protection active -> finds 'Relax — protecting 3 topics'

testWidgets('shows the base mode after protection expires', ...);
// protection expiresAt in the past -> finds 'Relax', no 'protecting'

testWidgets('turning protection off is one tap from home', ...);
// tap the protection badge -> protection is null in dataProvider

testWidgets('pinning a mode expires at the next boundary', ...);
// clock Mon 09:00, default schedule 540..1020 -> pin('private').expiresAt == DateTime(2026,11,16,17,0)
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/ui/home_screen_test.dart`
Expected: FAIL — `HomeScreen` not defined.

- [ ] **Step 3: Implement**

Base mode name + reason line, protection badge with countdown and a tap-to-end action, "next switch in 2h 14m", a `FilledButton` "Protect my peace" opening the protection sheet, and a quick mode switch row. A quick switch writes a `Pin` whose `expiresAt` is `activeState.nextChangeAt` (null when there is no boundary). No streaks, no counters.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/ui/home_screen_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/home_screen.dart test/ui/home_screen_test.dart
git commit -m "feat: home screen with derived mode and protection countdown"
```

---

### Task 6: Profiles and editor

**Files:**
- Create: `lib/ui/profiles_screen.dart`, `lib/ui/profile_editor.dart`, `test/ui/profile_editor_test.dart`

**Interfaces:**
- Consumes: `dataProvider`, `Profile`, `Surface`, `Level`, `Category`.
- Produces: `class ProfilesScreen extends ConsumerWidget`, `class ProfileEditor extends ConsumerStatefulWidget` with `ProfileEditor({required Profile profile})`.

- [ ] **Step 1: Write the failing widget tests**

```dart
testWidgets('lists the four modes', ...);
testWidgets('editing a surface level persists it', ...);
// open Work, set feed -> allow, assert dataProvider profile.surfaces[Surface.feed] == Level.allow
testWidgets('setting a new default clears the previous one', ...);
// expect exactly one profile with isDefault true
testWidgets('following-only is its own switch, not a surface level', ...);
// toggle it on Work -> profile.followingOnly true, profile.surfaces unchanged
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/ui/profile_editor_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

List with name, icon, and a one-line summary of what it hides. Editor: name field, per-surface `SegmentedButton` of allow/reduce/hide, per-category levels, and a "Following accounts only" switch bound to `followingOnly`. Exactly one profile may be default; setting a new default clears the old.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/ui/profile_editor_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/profiles_screen.dart lib/ui/profile_editor.dart test/ui/profile_editor_test.dart
git commit -m "feat: mode list and per-surface editor"
```

---

### Task 7: Schedule screen

**Files:**
- Create: `lib/ui/schedule_screen.dart`, `test/ui/schedule_screen_test.dart`

**Interfaces:**
- Consumes: `dataProvider`, `Schedule`.
- Produces: `class ScheduleScreen extends ConsumerWidget`.

- [ ] **Step 1: Write the failing widget tests**

```dart
testWidgets('lists blocks sorted by start time', ...);
testWidgets('a block shows its days, window and mode', ...);
testWidgets('disabling a block removes it from resolution', ...);
// disable the only block at Mon 09:00 -> activeStateProvider.reason == defaultProfile
testWidgets('a wrapping block is labelled as overnight', ...);
// start 1320, end 420 -> finds '22:00 – 07:00'
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/ui/schedule_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Blocks grouped by day with a 24-hour bar; add/edit sheet with day chips, start/end `TimePicker`, mode dropdown, priority stepper, enabled switch. Copy states that overlapping blocks are legal and priority decides.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/ui/schedule_screen_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/schedule_screen.dart test/ui/schedule_screen_test.dart
git commit -m "feat: weekly schedule editor"
```

---

### Task 8: Protection sheet

**Files:**
- Create: `lib/ui/protection_sheet.dart`, `test/ui/protection_sheet_test.dart`

**Interfaces:**
- Consumes: `dataProvider`, `Protection`, `Category`.
- Produces: `class ProtectionSheet extends ConsumerStatefulWidget`, `Future<Protection?> showProtectionSheet(BuildContext)`.

- [ ] **Step 1: Write the failing widget tests**

```dart
testWidgets('offers 30m, 2h, 4h and until morning', ...);
testWidgets('preselects the stored default categories', ...);
testWidgets('romantic and suggestive are absent, not disabled', ...);
// expect(find.text('Romantic'), findsNothing); expect(find.text('Suggestive'), findsNothing);
testWidgets('confirming writes an expiry and leaves the base mode alone', ...);
// 2h chip -> protection.expiresAt == now + 2h; baseProfile unchanged
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/ui/protection_sheet_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Duration chips (30m, 2h, 4h, until morning = next 07:00 local), checkbox rows for the three default categories only, confirm button. The sheet never auto-activates and never renews.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/ui/protection_sheet_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/protection_sheet.dart test/ui/protection_sheet_test.dart
git commit -m "feat: protection sheet with fixed categories and self-expiring durations"
```

---

### Task 9: Settings screen

**Files:**
- Create: `lib/ui/settings_screen.dart`, `test/ui/settings_screen_test.dart`

**Interfaces:**
- Consumes: `dataProvider`, `packInstalledProvider`, `Settings`.
- Produces: `class SettingsScreen extends ConsumerWidget`.

- [ ] **Step 1: Write the failing widget tests**

```dart
testWidgets('keeps the gate toggle whether or not the pack is installed', ...);
// packInstalled true and false -> find.text('App-open reminder') in both
testWidgets('names the pack as installed without hiding anything', ...);
testWidgets('shows the honest degraded-mode line when usage access is missing', ...);
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/ui/settings_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Default mode picker, gate toggle (always present — it watches stock Instagram and Facebook, which the clone leaves installed), usage-access grant row that deep-links to the system screen and explains the fallback, protection defaults, gate-event counter toggle, a read-only "MoodFeed pack" row showing installed/not, and an "about" block stating the privacy claim.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/ui/settings_screen_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/settings_screen.dart test/ui/settings_screen_test.dart
git commit -m "feat: settings with capability-aware gate toggle"
```

---

### Task 10: Usage channel and the gate

**Files:**
- Create: `android/app/src/main/kotlin/com/moodfeed/moodfeed/MoodFeedPlugin.kt`, `lib/platform/usage_channel.dart`, `lib/platform/gate.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/com/moodfeed/moodfeed/MainActivity.kt`

**Interfaces:**
- Consumes: `activeStateProvider`.
- Produces: `class MoodFeedPlatform { Future<String?> foregroundPackage(); Future<bool> hasUsageAccess(); Future<void> openUsageAccessSettings(); Future<bool> isPackInstalled(); Future<bool> pushTimeline(String json); }` over channel `com.moodfeed/platform`.

- [ ] **Step 1: Write the failing test**

`test/platform/usage_channel_test.dart`: register a `TestDefaultBinaryMessengerBinding` handler returning `'com.instagram.android'`, assert `MoodFeedPlatform().foregroundPackage()` returns it, and that a `null` reply maps to `null` without throwing.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/platform/usage_channel_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the Kotlin side**

`foregroundPackage` queries `UsageStatsManager.queryEvents(now - 10s, now)` and returns the last `ACTIVITY_RESUMED` package. `hasUsageAccess` checks `AppOpsManager` `GET_USAGE_STATS`. `openUsageAccessSettings` starts `Settings.ACTION_USAGE_ACCESS_SETTINGS`. `isPackInstalled` checks `PackageManager` for `com.instagram.android.moodfeed`. `pushTimeline` calls the pack's ContentProvider (Task 11 wires the call).

- [ ] **Step 4: Implement the gate**

`flutter_foreground_task` starts when `settings.gateEnabled`, the pack is absent, and usage access is granted. It polls every 5s, fires when a watched package (`com.instagram.android`, `com.facebook.katana`, and their `.lite`/`.orca` builds) becomes foreground after ≥5 minutes background, applies a persisted 90-minute cooldown per package, and posts a high-priority notification naming the active mode with `Close app` / `Continue` actions. Record a `GateEvent` on either action, and keep the list trimmed to the newest 500.

- [ ] **Step 5: Verify manually on a device**

Run: `flutter run`, open Instagram, confirm the notification appears once and not again within 90 minutes. Confirm the persistent low-importance notification appears when usage access is revoked.

- [ ] **Step 6: Commit**

```bash
git add android lib/platform test/platform
git commit -m "feat: usage-stats channel and dismissible app-open gate"
```

---

### Task 11: Pack bridge

**Files:**
- Create: `lib/platform/pack_bridge.dart`, `test/platform/pack_bridge_test.dart`
- Modify: `lib/app.dart`, `lib/state/providers.dart`, `MoodFeedPlugin.kt`

**Interfaces:**
- Consumes: `buildTimeline`, `timelineToJson`, `MoodFeedPlatform`.
- Produces: `class PackBridge { Future<void> push(MoodData data, DateTime now); }`; `packInstalledProvider` backed by `MoodFeedPlatform.isPackInstalled()`.

- [ ] **Step 1: Write the failing test**

```dart
test('pushes the serialised timeline when the pack is installed', ...);
// fake platform records the json; assert states.length >= 1 and effectiveAt <= now

test('does nothing when the pack is absent', ...);
// isPackInstalled false -> platform received no push
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/platform/pack_bridge_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Kotlin `pushTimeline` does `contentResolver.call(Uri.parse('content://com.instagram.android.moodfeed.state'), 'set_state', null, bundleOf('json' to json))` inside a `try/catch (SecurityException | IllegalArgumentException)` that returns `false` — a missing or unsigned pack must be silent. Dart calls `PackBridge.push` on app start, on every `dataProvider` change, and on `AppLifecycleState.resumed`.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/platform/pack_bridge_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/platform/pack_bridge.dart test/platform/pack_bridge_test.dart lib/app.dart lib/state/providers.dart android
git commit -m "feat: push resolved timeline to the patched pack"
```

---

### Task 12: Release

**Files:**
- Modify: `README.md`, `android/app/build.gradle.kts`

**Interfaces:**
- Consumes: everything.
- Produces: a signed `app-release.apk`.

- [ ] **Step 1: Verify the manifest claim**

Run: `grep -c INTERNET android/app/src/main/AndroidManifest.xml`
Expected: `0`. If not zero, remove the permission and re-run.

- [ ] **Step 2: Configure signing**

Add a `release` signingConfig reading `key.properties` (git-ignored), `minifyEnabled true`, and `applicationId "com.moodfeed.app"`.

- [ ] **Step 3: Build**

Run: `flutter build apk --release`
Expected: `build/app/outputs/flutter-apk/app-release.apk` exists.

- [ ] **Step 4: Install and smoke-test**

Run: `adb install -r build/app/outputs/flutter-apk/app-release.apk`
Open the app: home shows a mode, the schedule screen has the default weekday block, protection sheet offers four durations, and the gate notification fires once when Instagram opens.

- [ ] **Step 5: Commit**

```bash
git add README.md android/app/build.gradle.kts
git commit -m "chore: signed release build"
```
