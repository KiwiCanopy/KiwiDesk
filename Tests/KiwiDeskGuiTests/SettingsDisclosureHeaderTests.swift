import Foundation
import Testing

@testable import KiwiDesk

/// The Settings drawer header (#956): one full-row button, a
/// resting affordance, and the announcement the native triangle
/// used to make.
///
/// **What this holds is composition, not behaviour.** Every
/// assertion is a token match over one squashed file, so a
/// modifier moved onto the wrong subview — `.contentShape` on
/// the chevron, the value on a descendant — keeps the suite
/// green while the row stops being one hit target
/// (guard-prover, 2026-08-24). That is the standing limit of a
/// source scan, and the reason #956's eye-confirm on device
/// with keyboard navigation on is part of the change rather
/// than a nicety: read a green here as "the pieces are still
/// declared", never as "the row is clickable end to end".
///
/// Each half is here because losing it silently is exactly the
/// failure #956 fixed. A header that keeps the chevron and loses
/// `.contentShape` still LOOKS clickable and answers only its
/// glyph; one that keeps the button and loses
/// `.accessibilityValue` reads perfectly on screen and stops
/// telling a VoiceOver reader whether the drawer is open — the
/// `LinkedCaptionHitTests` lesson, that a custom control re-earns
/// what its native twin gave free.
@Suite("Settings disclosure header")
struct SettingsDisclosureHeaderTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )

    /// The files that build a `DisclosureGroup`, held EXACTLY:
    /// `SettingsDisclosure` is the wrapper every drawer goes
    /// through, and the Overrides popover's dormant drawer is
    /// the one allowed to sit outside it
    /// (`SettingsAnchorPrimitiveTests` owns that exemption and
    /// its reason). A third builder joins this list in the same
    /// change or the scan goes quiet against it.
    private static let disclosureSites: Set<String> = [
        "SettingsDisclosure.swift",
        "SpaceOverrideRows+Footer.swift",
    ]

    private static let styleFile =
        "Sources/KiwiDesk/Settings/Components/Common/"
        + "SettingsDisclosureStyle.swift"

    private func squashed(_ repoRelative: String) throws -> String {
        let url = Self.root
            .appendingPathComponent(repoRelative)
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(!raw.isEmpty)
        return SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    @Test("every disclosure in the tree takes the house style")
    func everyDisclosureTakesTheStyle() throws {
        var found: Set<String> = []
        for url in try ChromeScanRoots.sources(from: #filePath) {
            let source = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            guard source.contains("DisclosureGroup(") else {
                continue
            }
            let name = url.lastPathComponent
            found.insert(name)
            #expect(
                source.contains(
                    ".disclosureGroupStyle("
                        + "SettingsDisclosureStyle())"
                ),
                Comment(
                    rawValue:
                        "\(name) builds a DisclosureGroup that "
                        + "keeps the native header — the "
                        + "triangle is its only hit target "
                        + "(#956); apply "
                        + "SettingsDisclosureStyle()"
                )
            )
        }
        #expect(
            found == Self.disclosureSites,
            Comment(
                rawValue:
                    "the set of DisclosureGroup builders "
                    + "changed: found \(found.sorted()) — "
                    + "update `disclosureSites` in the same "
                    + "change so this scan stays proven to see "
                    + "every header"
            )
        )
    }

    @Test("the header is one full-width plain button")
    func headerIsOneFullRowButton() throws {
        let style = try squashed(Self.styleFile)
        // `.plain` is what brings it under the style guards, and
        // what makes Space and Return toggle a focused header.
        #expect(style.contains(".buttonStyle(.plain)"))
        // Without these two the row is a button whose hit area
        // is still just its glyph — the defect, wearing a
        // button's clothes.
        #expect(style.contains(".contentShape(Rectangle())"))
        #expect(style.contains("Spacer(minLength:0)"))
        #expect(style.contains("configuration.isExpanded.toggle()"))
    }

    @Test("the header carries a resting affordance")
    func headerCuesAtRest() throws {
        let style = try squashed(Self.styleFile)
        // The house ambiguous-control cue, not a bespoke fill —
        // `hoverHighlight()` owns the 0.06 → 0.12 ladder, so a
        // retune moves every ambiguous control together.
        #expect(style.contains(".hoverHighlight()"))
        #expect(
            style.contains("Image(systemName:\"chevron.right\")")
        )
        #expect(
            style.contains(".footnote.weight(.semibold)"),
            "the chevron's weight is the visible half of the cue"
        )
        #expect(
            style.contains(
                ".rotationEffect(.degrees(expanded?90:0))"
            )
        )
    }

    @Test("the button gives the disclosure state back")
    func headerAnnouncesItsState() throws {
        let style = try squashed(Self.styleFile)
        #expect(style.contains(".accessibilityValue("))
        #expect(
            style.contains(
                "L(\"settings.disclosure.expanded\",\"expanded\")"
            )
        )
        #expect(
            style.contains(
                "L(\"settings.disclosure.collapsed\","
                    + "\"collapsed\")"
            )
        )
        // The chevron says the same thing in pixels; a second
        // spoken copy ("chevron.right") is noise, and hiding it
        // is what leaves the value as the one reading.
        #expect(style.contains(".accessibilityHidden(true)"))
    }
}
