---
name: testing-anti-patterns
description: "Common testing anti-patterns to avoid: testing mock behavior, adding test-only methods to production classes, blind mocking, order-dependent tests, fragile snapshot tests. Apply when writing or reviewing tests — before assertions and mock setups, check against the iron laws below."
---

# Testing Anti-Patterns

Tests can lie. They can pass without proving anything real. They can pin down implementation details that should be free to change. They can grow into a maintenance burden bigger than the code they test.

This skill catalogs the worst offenders. Use it as a checklist when writing tests, and as a review lens when reading them.

## Iron Laws

These three rules override the rest. If a test breaks any of them, stop and redesign.

1. **NEVER test mock behavior.** Mocks are stand-ins for real things; verifying that the stand-in does what you told it to do verifies nothing.
2. **NEVER add test-only methods to production classes.** `getInternalStateForTesting()` and similar are code smells; they entangle test infrastructure with production code permanently.
3. **NEVER mock without understanding the dependency.** Blind mocking — copy a mock from another test and hope — produces tests that pass for reasons unrelated to your code.

## Anti-pattern: Testing mock behavior

You replaced the database with a mock, then asserted the mock was called. You haven't tested your code; you've tested your mock setup.

```typescript
// Anti-pattern
test('saveUser persists to database', () => {
    const mockDb = { save: jest.fn() };
    const service = new UserService(mockDb);
    service.saveUser({ name: 'Alice' });
    expect(mockDb.save).toHaveBeenCalledWith({ name: 'Alice' });
    //                                         ^^^^^^^^^^^^^^^
    // This tests that mockDb.save was called. It doesn't test that
    // any user data is actually saved anywhere.
});
```

What you actually want:

- **Integration**: use a real (or test-double) database, assert the user can be retrieved
- **Unit**: assert the service transforms input correctly before passing to db (test the transformation, not the call)

```typescript
// Better: test the actual behavior
test('saveUser canonicalizes email before persisting', () => {
    const captured: any[] = [];
    const fakeDb = { save: (u: any) => captured.push(u) };
    const service = new UserService(fakeDb);
    service.saveUser({ name: 'Alice', email: 'ALICE@Example.COM' });
    expect(captured[0].email).toBe('alice@example.com');
    //                              ^^^^^^^^^^^^^^^^^^^
    // Asserts the actual behavior of UserService (canonicalization).
});
```

## Anti-pattern: Test-only production methods

You needed to verify internal state, so you added `getInternalCache()` or `setStateForTesting()` to the production class. Now:

- Production code carries test infrastructure forever
- The method is callable in production — security risk
- Any refactor that changes internals also breaks the test "API"
- Future engineers think the method has a real purpose

```typescript
// Anti-pattern
class Cache {
    private data = new Map();
    set(k: string, v: any) { this.data.set(k, v); }
    get(k: string) { return this.data.get(k); }

    // Added for tests:
    getInternalDataForTesting() { return this.data; }
}

test('cache stores values', () => {
    const c = new Cache();
    c.set('k', 'v');
    expect(c.getInternalDataForTesting().get('k')).toBe('v');
});
```

Better: test through the public API.

```typescript
test('cache stores values', () => {
    const c = new Cache();
    c.set('k', 'v');
    expect(c.get('k')).toBe('v');
});
```

If a behavior is genuinely not observable through the public API, ask: should it be?

- Side effects that matter externally → make them observable (return value, event, callback)
- Internal optimizations → don't test them; test the observable effect they enable

## Anti-pattern: Blind mocking

You copy a mock from another test (or from a tutorial) and don't actually understand what the real dependency does. Result: your test passes regardless of whether your code is correct, because the mock returns whatever shape your code happens to want.

```typescript
// Anti-pattern: copied mock without verifying real API
const mockHttpClient = {
    get: jest.fn().mockResolvedValue({ data: { items: [] } })
};
// Did the real client return { data: { items: [] } } or { results: [] }?
// You don't know. Your test passes; production fails.
```

Gate function before any mock setup: **"Do I know what the real dependency returns for this input?"** If no, stop. Read the real dependency's contract. Then mock with confidence.

## Anti-pattern: Order-dependent tests

A test passes when run alone but fails when run with others (or vice versa). Symptoms:

- Shared mutable state (a module-level cache, a global config)
- A test that doesn't clean up its side effects
- A test that depends on another test's setup

```typescript
// Anti-pattern: test 2 depends on test 1
let counter = 0;

test('increments counter', () => {
    counter++;
    expect(counter).toBe(1);
});

test('counter is now 1', () => {
    expect(counter).toBe(1);
    // Passes only if previous test ran. Run in isolation: fails.
});
```

Each test sets up its own state. Each test cleans up. Tests should pass in any order, alone or together.

## Anti-pattern: Fragile snapshot tests

Snapshot tests are great for catching unintentional changes. They're terrible when used as a stand-in for actual assertions.

```typescript
// Anti-pattern
test('renders user card', () => {
    const html = renderUserCard({ name: 'Alice', age: 30 });
    expect(html).toMatchSnapshot();
});
```

Every cosmetic change breaks the snapshot. Reviewers stop reading the diff and just hit "update snapshot." Now the snapshot proves nothing.

Snapshot tests are OK for:

- Stable structural output where any change is suspect (e.g., generated config files, GraphQL schemas)
- Output of code generators where the inputs are deliberately controlled

Snapshot tests are NOT OK for:

- HTML output that's expected to evolve
- API response bodies where you want to specifically assert key fields
- Anything where a human won't carefully read the diff

When unsure, write explicit assertions: `expect(html).toContain('Alice')` is small but meaningful.

## Anti-pattern: Testing through too many layers

```typescript
// Anti-pattern: testing pricing logic through HTTP + auth + db
test('discount applies for premium users', async () => {
    await db.users.insert({ id: 1, plan: 'premium' });
    const token = await login('user@example.com', 'pass');
    const response = await fetch('/api/checkout', {
        headers: { Authorization: token },
        body: JSON.stringify({ items: [...] })
    });
    expect(response.json().total).toBe(90); // wanted to test 10% discount
});
```

This test breaks when ANY of HTTP, auth, db, or pricing breaks. When it fails, the cause is ambiguous.

Better: unit-test the pricing function directly with premium and non-premium inputs. Add ONE integration test for the full flow.

## Anti-pattern: Excessive setup

If your test has 30 lines of setup and 1 line of assertion, the assertion is buried.

```typescript
// Anti-pattern: too much setup
test('discount applies', () => {
    const user = createUser(...);
    const product = createProduct(...);
    const cart = createCart(user);
    const session = createSession(user);
    const inventory = createInventory(...);
    const taxConfig = createTaxConfig(...);
    addToCart(cart, product);
    const result = calculateTotal(cart, user, taxConfig);
    expect(result.discount).toBe(10);
});
```

Extract setup into helpers / fixtures. Make the test body about the behavior under test:

```typescript
test('discount applies for premium users', () => {
    const cart = cartWithPremiumUserAnd99DollarProduct();
    expect(cart.totals.discount).toBe(9.90);
});
```

## Gate functions

Before you write a test, ask:

- **What real behavior am I testing?** Not "this method is called" — what observable thing happens?
- **Do I know what the real dependencies return?** If using mocks, you must.
- **Can this test fail for the right reason?** Cause the production behavior the test asserts on; does the test fail?
- **Will this test still pass after a refactor that preserves behavior?** It should.

If any answer is "no" or "unclear", redesign the test.

## Quick reference

| Anti-pattern | Detection |
|--------------|-----------|
| Testing mock behavior | Assertion is `expect(mock.thing).toHaveBeenCalled...` |
| Test-only production methods | Method name contains `ForTesting`, `_internal`, `__private` |
| Blind mocking | Can you explain what the real dependency returns? |
| Order-dependent | Does test rely on module-level state? Does cleanup exist? |
| Fragile snapshot | Snapshot covers evolving output; will reviewer read the diff? |
| Too many layers | Does the test break for reasons unrelated to what it's testing? |
| Excessive setup | Ratio of setup-to-assertion >5:1? Extract fixtures. |
