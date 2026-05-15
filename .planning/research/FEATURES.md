# Feature Landscape: Family Score

**Domain:** Family activity tracking / time equity visualization / gamified household management
**Researched:** 2026-05-15
**Research confidence:** HIGH (multiple competitive apps analyzed, App Store reviews, UX research verified)

---

## Research Basis

Apps studied: OurHome, Sweepy, Tody, Habitica, Homsy, Chorly, Chorsee, KidKarma, Chores (getchores.app), FairShare Family Planner, Household Fair Share, Mental Marbles, Evenus.

---

## Table Stakes

Features users expect. Missing = app feels incomplete or unprofessional.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Activity/task logging — log who did what | Core premise of all tracking apps. Users abandon without it. | Low | Must be < 3 taps. Speed matters more than completeness. |
| Point / score system | OurHome, Sweepy, Tody all use it. Users expect numeric acknowledgment. | Low | Points need to be visually prominent, not buried. |
| Multiple family member profiles | Every competing app supports this. Single-user = personal diary, not family app. | Medium | Parents create; children inherit. Role hierarchy matters. |
| Recurring / scheduled activities | One-off logging creates friction. Set-and-forget is expected. | Medium | Daily, weekly, custom cadence. |
| Cross-device sync | All modern family apps sync. Non-sync = unusable for families on separate devices. | Medium | Real-time preferred; offline-first with eventual sync acceptable. |
| Today / this week view | Immediate "what needs doing" overview. Tody and Sweepy make this central. | Low | The home screen of the app. Should be glanceable in < 2 seconds. |
| Completion confirmation | Marking done + visual feedback. Dopamine hit is part of the loop. | Low | Animation on completion is expected (not optional). |
| Per-person score totals | Leaderboard-lite: who has contributed most. Homsy, Tody, Sweepy all have it. | Low | Weekly / monthly view prevents burnout from permanent rankings. |
| Push notifications / reminders | 37% of BusyKid reviewers cited "forgotten tasks" as primary frustration. | Medium | Must be intelligent — not nagging. One well-timed reminder beats five bad ones. |
| Offline functionality | Families use apps during camping, travel, connectivity outage. | Medium | Local SQLite + background sync. Not optional for daily-driver apps. |
| History / activity log | "Who did what last week?" is a common question that causes family tension. | Low | Scrollable log, filterable by person. |
| Parental approval / verification | Chore quality control. All child-facing apps include this. | Medium | Photo proof is a differentiator (see below); binary yes/no is table stakes. |

---

## Differentiators

Features that make the app stand out. Not universally expected, but create clear preference when present.

### Time Equity Visualization — Core Differentiator

**What:** Track not just task count or points, but time invested — hours spent on duty (chores, errands, work, school) vs. free time per family member. Surface who is carrying disproportionate load.

**Why valuable:**
- No competing app tracks time equity across hobby hours, errands, AND household tasks as one unified view. Tody's 2025 FairShare update is the closest, but limited to cleaning.
- The "mental load" / invisible work problem (63% of women report doing more than their fair share per 2025 Journal of Marriage and Family data) is unsolved by current apps.
- A neutral, data-driven view eliminates emotional arguments about fairness.

**Complexity:** High
**Dependencies:** Activity logging, per-person profiles, time-tagging on activities

| Sub-feature | Description | Complexity |
|-------------|-------------|------------|
| Time-tagged activity logging | Log duration, not just completion | Low — add duration field |
| Free time vs. duty time ratio | Ring or bar showing daily/weekly balance | Medium — derived metric |
| Equity dashboard | Who has how much free time vs. duty time, per day/week/month | High — visualization layer |
| "Fairness gap" alert | Passive notification when one member consistently carries more | Medium — threshold logic |

---

### Apple Health-Style Ring Visualization

**What:** Circular progress rings per family member, per day — showing duty-time filled vs. daily target, similar to Move/Exercise/Stand rings. Closes when goal met.

**Why valuable:**
- Instantly understood by any iPhone user. Zero learning curve.
- Ring closure is psychologically satisfying — drives intrinsic motivation (completion-based, not fear-based).
- Works perfectly as a Lock Screen and Home Screen widget: one glance shows entire family status.
- No family app uses this pattern. Everyone uses bars and leaderboards.

**Complexity:** Medium (SwiftUI ring drawing is straightforward; data modeling is the complexity)
**Dependencies:** Time-tagged activity logging, per-person profiles, daily targets

---

### Lock Screen Widget — Score Ring

**What:** Compact circular widget on iOS lock screen showing today's score or ring completion for one family member (or the family aggregate). Updates in background.

**Why valuable:**
- The single highest-visibility surface on iPhone. 
- Competing apps (OurHome, Sweepy, Tody) do not offer lock screen widgets as a core feature — this is a clear gap.
- Daily active use increases dramatically when users see their score without opening the app.
- iOS 26 introduces glass-style widget rendering — visual differentiation opportunity.

**Complexity:** Medium (WidgetKit, accessoryCircular family)
**Dependencies:** Core score system, WidgetKit integration

---

### Home Screen Widget — Family Status Row

**What:** Medium or large widget showing all family members' scores/rings for today. Parent sees the whole family at a glance.

**Why valuable:**
- Parents' primary anxiety: "Is everyone doing their part?" This answers it without opening the app.
- No family chore app treats this as a first-class feature.
- Drives passive awareness and accountability without requiring active engagement.

**Complexity:** Medium
**Dependencies:** Multi-member profiles, today's score data, WidgetKit

---

### Progressive Child Interface

**What:** The app grows with the child. Three distinct modes on the same account:
1. **Parent-managed** (age 5-8): Parent logs everything. Child only sees rewards and score.
2. **Child-assisted** (age 9-13): Simplified UI — big buttons, emoji, tap to mark done. No complexity exposed.
3. **Teen/adult** (age 14+): Full interface. Sees time equity view, history, own schedule.

**Why valuable:**
- No competing app implements this "growing into the app" concept.
- Most child apps are locked to a juvenile interface that teens abandon.
- Family Score becomes a long-term family tool, not something kids age out of.

**Complexity:** High (requires role system, per-member UI mode, mode transition logic)
**Dependencies:** Role hierarchy, per-person profiles, parental controls

---

### Activity Categories Beyond Chores

**What:** Track multiple life domains, not just household tasks:
- Household (cleaning, cooking, shopping)
- Hobby hours (sports, music, crafts)
- Errands (banking, appointments, logistics)
- Work / school (professional hours, homework, study)
- Care work (childcare, eldercare, vet runs)

**Why valuable:**
- The unique positioning: this is a TIME EQUITY tracker, not a chore app.
- Hobby hours matter for fairness: if one parent gets 5 hours of golf but the other gets 0 free time, that's a fairness issue.
- Nearest competitor is Tody (FairShare) but it's cleaning-only.

**Complexity:** Low (just category taxonomy on activity type)
**Dependencies:** Activity logging

---

### Photo Proof for Task Completion

**What:** Child (or any member) attaches a photo when marking a task done. Parent reviews and approves or rejects.

**Why valuable:**
- Chorly includes this; Chorsee does not. Users specifically mention it in reviews of Chorly.
- Prevents "I did it" without evidence — common family friction point.
- Doesn't require surveillance — it's invitation-based quality confirmation.

**Complexity:** Medium (camera access, photo storage, approval workflow)
**Dependencies:** Task logging, parental approval system, storage (Supabase Storage)

---

### Streak System With Grace Periods

**What:** Consecutive-day completion streaks with built-in forgiveness mechanics — a missed day pauses rather than resets.

**Why valuable:**
- Streaks increase daily active use by an average of 22% (Smashing Magazine, 2026 data).
- Hard resets are the single biggest cause of streak-based abandonment (Duolingo learned this and added freezes).
- Grace period (24-48 hour window or one "freeze" per month) maintains engagement through real life.

**Complexity:** Low-Medium (state machine for streak logic)
**Dependencies:** Daily completion tracking

---

### Reward Redemption System (Child-Facing)

**What:** Children accumulate points and redeem them for family-defined rewards (screen time, special activity, allowance cash equivalent). Parents set reward catalog and prices.

**Why valuable:**
- OurHome does this well and gets praise for it.
- Creates intrinsic motivation loop: effort → points → visible reward → effort again.
- Better than monetary allowance integration (see Anti-Features) — stays in-app.

**Complexity:** Medium (reward catalog CRUD, redemption request/approval flow)
**Dependencies:** Point system, parental approval, per-child profiles

---

### Monthly/Period Review

**What:** End-of-month summary: who did the most, biggest contributor by category, family score trend, equity gap over time.

**Why valuable:**
- Tody's FairShare update (2025) introduced period review and it became a key feature cited in reviews.
- Makes the data actionable — families can reallocate tasks based on visible patterns.
- Low-effort insight: data is already collected, presentation is the feature.

**Complexity:** Low (aggregate queries + report view)
**Dependencies:** History log, time-tagged activities

---

### Rotation / Auto-Assignment

**What:** Chores that automatically rotate between eligible members each cycle.

**Why valuable:**
- OurHome supports this and users specifically praise it.
- Removes cognitive load of deciding who does what each week.
- Critical for fairness — prevents the same person always getting the worst tasks.

**Complexity:** Medium (rotation algorithm, eligibility rules)
**Dependencies:** Task scheduling, multi-member profiles

---

## Anti-Features

Features to deliberately NOT build. Each has a documented reason.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| In-app messaging / chat | OurHome includes it; users ignore it. Every family already has Messages/WhatsApp. Adds complexity with zero unique value. | Use system notifications for relevant events. |
| Grocery list | Tody, OurHome, Cozi all have it. Users switch to Reminders or AnyList anyway. Dilutes focus. | Explicitly out of scope. Refer users to native Reminders. |
| Family calendar | Cozi and Homsy offer this. Competes with Apple Calendar and Google Calendar which families already use. | Focus on activity logging, not scheduling other life events. |
| Real-money allowance integration | Banking integrations (BusyKid, Greenlight) are their own category. Complex, compliance-heavy, breaks easily. | Points-to-rewards stays in-app. No real money. |
| AI task suggestions | Users distrust AI-generated chore lists. Feels impersonal. Leads to "AI slop" — lists that don't reflect actual family life. | Curated category templates, user-defined tasks. |
| Complex RPG / avatar system | Habitica's RPG layer confuses non-gamers and gets in the way of simple tracking. "Games within games" create friction. | Simple visual score rings and streaks. No avatars, no character classes. |
| Social sharing / external leaderboards | Family data is private. Sharing outside the family creates anxiety. Habitica's community created safety issues. | Keep all data strictly within the family group. |
| Meal planning | Out of scope. Apps that add meal planning (Fami, Cozi) become cluttered and users abandon premium features. | Single-purpose focus. |
| Homework / school grade tracking | Separate category. Apps like Joon do this for ADHD kids. Different audience and use case. | Out of scope for initial versions. |
| Feature-gated free tier | Research shows aggressive paywalls are the #1 complaint across Sweepy, Tody, and Chorsee. | Generous free tier; charge for multi-device sync or advanced analytics. |
| Mandatory setup wizard with 50+ tasks | Both Sweepy and Tody reviews cite "entering too many tasks" as the #1 onboarding failure causing app abandonment by day 4. | Onboard with 3 suggested tasks. Add more gradually. |
| Hard streak resets | Single biggest cause of habit-app abandonment. Psychological research confirms loss aversion causes users to abandon rather than restart. | Grace periods, streak freezes, decay model. |
| Surveillance-heavy monitoring | KidKarma comparison noted "surveillance-heavy" features feel invasive and damage parent-child trust. | Photo proof is invitation-based, not forced. |

---

## Feature Dependencies

```
Multi-member profiles
  → Cross-device sync (Supabase Realtime)
  → Per-person score totals
  → Parental approval system
    → Photo proof
    → Reward redemption

Activity logging (with duration)
  → Point system
    → Streak system (with grace periods)
    → Reward redemption system
    → Per-person score totals
  → Time equity calculations
    → Free time vs. duty time ratio
    → Equity dashboard
    → Monthly/period review
    → Fairness gap alerts

Activity categories (chores / hobby / errands / work / care)
  → Time equity visualization
  → Ring visualization (per category or aggregate)

Ring visualization (aggregate per person per day)
  → Lock Screen Widget (accessoryCircular)
  → Home Screen Widget (medium — family status row)

Progressive child interface
  → Role hierarchy (parent / child-assisted / teen)
  → Per-member UI mode flag
  → Parental controls (disable features per child)

Task scheduling (recurring)
  → Rotation / auto-assignment
  → Reminders / push notifications
  → History log (who did what, when)
```

---

## Gamification Loop Analysis

Sourced from Habitica case study (Trophy.so), Sweepy mechanics, Smashing Magazine streak psychology research.

### What Works

1. **Immediate feedback on completion** — points awarded the moment task is marked done, with animation. Delay kills motivation.
2. **Visible daily progress** — rings filling, bars progressing. Glanceable from lock screen.
3. **Consequence without punishment** — ring doesn't close = obvious, but no harsh reset. Shame spiral (Sweepy's documented ADHD problem with red bars) must be avoided.
4. **Social accountability within family** — seeing family members' rings creates motivation without external competition or public exposure.
5. **Milestone celebrations** — day 7, 30, 100 streaks deserve animation and acknowledgment. Reignites motivation.
6. **Low floor, high ceiling** — completing even one small task should move the ring visibly. Apple's "stand for 1 minute" philosophy: even bad days should show progress.

### What Fails

1. **RPG complexity layered on top** — Habitica's character classes, guild systems, and quests confuse users who just want to track chores. Feature bloat destroys core value.
2. **External rewards (real money)** — Disconnects effort from intrinsic satisfaction. Creates entitlement rather than habit.
3. **Fear-based streaks** — When streak loss creates anxiety more than streak building creates joy, users abandon.
4. **Points without meaning** — Points that can't be redeemed for anything concrete lose motivating power within 2 weeks (Chorsee's position: gamification is a "false motivator").
5. **Leaderboard competition between adults** — Works for children; creates resentment between partners who have different availability.

### The Right Loop for Family Score

```
Log activity (< 3 taps)
  → Points awarded immediately (animation)
  → Ring fills (visible on lock screen widget)
  → Daily ring closes (celebration animation)
  → Streak counter increments
  → Weekly family summary (who did most, equity view)
  → Monthly review (trend, reallocation prompt)
  → Points redeemed for child rewards (parent approves)
```

Adults see: ring, equity dashboard, history.
Children see: ring, stars/points, reward store.

---

## Apple Health Rings — Lessons for Family Score

Apple's Activity Rings are the gold standard for habit visualization on iOS. Key lessons:

1. **Three rings maximum** — Move, Exercise, Stand. Not six. Not ten. Three things users can internalize. Family Score equivalent: Duty, Free, Balance (or similar three-concept model).
2. **Color = identity** — Each ring has a consistent color. Each family member should have a persistent assigned color throughout the app. Their ring IS their color.
3. **Glanceable completion state** — Open ring (in progress), closed ring (goal met), ring-past-360 (overachieved). Three states only.
4. **Works with nothing** — Lock screen widget shows ring without opening app. The most important interaction should require zero taps.
5. **Goal is adjustable** — Apple lets users change Move goal. Family Score daily targets should be adjustable per member (a 10-year-old and an adult parent have different baselines).
6. **Sharing is optional** — Apple Watch allows ring sharing with specific people. Family Score shares within the family group only, never outside.
7. **No number unless asked** — Ring communicates ratio visually; tap to see actual hours. Progressive disclosure.

---

## Market Gaps — What Nobody Does Well

Confirmed by competitive research across 10+ apps:

1. **Time equity across ALL life domains** — No app tracks hobby hours, errands, care work, AND chores in one unified equity view. Tody FairShare is cleaning-only. This is the core gap Family Score fills.

2. **Progressive child UI** — Apps are either adult-UX (confusing for kids) or kid-UX (abandoned by teens). No app grows with the child.

3. **Lock screen widget as primary surface** — Every app treats widgets as an afterthought. Family Score should design the lock screen widget first and the app second.

4. **Fair distribution that accounts for time, not just task count** — Counting tasks is wrong. Doing 3 long tasks may be more than doing 10 quick ones. Time-based points (e.g., 1 point per 10 minutes) is more accurate.

5. **Adult fairness without gamification theatrics** — Adults want data and equity; they don't want RPG avatars. No app serves adults without either being a to-do list (no gamification) or an RPG (too much gamification).

---

## MVP Feature Priority

**Must have at launch (MVP):**
1. Activity logging — with duration and category (< 3 taps)
2. Per-person profiles — up to 6 family members
3. Point system — time-based (minutes → points)
4. Ring visualization — per person, per day
5. Cross-device sync (Supabase Realtime)
6. Lock screen widget (accessoryCircular, one ring)
7. Today view — family at a glance
8. History log — last 30 days

**Second release (post-MVP differentiators):**
9. Time equity dashboard
10. Home screen widget (family status row)
11. Streak system with grace periods
12. Recurring activities + rotation
13. Progressive child interface (mode 2: child-assisted)
14. Monthly review / period summary

**Defer (Phase 3+):**
15. Reward redemption system
16. Photo proof for tasks
17. Fairness gap alerts
18. Teen/adult mode (mode 3 of progressive interface)
19. Parental approval workflow

---

## Sources

- OurHome App Store reviews: https://apps.apple.com/us/app/ourhome-by-elusios/id6753957205
- OurHome review (Daeken): https://www.daeken.com/blog/ourhome-app-review/
- Sweepy review (Tidied): https://www.tidied.app/blog/sweepy-app-review
- Tody review (Tidied): https://www.tidied.app/blog/tody-app-review
- Habitica gamification case study (Trophy): https://trophy.so/blog/habitica-gamification-case-study
- Streak UX psychology (Smashing Magazine): https://www.smashingmagazine.com/2026/02/designing-streak-system-ux-psychology/
- Best chore apps comparison (KidKarma): https://kidkarma.app/compare/best-chore-apps/
- Best chore chart apps 2026 (Homsy): https://gethomsy.com/blog/comparisons/best-chore-chart-apps-2026
- Best free chore apps 2025 (MyChoreBoard): https://www.mychoreboard.com/blog/best-free-chore-apps-2025/
- Best chore apps for families 2025 (KiddiKash): https://www.kiddikash.com/blog/best-chore-apps-2025
- Chores app (getchores.app): https://getchores.app/
- Time equity / mental load research: https://www.tidied.app/blog/best-chore-apps-couples
- Apple Activity Rings HIG: https://developer.apple.com/design/human-interface-guidelines/activity-rings
- iOS WidgetKit (WWDC 2025): https://dev.to/arshtechpro/wwdc-2025-widgetkit-in-ios-26-a-complete-guide-to-modern-widget-development-1cjp
- Family chore app anti-patterns: https://www.mychoreboard.com/blog/best-free-chore-apps-2025/
