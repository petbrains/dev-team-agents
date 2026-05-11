---
name: condition-based-waiting
description: "Wait for a specific condition to become true (or false), not for a hardcoded duration. Apply when Orchestrator needs to wait for a Human gate response, an async subagent completion, or a state change in shared files. Avoids both premature continuation (race) and unnecessary sleep (waste). Adapted from claude-power-user."
---

# Condition-Based Waiting

When you need to wait, wait for the **thing** you actually need, not for a timer. Hardcoded sleeps are either too short (race conditions) or too long (wasted time). Polling a condition with a sensible interval handles both: you proceed as soon as it's ready, and you don't proceed until it's ready.

## When to use

- Orchestrator awaiting a Human gate response (user confirmation)
- Awaiting completion of an async operation (test run, build, deploy)
- Awaiting a shared-file state change (`.claude-team/current/*.md` from a subagent)
- Verifying an external system reached a state (DB row exists, file appeared, service responsive)

NOT when:

- You have a clear callback / promise — use that, not polling
- The thing is synchronous (the call returns when done — no waiting needed)
- The wait would exceed reasonable budgets (>5 min for most operations) — that's an architecture issue, not a waiting issue

## The principle

Hardcoded sleep:

```typescript
await runTests();
await sleep(5000);            // hope tests are done
await checkResults();         // might not be there yet — or might be done 4 sec ago
```

Condition-based:

```typescript
await runTests();
await waitFor(() => testsComplete(), { interval: 200, timeout: 60_000 });
await checkResults();         // definitely ready
```

Difference: condition-based proceeds immediately when ready, and won't proceed prematurely.

## Patterns

### Pattern 1: Poll a state check

```typescript
async function waitFor<T>(
    check: () => Promise<T | null>,
    options: { interval?: number; timeout?: number } = {}
): Promise<T> {
    const { interval = 200, timeout = 30_000 } = options;
    const start = Date.now();

    while (Date.now() - start < timeout) {
        const result = await check();
        if (result !== null && result !== false) {
            return result;
        }
        await sleep(interval);
    }
    throw new Error(`waitFor: condition not met within ${timeout}ms`);
}
```

Usage:

```typescript
const file = await waitFor(
    async () => existsSync(path) ? readFileSync(path, 'utf8') : null,
    { interval: 500, timeout: 30_000 }
);
```

### Pattern 2: Poll with exponential backoff (for slow / uncertain durations)

```typescript
async function waitForBackoff<T>(
    check: () => Promise<T | null>,
    { initialInterval = 100, maxInterval = 5000, timeout = 60_000 } = {}
): Promise<T> {
    let interval = initialInterval;
    const start = Date.now();

    while (Date.now() - start < timeout) {
        const result = await check();
        if (result !== null && result !== false) return result;
        await sleep(interval);
        interval = Math.min(interval * 2, maxInterval);
    }
    throw new Error(`waitForBackoff: condition not met within ${timeout}ms`);
}
```

Useful when you don't know if the operation takes 100ms or 30s — quickly catches fast finishes, doesn't hammer when slow.

### Pattern 3: Event-driven (preferred when available)

If the platform provides events / callbacks / promises:

```typescript
await subagent.start();          // returns when subagent completes (promise-based)
const result = readReport();
```

This is just "don't poll when you have a direct mechanism." Always prefer when available.

In Claude Code: the Task tool returns when the subagent completes. So spawning a subagent doesn't need waiting logic — the await IS the wait.

## Orchestrator scenarios

### Human gate

```
You: "Architect has written the plan. Confirm before Developer starts?"
[AskUserQuestion presents options]
[User clicks one]
```

This is event-driven via `AskUserQuestion` — the next user message arrives when they choose. No polling needed; just wait for the response. The tool returns when the user has acted.

### Subagent completion

```typescript
// You spawn via Task tool — returns when subagent completes
await Task({ agent: 'developer', prompt: '...' });
const devChanges = await readFile('.claude-team/current/dev-changes.md');
```

Task tool already waits. You don't add waiting logic.

### Watching a shared file for a subagent's writes

Rare — usually you Task the subagent and read its output after Task returns. But occasionally (e.g., parallel sibling subagents producing per-task files), you need to wait for all of them.

For multiple parallel Tasks, await Promise.all:

```typescript
await Promise.all([
    Task({ agent: 'developer-parallel', prompt: 'Task 1' }),
    Task({ agent: 'developer-parallel', prompt: 'Task 2' }),
]);
// All parallel writes are done; read all per-task files
```

Don't poll for file existence — let the Task interface do its job.

### External service ready

A new dependency setup might require a service to be running (DB, queue, API). Wait for it before proceeding:

```typescript
async function waitForService(url: string) {
    return waitFor(async () => {
        try {
            const r = await fetch(url);
            return r.ok ? true : null;
        } catch {
            return null;
        }
    }, { interval: 500, timeout: 30_000 });
}
```

## Reasonable timeouts

Pick timeouts based on what you're actually waiting for:

| Wait type | Typical timeout |
|-----------|-----------------|
| Internal state change (in-process) | 5-10 seconds |
| File from local subagent | 30-60 seconds |
| Test suite completion | 5-10 minutes |
| Build / compile | 5-15 minutes |
| External API health check | 30-60 seconds |
| Deployment to staging | 5-30 minutes |
| Human response | Don't auto-timeout in normal cases; human will respond when ready |

If timeouts must be longer than these, the operation has an architecture problem (too slow, no fast feedback) — that's its own concern, not just a waiting concern.

## What "ready" means

Define the condition precisely BEFORE writing the wait:

- **Bad:** "Wait for the file to be ready" — what does "ready" mean? exists? non-empty? specific content?
- **Good:** "Wait for `.claude-team/current/dev-changes.md` to exist AND contain `Status: DONE`"

```typescript
async function waitForDevChangesDone() {
    return waitFor(async () => {
        const path = '.claude-team/current/dev-changes.md';
        if (!existsSync(path)) return null;
        const content = readFileSync(path, 'utf8');
        return content.includes('Status: DONE') ? content : null;
    }, { interval: 500, timeout: 60_000 });
}
```

The condition includes BOTH the file existing AND its content showing completion. Sloppy "file exists" would proceed too early.

## What to do on timeout

When `waitFor` times out, the operation didn't complete. Options:

1. **Retry the operation** — if it might have been a transient hiccup
2. **Investigate** — check logs, ask user
3. **Report as BLOCKED** — return to caller (Orchestrator) for higher-level decision

Don't:

- Silently proceed assuming it's "probably done"
- Endlessly extend the timeout
- Treat timeout as success

## Anti-patterns

- **`sleep(N)` then continue.** Hope-driven coding. If N is too small, race; if too large, waste.
- **Poll without timeout.** Eventually loops forever when the thing never happens (race lost, error swallowed).
- **Poll too aggressively** (interval = 10ms). CPU hot loop. Use intervals appropriate to the wait (≥100ms for most things).
- **Polled wait when an event mechanism exists.** Promise / callback / await is direct; polling is fallback.
- **Vague "ready" definition.** Specify the exact condition before writing the wait.
- **Treat timeout as success.** "It didn't happen in 60s, must be done." No — timeout means failure to satisfy condition.
- **Wait for human via polling.** Use `AskUserQuestion` — it returns when user responds. Don't poll for response files or anything similar.

## Quick reference

1. Identify what state you're waiting for — be precise (existence? content match? state field?)
2. Pick the right mechanism:
   - Promise / callback / await available? → use it
   - Otherwise → polling with `waitFor`
3. Pick interval (≥100ms typical) and timeout (per wait type table)
4. Express the condition as a function returning truthy/falsy (or value/null)
5. On success: proceed with the value
6. On timeout: don't pretend — handle as a real failure (retry, investigate, or BLOCKED)
