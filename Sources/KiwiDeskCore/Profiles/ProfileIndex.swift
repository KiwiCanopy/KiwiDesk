import Foundation

/// Which profile file holds each `ProfileID` (#2324 ruling 11):
/// the binding gate's lookup.
///
/// A file that will not decode still holds its id — read raw from
/// its top level — as an UNREADABLE holder, so a binding to it
/// reads "couldn't load" rather than "missing". Two files can carry
/// one id (a Finder duplicate, a restore beside a copy): the keeper
/// is the file whose stored name is its own file name, ties going
/// to the lowest file name, so every Mac picks the same file; the
/// other takes a fresh id when it is next written.
struct ProfileIndex: Equatable {
    struct Holder: Equatable {
        let file: String
        let readable: Bool
    }

    /// One profile file as the index reads it.
    struct Entry {
        let file: String
        let id: ProfileID
        let storedName: String
        let readable: Bool
    }

    private(set) var holders: [ProfileID: Holder] = [:]

    init(_ entries: [Entry]) {
        var own: [ProfileID: Bool] = [:]
        for entry in entries.sorted(by: { $0.file < $1.file }) {
            let isOwn = entry.storedName == entry.file
            if holders[entry.id] != nil, own[entry.id] == true || !isOwn {
                continue
            }
            holders[entry.id] = Holder(
                file: entry.file,
                readable: entry.readable
            )
            own[entry.id] = isOwn
        }
    }

    /// The file holding `id`, nil where none does.
    func holder(of id: ProfileID) -> Holder? { holders[id] }

    /// The id the file `name` keeps, nil where it keeps none.
    func id(ofFile name: String) -> ProfileID? {
        holders.first { $0.value.file == name }?.key
    }

    /// The write door's own write of `file` under `id`.
    mutating func recordWrite(file: String, id: ProfileID) {
        holders = holders.filter { $0.value.file != file }
        holders[id] = Holder(file: file, readable: true)
    }

    /// A file removed or moved away.
    mutating func remove(file: String) {
        holders = holders.filter { $0.value.file != file }
    }
}

extension ProfileManager {
    /// The file holding `id` through the cached index, nil where
    /// none does — a lookup that reads no profile while the folder
    /// is unchanged.
    public func profileName(withID id: ProfileID) -> String? {
        currentIndex().holder(of: id)?.file
    }

    /// `id`'s holder, readable or not.
    func holder(of id: ProfileID) -> ProfileIndex.Holder? {
        currentIndex().holder(of: id)
    }

    /// The id a write of `profile` keeps: the one the file of that
    /// name already carries, else the incoming id unless another
    /// file keeps it, in which case a fresh one (#2324).
    func idForWrite(of profile: Profile) -> ProfileID {
        let index = currentIndex()
        if let held = index.id(ofFile: profile.name) { return held }
        if let holder = index.holder(of: profile.id),
            holder.file != profile.name
        {
            return .fresh()
        }
        return profile.id
    }

    /// The index, rebuilt when the folder changed since it was
    /// built — stamped BEFORE the scan, so a change landing during
    /// it is never recorded as covered.
    func currentIndex() -> ProfileIndex {
        let stamp = folderStamp()
        if let cached = idIndex, cached.stamp == stamp {
            return cached.index
        }
        let built = ProfileIndex(
            scan().compactMap { name, result in
                switch result {
                case .success(let profile):
                    return ProfileIndex.Entry(
                        file: name,
                        id: profile.id,
                        storedName: profile.name,
                        readable: true
                    )
                case .failure:
                    return rawEntry(file: name)
                }
            }
        )
        idIndex = (stamp, built)
        return built
    }

    /// An undecodable file's id, read raw; a file written before
    /// ids takes its name's legacy id, as the migration would.
    private func rawEntry(file: String) -> ProfileIndex.Entry? {
        guard let url = try? fileURL(name: file),
            let data = try? Data(contentsOf: url),
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { return nil }
        let stored = root["name"] as? String ?? file
        let id =
            (root["id"] as? String).map(ProfileID.init(raw:))
            ?? .legacy(name: stored)
        return ProfileIndex.Entry(
            file: file,
            id: id,
            storedName: stored,
            readable: false
        )
    }

    /// Applies this manager's own change to a fresh index in place,
    /// re-stamped, so the next lookup reads nothing; an index that
    /// was already stale is dropped instead.
    func updateIndex(
        stampBefore: Date?,
        _ change: (inout ProfileIndex) -> Void
    ) {
        guard var cached = idIndex, cached.stamp == stampBefore else {
            idIndex = nil
            return
        }
        change(&cached.index)
        cached.stamp = folderStamp()
        idIndex = cached
    }

    func folderStamp() -> Date? {
        (try? FileManager.default.attributesOfItem(
            atPath: directory.path
        ))?[.modificationDate] as? Date
    }
}
