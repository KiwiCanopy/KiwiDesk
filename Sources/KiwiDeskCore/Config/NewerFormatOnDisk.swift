import Foundation

/// A store's refusal to write over a file a newer KiwiDesk wrote
/// (#2325): this build cannot decode it, so a write would replace
/// a setup it never read — on a synced config folder, another
/// Mac's. Thrown by the one write door of each store whose
/// decoder refuses a newer format, and read by the latch that
/// greys Settings' Save and raises a Config Issue (#2324).
///
/// Structure, never a sentence (#96): the GUI narrates it.
public struct NewerFormatOnDisk: Error, Equatable, Sendable,
    CustomStringConvertible
{
    /// The store whose file is newer.
    public let artifact: ConfigArtifact
    /// The profile's name where `artifact` is `.profiles`.
    public let profile: String?
    /// The format the file on disk carries.
    public let format: Int

    public init(
        artifact: ConfigArtifact,
        profile: String? = nil,
        format: Int
    ) {
        self.artifact = artifact
        self.profile = profile
        self.format = format
    }

    /// English for the log and the CLI, which stay English.
    public var description: String {
        "\(fileName) was written by a newer KiwiDesk (format "
            + "\(format)); not overwriting it"
    }

    /// The one "newer than this build" predicate: the format
    /// `data` carries where it is above `knows`, else nil. Only a
    /// readable integer above `knows` counts; a corrupt file stays
    /// the decoder's to report.
    public static func newerFormat(of data: Data, knows: Int) -> Int? {
        guard let format = storedFormat(of: data), format > knows
        else { return nil }
        return format
    }

    /// Throws the refusal `check` finds; a write door's one line.
    static func refuse(
        _ url: URL,
        _ artifact: ConfigArtifact,
        _ knows: Int
    ) throws {
        if let refusal = check(url, artifact, knows: knows) {
            throw refusal
        }
    }

    /// `refuse` for a profile file at `url`.
    static func refuseProfile(_ url: URL) throws {
        if let refusal = checkProfile(url) { throw refusal }
    }

    /// The refusal owed before writing `url`, or nil where the
    /// file is absent, unreadable or carries a format this build
    /// `knows`.
    static func check(
        _ url: URL,
        _ artifact: ConfigArtifact,
        profile: String? = nil,
        knows: Int
    ) -> NewerFormatOnDisk? {
        guard let data = try? Data(contentsOf: url),
            let format = newerFormat(of: data, knows: knows)
        else { return nil }
        return NewerFormatOnDisk(
            artifact: artifact,
            profile: profile,
            format: format
        )
    }

    /// `check` for a profile file, named by its file's stem.
    static func checkProfile(_ url: URL) -> NewerFormatOnDisk? {
        check(
            url,
            .profiles,
            profile: url.deletingPathExtension().lastPathComponent,
            knows: Profile.currentFormat
        )
    }

    /// A config file's own top-level `format`, nil where it carries
    /// none or is no JSON object.
    static func storedFormat(of data: Data) -> Int? {
        let root = try? JSONSerialization.jsonObject(with: data)
        return (root as? [String: Any])?["format"] as? Int
    }
}
