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
