---
paths:
  - "Sources/KiwiDeskCore/**"
---

# Core boundaries

Deliberately short — it loads on every `KiwiDeskCore` edit. Three
seams that are violated *outside* the directory that owns them.

- **Core names, the GUI narrates (#96).** `L()` is `@MainActor`
  and much of Core is deliberately actor-free, so a user-facing
  condition detected in Core returns **structure** (a case, an
  enum, a value type) and the GUI renders the sentence at its own
  boundary — `Conflict.Target.systemShortcut(…)` (authored in
  `Keys/`) → `ConflictText`. Never a pre-rendered English string
  across that seam. Core holds **no** `L()` call site outside
  `Localization/`; keep it that way. Full argument:
  [localization.md](localization.md).
- **CLI/IPC error strings stay English** — they are a machine
  contract, not UI copy. The deliberate exception to the above.
- **Never `Bundle.module`** in code that runs from the `.app` —
  go through `ResourceBundle.locate` (`Bundle.kiwiDeskCore` /
  `Bundle.kiwiDeskGui`). It resolves on the machine that built it
  and `fatalError`s everywhere else, so bundling a resource in
  `Appearance/`, `Bar/` or `Localization/` is where this bites.
  `ResourceBundleRoutingTests` is the guard and its map is the
  exemption list; the argument is in
  [packaging-and-release.md](packaging-and-release.md).
