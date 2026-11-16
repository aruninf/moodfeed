# MoodFeed — The Original Idea and the Problem

> Companion to the Phase 1 contract: [`specs/2026-11-16-moodfeed-design.md`](superpowers/specs/2026-11-16-moodfeed-design.md).
> This document is the *why*. The spec is the *what*.

---

## 1. The idea

A social media feed does not know what kind of day you are having.

It knows what held your attention yesterday. It has no idea whether that attention was wanted, welcome, or the reason you felt worse afterwards.

**MoodFeed is a time-aware control layer between you and the apps you already use.** Not another social network. Not a feed. A thin layer that holds your rules — what you want to see at 8am on a train, at 9pm on a sofa, and on the evening after a hard conversation — and intervenes at the one moment it can: when you open Instagram.

---

## 2. The problem

### 2.1 The loop nobody designed

```mermaid
flowchart TD
    A["Bad evening<br/>argument · stress · loneliness"] --> B["Open Instagram<br/>to unwind"]
    B --> C["Angry relationship reel<br/>appears in the feed"]
    C --> D["Watch to the end<br/>read the comments"]
    D --> E["Platform records<br/>watch time · dwell · replay"]
    E --> F["Ranker concludes:<br/>this user engages with conflict"]
    F --> C
    E --> G["Your 'interests' update<br/>for weeks"]
    G --> C

    style A fill:#fde8e8,stroke:#c0392b
    style C fill:#fde8e8,stroke:#c0392b
    style F fill:#fde8e8,stroke:#c0392b
```

Read it again with one substitution: **attention is not intent.**

The ranker's job is to predict engagement. Engagement is measurable. Intent is not. So the system learns the only thing it can observe — that conflict content holds you — and treats a bad evening as a preference.

### 2.2 The asymmetry

Every signal the platform collects is a *behaviour*. Every signal that matters to you is a *context*.

| What the algorithm sees | What it cannot see |
|---|---|
| Watch duration | Whether you were doom-scrolling at 1am |
| Replays | Whether you replayed it because it upset you |
| Likes, comments, saves | Whether you were in public, at work, on a train |
| Skips | Whether you were protecting your peace |
| Accounts followed | Whether your interests changed this month |
| Topic and creator metadata | Whether you had an argument an hour ago |

One replayed video can outweigh a year of deliberate choices, because the deliberate choices require a tap and the replay requires nothing.

### 2.3 The day has a shape the feed ignores

These two curves are the entire product thesis. They are illustrative, not measured — measuring them honestly is Phase 5.

```mermaid
xychart-beta
    title "Public-safe content — what you actually want, by hour"
    x-axis [dawn, morning, midday, afternoon, evening, night, late]
    y-axis "Appetite (0-10)" 0 --> 10
    line [8, 9, 7, 5, 3, 2, 2]
```

```mermaid
xychart-beta
    title "Private / emotional content — what you actually want, by hour"
    x-axis [dawn, morning, midday, afternoon, evening, night, late]
    y-axis "Appetite (0-10)" 0 --> 10
    line [1, 1, 2, 3, 6, 9, 8]
```

The curves cross around 6pm. **The feed serves the same mixture at both times**, because a global ranker has one model of you. Two people with identical histories but different clocks are served identical content.

That gap — between what the clock implies and what the ranker assumes — is the product.

### 2.4 What happens over a fortnight

```mermaid
xychart-beta
    title "Conflict reels per 20 in the feed, after one bad night (illustrative)"
    x-axis [d0, d2, d4, d6, d8, d10, d14]
    y-axis "Conflict reels per 20 feed items" 0 --> 20
    line [2, 5, 8, 11, 13, 15, 16]
```

The line is not the interesting part. The interesting part is that **nothing in the platform has a concept of "this was a bad night, don't learn from it."** There is no signal for a one-off. A temporary state is permanently encoded as a trait.

### 2.5 Why the user cannot just fix it in settings

Instagram offers *Not Interested*, *Show Less*, Hidden Words, Sensitive Content Control, and a suggested-content reset. These are real and they help. They share three limits:

1. **They are global, not temporal.** "Show less relationship content" applies at 8am on the train too.
2. **They require the encounter first.** You must be shown the thing to suppress it.
3. **They are permanent.** There is no two-hour "I'm fragile tonight" toggle that undoes itself.

Meta's own *Your Algorithm* (Nov 2026) fixes the first partly — natural-language preferences — but still answers *"what do you want?"*, not *"what do you want **right now**?"*

---

## 3. What we are building

```mermaid
flowchart LR
    U["You"] -->|"opens, 8:04am"| IG["Instagram / Facebook"]
    U -->|"one tap"| MF["MoodFeed"]

    subgraph phone ["On your phone · no server · no INTERNET permission"]
        direction TB
        MF --> R["Resolver<br/>one pure function of the clock"]
        R --> S["Schedules<br/>Work · Public · Private · Relax"]
        R --> P["Protection<br/>2-hour user-activated layer"]
        R --> G["Gate<br/>notification when a watched app opens"]
        G -.->|"Close app · Continue"| IG
    end

    M["Meta's ranking system<br/>opaque · no public API"] -.->|"we cannot touch this"| IG

    style M fill:#f0f0f0,stroke:#999,stroke-dasharray: 5 5
    style G fill:#e8f4ea,stroke:#2d7a46
```

Three things, in priority order:

1. **A schedule engine.** Profiles per day and hour, resolved from the clock. No stored state machine, so it cannot drift or desync.
2. **Emotional Protection.** One tap → two hours → conflict, breakup and anger content softened, then it switches itself off. *Never* romantic content: a rough evening is not a reason to remove affection. The user activates it; the app never infers a mood.
3. **A gate.** When Instagram comes to the foreground, a notification names the active profile and offers to close the app. One deliberate tap to override. That is the entire enforcement mechanism, stated plainly.

### Where this sits

```mermaid
quadrantChart
    title Escaping the platform's permission
    x-axis "Needs Meta's cooperation" --> "Works from outside"
    y-axis "Passive information" --> "Intervenes at the moment"
    quadrant-1 "Our space"
    quadrant-2 "Unavailable"
    quadrant-3 "Meta's own feature"
    quadrant-4 "Reminder apps"
    "MoodFeed": [0.86, 0.82]
    "Meta Your Algorithm": [0.18, 0.32]
    "In-app Show less": [0.55, 0.18]
    "Screen-time limiters": [0.88, 0.24]
    "Overlay blockers": [0.62, 0.78]
```

The top-right quadrant is nearly empty for one reason: intervening at the moment, from outside the app, is the hard combination. It is also the only combination worth building.

---

## 4. The honest ceiling

This must be said in the product, not just the docs. Without it, everything above reads as a promise we cannot keep.

```mermaid
flowchart TD
    L1["Change Meta's ranking directly"] --> X1["Impossible<br/>no public API"]
    L2["Read the screen of another app"] --> X2["AccessibilityService<br/>Play policy ban risk"]
    L3["Draw over Instagram"] --> X3["Blocked or fragile<br/>breaks on every UI update"]
    L4["Know Instagram was opened"] --> Y4["Possible<br/>Usage Access · same API as Digital Wellbeing"]
    L5["Remind, and offer to close"] --> Y5["Possible<br/>notification + our own app"]
    L6["Hold your rules and the clock"] --> Y6["Trivial<br/>and entirely ours"]

    style X1 fill:#fde8e8,stroke:#c0392b
    style X2 fill:#fde8e8,stroke:#c0392b
    style X3 fill:#fde8e8,stroke:#c0392b
    style Y4 fill:#e8f4ea,stroke:#2d7a46
    style Y5 fill:#e8f4ea,stroke:#2d7a46
    style Y6 fill:#e8f4ea,stroke:#2d7a46
```

**The product is a controller you can dismiss.** It costs the user one tap. Anyone promising more from outside Instagram is either using a policy-violating API or lying.

---

## 5. The bet, and how it dies

The bet is not "people want different reels at different times." It is that **a user will accept one small friction at the open of an app in exchange for not being defined by their worst evening.**

Three ways this fails, with the number that proves it:

| Failure | Signal | Response |
|---|---|---|
| Nobody cares about schedules | <40% still scheduling at week 4 | The schedule was never the value; protection is. Cut it. |
| The gate is ignored | honour rate <30% | It is a reminder app. Price and position it as one. |
| Only works for the anxious 5% | retention concentrated in a tiny cohort | Narrow the product instead of broadening the audience. |

```mermaid
flowchart LR
    A["Phase 1<br/>30-50 users · APK"] --> B{"week 4:<br/>40% scheduling?"}
    B -->|no| C["Cut scheduling<br/>protection-only product"]
    B -->|yes| D{"honour rate<br/>30%?"}
    D -->|no| E["Reminder app<br/>no classifier investment"]
    D -->|yes| F["Phase 3<br/>on-device classifier"]
    style F fill:#e8f4ea,stroke:#2d7a46
```

The classifier — the AI everyone assumes is the product — is deliberately **last**, because it is the most expensive way to learn whether anyone wants this.

---

## 6. What we are not building

Stated so it cannot creep back in:

- **Not another feed.** No content of our own, no creator ecosystem, no algorithmic discovery.
- **Not a parental control product.** Different buyer, different consent surface.
- **Not a moral filter.** Categories are user-chosen labels. Romantic and suggestive content are absent from protection entirely, so the app cannot be read as judging them.
- **Not a diagnosis.** The app never concludes you are struggling. It never activates protection for you.
- **Not a data business.** No `INTERNET` permission in the manifest is a claim you can verify, not a policy you have to trust.

---

## 7. The one sentence

> People should be able to decide what kind of digital environment they enter, without being permanently defined by their previous scrolling.

That is the problem. Everything in the spec is the smallest thing that serves it.

---

*Sources cited in the original brief: Meta Engineering, "Your Algorithm" architecture (Nov 2026); Meta, "Your Algorithm, Your Words"; Meta AI, unconnected recommendations; Google Play, AccessibilityService policy; Apple, Screen Time frameworks.*
