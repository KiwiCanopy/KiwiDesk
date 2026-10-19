import AppKit
import KiwiDeskCore
import SwiftUI

/// General's last top-level row (#2324 slice 2): the sync folder,
/// remembered on this Mac, and Compare and Copy beside it. It hosts
/// the sheet, since the row outlives the menu that opens it.
struct SyncAcrossMacsRow: View {
    @ObservedObject var model: SettingsModel
    @State private var folder = SyncFolderPreference.stored
    @State private var refusal: SyncRefusal?
    @State private var request: SyncCompareRequest?
    @State private var failure: SyncRefusal?

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
        .onAppear(perform: refresh)
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
                .selectionDisabled(!SyncFolderPreference.iCloudDriveIsOn)
            if let folder, !SyncFolderPreference.isICloudFolder(folder) {
                Text(folder.lastPathComponent).tag(Pick.chosen)
            }
            Divider()
            Text(SyncText.chooseFolder).tag(Pick.choose)
        }
    }

    private var pick: Pick {
        guard let folder else { return .none }
        return SyncFolderPreference.isICloudFolder(folder)
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
                SyncFolderPreference.displayPath(folder)
            )
        }
        if refusal == .folderUnavailable,
            SyncFolderPreference.isICloudFolder(folder),
            !SyncFolderPreference.iCloudDriveIsOn
        {
            return SyncText.iCloudOff
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
            let url = SyncFolderPreference.iCloudFolder
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
        SyncFolderPreference.stored = url
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
        request = SyncCompareRequest(
            folder: folder,
            folderName: SyncFolderPreference.displayPath(folder),
            comparison: model.compareSync(with: folder),
            unsaved: model.isDirty,
            saveBlocked: model.isDirty ? model.syncSaveBlockedReason : nil
        )
    }

    /// Saves the draft first where it has edits; a Save that did
    /// not land leaves the folder alone.
    private func keepThisMac(_ request: SyncCompareRequest) {
        self.request = nil
        if request.unsaved {
            model.performPrimarySave()
            guard !model.isDirty else { return }
        }
        failure = model.keepThisMacsSetup(in: request.folder)
        refresh()
    }

    private func keepFolder(_ request: SyncCompareRequest) {
        self.request = nil
        failure = model.keepFoldersSetup(from: request.folder)
        refresh()
    }
}
