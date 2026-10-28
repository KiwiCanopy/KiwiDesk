import Foundation

/// The look another one started from (#1740): its name, its author
/// and, for a gallery look, the gallery id. A credit to a look its
/// author removed with "Also remove my name" is `removed` alone.
public struct LookCredit: Sendable, Equatable, Codable {
    public var name: String?
    public var author: String?
    /// The gallery's folder id, set when the original came from it.
    public var id: String?
    public var removed: Bool?

    public init(
        name: String? = nil,
        author: String? = nil,
        id: String? = nil,
        removed: Bool? = nil
    ) {
        self.name = name
        self.author = author
        self.id = id
        self.removed = removed
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case author
        case id
        case removed
    }
}
