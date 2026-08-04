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

    /// The PREVIEW's own verdict, asserted against the engine's
    /// over the inputs where a re-derivation diverges. The scan
    /// below is one spelling deep — guard-prover slipped a
    /// plausible "fast path while typing" past it, which
    /// disagreed with the engine on exactly the pending pattern
    /// the user is watching — so the agreement is asserted as
    /// arithmetic and the scan kept only for a preview that
    /// never called the engine at all.
    @MainActor
    @Test("the preview's verdict is the engine's")
    func previewVerdictMatchesEngine() {
        let model = makeTestModel()
        model.config.floatRules = ["\(app):Info"]
        let preview = AppRuleMatchPreview(model: model, app: app)
        for title in [
            "Get Info", "Information", "Documents", "info",
        ] {
            let window = AppRuleMatchPreview.PreviewWindow(
                title: title,
                isFloating: false
            )
            let engine = FloatRules(model.config.floatRules)
                .matches(bundleID: app, title: title)
            #expect(
                (preview.verdict(for: window) == .floatsByRule)
                    == engine,
                Comment(rawValue: "diverged on \(title)")
            )
        }
        // A window the ENGINE floats with no rule — a dialog, a
        // panel — reads as floating for its own reason, never as
        // tiling. Saying "tiles" there is the defect this view
        // shipped in its first cut, and it contradicted the user
        // guide on the same screen.
        let dialog = AppRuleMatchPreview.PreviewWindow(
            title: "Documents",
            isFloating: true
        )
        #expect(preview.verdict(for: dialog) == .floatsAnyway)
        // And with a pattern still being typed — the branch the
        // scan could not defend, and the one the reader trusts
        // most because it answers as they type.
        let typing = AppRuleMatchPreview(
            model: model,
            app: app,
            pending: "Down"
        )
        func typed(
            _ title: String
        ) -> AppRuleMatchPreview.Verdict {
            typing.verdict(
                for: .init(title: title, isFloating: false)
            )
        }
        #expect(typed("Downloads") == .floatsByRule)
        #expect(typed("down") == .tiles)
        #expect(typed("Documents") == .tiles)
    }

    /// The preview calls the engine rather than re-deriving it.
    /// Kept beside the arithmetic above for the case arithmetic
    /// cannot see: a preview rewritten to never consult
    /// `FloatRules` at all, which would still agree on any
    /// fixture chosen to match it.
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
        // No `window.isFloating` needle: the expression occurs
        // twice in this file, so deleting the one that decides
        // the verdict left it green (guard-prover). The
        // arithmetic test above reds on exactly that, which is
        // where the coverage actually lives.
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
