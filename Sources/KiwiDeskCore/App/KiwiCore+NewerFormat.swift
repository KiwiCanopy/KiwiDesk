import Foundation

/// The newer-format latch (#2324 ruling 2): a store whose file a
/// newer KiwiDesk wrote is read-only on this build. Each write door
/// already refuses such a file (#2325); this is the reading the
/// GUI asks UP FRONT, so Settings greys its Save rather than failing
/// after a Save wrote other files, and Config Issues says why.
extension KiwiCore {
    /// Every store file a newer build wrote, one profile per file.
    public func newerFormatFiles() -> [NewerFormatOnDisk] {
        storeNewerFormats()
            + profiles.list().compactMap {
                (try? profiles.fileURL(name: $0))
                    .flatMap(NewerFormatOnDisk.checkProfile)
            }
    }

    /// The file that latches a Settings Save, if any: one of those
    /// `GuiConfigStore.save` refuses, which every structured Save
    /// ends in.
    public func guiConfigWriteLatch() -> NewerFormatOnDisk? {
        let store = guiConfigStore
        return guiConfigNewerFormat(store)
            ?? store.machine.newerFormat()
            ?? store.bindingsFile.newerFormat()
    }

    /// Whether `gui.json` itself is newer, which its unreadable
    /// issue stands down for: the newer-format one says it.
    var guiConfigIsNewer: Bool {
        guiConfigNewerFormat(guiConfigStore) != nil
    }

    /// The stores beside the profiles, in `ConfigArtifact` order.
    func storeNewerFormats() -> [NewerFormatOnDisk] {
        let store = guiConfigStore
        return [
            guiConfigNewerFormat(store),
            NewerFormatOnDisk.check(
                paletteLibrary.url,
                .palettes,
                knows: PaletteDocument.currentFormat
            ),
            NewerFormatOnDisk.check(
                lookLibrary.url,
                .looks,
                knows: LookDocument.currentFormat
            ),
            store.machine.newerFormat(),
            store.bindingsFile.newerFormat(),
        ].compactMap { $0 }
    }

    /// One issue per newer store file; a profile's rides its
    /// `profileBroken(.newerFormat)`.
    func newerFormatIssues() -> [ConfigIssue] {
        storeNewerFormats().map {
            ConfigIssue(
                source: url(of: $0.artifact).lastPathComponent,
                kind: .newerFormat($0.artifact)
            )
        }
    }

    private func guiConfigNewerFormat(
        _ store: GuiConfigStore
    ) -> NewerFormatOnDisk? {
        NewerFormatOnDisk.check(
            store.url,
            .guiConfig,
            knows: GuiConfig.currentFormat
        )
    }
}
