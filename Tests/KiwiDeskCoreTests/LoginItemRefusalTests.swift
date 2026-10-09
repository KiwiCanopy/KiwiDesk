import Foundation
import Testing

@testable import KiwiDeskCore

/// A copy `unavailableReason` refuses is never written as a login
/// item, on or off (#2094). The bundle URL and the OS write are
/// injected, so no case here reaches `SMAppService` (#2092).
@Suite("Login-item write refuses an unstable copy (#2094)")
struct LoginItemRefusalTests {
    private static let translocated = URL(
        fileURLWithPath:
            "/private/var/folders/x/T/AppTranslocation/"
            + "ABC/d/KiwiDesk.app"
    )
    private static let bareBinary = URL(
        fileURLWithPath: "/Users/me/.build/release"
    )
    private static let installed = URL(
        fileURLWithPath: "/Applications/KiwiDesk.app"
    )

    @Test(
        "an unavailable copy is refused without a write",
        arguments: [true, false]
    )
    func unavailableCopyIsRefused(enabled: Bool) {
        let cases: [(URL, LoginItemUnavailable)] = [
            (Self.translocated, .translocated),
            (Self.bareBinary, .notBundled),
        ]
        for (url, reason) in cases {
            var writes: [Bool] = []
            let state = LoginItemManager.guardedWrite(
                enabled,
                at: url,
                write: { writes.append($0) }
            )
            #expect(writes.isEmpty, "\(url.path) was written")
            #expect(state == .unavailable(reason))
        }
    }

    @Test(
        "a registerable copy writes what was asked",
        arguments: [true, false]
    )
    func registerableCopyWrites(enabled: Bool) {
        var writes: [Bool] = []
        _ = LoginItemManager.guardedWrite(
            enabled,
            at: Self.installed,
            write: { writes.append($0) }
        )
        #expect(writes == [enabled])
    }
}
