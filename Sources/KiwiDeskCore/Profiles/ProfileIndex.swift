import Foundation

/// Which profile file holds each `ProfileID` (#2324 ruling 11):
/// the binding gate's lookup, built from what `ProfileManager`
/// reads, so no second reader of the profile shape exists.
///
/// Two files can carry one id — a Finder duplicate, a restore
/// beside a copy. The keeper is the file whose stored name is its
/// own file name, ties going to the lowest file name, so every Mac
/// picks the same file; the other stays reachable by name and
/// takes a fresh id when it is next written.
struct ProfileIndex: Equatable {
    /// File name (without `.json`) per id.
    private(set) var files: [ProfileID: String] = [:]

    init(_ entries: [(file: String, profile: Profile)]) {
        var keepers: [ProfileID: (file: String, own: Bool)] = [:]
        for (file, profile) in entries.sorted(by: { $0.file < $1.file }) {
            let own = profile.name == file
            if let held = keepers[profile.id], held.own || !own {
                continue
            }
            keepers[profile.id] = (file, own)
        }
        files = keepers.mapValues(\.file)
    }

    /// The file holding `id`, nil where none does.
    func file(of id: ProfileID) -> String? { files[id] }

    /// The id the file `name` keeps, nil where it keeps none.
    func id(ofFile name: String) -> ProfileID? {
        files.first { $0.value == name }?.key
    }
}

extension ProfileManager {
    /// The file holding `id`, through the cached index, rebuilt when
    /// the folder changed since it was built. Nil reads as "missing".
    public func profileName(withID id: ProfileID) -> String? {
        currentIndex().file(of: id)
    }

    /// The id a write of `profile` keeps: the one the file of that
    /// name already carries, else the incoming id unless another
    /// file keeps it, in which case a fresh one (#2324).
    func idForWrite(of profile: Profile) -> ProfileID {
        let index = currentIndex()
        if let held = index.id(ofFile: profile.name) { return held }
        if let holder = index.file(of: profile.id),
            holder != profile.name
        {
            return .fresh()
        }
        return profile.id
    }

    func currentIndex() -> ProfileIndex {
        let stamp = folderStamp()
        if let cached = idIndex, cached.stamp == stamp {
            return cached.index
        }
        let built = ProfileIndex(
            scan().compactMap { name, result in
                (try? result.get()).map { (name, $0) }
            }
        )
        // Reading may migrate a file, which moves the stamp.
        idIndex = (folderStamp(), built)
        return built
    }

    /// Forgets the index after this manager's own write.
    func invalidateIndex() { idIndex = nil }

    private func folderStamp() -> Date? {
        (try? FileManager.default.attributesOfItem(
            atPath: directory.path
        ))?[.modificationDate] as? Date
    }
}
