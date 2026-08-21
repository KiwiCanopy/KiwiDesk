import Foundation

/// Why a profile file will not load, as STRUCTURE rather than a
/// sentence (#96) — the GUI picks the words, in `ProfileBrokenText`.
///
/// The split is the one a reader can act on: it answers "is
/// opening this file going to show me anything?". A corrupt
/// shape or an unsupported schema format maps to `.unexpectedShape`.
/// What the decoder DOES know is whether the bytes are JSON at
/// all, and that is the useful half.
/// `CaseIterable` so its renderer's coverage DERIVES: the text
/// suite builds one fixture per case rather than restating three
/// by hand, and a fourth cause then reaches the distinctness
/// assertion instead of shipping a sentence identical to
/// another's, green (architect review, 2026-08-11).
public enum ProfileBrokenCause: Sendable, Equatable, CaseIterable {
    /// The bytes are not JSON. Nothing this app writes can come
    /// out this way, so a human edited it and lost a brace, a
    /// quote or a comma — visible on sight in an editor.
    case malformedJSON
    /// Valid JSON this version will not accept: a key missing, a
    /// value of the wrong type, an unknown enum spelling. Either
    /// another KiwiDesk wrote it or a hand edit changed a field
    /// rather than the syntax, and the file cannot say which.
    case unexpectedShape
    /// The file could not be read at all — deleted between the
    /// listing and the read, or unreadable to this user.
    case unreadable
}

extension ProfileManager {
    /// Profiles whose JSON won't decode, each with why — greyed
    /// out, never hidden, so a broken profile stays deletable
    /// wherever it is listed (#246, #171). A file that vanishes
    /// from the list reads as data loss.
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

    /// Classifies a `read(name:)` failure. `DecodingError`'s own
    /// cases carry the distinction: `.dataCorrupted` at the ROOT
    /// (an empty coding path) is `JSONSerialization` refusing the
    /// bytes, while the same case deeper in is one value the
    /// parser reached and rejected — which is a shape problem,
    /// not a syntax one. Testing the path rather than the case is
    /// what keeps a bad date string out of "edited by hand".
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
