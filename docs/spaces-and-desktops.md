---
title: Spaces & Desktops
description: How your screens, macOS's Desktops, KiwiDesk's profiles and KiwiDesk's Spaces fit together — and which of them owns what.
---

# Spaces & Desktops

Two systems are stacked here, and they use two different words.

- **Desktops** are **macOS's**. Mission Control labels them
  "Desktop 1", "Desktop 2", …; you swipe or press Ctrl+arrow
  between them, and macOS decides which windows live on which.
- **Spaces** are **KiwiDesk's**. A Space is a named group of
  windows with a layout of its own — `focus_space("mail")`, the
  Space Bar, the Spaces list in Settings.

Neither is built out of the other. macOS decides which windows
exist for you right now; KiwiDesk arranges the ones it can see
and keeps its own Spaces on top.

## The picture

```mermaid
flowchart TD
    S["Screen<br/>(the main one has the menu bar)"] --> D["macOS Desktop<br/>Mission Control's Desktop 2"]
    D -->|"main screen only,<br/>and only where you bound one"| P["Profile<br/>one at a time, for the whole desk"]
    P --> SP["Spaces<br/>KiwiDesk's — one list per profile"]
    SP -->|"pinned, or placed for you"| S
    D -.->|"remembers the Space<br/>it last showed"| SP
```

Four facts: a profile owns Spaces, Spaces are placed on screens,
a Desktop can *choose* a profile, and a Desktop *remembers* a
Space.

<figure>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 632 104" role="img" aria-label="Key: a screen stands on a stand; a Desktop is a plate; a Space is a folder, filled when on show and outlined when waiting; a window is a plain rectangle, stronger when focused." font-family="-apple-system, system-ui, sans-serif"><text x="54.0" y="92.0" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="0.9">Screen</text><rect x="14.0" y="12.0" width="80.0" height="50.0" rx="2" fill="currentColor" fill-opacity="0" stroke="currentColor" stroke-opacity="1" stroke-width="2.2"/><line x1="54.0" y1="62.0" x2="54.0" y2="69.0" stroke="currentColor" stroke-opacity="1" stroke-width="2"/><line x1="44.4" y1="70.0" x2="63.6" y2="70.0" stroke="currentColor" stroke-opacity="1" stroke-width="2"/><text x="159.0" y="92.0" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="0.9">macOS Desktop</text><rect x="119.0" y="12.0" width="80.0" height="56.0" rx="8" fill="currentColor" fill-opacity="0.055" stroke="currentColor" stroke-opacity="0.22" stroke-width="1"/><text x="127.0" y="28.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 1</text><text x="264.0" y="92.0" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="0.9">Space on show</text><path d="M221.0 65.0 V15.0 Q221.0 12.0 224.0 12.0 H268.0 Q271.0 12.0 271.0 15.0 V29.0 H304.0 Q307.0 29.0 307.0 32.0 V65.0 Q307.0 68.0 304.0 68.0 H224.0 Q221.0 68.0 221.0 65.0 Z" fill="currentColor" fill-opacity=".16" stroke="currentColor" stroke-width="1.5"/><text x="246.0" y="24.4" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1" font-weight="600">Space</text><text x="369.0" y="92.0" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="0.9">Space waiting</text><path d="M326.0 65.0 V15.0 Q326.0 12.0 329.0 12.0 H373.0 Q376.0 12.0 376.0 15.0 V29.0 H409.0 Q412.0 29.0 412.0 32.0 V65.0 Q412.0 68.0 409.0 68.0 H329.0 Q326.0 68.0 326.0 65.0 Z" fill="none" stroke="currentColor" stroke-opacity=".45" stroke-width="1"/><text x="351.0" y="24.4" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="0.8">Space</text><text x="474.0" y="92.0" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="0.9">Window</text><rect x="444.0" y="24.0" width="60.0" height="36.0" rx="2" fill="currentColor" fill-opacity="0.1" stroke="currentColor" stroke-opacity="0.8" stroke-width="1.2"/><text x="579.0" y="92.0" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="0.9">Focused window</text><rect x="549.0" y="24.0" width="60.0" height="36.0" rx="2" fill="currentColor" fill-opacity="0.32" stroke="currentColor" stroke-opacity="0.8" stroke-width="1.2"/></svg>
</figure>

## Spaces belong to a profile, and sit on screens

The Space list is part of the **profile**, with its layout
modes, gaps, borders and rules. Whenever a different profile
becomes live — loaded by you, or arriving on its own from a
Desktop binding or a screen change — its Space list becomes the
authority. A Space's name is what makes it that Space: when both
profiles have a `1`, it stays on screen and takes the new
profile's settings. Re-applying the profile that is already
live changes nothing, so a screen reconnect is harmless.

**Switching holds the Spaces it does not name.** When a
different profile or a built-in Standard becomes live, each Space
it does not have, and that still has windows in it, is **held**
for the profile you left instead of being dropped — whether its
screen was unplugged or is still there. A window the new profile
has had before goes back to the Space it had it in, so a held
Space keeps only windows that profile has never seen, and one
left empty goes away.

**Unplugging a screen holds its Spaces.** When unplugging a
screen makes a different profile live, each Space that was on
that screen and still has windows in it is carried onto a
remaining screen instead of being dropped. Where the new profile
has a Space of its name, it takes the next number past the
highest one in use, so a held `3` beside
your own `1`–`5` becomes `6`, and a held `Mail` beside your own
`Mail` becomes a number too. A held Space moves to a new number
again whenever a profile that loads uses its current one.

Where KiwiDesk manages your config, a Space missing its go-to,
move or move-and-follow digit shortcut gets it for its own number —
a held `6` gets `⌃⌥6` — if that key is still free. Any other Space
takes the digit of its place among the first ten, unless a
numbered Space owns that digit. A Space never gets a second
digit shortcut for the same thing, and reordering your Spaces never
changes them.

Held Spaces keep the order they had: when a screen's Spaces are
held, a numbered Space after a renumbered one is renumbered after
it too, so the Space Bar and the digit shortcuts list them in the
order the screen had them. A later renumber keeps the Space Bar in
that order.

The Space Bar draws a two-screen marker after a held Space's
identifier, and VoiceOver reads the profile it was held from, the
screen it came from, its old name when it was renumbered, and that
it is not saved: saving a profile never includes a held Space. A
Space held from a built-in Standard names only its screen.

A Space you make on the fly — **New Space** on a Space's
right-click menu, `create_space`, or `focus_space` and
`move_to_space` naming a Space that does not exist — is
**temporary**. It wears an hourglass marker, lasts through a
restart, a reload and a Settings Save, and goes away when its
last window leaves it. No save writes it into the profile until
you choose **Add Space ‹n› to this profile** in Settings ▸
Spaces, or save the profile under a name with `save_profile`.
Switch to another profile while it holds windows and it is held
like any other Space, and comes back temporary; an empty one goes
away on the switch.

An empty temporary Space also goes away once you have switched to
it and then left it with nothing in it, so a Space shortcut that
made one by mistake leaves nothing behind. Temporary Spaces sit
in the Space Bar in number order.

Plug the screen back in and a held Space goes back to it with
everything in it, windows opened while it was held included, when
what comes back is the profile (or built-in Standard) it left and
that has a Space of the held one's original name. Otherwise it
moves back onto its screen and stays held.

A held Space goes away once no window is left in it; a window on
another Desktop, or hidden with its app, still counts. Loading a
profile does not end a hold, and neither does a Desktop binding:
it ends when the profile or Standard it left comes back and has
a Space of its original name, when it empties, or when you reset
every setting. `delete_space` moves its windows to the fallback
Space (`set_fallback_space`), which empties it.

Held Spaces come back when KiwiDesk quits and reopens, updates or
crashes — a window hidden, on another Desktop or still opening
included — and go home at once, as above, if their screen is back
by then. A restart of the Mac ends them, since a held Space names
its windows by ids a restart retires and no restore re-keys a
hold. A window of a hidden app goes home with its
held Space too, and comes back there when you show the app.

Every Space sits on a screen. In Settings the **Screens**
section is a picture of your desk: drag a Space chip onto the
screen it belongs to, or leave it outlined and KiwiDesk places
it for you. From Lua the same pin is
`pin_space_to_display("mail", 2)`.

Each screen shows **one** of its Spaces at a time — with two
screens, two Spaces are on show at once. The Spaces no screen is
showing are parked (see [Parking is not a Desktop
move](#parking-is-not-a-desktop-move)).

## Every Desktop keeps its own Space, and its own windows

Every Desktop remembers which Space it was on. Switch away and
back and you land on the same Space, with the same windows in
the same order and the same one focused — as long as they come
back promptly ([accepted limitations](accepted-limitations.md)
has the case where they do not). Where KiwiDesk owns your config
and can give a Desktop an identity of its own, that memory
survives quitting KiwiDesk; a hand-written `init.lua` setup keeps
it for the session only.

<figure>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 632 475" role="img" aria-label="Three Desktops, one per row, each a plate. On each, three Spaces drawn as folders in the same order, holding only that Desktop&#x27;s windows. One folder per plate is filled: the Space that Desktop shows." font-family="-apple-system, system-ui, sans-serif"><text x="10.0" y="20.0" font-size="13" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">A window sits on one Desktop and in one Space.</text><rect x="10.0" y="34.0" width="612.0" height="106.0" rx="8" fill="currentColor" fill-opacity="0.055" stroke="currentColor" stroke-opacity="0.22" stroke-width="1"/><text x="18.0" y="51.0" font-size="12" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 1</text><path d="M18.0 127.0 V63.0 Q18.0 60.0 21.0 60.0 H85.0 Q88.0 60.0 88.0 63.0 V80.0 H211.0 Q214.0 80.0 214.0 83.0 V127.0 Q214.0 130.0 211.0 130.0 H21.0 Q18.0 130.0 18.0 127.0 Z" fill="currentColor" fill-opacity=".16" stroke="currentColor" stroke-width="1.5"/><text x="53.0" y="73.9" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1" font-weight="600">Space 1</text><rect x="23.0" y="85.0" width="91.0" height="40.0" rx="2" fill="currentColor" fill-opacity="0.32" stroke="currentColor" stroke-opacity="0.8" stroke-width="1.2"/><text x="68.5" y="109.0" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1">Safari</text><rect x="118.0" y="85.0" width="91.0" height="40.0" rx="2" fill="currentColor" fill-opacity="0.1" stroke="currentColor" stroke-opacity="0.8" stroke-width="1.2"/><text x="163.5" y="109.0" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1">Notes</text><path d="M218.0 127.0 V63.0 Q218.0 60.0 221.0 60.0 H285.0 Q288.0 60.0 288.0 63.0 V80.0 H411.0 Q414.0 80.0 414.0 83.0 V127.0 Q414.0 130.0 411.0 130.0 H221.0 Q218.0 130.0 218.0 127.0 Z" fill="none" stroke="currentColor" stroke-opacity=".45" stroke-width="1"/><text x="253.0" y="73.9" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="0.8">Space 2</text><rect x="223.0" y="85.0" width="186.0" height="40.0" rx="2" fill="currentColor" fill-opacity="0.1" stroke="currentColor" stroke-opacity="0.8" stroke-width="1.2"/><text x="316.0" y="109.0" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1">Terminal</text><path d="M418.0 127.0 V63.0 Q418.0 60.0 421.0 60.0 H485.0 Q488.0 60.0 488.0 63.0 V80.0 H611.0 Q614.0 80.0 614.0 83.0 V127.0 Q614.0 130.0 611.0 130.0 H421.0 Q418.0 130.0 418.0 127.0 Z" fill="none" stroke="currentColor" stroke-opacity=".45" stroke-width="1"/><text x="453.0" y="73.9" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="0.8">mail</text><rect x="423.0" y="85.0" width="186.0" height="40.0" rx="2" fill="currentColor" fill-opacity="0.1" stroke="currentColor" stroke-opacity="0.8" stroke-width="1.2"/><text x="516.0" y="109.0" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1">Calendar</text><rect x="10.0" y="168.0" width="612.0" height="106.0" rx="8" fill="currentColor" fill-opacity="0.055" stroke="currentColor" stroke-opacity="0.22" stroke-width="1"/><text x="18.0" y="185.0" font-size="12" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 2</text><path d="M18.0 261.0 V197.0 Q18.0 194.0 21.0 194.0 H85.0 Q88.0 194.0 88.0 197.0 V214.0 H211.0 Q214.0 214.0 214.0 217.0 V261.0 Q214.0 264.0 211.0 264.0 H21.0 Q18.0 264.0 18.0 261.0 Z" fill="none" stroke="currentColor" stroke-opacity=".45" stroke-width="1"/><text x="53.0" y="207.9" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="0.8">Space 1</text><rect x="23.0" y="219.0" width="186.0" height="40.0" rx="2" fill="currentColor" fill-opacity="0.1" stroke="currentColor" stroke-opacity="0.8" stroke-width="1.2"/><text x="116.0" y="243.0" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1">Xcode</text><path d="M218.0 261.0 V197.0 Q218.0 194.0 221.0 194.0 H285.0 Q288.0 194.0 288.0 197.0 V214.0 H411.0 Q414.0 214.0 414.0 217.0 V261.0 Q414.0 264.0 411.0 264.0 H221.0 Q218.0 264.0 218.0 261.0 Z" fill="currentColor" fill-opacity=".16" stroke="currentColor" stroke-width="1.5"/><text x="253.0" y="207.9" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1" font-weight="600">Space 2</text><rect x="223.0" y="219.0" width="91.0" height="40.0" rx="2" fill="currentColor" fill-opacity="0.32" stroke="currentColor" stroke-opacity="0.8" stroke-width="1.2"/><text x="268.5" y="243.0" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1">Figma</text><rect x="318.0" y="219.0" width="91.0" height="40.0" rx="2" fill="currentColor" fill-opacity="0.1" stroke="currentColor" stroke-opacity="0.8" stroke-width="1.2"/><text x="363.5" y="243.0" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1">Slack</text><path d="M418.0 261.0 V197.0 Q418.0 194.0 421.0 194.0 H485.0 Q488.0 194.0 488.0 197.0 V214.0 H611.0 Q614.0 214.0 614.0 217.0 V261.0 Q614.0 264.0 611.0 264.0 H421.0 Q418.0 264.0 418.0 261.0 Z" fill="none" stroke="currentColor" stroke-opacity=".45" stroke-width="1"/><text x="453.0" y="207.9" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="0.8">mail</text><text x="516.0" y="242.9" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="0.85">no windows here</text><rect x="10.0" y="302.0" width="612.0" height="106.0" rx="8" fill="currentColor" fill-opacity="0.055" stroke="currentColor" stroke-opacity="0.22" stroke-width="1"/><text x="18.0" y="319.0" font-size="12" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 3</text><path d="M18.0 395.0 V331.0 Q18.0 328.0 21.0 328.0 H85.0 Q88.0 328.0 88.0 331.0 V348.0 H211.0 Q214.0 348.0 214.0 351.0 V395.0 Q214.0 398.0 211.0 398.0 H21.0 Q18.0 398.0 18.0 395.0 Z" fill="none" stroke="currentColor" stroke-opacity=".45" stroke-width="1"/><text x="53.0" y="341.9" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="0.8">Space 1</text><text x="116.0" y="376.9" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="0.85">no windows here</text><path d="M218.0 395.0 V331.0 Q218.0 328.0 221.0 328.0 H285.0 Q288.0 328.0 288.0 331.0 V348.0 H411.0 Q414.0 348.0 414.0 351.0 V395.0 Q414.0 398.0 411.0 398.0 H221.0 Q218.0 398.0 218.0 395.0 Z" fill="none" stroke="currentColor" stroke-opacity=".45" stroke-width="1"/><text x="253.0" y="341.9" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="0.8">Space 2</text><rect x="223.0" y="353.0" width="186.0" height="40.0" rx="2" fill="currentColor" fill-opacity="0.1" stroke="currentColor" stroke-opacity="0.8" stroke-width="1.2"/><text x="316.0" y="377.0" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1">Music</text><path d="M418.0 395.0 V331.0 Q418.0 328.0 421.0 328.0 H485.0 Q488.0 328.0 488.0 331.0 V348.0 H611.0 Q614.0 348.0 614.0 351.0 V395.0 Q614.0 398.0 611.0 398.0 H421.0 Q418.0 398.0 418.0 395.0 Z" fill="currentColor" fill-opacity=".16" stroke="currentColor" stroke-width="1.5"/><text x="453.0" y="341.9" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1" font-weight="600">mail</text><rect x="423.0" y="353.0" width="186.0" height="40.0" rx="2" fill="currentColor" fill-opacity="0.32" stroke="currentColor" stroke-opacity="0.8" stroke-width="1.2"/><text x="516.0" y="377.0" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1">Mail</text><text x="10.0" y="428.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.85">A filled folder is the Space that Desktop shows, and comes back to. Swipe sideways to switch Desktop:</text><text x="10.0" y="443.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.85">you land on the Space it remembers. Nothing moves between Desktops. A Space simply holds other windows</text><text x="10.0" y="458.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.85">there.</text></svg>
</figure>

That memory is kept on this Mac alone, in
`~/Library/Application Support/KiwiDesk/machine.json`.

**Your windows stay with their Desktop.** A Space holds whatever
of its windows are on the Desktop you are looking at. Switch
Desktop and the same Space shows you that Desktop's windows
instead — nothing is moved, and nothing is lost.

A Desktop you have never visited takes a Space no other Desktop
is **showing or remembers**; when every Space is spoken for it
takes the first.

With **Displays have separate Spaces** on, each screen switches
Desktops on its own, and each moves only its own Space — swiping
the external screen leaves the built-in one alone.

## A binding gives a Desktop a different set of Spaces

Bind a profile to a Desktop — the **Profiles per macOS Desktop**
card in Settings, or `bind_profile_to_desktop(2, "Creator
Studio")` in Lua — and activating that Desktop loads that
profile, with its Spaces, layouts and settings. A binding
changes *which Spaces exist at all*: two Desktops bound to
different profiles offer you different lists, while two bound to
the same profile offer the same list and still keep their own
windows in it.

**Desktops without a binding keep whatever profile is active.**

## The main screen chooses the profile

KiwiDesk runs **one** profile across the whole desk, so a
binding fires when its Desktop becomes current on your **main**
screen — the one with the menu bar. A swipe on a secondary
screen re-tiles the windows that arrived with it and moves that
screen onto its own Desktop's Space, but never selects a profile.
With a single screen, the main screen's Desktop is simply *the*
Desktop.

The profile it loads applies to every screen, so a second screen
can change Space too, even though its Desktop did not. A Space
both profiles have stays on screen.

A Desktop you bound that is not on your main screen keeps its
row in the card, with a *not on main screen* badge; the binding
goes live again if a screen change makes that Desktop your main
screen's.

**A binding fires only for its profile's screen count.** A
Desktop holds a profile per screen count, so the same Desktop
can load a one-screen profile undocked and a two-screen one
docked: the profile saved for as many screens as are connected
fires, and the others wait until that many are. A Desktop bound
only to a one-screen profile stands aside on two, and KiwiDesk
picks by your screens ([Which Profile
Loads](user-guide.md#which-profile-loads)).

**A binding can also be for one screen setup.** Within a screen
count, a Desktop can hold a profile for each particular set of
screens you name, beside the one for all its other setups: with
exactly those screens connected, that set's profile loads; any
other setup of the count loads the one for all setups. Either
loads over a profile saved for exactly those screens.

## A Desktop has two numbers

With "Displays have separate Spaces" on and more than one screen,
Mission Control numbers each screen's Desktops from 1. KiwiDesk
uses two counts:

- **What KiwiDesk shows** counts per screen, as Mission Control
  does: KiwiHub's window switcher, the Desktop switch plate and
  the Desktop rows in Settings. A KiwiHub row for a window on
  another screen names that screen too — `Work · DELL U2723 ·
  Desktop 1`.
- **What a command or binding takes** counts across every screen,
  the screen Mission Control lists first counted first:
  [`focus_desktop`](lua-reference.md#focus_desktop),
  `move_to_desktop`, `bind_profile_to_desktop`, and the
  **Go to Desktop N** shortcuts, as macOS's own "Switch to
  Desktop N" does.

On one screen, and on the screen Mission Control lists first,
the two agree. A Settings row for a Desktop that is not present
keeps the number it was last seen at, counted across every
screen. On another screen they differ: the second screen's
first Desktop may be **Go to Desktop 7**, and Settings ▸
Shortcuts and KiwiHub's Shortcuts side show which screen and
Desktop each such row reaches right now.

<figure>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 632 333" role="img" aria-label="A main screen with five Desktops, numbered 1 to 5 by Mission Control and by KiwiDesk shortcuts. After a new screen connects, the last one moves there: Mission Control calls it Desktop 1, KiwiDesk shortcuts Desktop 5." font-family="-apple-system, system-ui, sans-serif"><text x="8.0" y="16.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Before</text><rect x="8.0" y="24.0" width="596.0" height="102.0" rx="2" fill="currentColor" fill-opacity="0" stroke="currentColor" stroke-opacity="1" stroke-width="2.2"/><line x1="306.0" y1="126.0" x2="306.0" y2="133.0" stroke="currentColor" stroke-opacity="1" stroke-width="2"/><line x1="234.5" y1="134.0" x2="377.5" y2="134.0" stroke="currentColor" stroke-opacity="1" stroke-width="2"/><text x="16.0" y="41.0" font-size="12" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Main screen</text><rect x="14.0" y="48.0" width="112.0" height="72.0" rx="8" fill="currentColor" fill-opacity="0.055" stroke="currentColor" stroke-opacity="0.22" stroke-width="1"/><text x="22.0" y="62.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">Mission Control</text><text x="22.0" y="76.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 1</text><text x="22.0" y="94.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">KiwiDesk</text><text x="22.0" y="108.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 1</text><rect x="132.0" y="48.0" width="112.0" height="72.0" rx="8" fill="currentColor" fill-opacity="0.055" stroke="currentColor" stroke-opacity="0.22" stroke-width="1"/><text x="140.0" y="62.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">Mission Control</text><text x="140.0" y="76.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 2</text><text x="140.0" y="94.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">KiwiDesk</text><text x="140.0" y="108.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 2</text><rect x="250.0" y="48.0" width="112.0" height="72.0" rx="8" fill="currentColor" fill-opacity="0.055" stroke="currentColor" stroke-opacity="0.22" stroke-width="1"/><text x="258.0" y="62.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">Mission Control</text><text x="258.0" y="76.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 3</text><text x="258.0" y="94.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">KiwiDesk</text><text x="258.0" y="108.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 3</text><rect x="368.0" y="48.0" width="112.0" height="72.0" rx="8" fill="currentColor" fill-opacity="0.055" stroke="currentColor" stroke-opacity="0.22" stroke-width="1"/><text x="376.0" y="62.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">Mission Control</text><text x="376.0" y="76.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 4</text><text x="376.0" y="94.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">KiwiDesk</text><text x="376.0" y="108.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 4</text><rect x="486.0" y="48.0" width="112.0" height="72.0" rx="8" fill="currentColor" fill-opacity="0.055" stroke="currentColor" stroke-opacity="0.22" stroke-width="1"/><text x="494.0" y="62.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">Mission Control</text><text x="494.0" y="76.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 5</text><text x="494.0" y="94.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">KiwiDesk</text><text x="494.0" y="108.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 5</text><text x="8.0" y="162.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">After a new screen connects</text><rect x="8.0" y="170.0" width="478.0" height="102.0" rx="2" fill="currentColor" fill-opacity="0" stroke="currentColor" stroke-opacity="1" stroke-width="2.2"/><line x1="247.0" y1="272.0" x2="247.0" y2="279.0" stroke="currentColor" stroke-opacity="1" stroke-width="2"/><line x1="189.6" y1="280.0" x2="304.4" y2="280.0" stroke="currentColor" stroke-opacity="1" stroke-width="2"/><text x="16.0" y="187.0" font-size="12" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Main screen</text><rect x="14.0" y="194.0" width="112.0" height="72.0" rx="8" fill="currentColor" fill-opacity="0.055" stroke="currentColor" stroke-opacity="0.22" stroke-width="1"/><text x="22.0" y="208.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">Mission Control</text><text x="22.0" y="222.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 1</text><text x="22.0" y="240.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">KiwiDesk</text><text x="22.0" y="254.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 1</text><rect x="132.0" y="194.0" width="112.0" height="72.0" rx="8" fill="currentColor" fill-opacity="0.055" stroke="currentColor" stroke-opacity="0.22" stroke-width="1"/><text x="140.0" y="208.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">Mission Control</text><text x="140.0" y="222.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 2</text><text x="140.0" y="240.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">KiwiDesk</text><text x="140.0" y="254.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 2</text><rect x="250.0" y="194.0" width="112.0" height="72.0" rx="8" fill="currentColor" fill-opacity="0.055" stroke="currentColor" stroke-opacity="0.22" stroke-width="1"/><text x="258.0" y="208.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">Mission Control</text><text x="258.0" y="222.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 3</text><text x="258.0" y="240.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">KiwiDesk</text><text x="258.0" y="254.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 3</text><rect x="368.0" y="194.0" width="112.0" height="72.0" rx="8" fill="currentColor" fill-opacity="0.055" stroke="currentColor" stroke-opacity="0.22" stroke-width="1"/><text x="376.0" y="208.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">Mission Control</text><text x="376.0" y="222.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 4</text><text x="376.0" y="240.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">KiwiDesk</text><text x="376.0" y="254.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 4</text><rect x="496.0" y="170.0" width="124.0" height="102.0" rx="2" fill="currentColor" fill-opacity="0" stroke="currentColor" stroke-opacity="1" stroke-width="2.2"/><line x1="558.0" y1="272.0" x2="558.0" y2="279.0" stroke="currentColor" stroke-opacity="1" stroke-width="2"/><line x1="543.1" y1="280.0" x2="572.9" y2="280.0" stroke="currentColor" stroke-opacity="1" stroke-width="2"/><text x="504.0" y="187.0" font-size="12" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">New screen</text><rect x="502.0" y="194.0" width="112.0" height="72.0" rx="8" fill="currentColor" fill-opacity="0.055" stroke="currentColor" stroke-opacity="0.22" stroke-width="1"/><text x="510.0" y="208.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">Mission Control</text><text x="510.0" y="222.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 1</text><text x="510.0" y="240.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">KiwiDesk</text><text x="510.0" y="254.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 5</text><line x1="552.0" y1="132.0" x2="552.0" y2="166.0" stroke="currentColor" stroke-opacity="0.8" stroke-width="1.2"/><polygon points="552.0,166.0 549.4,160.6 554.6,160.6" fill="currentColor" fill-opacity="0.8"/><text x="8.0" y="298.0" font-size="11.5" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Mission Control counts per screen. KiwiDesk shortcuts, Lua and CLI count across screens.</text><text x="8.0" y="316.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.85">KiwiDesk labels count per screen.</text></svg>
</figure>

## A binding follows its Desktop, not its number

Desktops are numbered by **position**: add a Desktop
before a bound one, delete one, drag them around in Mission
Control, plug a screen in or unplug it, and everything after the
change is renumbered.

A binding is not stored against that number. KiwiDesk writes a
small private identifier into each Desktop's own settings the
first time it sees it, and files the binding under **that**. A
Desktop keeps its profile when the numbers shift, the Desktop
that inherits its old number does not inherit its profile, and
the card's rows re-label themselves to the new numbers.

Deleting the Desktop deletes the identifier with it. That
binding shows a *not present* badge and does nothing until you
point it somewhere else — it is never fired for a different
Desktop.

**Unplugging a screen:** the first Desktop of the unplugged
screen merges into the one you are on and is gone, and the rest
move over to the remaining screen at new numbers. Their
identifiers travel with them, so their bindings keep working.
The merged one goes quiet; plugging the screen back in restores
it, identifier and all, and its binding comes back with it.

On a Mac where KiwiDesk cannot write the identifier, bindings
key by the Desktop's number — the behaviour above minus
the protection.

A binding follows its **profile** the same way: it names the
profile by an identifier the profile file keeps, so renaming the
profile — on this Mac or on another one syncing your config
folder — keeps the binding. Delete the profile and the binding
moves under *Missing profiles* in the card; a new profile under
the old name does not take it over. A binding written in
`init.lua` names its profile on every load and follows the name.

## "Displays have separate Spaces" decides the nesting

This macOS switch (System Settings ▸ Desktop & Dock) changes
which of *screen* and *Desktop* is the outer level, and KiwiDesk
follows it either way:

| The macOS setting | The shape | What it means here |
|---|---|---|
| **On** (macOS's default) | Screen → Desktop → Space | Each screen has its own Desktops and switches them on its own. Only your main screen's Desktops can be bound. |
| **Off** | Desktop → Screen → Space | One Desktop set spans every screen, so all screens switch together and every Desktop is bindable. |

<figure>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 632 708" role="img" aria-label="Displays have separate Spaces, on and off. With it off, each Desktop spans both screens, and a Desktop bound to its own profile offers its own Spaces. With it on, Desktop 1 on the main screen and Desktop 1 on the second screen are different macOS Desktops." font-family="-apple-system, system-ui, sans-serif"><text x="10.0" y="20.0" font-size="13" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">"Displays have separate Spaces" ON</text><text x="10.0" y="36.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">Screen → Desktop → Space</text><rect x="10.0" y="46.0" width="214.0" height="244.0" rx="2" fill="currentColor" fill-opacity="0" stroke="currentColor" stroke-opacity="1" stroke-width="2.2"/><line x1="117.0" y1="290.0" x2="117.0" y2="297.0" stroke="currentColor" stroke-opacity="1" stroke-width="2"/><line x1="91.3" y1="298.0" x2="142.7" y2="298.0" stroke="currentColor" stroke-opacity="1" stroke-width="2"/><text x="18.0" y="63.0" font-size="12" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Main screen</text><text x="216.0" y="63.0" font-size="11" text-anchor="end" fill="currentColor" fill-opacity="0.75">menu bar</text><rect x="16.0" y="70.0" width="202.0" height="104.0" rx="8" fill="currentColor" fill-opacity="0.055" stroke="currentColor" stroke-opacity="0.22" stroke-width="1"/><text x="24.0" y="86.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 1</text><g transform="translate(0,-6)"><path d="M24.0 163.0 V113.0 Q24.0 110.0 27.0 110.0 H71.0 Q74.0 110.0 74.0 113.0 V127.0 H107.0 Q110.0 127.0 110.0 130.0 V163.0 Q110.0 166.0 107.0 166.0 H27.0 Q24.0 166.0 24.0 163.0 Z" fill="currentColor" fill-opacity=".16" stroke="currentColor" stroke-width="1.5"/><text x="49.0" y="122.4" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1" font-weight="600">Space 1</text></g><text x="86.0" y="86.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">bindable</text><rect x="16.0" y="180.0" width="202.0" height="104.0" rx="8" fill="currentColor" fill-opacity="0.055" stroke="currentColor" stroke-opacity="0.22" stroke-width="1"/><text x="24.0" y="196.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 2</text><g transform="translate(0,-6)"><path d="M24.0 273.0 V223.0 Q24.0 220.0 27.0 220.0 H71.0 Q74.0 220.0 74.0 223.0 V237.0 H107.0 Q110.0 237.0 110.0 240.0 V273.0 Q110.0 276.0 107.0 276.0 H27.0 Q24.0 276.0 24.0 273.0 Z" fill="currentColor" fill-opacity=".16" stroke="currentColor" stroke-width="1.5"/><text x="49.0" y="232.4" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1" font-weight="600">Space 2</text></g><text x="86.0" y="196.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">bindable</text><rect x="400.0" y="46.0" width="214.0" height="244.0" rx="2" fill="currentColor" fill-opacity="0" stroke="currentColor" stroke-opacity="1" stroke-width="2.2"/><line x1="507.0" y1="290.0" x2="507.0" y2="297.0" stroke="currentColor" stroke-opacity="1" stroke-width="2"/><line x1="481.3" y1="298.0" x2="532.7" y2="298.0" stroke="currentColor" stroke-opacity="1" stroke-width="2"/><text x="408.0" y="63.0" font-size="12" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Second screen</text><rect x="406.0" y="70.0" width="202.0" height="104.0" rx="8" fill="currentColor" fill-opacity="0.055" stroke="currentColor" stroke-opacity="0.22" stroke-width="1"/><text x="414.0" y="86.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 1</text><g transform="translate(0,-6)"><path d="M414.0 163.0 V113.0 Q414.0 110.0 417.0 110.0 H461.0 Q464.0 110.0 464.0 113.0 V127.0 H497.0 Q500.0 127.0 500.0 130.0 V163.0 Q500.0 166.0 497.0 166.0 H417.0 Q414.0 166.0 414.0 163.0 Z" fill="currentColor" fill-opacity=".16" stroke="currentColor" stroke-width="1.5"/><text x="439.0" y="122.4" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1" font-weight="600">mail</text></g><text x="476.0" y="86.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">not bindable</text><rect x="406.0" y="180.0" width="202.0" height="104.0" rx="8" fill="currentColor" fill-opacity="0.055" stroke="currentColor" stroke-opacity="0.22" stroke-width="1"/><text x="414.0" y="196.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 2</text><g transform="translate(0,-6)"><path d="M414.0 273.0 V223.0 Q414.0 220.0 417.0 220.0 H461.0 Q464.0 220.0 464.0 223.0 V237.0 H497.0 Q500.0 237.0 500.0 240.0 V273.0 Q500.0 276.0 497.0 276.0 H417.0 Q414.0 276.0 414.0 273.0 Z" fill="currentColor" fill-opacity=".16" stroke="currentColor" stroke-width="1.5"/><text x="439.0" y="232.4" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1" font-weight="600">Space 3</text></g><text x="476.0" y="196.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">not bindable</text><line x1="136.0" y1="82.0" x2="412.0" y2="82.0" stroke="currentColor" stroke-opacity="0.9" stroke-width="1.4"/><line x1="136.0" y1="192.0" x2="412.0" y2="192.0" stroke="currentColor" stroke-opacity="0.9" stroke-width="1.4"/><text x="312.0" y="98.0" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1">even though they</text><text x="312.0" y="112.0" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1">have the same name</text><text x="312.0" y="208.0" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1" font-weight="600">they are different</text><text x="312.0" y="222.0" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1" font-weight="600">macOS Desktops</text><text x="10.0" y="316.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Same name, different macOS Desktops.</text><text x="10.0" y="331.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">Each screen numbers its own from 1 and switches alone.</text><line x1="10.0" y1="360.0" x2="622.0" y2="360.0" stroke="currentColor" stroke-opacity="0.3" stroke-width="1.2"/><text x="10.0" y="382.0" font-size="13" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">"Displays have separate Spaces" OFF</text><text x="10.0" y="398.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">Desktop → Screen → Space</text><rect x="10.0" y="408.0" width="612.0" height="124.0" rx="8" fill="currentColor" fill-opacity="0.055" stroke="currentColor" stroke-opacity="0.22" stroke-width="1"/><text x="18.0" y="424.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 1</text><text x="80.0" y="424.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">bindable, bound to profile Everyday, which holds 5 Spaces in total</text><rect x="27.3" y="432.0" width="280" height="86.0" rx="2" fill="currentColor" fill-opacity="0" stroke="currentColor" stroke-opacity="1" stroke-width="2.2"/><line x1="167.3" y1="518.0" x2="167.3" y2="525.0" stroke="currentColor" stroke-opacity="1" stroke-width="2"/><line x1="131.7" y1="526.0" x2="202.9" y2="526.0" stroke="currentColor" stroke-opacity="1" stroke-width="2"/><text x="35.3" y="449.0" font-size="12" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Main screen</text><path d="M33.3 509.0 V459.0 Q33.3 456.0 36.3 456.0 H80.3 Q83.3 456.0 83.3 459.0 V473.0 H112.3 Q115.3 473.0 115.3 476.0 V509.0 Q115.3 512.0 112.3 512.0 H36.3 Q33.3 512.0 33.3 509.0 Z" fill="currentColor" fill-opacity=".16" stroke="currentColor" stroke-width="1.5"/><text x="58.3" y="468.4" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1" font-weight="600">Space 1</text><path d="M124.3 509.0 V459.0 Q124.3 456.0 127.3 456.0 H171.3 Q174.3 456.0 174.3 459.0 V473.0 H203.3 Q206.3 473.0 206.3 476.0 V509.0 Q206.3 512.0 203.3 512.0 H127.3 Q124.3 512.0 124.3 509.0 Z" fill="none" stroke-opacity="0.5" stroke="currentColor" stroke-width="1"/><text x="149.3" y="468.4" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="0.8">Space 2</text><path d="M215.3 509.0 V459.0 Q215.3 456.0 218.3 456.0 H262.3 Q265.3 456.0 265.3 459.0 V473.0 H294.3 Q297.3 473.0 297.3 476.0 V509.0 Q297.3 512.0 294.3 512.0 H218.3 Q215.3 512.0 215.3 509.0 Z" fill="none" stroke-opacity="0.5" stroke="currentColor" stroke-width="1"/><text x="240.3" y="468.4" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="0.8">Space 3</text><rect x="324.7" y="432.0" width="280" height="86.0" rx="2" fill="currentColor" fill-opacity="0" stroke="currentColor" stroke-opacity="1" stroke-width="2.2"/><line x1="464.7" y1="518.0" x2="464.7" y2="525.0" stroke="currentColor" stroke-opacity="1" stroke-width="2"/><line x1="429.1" y1="526.0" x2="500.3" y2="526.0" stroke="currentColor" stroke-opacity="1" stroke-width="2"/><text x="332.7" y="449.0" font-size="12" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Second screen</text><path d="M330.7 509.0 V459.0 Q330.7 456.0 333.7 456.0 H377.7 Q380.7 456.0 380.7 459.0 V473.0 H409.7 Q412.7 473.0 412.7 476.0 V509.0 Q412.7 512.0 409.7 512.0 H333.7 Q330.7 512.0 330.7 509.0 Z" fill="currentColor" fill-opacity=".16" stroke="currentColor" stroke-width="1.5"/><text x="355.7" y="468.4" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1" font-weight="600">Space 4</text><path d="M421.7 509.0 V459.0 Q421.7 456.0 424.7 456.0 H468.7 Q471.7 456.0 471.7 459.0 V473.0 H500.7 Q503.7 473.0 503.7 476.0 V509.0 Q503.7 512.0 500.7 512.0 H424.7 Q421.7 512.0 421.7 509.0 Z" fill="none" stroke-opacity="0.5" stroke="currentColor" stroke-width="1"/><text x="446.7" y="468.4" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="0.8">Space 5</text><rect x="10.0" y="538.0" width="612.0" height="124.0" rx="8" fill="currentColor" fill-opacity="0.055" stroke="currentColor" stroke-opacity="0.22" stroke-width="1"/><text x="18.0" y="554.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Desktop 2</text><text x="80.0" y="554.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">bindable, bound to profile Focus, which holds 3 Spaces in total</text><rect x="27.3" y="562.0" width="280" height="86.0" rx="2" fill="currentColor" fill-opacity="0" stroke="currentColor" stroke-opacity="1" stroke-width="2.2"/><line x1="167.3" y1="648.0" x2="167.3" y2="655.0" stroke="currentColor" stroke-opacity="1" stroke-width="2"/><line x1="131.7" y1="656.0" x2="202.9" y2="656.0" stroke="currentColor" stroke-opacity="1" stroke-width="2"/><text x="35.3" y="579.0" font-size="12" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Main screen</text><path d="M33.3 639.0 V589.0 Q33.3 586.0 36.3 586.0 H80.3 Q83.3 586.0 83.3 589.0 V603.0 H112.3 Q115.3 603.0 115.3 606.0 V639.0 Q115.3 642.0 112.3 642.0 H36.3 Q33.3 642.0 33.3 639.0 Z" fill="currentColor" fill-opacity=".16" stroke="currentColor" stroke-width="1.5"/><text x="58.3" y="598.4" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1" font-weight="600">work</text><path d="M124.3 639.0 V589.0 Q124.3 586.0 127.3 586.0 H171.3 Q174.3 586.0 174.3 589.0 V603.0 H203.3 Q206.3 603.0 206.3 606.0 V639.0 Q206.3 642.0 203.3 642.0 H127.3 Q124.3 642.0 124.3 639.0 Z" fill="none" stroke-opacity="0.5" stroke="currentColor" stroke-width="1"/><text x="149.3" y="598.4" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="0.8">read</text><rect x="324.7" y="562.0" width="280" height="86.0" rx="2" fill="currentColor" fill-opacity="0" stroke="currentColor" stroke-opacity="1" stroke-width="2.2"/><line x1="464.7" y1="648.0" x2="464.7" y2="655.0" stroke="currentColor" stroke-opacity="1" stroke-width="2"/><line x1="429.1" y1="656.0" x2="500.3" y2="656.0" stroke="currentColor" stroke-opacity="1" stroke-width="2"/><text x="332.7" y="579.0" font-size="12" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">Second screen</text><path d="M330.7 639.0 V589.0 Q330.7 586.0 333.7 586.0 H377.7 Q380.7 586.0 380.7 589.0 V603.0 H409.7 Q412.7 603.0 412.7 606.0 V639.0 Q412.7 642.0 409.7 642.0 H333.7 Q330.7 642.0 330.7 639.0 Z" fill="currentColor" fill-opacity=".16" stroke="currentColor" stroke-width="1.5"/><text x="355.7" y="598.4" font-size="11" text-anchor="middle" fill="currentColor" fill-opacity="1" font-weight="600">browse</text><text x="10.0" y="682.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="0.8">One Desktop set spans every screen: all screens switch together, and every Desktop can be bound.</text><text x="10.0" y="700.0" font-size="11" text-anchor="start" fill="currentColor" fill-opacity="1" font-weight="600">On or off: one profile for the whole desk, and each screen shows one Space, the filled one.</text></svg>
</figure>

## Parking is not a Desktop move

When a Space is not being shown on any screen, KiwiDesk **parks**
its windows: it moves them into a bottom corner of their own
screen, leaving a hair of each at the edge, and moves them back
when their Space is shown again. The same park holds the windows
a Stack, Track, Grid or BSP layout cannot fit, which wait off
screen until they scroll in, and, under
`monocle.set_hide_style("park")`, the windows Monocle is not
showing.

**A parked window has not gone anywhere.** It is still on the
same macOS Desktop, still in the same KiwiDesk Space, still
listed in `get_state`. Parking is how a Space is hidden; it is
never how a window changes Desktop.

The only things that move a window between Desktops are macOS
itself and the two verbs that ask it to: `move_to_desktop(n[,
space])` and `move_to_desktop_and_follow(n[, space])`. A window
sent to another Desktop leaves KiwiDesk's view and rejoins its
Space when that Desktop is next shown — or the Space you named,
when you named one. It is reported gone with `reason: vanished`,
the same value a plain Desktop swipe produces.

KiwiDesk keeps knowing it is there, but does not draw it. The
Space Bar shows the Desktop you are looking at, so a window on
another Desktop leaves the bar, and *Hide empty Spaces* hides a
Space holding only such windows. *Open or Focus* still finds it:
it switches to that Desktop and gives the window the focus.

### With more than one screen

KiwiDesk parks in the bottom-right corner of the window's own
screen, and in the bottom-left corner when a screen sits to the
right and none to the left. A screen counts as beside it when
any part of it lies level with this screen. A parked window's top
sits about 48 pt above the bottom of the screen's usable area
(above a bottom Dock), a strip 1 pt wide shows, and the rest hangs
down and out past that corner. Keep the corner KiwiDesk picks
clear, with no screen beside it or below it; otherwise its parked
windows show on that screen.

A screen between two taller screens parks bottom-right, where the
right-hand screen reaches below it. Raising the right-hand screen
in System Settings ▸ Displays until its bottom sits more than
about 48 pt above that corner clears it; raising the left-hand
one changes nothing while both sides still have a screen. Parking
on another screen's free corner is not an option
([Accepted limitations](accepted-limitations.md)).

<figure>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="-8 -4 464 348" role="img" aria-label="Four screen arrangements, each problem beside its fix. Boxed in: a centre screen between two taller screens has no free corner, so its parked window shows on the right-hand screen; raising the right-hand screen clears that corner. A wider screen below sits under both corners; a narrower screen below, such as a laptop under a monitor, leaves them free." font-family="-apple-system, system-ui, sans-serif"><defs><pattern id="kd-park-hatch" width="3" height="3" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><line x1="0" y1="0" x2="0" y2="3" stroke="var(--sl-color-red, #e5484d)" stroke-width="1"/></pattern></defs><g transform="translate(0,0)"><rect x="34" y="18" width="36" height="60" rx="3.5" fill="none" stroke="currentColor" stroke-width="1.25" stroke-opacity="0.6"/><rect x="36.5" y="20.5" width="31" height="55" rx="1.5" fill="currentColor" fill-opacity="0.07"/><rect x="72" y="18" width="82" height="46" rx="3.5" fill="none" stroke="currentColor" stroke-width="1.25" stroke-opacity="0.6"/><rect x="74.5" y="20.5" width="77" height="41" rx="1.5" fill="currentColor" fill-opacity="0.07"/><rect x="156" y="18" width="36" height="60" rx="3.5" fill="none" stroke="currentColor" stroke-width="1.25" stroke-opacity="0.6"/><rect x="158.5" y="20.5" width="31" height="55" rx="1.5" fill="currentColor" fill-opacity="0.07"/><rect x="7" y="73" width="28" height="20" rx="2" fill="none" stroke="currentColor" stroke-opacity="0.65" stroke-dasharray="4 3"/><rect x="7.6" y="73.6" width="26.8" height="4" fill="currentColor" fill-opacity="0.25"/><circle cx="10.5" cy="75.6" r="1" fill="currentColor" fill-opacity="0.5"/><circle cx="13.5" cy="75.6" r="1" fill="currentColor" fill-opacity="0.5"/><circle cx="16.5" cy="75.6" r="1" fill="currentColor" fill-opacity="0.5"/><rect x="153" y="59" width="28" height="20" rx="2" fill="var(--sl-color-red, #e5484d)" fill-opacity="0.18" stroke="var(--sl-color-red, #e5484d)" stroke-width="1.25"/><rect x="156" y="59" width="25" height="19" fill="url(#kd-park-hatch)"/><path d="M172 62 L178 68 M178 62 L172 68" stroke="var(--sl-color-red, #e5484d)" stroke-width="1.5" stroke-linecap="round"/><rect x="153.6" y="59.6" width="26.8" height="4" fill="currentColor" fill-opacity="0.25"/><circle cx="156.5" cy="61.6" r="1" fill="currentColor" fill-opacity="0.5"/><circle cx="159.5" cy="61.6" r="1" fill="currentColor" fill-opacity="0.5"/><circle cx="162.5" cy="61.6" r="1" fill="currentColor" fill-opacity="0.5"/><rect x="191" y="73" width="28" height="20" rx="2" fill="none" stroke="currentColor" stroke-opacity="0.65" stroke-dasharray="4 3"/><rect x="191.6" y="73.6" width="26.8" height="4" fill="currentColor" fill-opacity="0.25"/><circle cx="194.5" cy="75.6" r="1" fill="currentColor" fill-opacity="0.5"/><circle cx="197.5" cy="75.6" r="1" fill="currentColor" fill-opacity="0.5"/><circle cx="200.5" cy="75.6" r="1" fill="currentColor" fill-opacity="0.5"/><text x="105.0" y="142" text-anchor="middle" font-size="14" font-weight="600" fill="currentColor"><tspan fill="var(--sl-color-red, #e5484d)">✗</tspan> Boxed in</text><text x="105.0" y="160" text-anchor="middle" font-size="12.5" fill="currentColor" fill-opacity="0.7">both of the centre's corners are taken</text></g><g transform="translate(230,0)"><rect x="34" y="34" width="36" height="60" rx="3.5" fill="none" stroke="currentColor" stroke-width="1.25" stroke-opacity="0.6"/><rect x="36.5" y="36.5" width="31" height="55" rx="1.5" fill="currentColor" fill-opacity="0.07"/><rect x="72" y="34" width="82" height="46" rx="3.5" fill="none" stroke="currentColor" stroke-width="1.25" stroke-opacity="0.6"/><rect x="74.5" y="36.5" width="77" height="41" rx="1.5" fill="currentColor" fill-opacity="0.07"/><rect x="156" y="2" width="36" height="60" rx="3.5" fill="none" stroke="currentColor" stroke-width="1.25" stroke-opacity="0.6"/><rect x="158.5" y="4.5" width="31" height="55" rx="1.5" fill="currentColor" fill-opacity="0.07"/><rect x="7" y="89" width="28" height="20" rx="2" fill="none" stroke="currentColor" stroke-opacity="0.65" stroke-dasharray="4 3"/><rect x="7.6" y="89.6" width="26.8" height="4" fill="currentColor" fill-opacity="0.25"/><circle cx="10.5" cy="91.6" r="1" fill="currentColor" fill-opacity="0.5"/><circle cx="13.5" cy="91.6" r="1" fill="currentColor" fill-opacity="0.5"/><circle cx="16.5" cy="91.6" r="1" fill="currentColor" fill-opacity="0.5"/><rect x="153" y="75" width="28" height="20" rx="2" fill="none" stroke="currentColor" stroke-opacity="0.65" stroke-dasharray="4 3"/><rect x="153.6" y="75.6" width="26.8" height="4" fill="currentColor" fill-opacity="0.25"/><circle cx="156.5" cy="77.6" r="1" fill="currentColor" fill-opacity="0.5"/><circle cx="159.5" cy="77.6" r="1" fill="currentColor" fill-opacity="0.5"/><circle cx="162.5" cy="77.6" r="1" fill="currentColor" fill-opacity="0.5"/><rect x="191" y="57" width="28" height="20" rx="2" fill="none" stroke="currentColor" stroke-opacity="0.65" stroke-dasharray="4 3"/><rect x="191.6" y="57.6" width="26.8" height="4" fill="currentColor" fill-opacity="0.25"/><circle cx="194.5" cy="59.6" r="1" fill="currentColor" fill-opacity="0.5"/><circle cx="197.5" cy="59.6" r="1" fill="currentColor" fill-opacity="0.5"/><circle cx="200.5" cy="59.6" r="1" fill="currentColor" fill-opacity="0.5"/><text x="105.0" y="142" text-anchor="middle" font-size="14" font-weight="600" fill="currentColor"><tspan>✓</tspan> Right-hand screen raised</text><text x="105.0" y="160" text-anchor="middle" font-size="12.5" fill="currentColor" fill-opacity="0.7">its bottom 48 pt above the centre's</text></g><g transform="translate(0,172)"><rect x="64" y="14" width="82" height="48" rx="3.5" fill="none" stroke="currentColor" stroke-width="1.25" stroke-opacity="0.6"/><rect x="66.5" y="16.5" width="77" height="43" rx="1.5" fill="currentColor" fill-opacity="0.07"/><rect x="28" y="64" width="154" height="52" rx="3.5" fill="none" stroke="currentColor" stroke-width="1.25" stroke-opacity="0.6"/><rect x="30.5" y="66.5" width="149" height="47" rx="1.5" fill="currentColor" fill-opacity="0.07"/><rect x="145" y="57" width="28" height="20" rx="2" fill="var(--sl-color-red, #e5484d)" fill-opacity="0.18" stroke="var(--sl-color-red, #e5484d)" stroke-width="1.25"/><rect x="145" y="64" width="28" height="13" fill="url(#kd-park-hatch)"/><path d="M164 60 L170 66 M170 60 L164 66" stroke="var(--sl-color-red, #e5484d)" stroke-width="1.5" stroke-linecap="round"/><rect x="145.6" y="57.6" width="26.8" height="4" fill="currentColor" fill-opacity="0.25"/><circle cx="148.5" cy="59.6" r="1" fill="currentColor" fill-opacity="0.5"/><circle cx="151.5" cy="59.6" r="1" fill="currentColor" fill-opacity="0.5"/><circle cx="154.5" cy="59.6" r="1" fill="currentColor" fill-opacity="0.5"/><rect x="181" y="111" width="28" height="20" rx="2" fill="none" stroke="currentColor" stroke-opacity="0.65" stroke-dasharray="4 3"/><rect x="181.6" y="111.6" width="26.8" height="4" fill="currentColor" fill-opacity="0.25"/><circle cx="184.5" cy="113.6" r="1" fill="currentColor" fill-opacity="0.5"/><circle cx="187.5" cy="113.6" r="1" fill="currentColor" fill-opacity="0.5"/><circle cx="190.5" cy="113.6" r="1" fill="currentColor" fill-opacity="0.5"/><text x="105.0" y="142" text-anchor="middle" font-size="14" font-weight="600" fill="currentColor"><tspan fill="var(--sl-color-red, #e5484d)">✗</tspan> Wider screen below</text><text x="105.0" y="160" text-anchor="middle" font-size="12.5" fill="currentColor" fill-opacity="0.7">it sits under both corners</text></g><g transform="translate(230,172)"><rect x="30" y="14" width="150" height="52" rx="3.5" fill="none" stroke="currentColor" stroke-width="1.25" stroke-opacity="0.6"/><rect x="32.5" y="16.5" width="145" height="47" rx="1.5" fill="currentColor" fill-opacity="0.07"/><rect x="70" y="68" width="70" height="42" rx="3.5" fill="none" stroke="currentColor" stroke-width="1.25" stroke-opacity="0.6"/><rect x="72.5" y="70.5" width="65" height="37" rx="1.5" fill="currentColor" fill-opacity="0.07"/><rect x="179" y="61" width="28" height="20" rx="2" fill="none" stroke="currentColor" stroke-opacity="0.65" stroke-dasharray="4 3"/><rect x="179.6" y="61.6" width="26.8" height="4" fill="currentColor" fill-opacity="0.25"/><circle cx="182.5" cy="63.6" r="1" fill="currentColor" fill-opacity="0.5"/><circle cx="185.5" cy="63.6" r="1" fill="currentColor" fill-opacity="0.5"/><circle cx="188.5" cy="63.6" r="1" fill="currentColor" fill-opacity="0.5"/><rect x="139" y="105" width="28" height="20" rx="2" fill="none" stroke="currentColor" stroke-opacity="0.65" stroke-dasharray="4 3"/><rect x="139.6" y="105.6" width="26.8" height="4" fill="currentColor" fill-opacity="0.25"/><circle cx="142.5" cy="107.6" r="1" fill="currentColor" fill-opacity="0.5"/><circle cx="145.5" cy="107.6" r="1" fill="currentColor" fill-opacity="0.5"/><circle cx="148.5" cy="107.6" r="1" fill="currentColor" fill-opacity="0.5"/><text x="105.0" y="142" text-anchor="middle" font-size="14" font-weight="600" fill="currentColor"><tspan>✓</tspan> Narrower screen below</text><text x="105.0" y="160" text-anchor="middle" font-size="12.5" fill="currentColor" fill-opacity="0.7">e.g. a laptop under a monitor</text></g></svg>
<figcaption>A dashed window hangs into empty space; a hatched red one shows on another screen.</figcaption>
</figure>

AeroSpace's [proper monitor arrangement
guide](https://nikitabobko.github.io/AeroSpace/guide#proper-monitor-arrangement)
shows the same rule with more arrangements.

## Every profile keeps its own arrangement

Two profiles can each define a Space called `1` — or `Work` —
and it is one Space, which wears the settings of the profile that
is live. Where your windows go is each profile's own: KiwiDesk files
which Space each window was in under the profile you are leaving
and puts them back when you return. Give two Spaces different
names to keep them apart.

The full rules are in the [Lua reference](lua-reference.md)
▸ *Space Reconciliation*.
