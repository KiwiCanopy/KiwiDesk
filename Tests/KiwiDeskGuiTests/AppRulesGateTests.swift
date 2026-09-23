import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The App Rules census gates resolve through ONE resolver
/// (#1022), the `ShortcutsGates` shape gui.md requires of a
/// census-rendered area — and the views ask it rather than
/// re-deriving either condition beside a control.
@Suite("App Rules gates (#1022)")
struct AppRulesGateTests {
    private func gates(
        spaces: [String] = ["1"],
        floatRules: [String] = [],
        base: [String]? = nil
    ) -> AppRulesGates {
        var config = GuiConfig()
        config.spaces = spaces.map { SpaceID($0) }
        config.floatRules = floatRules
        return AppRulesGates(config: config, baseFloatRules: base)
    }

    // MARK: - The census and the resolver agree

    /// A gate declared on an App Rules row that the resolver does
    /// not answer greys or withholds nothing, silently.
    @Test("every gated App Rules row is resolved")
    func everyGatedRowIsResolved() {
        let gated = Set(
            SettingKey.allCases.filter {
                $0.placement.area == .appRules
                    && $0.placement.gate != nil
            }
        )
        #expect(!gated.isEmpty)
        #expect(
            gated
                == AppRulesGates.resolved
                .union(AppRulesGates.resolvedElsewhere)
        )
        #expect(
            AppRulesGates.resolved
                .isDisjoint(with: AppRulesGates.resolvedElsewhere)
        )
        // The resolver has no `containerReason` arm, so a gate on
        // the card's container would grey nothing, silently.
        #expect(SettingsContainer.rulesPerApp.gate == nil)
    }

    // MARK: - The two reasons

    @Test("no Spaces is the Space facet's reason")
    func noSpaces() {
        let empty = gates(spaces: [])
        #expect(
            empty.inertReason(for: .appRules(.appRules))
                == .noSpaces
        )
        #expect(!empty.hasSpaces)
        #expect(gates().hasSpaces)
    }

    /// The draft's patterns and the override base's both count,
    /// and a bare float rule is not a pattern.
    @Test("a title pattern on either side retires the offer gate")
    func titlePatterns() {
        #expect(!gates(floatRules: ["com.apple.mail"]).titlePatternsExist)
        #expect(
            gates(floatRules: ["com.apple.mail:Drafts"])
                .titlePatternsExist
        )
        #expect(
            gates(base: ["com.apple.mail:Drafts"])
                .titlePatternsExist,
            "a pattern the base carries is one the reader sees"
        )
        #expect(
            gates().inertReason(for: .appRules(.floatRulesPattern))
                == .noTitlePatterns
        )
    }

    // MARK: - The views ask the resolver

    private static func squashed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined()
    }

    private func source(_ file: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/" + file
            )
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        #expect(text.count > 400, "\(file) read empty")
        return Self.squashed(text)
    }

    /// Gate-granular: each use site of the no-Spaces answer is
    /// named, so one site going hand-rolled reds on its own. A
    /// NEW site re-deriving the condition is review's: no spelling
    /// of "the list is empty" is one a negative needle can hold.
    @Test("the no-Spaces sites consult the resolver")
    func noSpacesSitesConsult() throws {
        let section = try source("AppRulesSection.swift")
        let facets = try source("AppRuleRow+Facets.swift")
        for (needle, text, site) in [
            ("if !gates.hasSpaces {", section, "the Spaces pointer"),
            // Contiguous with the SPACE picker's own arguments: a
            // file-wide `.disabled(!gates.hasSpaces)` stayed green
            // moved onto the float picker (guard-prover,
            // 2026-09-23). The arguments are glue holding the
            // needle to that control, not an assertion.
            (
                "role: .space, name: $newSpaceApp, "
                    + "exclude: Set(apps), onCommit: addWithSpace) "
                    + ".disabled(!gates.hasSpaces)",
                section, "the Space add picker"
            ),
            ("hasSpaces: gates.hasSpaces", facets, "the pin verdict"),
        ] {
            #expect(
                text.contains(Self.squashed(needle)),
                "\(site) no longer asks `AppRulesGates`"
            )
        }
    }
}
