import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An App Rule files an app's windows but never its popups: a
/// popup filed into a Space that is not shown is parked the moment
/// it appears, which read on device as Telegram's right-click menu
/// (#1602, raised layer) and a Chromium extension popup (#2475,
/// layer 0, no title-bar button) closing on their own. The skip is
/// scoped by owner rulings (2026-09-23, 2026-10-20): a layer-0
/// overlay WITH a title-bar button — a dialog, a panel — keeps its
/// rule, and so does one whose button read did not answer.
@Suite("A popup ignores its app's rule (#1602, #2475)")
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
        button: Bool? = true,
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
            isRaisedLayer: raised,
            hasTitlebarButton: button
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

    /// A layer-0 overlay with a title-bar button — a dialog, a
    /// panel, an accessory app's window — is the reach the rulings
    /// leave on the rule.
    @Test("a layer-0 overlay with a button still follows the rule")
    func layerZeroOverlayFollowsTheRule() {
        var state = makeState()
        state.apply(
            .windowCreated(window(3, overlay: true, raised: false))
        )
        #expect(state.workspaces.space(of: WindowID(3)) == ruled)
    }

    /// A Chromium extension popup: layer 0, no title-bar button
    /// (#2475, measured on Brave with Bitwarden, 2026-10-20).
    @Test("a buttonless layer-0 popup opens where you are")
    func buttonlessPopupStaysOnTheShownSpace() {
        var state = makeState()
        state.apply(
            .windowCreated(
                window(4, overlay: true, raised: false, button: false)
            )
        )
        #expect(
            state.workspaces.space(of: WindowID(4)) == shown,
            Comment(
                rawValue:
                    "the extension popup was filed into its app's "
                    + "rule Space, which is not shown, so it is "
                    + "parked as it opens"
            )
        )
    }

    /// A read that did not answer is no verdict: the window keeps
    /// its rule rather than being guessed a popup.
    @Test("an overlay whose button read failed follows the rule")
    func unreadButtonFollowsTheRule() {
        var state = makeState()
        state.apply(
            .windowCreated(
                window(5, overlay: true, raised: false, button: nil)
            )
        )
        #expect(state.workspaces.space(of: WindowID(5)) == ruled)
    }

    /// The skip is a popup's: a window detection does not call an
    /// overlay keeps its rule however bare its title bar.
    @Test("a buttonless window that is no overlay follows the rule")
    func buttonlessWindowFollowsTheRule() {
        var state = makeState()
        state.apply(
            .windowCreated(
                window(6, overlay: false, raised: false, button: false)
            )
        )
        #expect(state.workspaces.space(of: WindowID(6)) == ruled)
    }

    /// The tracker is where the layer is read, from a live element
    /// no fixture can build, so the fold clauses above hand the
    /// field in and would stay green with the assignment gone. Read
    /// from code lines only, so a comment cannot satisfy it.
    @Test("the tracker records the raised layer and the button")
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
        #expect(
            code.contains {
                $0.contains(
                    "window.hasTitlebarButton = traits??.hasTitlebarButton"
                )
            },
            Comment(
                rawValue:
                    "the tracker no longer records the title-bar "
                    + "button, so an extension popup follows its "
                    + "app's rule again (#2475)"
            )
        )
        // The created-window notification tracks with no arrival,
        // so the popup's button comes from the fallback read; one
        // run pins that read AND its hand-off to the shadow rule,
        // which then reads nothing itself (one AX read, not two).
        let joined = code.map {
            $0.trimmingCharacters(in: .whitespaces)
        }.joined(separator: " ")
        #expect(
            joined.contains(
                "let traits = arrival.map(\\.traits) "
                    + "?? .some(shadows.traits(element, window.id)) "
                    + "guard shadowVerdict( element, id: window.id, "
                    + "pid: pid, traits: traits ) == .window"
            ),
            Comment(
                rawValue:
                    "the synchronous track path no longer reads the "
                    + "button once and hands it on, so the popup "
                    + "records nil and follows its rule (#2475), or "
                    + "the shadow rule reads the traits a second time"
            )
        )
    }
}
