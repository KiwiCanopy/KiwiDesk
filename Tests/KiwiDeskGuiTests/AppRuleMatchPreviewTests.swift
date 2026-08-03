import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// "What this rule matches" (#678 turn 14a) must agree with the
/// engine, because a preview that disagrees is worse than no
/// preview — it is trusted.
///
/// These assert the two details a re-implementation gets wrong,
/// against `FloatRules` itself rather than against a copy of
/// what it is believed to do: title fragments match
/// case-SENSITIVELY, and bundle ids match case-INSENSITIVELY.
/// The preview calls that matcher, so a change to either rule
/// moves both sides together and these stay honest; what they
/// catch is somebody replacing the call with a `contains`.
@Suite("App rule match preview")
struct AppRuleMatchPreviewTests {
    private let app = "com.apple.finder"

    private func rules(_ patterns: [String]) -> FloatRules {
        FloatRules(patterns.map { "\(app):\($0)" })
    }

    /// The case-sensitivity that makes the preview worth having:
    /// "info" does not catch "Get Info", and a user typing the
    /// lower-case one would never learn that from the rule text.
    @Test("a title fragment matches case-sensitively")
    func titleIsCaseSensitive() {
        #expect(
            rules(["Info"]).matches(
                bundleID: app,
                title: "Downloads Info"
            )
        )
        #expect(
            !rules(["info"]).matches(
                bundleID: app,
                title: "Downloads Info"
            )
        )
    }

    /// A fragment, not a whole title — the over-matching half of
    /// the same question ("Info" also catching "Information").
    @Test("a title fragment matches anywhere in the title")
    func fragmentMatchesSubstring() {
        let net = rules(["Info"])
        #expect(net.matches(bundleID: app, title: "Information"))
        #expect(!net.matches(bundleID: app, title: "Documents"))
    }

    /// The bundle id is the other half, and it goes the other
    /// way — the picker stores a lower-cased id but a hand-typed
    /// one may not be, and the engine folds both.
    @Test("the bundle id matches case-insensitively")
    func bundleIDIsCaseInsensitive() {
        #expect(
            FloatRules(["com.apple.Finder:Info"]).matches(
                bundleID: "com.apple.finder",
                title: "Get Info"
            )
        )
    }

    /// An app-only rule floats every window, which is what the
    /// preview must show for the "floats" facet rather than
    /// falling through to per-title reasoning.
    @Test("an app-only rule floats every window")
    func appOnlyRuleFloatsAll() {
        let net = FloatRules([app])
        #expect(net.matches(bundleID: app, title: "anything"))
        #expect(net.matches(bundleID: app, title: ""))
    }

    /// Another app's windows are never this rule's business.
    @Test("a rule never reaches another app's windows")
    func otherAppsUnaffected() {
        #expect(
            !rules(["Info"]).matches(
                bundleID: "com.apple.safari",
                title: "Get Info"
            )
        )
    }

    /// The preview calls the engine rather than re-deriving it.
    /// A source scan, because the agreement is the whole point
    /// and the assertions above would keep passing over a
    /// hand-rolled `contains` that happened to agree on these
    /// five inputs.
    @Test("the preview asks the engine for its verdict")
    func previewCallsTheEngine() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Components/"
                            + "AppRules/AppRuleMatchPreview.swift"
                    ),
                encoding: .utf8
            )
        )
        #expect(source.contains("FloatRules(staged)"))
        #expect(source.contains(".matches(bundleID:"))
        #expect(
            !source.contains("title.contains("),
            Comment(
                rawValue:
                    "the preview is re-deriving the match instead "
                    + "of asking FloatRules — the two will stop "
                    + "agreeing and the preview is the one that "
                    + "gets believed"
            )
        )
    }
}
