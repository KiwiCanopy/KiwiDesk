import Foundation
import Testing

@testable import KiwiDeskCore

/// A rejected bar setting names the values its own decoder
/// accepts (#1033).
///
/// Both bar setters used to carry the expected list as a
/// hand-typed string, and both had gone stale identically:
/// `active_indicator` answered `expected ring|edge_mark|gap`
/// after the case was renamed `outline`, so a user following the
/// error message got the same rejection again.
@Suite("bar setting choice")
struct BarSettingChoiceTests {
    /// The message names every case, in declaration order — the
    /// SHAPE, so renaming or adding a case retunes it rather
    /// than redding this.
    private func expectedMessage<T: APIChoiceType>(
        _ type: T.Type
    ) -> String {
        "expected "
            + T.allCases.map(\.rawValue).joined(separator: "|")
    }

    @Test("the App Bar names its own indicator cases")
    func appBarIndicator() {
        let result = AppBarCommandSetting.parse(
            field: "active_indicator",
            args: [.string("nonsense")]
        )
        guard case .failure(let error) = result else {
            Issue.record("expected a rejection")
            return
        }
        #expect(
            error.message
                == expectedMessage(
                    AppBarStyle.ActiveIndicator.self
                )
        )
        // The regression itself: the retired spelling must not
        // come back as advice.
        #expect(!error.message.contains("ring"))
    }

    @Test("the Space Bar names its own indicator cases")
    func spaceBarIndicator() {
        let result = SpaceBarCommandSetting.parse(
            field: "active_indicator",
            args: [.string("nonsense")]
        )
        guard case .failure(let error) = result else {
            Issue.record("expected a rejection")
            return
        }
        #expect(
            error.message
                == expectedMessage(
                    SpaceBarStyle.ActiveIndicator.self
                )
        )
        #expect(!error.message.contains("ring"))
    }

    @Test("two fields with different enums both name their own")
    func twoFieldsCannotShareOneLiteral() {
        // The clause that catches a hardcoded message that
        // happens to be RIGHT today: `guard-prover` replaced the
        // whole derivation with a literal spelling
        // `active_indicator`'s cases, and every other assertion
        // here passed. No single literal can be correct for two
        // different enums, so asserting a second field is what
        // makes the derivation itself the only way to be green.
        let fields: [(String, String)] = [
            (
                "edge",
                expectedMessage(AppBarEdge.self)
            ),
            (
                "content",
                expectedMessage(AppBarStyle.Content.self)
            ),
            (
                "active_indicator",
                expectedMessage(AppBarStyle.ActiveIndicator.self)
            ),
        ]
        for (field, expected) in fields {
            let result = AppBarCommandSetting.parse(
                field: field,
                args: [.string("nonsense")]
            )
            guard case .failure(let error) = result else {
                Issue.record("\(field): expected a rejection")
                continue
            }
            #expect(
                error.message == expected,
                "\(field): said \"\(error.message)\""
            )
        }
    }

    @Test("a legal value still decodes")
    func legalValueDecodes() {
        let result = AppBarCommandSetting.parse(
            field: "edge",
            args: [.string("left")]
        )
        guard case .success(let setting) = result,
            case .edge(let edge) = setting
        else {
            Issue.record("expected a decoded edge")
            return
        }
        #expect(edge == .left)
    }
}
