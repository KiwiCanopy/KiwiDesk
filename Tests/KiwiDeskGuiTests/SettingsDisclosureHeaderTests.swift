import Foundation
import Testing

@testable import KiwiDesk

/// The Settings drawer header (#956): one full-row button, a
/// resting affordance, the announcement the native triangle used
/// to make, and an accessory that stays a control of its own.
///
/// **What this holds is composition, not behaviour.** Every
/// assertion is a token match over one squashed file, so a
/// modifier moved onto the wrong subview keeps the suite green
/// while the row stops being one hit target (guard-prover,
/// 2026-08-24). That is the standing limit of a source scan, and
/// the reason #956's eye-confirm on device with keyboard
/// navigation on is part of the change rather than a nicety:
/// read a green here as "the pieces are still declared", never
/// as "the row is clickable end to end".
///
/// Each half is here because losing it silently is exactly the
/// failure #956 fixed. A header that keeps the chevron and loses
/// `.contentShape` still LOOKS clickable and answers only its
/// glyph; one that keeps the button and loses
/// `.accessibilityValue` reads perfectly on screen and stops
/// telling a VoiceOver reader whether the drawer is open — the
/// `LinkedCaptionHitTests` lesson, that a custom control
/// re-earns what its native twin gave free.
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

    /// The whole GUI target, not the chrome roots.
    ///
    /// "Who builds a `DisclosureGroup`" is not the chrome
    /// question `ChromeScanRoots` answers, and borrowing its two
    /// roots left `Shortcuts`, `Updates` and the `KiwiDesk` root
    /// files silently exempt — the Onboarding lesson exactly
    /// (architect review, 2026-08-24). A native header can
    /// appear anywhere a view can.
    private static var guiRoot: URL {
        root.appendingPathComponent("Sources/KiwiDesk")
    }

    private func guiSources() throws -> [URL] {
        try SourceScan.swiftSources(under: Self.guiRoot)
    }

    private func squashed(_ repoRelative: String) throws -> String {
        let url = Self.root
            .appendingPathComponent(repoRelative)
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(!raw.isEmpty)
        return SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    /// Root coverage: the scan must read a real tree, and one
    /// wider than the chrome roots — otherwise the widening
    /// could be reverted and every clause stay green.
    @Test("the scan reads the whole GUI target")
    func theScanReadsTheWholeTarget() throws {
        let files = try guiSources()
        // DERIVED, not a round number: `Settings` alone is the
        // overwhelming majority of the target, so a flat
        // `count > 100` stayed green with the root narrowed back
        // to it (guard-prover, 2026-08-24). Comparing the two is
        // what actually says "wider than the old root".
        let settingsOnly = try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent(
                "Sources/KiwiDesk/Settings"
            )
        )
        #expect(
            files.count > settingsOnly.count,
            Comment(
                rawValue:
                    "the scan is no wider than Settings — the "
                    + "roots this question needs are the whole "
                    + "GUI target"
            )
        )
        for outside in ["/Shortcuts/", "/Updates/"] {
            #expect(
                files.contains { $0.path.contains(outside) },
                Comment(
                    rawValue:
                        "\(outside) is not scanned — a native "
                        + "disclosure header there would not be "
                        + "seen"
                )
            )
        }
    }

    @Test("every disclosure in the tree takes the house style")
    func everyDisclosureTakesTheStyle() throws {
        var found: Set<String> = []
        for url in try guiSources() {
            // Squashed, so a call broken across lines by the
            // formatter still reads as one token.
            let source = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace)
            .joined()
            let built =
                source.components(
                    separatedBy: "DisclosureGroup("
                ).count - 1
            guard built > 0 else { continue }
            let name = url.lastPathComponent
            found.insert(name)
            // Counted, never a per-file `contains`: a SECOND
            // disclosure in a file that already applies the
            // style would ship the native triangle while a
            // file-total scan stayed green — the shape gui.md
            // forbids after a guard-prover round forged it on
            // `LayoutMenuEnablementScanTests`.
            let styled =
                source.components(
                    separatedBy: ".disclosureGroupStyle("
                        + "SettingsDisclosureStyle("
                ).count - 1
            #expect(
                styled == built,
                Comment(
                    rawValue:
                        "\(name) builds \(built) "
                        + "DisclosureGroup(s) but styles "
                        + "\(styled) — an unstyled one keeps "
                        + "the native header, whose triangle is "
                        + "its only hit target (#956)"
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
        // what makes Space toggle a focused header.
        #expect(style.contains(".buttonStyle(.plain)"))
        // Without these two the row is a button whose hit area
        // is still just its glyph — the defect, wearing a
        // button's clothes.
        #expect(style.contains(".contentShape(Rectangle())"))
        #expect(style.contains("Spacer(minLength:0)"))
        #expect(
            style.contains("configuration.isExpanded.toggle()")
        )
    }

    @Test("the header carries a resting affordance")
    func headerCuesAtRest() throws {
        let style = try squashed(Self.styleFile)
        // The FULL-ROW ladder, by its named seam — not the
        // icon-chip recipe this first took. `rowHoverHighlight`
        // owns 0 → 0.06, so a retune moves every full-row
        // control together, and no resting fill paints: at row
        // width the chip's rest state is the one achromatic
        // band in a green-tinted window (#956, owner on device).
        #expect(
            style.contains(
                ".rowHoverHighlight("
            )
        )
        #expect(
            !style.contains(".hoverHighlight("),
            Comment(
                rawValue:
                    "the header is back on the icon-chip cue, "
                    + "whose 0.06 REST fill is what the owner "
                    + "saw as grey at full-row area"
            )
        )
        #expect(
            style.contains("Image(systemName:\"chevron.right\")")
        )
        // A THEME ink, not `.secondary`: hierarchical styles
        // compound under the Overrides footer's own
        // `.secondary`, so the chevron drew its cue at
        // secondary-of-secondary. That is the invariant — WHICH
        // ink it takes is a tuning, argued where it is chosen
        // (`SettingsDisclosureStyle`'s docstring) rather than
        // pinned here, so retuning it costs no test edit.
        #expect(
            style.contains(
                ".foregroundStyle(SettingsTheme."
            )
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
        // `ax_` marks these spoken-only, which is what tells a
        // translator they are value words rather than labels
        // (localization audit, 2026-08-24).
        #expect(
            style.contains(
                "L(\"settings.disclosure.ax_expanded\","
                    + "\"expanded\")"
            )
        )
        #expect(
            style.contains(
                "L(\"settings.disclosure.ax_collapsed\","
                    + "\"collapsed\")"
            )
        )
        // The chevron says the same thing in pixels; a second
        // spoken copy ("chevron.right") is noise, and hiding it
        // is what leaves the value as the one reading.
        #expect(style.contains(".accessibilityHidden(true)"))
    }
}
