import AppKit
import KiwiDeskCore
import SwiftUI

/// General's last top-level row (#2324 slice 2): the sync folder,
/// remembered on this Mac, and Compare and Copy beside it. It hosts
/// the sheet, since the row outlives the menu that opens it.
struct SyncAcrossMacsRow: View {
    @ObservedObject var model: SettingsModel
    @State private var folder: URL?
    @State private var refusal: SyncRefusal?
    @State private var request: SyncCompareRequest?
    @State private var failure: SyncRefusal?
    /// A copy's failure, shown once its sheet has gone: an alert
    /// raised while the sheet closes is dropped.
    @State private var pendingFailure: SyncRefusal?

    private enum Pick: Hashable { case none, iCloud, chosen, choose }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            DropdownRow(
                label: SyncText.label,
                spokenValue: spokenValue,
                help: SyncText.help
            ) {
                picker
            } trailing: {
                Button(SyncText.compare, action: compare)
                    .settingsActionButton()
                    .disabled(folder == nil || refusal != nil)
            }
            Text(caption)
                .font(.caption)
                .foregroundStyle(
                    folder != nil && refusal != nil
                        ? SettingsTheme.warningInk : SettingsTheme.ink2
                )
                .lineLimit(2)
                .truncationMode(.middle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear {
            folder = model.syncFolder
            refresh()
        }
        .onChange(of: request == nil) { _, closed in
            guard closed, let pending = pendingFailure else { return }
            failure = pending
            pendingFailure = nil
        }
        .sheet(item: $request) { request in
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

    private var picker: some View {
        Picker(SyncText.label, selection: pickBinding) {
            Text(SyncText.none).tag(Pick.none)
            Divider()
            Text(SyncText.iCloudDrive).tag(Pick.iCloud)
                .selectionDisabled(!SyncFolderLocation.iCloudDriveIsOn)
            if let folder, !SyncFolderLocation.isICloudFolder(folder) {
                Text(folder.lastPathComponent).tag(Pick.chosen)
            }
            Divider()
            Text(SyncText.chooseFolder).tag(Pick.choose)
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
        guard let refusal else {
            return SyncText.chosenCaption(
                SyncFolderDisplay.path(folder)
            )
        }
        return SyncText.caption(for: refusal)
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

    private func store(_ url: URL?) {
        model.syncFolder = url
        folder = url
        refresh()
    }

    private func refresh() {
        refusal = folder.flatMap(model.syncFolderRefusal)
    }

    private func compare() {
        guard let folder else { return }
        refresh()
        guard refusal == nil else { return }
        let comparison = model.compareSync(with: folder)
        request = SyncCompareRequest(
            folder: folder,
            folderName: SyncFolderDisplay.path(folder),
            comparison: comparison,
            unsaved: model.isDirty,
            saveBlocked: model.isDirty ? model.syncSaveBlockedReason : nil,
            // Nothing is replaced into an empty folder, so Return
            // copies there; everywhere else it cancels (ruling 14).
            returnKeepsThisMac: comparison.folder.isEmpty
                && comparison.keepThisMacRefusal == nil
                && !(model.isDirty && model.syncSaveBlockedReason != nil)
        )
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
