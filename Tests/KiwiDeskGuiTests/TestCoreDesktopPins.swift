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
    // compositor", and the filed Desktop reading to the fixture's
    // own topology: a suite that states none reads no Desktop.
    core.desktopMemory.readWindowSpace = { _ in .unavailable }
    core.desktopMemory.readOffShown = { _ in false }
    core.desktopMemory.liveSpaceIsUser = { _ in true }
    core.desktopMemory.readDesktops = {
        NativeSpaces.spacesOverride == nil
            ? DesktopSnapshot(
                authority: nil,
                mainUUID: nil,
                mainCurrentSpace: nil,
                currentSpaces: [:],
                spaces: []
            )
            : NativeSpaces.desktopSnapshot()
    }
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
