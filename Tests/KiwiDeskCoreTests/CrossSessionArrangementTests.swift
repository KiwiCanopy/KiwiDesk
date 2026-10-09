import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private typealias F = BootRestoreFixture

/// The cross-session match is pinned to the arrangement live at
/// arming, never the snapshot's (#1385): a login under another
/// arrangement than the logout's — docked, then undocked — would
/// otherwise close both late phases at once. They file as the
/// ordinary restore does: by Space name, never a mode (#1646).
@Suite("Cross-session arrangement pin (#1385)", .serialized)
@MainActor
struct CrossSessionArrangementTests: CrossSessionFixture {
    @Test(
        "A boot under another arrangement still files by name",
        .enabled(if: NSScreen.main != nil)
    )
    func foreignBootFilesByName() throws {
        let core = try #require(
            boot([
                window(20, "com.ide", "Preview"),
                window(21, "com.ide", "IDE"),
            ])
        )
        let live = core.buildProfile(name: "B", modes: nil)
        core.profiles.becameLive(live, fits: true)
        var captured = previous([
            (F.shown, "com.ide", "IDE"),
            (F.hidden, "com.ide", "Preview"),
            (F.hidden, "app.zen", "Zen Browser"),
        ])
        captured.arrangement = .profile("A")
        captured.spaces = captured.spaces.map { record in
            guard record.id == F.hidden.raw else { return record }
            return .init(
                space: Space(
                    id: F.hidden,
                    mode: .stack,
                    windows: record.windows.map(WindowID.init)
                )
            )
        }
        leave(captured, in: core)
        arrange(core)
        // B declares the hidden Space: it keeps B's mode.
        #expect(core.state.workspaces[F.hidden]?.mode == .bsp)
        core.handle(.windowCreated(window(30, "app.zen", "Zen Browser")))
        #expect(space(core, 30) == F.hidden)
        core.crossSessionSettlePass()
        #expect(space(core, 20) == F.hidden)
        #expect(space(core, 21) == F.shown)
    }
}
