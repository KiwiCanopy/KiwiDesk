import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The verdict algebra `self_test` judges a read by (#1889): pure,
/// both readings handed in, so no seam is touched.
@Suite("self_test verdicts")
struct PrivatePathVerdictTests {
    @Test("a read is judged against an independent re-query")
    func verificationNeedsAgreement() {
        let own = PrivatePathContext.OwnWindow(
            id: 7,
            bounds: CGRect(x: 10, y: 20, width: 300, height: 200)
        )
        #expect(
            PrivatePathVerify.bounds(own.bounds, of: own).label
                == "works"
        )
        #expect(
            PrivatePathVerify.bounds(
                own.bounds.offsetBy(dx: 40, dy: 0),
                of: own
            ).label == "failed"
        )
        #expect(PrivatePathVerify.bounds(nil, of: own).label == "failed")
        #expect(
            PrivatePathVerify.bounds(own.bounds, of: nil).label
                == "inconclusive"
        )
        let spaces = [
            NativeSpace(id: 1, displayUUID: "A", isCurrent: true),
            NativeSpace(id: 2, displayUUID: "A", isCurrent: false),
            NativeSpace(id: 3, displayUUID: "B", isCurrent: true),
        ]
        #expect(
            PrivatePathVerify.activeSpace(1, in: spaces).label == "works"
        )
        #expect(
            PrivatePathVerify.activeSpace(9, in: spaces).label
                == "failed"
        )
        #expect(
            PrivatePathVerify.activeSpace(nil, in: spaces).label
                == "failed"
        )
        let agreeing: (String) -> UInt64? = { $0 == "A" ? 1 : 3 }
        #expect(
            PrivatePathVerify.currentSpaces(agreeing, in: spaces).label
                == "works"
        )
        #expect(
            PrivatePathVerify.currentSpaces({ _ in 2 }, in: spaces)
                .label == "failed"
        )
        #expect(PrivatePathVerify.connection(0).label == "failed")
        #expect(PrivatePathVerify.connection(42).label == "answered")
    }

    @Test("the bridge's answers are held against the C reads")
    func bridgeReadsAgreeWithC() {
        let spaces = [
            NativeSpace(id: 1, displayUUID: "A", isCurrent: true),
            NativeSpace(id: 2, displayUUID: "A", isCurrent: false),
        ]
        func plist(_ ids: [UInt64]) -> [[String: Any]] {
            [
                [
                    "Display Identifier": "A",
                    "Spaces": ids.map { ["id64": $0, "type": 0] },
                ]
            ]
        }
        #expect(
            PrivatePathVerify.bridgeSpaces(plist([1, 2]), against: spaces)
                .label == "works"
        )
        #expect(
            PrivatePathVerify.bridgeSpaces(plist([1]), against: spaces)
                .label == "failed"
        )
        #expect(
            PrivatePathVerify.bridgeSpaces(nil, against: spaces).label
                == "failed"
        )
        let own = PrivatePathContext.OwnWindow(id: 7, bounds: .zero)
        #expect(
            PrivatePathVerify.bridgeWindowSpaces(
                [4],
                against: .hosted(4),
                of: own
            ).label == "works"
        )
        #expect(
            PrivatePathVerify.bridgeWindowSpaces(
                [5],
                against: .hosted(4),
                of: own
            ).label == "failed"
        )
        #expect(
            PrivatePathVerify.hostedSpace(.unavailable, of: own).label
                == "failed"
        )
        #expect(
            PrivatePathVerify.hostedSpace(.hosted(4), of: own).label
                == "answered"
        )
    }

    @Test("the census is judged by the public window list")
    func censusNeedsTheOwnWindow() {
        let own = PrivatePathContext.OwnWindow(id: 7, bounds: .zero)
        let listed = DesktopCensus(
            hosts: [WindowID(7): .init(space: 3, pid: 1, isUp: true)],
            shown: [3]
        )
        let other = DesktopCensus(
            hosts: [WindowID(8): .init(space: 3, pid: 1, isUp: true)],
            shown: [3]
        )
        #expect(PrivatePathVerify.census(listed, of: own).label == "works")
        #expect(
            PrivatePathVerify.census(other, of: own).label
                == "inconclusive"
        )
        #expect(PrivatePathVerify.census(nil, of: own).label == "failed")
    }
}
