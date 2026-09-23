import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An App Rule files an app's windows but never its raised-layer
/// popups (#1602): a popup menu filed into a Space that is not
/// shown is parked the moment it appears, which read on device as
/// Telegram's right-click menu closing on its own. The skip is
/// scoped to the measured shape by owner ruling (2026-09-23): a
/// layer-0 dialog or an accessory app's window keeps its rule.
@Suite("A raised-layer popup ignores its app's rule (#1602)")
struct TransientOverlayRuleTests {
    private let shown = SpaceID("1")
    private let ruled = SpaceID("2")
    private let bundle = "ru.keepcoder.telegram"

    /// Two Spaces, the first shown, and a rule filing the app into
    /// the second.
    private func makeState() -> StateCoordinator {
        var state = StateCoordinator()
        state.workspaces.ensureSpace(shown)
        state.workspaces.ensureSpace(ruled)
        state.appRules[bundle] = ruled
        return state
    }

    private func window(
        _ id: UInt32,
        overlay: Bool,
        raised: Bool,
        title: String = ""
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: 7,
            appName: "Telegram",
            appBundleID: bundle,
            title: title,
            frame: CGRect(x: 0, y: 0, width: 200, height: 200),
            isFloating: overlay,
            isTransientOverlay: overlay,
            isRaisedLayer: raised
        )
    }

    /// The control: without it, every clause below would also pass
    /// on a rule that files nothing at all.
    @Test("a window of the app still follows its rule")
    func windowFollowsTheRule() {
        var state = makeState()
        #expect(state.workspaces.activeSpace == shown)
        state.apply(
            .windowCreated(window(1, overlay: false, raised: false))
        )
        #expect(state.workspaces.space(of: WindowID(1)) == ruled)
    }

    @Test("a raised-layer popup of the app opens where you are")
    func popupStaysOnTheShownSpace() {
        var state = makeState()
        state.apply(
            .windowCreated(window(2, overlay: true, raised: true))
        )
        #expect(
            state.workspaces.space(of: WindowID(2)) == shown,
            Comment(
                rawValue:
                    "the popup was filed into its app's rule Space, "
                    + "which is not shown, so it is parked as it opens"
            )
        )
    }

    /// A layer-0 overlay — a dialog, a panel, an accessory app's
    /// window — is the reach the ruling leaves on the rule.
    @Test("a layer-0 overlay still follows the rule")
    func layerZeroOverlayFollowsTheRule() {
        var state = makeState()
        state.apply(
            .windowCreated(window(3, overlay: true, raised: false))
        )
        #expect(state.workspaces.space(of: WindowID(3)) == ruled)
    }

    /// The skip reads STATE, not the incoming snapshot: a restored
    /// tiled intent clears the overlay flag ahead of the target, so
    /// the window is a window again and follows the rule.
    @Test("a popup restored as tiled follows the rule")
    func restoredTiledIntentFollowsTheRule() {
        var state = makeState()
        let popup = window(4, overlay: true, raised: true, title: "T")
        state.rememberedFloating[
            StateCoordinator.WindowIdentity(of: popup)
        ] = false
        state.apply(.windowCreated(popup))
        #expect(state.windows[WindowID(4)]?.isTransientOverlay == false)
        #expect(state.workspaces.space(of: WindowID(4)) == ruled)
    }

    /// The tracker is where the layer is read, from a live element
    /// no fixture can build, so the fold clauses above hand the
    /// field in and would stay green with the assignment gone. Read
    /// from code lines only, so a comment cannot satisfy it.
    @Test("the tracker records the raised layer")
    func trackerRecordsTheLayer() throws {
        let source = try String(
            contentsOf: scriptFixtureRepoRoot()
                .appendingPathComponent(
                    "Sources/KiwiDeskCore/Events/EventLoop+Tracking.swift"
                ),
            encoding: .utf8
        )
        let code = source.split(separator: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        #expect(code.count > 50, "the tracker read empty")
        #expect(
            code.contains {
                $0.contains("window.isRaisedLayer = (layer ?? 0) != 0")
            },
            Comment(
                rawValue:
                    "the tracker no longer records the layer, so "
                    + "every popup follows its app's rule again"
            )
        )
    }
}
