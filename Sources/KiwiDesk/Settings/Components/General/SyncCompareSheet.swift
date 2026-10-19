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
    /// Return keeps the folder's setup, as when a folder holding
    /// one was just chosen to follow (#2324 slice 3); else Cancel.
    var keepsFolderByDefault = false
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
            isDefault: request.keepsFolderByDefault,
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

    /// Cancel is the default — every Keep sends a setup to the
    /// Trash — save where the folder's setup is the one to keep.
    private var footer: some View {
        HStack {
            escapeRoute
            Spacer()
            if request.keepsFolderByDefault {
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
