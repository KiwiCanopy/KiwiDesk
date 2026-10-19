import KiwiDeskCore
import SwiftUI

/// One Compare and Copy, handed to the sheet by `item:` (#843).
struct SyncCompareRequest: Identifiable {
    let id = UUID()
    let folder: URL
    /// The folder as Finder names it, the folder card's heading.
    let folderName: String
    let comparison: SyncComparison
    /// The draft holds edits nobody saved (#2324 ruling 14).
    let unsaved: Bool
    /// Why Save cannot run first, where it cannot.
    let saveBlocked: String?
    /// Return presses Keep This Mac's rather than Cancel.
    let returnKeepsThisMac: Bool
}

/// Compare and Copy's sheet (#2324 slice 2): both setups side by
/// side, each with the button that keeps it. Its commit runs
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

    private var returnKeepsThisMac: Bool { request.returnKeepsThisMac }

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
            symbol: "desktopcomputer",
            side: comparison.thisMac,
            isNewer: newer == .thisMac,
            extra: request.unsaved ? SyncText.unsavedLine : nil,
            button: request.unsaved
                ? SyncText.saveAndKeepThisMac : SyncText.keepThisMac,
            hint: SyncText.keepThisMacHint,
            refusal: thisMacRefusal,
            isDefault: returnKeepsThisMac,
            action: onKeepThisMac
        )
    }

    private var folderCard: some View {
        SyncSideCard(
            heading: request.folderName,
            symbol: "folder",
            side: comparison.folder,
            isNewer: newer == .folder,
            extra: folderIsNewerFormat ? SyncText.newerLine : nil,
            button: SyncText.keepFolder,
            hint: SyncText.keepFolderHint,
            refusal: folderRefusal,
            isDefault: false,
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

    @ViewBuilder private var notes: some View {
        note(SyncText.includes, warn: false)
        if !comparison.folder.isEmpty {
            note(SyncText.trashNote, warn: false)
        }
        if request.unsaved, comparison.keepFolderRefusal == nil {
            note(SyncText.replacesEdits, warn: true)
        }
    }

    private func note(_ text: String, warn: Bool) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(
                warn ? SettingsTheme.warningInk : SettingsTheme.ink2
            )
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var footer: some View {
        HStack {
            escapeRoute
            Spacer()
            if returnKeepsThisMac {
                Button(SyncText.cancel, action: onCancel)
                    .controlSize(.large)
                    .settingsActionButton()
            } else {
                Button(SyncText.cancel, action: onCancel)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .kiwiProminentButton()
            }
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

/// One side of the comparison, with the button that keeps it.
private struct SyncSideCard: View {
    let heading: String
    let symbol: String
    let side: SyncSide
    let isNewer: Bool
    let extra: String?
    let button: String
    let hint: String
    let refusal: String?
    let isDefault: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            details
                .accessibilityElement(children: .combine)
            Spacer(minLength: 10)
            keep
            if let refusal {
                Text(refusal)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.warningInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .background(
            SettingsTheme.panel,
            in: RoundedRectangle(cornerRadius: 10)
        )
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .foregroundStyle(SettingsTheme.ink3)
                    .accessibilityHidden(true)
                Text(heading)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 4)
                if isNewer {
                    Label(SyncText.newerTag, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(SettingsTheme.ink)
                }
            }
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.callout)
                    .foregroundStyle(SettingsTheme.ink2)
            }
        }
    }

    private var lines: [String] {
        guard let changed = side.lastChanged else {
            return [SyncText.nothingHere]
        }
        var lines = [extra, SyncText.changed(changed)].compactMap { $0 }
        if let mac = side.mac { lines.append(SyncText.on(mac)) }
        lines.append(SyncText.profiles(side.profileCount))
        return lines
    }

    @ViewBuilder private var keep: some View {
        let control = Button(action: action) {
            Text(button).frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .disabled(refusal != nil)
        .accessibilityHint(hint)
        if isDefault {
            control.keyboardShortcut(.defaultAction).kiwiProminentButton()
        } else {
            control.settingsActionButton()
        }
    }
}
