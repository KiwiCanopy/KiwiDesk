import Foundation
import Testing

@testable import KiwiDeskCore

/// The gallery's `kiwidesk://look/<id>` link (#1740): which URLs are
/// one, where its file is fetched, and how a fetch answers.
@Suite("Look link")
struct LookLinkTests {
    @Test("a gallery link names its id and the release asset")
    func parses() throws {
        let url = try #require(URL(string: "kiwidesk://look/purple-neon"))
        let link = try #require(LookLink(url))
        #expect(link.id == "purple-neon")
        #expect(
            link.download.absoluteString
                == "https://github.com/KiwiCanopy/KiwiDesk-Looks"
                + "/releases/download/looks/purple-neon.json"
        )
    }

    @Test(
        "anything else is no link of ours",
        arguments: [
            "https://kiwidesk.kiwicanopy.com/looks/purple-neon",
            "kiwidesk://profile/purple-neon",
            "kiwidesk://look/",
            "kiwidesk://look/a/b",
            "kiwidesk://look/Purple",
            "kiwidesk://look/..",
            "kiwidesk://look/a%2Fb",
        ]
    )
    func refuses(_ text: String) throws {
        let url = try #require(URL(string: text))
        #expect(LookLink(url) == nil)
    }

    private func answer(
        _ status: Int,
        _ data: Data = Data("{}".utf8)
    ) -> (URLRequest) async throws -> (Data, URLResponse) {
        { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: nil
            )!
            return (data, response)
        }
    }

    private var link: LookLink {
        LookLink(URL(string: "kiwidesk://look/dusk")!)!
    }

    @Test("a 200 hands the file back, fetched from the asset")
    func fetchesTheAsset() async throws {
        var asked: URL?
        let data = try await link.fetch { request in
            asked = request.url
            return try await answer(200)(request)
        }
        #expect(data == Data("{}".utf8))
        #expect(asked == link.download)
    }

    @Test("a 404 is a look the gallery no longer has")
    func missing() async {
        await #expect(throws: LookLink.Failure.missing) {
            try await link.fetch(using: answer(404))
        }
    }

    @Test("another status or an oversized body is no look file")
    func invalid() async {
        await #expect(throws: LookLink.Failure.invalid) {
            try await link.fetch(using: answer(500))
        }
        let big = Data(count: LookLink.byteLimit + 1)
        await #expect(throws: LookLink.Failure.invalid) {
            try await link.fetch(using: answer(200, big))
        }
    }

    @Test("no answer at all is unreachable")
    func unreachable() async {
        await #expect(throws: LookLink.Failure.unreachable) {
            try await link.fetch { _ in
                throw URLError(.notConnectedToInternet)
            }
        }
    }
}
