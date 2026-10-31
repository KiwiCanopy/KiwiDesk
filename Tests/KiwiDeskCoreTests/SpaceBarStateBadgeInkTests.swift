import AppKit
import Testing

@testable import KiwiDeskCore

/// A state's colour is its symbol's (#2831): a coloured sticky or
/// floating badge keeps the count badge's own disc and inks its
/// symbol in the colour; Automatic takes the disc's contrasting ink.
@Suite("Space Bar state badge ink (#2831)")
@MainActor
struct SpaceBarStateBadgeInkTests {
    private let blue = "#3D6FE8"
    private let violet = "#8E5DE0"

    private func view(sticky: String, floating: String) -> SpaceBarItemView {
        let view = SpaceBarItemView(
            frame: CGRect(x: 0, y: 0, width: 120, height: 28)
        )
        view.configure(
            identity: .space(SpaceID("1")),
            spaceGlyph: .text("1", tinted: true),
            apps: [
                SpaceBarItemView.App(
                    name: "App",
                    icon: nil,
                    glyph: "A",
                    focused: true,
                    count: 1,
                    sticky: true,
                    floating: true
                )
            ],
            active: true,
            horizontal: true,
            style: SpaceBarLook(),
            stateMarkColors: StateMarkColors(
                sticky: sticky,
                floating: floating,
                pocket: ""
            )
        )
        view.layout()
        return view
    }

    private func hex(_ color: NSColor?) throws -> String {
        let c = try #require(color?.usingColorSpace(.sRGB))
        return String(
            format: "#%02X%02X%02X",
            Int((c.redComponent * 255).rounded()),
            Int((c.greenComponent * 255).rounded()),
            Int((c.blueComponent * 255).rounded())
        )
    }

    private func disc(_ badge: StateBadgeView) throws -> String {
        try hex(
            badge.layer?.backgroundColor.flatMap(NSColor.init(cgColor:))
        )
    }

    @Test("a coloured badge keeps the count disc and inks its symbol")
    func colourOnTheSymbol() throws {
        let item = view(sticky: blue, floating: violet)
        let group = try hex(NSColor(kiwiHex: item.style.groupBadgeColor))
        let sticky = try #require(item.stickyBadgeViews.first ?? nil)
        let floating = try #require(item.floatingBadgeViews.first ?? nil)
        #expect(try disc(sticky) == group)
        #expect(try disc(floating) == group)
        #expect(try hex(sticky.symbol.contentTintColor) == blue)
        #expect(try hex(floating.symbol.contentTintColor) == violet)
    }

    @Test("Automatic inks the symbol against the disc")
    func automaticContrasts() throws {
        let item = view(sticky: "", floating: "")
        let disc = NSColor(kiwiHex: item.style.groupBadgeColor)
        let sticky = try #require(item.stickyBadgeViews.first ?? nil)
        #expect(
            try hex(sticky.symbol.contentTintColor)
                == hex(disc.contrastingGlyph)
        )
    }
}
