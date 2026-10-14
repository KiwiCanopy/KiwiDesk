import KiwiDeskCore
import SwiftUI

/// KiwiVision ▸ Dim and blur (#2103). Under Reduce transparency
/// the card greys as a unit (its census gate, Glass's shape,
/// #1418) with the dim exempt, and the reason sits under Blur,
/// outside the grey so it survives the dim (#527).
struct KiwiVisionLevelsCard: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    var body: some View {
        SettingsSection(
            SettingsCatalog.kiwiVision.levelsCard,
            caption: KiwiVisionCopy.appliesAtOnce
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(KiwiVisionRowOrder.levels, id: \.id) { key in
                    row(key).modifier(GreyOut(active: greyed(key)))
                    reasonCaption(for: key)
                }
            }
        }
    }

    private var gates: KiwiVisionGates {
        KiwiVisionGates(guiManaged: model.guiManaged)
    }

    /// Whether Reduce transparency greys `key`: the card's gate,
    /// less the census's exemption.
    private func greyed(_ key: SettingKey) -> Bool {
        reduceTransparency && !key.placement.exemptFromContainerGate
    }

    @ViewBuilder private func row(_ key: SettingKey) -> some View {
        switch key {
        case .kiwiVision(.dim): dimRow
        case .kiwiVision(.blur): blurRow
        default:
            let _ = assertionFailure(
                "unrendered KiwiVision census key: \(key.id)"
            )
            EmptyView()
        }
    }

    /// 0–100 % in 5 % steps, any value typed in range (ruling 10);
    /// a stored fraction from Lua shows rounded.
    private var dimRow: some View {
        let label = SettingsCatalog.kiwiVision.dim.text
        return SettingsRowShape {
            SettingsRowLabel(label: label, help: nil)
        } control: {
            StepperRow(
                label: label,
                value: Binding(
                    get: { Int(model.appWide.visionDim.rounded()) },
                    set: { percent in
                        model.setAppWide { $0.visionDim = Double(percent) }
                    }
                ),
                in: 0...100,
                step: 5,
                suffix: "%",
                labelHidden: true
            )
            .disabled(gates.inertReason(for: .kiwiVision(.dim)) != nil)
        }
        .searchAnchored(SettingsCatalog.kiwiVision.dim)
    }

    private var blurRow: some View {
        ToggleRow(
            label: SettingsCatalog.kiwiVision.blur.text,
            isOn: Binding(
                get: { model.appWide.visionBlur },
                set: { on in model.setAppWide { $0.visionBlur = on } }
            ),
            help: L(
                "kiwivision.blur.help",
                "Blurs the windows behind the focused one as well as "
                    + "dimming them. If you notice a faint flicker, "
                    + "turn %1$@ off; the dim alone does not flicker.",
                SettingsCatalog.kiwiVision.blur.text
            ),
            disabled: gates.inertReason(for: .kiwiVision(.blur)) != nil
        )
        .searchAnchored(SettingsCatalog.kiwiVision.blur)
    }

    /// The Lua-owned reason under its row, and Reduce
    /// transparency's under Blur — never on the header, which
    /// would claim it for the dim too.
    @ViewBuilder private func reasonCaption(
        for key: SettingKey
    ) -> some View {
        if let reason = gates.inertReason(for: key) {
            KiwiVisionCopy.reason(KiwiVisionGates.sentence(for: reason))
        } else if reduceTransparency, key == .kiwiVision(.blur) {
            KiwiVisionCopy.reason(
                L(
                    "kiwivision.blur.reduce_transparency.help",
                    "System Settings ▸ Accessibility ▸ Display ▸ "
                        + "Reduce transparency is on, so the windows "
                        + "behind are dimmed but not blurred, "
                        + "regardless of this setting."
                )
            )
        }
    }
}

/// Strings and the reason line the KiwiVision cards share.
@MainActor
enum KiwiVisionCopy {
    /// Each immediate card says so (#1741), since v3's lens cards
    /// beside them save through Save.
    static var appliesAtOnce: String {
        L("kiwivision.applies_at_once", "Applies at once, in every profile.")
    }

    static func reason(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink3)
            .fixedSize(horizontal: false, vertical: true)
    }
}
