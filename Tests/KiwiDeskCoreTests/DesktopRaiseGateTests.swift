import Foundation
import Testing

@testable import KiwiDeskCore

/// The Desktop raise gate (#1345): raising a window the
/// compositor hosts on a Desktop nobody shows makes macOS switch
/// to it, so `raiseWindow` refuses such a raise ahead of every
/// focus path. The verdict is the compositor's — state still held
/// the departed window on the device, its app's destroy seconds
/// behind the swipe. Serialized: the topology override is
/// process-global.
///
/// The #888 topology: Desktops 10 (shown) and 11 on display A,
/// 20 (shown) and 21 on display B.
@Suite("Desktop raise gate (#1345)", .serialized)
@MainActor
struct DesktopRaiseGateTests {
    private static let refusalNeedle = "refused"

    private func makeCore() -> KiwiCore {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-raise-gate-\(UUID().uuidString)"
                )
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(1), pid: 1, appName: "App")
            )
        )
        return core
    }

    @Test("Hosted on a Space no display shows crosses Desktops")
    func unshownCrosses() {
        let core = makeCore()
        defer { NativeSpaces.spacesOverride = nil }
        core.desktopMemory.readWindowSpace = { _ in .hosted(11) }
        #expect(core.raiseCrossesDesktops(WindowID(1)))
    }

    @Test("Shown on either display, gone, or unreadable never crosses")
    func shownGoneAndUnknownDoNotCross() {
        let core = makeCore()
        defer { NativeSpaces.spacesOverride = nil }
        for reading in [
            WindowSpaceReading.hosted(10), .hosted(20), .gone,
            .unavailable,
        ] {
            core.desktopMemory.readWindowSpace = { _ in reading }
            #expect(
                !core.raiseCrossesDesktops(WindowID(1)),
                "\(reading)"
            )
        }
    }

    /// No topology (no SkyLight) is unknown, never a refusal —
    /// the AX fallback host must keep every raise.
    @Test("Without a topology nothing crosses")
    func noTopologyDoesNotCross() {
        let core = makeCore()
        defer { NativeSpaces.spacesOverride = nil }
        NativeSpaces.spacesOverride = []
        core.desktopMemory.readWindowSpace = { _ in .hosted(11) }
        #expect(!core.raiseCrossesDesktops(WindowID(1)))
    }

    /// The consumer: `focusWindow` reaches the raise through
    /// `raiseWindow`, which refuses and says so. The log is the
    /// observable — a fixture id has no AX element, so the raise
    /// itself is invisible here either way.
    @Test("focusWindow refuses a raise that would switch Desktops")
    func focusWindowRefuses() {
        let core = makeCore()
        defer { NativeSpaces.spacesOverride = nil }
        core.desktopMemory.readWindowSpace = { _ in .hosted(11) }
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.focusWindow(WindowID(1), warp: false)
        #expect(log.contains { $0.contains(Self.refusalNeedle) })
    }

    @Test("focusWindow raises a shown window without a word")
    func focusWindowRaisesShown() {
        let core = makeCore()
        defer { NativeSpaces.spacesOverride = nil }
        core.desktopMemory.readWindowSpace = { _ in .hosted(10) }
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.focusWindow(WindowID(1), warp: false)
        #expect(!log.contains { $0.contains(Self.refusalNeedle) })
    }
}
