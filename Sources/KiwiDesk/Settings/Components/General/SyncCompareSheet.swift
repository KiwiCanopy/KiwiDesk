import KiwiDeskCore
import SwiftUI

/// One Compare and Copy, handed to the sheet by `item:` (#843).
struct SyncCompareRequest: Identifiable {
    let id = UUID()
    let folder: URL
    /// The folder as Finder names it, the folder card's heading.
    let folderName: String
    /// Where the folder lies, "~ ▸ Dotfiles".
    let folderLocation: String
    /// Where this Mac's setup lies, its config folder as named.
    let thisMacLocation: String
    let comparison: SyncComparison
    /// The draft holds edits nobody saved (#2324 ruling 14).
    let unsaved: Bool
    /// Why Save cannot run first, where it cannot.
    let saveBlocked: String?
}

/// Compare and Copy's sheet (#2324 slice 2): both setups side by
/// side, each with the button that keeps it. An empty folder takes
/// the row's one-way alert instead (ruling 14). Its commit runs
/// through the host's closures and it takes no model — the second
/// ruled exception to a read-only sheet, after #1870's
/// (`SheetPresentationSeamTests`).
struct SyncCompareSheet: View {
    let request: SyncCompareRequest
    let onKeepThisMac: () -> Void
    let onKeepFolder: () -> Void
    let onCancel: () -> Void

    private static let pad: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            HStack(alignment: .top, spacing: 12) {
                thisMacCard
                folderCard
            }
            notes
            footer
        }
        .padding(Self.pad)
        .frame(width: 560)
        .background(SettingsTheme.card)
    }

    private var comparison: SyncComparison { request.comparison }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(SyncText.title)
                .font(.title3)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            Text(SyncText.body)
                .font(.callout)
                .foregroundStyle(SettingsTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Cards

    private var thisMacRefusal: String? {
        comparison.keepThisMacRefusal.map(SyncText.sentence(for:))
            ?? (request.unsaved ? request.saveBlocked : nil)
    }

    private var folderRefusal: String? {
        comparison.keepFolderRefusal.map(SyncText.sentence(for:))
    }

    private var thisMacCard: some View {
        SyncSideCard(
            heading: SyncText.thisMac,
            location: request.thisMacLocation,
            symbol: "desktopcomputer",
            side: comparison.thisMac,
            isNewer: newer == .thisMac,
            newerFormat: false,
            button: request.unsaved
                ? SyncText.saveAndKeepThisMac : SyncText.keepThisMac,
            hint: SyncText.keepThisMacHint,
            refusal: thisMacRefusal,
            action: onKeepThisMac
        )
    }

    private var folderCard: some View {
        SyncSideCard(
            heading: request.folderName,
            location: request.folderLocation,
            symbol: "folder",
            side: comparison.folder,
            isNewer: newer == .folder,
            newerFormat: folderIsNewerFormat,
            button: SyncText.keepFolder,
            hint: SyncText.keepFolderHint,
            refusal: folderRefusal,
            action: onKeepFolder
        )
    }

    private enum Side { case thisMac, folder }

    /// The side changed last, marked by a word, never by hue.
    private var newer: Side? {
        guard let mine = comparison.thisMac.lastChanged,
            let theirs = comparison.folder.lastChanged, mine != theirs
        else { return nil }
        return mine > theirs ? .thisMac : .folder
    }

    private var folderIsNewerFormat: Bool {
        if case .folderNewer? = comparison.keepFolderRefusal {
            return true
        }
        return false
    }

    // MARK: - Notes and footer

    /// One block, so the notes read as a paragraph rather than
    /// taking the sheet's section spacing between them.
    private var notes: some View {
        VStack(alignment: .leading, spacing: 4) {
            note(SyncText.includes)
            note(SyncText.trashNote)
            if request.unsaved, comparison.keepFolderRefusal == nil {
                SyncWarning(text: SyncText.replacesEdits, font: .callout)
                    .padding(.top, 4)
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(SettingsTheme.ink2)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Cancel is the default: every Keep sends a setup to the Trash.
    private var footer: some View {
        HStack {
            escapeRoute
            Spacer()
            Button(SyncText.cancel, action: onCancel)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .kiwiProminentButton()
        }
    }

    /// Escape as a hidden `.cancelAction` button (#859), since
    /// `.onExitCommand` needs focus the sheet may not hold.
    private var escapeRoute: some View {
        Button(SyncText.cancel, action: onCancel)
            .keyboardShortcut(.cancelAction)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
    }
}

/// One side of the comparison, with the button that keeps it. Rows
/// common to both sides line up — In, Changed, On, Profiles — each a
/// grey glyph and a bare value, the words kept for VoiceOver (#2324
/// ruling 14).
private struct SyncSideCard: View {
    let heading: String
    let location: String
    let symbol: String
    let side: SyncSide
    let isNewer: Bool
    let newerFormat: Bool
    let button: String
    let hint: String
    let refusal: String?
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

    private var keep: some View {
        Button(action: action) {
            Text(button).frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .disabled(refusal != nil)
        .accessibilityHint(hint)
        .settingsActionButton()
    }
}

/// One card row: a grey glyph in a fixed column and its value, spoken
/// with the word the glyph stands for.
private struct SyncSideRow: View {
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
