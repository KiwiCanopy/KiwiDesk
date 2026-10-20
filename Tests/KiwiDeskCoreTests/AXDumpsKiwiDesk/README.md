# AXDumpsKiwiDesk — dumps KiwiDesk recorded itself

AX dumps of real windows that AeroSpace's corpus (`../AXDumps/`)
does not hold, recorded on a KiwiDesk dev machine in the same key
shape, so `AXDumpCorpusTests` replays them beside the vendored ones
under the `kiwidesk/` prefix. Kept apart because `AXDumps/` is
refreshed by copying upstream's directory whole.

Each file carries the keys `AXDump.readKeys` reads, plus any other
attribute the recorder read, which the corpus ignores. The `Aero.*`
keys hold the same facts AeroSpace records under those names (bundle
id, activation policy, CGWindow layer, failed reads), never a
classification.

| Dump | Recorded | Window |
|---|---|---|
| `macos27_spotlight` | 2026-10-20, macOS 27.0.1 (26A434) | Spotlight's search panel, opened with ⌘Space (#2236, #2239) |
