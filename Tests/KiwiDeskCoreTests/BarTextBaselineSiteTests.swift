import AppKit
import Testing

@testable import KiwiDeskCore

/// The rest of bar text on the one baseline (#1707): the
/// front-app name, a count badge and the shelf's overflow count,
/// each rendered in Apple Chancery at a size where centring the
/// line box instead misses the cap band by more than the
/// tolerance. The measurement is `BarTextBaselineTests`': the ink
/// bottom of a flat-footed glyph is the baseline, and the band —
/// caps, or a count's figures — is measured above it.
@Suite("Bar text sites centre their cap band")
@MainActor
struct BarTextBaselineSiteTests {
    static let family = BarTextBaselineTests.family

    init() { LiquidGlassGate.override = { false } }

    /// The cap band's middle, in the field's host, and whether the
    /// ink stays inside the field.
    static func capMiddle(
        of field: NSTextField,
        band: BarTextGlyph.Band = .caps
    ) throws -> (mid: CGFloat, whole: Bool) {
        let rows = try #require(
            BarTextBaselineTests.inkRows(of: field),
            "no ink in \(field.stringValue)"
        )
        let middle = BarTextBaselineTests.bandMiddle(
            band,
            font: try #require(field.font)
        )
        return (
            field.frame.minY + rows.upperBound - middle,
            rows.lowerBound > 0 && rows.upperBound < field.bounds.height
        )
    }

    @Test("the front-app name centres its caps on the strip")
    func frontAppName() throws {
        try #require(BarFont.isInstalled(Self.family))
        var style = SpaceBarLook()
        style.fontFamily = Self.family
        style.fontSize = 40
        style.showFrontApp = true
        let strip = CGRect(x: 0, y: 0, width: 1440, height: 60)
        let bar = SpaceBarManager.Bar(
            display: barTitleDisplay,
            items: [
                SpaceBarOverlay.Item(
                    space: SpaceID("1"),
                    spaceGlyph: .text("1", tinted: true),
                    apps: [],
                    active: true,
                    after: .none
                )
            ],
            frontApp: SpaceBarItemView.App(
                name: "HH",
                icon: nil,
                glyph: nil,
                focused: true,
                count: 1
            ),
            frontWindow: WindowID(1),
            strip: strip,
            style: style,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        let manager = SpaceBarManager()
        manager.sync([bar])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        let field = overlay.frontName
        try #require(!field.isHidden && field.stringValue == "HH")
        let band = try Self.capMiddle(of: field)
        #expect(band.whole, "front-app name clipped at \(field.frame)")
        #expect(
            abs(band.mid - strip.height / 2) <= 1,
            "cap band \(band.mid) vs strip middle \(strip.height / 2)"
        )
    }

    /// A badge on a disc in Chancery, framed in a flipped host.
    static func badge(_ text: String) -> NSTextField {
        let host = AppBarOverlay.FlippedView(
            frame: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        let badge = SpaceBarItemView.makeBadge()
        host.addSubview(badge)
        badge.font = NSFont(name: family, size: 40)
        badge.stringValue = text
        badge.frame = CGRect(x: 10, y: 10, width: 70, height: 70)
        return badge
    }

    /// The 1's flat foot is the baseline the figure band rests on.
    @Test("a count badge centres its figures on its disc")
    func countBadge() throws {
        try #require(BarFont.isInstalled(Self.family))
        let badge = Self.badge("1")
        let band = try Self.capMiddle(of: badge, band: .figures)
        #expect(band.whole, "badge clipped")
        #expect(
            abs(band.mid - badge.frame.midY) <= 1,
            "figure band \(band.mid) vs disc middle \(badge.frame.midY)"
        )
    }

    /// The band is the badge's role, never its string: a count
    /// and an overflow badge sit on one line in an old-style face.
    @Test("a count and an overflow badge share one line")
    func overflowBadgeLine() throws {
        try #require(BarFont.isInstalled(Self.family))
        let tops = ["3", "+3", "12"].map { text in
            let badge = Self.badge(text)
            return badge.cell?.titleRect(forBounds: badge.bounds).minY
        }
        #expect(Set(tops).count == 1, "line tops \(tops)")
    }

    @Test("the shelf's overflow count centres its caps")
    func shelfCount() throws {
        try #require(BarFont.isInstalled(Self.family))
        var shelf = KiwiShelf()
        shelf.fontFamily = Self.family
        let view = ShelfCountView(side: .after)
        view.configure(
            count: 11,
            horizontal: false,
            fontSize: 40,
            shelf: shelf,
            ink: .white,
            hoverInk: .red
        )
        view.place(
            in: CGRect(x: 0, y: 0, width: 100, height: 300),
            atEnd: true
        )
        view.layout()
        let label = try #require(
            view.subviews.first { $0 is NSTextField } as? NSTextField
        )
        let band = try Self.capMiddle(of: label, band: .figures)
        #expect(band.whole, "count clipped at \(label.frame)")
        #expect(
            abs(band.mid - view.bounds.midY) <= 1,
            "cap band \(band.mid) vs count middle \(view.bounds.midY)"
        )
    }
}
