---
paths:
  - "Sources/KiwiDeskCore/**"
---

# Core boundaries

Deliberately short — it loads on every `KiwiDeskCore` edit. Five
seams, each violated *outside* the directory that owns them — the
count is the five bullets immediately below, so it corrects
itself when a sixth is added.

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
  never called directly. Leaving one unassigned costs no red and
  no warning: its lines simply never reach `KiwiCore.onLog`, so
  nothing that reads the sink carries them. **A capture
  diagnostic writes through an `os.Logger` with a
  `privacy: .public` interpolation, never `NSLog`** — macOS
  redacts every NSLog line's content to `<private>` in
  `log show` (observed 2026-08-23, macOS 26.6.2), so the lines
  fire and the documented capture reads nothing.
  `LogSeamSinkTests` pins Core's sink both ways; a GUI-side
  logger owes the same shape with no guard, so its doc comment
  carries the danger (`ShortcutsPanelController`'s `panelLog`
  is the worked example). Four guards, reading
  different things — `LogSeamWiringTests` scans source for the
  wiring and its `allowed` map is the exemption list;
  `LogSeamDefaultTests` guards the default; `LogSeamSinkTests`
  guards the sink itself; and `LogSeamProbeTests` sends a line
  through every seam it finds on a live `KiwiCore` and requires
  it back out of the sink (#625). Each docstring carries its own
  argument, and `CoreLog` carries the default's.
  Bootstrap-time only, enforced twice: `onLog` needs no
  permission to be useful, so a seam wired later
  (`KiwiCore+Lifecycle`, after the AX grant) reds in the scan —
  a late wire is that rule's violation by its own terms — and
  again in the probe, which reads the sink before any lifecycle
  runs.
- **The API surface describes itself, and an enum's values are
  READ rather than typed (#1033).** Three obligations, all on
  `Commands/`:
  - **A new command owes a record** in the matching
    `Commands/Reference/APIRecords+*` table — group, arguments,
    one-line summary. `APIRecordCensusTests` holds the record
    keys against `commands` / `namespaces` / `luaOnly` in both
    directions, so a command with no record reds, as does a
    record for a command that does not exist.
  - **An enum-valued argument names the TYPE, never the values**
    — `.choice("anchor", ScrollingParams.Anchor.self)`.
    `APIChoice` has exactly one initializer and it reads
    `allCases`; `APIChoiceDerivationTests` scans that
    declaration, because adding a second, list-taking one is a
    two-line change that compiles and reads harmlessly.
  - **A decoder rejecting an enum value answers with
    `CommandResponse.expected(_:)`**, which builds the message
    from the same `allCases`. A hand-typed list is right the day
    it is written and silent after: both bar setters told users
    to send `ring|edge_mark|gap` for as long as they shipped,
    the case having been renamed `outline`.
    `CommandRejectionDerivationTests` scans for a rejection
    naming two or more cases of a decoder enum — its vocabularies
    are derived from the records, so its reach is the records
    that are filled, which that suite states.

  A record's `summary` is English prose authored in Core, and it
  rides the **CLI/IPC exception above rather than widening the
  #96 seam**: `list_commands` is a machine-readable description
  of a machine contract, delivered on the channel that bullet
  already rules English, and no GUI surface renders it. A summary
  that ever needs to reach the Settings window is a different
  feature and takes structure across the seam like everything
  else.
- **Never `Bundle.module`** in code that runs from the `.app` —
  go through `ResourceBundle.locate` (`Bundle.kiwiDeskCore` /
  `Bundle.kiwiDeskGui`). It resolves on the machine that built it
  and `fatalError`s everywhere else, so bundling a resource in
  `Appearance/`, `Bar/` or `Localization/` is where this bites.
  `ResourceBundleRoutingTests` is the guard and its map is the
  exemption list; the argument is in
  [packaging-and-release.md](packaging-and-release.md).
