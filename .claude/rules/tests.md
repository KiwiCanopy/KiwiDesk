---
paths:
  - "Tests/**"
---

# Tests

The binding rules live in **AGENTS.md §2 & §5** (canonical). The
ones that bite large test PRs, as a checklist (rationale is in §5):

- **Split suites early** — the 79-char limit and 350-line ceiling
  bite large test files. Break a suite into focused files *before*
  it approaches the ceiling.
- **Per-file private helpers are the convention** — small
  duplication across suites is fine; no shared test harness. One
  ratified exception: *stateless structural-parity primitives*
  (reflection helpers backing the field-list guards) live shared
  in `ReflectionParity.swift` — duplicating them would let a
  divergent copy silently weaken a guard, the exact drift those
  guards prevent.
- Config/profile shape is pinned by `SettingsCodingTests` — extend
  it when adding a setting (Lua name → JSON key via `CodingKeys`;
  see [config-vocabulary.md](config-vocabulary.md)).
- Pre-release, single-user: profile JSON needs no migration — see
  [profiles.md](profiles.md) and §5.
