import KiwiDeskCore
import SwiftUI

/// Colors & glass gating logic (#520, #527, #678).
@MainActor
struct ColorsAndGlassGates {
    let settings: TilingSettings

    /// The bar halves, delegated whole.
    var bars: BarsGates { BarsGates(settings: settings) }

    // MARK: - Borders

    var borderOn: Bool { settings.borderStyle.enabled }
    var unfocusedOn: Bool { settings.borderStyle.unfocusedEnabled }

    // MARK: - KiwiShelf

    /// The shelf draws no border, so its colour is inert (#1679).
    var shelfBorderOff: Bool { !settings.kiwishelf.border }

    // MARK: - Space Bar

    /// In-chip glyphs are native images and no front-app name renders
    /// (`SpaceBarOverlay+FrontApp`).
    var focusedItemInert: Bool {
        // Inert only where no screen draws the name (#1948).
        settings.screenVariants.allSatisfy { screen in
            let style = screen.spaceBarLook
            return style.iconSource == .appImage
                && !(style.showFrontApp && style.edge.isHorizontal)
        }
    }

    /// The front chip's indicator draws only while the segment
    /// does (#1856).
    var focusedHighlightInert: Bool {
        !settings.spaceBarLook.showFrontApp
    }
}
