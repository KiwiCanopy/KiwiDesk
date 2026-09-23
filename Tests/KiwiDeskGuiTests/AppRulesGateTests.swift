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
        #expect(gated == AppRulesGates.resolved)
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
    /// named, so one site going hand-rolled reds on its own.
    @Test("the no-Spaces sites consult the resolver")
    func noSpacesSitesConsult() throws {
        let section = try source("AppRulesSection.swift")
        let facets = try source("AppRuleRow+Facets.swift")
        for (needle, text, site) in [
            ("if !gates.hasSpaces {", section, "the Spaces pointer"),
            (".disabled(!gates.hasSpaces)", section, "the add picker"),
            ("hasSpaces: gates.hasSpaces", facets, "the pin verdict"),
        ] {
            #expect(
                text.contains(Self.squashed(needle)),
                "\(site) no longer asks `AppRulesGates`"
            )
        }
        let files = [
            "AppRulesSection.swift", "AppRulesSection+Prose.swift",
            "AppRuleRow.swift", "AppRuleRow+Facets.swift",
            "AppRuleTitledEditor.swift",
        ]
        for file in files {
            #expect(
                !(try source(file)).contains("spaces.isEmpty"),
                "\(file) re-derives the no-Spaces gate inline"
            )
        }
    }
}
