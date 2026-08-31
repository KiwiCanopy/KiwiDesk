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
            return (name, Self.cause(of: error))
        }
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
