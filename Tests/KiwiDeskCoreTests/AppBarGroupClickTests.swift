import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// An App Bar group's click (#2571 ▸ Ruling): it opens the group's
/// list and selects nothing until a row is picked, while a single
/// item's click still selects; the group stays lit while its list
/// shows, and a left press on it leaves the peek to its release.
@Suite("App Bar group click", .serialized)
@MainActor
struct AppBarGroupClickTests {
    init() {
        LiquidGlassGate.override = { false }
    }

    /// The active Mail item first, then a Finder item of `members`
    /// — not active, so its click is live — re-hosted in the rig's
    /// window and wired to its peek.
    private func finder(
        _ core: KiwiCore,
        _ rig: BarPeekRig,
        _ actions: AppBarItemActions,
        members: [UInt32]
    ) throws -> AppBarItemView {
        core.appBars.sync([
            paintedAppBar(
                items: [
                    AppBarOverlay.Item(
                        id: WindowID(9),
                        text: "Mail",
                        icon: nil
                    ),
                    AppBarOverlay.Item(
                        id: WindowID(members[0]),
                        text: "Finder",
                        icon: nil,
                        count: members.count,
                        members: members.map(WindowID.init)
                    ),
                ]
            )
        ])
        let overlay = try #require(
            core.appBars.overlayForTesting(barTitleDisplay)
        )
        let view = try #require(overlay.itemViews.last)
        actions.peek = rig.peek
        view.itemActions = actions
        rig.item.addSubview(view)
        view.layout()
        return view
    }

    private func click(_ view: AppBarItemView) throws {
        let event = { (type: NSEvent.EventType) in
            NSEvent.mouseEvent(
                with: type,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        }
        view.mouseDown(with: try #require(event(.leftMouseDown)))
        view.mouseUp(with: try #require(event(.leftMouseUp)))
    }

    @Test("A group's click opens its list and selects nothing")
    func groupClickOpensTheList() throws {
        let core = makeBarCore()
        let rig = BarPeekRig()
        defer { rig.close() }
        let actions = AppBarItemActions()
        defer { withExtendedLifetime(actions) {} }
        let group = try finder(core, rig, actions, members: [1, 2])
        var selected: [WindowID] = []
        group.onSelect = { selected.append($0) }
        try click(group)
        #expect(selected.isEmpty)
        #expect(rig.peek.shown?.view === group)
        #expect(rig.shownTitles == ["Window 1", "Window 2"])
        #expect(rig.peek.holdsOpen(group))
        #expect(group.isHovered, "lit while its list shows")
        rig.peek.dismiss()
        #expect(!group.isHovered, "unlit as it closes")
    }

    @Test("A single item's click still selects its window")
    func singleClickSelects() throws {
        let core = makeBarCore()
        let rig = BarPeekRig()
        defer { rig.close() }
        let actions = AppBarItemActions()
        defer { withExtendedLifetime(actions) {} }
        let single = try finder(core, rig, actions, members: [1])
        var selected: [WindowID] = []
        single.onSelect = { selected.append($0) }
        try click(single)
        #expect(selected == [WindowID(1)])
        #expect(rig.peek.shown == nil)
    }

    /// A left press on a group leaves the peek to its release, so a
    /// second click can close the list it opened; a single item's
    /// press closes a peek at once, as any press outside it does.
    @Test("A left press on a group leaves the peek to its release")
    func pressOnAGroupIsSpared() throws {
        let core = makeBarCore()
        let rig = BarPeekRig()
        defer { rig.close() }
        let actions = AppBarItemActions()
        defer { withExtendedLifetime(actions) {} }
        let group = try finder(core, rig, actions, members: [1, 2])
        #expect(BarPeek.releaseDecides(group))
        #expect(BarPeek.releaseDecides(group.subviews.first))
        let single = try finder(core, rig, actions, members: [1])
        #expect(!BarPeek.releaseDecides(single))
        #expect(!BarPeek.releaseDecides(nil))
    }
}
