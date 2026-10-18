import Foundation

/// What a Desktop binding entry names (#2324 ruling 11): the ONE
/// reading the gate, the promotion and the Desktops card take, so
/// none of them decides "missing" or "couldn't load" beside it.
public enum BindingResolution: Equatable, Sendable {
    /// A readable profile, by its file name.
    case profile(String)
    /// A profile file that exists and will not decode.
    case unreadable(String)
    /// No profile carries the id, or the pending name names none.
    case missing
}

extension KiwiCore {
    /// The entry's profile: an id through `ProfileManager`'s index;
    /// a pending name by the file of that name, else by a profile
    /// written before ids and renamed since, which carries the
    /// name's legacy id.
    public func bindingResolution(
        of entry: DesktopBinding.Entry
    ) -> BindingResolution {
        if let id = entry.id { return resolution(of: id) }
        if profiles.list().contains(entry.name) {
            // The file of that name answers, keeper or not: a
            // duplicate that reads is a profile with no id to give.
            if let id = profiles.currentIndex().id(ofFile: entry.name) {
                return resolution(of: id)
            }
            return (try? profiles.read(name: entry.name)) == nil
                ? .unreadable(entry.name) : .profile(entry.name)
        }
        return resolution(of: .legacy(name: entry.name))
    }

    /// The id a pending entry takes once its profile exists, nil
    /// while it names none.
    func pendingID(_ name: String) -> ProfileID? {
        switch bindingResolution(of: .init(name: name)) {
        case .profile(let file), .unreadable(let file):
            profiles.currentIndex().id(ofFile: file)
        case .missing:
            nil
        }
    }

    private func resolution(of id: ProfileID) -> BindingResolution {
        let index = profiles.currentIndex()
        guard let holder = index.holder(of: id) else {
            // A file whose id cannot be read may be this one.
            return index.unparseable.first.map(BindingResolution.unreadable)
                ?? .missing
        }
        return holder.readable
            ? .profile(holder.file) : .unreadable(holder.file)
    }
}
