---
paths:
  - "Sources/KiwiDeskCore/**"
---

# Core boundaries

Deliberately short — it loads on every `KiwiDeskCore` edit. Four
seams, each violated *outside* the directory that owns them — the
count is the four bullets immediately below, so it corrects
itself when a fifth is added.

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
- **A `var onLog` seam is wired in `KiwiCore+Bootstrap`**, in
  the group where all of them are, and in the same change that
  declares it — and it **defaults to `CoreLog.write`**, which is
  never called directly. `LogSeamWiringTests` guards the wiring
  and its `allowed` map is the exemption list;
  `LogSeamDefaultTests` guards the default, and
  `LogSeamSinkTests` guards the sink itself — that its body still
  writes, and that Core never calls it outside a seam
  declaration. The argument for all of it is on `CoreLog`.
  Bootstrap-time only: a seam wired later (`KiwiCore+Lifecycle`,
  after the AX grant) is invisible to that guard, and `onLog`
  needs no permission to be useful.
- **Never `Bundle.module`** in code that runs from the `.app` —
  go through `ResourceBundle.locate` (`Bundle.kiwiDeskCore` /
  `Bundle.kiwiDeskGui`). It resolves on the machine that built it
  and `fatalError`s everywhere else, so bundling a resource in
  `Appearance/`, `Bar/` or `Localization/` is where this bites.
  `ResourceBundleRoutingTests` is the guard and its map is the
  exemption list; the argument is in
  [packaging-and-release.md](packaging-and-release.md).
