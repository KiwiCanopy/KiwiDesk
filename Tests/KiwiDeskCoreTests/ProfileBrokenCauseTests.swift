import Foundation
import Testing

@testable import KiwiDeskCore

/// Why a profile file will not load, split from
/// `ProfileManagerTests` at the §2.1 ceiling. The classification
/// is what the broken-profile row's sentence rests on (#678
/// Phase 4 pass 9), so it earns its own suite rather than riding
/// along with save/load/default behaviour.
@Suite("Profile broken causes", .serialized)
@MainActor
struct ProfileBrokenCauseTests {
    /// A one-off `CodingKey` so the fixture can name a path
    /// segment: `Profile`'s own keys are `private`, and the point
    /// here is only that the path is NOT empty.
    private struct AnyKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    /// The `codingPath.isEmpty` half of the classification, which
    /// the two fixtures above do not reach at all: `{"nope": 1}`
    /// raises `.keyNotFound`, so dropping the clause entirely left
    /// the whole suite green (guard-prover, 2026-08-11). What the
    /// tests above actually pin is the decoder's CASE; this pins
    /// its PATH, which is the distinction `cause(of:)` is written
    /// on.
    ///
    /// Called directly rather than through a third file fixture:
    /// the error is the subject here, and building it by hand is
    /// what makes the non-empty coding path unambiguous instead
    /// of a property of whatever JSON happened to be written.
    @Test("A corrupt VALUE is a shape problem, not a syntax one")
    func corruptValueDeeperThanTheRootIsAShapeProblem() {
        // `read` decodes dates as ISO-8601, so a profile whose
        // `saved_at` reads "yesterday" raises exactly this: the
        // bytes ARE valid JSON, one value inside them is not
        // decodable, and the user opening the file sees nothing
        // obviously wrong — which is why it must not be reported
        // as a hand edit that broke the syntax.
        let corruptValue = DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: [AnyKey(stringValue: "saved_at")],
                debugDescription: "expected an ISO-8601 date"
            )
        )
        #expect(
            ProfileManager.cause(of: corruptValue)
                == .unexpectedShape
        )
        // The same case at the ROOT is the parser refusing the
        // bytes, which is the one a reader can see and fix.
        let refusedBytes = DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: [],
                debugDescription: "not JSON"
            )
        )
        #expect(
            ProfileManager.cause(of: refusedBytes)
                == .malformedJSON
        )
    }
}
