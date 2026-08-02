---
paths:
  - "Sources/KiwiDeskCore/Config/**"
  - "Sources/KiwiDeskCore/Profiles/**"
  - "Sources/KiwiDeskCore/Models/**"
  - "Sources/KiwiDeskCore/Bar/**"
  - "Sources/KiwiDeskCore/Borders/**"
  - "Tests/**"
---

# Hand-mirrored field lists & parity tests

Canonical for this pattern (AGENTS.md §5 indexes it). The
checklist for any code that repeats a struct's field list:

- Patterns that mirror a field list: global ↔ optional-override
  (`AppBarStyle` ↔ `LayoutAppBar`), dual apply switch
  (`AppBarCommandSetting`), manual sparse `Codable`.
- Small readable duplication is fine (§2.4). Past **two** mirrors
  of the same list, weigh whether it still pays off before adding
  a third — drift (add a field, forget one site → silent data
  loss) starts to outweigh the clarity.
- A shipped mirror **must** carry a parity test. Prefer one that
  discovers fields by **reflection / shared `CodingKeys`** over a
  hand-enumerated list — a hand-listed parity test is itself one
  more place to forget.
- Know the net's reach: a reflection parity test catches a missing
  field *property*, not a missing line in `resolved()` / `encode` /
  `decode` (Swift can't drive those from reflection without
  keypaths). Back it with a round-trip + resolve-every-field test
  so a forgotten merge/encode line also fails — those stay
  hand-listed, so treat them as part of the same mirror.
- Reflection also only sees a container it can *type*: an empty
  one has no readable element type, and one whose element
  **wraps** the mirrored key in a struct reads as an unrelated
  collection. Either shape passes the parity test by being
  invisible to it, which is worse than not being covered — the
  suite goes green having looked. Adding a container of either
  shape owes a behavioural test of its own in the suite that owns
  that container, and a line in the parity suite's stated
  limitations so the next author knows the scan stops there
  (`WindowRekeyParityTests`, whose struct-element blind spot
  `MinimizeOrderTests` covers).
- A keypath/generic merge is justified only when it removes the
  drift, not just the `resolved()` lines. Sparse `Codable` stays
  per-field either way, so generics rarely buy down the real risk
  and fight §2.4.
