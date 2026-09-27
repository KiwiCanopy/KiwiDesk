import CoreGraphics
import KiwiDeskCore

/// The sheen's signed wording (#1644): the readout, the spoken
/// value and the diff pill read it alike. Each direction is its
/// own key, the number last (localization.md).
extension SettingsValueReadout {
    /// "+50%", "−50%" or "Off".
    static func sheen(_ strength: CGFloat) -> String {
        if strength > 0 {
            return L(
                "colors.sheen.readout.lighter",
                "+%1$@",
                percent(Double(strength))
            )
        }
        if strength < 0 {
            return L(
                "colors.sheen.readout.darker",
                "−%1$@",
                percent(Double(-strength))
            )
        }
        return onOff(false)
    }

    /// "Lighter by 50%", "Darker by 50%" or "Off".
    static func sheenSpoken(_ strength: CGFloat) -> String {
        if strength > 0 {
            return L(
                "colors.sheen.spoken.lighter",
                "Lighter by %1$@",
                percent(Double(strength))
            )
        }
        if strength < 0 {
            return L(
                "colors.sheen.spoken.darker",
                "Darker by %1$@",
                percent(Double(-strength))
            )
        }
        return onOff(false)
    }
}
