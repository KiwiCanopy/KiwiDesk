import Foundation

/// Failure reason classification for unreadable profile files
/// (`ProfileBrokenText`, #96).
public enum ProfileBrokenCause: Sendable, Equatable, CaseIterable {
    /// File content is not valid JSON syntax.
    case malformedJSON
    /// File contains valid JSON but does not match expected profile schema.
    case unexpectedShape
    /// File cannot be accessed or read from disk.
    case unreadable
    /// A newer KiwiDesk wrote the file (#2324 ruling 2): this
    /// build leaves it as it is, so it is never offered for
    /// deletion.
    case newerFormat
}

extension ProfileManager {
    /// Returns unreadable profiles with failure cause
    /// (`ProfileBrokenCause`, #171, #246).
    public func brokenProfiles()
        -> [(name: String, cause: ProfileBrokenCause)]
    {
        scan().compactMap { name, result in
            guard case .failure(let error) = result else {
                return nil
            }
            return (name, brokenCause(name: name, error: error))
        }
    }

    /// Why the profile `name` failed to read with `error`: a file
    /// a newer build wrote is told apart first, by the one
    /// predicate, since its decode error reads as a wrong shape.
    func brokenCause(name: String, error: Error) -> ProfileBrokenCause {
        if let url = try? fileURL(name: name),
            NewerFormatOnDisk.checkProfile(url) != nil
        {
            return .newerFormat
        }
        return Self.cause(of: error)
    }

    /// Classifies a decoding or file read error into a broken profile cause.
    static func cause(of error: Error) -> ProfileBrokenCause {
        guard let decoding = error as? DecodingError else {
            return .unreadable
        }
        if case .dataCorrupted(let context) = decoding,
            context.codingPath.isEmpty
        {
            return .malformedJSON
        }
        return .unexpectedShape
    }
}

extension ProfileManager {
    /// The profile door's guard before a write over `file`: refuses
    /// a newer build's file (#2325) and keeps a corrupt one's copy
    /// (#2324 ruling 13).
    func clearForWrite(_ file: URL) throws {
        try NewerFormatOnDisk.refuseProfile(file)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        CorruptFile.keepBeforeOverwrite(
            file,
            as: Profile.self,
            decoder: decoder,
            in: migrationBackups
        )
    }
}
