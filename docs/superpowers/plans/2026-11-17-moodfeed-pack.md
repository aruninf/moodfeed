# MoodFeed Pack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fork FeurStagram into the MoodFeed Pack: a patched Instagram build that obeys the timeline MoodFeed pushes to it, so a mode actually removes surfaces and protection actually filters conflict content.

**Architecture:** MoodFeed stays the brain. The pack holds no rules: a `ContentProvider` receives one JSON timeline from the signed MoodFeed app, stores it verbatim, and a `ModeApplier` maps the entry in force onto FeurStagram's existing `Config` toggles, then restarts the activity. Protection categories are matched by a pure `CategoryLexicon` class called from the existing feed-item filter.

**Tech Stack:** Kotlin patches (Morphe `app.morphe.patches` 1.3.2), a Java extension merged into the APK, Python + `javac` test harness (the existing `tests/` pattern), `build.sh`.

**Spec:** `docs/superpowers/specs/2026-11-17-moodfeed-pack-design.md`

## Global Constraints

- GPLv3. The fork keeps `LICENSE`, `NOTICE` and the Piko/Morphe attribution. Source ships with every release.
- Package stays `com.instagram.android`; the default build renames to `com.instagram.android.moodfeed` (clone). Classic stays available.
- Same signing key as MoodFeed. The bridge permission is `protectionLevel="signature"`.
- No added network calls, no telemetry, no analytics. `feurstagram_prefs` stays the only store.
- Never crash Instagram. Every bridge path catches `SecurityException`, `IllegalArgumentException` and `JSONException` and returns silently.
- Java 17 source level for the extension; JDK 21 for the build.
- English-only keyword lexicon in v1 (documented as a limit, not a bug).

## Review Focus

1. **A payload from a newer MoodFeed** — unknown keys, `states: []`, or a missing `surfaces` object must leave the last good state in force and never crash the app. (Task 2)
2. **A pack signed with a different key** (someone rebuilds it) — the provider call throws `SecurityException`; the pack must keep working with its own stored toggles, and MoodFeed must fall back to the gate. (Tasks 2 and 3)
3. **A response whose root container is emptied** — the filter must never empty the DM inbox, the story tray or the profile payload; only individual content units may be dropped. (Task 4)
4. **A mode applied while the user is inside the pack's own settings page** — the pushed state wins; the page must say so instead of silently reverting the user's tap. (Task 3)
5. **Instagram updated, patch applies, provider missing** — the bridge no-ops and MoodFeed's gate takes over. No install-time failure. (Task 2; MoodFeed side: Plan 1 Task 11)

---

### Task 0: Prove the toolchain

**Files:**
- Move: `moodfeed/FeurStagram` → `~/src/feurstagram` (it is a nested git repo inside the MoodFeed repo)

**Interfaces:**
- Consumes: nothing.
- Produces: a patched, signed, installed Instagram APK and a working `build.sh` invocation to repeat it.

- [ ] **Step 1: Move the clone out of the MoodFeed repo**

Run: `mv /Users/arunkumar/Downloads/moodfeed/FeurStagram ~/src/feurstagram && cd /Users/arunkumar/Downloads/moodfeed && git status --short`
Expected: no `?? FeurStagram/` line.

- [ ] **Step 2: Satisfy the build prerequisites**

Install JDK 21 and the Android SDK build-tools; put a GitHub token with `read:packages` into `~/.gradle/gradle.properties` as `gpr.user` / `gpr.key`.

- [ ] **Step 3: Download a base APK**

Get a current `com.instagram.android` arm64-v8a APK (`.apk` or `.apkm`) from APKMirror.

- [ ] **Step 4: Build and install**

Run: `cd ~/src/feurstagram && ./build.sh <instagram.apk> --clone --install`
Expected: `feurstagram.apk` is produced, `adb install` succeeds, the app launches and its settings page opens from the profile header.

- [ ] **Step 5: Record what worked**

Append the exact commands, JDK path, Instagram version and any fingerprint failures to `docs/BUILD_FROM_SOURCE.md` in the fork. This is the baseline every later task is built on.

---

### Task 1: Fork and rebrand

**Files:**
- Create: `~/src/moodfeed-pack/` (fork of FeurStagram)
- Modify: `settings.gradle.kts`, `patches/build.gradle.kts`, `patches/src/main/kotlin/com/feurstagram/patches/clone/ClonePatch.kt`, `extensions/extension/src/main/java/com/feurstagram/extension/Settings.java`

**Interfaces:**
- Consumes: Task 0's working build.
- Produces: `com.moodfeed.pack` as the extension package root, `com.instagram.android.moodfeed` as the clone package, and a build that produces `moodfeed-pack.apk`.

- [ ] **Step 1: Fork and rename**

Run: `cp -R ~/src/feurstagram ~/src/moodfeed-pack && cd ~/src/moodfeed-pack && rm -rf .git && git init`
Rename `rootProject.name` to `moodfeed-pack`, `group` to `com.moodfeed`, and move `patches/src/main/kotlin/com/feurstagram/patches` to `com/moodfeed/pack/patches`; same for the extension package. Update every `Constants.EXTENSION_PACKAGE` reference.

- [ ] **Step 2: Rename the clone package and label**

In `ClonePatch.kt` set the clone package to `com.instagram.android.moodfeed` and the label to `MoodFeed`. Keep the classic path unchanged.

- [ ] **Step 3: Rebrand the settings page**

Change the header string, the settings entry-point content description, and the "about" row to MoodFeed. Keep the monochrome M3 design system in `Settings.java` — do not introduce a hue.

- [ ] **Step 4: Verify the build still patches and installs**

Run: `./build.sh <instagram.apk> --clone --install`
Expected: the app installs as `com.instagram.android.moodfeed`, is labelled `MoodFeed`, and opens its settings page.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "chore: fork FeurStagram as the MoodFeed pack"
```

---

### Task 2: State provider

**Files:**
- Create: `extensions/extension/src/main/java/com/moodfeed/pack/extension/MoodState.java`, `MoodStateProvider.java`
- Modify: the patch that edits `AndroidManifest.xml` (add the provider + permission), `extensions/extension/src/main/AndroidManifest.xml`
- Test: `tests/test_mood_state.py`

**Interfaces:**
- Consumes: the payload shape from spec delta §5.
- Produces: `final class MoodState { static MoodState parse(String json); long effectiveAt; String base; String reason; Set<String> softened; Set<String> filterCategories; Map<String,String> surfaces; boolean followingOnly; long protectionExpiresAt; }`, `static MoodState current(Context)` returning the entry in force or `null`, and `MoodStateProvider extends ContentProvider` answering `call("set_state", ...)`.

- [ ] **Step 1: Write the failing test**

`tests/test_mood_state.py`, following the existing harness pattern (compile the extension sources with `javac` into a temp dir, drive a `Harness` main over stdin):

```python
def test_keeps_last_good_state_on_garbage(self): ...
# feed "{not json" -> current() is None, no exception

def test_unknown_keys_are_ignored(self): ...
# payload with "future_key": 1 still parses

def test_empty_states_keeps_previous(self): ...
# set_state with states: [] -> current() still returns the earlier entry

def test_picks_the_last_entry_not_in_the_future(self): ...
# entries at t, t+3600s; clock at t+10 -> effectiveAt == t

def test_expired_protection_is_dropped(self): ...
# entry protection.expiresAt < now -> softened empty

def test_filter_categories_are_read_as_given(self): ...
# ["breakup"] -> filterCategories == {"breakup"}; a missing key -> empty set
```

- [ ] **Step 2: Run to verify failure**

Run: `python3 tests/test_mood_state.py`
Expected: FAIL — `MoodState` not found.

- [ ] **Step 3: Implement `MoodState`**

Parse with `org.json.JSONObject` inside `try/catch (JSONException)`. Store the raw string in `feurstagram_prefs` under `moodfeed_state`. `current(Context)` reads it, picks the last `states` entry whose `effectiveAt <= System.currentTimeMillis()`, drops `protection` when `protectionExpiresAt <= now`, and returns `null` on any failure.

- [ ] **Step 4: Implement the provider and its manifest entry**

`MoodStateProvider.call("set_state", ...)` reads `bundle.getString("json")`, calls `MoodState.parse`, persists it, returns `Bundle.EMPTY`. Manifest additions, inserted through the patch's manifest editor:

```xml
<permission android:name="com.instagram.android.moodfeed.permission.STATE" android:protectionLevel="signature"/>
<provider
    android:name="com.moodfeed.pack.extension.MoodStateProvider"
    android:authorities="com.instagram.android.moodfeed.state"
    android:exported="true"
    android:readPermission="com.instagram.android.moodfeed.permission.STATE"
    android:writePermission="com.instagram.android.moodfeed.permission.STATE"/>
```

- [ ] **Step 5: Run to verify it passes**

Run: `python3 tests/test_mood_state.py`
Expected: PASS, 6 tests.

- [ ] **Step 6: Verify on device**

With the MoodFeed app installed from Plan 1 Task 11, open it, then run `adb shell dumpsys activity provider com.instagram.android.moodfeed.state | head` and confirm the state is stored.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: signature-protected state provider for the pushed timeline"
```

---

### Task 3: Apply a mode

**Files:**
- Create: `extensions/extension/src/main/java/com/moodfeed/pack/extension/ModeApplier.java`
- Modify: `Settings.java` (banner + disabled rows when bridged), `SettingsEntryPointPatch.kt` (call `ModeApplier.apply` on activity resume)
- Test: `tests/test_mode_applier.py`

**Interfaces:**
- Consumes: `MoodState.current(Context)`, `Config.setBlocked(String, boolean)`.
- Produces: `static void apply(Context)` writing the surface keys and restarting when the applied state differs from the last applied one.

- [ ] **Step 1: Write the failing test**

```python
def test_hide_maps_to_true(self): ...
# surfaces feed=hide -> block_feed true
def test_allow_maps_to_false(self): ...
def test_reduce_leaves_the_surface_on(self): ...
# feed=reduce -> block_feed false, and reduce is recorded for the lexicon
def test_following_only_maps_to_limit_following_feed(self): ...
def test_identical_state_does_not_restart(self): ...
def test_changed_state_restarts_once(self): ...
```

- [ ] **Step 2: Run to verify failure**

Run: `python3 tests/test_mode_applier.py`
Expected: FAIL.

- [ ] **Step 3: Implement the mapping**

`feed→block_feed`, `reels→block_reels`, `explore→block_explore`, `stories→block_stories`, `suggested→block_suggested`, `ads→block_ads`, `notes→block_notes`, `instants→block_instants`, `threadsButton→block_threads`, `followingOnly→limit_following_feed`. `hide` → `true`, `allow` → `false`, `reduce` → `false` plus the surface is remembered as reduced. Store the applied JSON hash in `moodfeed_applied`; restart the activity only when it changes.

- [ ] **Step 4: Show the bridge state in the settings page**

When a valid `MoodState` exists, prepend a read-only banner "Managed by MoodFeed — Relax, protecting 3 topics" and disable the Blocked-surfaces and Feed rows, so a tap cannot silently lose to the next push.

- [ ] **Step 5: Run to verify it passes**

Run: `python3 tests/test_mode_applier.py`
Expected: PASS, 6 tests.

- [ ] **Step 6: Verify on device**

Change the mode in MoodFeed, reopen the pack, confirm the feed appears/disappears without touching the pack's own settings.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: apply the pushed mode to surfaces"
```

---

### Task 4: Protection content filter

**Files:**
- Create: `extensions/extension/src/main/java/com/moodfeed/pack/extension/CategoryLexicon.java`
- Modify: `patches/src/main/kotlin/com/moodfeed/pack/patches/network/FeedItemFilterPatch.kt`, `ModeApplier.java`
- Test: `tests/test_category_lexicon.py`

**Interfaces:**
- Consumes: `MoodState.filterCategories` and the surface levels from `MoodState`.
- Produces: `static boolean matches(String caption, Set<String> categories)`, `static String categoryOf(String caption)`.

- [ ] **Step 1: Write the failing test**

```python
def test_matches_a_breakup_caption(self): ...
# "we broke up last night" with {"breakup"} -> True
def test_ignores_categories_not_softened(self): ...
# same caption with {"anger_aggression"} -> False
def test_case_and_punctuation_insensitive(self): ...
# "Broke Up." -> True
def test_empty_caption_is_not_a_match(self): ...
def test_romantic_is_never_matched_by_protection(self): ...
# caption "i love you so much" with the three default categories -> False
```

- [ ] **Step 2: Run to verify failure**

Run: `python3 tests/test_category_lexicon.py`
Expected: FAIL.

- [ ] **Step 3: Implement the lexicon**

A `Map<String, String[]>` keyed by category id, matched with lowercase `String.contains`. `relationship_conflict`: breakup, broke up, cheating, cheated, toxic, argument, fight, narcissist, red flag. `breakup`: broke up, breakup, ex-boyfriend, ex-girlfriend, divorce, heartbroken. `anger_aggression`: rage, furious, hate, revenge, screaming, abuse. No entries for `romantic` or `suggestive`.

- [ ] **Step 4: Wire it into the feed-item filter**

In `FeedItemFilterPatch`, before the existing type-token rewrite, read the unit's caption text; when `CategoryLexicon.matches` is true for the active `filterCategories` set and the surface is not `hide`, rewrite the token to the invalid one. Home feed and Reels only. Never touch the DM inbox, the story tray, or profile payloads.

- [ ] **Step 5: Run to verify it passes**

Run: `python3 tests/test_category_lexicon.py`
Expected: PASS, 5 tests.

- [ ] **Step 6: Verify on device**

Turn protection on in MoodFeed, open the pack's home feed, and confirm a conflict/breakup unit no longer renders while DMs and stories are intact. Turn it off and confirm the feed returns.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: protection filters conflict content by category"
```

---

### Task 5: Quick Settings tile

**Files:**
- Create: `extensions/extension/src/main/java/com/moodfeed/pack/extension/ProtectionTile.java`
- Modify: manifest (add the `TileService`), `ModeApplier.java` (honour a locally requested protection)
- Test: `tests/test_protection_tile.py`

**Interfaces:**
- Consumes: `MoodState`, `Config`.
- Produces: `ProtectionTile extends TileService` with one tap = 2 hours of protection requested from the pack side.

- [ ] **Step 1: Write the failing test**

```python
def test_tile_request_sets_a_two_hour_expiry(self): ...
def test_tile_request_survives_a_restart(self): ...
def test_tile_request_does_not_override_a_moodfeed_push(self): ...
# a pushed state with an active protection wins over a tile request
```

- [ ] **Step 2: Run to verify failure**

Run: `python3 tests/test_protection_tile.py`
Expected: FAIL.

- [ ] **Step 3: Implement**

`ProtectionTile.onClick` writes `tile_protection_expires` = now + 2h into `feurstagram_prefs`, then calls `ModeApplier.apply`. `ModeApplier` uses the later of the pushed protection expiry and the tile expiry, and keeps the softened set from the last pushed state (or the three defaults when none exists). The tile shows "Protecting" while active and clears itself at expiry.

- [ ] **Step 4: Run to verify it passes**

Run: `python3 tests/test_protection_tile.py`
Expected: PASS, 3 tests.

- [ ] **Step 5: Verify on device**

Add the tile, tap it, confirm the feed empties for two hours and restores itself without reopening anything.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: one-tap protection tile"
```

---

### Task 6: Release

**Files:**
- Modify: `README.md`, `docs/INSTALL.md`, `docs/PRIVACY.md`, `extensions/extension/src/main/java/com/moodfeed/pack/extension/UpdateChecker.java`

**Interfaces:**
- Consumes: everything above.
- Produces: a signed release APK, its SHA256, and install instructions that state the risks plainly.

- [ ] **Step 1: Point the updater at our releases**

Set the repository slug in `UpdateChecker` to the MoodFeed pack repo and keep the once-per-day prompt throttle.

- [ ] **Step 2: Rewrite the install copy**

State, in this order: what the pack changes, that it is a modified Instagram build installed outside Play, that it may violate Instagram's terms and accounts may be restricted, that the source and patches are public, that the clone package keeps stock Instagram installed, and that MoodFeed works without the pack.

- [ ] **Step 3: Build and hash**

Run: `./build.sh <instagram.apk> --clone`
Run: `shasum -a 256 moodfeed-pack.apk`
Expected: an APK and a hash to paste into the release notes.

- [ ] **Step 4: Smoke-test the whole loop**

On a clean device: install MoodFeed, install the pack, log in, switch modes in MoodFeed, confirm the pack follows within one reopen, tap the tile, confirm protection, then uninstall the pack and confirm MoodFeed falls back to the gate notification.

- [ ] **Step 5: Commit and tag**

```bash
git add -A && git commit -m "docs: release, install and privacy copy for the pack"
git tag v1.0.0 && git push --tags
```
