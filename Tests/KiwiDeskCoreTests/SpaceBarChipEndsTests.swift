import AppKit
import Testing

@testable import KiwiDeskCore

/// A Space chip pads every rounded end alike once an icon sits at
/// either (#1856, owner 2026-10-01): its content centres. A lone
/// glyph that fits the round end pads none, so an empty Space with
/// a symbol draws as round as one with a digit.
@Suite("Space chip ends")
@MainActor
struct SpaceBarChipEndsTests {
    init() { LiquidGlassGate.override = { false } }

    private static let depth: CGFloat = 44
    private static let envelope = SpaceGlyph.symbol("envelope")

    private static func look(fontSize: CGFloat = 0) -> SpaceBarLook {
        var look = SpaceBarLook()
        look.shelf.backgroundStyle = .boxed
        look.shelf.liquidGlass = false
        look.shelf.cornerRoundness = 100
        look.shelf.thickness = depth
        look.shelf.fontSize = fontSize
        return look
    }

    private static func ends(
        _ look: SpaceBarLook,
        leads: Bool,
        trails: Bool,
        lone: SpaceGlyph?
    ) -> ItemEnds {
        SpaceBarItemView.ends(
            look: look,
            depth: depth,
            first: false,
            last: false,
            leadsWithIcon: leads,
            endsInIcon: trails,
            lone: lone
        )
    }

    @Test("A lone glyph that fits the round end pads nothing")
    func loneFittingGlyph() {
        let look = Self.look()
        #expect(
            SpaceBarItemView.fitsRoundEnd(
                Self.envelope,
                look: look,
                depth: Self.depth
            )
        )
        #expect(
            Self.ends(look, leads: true, trails: false, lone: Self.envelope)
                == .zero
        )
    }

    @Test("An icon at one end pads both alike")
    func oneIconPadsBoth() {
        let look = Self.look()
        for (leads, trails) in [(true, false), (false, true), (true, true)] {
            let ends = Self.ends(
                look,
                leads: leads,
                trails: trails,
                lone: nil
            )
            #expect(ends.leading > 0)
            #expect(ends.leading == ends.trailing)
        }
        #expect(
            Self.ends(look, leads: false, trails: false, lone: nil) == .zero
        )
    }

    @Test("A lone glyph too large for the round end pads both alike")
    func loneOversizeGlyph() {
        let look = Self.look(fontSize: 36)
        #expect(
            !SpaceBarItemView.fitsRoundEnd(
                Self.envelope,
                look: look,
                depth: Self.depth
            )
        )
        let ends = Self.ends(
            look,
            leads: true,
            trails: false,
            lone: Self.envelope
        )
        #expect(ends.leading > 0)
        #expect(ends.leading == ends.trailing)
    }

    /// Through the live overlay: an empty symbol Space is as long
    /// as an empty digit Space, its symbol centred; a marked digit
    /// Space centres its identifier between its padded ends.
    @Test("The bar draws a lone symbol chip round and centred")
    func liveChips() throws {
        let items = [
            SpaceBarOverlay.Item(
                space: SpaceID("mail"),
                spaceGlyph: .symbol("envelope"),
                apps: [],
                active: false,
                after: .none
            ),
            SpaceBarOverlay.Item(
                space: SpaceID("3"),
                spaceGlyph: .text("3", tinted: true),
                apps: [],
                active: true,
                after: .none
            ),
        ]
        let manager = SpaceBarManager()
        manager.sync([
            SpaceBarManager.Bar(
                display: barTitleDisplay,
                items: items,
                frontApp: nil,
                frontWindow: nil,
                strip: CGRect(x: 0, y: 0, width: 1440, height: Self.depth),
                style: Self.look(),
                stateMarkColors: StateMarkColors(
                    sticky: "#ffffff",
                    floating: "#ffffff"
                )
            )
        ])
        let overlay = try #require(manager.overlayForTesting(barTitleDisplay))
        let mail = overlay.itemViews[0]
        let digit = overlay.itemViews[1]
        #expect(abs(mail.frame.width - digit.frame.width) < 0.5)
        mail.layout()
        let icon = mail.identifierImage.frame
        #expect(
            abs(icon.midX - mail.bounds.midX) <= 0.5,
            "\(icon) in \(mail.bounds)"
        )
    }
}
