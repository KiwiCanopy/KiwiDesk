import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// **KiwiHub and the cue plates wear the Fill under the toggle,
/// follow KiwiHub's Liquid Glass leaf, and their panels wear the
/// rim** (#2569 ▸ Ruling). The value is `PanelGlass`; the wiring
/// no behavioural test can reach — which view draws through it,
/// which panel wears the rim — is needled on its use sites.
@Suite("KiwiHub and cue plate glass (#2569)")
@MainActor
struct PanelGlassTests {
    private static let gui = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDesk")

    private static func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: gui.appendingPathComponent(path)
        )
    }

    /// KiwiHub's paint on `glass`, with the inks the chrome resolves.
    private static func paint(_ glass: PanelGlass) -> KiwiHubPaint {
        KiwiHubPaint.of(
            glass,
            ink: glass.shelf?.panelInk(increaseContrast: false)
        )
    }

    @Test(
        "The toggle picks clear glass with the Fill",
        arguments: [true, false]
    )
    func togglePicksTheGlass(tinted: Bool) throws {
        var settings = TilingSettings()
        settings.kiwishelf.tintHubAndPlates = tinted
        try #require(GlassChromeVariant.drawable, "no glass below 26")
        let glass = PanelGlass(settings: settings)
        #expect((glass.shelf != nil) == tinted)
        #expect(glass.variant == (tinted ? .clear : .regular))
        #expect(glass.wearsActiveLook == tinted)
    }

    /// Reduce transparency draws the fallback, so the Fill, its
    /// inks and KiwiHub's paint stand down with the glass, live.
    @Test("Reduce transparency stands the Fill down")
    func reduceTransparencyStandsDown() throws {
        try #require(GlassChromeVariant.drawable, "no glass below 26")
        var settings = TilingSettings()
        settings.kiwishelf.tintHubAndPlates = true
        let glass = PanelGlass(settings: settings)
        try #require(glass.shelf != nil)
        #expect(glass.drawn(reduceTransparency: false) == glass)
        let reduced = glass.drawn(reduceTransparency: true)
        #expect(reduced.shelf == nil)
        #expect(reduced.enabled == glass.enabled)
        #expect(!Self.paint(reduced).tinted)
        // A leaf turned off after the read draws the fallback too.
        var off = glass
        off.enabled = false
        #expect(off.drawn(reduceTransparency: false).shelf == nil)
    }

    @Test(
        "The plates follow KiwiHub's Liquid Glass leaf",
        arguments: [true, false]
    )
    func followsTheLeaf(on: Bool) {
        var settings = TilingSettings()
        settings.shortcutPanelLiquidGlass = on
        #expect(PanelGlass(settings: settings).enabled == on)
    }

    /// KiwiHub's leaf off leaves KiwiHub and the cues untinted though
    /// the toggle is on: the answer is Core's, not the toggle's.
    @Test("KiwiHub's glass off leaves the panels untinted")
    func leafOffLeavesThemUntinted() {
        var settings = TilingSettings()
        settings.kiwishelf.tintHubAndPlates = true
        settings.shortcutPanelLiquidGlass = false
        #expect(PanelGlass(settings: settings).shelf == nil)
        #expect(!Self.paint(PanelGlass(settings: settings)).tinted)
    }

    /// A Fill without colour leaves KiwiHub and the cues untinted,
    /// as the toggle off does (#2569 ▸ "No Colour").
    @Test("No colour falls back to the untinted panel")
    func noColourFallsBack() {
        var settings = TilingSettings()
        settings.kiwishelf.tintHubAndPlates = true
        settings.kiwishelf.fillColor = "#14201C00"
        #expect(PanelGlass(settings: settings).shelf == nil)
        #expect(!Self.paint(PanelGlass(settings: settings)).tinted)
    }

    @Test("Every cue view and KiwiHub draw through the panel glass")
    func surfacesDrawThroughIt() throws {
        for path in [
            "CuePlate/SpaceCueView.swift", "CuePlate/DesktopCueView.swift",
            "CuePlate/ModeCueView.swift", "Jump/JumpPanelView.swift",
        ] {
            let body = try Self.source(path)
            #expect(body.contains(".panelGlassChrome("), "\(path)")
            #expect(!body.contains(".glassChrome("), "\(path)")
            #expect(!body.contains("enabled: true"), "\(path)")
        }
        let view = try Self.source("CuePlate/CuePlateModel.swift")
        for cue in ["DesktopCueView", "ModeCueView", "SpaceCueView"] {
            #expect(
                view.contains("\(cue)(cue: cue, glass: model.glass)"),
                "\(cue)"
            )
        }
    }

    /// The tinted panel reads in the look's three inks; the
    /// untinted one keeps SwiftUI's hierarchy (#2569 ▸ Ruling).
    @Test("The panel chrome inks and tints the tinted panel")
    func chromeInksTheTintedPanel() throws {
        let chrome = try Self.source(
            "Settings/Components/Common/PanelGlass.swift"
        ).filter { !$0.isWhitespace }
        #expect(
            chrome.contains(
                "inked(content,ink).environment(\\.kiwiHubPaint,"
                    + "KiwiHubPaint.of(drawn,ink:ink,tint:tint))"
                    + ".glassChrome("
            )
        )
        // One read of Increase Contrast resolves the inks for both.
        #expect(
            chrome.contains(
                "letink=drawn.shelf?.panelInk(increaseContrast:increased)"
            )
        )
        #expect(
            chrome.contains(
                "content.foregroundStyle(Color(kiwiHex:ink.primary),"
                    + "Color(kiwiHex:ink.secondary),"
                    + "Color(kiwiHex:ink.tertiary))"
            )
        )
        #expect(chrome.contains("ifletink{"))
        // Reduce transparency read live, in the chrome itself.
        #expect(
            chrome.contains(
                "glass.drawn(reduceTransparency:reduceTransparency)"
            )
        )
        #expect(
            chrome.contains(
                "glassChrome(in:shape,enabled:drawn.enabled,"
                    + "variant:drawn.variant,tint:"
            )
        )
        // One paint, minted once, lands as the chrome's tint and
        // KiwiHub's fade alike.
        #expect(
            chrome.contains(
                "lettint=drawn.shelf.flatMap{GlassTint.paint("
                    + "$0.panelGlassFill(increaseContrast:increased),"
                    + "edge:.top)}"
            )
        )
        #expect(chrome.contains("tint:tint,fallback:fallback)"))
        #expect(chrome.occurrences(of: "GlassTint.paint(") == 1)
    }

    @Test("The cue panel wears the rim the glass asks for")
    func cuePanelWearsTheRim() throws {
        let controller = try Self.source("CuePlate/CuePlateController.swift")
        #expect(controller.contains("ActiveGlassPanel("))
        #expect(
            controller.contains(
                "wearsActiveLook = glass.enabled && glass.wearsActiveLook"
            )
        )
        #expect(controller.contains("model.glass = glass"))
        let delegate = try Self.source("AppDelegate+CuePlate.swift")
        #expect(
            delegate.components(
                separatedBy:
                    "glass: PanelGlass(settings: self.core.tiler.settings)"
            ).count - 1 == 3
        )
    }

    /// KiwiHub's selection and hover take the shelf's colours under
    /// the toggle and keep kiwi green off it (#2569 ▸ Ruling).
    @Test("KiwiHub's selection follows the toggle", arguments: [true, false])
    func selectionFollowsTheToggle(tinted: Bool) throws {
        var settings = TilingSettings()
        settings.kiwishelf.tintHubAndPlates = tinted
        try #require(GlassChromeVariant.drawable, "no glass below 26")
        let paint = Self.paint(PanelGlass(settings: settings))
        #expect(paint.tinted == tinted)
        // A selected item's every level takes its own ink only
        // under the toggle (#2569).
        #expect(
            (paint.rowInk(selected: true, lifted: false) != nil) == tinted
        )
        #expect(paint.rowInk(selected: false, lifted: false) == nil)
    }

    /// KiwiHub's scope switch is Settings' segmented picker; its
    /// selection and inks come from the paint, whose untinted
    /// defaults are the picker's own tokens (#2569).
    @Test("The scope switch paints through KiwiHub's paint")
    func scopeSwitchReadsThePaint() throws {
        let picker = try Self.source(
            "Settings/Components/Common/SegmentedPicker.swift"
        )
        #expect(picker.contains("@Environment(\\.kiwiHubPaint)"))
        #expect(picker.contains(".fill(paint.selection)"))
        #expect(picker.contains("paint.selectionInk"))
        #expect(picker.contains("paint.selectionInkSecondary"))
        #expect(
            picker.contains(
                "? paint.fill(paint.rowHover) : AnyShapeStyle(.clear)"
            )
        )
        for token in [
            "SettingsTheme.accent)", "SettingsTheme.accentInk",
            "SettingsTheme.chipRest",
        ] {
            #expect(!picker.contains(token), "\(token)")
        }
        let paint = KiwiHubPaint()
        #expect(paint.selection == SettingsTheme.accent)
        #expect(paint.selectionInk == SettingsTheme.accentInk)
        #expect(
            paint.selectionInkSecondary == SettingsTheme.accentInkSecondary
        )
        #expect(paint.rowHover == SettingsTheme.chipRest)
    }

    /// KiwiHub's footer buttons rest on the neutral chip, lift in
    /// the shelf's hover, and read the panel's inks; the layer pill
    /// takes the highlight (#2569 ▸ owner).
    @Test("KiwiHub's footer chips and layer pill read the paint")
    func footerReadsThePaint() throws {
        let face = try Self.source("Settings/ChipFace.swift")
            .filter { !$0.isWhitespace }
        #expect(face.contains("@Environment(\\.kiwiHubPaint)"))
        #expect(face.contains("ifpaint.tinted,lifted{returnpaint.rowHover}"))
        #expect(face.contains("guardpaint.tintedelse{"))
        #expect(face.contains(".foregroundStyle(ink)"))
        let footer = try Self.source("Jump/JumpPanelView+Footer.swift")
        #expect(
            footer.contains("Capsule().fill(paint.selection.opacity(0.2))")
        )
        #expect(!footer.contains("SettingsTheme.accent"))
    }

    @Test("Rows, chips and tiles paint through KiwiHub's paint")
    func rowsReadThePaint() throws {
        for path in [
            "Jump/JumpRowView.swift", "Jump/ViewChip.swift",
            "Jump/JumpLayoutTile.swift",
        ] {
            let body = try Self.source(path)
            #expect(body.contains("@Environment(\\.kiwiHubPaint)"), "\(path)")
            #expect(body.contains("paint.selection)"), "\(path)")
            // Squashed: the call wraps across lines.
            #expect(
                body.filter { !$0.isWhitespace }.contains(
                    "kiwiHubRowInk(paint,selected:isSelected,lifted:isLifted)"
                ),
                "\(path)"
            )
            for token in ["SettingsTheme.accent", "SettingsTheme.chip"] {
                #expect(!body.contains(token), "\(path): \(token)")
            }
        }
        // The chrome hands KiwiHub its paint, from the glass as
        // drawn.
        let chrome = try Self.source(
            "Settings/Components/Common/PanelGlass.swift"
        ).filter { !$0.isWhitespace }
        #expect(
            chrome.contains(
                ".environment(\\.kiwiHubPaint,KiwiHubPaint.of(drawn,"
                    + "ink:ink,tint:tint))"
            )
        )
    }
}
