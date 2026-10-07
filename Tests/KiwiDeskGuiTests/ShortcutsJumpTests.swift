import CoreGraphics
import Foundation
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

    private func frame(_ top: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: 0, y: top, width: 400, height: height)
    }

    /// A page laid out the way the section draws it: Mouse &
    /// trackpad, then the layer chrome no chip names, then the
    /// four action groups, scrolled up by `offset`.
    private func page(
        scrolledBy offset: CGFloat,
        viewport: CGFloat = 500
    ) -> [ShortcutsJumpSlot: CGRect] {
        let top = SettingsMetrics.paneInset - offset
        return [
            .viewport: frame(0, viewport),
            .content: frame(top, 2000),
            .group(.gestures): frame(top, 80),
            .group(.focus): frame(top + 300, 400),
            .group(.moveWindows): frame(top + 716, 500),
            .group(.sizeFloat): frame(top + 1232, 300),
            .group(.openApplications): frame(top + 1548, 300),
        ]
    }

    @Test("at rest the first group is current, nothing underlaps")
    func atRest() {
        let reading = ShortcutsJumpReading.read(page(scrolledBy: 0))
        #expect(reading.marked == .gestures)
        #expect(!reading.underlapped)
    }

    @Test("the group whose header reached the bar is marked")
    func headerUnderTheBar() {
        let landed = SettingsMetrics.paneInset + 300
        let reading = ShortcutsJumpReading.read(page(scrolledBy: landed))
        #expect(reading.marked == .focus)
        #expect(reading.underlapped)
        let inside = ShortcutsJumpReading.read(
            page(scrolledBy: landed + 200)
        )
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

    /// The last group's header may never reach the bar, so the
    /// end of the scroll marks it.
    @Test("the end of the scroll marks the last group")
    func endMarksTheLast() {
        let end = SettingsMetrics.paneInset + 2000 - 500
        let reading = ShortcutsJumpReading.read(page(scrolledBy: end))
        #expect(reading.marked == .openApplications)
    }

    @Test("a page that fits is never at its end")
    func shortPageHasNoEnd() {
        let reading = ShortcutsJumpReading.read(
            page(scrolledBy: 0, viewport: 3000)
        )
        #expect(reading.marked == .gestures)
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

    /// Every chip's group reports its frame, once, and the card
    /// the first chip opens is the section's own binding.
    @Test("every chip's group is measured, and the card opens")
    func groupsAreMeasured() throws {
        let section = try Self.source("Sections/ShortcutsSection.swift")
        for group in ShortcutsJumpGroup.allCases {
            #expect(
                section.occurrences(
                    of: ".shortcutsJumpSlot(.group(.\(group)))"
                ) == 1,
                Comment(rawValue: "\(group)")
            )
        }
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
    /// selected; hover and marking draw on separate layers, so a
    /// hover never erases the marking (#1173).
    @Test("the chips announce, and hover keeps the marking")
    func chipsAnnounce() throws {
        let bar = try Self.source(
            "Components/Keybindings/ShortcutsJumpBar.swift"
        )
        #expect(bar.contains(".accessibilityElement(children:.contain)"))
        // Squeezed, so the English reads without its space.
        #expect(bar.contains("L(\"shortcuts.jump.label\",\"Jumpto\")"))
        #expect(bar.contains(".accessibilityAddTraits(marked?.isSelected:[])"))
        #expect(bar.occurrences(of: "hovered?") == 1)
        #expect(bar.occurrences(of: "marked?Self.markedWash") == 1)
        #expect(!bar.contains("hovered&&marked"))
        #expect(!bar.contains("marked&&hovered"))
    }
}
