import SwiftUI

extension View {
    /// The one way a Settings action button takes the bordered
    /// style: paired with its label neutralisation, by
    /// construction.
    ///
    /// `.buttonStyle(.bordered)` paints its label from the tint,
    /// and once #678 turn 16b tinted the window kiwi every
    /// bordered button in Settings became green text (#759). The
    /// first fix applied `.neutralButtonLabel()` beside the style
    /// at every call site, which left the style and its
    /// neutralisation two independent decisions a site can get
    /// half right — and left `SettingsLabelNeutralityTests`
    /// counting three hand-kept registers to prove nobody had
    /// (#771). This seal removes the arithmetic: a site that
    /// styles through here cannot skip the neutralisation,
    /// so the guard now only has to pin that no raw
    /// `.buttonStyle(.bordered)` appears outside it.
    ///
    /// Not for every button, same as before the seal:
    ///
    /// - A `role: .destructive` button keeps the raw style — the
    ///   system red IS the warning and neutralising it would
    ///   paint a delete action in the same ink as a save. Its
    ///   file names itself in `SettingsBorderedSealTests`'
    ///   `borderedExempt` map, the one copy of who may.
    /// - `KeyRecorderField` resolves its own tint per state and
    ///   is exempt the same way.
    /// - `.borderedProminent` is a filled control whose accent
    ///   IS the fill; it never goes through here.
    ///
    /// The first link is written WITHOUT a leading dot on
    /// purpose: the guards' needles are `.buttonStyle(` and
    /// `.buttonStyle(.bordered)`, so the seal's own use stays
    /// out of every call-site count and is pinned by its own
    /// assertion instead (`SettingsBorderedSealTests`'
    /// `sealPairsStyleAndNeutralisation`).
    func settingsActionButton() -> some View {
        buttonStyle(.bordered)
            .neutralButtonLabel()
    }
}
