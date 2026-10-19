import Foundation

/// What one sync pass copies (#2324 slice 3), decided from three
/// hash maps alone: this Mac's files, the folder's, and the
/// versions the two last agreed on (`SyncLedger`). A file only one
/// side changed is copied to the other; a file both changed is
/// DIVERGED, and a diverged pass copies nothing — Compare and Copy
/// settles it.
struct SyncPlan: Equatable, Sendable {
    /// Paths copied from this Mac into the folder.
    var push: [String] = []
    /// Paths copied from the folder onto this Mac.
    var pull: [String] = []
    /// Paths this Mac deleted, removed from the folder.
    var removeFromFolder: [String] = []
    /// Paths the folder dropped, removed from this Mac.
    var removeHere: [String] = []
    /// Paths both sides changed since they last agreed.
    var diverged: [String] = []

    var copiesNothing: Bool {
        push.isEmpty && pull.isEmpty && removeFromFolder.isEmpty
            && removeHere.isEmpty
    }

    /// The pass for `here` and `folder` (path → hash) against
    /// `agreed`. With no ledger the sides must already match, or
    /// the folder be empty, which takes this Mac's setup; anything
    /// else is diverged, since nothing says which side is newer.
    static func plan(
        here: [String: String],
        folder: [String: String],
        agreed: [String: String]?
    ) -> SyncPlan {
        var plan = SyncPlan()
        let paths = Set(here.keys).union(folder.keys).sorted()
        guard let agreed else {
            if here == folder { return plan }
            if folder.isEmpty {
                plan.push = here.keys.sorted()
            } else {
                plan.diverged = paths.filter { here[$0] != folder[$0] }
            }
            return plan
        }
        for path in paths {
            let mine = here[path]
            let theirs = folder[path]
            let base = agreed[path]
            if mine == theirs { continue }
            if theirs == base {
                if mine == nil {
                    plan.removeFromFolder.append(path)
                } else {
                    plan.push.append(path)
                }
            } else if mine == base {
                if theirs == nil {
                    plan.removeHere.append(path)
                } else {
                    plan.pull.append(path)
                }
            } else {
                plan.diverged.append(path)
            }
        }
        guard plan.diverged.isEmpty else {
            return SyncPlan(diverged: plan.diverged)
        }
        return plan
    }
}

/// The synced files a folder holds, read by name (#2324 slice 3).
/// A name the setup does not list — a sync app's conflict copy,
/// an iCloud placeholder, a temporary file — is never copied; a
/// conflict copy is reported, a placeholder holds the pass.
enum SyncScan {
    /// Path → SHA-256 of every synced file under `root`; nil where
    /// one is listed and cannot be read now — not downloaded yet,
    /// or refused — since a file read as absent would be deleted
    /// on the other side.
    static func hashes(in root: URL) -> [String: String]? {
        var result: [String: String] = [:]
        for path in syncedPaths(in: root) {
            let url = root.appendingPathComponent(path)
            guard !isDataless(url), let data = try? Data(contentsOf: url)
            else { return nil }
            result[path] = SyncLedger.hash(data)
        }
        return result
    }

    /// Whether the file's bytes live only in the cloud: a read
    /// would block on the download (iCloud Drive, a File Provider).
    static func isDataless(_ url: URL) -> Bool {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { return false }
        return info.st_flags & datalessFlag != 0
    }

    /// `SF_DATALESS`, which Swift does not import.
    private static let datalessFlag: UInt32 = 0x4000_0000

    /// The synced paths under `root`: the setup's files, and each
    /// profile file in its folder.
    static func syncedPaths(in root: URL) -> [String] {
        let profiles = SyncFolder.name(of: .profiles)
        var paths: [String] = []
        for name in SyncFolder.setupNames where name != profiles {
            if isFile(root.appendingPathComponent(name)) {
                paths.append(name)
            }
        }
        let folder = root.appendingPathComponent(profiles)
        for file in names(in: folder)
        where file.hasSuffix(".json") && !isIgnored(file)
            && !isProfileConflictCopy(file, in: folder)
        {
            paths.append(profiles + "/" + file)
        }
        return paths.sorted()
    }

    /// The conflict copies a sync app left beside the setup.
    static func conflictCopies(in root: URL) -> [String] {
        let profiles = SyncFolder.name(of: .profiles)
        let top = names(in: root).filter { file in
            SyncFolder.setupNames.contains { isConflictCopy(file, of: $0) }
        }
        let folder = root.appendingPathComponent(profiles)
        let nested = names(in: folder)
            .filter { isProfileConflictCopy($0, in: folder) }
            .map { profiles + "/" + $0 }
        return (top + nested).sorted()
    }

    /// The synced files iCloud Drive holds only as placeholders
    /// (`.gui.json.icloud`), not yet downloaded.
    static func placeholders(in root: URL) -> [URL] {
        let profiles = SyncFolder.name(of: .profiles)
        return [root, root.appendingPathComponent(profiles)].flatMap {
            folder in
            names(in: folder).filter {
                $0.hasPrefix(".") && $0.hasSuffix(".icloud")
            }.map { folder.appendingPathComponent($0) }
        }
    }

    /// A dot file, an editor's backup or a sync app's temporary.
    static func isIgnored(_ name: String) -> Bool {
        name.hasPrefix(".") || name.hasPrefix("~") || name.hasSuffix("~")
            || name.hasSuffix(".tmp")
    }

    /// Whether `file` is a conflict copy of `name` — "gui 2.json",
    /// "gui (… conflicted copy …).json", "gui.sync-conflict-….json"
    /// — or, with no name, any file that says "conflict".
    static func isConflictCopy(_ file: String, of name: String?) -> Bool {
        guard !isIgnored(file) else { return false }
        guard let name else {
            return file.range(of: "conflict", options: .caseInsensitive)
                != nil
        }
        guard file != name else { return false }
        let ext = (name as NSString).pathExtension
        let stem = (name as NSString).deletingPathExtension
        guard file.hasPrefix(stem), file.hasSuffix("." + ext) else {
            return false
        }
        let middle = file.dropFirst(stem.count).dropLast(ext.count + 1)
        if middle.range(of: "conflict", options: .caseInsensitive) != nil {
            return true
        }
        return middle.first == " " && !middle.dropFirst().isEmpty
            && middle.dropFirst().allSatisfy(\.isNumber)
    }

    /// A profile file a sync app copied: one that says "conflict",
    /// or iCloud's "Work 2.json" beside a "Work.json" carrying the
    /// same profile id — a profile really named "Work 2" has its own.
    static func isProfileConflictCopy(_ file: String, in folder: URL) -> Bool {
        if isConflictCopy(file, of: nil) { return true }
        let stem = (file as NSString).deletingPathExtension
        guard let space = stem.lastIndex(of: " "),
            !stem[stem.index(after: space)...].isEmpty,
            stem[stem.index(after: space)...].allSatisfy(\.isNumber)
        else { return false }
        let twin = String(stem[..<space]) + ".json"
        guard let id = profileID(folder.appendingPathComponent(file)) else {
            return false
        }
        return profileID(folder.appendingPathComponent(twin)) == id
    }

    private static func profileID(_ url: URL) -> String? {
        guard !isDataless(url), let data = try? Data(contentsOf: url),
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { return nil }
        return root["id"] as? String
    }

    private static func names(in folder: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: folder.path))
            ?? []
    }

    private static func isFile(_ url: URL) -> Bool {
        var directory: ObjCBool = false
        return FileManager.default.fileExists(
            atPath: url.path,
            isDirectory: &directory
        ) && !directory.boolValue
    }
}
