import Foundation

extension ServiceManager {
    /// Deletes the LaunchAgent plist at `url` (#3538). A missing
    /// file is success. Returns an error message on failure, `nil`
    /// on success.
    static func removeAgent(at url: URL) -> String? {
        let files = FileManager.default
        guard files.fileExists(atPath: url.path) else { return nil }
        do {
            try files.removeItem(at: url)
            return nil
        } catch {
            return "failed to remove LaunchAgent: \(error)"
        }
    }
}
