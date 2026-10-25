import KiwiDeskCore
import SwiftUI

/// The one Liquid Glass switch, over both bars and the ⌃⌥K
/// shortcuts panel (#1307), the Fill and the two rows it greys —
/// "Tint KiwiHub and plates" and "Fill fade" (#2569, #2593) — and
/// the sheen's own row last (#1644); the Fill and the sheen alone
/// show below macOS 26. The open group of Colors & glass (#2389).
struct GlassCard: View {
    @ObservedObject var model: SettingsModel
    /// The same OS value the glass surfaces read live (#1374);
    /// here it greys the switch with its reason (#1418) and
    /// moves no stored value.
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    private var agreement: LiquidGlassAgreement {
        LiquidGlassAgreement(settings: model.config.settings)
    }

    var body: some View {
        SettingsSection(
            SettingsCatalog.colors.liquidGlassGroup,
            caption: AppBarStyle.glassAvailable ? caption : nil,
            subsection: true,
            plated: false
        ) {
            // The grey is per row, honoring the census's
            // exemption: the sheen is not glass and never greys
            // (#1644) — parallel `GreyOut`s, never nested
            // (gui.md).
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Self.rows, id: \.id) { key in
                    if key == .kiwishelf(.fillColor) {
                        // A colour row, greyed by its own verdict.
                        ColorsAndGlassRows(model: model, keys: [key])
                    } else {
                        row(key).modifier(GreyOut(active: greyed(key)))
                    }
                    reasonCaption(for: key)
                }
            }
        }
    }

    /// The card's rows as this Mac draws them: the switch is
    /// hidden below macOS 26, never greyed — an OS-capability gate
    /// is an absence (#390), which the census records in the HIDES
    /// group — while the sheen, which is not glass, stays (#1644).
    static var rows: [SettingKey] {
        ColorsRowOrder.glassRows.filter {
            !$0.placement.hiddenWithoutGlass
        }
    }

    /// Whether Reduce transparency greys `key`: the card's gate,
    /// less the census's exemption.
    private func greyed(_ key: SettingKey) -> Bool {
        (reduceTransparency && !key.placement.exemptFromContainerGate)
            || (Self.followsTheFill(key) && fillIdle)
    }

    /// The rows the switch and the Fill both gate (#2569).
    static func followsTheFill(_ key: SettingKey) -> Bool {
        key == .kiwishelf(.tintHubAndPlates) || key == .kiwishelf(.fillFade)
    }

    /// The Fill's rows have nothing to do: the switch is off, or
    /// the Fill has no colour (#2569 ▸ "No Colour").
    private var fillIdle: Bool {
        !model.liquidGlassMaster.wrappedValue || !shelf.hasFill
    }

    private var shelf: KiwiShelf { model.config.settings.kiwishelf }

    /// The Reduce-transparency reason, under the switch it greys
    /// and outside that grey so it survives the dim (#527) — never
    /// on the header, which would claim it for the sheen too. The
    /// Fill's grey needs none: the Fill sits right above (#2593).
    @ViewBuilder private func reasonCaption(
        for key: SettingKey
    ) -> some View {
        if reduceTransparency, key == .colours(.liquidGlassMaster) {
            Text(reduceTransparencyHelp)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func row(_ key: SettingKey) -> some View {
        switch key {
        case .colours(.liquidGlassMaster):
            ToggleRow(
                label: Self.title,
                isOn: model.liquidGlassMaster,
                help: agreement.differ ? differHelp : baseHelp
            )
        case .kiwishelf(.tintHubAndPlates):
            ToggleRow(
                label: SettingsCatalog.colors.tintHubAndPlates.text,
                isOn: $model.config.settings.kiwishelf.tintHubAndPlates,
                help: L(
                    "kiwishelf.tint_hub_and_plates.help",
                    "%1$@ and the plates a Space, Desktop or layout "
                        + "switch shows wear the bars' %2$@ and colors "
                        + "on clear glass. Off, they draw plain frosted "
                        + "glass.",
                    JumpScope.panelName,
                    L("kiwishelf.color.fill", "Fill")
                )
            )
            .searchAnchored(SettingsCatalog.colors.tintHubAndPlates)
        case .kiwishelf(.fillFade):
            FillFadeRow(fade: $model.config.settings.kiwishelf.fillFade)
                .searchAnchored(SettingsCatalog.colors.fillFade)
        case .colours(.borderSheen):
            SheenRow(strength: $model.config.settings.borderStyle.sheen)
                .searchAnchored(SettingsCatalog.colors.sheenStrength)
        default:
            let _ = assertionFailure(
                "unrendered Glass census key: \(key.id)"
            )
            EmptyView()
        }
    }

    /// Quotes Apple's own control (config-vocabulary.md) so the
    /// user can find the row.
    private var reduceTransparencyHelp: String {
        L(
            "colors.liquid_glass.reduce_transparency.help",
            "System Settings ▸ Accessibility ▸ Display ▸ Reduce "
                + "transparency is on, so the glass stays off "
                + "regardless of this setting."
        )
    }

    /// ONE key for the card and its only row: the product name
    /// twice under its own header is a second string nothing
    /// holds in step (localization-auditor, 2026-09-07).
    static var title: String {
        L("colors.liquid_glass", "Liquid Glass")
    }

    private var caption: String {
        L(
            "colors.glass.caption",
            "A translucent material over both bars, %1$@, the "
                + "drag ghost and drop zone, the sticky mark and the "
                + "plates a Space switch slides.",
            JumpScope.panelName
        )
    }

    /// The material's NAME is deliberately absent from both help
    /// strings: the card's title carries it directly above.
    /// KiwiHub is named by its key (#818, #2265).
    private var baseHelp: String {
        L(
            "colors.liquid_glass.help",
            "Lays macOS's translucent material over the Space "
                + "Bar, the App Bar, %2$@, the drag ghost and drop "
                + "zone, the sticky mark and the plates a Space "
                + "switch slides. KiwiShelf's %1$@ color tints the "
                + "bars, fading from their screen edge as far as "
                + "\u{201C}%3$@\u{201D} sets; with "
                + "\u{201C}%4$@\u{201D} on, it tints %2$@ and the "
                + "plates too. The drag ghost, drop zone and sticky "
                + "mark take their own colors.",
            L("kiwishelf.color.fill", "Fill"),
            JumpScope.panelName,
            L("kiwishelf.fill_fade", "Fill fade"),
            SettingsCatalog.colors.tintHubAndPlates.text
        )
    }

    /// Owed only while the surfaces disagree, which only Lua or an
    /// imported profile can produce: a boolean cannot show "some
    /// of them", so this sentence carries what the switch cannot,
    /// and both read the ONE `LiquidGlassAgreement`.
    private var differHelp: String {
        L(
            "colors.liquid_glass.differ.help",
            "These surfaces are set differently right now. "
                + "Turning this on switches it on for all of "
                + "them."
        )
    }
}
