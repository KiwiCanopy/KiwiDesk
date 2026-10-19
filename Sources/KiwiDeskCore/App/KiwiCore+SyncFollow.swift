import Foundation

/// Following a sync folder (#2324 slice 3): the config folder stays
/// on this Mac and a watch keeps the folder in step with it. A
/// change made here is copied out; a change the folder brings is
/// copied in and enters through `adoptSyncedChange`, the one door.
/// What changed is read off content hashes (`SyncLedger`,
/// `SyncPlan`), so our own copies never echo.
extension KiwiCore {
    /// Follows `folder`, or stops following with nil. Stopping
    /// keeps this Mac's copy and touches neither side.
    public func followSyncFolder(_ folder: URL?) {
        sync.watch = nil
        sync.pending?.cancel()
        sync.pending = nil
        sync.folder = folder
        guard let folder else {
            sync.status = .off
            return
        }
        sync.watch = sync.makeWatch([configDirectory, folder]) {
            [weak self] in self?.scheduleSyncPass()
        }
        runSyncPass()
    }

    /// Runs a pass once both folders have been quiet a moment.
    func scheduleSyncPass() {
        sync.pending?.cancel()
        let pass = DispatchWorkItem { [weak self] in self?.runSyncPass() }
        sync.pending = pass
        DispatchQueue.main.asyncAfter(
            deadline: .now() + sync.quietDelay,
            execute: pass
        )
    }

    /// One pass: copies what one side changed to the other and
    /// records what the two now agree on. Copies nothing while a
    /// Compare and Copy runs, while either side is unreadable or
    /// newer, or while both changed the same files.
    func runSyncPass() {
        guard let folder = sync.folder, sync.paused == 0 else { return }
        if let status = syncHold(folder) {
            sync.status = status
            return
        }
        let ledgerURL = url(of: .syncLedger)
        let ledger = SyncLedger.load(from: ledgerURL, for: folder)
        let plan = SyncPlan.plan(
            here: SyncScan.hashes(in: configDirectory),
            folder: SyncScan.hashes(in: folder),
            agreed: ledger?.agreed
        )
        guard plan.diverged.isEmpty else {
            sync.status = .changedOnBoth
            return
        }
        let copied = applySyncPlan(plan, with: folder)
        recordAgreement(with: folder, over: ledger, at: ledgerURL)
        if !plan.push.isEmpty || !plan.removeFromFolder.isEmpty {
            stampSyncFolder(folder)
        }
        sync.status =
            SyncScan.conflictCopies(in: folder).first
            .map(SyncStatus.conflictCopy) ?? .upToDate
        if !copied.isEmpty {
            adoptSyncedChange(
                SyncedChange(
                    paths: copied,
                    mac: SyncFolder.stampedMac(in: folder)
                )
            )
        }
    }

    /// Why no pass may run, as the status it shows; nil to run.
    private func syncHold(_ folder: URL) -> SyncStatus? {
        switch syncFolderRefusal(folder) {
        case .folderNewer(let newer)?: return .newerOnAnotherMac(newer)
        case _?: return .folderUnavailable
        case nil: break
        }
        if let newer = thisMacNewer() { return .newerOnAnotherMac(newer) }
        let placeholders = SyncScan.placeholders(in: folder)
        guard placeholders.isEmpty else {
            for placeholder in placeholders {
                try? FileManager.default.startDownloadingUbiquitousItem(
                    at: placeholder
                )
            }
            return .folderUnavailable
        }
        return nil
    }

    /// Carries `plan` out; answers the paths that came in.
    private func applySyncPlan(
        _ plan: SyncPlan,
        with folder: URL
    ) -> [String] {
        for path in plan.push {
            syncCopy(path, from: configDirectory, to: folder)
        }
        for path in plan.removeFromFolder {
            syncRemove(folder.appendingPathComponent(path))
        }
        var copied: [String] = []
        for path in plan.pull
        where syncCopy(path, from: folder, to: configDirectory) {
            copied.append(path)
        }
        for path in plan.removeHere
        where syncRemove(configDirectory.appendingPathComponent(path)) {
            copied.append(path)
        }
        return copied
    }

    /// Records every path the two sides now hold alike; a path a
    /// failed copy left apart keeps its earlier agreement.
    private func recordAgreement(
        with folder: URL,
        over ledger: SyncLedger?,
        at url: URL
    ) {
        let here = SyncScan.hashes(in: configDirectory)
        let there = SyncScan.hashes(in: folder)
        var agreed = ledger?.agreed ?? [:]
        for path in Set(here.keys).union(there.keys).union(agreed.keys) {
            if here[path] == there[path] { agreed[path] = here[path] }
        }
        let next = SyncLedger(
            folder: folder.standardizedFileURL.path,
            agreed: agreed
        )
        guard next != ledger else { return }
        do {
            try next.save(to: url)
        } catch {
            onLog("sync: could not record the agreement: \(error)")
        }
    }

    /// Copies `path` from `source` to `target` through a hidden
    /// temporary beside it, so a reader never sees half a file.
    @discardableResult
    private func syncCopy(_ path: String, from source: URL, to target: URL)
        -> Bool
    {
        let files = FileManager.default
        let into = target.appendingPathComponent(path)
        let temporary = into.deletingLastPathComponent()
            .appendingPathComponent(Self.incomingPrefix + UUID().uuidString)
        do {
            try files.createDirectory(
                at: into.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try files.copyItem(
                at: source.appendingPathComponent(path),
                to: temporary
            )
            if files.fileExists(atPath: into.path) {
                _ = try files.replaceItemAt(into, withItemAt: temporary)
            } else {
                try files.moveItem(at: temporary, to: into)
            }
            return true
        } catch {
            try? files.removeItem(at: temporary)
            onLog("sync: could not copy \(path): \(error)")
            return false
        }
    }

    @discardableResult
    private func syncRemove(_ url: URL) -> Bool {
        do {
            try discard(url, sync.trash)
            return true
        } catch {
            return false
        }
    }

    /// Names this Mac in the folder after copying into it.
    private func stampSyncFolder(_ folder: URL) {
        guard let mac = Self.thisMacName(),
            let data = try? JSONEncoder().encode(SyncStamp(mac: mac))
        else { return }
        try? data.write(
            to: folder.appendingPathComponent(SyncFolder.stampName),
            options: .atomic
        )
    }

    /// The one door a change from the sync folder enters by
    /// (#2324 ruling 4): the config reloads with no machine event
    /// writing a synced file — the top-ups and the shortcut drop
    /// stand down while `sync.adopting` is raised — then Settings
    /// is told what came in.
    func adoptSyncedChange(_ change: SyncedChange) {
        sync.adopting += 1
        defer { sync.adopting -= 1 }
        onLog("sync: \(change.paths.count) file(s) came in")
        loadConfig()
        sync.onSyncedIn(change)
    }

    /// Holds every pass while `body` rewrites either side, then
    /// runs one, so a Compare and Copy is never copied half-done.
    func pausingSync<T, E: Error>(
        _ body: () throws(E) -> T
    ) throws(E) -> T {
        sync.paused += 1
        defer {
            sync.paused -= 1
            if sync.paused == 0, sync.folder != nil { scheduleSyncPass() }
        }
        return try body()
    }
}
