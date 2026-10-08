# AXDumps — vendored test data

Recorded accessibility dumps of real apps' windows, copied
unmodified from AeroSpace's `axDumps/` directory:

- Source: https://github.com/nikitabobko/AeroSpace
- Commit: `74a1bf17e82d70e0a21945ba04bb4f590bf19f83`
- License: MIT, `LICENSE.txt` beside these files (copied from the
  same commit's `LICENSE.txt`)

`AXDumpCorpusTests` replays each dump through KiwiDesk's float and
tile detection against an expected table KiwiDesk keeps itself
(#1883). The `Aero.*` keys that record AeroSpace's own verdicts are
never read. Refresh by copying the directory from a newer commit
whole and updating the commit above; never hand-edit a dump.
