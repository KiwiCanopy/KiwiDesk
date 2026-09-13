import Foundation

/// The license texts Settings ▸ About opens (#1407).
///
/// `scripts/build-app.sh` copies the repository's `LICENSE` and
/// `ACKNOWLEDGEMENTS` into `Contents/Resources` as `.txt`, and
/// derives `NSHumanReadableCopyright` from the former. The dev
/// binary under `.build/` has neither a plist nor those copies,
/// so each document falls back to its file on GitHub and the
/// copyright line to nil.
enum LicenseDocuments {
    static var license: URL {
        document("LICENSE", in: .main)
    }

    static var acknowledgements: URL {
        document("ACKNOWLEDGEMENTS", in: .main)
    }

    /// The packager's copyright line; nil under `swift run`.
    static var copyright: String? {
        copyright(in: .main)
    }

    static func copyright(in bundle: Bundle) -> String? {
        bundle.object(
            forInfoDictionaryKey: "NSHumanReadableCopyright"
        ) as? String
    }

    /// The bundled `<name>.txt`, else that file on GitHub.
    static func document(_ name: String, in bundle: Bundle) -> URL {
        if let bundled = bundle.url(
            forResource: name,
            withExtension: "txt"
        ) {
            return bundled
        }
        return URL(
            string: SupportLinks.gitHub.absoluteString
                + "/blob/main/" + name
        )!
    }
}
