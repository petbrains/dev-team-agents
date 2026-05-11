---
name: brainstorming
description: "Before specifying a feature's details, generate 2-3 genuinely different approaches that solve the goal — vary on real axes (scope, architecture, tech, UX), capture trade-offs for each, present to user for direction selection. Apply for greenfield projects and feature-full pipelines, before clarification phase. Skip for fast-track features, bugs (use Debugger instead), refactors (Architect goes direct), and trivial tasks."
---

# Brainstorming

Generate 2-3 directions before locking into one. The user owns the direction choice; you provide the options with honest trade-offs. This phase is BEFORE clarification — clarification refines a chosen direction; brainstorming chooses it.

## When to use

- Greenfield project, any feature
- Live project, feature task in FULL mode where the approach is not pre-specified
- Architect's planning shows the problem has genuinely different solution shapes

Skip when:

- User's request already specifies the approach ("build a REST API for X" — REST is chosen)
- Bug fix — root cause dictates the fix, not direction selection
- Refactor — the constraint is "no behavior change", so direction is structural
- Trivial task — no design choice exists
- Fast-mode feature — by user's choice, skip the ceremony

## The principle

Don't impose your favorite approach. Don't generate fake alternatives ("A, or A with a slight tweak") to look like you considered options. Either there are genuinely different ways to solve this, in which case present them honestly, or there aren't, in which case skip brainstorming and say so explicitly: "The request specifies the approach. Skipping brainstorming and moving to clarification."

## How to generate options

Step 1: identify the user's goal — NOT the solution they proposed, the outcome they want.

```
User says: "Build a CLI to manage my notes"
Goal: "I need a system to store and retrieve text notes efficiently"
```

The user's wording is CLI, but the goal admits other shapes: web app, mobile app, desktop app, browser extension. Brainstorming considers them.

Step 2: vary on real axes. Pick 1-2 axes that genuinely change the trade-offs:

| Axis | Examples |
|------|----------|
| **Scope** | Minimal core vs comprehensive solution |
| **Architecture** | Embedded library vs service vs microservice |
| **Tech stack** | Different languages/frameworks for greenfield |
| **Sync vs async** | Real-time vs queued/batched |
| **Client-side vs server-side** | Where state lives, where compute happens |
| **Manual vs automated** | User-driven vs scheduled vs event-driven |
| **UX shape** | CLI vs UI vs API vs interactive script |
| **Build vs reuse** | Custom code vs adopt existing library/service |

Step 3: for each option (2-3 of them), capture:

- **Core idea** — one sentence
- **Trade-offs** — what you gain, what you lose
- **Estimated complexity** — rough small / medium / large

Don't write code. Don't pick interfaces. Just the direction.

## How many options

**Two is the floor.** Single-option brainstorming is just "here's my plan, agree?" — not brainstorming.

**Three is the ceiling.** Four or more options causes paralysis and signals that you haven't narrowed enough.

If you can only think of one direction, that's information: the problem is constrained enough that brainstorming doesn't add value. Skip and explain.

## Example: real brainstorming

User: "I need to know when items in my project go out of stock"

Goal: be notified of stock changes for tracked items.

```markdown
**Option A — Polling script run by cron**
Periodic script checks the API/database for tracked items, logs/notifies if any went to zero.
- Gains: simple, no server infra, easy to reason about
- Loses: latency = polling interval (5-15 min typical); fires polls even when nothing changes
- Complexity: small

**Option B — Event-driven webhook**
Subscribe to inventory system's webhook; receive push notifications on stock changes.
- Gains: real-time, no wasted polls
- Loses: requires the inventory system to support webhooks (verify first); requires public endpoint or tunnel for local dev
- Complexity: medium (webhook handler + endpoint + auth)

**Option C — Embedded dashboard**
Web UI that queries inventory on demand; no notifications, user checks when curious.
- Gains: zero infrastructure for alerts; user controls timing
- Loses: not actually a notification system (changes the deliverable)
- Complexity: small-medium (UI work)
```

Then to user via AskUserQuestion: "Here are 3 directions. Trade-offs differ — which direction?" with these options.

## Example: bad brainstorming

```markdown
**Option A — Polling every 15 min**
**Option B — Polling every 5 min**
**Option C — Polling every 30 min**
```

These aren't directions. They're the same direction with a parameter. Bad.

```markdown
**Option A — Build it in Node**
**Option B — Build it in Python**
```

Tech stack is sometimes a real axis (when project doesn't already have an established stack), but if the project is already a Node project, this is fake variation. Don't.

## After user picks a direction

Once user chooses, brainstorming is DONE. Move to clarification (`asking-clarifying-questions` skill) to nail specifics within the chosen direction.

Record the chosen direction in `analyst.md` under `## Approach`:

```markdown
## Approach

**Chosen direction:** Polling script run by cron (Option A from brainstorming)
**Why:** User has no public endpoint and prefers minimal infra
**Approaches considered but not chosen:** Webhook (B — needs public endpoint, deferred), Dashboard (C — different deliverable)
```

The "not chosen" record matters: it documents that alternatives were considered honestly, and helps future readers understand why we are where we are.

## Anti-patterns

- **Five or more options.** Choice paralysis; user shrugs and you pick anyway. Cut to 2-3.
- **Fake variants** — same direction with a knob turned. Doesn't add value, signals padding.
- **Implementation details masquerading as direction** ("Option A: use library X; Option B: use library Y"). Library choice is downstream of direction. Direction is about shape.
- **Picking the option for the user.** They get to choose. Even if you have a recommendation (and you can mention it), present the options fairly and let them pick.
- **Skipping brainstorming for greenfield because "it's obvious".** Almost nothing in greenfield is actually obvious; what feels obvious is usually one solution from a family of viable ones.
- **Brainstorming for tasks where direction is pre-specified.** "Build a REST API for X" — REST is chosen. Don't generate "or a GraphQL API" if the user said REST. Move to clarification.
- **No trade-offs.** "Option A: do X. Option B: do Y." With nothing about what each gains or loses — user can't decide.

## Quick reference

1. Identify the user's actual goal (not their proposed solution)
2. Pick 1-2 axes of variation that genuinely change trade-offs
3. Generate 2-3 options (NOT 4+, NOT 1)
4. For each: one-sentence idea + trade-offs + rough complexity
5. Present via AskUserQuestion, wait for choice
6. Record chosen direction (and considered alternatives) in `analyst.md`
7. Move to clarification phase
