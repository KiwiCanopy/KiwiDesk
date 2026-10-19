import KiwiDeskCore
import SwiftUI

/// One side of the comparison, with the button that keeps it. Rows
/// common to both sides line up — In, Changed, On, Profiles — each a
/// grey glyph and a bare value, the words kept for VoiceOver (#2324
/// ruling 14).
struct SyncSideCard: View {
    let heading: String
    let location: String
    let symbol: String
    let side: SyncSide
    let isNewer: Bool
    let newerFormat: Bool
    let button: String
    let hint: String
    let refusal: String?
    var isDefault = false
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            details
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 10)
            keep
            if let refusal {
                SyncWarning(text: refusal)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .background(
            SettingsTheme.panel,
            in: RoundedRectangle(cornerRadius: 10)
        )
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .foregroundStyle(SettingsTheme.ink3)
                    .accessibilityHidden(true)
                Text(heading)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                if isNewer { newerChip }
            }
            ForEach(rows, id: \.glyph) { row in
                SyncSideRow(row: row)
            }
            if newerFormat {
                Text(SyncText.newerLine)
                    .font(.callout)
                    .foregroundStyle(SettingsTheme.ink2)
            }
        }
    }

    /// Which side changed last: a neutral capsule, never the accent,
    /// which would read as the side to pick.
    private var newerChip: some View {
        Label(SyncText.newerTag, systemImage: "clock")
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(SettingsTheme.chipRest, in: Capsule())
            .overlay(
                Capsule().strokeBorder(SettingsTheme.chipEdge, lineWidth: 0.5)
            )
    }

    private var rows: [SyncSideRow.Model] {
        var rows = [
            SyncSideRow.Model(
                glyph: "internaldrive",
                value: location,
                spoken: SyncText.inLocation(location)
            )
        ]
        guard let changed = side.lastChanged else {
            rows.append(
                SyncSideRow.Model(
                    glyph: "calendar",
                    value: SyncText.nothingHere,
                    spoken: SyncText.nothingHere
                )
            )
            return rows
        }
        rows.append(
            SyncSideRow.Model(
                glyph: "calendar",
                value: SyncText.date(changed),
                spoken: SyncText.changed(changed)
            )
        )
        if let mac = side.mac {
            rows.append(
                SyncSideRow.Model(
                    glyph: "mappin",
                    value: mac,
                    spoken: SyncText.on(mac)
                )
            )
        }
        rows.append(
            SyncSideRow.Model(
                glyph: "square.stack.3d.up",
                value: SyncText.profiles(side.profileCount),
                spoken: SyncText.profiles(side.profileCount)
            )
        )
        return rows
    }

    /// The default Keep wears the accent and takes Return.
    @ViewBuilder private var keep: some View {
        if isDefault {
            Button(action: action) { label }
                .keyboardShortcut(.defaultAction)
                .modifier(KeepTraits(hint: hint, refused: refusal != nil))
                .kiwiProminentButton()
        } else {
            Button(action: action) { label }
                .modifier(KeepTraits(hint: hint, refused: refusal != nil))
                .settingsActionButton()
        }
    }

    private var label: some View {
        Text(button).frame(maxWidth: .infinity)
    }
}

/// What both forms of a Keep button share.
private struct KeepTraits: ViewModifier {
    let hint: String
    let refused: Bool

    func body(content: Content) -> some View {
        content
            .controlSize(.large)
            .disabled(refused)
            .accessibilityHint(hint)
    }
}

/// One card row: a grey glyph in a fixed column and its value, spoken
/// with the word the glyph stands for.
struct SyncSideRow: View {
    struct Model {
        let glyph: String
        let value: String
        let spoken: String
    }

    let row: Model

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: row.glyph)
                .imageScale(.small)
                .foregroundStyle(SettingsTheme.ink3)
                .frame(width: 16)
                .accessibilityHidden(true)
            Text(row.value)
                .foregroundStyle(SettingsTheme.ink2)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.callout)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.spoken)
    }
}
