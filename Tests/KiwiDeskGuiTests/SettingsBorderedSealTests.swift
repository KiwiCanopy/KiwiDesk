import Foundation
import Testing

@testable import KiwiDesk

/// The bordered half of the label-neutrality obligation, sealed.
///
/// `.buttonStyle(.bordered)` paints its label from the tint, so
/// with the window tinted kiwi every bordered button rendered
/// green text (#759). The first fix paired the style with
/// `.neutralButtonLabel()` at every call site, which left the
/// two as independent decisions a site can get half right — and
/// left the guard counting three hand-kept registers to prove
/// nobody had. Since #771 an action button styles itself through
/// `settingsActionButton()`, which applies both in one call, so
/// what is guarded here are the seams of that seal:
///
/// - no raw `.buttonStyle(.bordered)` outside the declared
///   exemptions,
/// - the seal's own body still pairs style and neutralisation,
/// - every exemption is still standing on its stated grounds.
///
/// Split from `SettingsLabelNeutralityTests` (the menu half and
/// the direct-use enumeration) at the 350-line ceiling.
///
/// A `role: .destructive` button routed THROUGH the seal keeps
/// its red on the Settings ground: the chip face reads the role
/// and draws the label in `SettingsTheme.danger` (#3630), pinned
/// by `deleteTwinsRouteThroughSeal`. KiwiHub's Fill draws its own
/// hierarchy instead, and no destructive chip sits there.
@Suite("Settings bordered seal")
struct SettingsBorderedSealTests {
    /// The trees this guard covers — `ChromeScanRoots`, whose
    /// own suite proves every root is read.
    private func scannedSources() throws -> [URL] {
        try ChromeScanRoots.sources(from: #filePath)
    }

    /// The seal's own file, where the one legitimate
    /// `buttonStyle(.bordered)` lives — written dot-free there
    /// so no call-site needle counts it, and pinned by
    /// `sealPairsStyleAndNeutralisation` instead.
    private static let sealFile = "SettingsActionButton.swift"

    /// Files allowed to carry a raw `.buttonStyle(.bordered)` —
    /// that is, WITHOUT going through `settingsActionButton()` —
    /// and how many each may carry.
    ///
    /// **This map is the one copy of who may.** Three fields, and
    /// the middle one is what makes it more than a licence:
    ///
    /// - `count` — how many, so a file with one legitimate
    ///   exemption cannot quietly grow a second;
    /// - `needle` — the source token that IS the reason, which
    ///   must still appear at least `count` times. Without it the
    ///   guard pins only that the file still has *some* bordered
    ///   button, so swapping a destructive button for a plain one
    ///   keeps it green while an accent label ships;
    /// - `why` — for the reader.
    ///
    /// **One place this map cannot reach**, stated so the two
    /// guards have a precedence rather than a contradiction: on
    /// the fixed-dark chrome families `SettingsFixedGroundTests`
    /// bans `.bordered` and its seal ABSOLUTELY, because there
    /// the objection is not the accent label but that
    /// `SettingsTheme.ink` moves with the appearance while the
    /// ground does not (#1198). An entry added here for such a
    /// file grants nothing and stays red; the escape is an ink
    /// that is fixed, never an exemption.
    private let borderedExempt:
        [String: (count: Int, needle: String, why: String)] = [
            "SpacesSection+Overrides.swift": (
                1, "role: .destructive",
                "a raw destructive reset not yet moved onto the "
                    + "seal, as #3630 moved the delete twins"
            ),
            "SpaceOverrideRows+Footer.swift": (
                1, "role: .destructive",
                "reset-all, the same straggler"
            ),
            "KeyRecorderField.swift": (
                1, ".tint(buttonTint)",
                "resolves its own tint per state: red on a "
                    + "rejected chord, ink otherwise. The recording "
                    + "signal is the chrome's own accent fill, "
                    + "which never reads the tint"
            ),
            "HyperKeyField.swift": (
                1, ".tint(buttonTint)",
                "the Hyper key's recorder (#1870), the key "
                    + "recorder's own field and tint"
            ),
        ]

    /// A raw bordered style appears only where an exemption
    /// says it may.
    ///
    /// Since #771 an action button takes `.bordered` through
    /// `settingsActionButton()`, which cannot skip the
    /// neutralisation — so any raw `.buttonStyle(.bordered)` at
    /// a call site is either one of the declared exemptions
    /// (a destructive red, the recorder's own tint) or the
    /// regression the seal exists to end.
    @Test("a raw bordered style appears only where exempt")
    func rawBorderedStylesAreExempt() throws {
        var rawFound = 0
        var sealedFound = 0
        for file in try scannedSources() {
            let name = file.lastPathComponent
            guard name != Self.sealFile else { continue }
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            // Deliberately dot-free: the substring matches BOTH
            // spellings, so a convenience wrapper written
            // first-in-chain inside a View extension — the shape
            // the seal itself takes — cannot escape the count by
            // its spelling. `.borderedProminent` never matches:
            // the needle's closing paren excludes it.
            let styled = source.occurrences(
                of: "buttonStyle(.bordered)"
            )
            let sealed = source.occurrences(
                of: ".settingsActionButton()"
            )
            rawFound += styled
            sealedFound += sealed
            let exempt = borderedExempt[name]?.count ?? 0
            #expect(
                styled == exempt,
                Comment(
                    rawValue:
                        "\(name) has \(styled) raw "
                        + "`.buttonStyle(.bordered)` but "
                        + "\(exempt) exemption(s) — an action "
                        + "button styles itself through "
                        + "`settingsActionButton()`, which pairs "
                        + "the neutralisation by construction."
                )
            )
        }
        // A scan finding neither the exemptions nor any sealed
        // call site has looked at nothing (#635) — and a tree
        // with zero sealed buttons means the seal lost its
        // consumers, which this suite exists to notice.
        #expect(rawFound > 0)
        #expect(sealedFound > 0)
    }

    /// The seal itself still pairs the style with the
    /// neutralisation.
    ///
    /// `settingsActionButton()` writes its `buttonStyle` link
    /// dot-free so no call-site needle counts it; the cost of
    /// that invisibility is that nothing else watches the seal's
    /// body, so this does — the style exactly once, and the
    /// neutralisation directly beneath it.
    @Test("the seal pairs style and neutralisation")
    func sealPairsStyleAndNeutralisation() throws {
        let sources = try scannedSources()
        // Exactly one: `rawBorderedStylesAreExempt` skips the
        // seal by NAME, so a second file with this name anywhere
        // under Settings/ would inherit the skip unwatched.
        let matches = sources.filter {
            $0.lastPathComponent == Self.sealFile
        }
        #expect(matches.count == 1)
        let file = try #require(
            matches.first,
            Comment(rawValue: "no such file: \(Self.sealFile)")
        )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        // Since #2377 the seal's style is the button-chip face.
        #expect(
            source.occurrences(of: "buttonStyle(ButtonChipStyle())") == 1,
            "the seal applies the button-chip style exactly once"
        )
        #expect(
            SourceScan.adjacentPairs(
                in: source,
                line: "buttonStyle(ButtonChipStyle())",
                followedBy: ".neutralButtonLabel()"
            ) == 1,
            Comment(
                rawValue:
                    "the seal's `.neutralButtonLabel()` must sit "
                    + "directly beneath its `buttonStyle"
                    + "(ButtonChipStyle())` — a seal that styles "
                    + "without neutralising re-opens #759 at every "
                    + "call site at once."
            )
        )
    }

    /// An exemption for a file with no bordered button at all is
    /// a licence nothing needs — and it would silently absorb
    /// the first one added there.
    ///
    /// Checks the REASON too, not just the count: an exemption
    /// whose grounds have gone is the same licence, and it fails
    /// in the direction that ships an accent label.
    @Test("every bordered-button exemption is still used")
    func borderedExemptionsAreLive() throws {
        let sources = try scannedSources()
        for (name, entry) in borderedExempt {
            let file = try #require(
                sources.first { $0.lastPathComponent == name },
                Comment(rawValue: "no such file: \(name)")
            )
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            #expect(
                source.occurrences(of: entry.needle)
                    >= entry.count,
                Comment(
                    rawValue:
                        "\(name) is exempted for \(entry.count) "
                        + "bordered button(s) on the grounds "
                        + "`\(entry.needle)` (\(entry.why)), but "
                        + "that no longer appears \(entry.count) "
                        + "time(s) — the reason is gone, so the "
                        + "exemption goes with it."
                )
            )
            // Dot-free like `rawBorderedStylesAreExempt`'s
            // needle — one concept, one spelling rule.
            #expect(
                source.occurrences(of: "buttonStyle(.bordered)")
                    >= entry.count,
                Comment(
                    rawValue:
                        "\(name) is exempted for "
                        + "\(entry.count) bordered button(s) "
                        + "(\(entry.why)) but no longer has that "
                        + "many — drop the entry."
                )
            )
        }
    }

    /// The two delete twins are action chips like Rename… beside
    /// them, the role alone drawing the label red, and the face
    /// still reads the role (#3630).
    @Test("the lens and layer delete buttons route through the seal")
    func deleteTwinsRouteThroughSeal() throws {
        let sources = try scannedSources()
        // Each button's own chain: its head up to what follows it.
        for (name, head, end) in [
            (
                "KiwiVisionLensHeader.swift",
                "Button(KiwiVisionLensWords.deleteLens,role:.destructive)",
                "VStack("
            ),
            (
                "LayerEditorPopover.swift",
                "Button(LayerEditorWords.deleteLayer,role:.destructive)",
                "Spacer("
            ),
        ] {
            let source = try Self.source(name, in: sources)
            let flat = source.filter { !$0.isWhitespace }
            let start = try #require(flat.range(of: head))
            let tail = flat[start.upperBound...]
            let stop = try #require(tail.range(of: end))
            let chain = tail[..<stop.lowerBound]
            #expect(
                chain.contains(".settingsActionButton()")
                    && !chain.contains(".buttonStyle("),
                Comment(
                    rawValue:
                        "\(name): Delete must be a destructive "
                        + "`.settingsActionButton()`, never a raw "
                        + "tinted `.bordered` (#3630)."
                )
            )
            if name == "KiwiVisionLensHeader.swift" {
                // The lens's settings sit on a card plate (#3630).
                #expect(flat.contains(".background(SettingsCardPlate())"))
                #expect(
                    flat.contains(
                        "role:.cancel){}.keyboardShortcut(.defaultAction)"
                    ),
                    Comment(
                        rawValue:
                            "the lens delete dialog's Cancel must be "
                            + "the default action (#3630)."
                    )
                )
            }
        }
        let face = try Self.source("ChipFace.swift", in: sources)
            .filter { !$0.isWhitespace }
        #expect(
            face.contains(
                "configuration.role==.destructive?SettingsTheme.danger"
            ) && face.contains(".foregroundStyle(ink)"),
            "ChipFace must draw a destructive role's label in danger red"
        )
    }

    private static func source(
        _ name: String,
        in sources: [URL]
    ) throws -> String {
        let file = try #require(
            sources.first { $0.lastPathComponent == name },
            Comment(rawValue: "no such file: \(name)")
        )
        return SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
    }
}
