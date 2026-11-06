import Foundation
import KiwiDeskCore
import SwiftUI
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
    private static let plate = GesturePlate<EmptyView>.size

    private static func squashed(_ file: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(file)
        return SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        ).split(whereSeparator: \.isWhitespace).joined()
    }

    private static func fades(offset: CGFloat, viewport: CGFloat)
        -> ShelfOverflow.Fades
    {
        GestureStrip.run.fades(
            StripScroll(offset: offset, viewport: viewport)
        )
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
            } + CGFloat(GestureItem.allCases.count) * Self.plate.width
            + 2 * GestureStrip.endRoom
        let viewport: CGFloat = 664
        let rest = Self.fades(offset: 0, viewport: viewport)
        #expect(rest.leading == 0)
        #expect(rest.trailing > 0)
        let mid = Self.fades(offset: 500, viewport: viewport)
        #expect(mid.leading > 0 && mid.trailing > 0)
        let end = Self.fades(
            offset: total - viewport,
            viewport: viewport
        )
        #expect(end.leading > 0)
        #expect(end.trailing == 0)
        let wide = Self.fades(offset: 0, viewport: total + 1)
        #expect(wide.leading == 0 && wide.trailing == 0)
        #expect(
            rest.trailing
                == ShelfOverflow.fadeLength(
                    thickness: Self.plate.height,
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
        #expect(strip.contains("SidewaysStrip(run:Self.run)"))
        let plate = try Self.squashed(
            Self.gestures + "GestureStripPlate.swift"
        )
        #expect(
            plate.contains("GestureStripHoverCue(onTap:{onLand(item)})")
        )
        #expect(
            plate.contains(
                ".overlay(PlateToolTip(text:item.sentence(settings)))"
            )
        )
        #expect(!plate.contains("GreyOut("))
    }

    /// The hover cue (#2537, #3042): its own view holding the picture
    /// as a stored value, so a hover never rebuilds it; the hover edge
    /// over the off-gesture fade, the rise, the pointing hand, the
    /// click.
    @Test("a picture under the pointer wears the hover edge and rises")
    func plateHoverCue() throws {
        let plate = try Self.squashed(
            Self.gestures + "GestureStripPlate.swift"
        )
        // The fade stays inside the cue's closure, so the edge laid
        // over the content stays whole on an off gesture.
        let closure = try #require(
            SourceScan.declarationBody(
                after: "){GesturePlate",
                in: plate
            )
        )
        #expect(closure.contains(".opacity(item.isOff"))
        let view = try Self.squashed(
            Self.gestures + "GestureStripHoverCue.swift"
        )
        #expect(view.contains(".onTapGesture(perform:onTap)"))
        #expect(view.contains(".onHover{hovering=$0}"))
        #expect(view.contains(".pointingHandCursor()"))
        #expect(
            view.contains(
                ".strokeBorder(SettingsTheme.hoverEdge"
                    + ".opacity(hovering?1:0),"
            )
        )
        #expect(view.contains("privateletcontent:Content"))
        // The view itself never fades out of hit-testing.
        #expect(!view.contains(").opacity("))
        // The edge lies over the stored picture, whose body the hover
        // never reaches.
        #expect(!view.contains("picture("))
    }
}
