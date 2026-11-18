import Foundation

@testable import KiwiDeskCore

/// `makeTestCore`'s compositor and Desktop pins (#1146, #1147,
/// #2937), split from `TestCore.swift` at the 350-line ceiling
/// and twinned like it (`MachineTouchTests`).
@MainActor
func pinDesktopReads(_ core: KiwiCore) {
    // Same class, sixth time (#1146): the compositor reads behind the
    // gone classifier, the away ledger, the heal stand-down and the
    // shelf stand-down's host Space (#2937) default LIVE. Pin "no
    // compositor", and the Desktop reading to no reading unless a
    // suite states a topology override, whose unstated reads stay
    // live (`NativeSpaces.desktopSnapshot`).
    core.desktopMemory.readWindowSpace = { _ in .unavailable }
    core.desktopMemory.readOffShown = { _ in false }
    core.desktopMemory.liveSpaceIsUser = { _ in true }
    // The two reads behind every stand-down and the cold-start bar
    // (#3442): a display's UUID read once per process, and the
    // active Space a user Desktop unless a suite states otherwise.
    core.desktopMemory.readDisplayUUID = { display in
        guard NativeSpaces.displayUUIDOverride == nil else {
            return NativeSpaces.displayUUID(for: display)
        }
        if let known = testDisplayUUIDs[display] { return known }
        let live = NativeSpaces.displayUUID(for: display)
        testDisplayUUIDs[display] = live
        return live
    }
    core.desktopMemory.readActiveSpaceIsUser = {
        statesNoTopology
            && NativeSpaces.activeSpaceIsUserOverride == nil
            ? true
            : NativeSpaces.activeSpaceIsUser()
    }
    core.desktopMemory.readDesktops = {
        statesNoTopology
            ? DesktopSnapshot(
                authority: nil,
                mainUUID: nil,
                mainCurrentSpace: nil,
                currentSpaces: [:],
                spaces: []
            )
            : NativeSpaces.desktopSnapshot()
    }
    // The Displays arrangement (#2756): no screens to read, and a
    // write that never reaches the host's screens.
    core.tiler.readArrangement = { _ in [] }
    core.tiler.writeArrangement = { _ in false }
    core.windowIsOnScreen = { _ in nil }
    core.windowIsOnShownDesktop = { _ in nil }
    core.vision.listWindows = { [] }
    core.desktopMemory.readCensus = { _ in nil }
    // Same class, seventh time (#1147): the Desktop stamp write
    // defaults LIVE, and a fixture space id is a real Desktop id
    // on the host — Desktop 1 is id 1 — so any suite that boots a
    // core or switches Desktops would stamp the developer's own
    // Desktops through the real bridge. Pin "the write is
    // refused", which is exactly the bridge-absent host; the
    // stamping suite takes the live writer back explicitly, with
    // the bridge itself faked.
    core.desktopMemory.writeStamp = { _, _ in false }
}

/// Whether a suite states none of the topology overrides the live
/// Desktop reading takes, so `pinDesktopReads` hands it no reading.
private var statesNoTopology: Bool {
    NativeSpaces.spacesOverride == nil
        && NativeSpaces.activeSpaceIDOverride == nil
        && NativeSpaces.activeDesktopNumberOverride == nil
        && NativeSpaces.mainDisplayUUIDOverride == nil
}

/// `pinDesktopReads`' per-process memo of each display's UUID.
@MainActor private var testDisplayUUIDs: [DisplayID: String?] = [:]
