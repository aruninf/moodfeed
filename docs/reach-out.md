# Reaching out

Practical, in order of what actually returns something. Nothing here asks Meta for permission — it makes the idea findable and puts a phone in 30 people's hands.

**Read this first:** you have a design, not an app. Do not launch. Recruit testers. A launch of a design doc produces likes; a tester list produces a product.

---

## 0. The one sentence

> Your feed doesn't know what kind of day you're having.

Use it everywhere, unchanged. Every draft below starts from it.

---

## 1. GitHub search visibility (5 minutes, done)

Topics and description are set. What's left is the repo being genuinely readable: name the problem in the first line of the README — which it now does.

Nothing else on GitHub matters until there's code.

---

## 2. Threads / X — the Meta-facing post

Post on **Threads** (Meta's own platform — the only place their employees actually read replies) and mirror to X. No tagging, no hashtags, no mention of Meta by name.

```
Your feed doesn't know what kind of day you're having.

One bad evening. One angry relationship reel watched to the end.
Watch time is engagement. Engagement is "interest". The ranker
learns conflict — and serves it for weeks.

Not because Meta is malicious. Because attention is measurable
and intent isn't.

So I'm building the missing layer: profiles that switch with the
clock (work, public, private), and a 2-hour "protecting my peace"
mode for the evenings that need one. Conflict, breakup, anger
softened. Romantic content never touched — a rough night isn't a
reason to remove affection. You activate it. It never guesses.

Honest about the ceiling: it cannot change Meta's ranking. Nothing
outside Instagram can. What it does is hold your rules, know the
time, and ask once when you open the app.

Android, local-only, no INTERNET permission, no account. Design
and repo in the reply. Looking for ~30 testers.
```

Rules: one post, no thread-of-twelve, no "thoughts?" Reply to people who reply. Post Tue–Thu, 8–10pm your local time — that's when this idea lands on the people it's about.

---

## 3. LinkedIn — the professional angle

Same story, different argument: this is a product-design critique of ranking systems, not a personal post.

```
Recommendation systems optimise for engagement. Engagement is
observable. Intent is not. So a system learns what holds your
attention and treats a bad evening as a preference.

Meta's "Your Algorithm" is a real step — natural-language
preferences. But it answers "what do you want?", not "what do
you want right now?".

I'm building the second question: time-scoped content profiles
plus a user-activated protection mode that expires on its own.
Deliberately not a feed, not a filter, and not a claim that
anyone can rewrite Meta's ranking from outside.

The constraint that makes it interesting is the design
constraint: a third-party app can detect that Instagram opened,
and can ask once. That's it. Everything else is policy-violating
or impossible. Designing inside that box is the whole exercise.

Repo and design doc in comments. Looking for Android testers and
for anyone who has shipped something against Android's Usage
Access restrictions.
```

---

## 4. Show HN — the technical angle

HN rewards stating limitations before anyone can attack you with them.

```
Show HN: MoodFeed – time-based content rules for Instagram, from outside

Your feed optimises for what holds your attention, not what you
wanted to pay attention to. One bad evening of watching conflict
reels trains weeks of recommendations.

MoodFeed is an Android app that keeps content profiles on a weekly
schedule (work / public / private / relax) and lets you activate a
2-hour protection layer over them. When Instagram comes to the
foreground, it raises a notification naming the active profile
with a "close app" action.

What it deliberately does not do, because people will assume it:
- Does not read the screen. AccessibilityService scraping is a
  Play ban and I'm not shipping that.
- Does not draw over Instagram.
- Does not change Meta's ranking. There is no public API for that;
  anything claiming otherwise is lying or policy-violating.
- Is not an AI classifier yet. The taxonomy exists so a model has
  somewhere to land later, gated on 85% precision.

The interesting engineering bit is small: the active state is a
pure function of the clock, never stored, so it can't desync.
The gate is an opt-in foreground service polling UsageStatsManager
every 5s with a 90-minute cooldown per app — because that API is a
log, not an event stream, and WorkManager's 15-minute floor can't
see an app open.

Design doc states the honest ceiling: it's a controller you can
dismiss with one tap. I'd rather ship that and be trusted than
promise filtering I can't do.

Repo (design phase, no code yet) in comments. Would especially
value critique from anyone who has shipped against Usage Access or
fg-service restrictions on Android 14+.
```

Title discipline: no "revolutionary", no emoji, no "Ask HN" double-post. Post 8–10am ET on a weekday.

---

## 5. Direct outreach — the five emails that matter

Not Meta. People who write about this for a living, and who would rather cover a working APK than a manifesto.

| Target type | Why | What to send |
|---|---|---|
| Android newsletters (Android Weekly, r/androidapps moderators) | They cover exactly this class of app | 3-sentence pitch + repo + "APK in 3 weeks" |
| Digital-wellbeing writers (newsletters, Guardian/TechCrunch wellbeing beats) | Already writing about Your Algorithm | The bad-evening story + the honest ceiling |
| Flutter community (Flutter Weekly, r/FlutterDev) | The build story is genuinely interesting (one resolver, fg isolate) | Technical angle, not the wellbeing angle |
| Privacy-focused newsletters | "No INTERNET permission" is a verifiable claim | One line: no INTERNET, no account, no analytics |
| One mental-health professional | Validates the ethics section, kills the "diagnosis app" read | The rules in §5.6 of the design, not the features |

Template — keep it under 90 words, no attachments, one link:

```
Subject: A 2-hour "protect my peace" layer for Instagram (Android)

Hi <name>,

You wrote about <specific piece>. The question I keep hitting is the
one it doesn't answer: the feed knows what you engage with, not what
you wanted that evening.

I'm building a small Android app for exactly that — scheduled content
profiles plus a user-activated 2-hour mode. No account, no INTERNET
permission, and it doesn't pretend to change Meta's ranking.

Design doc: <one link>. If it's useful as a hook for a piece, I'll
send you an APK before it's public.

<name>
```

No follow-up before 10 days. One follow-up, then drop it.

---

## 6. If you specifically want Meta to see it

Do not email them. Do not DM employees a pitch. The only route that has ever worked from outside is **a public post that earns engagement and then gets forwarded internally**, usually by a journalist asking them to comment.

If a writer picks it up, the question they'll put to Meta is *"is this something Your Algorithm should handle?"* — and that is exactly the conversation you want, with your name attached and your repo as the record.

That is the whole plan. It costs you nothing and cannot be misread as an unsolicited submission.

---

## 7. Sequence

| Week | Do | Success looks like |
|---|---|---|
| 1 | Threads/X post + LinkedIn post | 10 people say "I'd use that" |
| 2 | Flutter scaffold → resolver + test → ugly working home screen | It runs on your phone |
| 3 | Gate working → signed APK | 5 testers install it |
| 4 | Show HN + the five emails, with a real APK | 30 tester signups |
| 5–8 | Nothing but support and watching the honour rate | Retention number, not applause |

Ship the APK *before* Show HN. The most common failure here is posting the story and having nothing to install.

---

## 8. What not to do

- Don't say "Meta copied my idea" — the design doc says they already shipped the adjacent feature. Being right about the problem is a stronger position than being aggrieved.
- Don't post in five places the same day. You'll be in five comment sections at once and answer none of them.
- Don't ask for "feedback". Ask for one install. Feedback is free; installs are information.
- Don't use the word "AI" in the launch copy. You don't have one, and it invites the exact scepticism the design doc works hard to pre-empt.
- Don't pitch this as a mental-health product. It's a boundary tool. The difference is a regulatory one.
