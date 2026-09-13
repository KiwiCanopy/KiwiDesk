import Foundation

/// The license texts Settings ▸ About opens, and the copyright
/// line it draws (#1407). Resolves each to the `<name>.txt`
/// `scripts/build-app.sh` ships in `Contents/Resources`, else
/// to the same file on GitHub — the dev binary carries none.
enum LicenseDocuments {
    /// The texts the bundle carries, by repository file name;
    /// the script's `for doc in` list spells the same set
    /// (`LicenseDocumentsTests`).
    enum Document: String, CaseIterable {
        case license = "LICENSE"
        case acknowledgements = "ACKNOWLEDGEMENTS"
    }

    /// `NSHumanReadableCopyright`, drawn verbatim: the packager
    /// composes it from atoms only (©, year, licensor, license
    /// title), which is what keeps it locale-free. Nil under
    /// `swift run`, which has no plist.
    static var copyright: String? {
        copyright(in: .main)
    }

    static func copyright(in bundle: Bundle) -> String? {
        bundle.object(
            forInfoDictionaryKey: "NSHumanReadableCopyright"
        ) as? String
    }

    static func url(
        for document: Document,
        in bundle: Bundle = .main
    ) -> URL {
        if let bundled = bundle.url(
            forResource: document.rawValue,
            withExtension: "txt"
        ) {
            return bundled
        }
        return URL(
            string: SupportLinks.gitHub.absoluteString
                + "/blob/main/" + document.rawValue
        )!
    }
}
