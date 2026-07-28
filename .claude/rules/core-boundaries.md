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
  `Keys/`) → `ConflictText`, `ConfigIssue.Kind` →
  `ConfigIssueText`. **Never a pre-rendered user-facing string
  across that seam** — that is the invariant, and it binds
  whether or not the string went through `L()`: a hardcoded
  English sentence built in Core is worse, because
  `scripts/extract-keys` cannot see it and no locale can ever
  translate it (four `ConfigIssue` messages shipped that way
  until #601).

  It is **not** a ban on `L()` by file location. Core's in-app
  overlays — the App Bar and Space Bar item views, the sticky
  mark — are AppKit views that render their own text and are
  already `@MainActor`; they live under `Sources/KiwiDeskCore`
  only because the subsystem map puts the overlays there. There
  is no seam for them to cross, and `L()` is correct in them.
  `CoreLocalizationBoundaryTests` is the guard, and **its
  `allowed` map is the one copy** of which files are exempt and
  why. Full argument: [localization.md](localization.md).
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
