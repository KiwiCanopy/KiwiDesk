import Foundation

/// A gallery "Add to KiwiDesk" link, `kiwidesk://look/<id>` (#1740 ▸
/// Step 3 decisions): the one look it names and where its file is.
/// The id is the gallery's folder name, so anything but lower-case
/// letters, digits and hyphens is no link of ours.
public struct LookLink: Sendable, Equatable {
    /// The URL scheme `build-app.sh` registers for the app.
    public static let scheme = "kiwidesk"
    /// The gallery's repository, which Share's form lives in too.
    public static let gallery = URL(
        string: "https://github.com/KiwiCanopy/KiwiDesk-Looks"
    )!
    /// The release whose assets are the gallery's look files.
    public static let releases = gallery.appendingPathComponent(
        "releases/download/looks"
    )

    /// The gallery id.
    public let id: String

    /// The link `url` spells, or nil for any other URL.
    public init?(_ url: URL) {
        guard url.scheme?.lowercased() == Self.scheme,
            url.host?.lowercased() == "look"
        else { return nil }
        let parts = url.path.split(separator: "/")
        guard parts.count == 1, let id = parts.first.map(String.init),
            Self.isID(id)
        else { return nil }
        self.id = id
    }

    /// Where the look's file is downloaded from.
    public var download: URL {
        Self.releases.appendingPathComponent("\(id).json")
    }

    /// Why a download brought no look file.
    public enum Failure: Error, Equatable {
        /// No answer: offline, timed out, refused.
        case unreachable
        /// The gallery has no file under this id.
        case missing
        /// An answer, but no look file.
        case invalid
    }

    /// A look file is a few kilobytes; an answer past this is
    /// refused once downloaded, not cut short.
    public static let byteLimit = 512 * 1024

    /// Downloads the look's file through `fetch` — `URLSession`'s
    /// `data(for:)` in the app, a stand-in in a test.
    public func fetch(
        using fetch: (URLRequest) async throws -> (Data, URLResponse)
    ) async throws(Failure) -> Data {
        let request = URLRequest(
            url: download,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )
        let answer: (Data, URLResponse)
        do { answer = try await fetch(request) } catch {
            throw .unreachable
        }
        let status = (answer.1 as? HTTPURLResponse)?.statusCode
        if status == 404 { throw .missing }
        guard status == 200, answer.0.count <= Self.byteLimit else {
            throw .invalid
        }
        return answer.0
    }

    static func isID(_ text: String) -> Bool {
        text.count <= 64
            && text.utf8.allSatisfy {
                (0x61...0x7A).contains($0) || (0x30...0x39).contains($0)
                    || $0 == 0x2D
            }
    }
}
