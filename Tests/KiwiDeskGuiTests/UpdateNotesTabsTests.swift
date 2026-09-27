import AppKit
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The update window's tabs (#1666 ruling): which exist, which
/// opens, and when the strip gives way to a menu.
@MainActor
@Suite("Update notes tabs (#1666)", .serialized)
struct UpdateNotesTabsTests {
    private static func group(
        _ type: String,
        title: String? = nil,
        count: Int = 3
    ) -> UpdateNotesDigest.Group {
        .init(
            type: type,
            title: title ?? type,
            entries: (0..<count).map {
                .init(text: "Change \($0).", version: "2.1.0")
            }
        )
    }

    private static func digest(
        _ groups: [UpdateNotesDigest.Group]
    ) -> UpdateNotesDigest {
        UpdateNotesDigest(
            summary: "Summary.",
            cautions: [],
            groups: groups,
            versions: ["2.1.0"],
            unreadable: []
        )
    }

    @Test("Highlights, then every non-empty group in digest order")
    func tabsFollowTheDigest() {
        let tabs = UpdateNotesTabs.tabs(
            Self.digest([
                Self.group("new"),
                Self.group("fixed", count: 0),
                Self.group("scripting"),
            ])
        )
        #expect(tabs == [.highlights, .group("new"), .group("scripting")])
    }

    @Test("Highlights opens, even when Lua & CLI is the only group")
    func highlightsIsTheDefault() {
        #expect(UpdateNotesTabs.initial == .highlights)
        let tabs = UpdateNotesTabs.tabs(Self.digest([Self.group("scripting")]))
        #expect(tabs.first == UpdateNotesTabs.initial)
    }

    @Test("no strip when Highlights is the only tab")
    func loneHighlightsDrawsNoStrip() {
        #expect(!UpdateNotesTabs.showsStrip(Self.digest([])))
        #expect(
            !UpdateNotesTabs.showsStrip(
                Self.digest([Self.group("new", count: 0)])
            )
        )
        #expect(UpdateNotesTabs.showsStrip(Self.digest([Self.group("new")])))
    }

    @Test("a segment names its group and its count")
    func segmentsCarryTheirCount() {
        LocalizationManager.shared.select("en")
        let titles = UpdateNotesTabStrip.options(
            Self.digest([Self.group("fixed", count: 8)])
        ).map(\.title)
        #expect(titles == ["Highlights", "Fixed · 8"])
    }

    /// The strip's room: the window less its side insets.
    private static let available =
        UpdateWindowMetrics.width - 2 * UpdateWindowMetrics.inset

    private static func width<V: View>(_ view: V) -> CGFloat {
        NSHostingController(rootView: view).sizeThatFits(
            in: CGSize(width: 10_000, height: 10_000)
        ).width
    }

    /// The segmented strip at its widest selection, and what the
    /// window's strip chose at the room it has.
    private static func widths(
        _ digest: UpdateNotesDigest
    ) -> (strip: CGFloat, chosen: CGFloat) {
        let options = UpdateNotesTabStrip.options(digest)
        let strip =
            options.map { option in
                width(
                    SegmentedPicker(
                        selection: .constant(option.value),
                        options: options
                    ).fixedSize()
                )
            }.max() ?? 0
        let chosen = NSHostingController(
            rootView: UpdateNotesTabStrip(
                digest: digest,
                selection: .constant(.highlights)
            )
        ).sizeThatFits(
            in: CGSize(width: available, height: 10_000)
        )
        return (strip, chosen.width)
    }

    @Test("the four kinds fit as segments in every locale")
    func knownKindsFitAsSegments() {
        defer { LocalizationManager.shared.select("en") }
        for locale in LocalizationManager.shared.available {
            LocalizationManager.shared.select(locale)
            let (strip, chosen) = Self.widths(
                Self.digest(
                    ["new", "improved", "fixed", "scripting"].map {
                        Self.group($0, count: 18)
                    }
                )
            )
            #expect(strip <= Self.available, "\(locale): \(strip)")
            #expect(chosen == strip, "\(locale): \(chosen)")
        }
    }

    @Test("an unknown kind that overflows gives way to the menu")
    func overflowTakesTheMenu() {
        LocalizationManager.shared.select("fr")
        defer { LocalizationManager.shared.select("en") }
        let (strip, chosen) = Self.widths(
            Self.digest(
                ["new", "improved", "fixed"].map { Self.group($0) }
                    + [
                        Self.group(
                            "security",
                            title: "Sécurité et confidentialité"
                        ),
                        Self.group("scripting"),
                    ]
            )
        )
        #expect(strip > Self.available)
        #expect(chosen < Self.available)
    }

    /// The window opens at the tallest tab, not the one showing.
    @Test("the window is measured over every tab")
    func heightCoversTheTallestTab() {
        LocalizationManager.shared.select("en")
        func height(entries: Int) -> CGFloat {
            let offer = UpdateOffer(
                version: "2.1.0",
                build: "2.1.0",
                installed: "2.0.0",
                released: nil,
                digest: Self.digest([Self.group("fixed", count: entries)])
            )
            return NSHostingView(
                rootView: UpdateWindowView(
                    offer: offer,
                    mode: .whatsNew {},
                    measuring: true
                )
            ).fittingSize.height
        }
        #expect(height(entries: 30) > height(entries: 1) + 300)
    }
}
