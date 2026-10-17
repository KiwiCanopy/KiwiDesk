import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The shut Mouse & trackpad card's picture strip (owner ruling
/// 2026-10-17): every entry's picture, the groups set apart, the
/// KiwiShelf's overflow fade only at an end that cuts a picture, and
/// a click that opens the card at its entry.
@Suite("Gesture picture strip")
struct GestureStripTests {
    private static let gestures =
        "Sources/KiwiDesk/Settings/Components/Gestures/"

    private static func squashed(_ file: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(file)
        return SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        ).split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("a group starts a wider gap than a picture")
    func groupGaps() {
        let leads = GestureItem.allCases.map(GestureStrip.leading(of:))
        #expect(leads.first == 0)
        let starts = zip(GestureItem.allCases, leads).filter {
            $0.1 == GestureStrip.groupGap
        }.map(\.0)
        #expect(starts == [.hoverFocus, .swap, .dropOnSpace])
        #expect(
            leads.filter { $0 == GestureStrip.gap }.count
                == GestureItem.allCases.count - 4
        )
    }

    /// An end fades only where it cuts a picture, at Core's length.
    @Test("an end fades only while it cuts a picture")
    func fadesFollowTheOffset() {
        let total =
            GestureItem.allCases.reduce(CGFloat(0)) {
                $0 + GestureStrip.leading(of: $1)
            } + CGFloat(GestureItem.allCases.count) * 120
        let viewport: CGFloat = 664
        let rest = GestureStrip.fades(offset: 0, viewport: viewport)
        #expect(rest.leading == 0)
        #expect(rest.trailing > 0)
        let mid = GestureStrip.fades(offset: 500, viewport: viewport)
        #expect(mid.leading > 0 && mid.trailing > 0)
        let end = GestureStrip.fades(
            offset: total - viewport,
            viewport: viewport
        )
        #expect(end.leading > 0)
        #expect(end.trailing == 0)
        let wide = GestureStrip.fades(offset: 0, viewport: total + 1)
        #expect(wide.leading == 0 && wide.trailing == 0)
        #expect(
            rest.trailing
                == ShelfOverflow.fadeLength(
                    thickness: 72,
                    visible: viewport
                )
        )
    }

    /// A click opens the card at the picture's entry and plays it;
    /// the strip draws only while the card is shut.
    @Test("a click lands on the entry; the strip shows only shut")
    func clickLands() throws {
        let drawer = try Self.squashed(Self.gestures + "GesturesDrawer.swift")
        let land = try #require(
            SourceScan.declarationBody(
                after: "privatevarstrip:someView",
                in: drawer
            )
        )
        #expect(land.contains("expanded=true"))
        #expect(
            land.contains(
                "SettingsAnchor(destination:.shortcuts,anchor:item.anchor)"
            )
        )
        #expect(drawer.contains("preview:AnyView(strip)"))
        let section = try Self.squashed(
            "Sources/KiwiDesk/Settings/Components/Common/"
                + "SettingsCollapsibleSection.swift"
        )
        #expect(section.contains("if!isExpanded,letpreview{preview}"))
    }

    /// Pointer-only: hidden from VoiceOver, the sentence as its
    /// tooltip, the tap handing over its item.
    @Test("a picture is a pointer target with its sentence as tooltip")
    func plateIsPointerOnly() throws {
        let strip = try Self.squashed(Self.gestures + "GestureStrip.swift")
        #expect(strip.contains(".accessibilityHidden(true)"))
        #expect(strip.contains(".mask(GestureStripFade(fades:fades))"))
        let plate = try Self.squashed(
            Self.gestures + "GestureStripPlate.swift"
        )
        #expect(plate.contains(".onTapGesture{onLand(item)}"))
        #expect(plate.contains(".help(item.sentence(settings))"))
        #expect(!plate.contains("GreyOut("))
    }
}
