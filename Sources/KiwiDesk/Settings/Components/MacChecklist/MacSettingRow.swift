import AppKit
import KiwiDeskCore
import SwiftUI

/// One macOS setting on the checklist (#1365): a status chip
/// (glyph + word, never hue alone), the title, the caption with
/// its System Settings link. macOS answers the row; only an
/// unreadable read falls back to the user's own checkbox.
struct MacSettingRow: View {
    @ObservedObject var model: SettingsModel
    let key: MacChecklistKey
    let setting: MacSetting
    let control: SettingsControl
    /// `MacSettingRow.chipWidth`, measured once by the section.
    let chipWidth: CGFloat

    var body: some View {
        Group {
            if state == .unreadable {
                fallback
            } else {
                detected
            }
        }
        .searchAnchored(control)
    }

    private var state: MacSettingState {
        MacChecklistProgress.state(of: setting, in: model)
    }

    /// The detected shape: one VoiceOver element whose label is
    /// the title and whose value is the verdict, the caption's
    /// link staying a sibling so it stays followable.
    private var detected: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(
                alignment: .firstTextBaseline,
                spacing: Self.rowSpacing
            ) {
                chip
                Text(control.text)
                    .font(.body)
                    .foregroundStyle(SettingsTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(control.text)
            .accessibilityValue(spokenState)
            caption(MacChecklistText.caption(for: key))
                .padding(.leading, chipWidth + Self.rowSpacing)
        }
    }

    /// The fallback shape: a native checkbox owning the title,
    /// stored per machine (`SettingsModel.setMacChecklistTick`).
    private var fallback: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(control.text, isOn: tickBinding)
                .toggleStyle(.checkbox)
            caption(MacChecklistText.unreadable)
                .padding(.leading, chipWidth + Self.rowSpacing)
        }
    }

    private var tickBinding: Binding<Bool> {
        Binding(
            get: { model.macChecklistTicks.contains(setting) },
            set: { model.setMacChecklistTick(setting, $0) }
        )
    }

    /// Set: filled check in the confirmation green
    /// (`LoginItemCard`'s applied mark); not yet: an empty ring
    /// in the tertiary ink. Both carry their word.
    private var chip: some View {
        HStack(spacing: Self.chipSpacing) {
            Image(
                systemName: state == .set
                    ? "checkmark.circle.fill" : "circle"
            )
            Text(chipWord)
        }
        .font(Self.chipFont)
        .foregroundStyle(
            state == .set
                ? SettingsTheme.groupHeading : SettingsTheme.ink3
        )
        .frame(width: chipWidth, alignment: .leading)
    }

    private var chipWord: String {
        state == .set
            ? L("mac_checklist.state.set", "Set")
            : L("mac_checklist.state.not_yet", "Not yet")
    }

    private var spokenState: String {
        state == .set
            ? L(
                "mac_checklist.state.set.spoken",
                "Set, read from your Mac"
            )
            : L(
                "mac_checklist.state.not_yet.spoken",
                "Not yet, read from your Mac"
            )
    }

    /// The why, then the System Settings path as the link.
    private func caption(_ frame: String) -> some View {
        let (leading, trailing) = CrossReferenceRow.split(frame)
        return LinkedCaption(
            leading: leading,
            linkTitle: MacChecklistText.pathLabel,
            trailing: trailing,
            navigate: MacSettingRead.openDesktopAndDock
        )
    }

    /// The chip column: the tree's readout width, or the wider of
    /// the two words plus the glyph where a locale outgrows it —
    /// a `Text` in a fixed frame truncates, and a truncated state
    /// word is the row saying nothing. Measured at the WEIGHT the
    /// chip draws, once per container render, never per row.
    @MainActor static var chipWidth: CGFloat {
        let font = chipNSFont
        let widest =
            [
                L("mac_checklist.state.set", "Set"),
                L("mac_checklist.state.not_yet", "Not yet"),
            ]
            .map { ($0 as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        return max(
            SettingsMetrics.readoutColumn,
            ceil(widest) + glyphWidth + chipSpacing
        )
    }
    /// The chip's type, declared ONCE: the drawing wraps the
    /// same `NSFont` the measure uses, so they cannot drift.
    private static var chipNSFont: NSFont {
        NSFont.systemFont(
            ofSize: NSFont.preferredFont(forTextStyle: .caption1)
                .pointSize,
            weight: .medium
        )
    }
    private static var chipFont: Font { Font(chipNSFont) }
    /// The chip's glyph at the caption size, generously.
    private static let glyphWidth: CGFloat = 16
    /// The gap between the glyph and the word.
    static let chipSpacing: CGFloat = 3
    static let rowSpacing: CGFloat = 10
}
