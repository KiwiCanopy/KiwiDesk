import Foundation

/// The newer-format latch (#2324 ruling 2): a store whose file a
/// newer KiwiDesk wrote is read-only on this build. Each write door
/// already refuses such a file (#2325); this is the reading the
/// GUI asks UP FRONT, so Settings greys its Save rather than failing
/// after a Save wrote other files, and Config Issues says why.
extension KiwiCore {
    /// The file that latches a Settings Save, if any: the refusal
    /// `GuiConfigStore.save`, which every structured Save ends in,
    /// owes. Read at the Save itself, not only per refresh.
    public func guiConfigWriteLatch() -> NewerFormatOnDisk? {
        guiConfigStore.newerFormat()
    }

    /// Whether a newer build wrote the live profile's file, read
    /// at the moment asked, as the Save latch is (#2490).
    func liveProfileIsNewer() -> Bool {
        profiles.currentName.flatMap(profiles.newerFormat(name:)) != nil
    }

    /// Whether `gui.json` itself is newer, which its unreadable
    /// issue stands down for: the newer-format one says it.
    var guiConfigIsNewer: Bool {
        guiConfigStore.sidecarNewerFormat() != nil
    }

    /// The stores beside the profiles, each asked through its own
    /// pairing of file and format, in `ConfigArtifact` order.
    func storeNewerFormats() -> [NewerFormatOnDisk] {
        let store = guiConfigStore
        return [
            store.sidecarNewerFormat(),
            paletteLibrary.newerFormat(),
            lookLibrary.newerFormat(),
            store.machine.newerFormat(),
            store.bindingsFile.newerFormat(),
        ].compactMap { $0 }
    }

    /// One issue per newer store file; a profile's rides its
    /// `profileBroken(.newerFormat)`.
    func newerFormatIssues() -> [ConfigIssue] {
        storeNewerFormats().map {
            ConfigIssue(source: $0.fileName, kind: .newerFormat($0.artifact))
        }
    }
}
