import Foundation
import Testing

@testable import KiwiDeskCore

/// The change report's wire spellings (#1685), which `docs/cli.md`
/// ▸ Raw IPC Protocol documents: an encoder and decoder renamed
/// together round-trip whatever the key, so the keys are read off
/// the encoded JSON.
@Suite("Change report wire")
struct ChangeReportWireTests {
    private func keys(_ value: some Encodable) throws -> Set<String> {
        let data = try JSONEncoder().encode(value)
        let object = try JSONSerialization.jsonObject(with: data)
        return Set((object as? [String: Any])?.keys.map { $0 } ?? [])
    }

    @Test("a request asks with report_changes and keep_watch")
    func requestKeys() throws {
        let request = CommandRequest.reporting("version", watch: ["/a"])
        #expect(
            try keys(request).isSuperset(of: ["report_changes", "keep_watch"])
        )
    }

    @Test("a leaf carries id, owner, stored, value and not_keepable")
    func leafKeys() throws {
        let leaf = TouchedLeaf(
            id: "/a",
            owner: .none,
            notKeepable: .unknown,
            stored: true,
            value: .number(1)
        )
        #expect(
            try keys(leaf)
                == ["id", "owner", "stored", "value", "not_keepable"]
        )
    }

    @Test("a report carries profile, touched and watched")
    func reportKeys() throws {
        let report = ChangeReport(profile: "Work")
        #expect(try keys(report) == ["profile", "touched", "watched"])
    }
}
