import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The temporal native-tab matcher (#308): a same-frame,
/// `hasTabGroup` vanish + appear in one reconcile is a tab switch →
/// re-key; everything else stays a normal destroy/create. Biased to
/// NOT merge.
@Suite("TabReconciler")
struct TabReconcilerTests {
    private let frame = CGRect(x: 10, y: 42, width: 849, height: 528)

    private func win(
        _ raw: UInt32,
        frame: CGRect,
        tabGroup: Bool = true
    ) -> TabWindow {
        TabWindow(id: WindowID(raw), frame: frame, hasTabGroup: tabGroup)
    }

    @Test("switch: same-frame tab-group vanish+appear → re-key")
    func switchRekeys() {
        let rekeys = TabReconciler.rekeys(
            vanished: [win(1, frame: frame)],
            appeared: [win(2, frame: frame)]
        )
        #expect(rekeys == [.init(from: WindowID(1), to: WindowID(2))])
    }

    @Test("close 2→1: carrier vanishes, single tab appears → re-key")
    func carrierVanishesNonGroupAppears() {
        // The survivor of a close-to-one-tab has no AXTabGroup of its
        // own yet, but the vanished side was a carrier — a tab group
        // on either side is enough (#308).
        let rekeys = TabReconciler.rekeys(
            vanished: [win(1, frame: frame)],
            appeared: [win(2, frame: frame, tabGroup: false)]
        )
        #expect(rekeys == [.init(from: WindowID(1), to: WindowID(2))])
    }

    @Test("open 1→2: single tab vanishes, carrier appears → re-key")
    func nonGroupVanishesCarrierAppears() {
        let rekeys = TabReconciler.rekeys(
            vanished: [win(1, frame: frame, tabGroup: false)],
            appeared: [win(2, frame: frame)]
        )
        #expect(rekeys == [.init(from: WindowID(1), to: WindowID(2))])
    }

    @Test("no tab group on either side → no merge")
    func neitherSideTabGroup() {
        let rekeys = TabReconciler.rekeys(
            vanished: [win(1, frame: frame, tabGroup: false)],
            appeared: [win(2, frame: frame, tabGroup: false)]
        )
        #expect(rekeys.isEmpty)
    }

    @Test("different frames do not merge")
    func frameMismatch() {
        let other = CGRect(x: 900, y: 42, width: 849, height: 528)
        let rekeys = TabReconciler.rekeys(
            vanished: [win(1, frame: frame)],
            appeared: [win(2, frame: other)]
        )
        #expect(rekeys.isEmpty)
    }

    @Test("frames within tolerance still merge")
    func toleranceMerges() {
        let nudged = CGRect(x: 11, y: 41, width: 849, height: 529)
        let rekeys = TabReconciler.rekeys(
            vanished: [win(1, frame: frame)],
            appeared: [win(2, frame: nudged)]
        )
        #expect(rekeys.count == 1)
    }

    @Test("whole-group close: vanish with no appear → no re-key")
    func wholeClose() {
        let rekeys = TabReconciler.rekeys(
            vanished: [win(1, frame: frame)],
            appeared: []
        )
        #expect(rekeys.isEmpty)
    }

    @Test("new window: appear with no vanish → no re-key")
    func newWindow() {
        let rekeys = TabReconciler.rekeys(
            vanished: [],
            appeared: [win(2, frame: frame)]
        )
        #expect(rekeys.isEmpty)
    }

    @Test("two groups switch at once → paired by frame")
    func twoGroups() {
        let other = CGRect(x: 900, y: 42, width: 849, height: 528)
        let rekeys = TabReconciler.rekeys(
            vanished: [win(1, frame: frame), win(3, frame: other)],
            appeared: [win(4, frame: other), win(2, frame: frame)]
        )
        #expect(rekeys.count == 2)
        #expect(
            rekeys.contains(
                .init(
                    from: WindowID(1),
                    to: WindowID(2)
                )
            )
        )
        #expect(
            rekeys.contains(
                .init(
                    from: WindowID(3),
                    to: WindowID(4)
                )
            )
        )
    }

    @Test("each appeared window is claimed at most once")
    func claimOnce() {
        // Two vanished at the same frame, one appeared: only the
        // lowest-id vanished pairs; the other stays a destroy.
        let rekeys = TabReconciler.rekeys(
            vanished: [win(5, frame: frame), win(1, frame: frame)],
            appeared: [win(9, frame: frame)]
        )
        #expect(rekeys == [.init(from: WindowID(1), to: WindowID(9))])
    }
}
