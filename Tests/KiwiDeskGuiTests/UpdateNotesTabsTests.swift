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

    @Test("a segment names its group without a count")
    func segmentsCarryNoCount() {
        LocalizationManager.shared.select("en")
        let titles = UpdateNotesTabStrip.options(
            Self.digest([Self.group("fixed", count: 8)])
        ).map(\.title)
        #expect(titles == ["Highlights", "Fixed"])
    }

    /// The width the ruling was measured at: 560 pt less the
    /// strip's 20 pt insets.
    private static let available: CGFloat = 520

    private static func widths(
        _ digest: UpdateNotesDigest
    ) -> (strip: CGFloat, chosen: CGFloat) {
        let options = UpdateNotesTabStrip.options(digest)
        let strip = NSHostingController(
            rootView: SegmentedPicker(
                selection: .constant(UpdateNotesTab.highlights),
                options: options
            ).fixedSize()
        ).sizeThatFits(in: CGSize(width: 10_000, height: 10_000))
        let chosen = NSHostingController(
            rootView: UpdateNotesTabStrip(
                digest: digest,
                selection: .constant(.highlights)
            )
        ).sizeThatFits(
            in: CGSize(width: available, height: 10_000)
        )
        return (strip.width, chosen.width)
    }

    @Test("the four kinds fit as segments in the longest locale")
    func knownKindsFitAsSegments() {
        LocalizationManager.shared.select("fr")
        defer { LocalizationManager.shared.select("en") }
        let (strip, chosen) = Self.widths(
            Self.digest(
                ["new", "improved", "fixed", "scripting"].map {
                    Self.group($0, count: 18)
                }
            )
        )
        #expect(strip <= Self.available)
        #expect(chosen == strip)
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
}
