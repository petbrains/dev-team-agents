---
name: root-cause-tracing
description: "Trace backward through the call chain to find the original trigger of a bug, not just where the symptom appears. Apply when fixing any non-trivial bug. The first instinct is to fix where the error fires; this skill enforces tracing upward until you find where bad data or state was introduced. Adapted from claude-power-user."
---

# Root Cause Tracing

When a bug fires, the natural urge is to fix it where it shows. That's symptom treatment — the same bug class will recur in other places fed by the same source. Trace backward to find where the bad input or state entered the system; fix it there.

## When to use

- Any bug investigation that requires understanding "why this happens"
- Especially when the error message points to a function deep in the call chain
- When the bug pattern feels like it could recur (one of several similar bugs)

NOT when:

- The bug is genuinely at the symptom location (e.g., off-by-one in the line where the error fires)
- The trace would cross a trust boundary (third-party code) — fix at our boundary instead

## The principle

A bug surface chain looks like this:

```
Symptom (where the user sees the error)
  ↑ caller frame
  ↑ caller frame
  ↑ caller frame  
  ↑ ROOT — where bad data or state entered the system
```

Every frame from ROOT downward is just propagation. Fixing at the symptom line treats one propagation; the root remains and the next bug from the same root still ships.

## The six steps

### Step 1: Observe the symptom precisely

Capture exactly what the user/system sees:

- Full error message
- Stack trace (top to bottom)
- Logs around the time
- Reproduction inputs

Don't paraphrase. "Sometimes login fails" is not a symptom; "POST /login returns 500 with body 'Cannot read property email of undefined'" is.

### Step 2: Find immediate cause

Where does the error actually fire? Look at the top stack frame:

```
TypeError: Cannot read property 'email' of undefined
  at validateUser (src/auth/validate.ts:42)
  at processLogin (src/auth/login.ts:18)
  at POST /login (src/server.ts:55)
```

Immediate cause: `validate.ts:42`, accessing `.email` on `undefined`.

Resist the urge to fix here. "Just add a null check at line 42" is symptom treatment.

### Step 3: Ask — what called this with bad input?

Move up one frame. Why is `validate.ts:42` receiving `undefined`?

```typescript
// validate.ts:42 — top frame
function validateUser(user: User) {
    return user.email.toLowerCase();   // user is undefined here
}

// login.ts:18 — caller
function processLogin(req: Request) {
    const user = lookupUser(req.body.username);
    return validateUser(user);          // lookupUser returned undefined
}
```

The caller passed `undefined`. WHY?

### Step 4: Keep tracing up until you find the trigger

Move up frame by frame until you find where the bad data was generated (or should have been validated):

```typescript
// lookupUser — what returned undefined?
function lookupUser(username: string) {
    return users.find(u => u.username === username);  // returns undefined if not found
}
```

Got it: `lookupUser` returns `undefined` for unknown users. Two possible roots:

**Root candidate A**: `lookupUser` should never return `undefined`; it should throw `UserNotFound`. The contract is wrong.

**Root candidate B**: `processLogin` should handle the not-found case — check before passing to `validateUser`. The caller violated the contract.

Either one is a defensible root, depending on the codebase's conventions. The point: the fix at line 42 (`if (!user) return null`) wouldn't address either root.

### Step 5: Identify WHY the root exists

Once you've found WHERE, ask WHY:

- Wrong default value? Where was it set?
- Missing validation at the boundary?
- Race condition? Specifically what's the timing?
- Logic error? Off-by-one, inverted condition, missed case?
- API contract drift? Schema change unaccompanied by code update?

The "why" goes into your debug report as `## Root Cause Analysis`.

### Step 6: Fix at the source

The fix:

- Addresses the root, not the symptom
- Prevents recurrence of similar bugs from the same source
- Optionally adds defense-in-depth at intermediate layers

```typescript
// Fix: validate at the boundary
function processLogin(req: Request) {
    const user = lookupUser(req.body.username);
    if (!user) {
        return Response.status(401).body('Invalid credentials');
    }
    return validateUser(user);
}
```

OR refine the contract:

```typescript
// Fix: lookupUser throws instead of returning undefined
function lookupUser(username: string): User {
    const user = users.find(u => u.username === username);
    if (!user) throw new UserNotFound(username);
    return user;
}

// All callers must now handle UserNotFound — compile errors guide the update
```

Pick the fix that matches the codebase's conventions. Both are correct in different style cultures.

### Bonus: defense-in-depth

After fixing the root, optionally add guards at intermediate layers so the same bug class can't recur silently:

```typescript
// validate.ts — add a guard even though caller should never pass undefined
function validateUser(user: User) {
    if (!user) throw new Error('validateUser: received undefined user (caller bug?)');
    return user.email.toLowerCase();
}
```

This is **defense-in-depth**, not a fix. The fix is at the root. This is "if the root is ever re-broken, fail loudly here too."

## Stopping criterion

Stop tracing when you find:

- A function receiving bad input from **outside** our system (user input, network, file — the boundary)
- A specific config or state that was **set incorrectly** at initialization
- A **race condition** where ordering went wrong (and you can name the two operations whose ordering matters)
- A **logic error** (the function's own bug — off-by-one, inverted condition)

When the cause is in third-party code:

- DON'T patch third-party code (you don't own it)
- DO add defense at our boundary (validate inputs to / outputs from the third-party call)
- Document the third-party bug for context

## Examples

### Example 1: silent default

Symptom: `git init` runs in user's home directory unexpectedly.

```
Trace:
  child_process.exec('git init', { cwd: projectDir })   ← runs in cwd
    ↑ called from WorktreeManager.create(projectDir)
      ↑ called from Session.init(projectDir)
        ↑ called from CLI handler
          ↑ projectDir was '' (empty string, falsy) — bash treats empty cwd as $HOME
```

Symptom fix would be at the exec call. Root: CLI handler passes empty string when env var is unset. Fix: validate at CLI boundary that projectDir is non-empty.

### Example 2: race condition

Symptom: occasional duplicate user records.

```
Trace:
  insertUser(user)   ← INSERT executes
    ↑ called from registerHandler
      ↑ which first did SELECT to check if user exists
      ↑ NO transaction wrapping SELECT and INSERT
        ↑ ROOT: two concurrent requests both SELECT empty, both INSERT
```

Symptom fix: dedup after the fact. Root fix: wrap in transaction, use unique constraint at DB level.

## Anti-patterns

- **Stop at the immediate cause.** "Error on line 42, fix line 42." That's symptom treatment.
- **Add a null check at every "undefined" error.** Spreads bugs around, doesn't fix any.
- **Trace forever.** When you find an external boundary, stop — that IS the root.
- **Fix at multiple layers without identifying the root.** Defense-in-depth is a bonus, not a substitute for finding the source.
- **Skip the WHY step.** Knowing where the bug entered is necessary; knowing why is what lets you write a test that catches the bug class (not just the instance).
- **Refactor while tracing.** Trace first, then fix. Refactoring mid-trace muddles the investigation.
- **Trace into third-party code and try to fix it.** Defend at our boundary instead.

## Quick reference

1. Observe symptom precisely (full error, stack trace, repro inputs)
2. Find immediate cause (top stack frame)
3. Ask: what called this with bad input? (one frame up)
4. Keep tracing up until you find an external boundary or contract violation
5. Identify WHY: wrong default? missing validation? race? logic error?
6. Fix at the root
7. (Optional) Add defense-in-depth at intermediate layers
