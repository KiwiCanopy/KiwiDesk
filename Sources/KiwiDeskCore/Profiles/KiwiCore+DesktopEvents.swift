import Foundation

/// The `desktop_change` emission, with its #888 display
/// dimension — split from `KiwiCore+Desktops.swift` for the
/// file ceiling.
extension KiwiCore {
    /// Emits one `desktop_change` per switch notification.
    ///
    /// Payload: `desktop` (the Desktop now current on the
    /// display that switched), `monitor` (that display's 1-based
    /// positional number — 1 is the main display, the same
    /// numbering a Lua display argument takes), `profile`.
    ///
    /// Both inputs come from the handler's ONE topology reading:
    /// `snapshot` and the `changed` diff it derived. Which
    /// display switched is that diff; the main display answers
    /// when nothing diffed (a repeated notification, shared
    /// mode's synthetic managed display, or no SkyLight at all —
    /// every mode where the global number is the main display's).
    /// If one notification coalesces several displays' switches —
    /// a display connect, which fires the monitor-change
    /// machinery anyway — the main display outranks, then the
    /// first changed display in sorted-UUID order, so the pick is
    /// deterministic.
    ///
    /// **Nothing is emitted when the switched display's new Space
    /// has no Mission Control number** — it arrived on a
    /// fullscreen/system space, the pre-#888 silence. The number
    /// is never back-filled from another display: a payload
    /// pairing one display's `monitor` with another's
    /// `desktop` describes a switch that never happened
    /// (review, 2026-08-18).
    func emitDesktopChange(
        _ snapshot: DesktopSnapshot,
        changed: [String]
    ) {
        let switched: String? = {
            if let main = snapshot.mainUUID,
                changed.contains(main)
            {
                return main
            }
            return changed.first ?? snapshot.mainUUID
        }()
        // The switched display's new Desktop, numbered in the
        // same snapshot it was read from. Without a switched
        // display to name — no SkyLight, no display UUID — the
        // authority answers, which is that ladder's public
        // fallback rather than another display's number.
        let number =
            switched
            .flatMap { snapshot.currentSpaces[$0] }
            .flatMap { snapshot.number(of: $0) }
            ?? (switched == nil ? snapshot.authority : nil)
        guard let number else { return }
        let monitor =
            switched.flatMap {
                monitorNumber(
                    forUUID: $0,
                    mainUUID: snapshot.mainUUID
                )
            } ?? 1
        bus.emit(
            .desktopChange,
            data: .object([
                "desktop": .number(Double(number)),
                "monitor": .number(Double(monitor)),
                "profile": profiles.currentName.map {
                    .string($0)
                } ?? .null,
            ]),
            luaArgs: [
                .number(Double(number)),
                .number(Double(monitor)),
            ]
        )
    }

    /// Positional number of the display with this SkyLight
    /// UUID: 1 is the main display, secondaries follow
    /// left-to-right (`PositionalDisplays.ordered`). Nil when
    /// no connected display carries the UUID (unplugged
    /// mid-switch, or shared mode's synthetic identifier).
    ///
    /// Main arrives as the SNAPSHOT's `mainUUID` — the same
    /// value the switch attribution used, not merely the same
    /// seam re-read (review round 2, 2026-08-18) — so a switch
    /// cannot be attributed to one display and numbered as
    /// another.
    private func monitorNumber(
        forUUID uuid: String,
        mainUUID: String?
    ) -> Int? {
        let displays = state.workspaces.allDisplays
        let mainID = displays.first {
            NativeSpaces.displayUUID(for: $0.id) == mainUUID
        }?.id
        return
            PositionalDisplays
            .ordered(displays, mainID: mainID)
            .firstIndex {
                NativeSpaces.displayUUID(for: $0.id) == uuid
            }
            .map { $0 + 1 }
    }
}
