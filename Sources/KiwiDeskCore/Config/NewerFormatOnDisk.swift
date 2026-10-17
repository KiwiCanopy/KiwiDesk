import Foundation

/// A store's refusal to write over a file a newer KiwiDesk wrote
/// (#2325): this build cannot decode it, so a write would replace
/// a setup it never read — on a synced config folder, another
/// Mac's. Thrown by the one write door of each store whose
/// decoder refuses a newer format.
public struct NewerFormatOnDisk: Error, Equatable,
    CustomStringConvertible
{
    /// The refused file's name, e.g. `gui.json`.
    public let file: String
    /// The format the file on disk carries.
    public let format: Int

    public var description: String {
        "\(file) was written by a newer KiwiDesk (format "
            + "\(format)); not overwriting it"
    }

    /// Throws the refusal `check` finds; a write door's one line.
    static func refuse(_ url: URL, _ knows: Int) throws {
        if let refusal = check(url, knows: knows) { throw refusal }
    }

    /// `refuse` for a profile file at `url`.
    static func refuseProfile(_ url: URL) throws {
        try refuse(url, Profile.currentFormat)
    }

    /// The refusal owed before writing `url`, or nil where the
    /// file is absent, unreadable or carries a format this build
    /// `knows`. Only a readable integer above `knows` refuses: a
    /// corrupt file stays the decoder's to report.
    static func check(_ url: URL, knows: Int) -> NewerFormatOnDisk? {
        guard let data = try? Data(contentsOf: url),
            let format = storedFormat(of: data),
            format > knows
        else { return nil }
        return NewerFormatOnDisk(
            file: url.lastPathComponent,
            format: format
        )
    }

    /// A config file's own top-level `format`, nil where it carries
    /// none or is no JSON object.
    static func storedFormat(of data: Data) -> Int? {
        let root = try? JSONSerialization.jsonObject(with: data)
        return (root as? [String: Any])?["format"] as? Int
    }
}
