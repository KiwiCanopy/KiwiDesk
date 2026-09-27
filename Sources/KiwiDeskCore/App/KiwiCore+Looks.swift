import Foundation

/// The look library's Core seams (#1684): the one store owner, and
/// its share of a backup restore.
extension KiwiCore {
    /// The look library, built on demand — stateless like
    /// `paletteLibrary`, and public for the same one-owner reason.
    public var lookLibrary: LookStore {
        LookStore(directory: configDirectory)
    }

    /// Writes a bundle's looks, returning how many were refused.
    /// A bundle from before looks travelled carries none and
    /// leaves the library alone (`SetupBundle.replaces`).
    func writeIncomingLooks(
        _ bundle: SetupBundle
    ) throws(SetupBundleError) -> Int {
        guard let looks = bundle.looks, !looks.isEmpty else {
            return 0
        }
        do {
            return try lookLibrary.replaceUserLooks(with: looks)
        } catch {
            onLog("restore: looks write failed: \(error)")
            throw .couldNotWrite(name: lookLibrary.url.lastPathComponent)
        }
    }
}
