import AppKit
import Testing

@testable import KiwiDeskCore

/// The front-app chip wears the Space Bar's active indicator in
/// its own colour (#1856): Automatic follows the front app's
/// text, a set colour draws as set, and the edge mark sits on the
/// chip's window-facing side.
@Suite("Front-app chip indicator")
@MainActor
struct SpaceBarFrontAccentTests {
    /// Reduce transparency pinned off (#660, #1374); sheen 0 so
    /// the flat stroke carries the colour.
    init() { LiquidGlassGate.override = { false } }

    private func overlay(
        _ edit: (inout SpaceBarLook) -> Void = { _ in },
        front: WindowID? = WindowID(1)
    ) throws -> SpaceBarOverlay {
        let base = paintedSpaceBar(front: front, spaces: 2)
        var style = base.style
        style.sheen = 0
        style.shelf.backgroundStyle = .boxed
        style.shelf.liquidGlass = false
        style.bar.focusedItemColor = "#112233"
        edit(&style)
        let manager = SpaceBarManager()
        manager.sync([
            SpaceBarManager.Bar(
                display: base.display,
                items: base.items,
                frontApp: base.frontApp,
                frontWindow: base.frontWindow,
                strip: base.strip,
                style: style,
                stateMarkColors: base.stateMarkColors
            )
        ])
        return try #require(manager.overlayForTesting(barTitleDisplay))
    }

    private func stroke(_ view: NSView) -> String? {
        view.layer?.borderColor.flatMap(NSColor.init(cgColor:))?
            .usingColorSpace(.sRGB).map {
                String(
                    format: "#%02X%02X%02X",
                    Int(round($0.redComponent * 255)),
                    Int(round($0.greenComponent * 255)),
                    Int(round($0.blueComponent * 255))
                )
            }
    }

    @Test("Automatic outlines the chip in the front app's own colour")
    func automaticFollowsText() throws {
        let o = try overlay()
        #expect(!o.frontAccentClip.isHidden)
        #expect(o.frontAccentClip.frame == o.frontBox.frame)
        #expect(stroke(o.frontAccent) == "#112233")
        #expect(o.frontAccent.layer?.borderWidth ?? 0 > 0)
    }

    @Test("A set colour draws as set")
    func setColourDraws() throws {
        let o = try overlay { $0.bar.focusedHighlightColor = "#AA0000" }
        #expect(stroke(o.frontAccent) == "#AA0000")
    }

    @Test("The edge mark sits on the chip's window-facing side")
    func edgeMark() throws {
        let o = try overlay { $0.bar.activeIndicator = .edgeMark }
        let clip = o.frontAccentClip.bounds
        let mark = o.frontAccent.frame
        #expect(o.frontAccent.layer?.borderWidth == 0)
        #expect(mark.width == clip.width)
        // A top bar's window-facing side is its bottom; flipped.
        #expect(mark.maxY == clip.maxY)
        #expect(mark.height < clip.height)
    }

    /// From a chip that drew to none: a fresh view is unhidden by
    /// default, so the drawn state comes first.
    @Test("No front app draws no indicator")
    func hidesWithTheSegment() throws {
        let manager = SpaceBarManager()
        for front in [WindowID(1), nil] as [WindowID?] {
            let base = paintedSpaceBar(front: front, spaces: 2)
            manager.sync([base])
        }
        let o = try #require(manager.overlayForTesting(barTitleDisplay))
        #expect(o.frontAccentClip.isHidden)
    }

    /// The width a run reserves for the segment is the width it
    /// draws, so a hugging plate ends where the chip does.
    @Test(
        "The segment reserves what it draws",
        arguments: [AppBarStyle.BackgroundStyle.boxed, .plain]
    )
    func extentIsDrawn(background: AppBarStyle.BackgroundStyle) throws {
        let o = try overlay { $0.shelf.backgroundStyle = background }
        let shown = try #require(o.lastShown)
        let extent = o.frontExtent(
            shown.frontApp,
            depth: shown.strip.height,
            horizontal: true,
            style: shown.style
        )
        let drawn = o.frontAccentClip.frame.maxX - o.frontDivider.frame.minX
        #expect(abs(drawn - extent) <= 0.5, "\(drawn) vs \(extent)")
    }

    @Test("The setter takes empty as Automatic, the text colour not")
    func setterTakesAutomatic() {
        var style = SpaceBarStyle()
        style.focusedItemColor = "#123456"
        #expect(style.resolvedFocusedHighlightColor == "#123456")
        let parsed = SpaceBarCommandSetting.parse(
            field: "focused_highlight_color",
            args: [.string("")]
        )
        guard case .success(let setting) = parsed else {
            Issue.record("refused \"\": \(parsed)")
            return
        }
        style.focusedHighlightColor = "#FFFFFF"
        setting.apply(to: &style)
        #expect(style.focusedHighlightColor == "")
        guard
            case .failure = SpaceBarCommandSetting.parse(
                field: "focused_highlight_color",
                args: [.string("red")]
            )
        else {
            Issue.record("took a non-hex")
            return
        }
        guard
            case .failure = SpaceBarCommandSetting.parse(
                field: "focused_item_color",
                args: [.string("")]
            )
        else {
            Issue.record("the text colour took Automatic")
            return
        }
    }

    @Test("A palette hands the indicator back to Automatic")
    func paletteAutomatic() {
        var settings = TilingSettings()
        settings.spaceBarStyle.focusedHighlightColor = "#AA0000"
        ColorPalette(
            name: "t",
            colors: ["space_bar.focused_highlight_color": ""]
        ).apply(to: &settings)
        #expect(settings.spaceBarStyle.focusedHighlightColor == "")
    }
}
