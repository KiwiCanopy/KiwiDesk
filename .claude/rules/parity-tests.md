# Hand-mirrored field lists & parity tests

See **AGENTS.md §5** (canonical, last bullet) for full rationale.
The checklist for any code that repeats a struct's field list:

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
- A keypath/generic merge is justified only when it removes the
  drift, not just the `resolved()` lines. Sparse `Codable` stays
  per-field either way, so generics rarely buy down the real risk
  and fight §2.4.
