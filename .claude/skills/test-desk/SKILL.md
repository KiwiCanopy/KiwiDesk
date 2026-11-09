---
description: Launch a scratch KiwiDesk bundle against the in-repo test desk (Tests/KiwiDeskCoreTests/TestDesk) instead of the owner's ~/.config/KiwiDesk, drive it through its own CLI socket, and put the owner's instance back. Use when an implementation or a device check needs a running instance on a known config — six Spaces, one layout each — and whenever a fixture format bump reds TestDeskFixtureTests.
argument-hint: "[up <bundle.app> | windows <n> | cli <args> | down | regen]"
---

The test desk is a config folder checked into the repo
(`Tests/KiwiDeskCoreTests/TestDesk/config`) and the `KIWIDESK_HOME` QA lever
(#3121). With `KIWIDESK_HOME=<root>` set, a KiwiDesk process reads
`<root>/config` as its config folder and `<root>/machine` as its
machine folder, so the lock, the socket, the snapshots and the
migration copies are the desk's own. It also keeps the defaults in
the `com.kiwicanopy.kiwidesk.testdesk` suite, and it refuses the
service, the login item and the updater. It writes nothing of the
owner's config and settings. What it shares is machine-wide by
nature: a lock file beside the owner's (so neither instance starts
beside the other) and the records of the `hidutil` remap and the
KiwiVision appearance debt, which only one instance owns at a time.

## What the desk holds

- `gui.json`: Spaces 1–6, BSP · Scrolling · Stack · Monocle · Grid ·
  Floating, and the default shortcuts.
- `profiles/Test.json` and `profiles/Test Dual.json`: the one-screen
  and two-screen defaults. Neither names a real screen, so each is
  matched by screen count on any host. A two-screen check adds a
  virtual screen with the `extra-screen` skill.
- `init.lua`, which declares nothing, so `gui.json` owns the desk.
- No machine files. `machine.json` and `bindings.json` are keyed by
  Desktop stamps that only one Mac minted.

## Drive it

1. Build a scratch bundle (`scripts/build-app.sh --output <scratch>`),
   never the bare release binary (tests.md ▸ device eyeball).
2. `scripts/test-desk up <scratch>/KiwiDesk.app`; the bundle must
   be named `KiwiDesk.app`. It copies the fixture to
   `/tmp/kd-desk-<uid>`, or to `--root <dir>`, which keeps the socket
   path under `sun_path`'s 104 bytes. It stops the running KiwiDesk by its own
   bundle path, seeds the defaults suite past the first-run tour, and
   opens the bundle with the variable set. It returns once the
   instance answers `get_state`.
3. `scripts/test-desk windows 3` opens TextEdit windows in the Space
   on screen. Run it on an empty macOS Desktop, so the owner's own
   windows stay where they are.
4. `scripts/test-desk cli <command>` runs any CLI verb on the desk's
   socket. A bare `KiwiDesk <command>` without the variable talks to
   the owner's socket.
5. `scripts/test-desk down` quits the instance and closes, unsaved,
   every TextEdit window opened since `up`, the owner's included. It deletes the root and the defaults
   suite, then reopens the KiwiDesk that was running.

`up` swaps the owner's running app for the test desk (`main.swift`
says why the two never run together): run it only where the owner's
desk may be interrupted, and never during the owner's own sitting.

Change the copy, never the fixture: a check that needs Lua appends
to `<root>/config/init.lua` and reloads.

## When the fixture falls behind

`TestDeskFixtureTests` writes the desk through the real stores and
compares the bytes with the checked-in files. A `currentFormat` bump
or a new default reds it. Run `scripts/test-desk regen`, read the
diff, and commit the regenerated files with the change that moved
them. Never hand-edit a fixture file. The values live in
`Tests/KiwiDeskCoreTests/TestDeskFixture.swift`.

Older bundles: the [measure-work](../measure-work/SKILL.md) skill.
