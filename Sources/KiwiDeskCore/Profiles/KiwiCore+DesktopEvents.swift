import Foundation

/// The `desktop_change` emission, with its #888 display
/// dimension — split from `KiwiCore+Desktops.swift` for the
/// file ceiling.
extension KiwiCore {
    /// Emits one `desktop_change` per switch notification.
    ///
    /// Payload: `desktop` (the Desktop now current on the
    /// display that switched), `screen` (that display's Screen N,
    /// the number a Lua display argument takes, #3647), `main`
    /// (whether it is the main display), `profile`.
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
    /// pairing one display's `screen` with another's
    /// `desktop` describes a switch that never happened
    /// (review, 2026-08-18).
    /// Sent once the switch's batch has tracked the arrivals, so a
    /// consumer re-querying on the event sees them (#2347).
    func emitDesktopChange(
        _ snapshot: DesktopSnapshot,
        changed: [String]
    ) {
        eventLoop.afterSwitchReads { [weak self] in
            self?.emitDesktopChangeNow(snapshot, changed: changed)
        }
    }

    private func emitDesktopChangeNow(
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
        // Screen N, so whether it is the main screen is its own
        // field (#3647, owner 2026-11-26). With no display to name —
        // shared mode's synthetic one, no SkyLight — the main
        // display answers; a display gone mid-switch names none.
        let isMain = switched == nil || switched == snapshot.mainUUID
        let screen =
            isMain
            ? mainScreenNumber(snapshot)
            : switched.flatMap { screenNumber(forUUID: $0) }
        let screenValue: JSONValue =
            screen.map { .number(Double($0)) } ?? .null
        let screenArg: LuaValue =
            screen.map { .number(Double($0)) } ?? .none
        bus.emit(
            .desktopChange,
            data: .object([
                "desktop": .number(Double(number)),
                "screen": screenValue,
                "main": .bool(isMain),
                "profile": profiles.currentName.map {
                    .string($0)
                } ?? .null,
            ]),
            luaArgs: [
                .number(Double(number)),
                screenArg,
                .bool(isMain),
            ]
        )
    }

    /// Screen N of the display with this SkyLight UUID (#3647);
    /// nil when no connected display carries it (unplugged
    /// mid-switch, or shared mode's synthetic identifier).
    private func screenNumber(forUUID uuid: String) -> Int? {
        state.workspaces.allDisplays
            .first { desktopMemory.readDisplayUUID($0.id) == uuid }
            .flatMap { screenNumber(of: $0.id) }
    }

    /// The main display's Screen N: the one the snapshot names, else
    /// the menu-bar screen.
    private func mainScreenNumber(_ snapshot: DesktopSnapshot) -> Int? {
        snapshot.mainUUID.flatMap(screenNumber(forUUID:))
            ?? screenNumber(of: PositionalDisplays.liveMainID)
    }
}
