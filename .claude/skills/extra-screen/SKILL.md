---
description: Add a virtual second screen with BetterDisplay for a device test, unmirror it, read which Desktop mode the machine is really in, and put the desk back. Use when a change or a report needs more screens than are plugged in — a move across screens, a Space on another screen, per-screen bars — instead of asking the owner to connect one.
argument-hint: "[optional: screen name, or what the test needs]"
---

A virtual screen is a real screen to macOS and to KiwiDesk: it gets a
`displayIdentifier`, its own Space list and Accessibility frames. Use one
instead of asking for a cable. It proves arrangement, frames and Desktop
behavior. It does not prove rendering on real panels, refresh rates or
hot-plug timing of a physical connection.

`betterdisplaycli` needs the app running, and it answers
`Failed. Request timed out. Host app might not be running or is not accepting notifications.`
otherwise. Every step below takes effect on the owner's live desk, so
never run one while a `work-profiler` or a test suite that reads the
screen list is in flight.

## 1. Bring the screen up

Start the app, then wait until it answers. It takes a few seconds, so
poll rather than sleep a guess.

```bash
open -g -a BetterDisplay
betterdisplaycli get --identifiers
```

`--identifiers` lists every device with its `name`. This machine keeps a
virtual screen named `Wide Screen` (3200 × 1440). Reuse it:

```bash
betterdisplaycli set --name="Wide Screen" --connected=on
```

Only when no virtual screen exists, make one and name it, so that step 6
can name it too. It starts disconnected (2560 × 1440, to the panel's
right), so connect it as above:

```bash
betterdisplaycli create --type=VirtualScreen --virtualScreenName="Test Screen"
```

## 2. Unmirror it

A virtual screen can connect **mirrored** onto the built-in panel (seen
on one connect, not on another), which macOS counts as one screen:
KiwiDesk's `monitor_count` stays 1 and a test run measures nothing. Turn
the mirror off every time, naming the panel as
`--identifiers` spells it. The name follows the system language, so read
it rather than assume it (`Integriertes Display` on the owner's German
system).

```bash
betterdisplaycli set --name="Wide Screen" --targetName="Integriertes Display" --mirror=off
```

Then confirm both, from two different readers:

```bash
system_profiler SPDisplaysDataType | grep -E "^ {8}[A-Za-z].*:$|Mirror"
kiwidesk get_state
```

Both screens must show `Mirror: Off`, and `monitor_count` must read 2.

## 3. Read the Desktop mode, live

Whether a test runs on shared Desktops or separate Spaces decides what it
proves. `defaults read com.apple.spaces spans-displays` is the setting,
which applies at the next login, so it can disagree with the session
that is running. Ask the running session:

```swift
import AppKit
_ = NSApplication.shared
RunLoop.main.run(until: Date().addingTimeInterval(0.3))
print(NSScreen.screensHaveSeparateSpaces,
      NSScreen.screens.map { "\($0.localizedName) \($0.frame)" })
```

Run that with `swift <file>` from the scratchpad. It also prints each
screen's frame, which is where a test's windows must land.

Changing the mode needs a logout, which closes the owner's apps and
every session's work. Ask the owner, and let them do it. A logout also
ends BetterDisplay's connection, so repeat steps 1 and 2 afterwards.

A profile decides which Space lays out on which screen, so check that
before reasoning about a result (`get_state`'s `spaces`) rather than
assuming the screen from the Space's number.

## 4. Arrange the screens

Note the starting position with `--placement`, and put it back when done.
A placement is in logical points from the main screen's top left, and it
survives a disconnect.

```bash
betterdisplaycli get --name="Wide Screen" --placement
betterdisplaycli set --name="Wide Screen" --placement=1728x0
```

To change which screen is main, and with it the origin of every
coordinate, set it, then give it back the same way, since there is no
turning it off:

```bash
betterdisplaycli set --name="Wide Screen" --main=on
betterdisplaycli set --name="Integriertes Display" --main=on
```

`--moveTo` answers `Failed. Pro required.` here, so use `--placement`.

## 5. Add a Desktop to a screen

A hidden Desktop on the second screen needs a second Desktop there. No
command-line tool adds one without SIP off, which is never an option.
Mission Control does it, and it is not readable from here: Accessibility
lists nothing inside it and `screencapture` is refused, so click where
the button sits and check the result. Post the clicks with `CGEvent`:
`.mouseMoved` to hover, `.leftMouseDown` and `.leftMouseUp` to click.

1. Open Mission Control: `osascript -e 'tell application "System Events" to key code 126 using control down'`.
2. Move the pointer to the screen's top edge, 200 pt from its right, and
   wait a second for the Desktop bar to open.
3. Click 50 pt from the screen's right edge, 55 pt from its top.
4. Close it: `osascript -e 'tell application "System Events" to key code 53'`.
5. Read the Desktops back, through `SLSCopyManagedDisplaySpaces` (dlopen
   SkyLight, pass `SLSMainConnectionID()`), and confirm the screen's list grew.

That click landed first time on `Wide Screen` at the panel's left. It has
only been run once, at that one position.

**A Desktop you add outlives its screen.** On a disconnect it moves to
the built-in panel, and it goes back on a reconnect. Disconnected, it stays
on the panel and shifts the numbers of any Desktop after it, so ask the owner to
remove it in Mission Control: no removal has been run from here.

## 6. Put the desk back

Close the test's own windows **first**. A window left on the virtual
screen does not close with it: in one run KiwiDesk parked it on the panel,
in another Space, and put it back when the screen returned. Then:

```bash
betterdisplaycli set --name="Wide Screen" --connected=off
osascript -e 'quit app "BetterDisplay"'
```

Confirm that `system_profiler` lists only the built-in panel and that
`monitor_count` reads 1.

Keep a saved virtual screen for the next run. If one has to go, discard
it **by name**: `discard` without an identifier deletes every discardable
device, with no prompt and no undo.

```bash
betterdisplaycli discard --name="Test Screen"
```
