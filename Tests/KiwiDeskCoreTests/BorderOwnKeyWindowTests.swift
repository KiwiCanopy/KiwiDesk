import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The focused ring stands down while an own key window that
/// is NOT the focus anchor is active (#933): in Sparkle's
/// update flow the progress window's close re-points state
/// focus at the background survivor (#929) and no focus event
/// re-points it at the alert, so the anchor goes stale — the
/// ring must not keep drawing around it behind the alert. An
/// own key window that IS the anchor (the Settings window)
/// keeps its ring.
@Suite("Border own-key-window stand-down (#933)")
@MainActor
struct BorderOwnKeyWindowTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)

    private var slots: [(id: WindowID, frame: CGRect)] {
        [
            (w1, CGRect(x: 0, y: 0, width: 100, height: 100)),
            (w2, CGRect(x: 200, y: 0, width: 100, height: 100)),
        ]
    }

    @Test("Suppression drops the focused ring")
    func suppressionDropsFocusedRing() {
        let result = KiwiCore.borderSpecs(
            style: BorderStyle(),
            focused: w1,
            slots: slots,
            floating: [],
            overlays: [],
            fullscreen: [],
            isMonocle: false,
            focusedRingSuppressed: true
        )
        #expect(result.isEmpty)
    }

    @Test("Suppression demotes the anchor to an unfocused ring")
    func suppressionDemotesAnchor() {
        var style = BorderStyle()
        style.unfocusedEnabled = true
        let result = KiwiCore.borderSpecs(
            style: style,
            focused: w1,
            slots: slots,
            floating: [],
            overlays: [],
            fullscreen: [],
            isMonocle: false,
            focusedRingSuppressed: true
        )
        #expect(result.count == 2)
        #expect(
            result.allSatisfy {
                $0.colorHex == style.unfocusedColor
            }
        )
    }

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-own-key-border-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        for id: UInt32 in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: w1)!
        core.state.workspaces.focus(w1, in: space)
        return core
    }

    @Test("An own UNTRACKED key window stands the ring down")
    func ownUntrackedKeyWindowSuppresses() {
        let core = makeCore()
        // isDialog FALSE on purpose: the ring reads the broad
        // number facet — ANY own key window stales the anchor,
        // the ⌃⌥K panel included — so this must suppress even
        // outside the dialog class the raise reads (#935). A
        // ring "simplified" onto the dialog facet reds here.
        core.eventLoop.ownKeyWindow = {
            OwnKeyWindowReading(number: 999_999, isDialog: false)
        }
        let specs = core.desiredBorderSpecs()
        #expect(
            !specs.contains {
                $0.colorHex
                    == core.tiler.settings.borderStyle
                    .focusedColor
            }
        )
    }

    @Test("A TRACKED own key window — the anchor — keeps its ring")
    func trackedOwnKeyWindowKeepsRing() {
        let core = makeCore()
        // The ring reads the NUMBER facet alone (#935): the
        // marked Settings window is no dialog, and its ring
        // never depended on that facet.
        core.eventLoop.ownKeyWindow = { [self] in
            OwnKeyWindowReading(
                number: Int(w1.raw),
                isDialog: false
            )
        }
        let specs = core.desiredBorderSpecs()
        #expect(specs.contains { $0.window == w1 })
    }

    @Test("No own key window leaves the ring in place")
    func noOwnKeyWindowKeepsRing() {
        let core = makeCore()
        core.eventLoop.ownKeyWindow = { nil }
        let specs = core.desiredBorderSpecs()
        #expect(specs.contains { $0.window == w1 })
    }
}
