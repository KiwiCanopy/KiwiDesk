import KiwiDeskCore
import SwiftUI

/// The one Liquid Glass switch, over both bars and the ⌃⌥K
/// shortcuts panel (#1307, `SettingKey.masterWrites`).
extension SettingsModel {
    /// On only when ALL THREE surfaces carry glass; a flip writes
    /// all three. Owner ruling 2026-09-07: the switch means "all
    /// three", so `off` stays a true statement while they
    /// disagree, and the `?` carries what a boolean cannot.
    var liquidGlassMaster: Binding<Bool> {
        Binding(
            get: {
                LiquidGlassAgreement(
                    settings: self.config.settings
                ).allOn
            },
            set: { on in
                var next = self.config.settings
                next.appBarStyle.liquidGlass = on
                next.spaceBarStyle.liquidGlass = on
                next.shortcutPanelLiquidGlass = on
                self.config.settings = next
            }
        )
    }
}

/// The ONE comparison across the three stored leaves: the master
/// binding reads it as its displayed value and the row reads it
/// as the `?` predicate, so the switch and its explanation
/// cannot contradict (`GapsBordersGates.agreedCornerStyle`'s
/// discipline).
struct LiquidGlassAgreement {
    let settings: TilingSettings

    private var leaves: [Bool] {
        [
            settings.appBarStyle.liquidGlass,
            settings.spaceBarStyle.liquidGlass,
            settings.shortcutPanelLiquidGlass,
        ]
    }

    /// Every surface carries glass.
    var allOn: Bool { leaves.allSatisfy { $0 } }

    /// The three disagree — reachable only from hand-written Lua
    /// or an imported profile, never from this row, which writes
    /// all three at once.
    var differ: Bool { Set(leaves).count > 1 }
}
