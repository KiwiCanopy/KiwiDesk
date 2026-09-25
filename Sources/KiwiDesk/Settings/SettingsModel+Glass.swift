import KiwiDeskCore
import SwiftUI

/// The one Liquid Glass switch, over the bars' shelf, the ⌃⌥K
/// shortcuts panel, the drag markers and the sticky mark (#1307,
/// #1517, #1620, #1621, `SettingKey.masterWrites`).
extension SettingsModel {
    /// On only when EVERY stored leaf carries glass; a flip writes
    /// them all. Owner ruling 2026-09-07: the switch means "all of
    /// them", so `off` stays a true statement while they
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
                next.kiwishelf.liquidGlass = on
                next.shortcutPanelLiquidGlass = on
                next.dragLiquidGlass = on
                next.stickyStyle.liquidGlass = on
                self.config.settings = next
            }
        )
    }
}

/// The ONE comparison across the stored leaves: the master
/// binding reads it as its displayed value and the row reads it
/// as the `?` predicate, so the switch and its explanation
/// cannot contradict (`GapsBordersGates.agreedCornerStyle`'s
/// discipline).
struct LiquidGlassAgreement {
    let settings: TilingSettings

    private var leaves: [Bool] {
        [
            settings.kiwishelf.liquidGlass,
            settings.shortcutPanelLiquidGlass,
            settings.dragLiquidGlass,
            settings.stickyStyle.liquidGlass,
        ]
    }

    /// Every surface carries glass.
    var allOn: Bool { leaves.allSatisfy { $0 } }

    /// The leaves disagree — reachable from hand-written Lua or
    /// an imported profile, never from this row, which writes
    /// every leaf at once. The bars have one leaf since #1517, so
    /// no per-layout override can disagree with it.
    var differ: Bool { Set(leaves).count > 1 }
}
