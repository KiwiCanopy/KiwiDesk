---
paths:
  - "Sources/KiwiDeskCore/**"
---

# Core boundaries

Deliberately short — it loads on every `KiwiDeskCore` edit. Three
seams that are violated *outside* the directory that owns them.

- **Core names, the GUI narrates (#96).** A user-facing
  condition detected in Core returns **structure** (a case, an
  enum, a value type) and the GUI renders the sentence at its own
  boundary — `Conflict.Target.systemShortcut(…)` (authored in
  `Keys/`) → `ConflictText`, `ConfigIssue.Kind` →
  `ConfigIssueText`. **Never a pre-rendered user-facing string
  across that seam** — that is the invariant, and it binds
  whether or not the string went through `L()`: a hardcoded
  English sentence built in Core is worse, because
  `scripts/extract-keys` cannot see it and no locale can ever
  translate it (four `ConfigIssue` messages shipped that way
  until #601).

  It is **not** a ban on `L()` by file location. Core draws some
  of its own UI — the Space Bar and the sticky mark — and that
  copy never crosses a seam, so `L()` is right there. **Which
  files, and why, lives in `CoreLocalizationBoundaryTests`'s
  `allowed` map**, not here: that guard covers the `L()`-shaped
  half of the invariant. The other half — a sentence built
  without `L()` — no string scan can see; it is prevented by
  making Core carry *structure*, and by a per-family renderer
  test (`ConfigIssueTextTests`,
  `PresetSummaryCoverageTests`). Full argument:
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
