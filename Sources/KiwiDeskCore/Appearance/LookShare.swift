import Foundation

/// The current look as the gallery's "Submit a look" form takes it
/// (#1740 ▸ Share): the exported file prefilled as text, the credit
/// in the form's own `based_on` field, which the sharer may edit.
/// The field ids are the form's (`submit-look.yml` in
/// KiwiDesk-Looks), and its parser reads `based_on` as written here.
public struct LookShare: Sendable, Equatable {
    /// The issue form a share opens.
    public static let form = URL(
        string: "https://github.com/KiwiCanopy/KiwiDesk-Looks/issues/new"
    )!
    /// The longest form address a share opens with the file inside;
    /// past it the file is written to disk and attached by hand.
    public static let urlLimit = 7000

    /// The look as shared: the current styling and colours under
    /// the name the sharer chose, with the credit it still earns.
    public let look: ShelfLook

    public init(name: String, settings: TilingSettings) {
        look = .current(named: name, in: settings)
    }

    /// The credit the share carries, nil when none is attached.
    public var credit: LookCredit? { look.basedOn }

    /// The look file, compact and key-sorted so a share of the same
    /// look reads the same.
    public func fileData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(LookExport(look: look))
    }

    /// The form's address with the file inside, nil when it would be
    /// longer than `urlLimit`.
    public func prefilledURL(version: String) throws -> URL? {
        let file = String(decoding: try fileData(), as: UTF8.self)
        let url = formURL(version: version, file: file)
        return url.absoluteString.utf8.count > Self.urlLimit ? nil : url
    }

    /// The form's address without the file, for a share whose file
    /// is attached by hand.
    public func formURL(version: String, file: String? = nil) -> URL {
        var items = [
            URLQueryItem(name: "template", value: "submit-look.yml"),
            URLQueryItem(name: "title", value: "Look: \(look.name)"),
            URLQueryItem(name: "version", value: version),
        ]
        if let file { items.append(URLQueryItem(name: "look", value: file)) }
        if let field = basedOnField {
            items.append(URLQueryItem(name: "based_on", value: field))
        }
        var parts = URLComponents(
            url: Self.form,
            resolvingAgainstBaseURL: false
        )!
        parts.queryItems = items
        // `+` reads as a space in a form query; `&` and `=` are
        // already escaped by URLComponents.
        parts.percentEncodedQuery = parts.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        return parts.url!
    }

    /// The `based_on` field's text: the gallery id when the credit
    /// has one, else "Name by Author", else the name.
    var basedOnField: String? {
        guard let credit else { return nil }
        if let id = credit.id { return id }
        guard let name = credit.name else { return nil }
        guard let author = credit.author else { return name }
        return "\(name) by \(author)"
    }
}
