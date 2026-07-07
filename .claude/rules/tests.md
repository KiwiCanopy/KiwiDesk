---
paths:
  - "Tests/**"
---

# Tests

See AGENTS.md §2 & §5. Lesson learned the hard way on large PRs:

- **Split suites early.** The 79-char limit and the 350-line
  ceiling repeatedly bit large test files. Break a suite into
  focused files *before* it approaches the ceiling, not after.
- **Per-file private helpers are the convention** — small
  duplication across suites is fine; do not build a shared test
  harness or deep helper hierarchy to avoid it.
- Config/profile shape is pinned by `SettingsCodingTests`; extend
  it when adding a setting (Lua name → JSON key via `CodingKeys`).
- Pre-release, single-user: profile JSON needs no migration
  scripts — re-saving is the migration.
