import Foundation

/// The `native_space_change` emission, with its #888 display
/// dimension — split from `KiwiCore+NativeSpaces.swift` for the
/// file ceiling.
extension KiwiCore {
    /// Emits one `native_space_change` per switch notification.
    ///
    /// Payload: `native_space` (the Desktop now current on the
    /// display that switched), `monitor` (that display's
    /// 1-based positional number — 1 is the main display, the
    /// same numbering the Lua screen API documents), `profile`.
    /// Which display switched is the diff of the per-display
    /// current Spaces against the last emit's snapshot; the
    /// main display answers when nothing diffed (a repeated
    /// notification, shared mode's synthetic managed display,
    /// or no SkyLight at all — every mode where the global
    /// number is the main display's). If one notification
    /// coalesces several displays' switches — a display
    /// connect, which fires the monitor-change machinery
    /// anyway — the main display outranks, then the first
    /// changed display in sorted-UUID order, so the pick is
    /// deterministic.
    func emitNativeSpaceChange() {
        let spaces = NativeSpaces.allSpaces()
        let current = [String: SkyLight.SpaceID](
            spaces.filter(\.isCurrent).map {
                ($0.displayUUID, $0.id)
            },
            uniquingKeysWith: { first, _ in first }
        )
        let previous = desktopMemory.lastDisplaySpaces
        desktopMemory.lastDisplaySpaces = current
        let changed =
            current
            .filter { $0.value != previous[$0.key] }
            .keys.sorted()
        let mainUUID = NativeSpaces.mainDisplayUUID()
        let switched: String? = {
            if let mainUUID, changed.contains(mainUUID) {
                return mainUUID
            }
            return changed.first ?? mainUUID
        }()
        // The switched display's new Desktop; the main-display
        // authority answers when the topology cannot (no
        // SkyLight). Nil — a fullscreen/system space — emits
        // nothing, as before #888.
        let number =
            switched
            .flatMap { current[$0] }
            .flatMap { NativeSpaces.number(of: $0, in: spaces) }
            ?? NativeSpaces.activeDesktopNumber()
        guard let number else { return }
        let monitor =
            switched.flatMap { monitorNumber(forUUID: $0) } ?? 1
        bus.emit(
            .nativeSpaceChange,
            data: .object([
                "native_space": .number(Double(number)),
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
    private func monitorNumber(forUUID uuid: String) -> Int? {
        let ordered = PositionalDisplays.ordered(
            state.workspaces.allDisplays,
            mainID: PositionalDisplays.liveMainID
        )
        return
            ordered
            .firstIndex {
                NativeSpaces.displayUUID(for: $0.id) == uuid
            }
            .map { $0 + 1 }
    }
}
