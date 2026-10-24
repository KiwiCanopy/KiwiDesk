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
    /// The pointer pinned off every window, so the lit state reads
    /// the open list alone, never the host's resting pointer.
    init() {
        LiquidGlassGate.override = { false }
        BarHoverHit.pointerOverride = { _ in BarHoverHit.offWindow }
    }

    /// The active Mail item first, then a Finder item of `members`
    /// — not active, so its click is live — re-hosted in the rig's
    /// window and wired to its peek.
    private func finder(
        _ core: KiwiCore,
        _ rig: BarPeekRig,
        _ actions: AppBarItemActions,
        members: [UInt32],
        titleCut: Bool = false
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
                        members: members.map(WindowID.init),
                        titleCut: titleCut
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

    /// A press and release, windowless unless `releasedAt` names a
    /// point in `view`'s window, where the release lands.
    private func click(
        _ view: AppBarItemView,
        releasedAt: CGPoint? = nil
    ) throws {
        let event = { (type: NSEvent.EventType, at: CGPoint?) in
            NSEvent.mouseEvent(
                with: type,
                location: at ?? .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: at == nil ? 0 : view.window?.windowNumber ?? 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        }
        view.mouseDown(with: try #require(event(.leftMouseDown, nil)))
        view.mouseUp(with: try #require(event(.leftMouseUp, releasedAt)))
    }

    /// A press dragged off a group and released elsewhere cancels,
    /// as a button's does (#2044) — a float group never drags.
    @Test("A release off a group opens nothing")
    func releaseOffAGroupCancels() throws {
        let core = makeBarCore()
        let rig = BarPeekRig()
        defer { rig.close() }
        let actions = AppBarItemActions()
        defer { withExtendedLifetime(actions) {} }
        let group = try finder(core, rig, actions, members: [1, 2])
        let off = group.convert(
            CGPoint(x: group.bounds.maxX + 40, y: group.bounds.midY),
            to: nil
        )
        try click(group, releasedAt: off)
        #expect(rig.peek.shown == nil)
        let inside = group.convert(
            CGPoint(x: group.bounds.midX, y: group.bounds.midY),
            to: nil
        )
        try click(group, releasedAt: inside)
        #expect(rig.peek.shown?.view === group, "a release inside opens")
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

    /// A single item that cuts its title has a peek source — a label
    /// — which the click must still read as a select.
    @Test("A single item's click still selects its window")
    func singleClickSelects() throws {
        let core = makeBarCore()
        let rig = BarPeekRig()
        defer { rig.close() }
        let actions = AppBarItemActions()
        defer { withExtendedLifetime(actions) {} }
        let single = try finder(
            core,
            rig,
            actions,
            members: [1],
            titleCut: true
        )
        try #require(single.peekSource != nil)
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
        let single = try finder(
            core,
            rig,
            actions,
            members: [1],
            titleCut: true
        )
        try #require(single.peekSource != nil)
        #expect(!BarPeek.releaseDecides(single))
        #expect(!BarPeek.releaseDecides(nil))
    }
}
