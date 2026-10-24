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
struct PanelGlassTests {
    private static let gui = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDesk")

    private static func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: gui.appendingPathComponent(path)
        )
    }

    @Test(
        "The toggle picks clear glass with the Fill",
        arguments: [true, false]
    )
    func togglePicksTheGlass(tinted: Bool) {
        var settings = TilingSettings()
        settings.kiwishelf.tintHubAndPlates = tinted
        let glass = PanelGlass(settings: settings)
        #expect((glass.shelf != nil) == tinted)
        #expect(glass.variant == (tinted ? .clear : .regular))
        #expect(glass.wearsActiveLook == tinted)
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
    func selectionFollowsTheToggle(tinted: Bool) {
        var settings = TilingSettings()
        settings.kiwishelf.tintHubAndPlates = tinted
        let paint = KiwiHubPaint.of(settings)
        #expect(paint.tinted == tinted)
        // A selected item's every level takes its own ink only
        // under the toggle (#2569).
        #expect((paint.rowInk(selected: true, lifted: false) != nil) == tinted)
        #expect(paint.rowInk(selected: false, lifted: false) == nil)
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
        let panel = try Self.source("Jump/JumpPanelView.swift")
        #expect(
            panel.contains(
                ".environment(\\.kiwiHubPaint, KiwiHubPaint.of(settings))"
            )
        )
    }
}
