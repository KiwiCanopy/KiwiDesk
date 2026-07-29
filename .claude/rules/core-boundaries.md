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
  declares it. Leaving one unassigned fails by **doing
  nothing** — a seam whose default is a no-op lets its subsystem
  compile, ship, run and drop every line it logs, with no red and
  no symptom beyond a diagnostic that was never going to
  appear. Two guards, reading different things:
  `LogSeamWiringTests` scans source for the wiring and its
  `allowed` map is the exemption list; `LogSeamProbeTests` sends
  a line through every seam it finds on a live `KiwiCore` and
  requires it out of the sink, which is what catches a seam that
  is assigned to a body dropping the line, or clobbered by a
  later assignment (#625). Each docstring carries its own
  argument.
  Bootstrap-time only: a seam wired later (`KiwiCore+Lifecycle`,
  after the AX grant) is invisible to both — the runtime probe
  builds its `KiwiCore` and reads it, never running the app's
  later lifecycle — and `onLog` needs no permission to be useful.
- **Never `Bundle.module`** in code that runs from the `.app` —
  go through `ResourceBundle.locate` (`Bundle.kiwiDeskCore` /
  `Bundle.kiwiDeskGui`). It resolves on the machine that built it
  and `fatalError`s everywhere else, so bundling a resource in
  `Appearance/`, `Bar/` or `Localization/` is where this bites.
  `ResourceBundleRoutingTests` is the guard and its map is the
  exemption list; the argument is in
  [packaging-and-release.md](packaging-and-release.md).
