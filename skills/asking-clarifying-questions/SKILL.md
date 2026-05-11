---
name: asking-clarifying-questions
description: "Ask the user only what only they can answer. Read memory files, lockfiles, and existing code to resolve self-resolvable ambiguities first. Batch 1-3 user-owned questions per round, never barrage. Restate understanding before locking it in. Apply in Analyst's clarification phase (any mode) and any time an agent needs scope/intent/acceptance information from the user."
---

# Asking Clarifying Questions

User dialog is expensive: each round costs minutes of human time and patience. Treat their attention as a precious resource. Ask only what only they can answer; resolve everything else yourself.

## When to use

- Analyst's clarification phase (after brainstorming, or solo in fast/live-feature mode)
- Any time you genuinely need information that isn't in the codebase, memory, or your own reasoning
- Before locking down requirements in `analyst.md`

NOT when:

- You can find the answer in `memory/project.md`, `memory/patterns.md`, lockfiles, or 30 seconds of Glob/Grep
- The question is about implementation detail (architecture is the Architect's job)
- You can make a reasonable default and surface it for confirmation later (e.g., "I'll assume p99 < 200ms unless you say otherwise")

## The two categories

### Category 1: USER OWNS THIS — must ask

These are decisions only the user can make. Examples:

- **Scope** — "Is this single-user or multi-user? Should it support batch import?"
- **Acceptance criteria** — "What does done look like? p95 latency target? Error rate threshold?"
- **Trade-off priorities** — "Performance vs readability here?"
- **Edge case behavior** — "What should happen when input X is provided?"
- **External dependencies** — "Do we integrate with system Y? What auth does it use?"
- **Data model semantics** — "Is email unique per user, or globally? Case-sensitive?"
- **UX choices** — "Show error inline or via modal?"

### Category 2: YOU CAN RESOLVE — don't ask

These are answerable from project state. Examples:

| Question | How to resolve |
|----------|----------------|
| "Which test framework?" | Read `package.json` / `requirements.txt` / etc. |
| "What's the naming convention?" | Read 2-3 existing source files |
| "Which logging library?" | Read `memory/patterns.md`, then existing log statements |
| "Where do auth tests live?" | Glob for `*auth*test*` |
| "What's the build command?" | Read `package.json` scripts, or `Makefile`, or `README.md` |
| "What Node version?" | Read `.nvmrc`, `engines` in `package.json`, or CI config |

Gate function before any question: **"Can I answer this myself by reading something accessible in 30 seconds?"** If yes, do it.

## How to ask

### Use AskUserQuestion for structured choices

When you have a specific set of options:

```
Question: "How should authentication failures be handled?"
Options: [Show error to user] / [Redirect to login] / [Silent retry once, then error]
```

Better than open-ended because user picks fast; you get a clean signal.

### Use plain prose for open-ended

When the answer space isn't enumerable:

```
"What's the maximum file size we need to support?"
```

No options menu — they type a number.

### Pacing: ≤3 questions per round

A single batch contains AT MOST 3 questions, and only if they're genuinely independent. Examples:

**Good (3 independent):**

1. "What's the max file size we need to support?"
2. "Should uploads be public or private by default?"
3. "What happens if upload exceeds quota — block, or queue?"

**Bad (5+ questions, some dependent):**

1. "What database?"
2. "Should we cache?"
3. "What cache TTL?" (depends on #2)
4. "Where should logs go?"
5. "What's the log level?" (depends on #4)
6. "How should we monitor?"

The bad version: ask 1, 2, 4 in round one. If 2 is "yes", ask 3 in round two.

## Rounds budget

- **1 round** — typical
- **2 rounds** — fine when user's first answers reveal a follow-up
- **3 rounds** — borderline; user is probably tired
- **4+ rounds** — you're over-asking, OR the task is genuinely too vague (escalate, don't keep asking)

When you hit 3 rounds without locking down, stop. Either:

- Make defaults and tell the user ("Going with X, Y, Z unless you say otherwise — confirm or push back")
- Escalate ("Task as stated is too open-ended for me to nail down; can you give me the original problem and we'll re-scope?")

## Restating: the final validation

Before writing `analyst.md` and reporting DONE, restate your understanding:

```
"OK, to confirm: you want X that does Y, with Z constraint. Scope includes A and B, explicitly skips C. Acceptance: [criteria]. Yes?"
```

Why this matters:

- Catches misunderstandings before they propagate
- Cheap: 30 seconds of user time
- Massively cheaper than catching at Architect or Developer stage

If user corrects you, integrate and restate again (one more time, briefly). Then write.

## Examples of question quality

**Bad question (vague):**

> "What kind of authentication do you want?"

User's likely reaction: confusion. Authentication has many dimensions.

**Better (specific dimension):**

> "Should authentication be username/password, or do we delegate to an OAuth provider (Google/GitHub/etc.)?"

User can answer.

**Bad question (you should have read the codebase):**

> "Should I use Vitest or Jest?"

If the project already uses one, you should have read it. Don't ask.

**Better (genuinely open):**

> "I see the project uses Vitest. Should the new module follow that convention, or is there a reason to introduce a different framework?"

Confirms reading happened, surfaces only the genuinely open part.

**Bad question (implementation detail):**

> "Should I use a `Map` or an `Object` for the cache?"

Architecture, not requirements. Don't ask user.

**Better (requirement):**

> "Roughly how many entries do you expect in the cache at peak? (affects whether we need to bound it)"

A capacity requirement is something the user can answer; implementation choice follows from that.

## Anti-patterns

- **Question barrage** — 5+ questions in one go. User gives lazy answers and you've burned trust.
- **Asking what's in the lockfile** — "What language?" with `package.json` in front of you. Read first.
- **Vague questions** — "What do you want?" Be specific.
- **Implementation questions** — "Should I use library X?" That's HOW, not WHAT. User picks WHAT.
- **Asking for design choices the brainstorming step covered** — if user picked Option A, don't re-ask "what direction?"
- **Skipping restating** — costs nothing, prevents days of wrong work.
- **Asking yes/no when option-list is better** — "Should it be fast?" is a yes (trivial). "What's the p95 latency target — 100ms / 250ms / 500ms / 1s?" gets a useful answer.
- **Asking everything upfront** — when first answers will inform what to ask next, ask in rounds, not all at once.

## Quick reference

Before each potential question, gate:

- [ ] Have I read memory files and obvious project artifacts?
- [ ] Is this something only the user can answer (scope, acceptance, priorities, edge cases)?
- [ ] Is it specific enough that they can answer in <30 seconds?
- [ ] Am I keeping batch to ≤3 questions?

Before reporting DONE:

- [ ] Restated my understanding back to user
- [ ] User confirmed (or corrected and re-confirmed)
