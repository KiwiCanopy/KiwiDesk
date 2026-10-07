import CoreGraphics
import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk

/// The Shortcuts & Gestures jump chips (#1520): which groups get
/// one, which chip the bar marks as the page scrolls, and the
/// wiring a reading of the pure parts cannot see.
@Suite("Shortcuts jump chips")
@MainActor
struct ShortcutsJumpTests {
    /// The ruled chips, in page order, labelled by each group's
    /// own title control — Layers is scope, not a destination.
    @Test("the chips are the ruled groups, titled by their cards")
    func chipsAreTheRuledGroups() {
        #expect(
            ShortcutsJumpGroup.allCases.map(\.control.id) == [
                SettingsCatalog.shortcuts.gestures.control.id,
                SettingsCatalog.shortcuts.focusKeys.id,
                SettingsCatalog.shortcuts.moveWindows.id,
                SettingsCatalog.shortcuts.sizeFloat.id,
                SettingsCatalog.shortcuts.openApplications.id,
            ]
        )
        #expect(
            ShortcutsJumpGroup.allCases.filter(\.ruledAfter)
                == [.gestures]
        )
    }

    /// Every container the page renders is a chip's or a named
    /// exemption, so a new group cannot land unmapped.
    @Test("every Shortcuts container is a chip or exempt")
    func everyContainerIsMapped() {
        let exempt: Set<SettingsContainer> = [
            // Scope, not a destination.
            .layers,
            // The tail's Lua drawer and the header's restore row.
            .luaBindings, .defaultShortcuts,
        ]
        let chipped = Set(ShortcutsJumpGroup.allCases.map(\.container))
        let rendered = ShortcutsCensusRenderTests.containers(
            of: .shortcuts
        )
        #expect(chipped.count == ShortcutsJumpGroup.allCases.count)
        #expect(chipped.isDisjoint(with: exempt))
        #expect(chipped.union(exempt) == rendered)
        #expect(rendered.isSubset(of: Set(SettingsContainer.allCases)))
    }

    private func frame(_ top: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: 0, y: top, width: 400, height: height)
    }

    /// A page laid out the way the section draws it, content at
    /// the viewport's top: an optional banner, Mouse & trackpad,
    /// the layer chrome no chip names, then the four action
    /// groups, scrolled up by `offset`.
    private func page(
        scrolledBy offset: CGFloat,
        banner: CGFloat = 0,
        viewport: CGFloat = 500
    ) -> ShortcutsJumpPage {
        let top = banner - offset
        func id(_ group: ShortcutsJumpGroup) -> String {
            group.control.id
        }
        return ShortcutsJumpPage(
            sections: [
                id(.gestures): frame(top, 80),
                id(.focus): frame(top + 300, 400),
                id(.moveWindows): frame(top + 716, 500),
                id(.sizeFloat): frame(top + 1232, 300),
                id(.openApplications): frame(top + 1548, 300),
            ],
            content: frame(-offset, 1900 + banner),
            viewport: frame(0, viewport)
        )
    }

    @Test("at rest the first group is current, nothing underlaps")
    func atRest() {
        let reading = ShortcutsJumpReading.read(page(scrolledBy: 0))
        #expect(reading.marked == .gestures)
        #expect(!reading.underlapped)
    }

    /// The conflict banner pushes Mouse & trackpad's header past
    /// the bar's reach; unscrolled, its chip is still current.
    @Test("a banner above the first group leaves it marked")
    func bannerAtRest() {
        let reading = ShortcutsJumpReading.read(
            page(scrolledBy: 0, banner: 120)
        )
        #expect(reading.marked == .gestures)
    }

    @Test("the group whose header reached the bar is marked")
    func headerUnderTheBar() {
        let reading = ShortcutsJumpReading.read(page(scrolledBy: 300))
        #expect(reading.marked == .focus)
        #expect(reading.underlapped)
        let inside = ShortcutsJumpReading.read(page(scrolledBy: 500))
        #expect(inside.marked == .focus)
    }

    /// Scrolled past Mouse & trackpad into the layer chrome, no
    /// chip is current: none of them names what is under the bar.
    @Test("chrome no chip names marks nothing")
    func betweenGroups() {
        let reading = ShortcutsJumpReading.read(page(scrolledBy: 200))
        #expect(reading.marked == nil)
        #expect(reading.underlapped)
    }

    /// The last group's header may never reach the bar, so a
    /// scroll the user takes to the end marks it.
    @Test("the end of the scroll marks the last group")
    func endMarksTheLast() {
        let reading = ShortcutsJumpReading.read(page(scrolledBy: 1400))
        #expect(reading.marked == .openApplications)
    }

    @Test("a page that fits is never at its end")
    func shortPageHasNoEnd() {
        let reading = ShortcutsJumpReading.read(
            page(scrolledBy: 0, viewport: 3000)
        )
        #expect(reading.marked == .gestures)
    }

    /// Clicking Size & float ends the scroll before its header
    /// reaches the bar; the clicked chip stays marked through the
    /// jump's own scroll and gives way to the user's next one.
    @Test("a clicked chip holds until the user scrolls")
    func clickedChipHolds() {
        let tracker = ShortcutsJumpTracker()
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let atEnd = page(scrolledBy: 1400)
        _ = tracker.sections(atEnd.sections, at: start)
        _ = tracker.slots(
            [.content: atEnd.content!, .viewport: atEnd.viewport!],
            at: start
        )
        #expect(tracker.jump(to: .sizeFloat, at: start).marked == .sizeFloat)
        let landed = tracker.sections(
            atEnd.sections,
            at: start.addingTimeInterval(SettingsReveal.scroll)
        )
        #expect(landed.marked == .sizeFloat)
        let scrolled = tracker.sections(
            atEnd.sections,
            at: start.addingTimeInterval(5)
        )
        #expect(scrolled.marked == .openApplications)
    }

    // MARK: - Wiring

    private static func source(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/\(path)"
                    ),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
    }

    /// A section card reports its frame under the id its anchor
    /// takes — one key for the jump target and the marking — and
    /// the page opts in; the click opens the first chip's card.
    @Test("cards report under their anchor ids, and the card opens")
    func framesShareTheAnchorKey() throws {
        let card = try Self.source(
            "Components/Common/SettingsSection.swift"
        )
        #expect(
            card.contains(
                "core.searchAnchorCard(control)"
                    + ".background{frameReport(control)}"
            )
        )
        #expect(card.contains("control.id:proxy.frame("))
        let section = try Self.source("Sections/ShortcutsSection.swift")
        #expect(
            section.contains(".environment(\\.measuresSectionFrames,true)")
        )
        #expect(
            section.contains(
                "GesturesDrawer(model:model,expanded:$gesturesExpanded)"
            )
        )
        let jump = try Self.source("Sections/ShortcutsSection+Jump.swift")
        #expect(jump.contains("ifgroup==.gestures{gesturesExpanded=true}"))
        #expect(
            jump.contains("proxy.scrollTo(group.control.id,anchor:.top)")
        )
    }

    /// The row is one named container of buttons, the marked one
    /// selected.
    @Test("the chips announce as one named row")
    func chipsAnnounce() throws {
        let bar = try Self.source(
            "Components/Keybindings/ShortcutsJumpBar.swift"
        )
        #expect(bar.contains(".accessibilityElement(children:.contain)"))
        // Squeezed, so the English reads without its space.
        #expect(bar.contains("L(\"shortcuts.jump.label\",\"Jumpto\")"))
        #expect(bar.contains(".accessibilityAddTraits(marked?.isSelected:[])"))
    }

    /// Hover never erases the marking (#1173): each layer's colour
    /// is a function of its own state alone — the signatures admit
    /// nothing else — and the marking draws over the pointer's.
    @Test("hover and marking are separate layers")
    func hoverKeepsTheMarking() throws {
        #expect(
            ShortcutsJumpChip.markFill(true)
                != ShortcutsJumpChip.markFill(false)
        )
        #expect(
            ShortcutsJumpChip.hoverFill(true)
                != ShortcutsJumpChip.hoverFill(false)
        )
        let bar = try Self.source(
            "Components/Keybindings/ShortcutsJumpBar.swift"
        )
        #expect(
            bar.contains(
                "ZStack{Capsule().fill(Self.hoverFill(hovered))"
                    + "Capsule().fill(Self.markFill(marked))}"
            )
        )
    }
}
