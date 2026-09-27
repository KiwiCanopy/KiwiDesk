import KiwiDeskCore
import SwiftUI

/// The KiwiShelf Style drawer's font family and weight rows
/// (#1681).
extension KiwiShelfCard {
    var fontFamilyRow: some View {
        FontFamilyRow(family: shelf.fontFamily)
            .searchAnchored(
                SettingsCatalog.bars.kiwishelfStyle.children
                    .kiwishelfStyleFontFamily
            )
    }

    var fontWeightRow: some View {
        let reason = gates.fontWeightReason
        return FontWeightRow(
            weight: shelf.fontWeight,
            family: shelf.fontFamily.wrappedValue
        )
        .modifier(
            GreyOut(
                active: reason != nil,
                help: reason.map(BarsGateHelp.sentence(for:)) ?? ""
            )
        )
        .searchAnchored(
            SettingsCatalog.bars.kiwishelfStyle.children
                .kiwishelfStyleFontWeight
        )
    }
}

/// The family trigger: a menu-shaped button naming the stored
/// family and opening `FontFamilyPicker`. A family that is not
/// installed keeps its name, beside a warning glyph and words.
struct FontFamilyRow: View {
    @Binding var family: String
    @State private var showing = false

    private var label: String { L("kiwishelf.font_family", "Font") }
    private var missing: Bool { !BarFont.isInstalled(family) }

    var body: some View {
        SettingsRowShape {
            SettingsRowLabel(
                label: label,
                help: L(
                    "kiwishelf.font_family.help",
                    "The typeface of both bars' text — Space "
                        + "identifiers, titles and counts. App "
                        + "glyphs keep their own."
                )
            )
        } control: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    trigger
                    Spacer(minLength: 0)
                }
                // Its own wrapping line: beside the trigger it
                // truncated in a narrow window.
                if missing {
                    Label(
                        BarFontText.missing,
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SettingsTheme.warningInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
                }
            }
        }
    }

    private var trigger: some View {
        Button {
            showing = true
        } label: {
            HStack(spacing: 4) {
                Text(BarFontText.familyName(family))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 150, alignment: .leading)
        }
        .settingsActionButton()
        .controlSize(.large)
        .accessibilityLabel(label)
        .accessibilityValue(spokenValue)
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            FontFamilyPicker(
                selection: family,
                onPick: {
                    family = $0
                    showing = false
                },
                onClose: { showing = false }
            )
        }
    }

    /// The family, and for a missing one the trigger's words too.
    private var spokenValue: String {
        let name = BarFontText.familyName(family)
        guard missing else { return name }
        return L(
            "kiwishelf.font_family.missing.ax",
            "%1$@, %2$@",
            name,
            BarFontText.missing
        )
    }
}
