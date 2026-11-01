import SwiftUI

@testable import KiwiDesk

/// The inks the light plate draws (#2859 ruling 3): its caption,
/// readout and fallback ink on the plate, the well and a window,
/// and the incoming window's `+` — a mark, so the non-text floor.
/// The focus ring on the plate is the verdict's, measured per
/// look in `PlateGroundTests`.
extension SettingsThemeContrastTests {
    static let lightPlate: [Pairing] = [
        Pairing(
            "lightInk on lightPlate",
            SettingsTheme.lightInk,
            on: SettingsTheme.lightPlate
        ),
        Pairing(
            "lightInk on lightWell",
            SettingsTheme.lightInk,
            on: SettingsTheme.lightWell
        ),
        Pairing(
            "lightInk on lightWindow",
            SettingsTheme.lightInk,
            on: SettingsTheme.lightWindow
        ),
        Pairing(
            "lightMark on lightWindow",
            SettingsTheme.lightMark,
            on: SettingsTheme.lightWindow,
            floor: 3.0
        ),
        // The brand's marks on the plate (`accentMark`,
        // `boundKeyEdge`): the gesture strip's hover ring, the
        // tour's menu-bar icon ring and a bound key's edge on the
        // board — the accent fill itself measures ~1.9:1 here.
        Pairing(
            "lightAccent marks on lightPlate",
            SettingsTheme.lightAccent,
            on: SettingsTheme.lightPlate,
            floor: 3.0
        ),
        // KiwiVision's scene puts no ink of its own on the plate:
        // its windows draw on their own fills, its menu bar is a
        // wash of `lightInk`, its ring is the verdict's.
    ]
}
