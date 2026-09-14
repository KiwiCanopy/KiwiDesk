import AppKit
import KiwiDeskCore
import SwiftUI

/// One macOS setting on the checklist (#1365): tick · title ·
/// caption, the tick LEADING because a progress count reads off
/// that column. The tick is a status chip — glyph + word, so the
/// state rides shape and text and never hue alone — and not a
/// control: macOS answers this row. Only where macOS would not
/// answer does the row fall back to the user's own checkbox,
/// since a detected tick that lies is worse than a self-tick.
struct MacSettingRow: View {
    @ObservedObject var model: SettingsModel
    let key: MacChecklistKey
    let setting: MacSetting
    let control: SettingsControl

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
        model.macChecklistStates[setting] ?? .notSet
    }

    /// The detected shape: one VoiceOver element whose label is
    /// the title and whose value is the verdict, the caption's
    /// link staying a sibling so it stays followable.
    private var detected: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
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
                .padding(.leading, Self.captionInset)
        }
    }

    /// The fallback shape: a native checkbox owning the title,
    /// stored per machine (`SettingsModel.setMacChecklistTick`).
    private var fallback: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(control.text, isOn: tickBinding)
                .toggleStyle(.checkbox)
            caption(MacChecklistText.unreadable)
                .padding(.leading, Self.captionInset)
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
        HStack(spacing: 3) {
            Image(
                systemName: state == .set
                    ? "checkmark.circle.fill" : "circle"
            )
            Text(chipWord)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(
            state == .set
                ? SettingsTheme.groupHeading : SettingsTheme.ink3
        )
        .frame(width: Self.chipWidth, alignment: .leading)
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
        let (leading, trailing) = Self.split(frame)
        return LinkedCaption(
            leading: leading,
            linkTitle: MacChecklistText.pathLabel,
            trailing: trailing,
            navigate: MacSettingRead.openDesktopAndDock
        )
    }

    /// Splits at `CrossReferenceRow.linkSlot`, the same token the
    /// habit rows' cross-references carry.
    static func split(_ frame: String) -> (String, String) {
        guard let slot = frame.range(of: CrossReferenceRow.linkSlot)
        else {
            assertionFailure("checklist caption has no path slot")
            return (frame + " ", "")
        }
        return (
            String(frame[..<slot.lowerBound]),
            String(frame[slot.upperBound...])
        )
    }

    /// The chip column's width, so titles align across rows.
    static let chipWidth: CGFloat = 60
    /// Caption indent = chip column + row spacing.
    static let captionInset: CGFloat = chipWidth + 10
}
