import AppKit
import KiwiDeskCore
import SwiftUI

/// General's last top-level row (#2324 slice 2): the sync folder,
/// remembered on this Mac, and Compare and Copy beside it. It hosts
/// the sheet, since the row outlives the menu that opens it, and the
/// one-way alert an empty folder takes instead (ruling 14). The
/// switch under it keeps the folder in step on its own (slice 3,
/// ruling 15), and the line under that says how it stands.
struct SyncAcrossMacsRow: View {
    @ObservedObject var model: SettingsModel
    @State private var folder: URL?
    @State private var follows = false
    @State private var refusal: SyncRefusal?
    @State private var request: SyncCompareRequest?
    /// A copy into an empty folder: one side, so one question.
    @State private var firstCopy: SyncCompareRequest?
    @State private var failure: SyncRefusal?
    /// A copy's failure, shown once its sheet has gone: an alert
    /// raised while the sheet closes is dropped.
    @State private var pendingFailure: SyncRefusal?

    private enum Pick: Hashable { case none, iCloud, chosen, choose }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            heading
            DropdownRow(
                label: SyncText.folderLabel,
                spokenValue: spokenValue
            ) {
                picker
            } trailing: {
                Button(SyncText.compare, action: compare)
                    .settingsActionButton()
                    .disabled(folder == nil || refusal != nil)
            }
            ToggleRow(
                label: SyncText.follow,
                isOn: followsBinding,
                disabled: folder == nil
            )
            .alert(
                firstCopy.map { SyncText.firstCopyTitle($0.folderName) }
                    ?? "",
                isPresented: firstCopyBinding,
                presenting: firstCopy,
                actions: firstCopyActions,
                message: { Text(firstCopyMessage($0)) }
            )
            if folder != nil,
                refusal != nil || (follows && SyncText.warns(status))
            {
                SyncWarning(text: caption)
            } else {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink2)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            folder = model.syncFolder
            follows = model.syncFollows
            refresh()
        }
        .sheet(item: $request, onDismiss: showFailure) { request in
            SyncCompareSheet(
                request: request,
                onKeepThisMac: { keepThisMac(request) },
                onKeepFolder: { keepFolder(request) },
                onCancel: { self.request = nil }
            )
        }
        .alert(
            SyncText.failedTitle,
            isPresented: failureBinding,
            presenting: failure
        ) { _ in
        } message: { failure in
            Text(SyncText.sentence(for: failure))
        }
    }

    /// The group's heading inside General's card: the feature's name
    /// and its `?` (#2324 ruling 14).
    private var heading: some View {
        HStack(spacing: 5) {
            Text(SyncText.label)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
            HelpButton(explanation: SyncText.help, subject: SyncText.label)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(SettingsTheme.groupHeading)
        .padding(.top, 6)
    }

    /// Each item carries its icon, as a macOS folder picker does.
    private var picker: some View {
        Picker(SyncText.folderLabel, selection: pickBinding) {
            Text(SyncText.none).tag(Pick.none)
            Divider()
            Label(SyncText.iCloudDrive, systemImage: "icloud").tag(Pick.iCloud)
                .selectionDisabled(!SyncFolderLocation.iCloudDriveIsOn)
            if let folder, !SyncFolderLocation.isICloudFolder(folder) {
                Label(folder.lastPathComponent, systemImage: "folder")
                    .tag(Pick.chosen)
            }
            Divider()
            Label(SyncText.chooseFolder, systemImage: "folder").tag(
                Pick.choose
            )
        }
    }

    private var pick: Pick {
        guard let folder else { return .none }
        return SyncFolderLocation.isICloudFolder(folder)
            ? .iCloud : .chosen
    }

    private var pickBinding: Binding<Pick> {
        Binding(get: { pick }, set: choose)
    }

    private var spokenValue: String {
        switch pick {
        case .none, .choose: return SyncText.none
        case .iCloud: return SyncText.iCloudDrive
        case .chosen: return folder?.lastPathComponent ?? SyncText.none
        }
    }

    private var caption: String {
        guard let folder else { return SyncText.noFolderCaption }
        let path = SyncFolderDisplay.path(folder)
        if follows, status != .off {
            return SyncText.status(status, folder: path)
        }
        guard let refusal else { return SyncText.chosenCaption(path) }
        return SyncText.caption(for: refusal)
    }

    private var status: SyncStatus { model.sync.status }

    private var followsBinding: Binding<Bool> {
        Binding(
            get: { follows && folder != nil },
            set: { on in
                follows = on
                model.syncFollows = on
                if on { offerCompareIfDiverged() }
            }
        )
    }

    private var firstCopyBinding: Binding<Bool> {
        Binding(
            get: { firstCopy != nil },
            set: { if !$0 { firstCopy = nil } }
        )
    }

    /// Why a first copy cannot run, if it cannot: this Mac's own
    /// refusal, or a Save that has to land first and cannot.
    private func firstCopyRefusal(_ copy: SyncCompareRequest) -> String? {
        copy.comparison.keepThisMacRefusal.map(SyncText.sentence(for:))
            ?? (copy.unsaved ? copy.saveBlocked : nil)
    }

    private func firstCopyMessage(_ copy: SyncCompareRequest) -> String {
        firstCopyRefusal(copy) ?? SyncText.firstCopyMessage
    }

    @ViewBuilder
    private func firstCopyActions(_ copy: SyncCompareRequest) -> some View {
        if firstCopyRefusal(copy) != nil {
            Button(SyncText.ok) {}
        } else {
            Button(
                copy.unsaved
                    ? SyncText.saveAndCopyToFolder : SyncText.copyToFolder
            ) { copyFirst(copy) }
            .keyboardShortcut(.defaultAction)
            Button(SyncText.cancel, role: .cancel) {}
        }
    }

    private var failureBinding: Binding<Bool> {
        Binding(
            get: { failure != nil },
            set: { if !$0 { failure = nil } }
        )
    }

    // MARK: - Actions

    private func choose(_ pick: Pick) {
        switch pick {
        case .none:
            store(nil)
        case .iCloud:
            let url = SyncFolderLocation.iCloudFolder
            try? FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
            store(url)
        case .chosen:
            break
        case .choose:
            // After the menu closes, or the panel opens behind it.
            DispatchQueue.main.async { chooseFolder() }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = folder
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store(url)
    }

    /// A chosen folder is followed from the start (ruling 15); one
    /// that already holds another setup opens Compare and Copy with
    /// Keep the Folder's as its default.
    private func store(_ url: URL?) {
        if url != nil {
            follows = true
            SyncFolderLocation.storeFollows(true, in: model.preferences)
        }
        model.syncFolder = url
        folder = url
        refresh()
        offerCompareIfDiverged()
    }

    private func offerCompareIfDiverged() {
        guard follows, model.sync.status == .changedOnBoth else { return }
        compare(keepingFolder: true)
    }

    private func refresh() {
        refusal = folder.flatMap(model.syncFolderRefusal)
    }

    private func compare() { compare(keepingFolder: false) }

    private func compare(keepingFolder: Bool) {
        guard let folder else { return }
        refresh()
        guard refusal == nil else { return }
        let comparison = model.compareSync(with: folder)
        let request = SyncCompareRequest(
            folder: folder,
            folderName: FileManager.default.displayName(
                atPath: folder.path
            ),
            folderLocation: SyncFolderDisplay.path(
                folder.deletingLastPathComponent()
            ),
            thisMacLocation: SyncFolderDisplay.path(
                model.configURL.deletingLastPathComponent()
            ),
            comparison: comparison,
            unsaved: model.isDirty,
            saveBlocked: model.isDirty ? model.syncSaveBlockedReason : nil,
            keepsFolderByDefault: keepingFolder
        )
        if comparison.folder.isEmpty {
            firstCopy = request
        } else {
            self.request = request
        }
    }

    /// The alert's binding is still set while its action runs, so a
    /// failure is raised on the next turn or the alert drops it.
    private func copyFirst(_ copy: SyncCompareRequest) {
        let failed = model.keepThisMacsSetup(in: copy.folder)
        refresh()
        DispatchQueue.main.async { failure = failed }
    }

    private func showFailure() {
        failure = pendingFailure
        pendingFailure = nil
    }

    private func keepThisMac(_ request: SyncCompareRequest) {
        self.request = nil
        pendingFailure = model.keepThisMacsSetup(in: request.folder)
        refresh()
    }

    private func keepFolder(_ request: SyncCompareRequest) {
        self.request = nil
        pendingFailure = model.keepFoldersSetup(from: request.folder)
        refresh()
    }
}
