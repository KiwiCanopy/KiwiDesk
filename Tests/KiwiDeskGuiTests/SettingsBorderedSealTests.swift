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
/// One residue is knowingly unguarded and stated so it is not
/// mistaken for coverage: a `role: .destructive` button routed
/// THROUGH the seal is invisible to every needle here — the
/// role sits inside the `Button` initialiser, lines away from
/// the modifier, so no substring count can bind the two. The
/// seal silently suppresses such a button's system red (#770's
/// hand-pairing did exactly that on LayerStripEditor's delete,
/// carried into the seal by #771 and caught in its review).
/// Only the COMPLIANT path is registered — a destructive
/// button styled raw names itself in `borderedExempt` — so a
/// misrouted one is caught by review and the owner's eye, not
/// by any needle here.
@Suite("Settings bordered seal")
struct SettingsBorderedSealTests {
    /// The trees this guard covers — `ChromeScanRoots`, which
    /// is the ONE list of "which GUI trees draw chrome". It was
    /// hand-copied into five suites when the Onboarding tree
    /// joined (#828), which is five registers a sixth tree has
    /// to be added to and four places for it to be forgotten.
    private var scanRoots: [URL] {
        ChromeScanRoots.urls(from: #filePath)
    }

    private func scannedSources() throws -> [URL] {
        try ChromeScanRoots.sources(from: #filePath)
    }

    @Test("every scan root is actually read")
    func everyScanRootIsRead() throws {
        for root in scanRoots {
            #expect(
                !(try SourceScan.swiftSources(under: root))
                    .isEmpty,
                Comment(
                    rawValue: "\(root.lastPathComponent) yielded "
                        + "no Swift files — this guard no longer "
                        + "covers that tree"
                )
            )
        }
        // Derived from what the scan READ, never from the
        // literal list: deleting a root leaves the loop above
        // green, having faithfully checked whatever remains.
        #expect(
            try scannedSources().contains {
                $0.path.contains("/Onboarding/")
            }
        )
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
    private let borderedExempt:
        [String: (count: Int, needle: String, why: String)] = [
            "SpacesSection+Overrides.swift": (
                1, "role: .destructive",
                "the system red IS the warning and must survive"
            ),
            "SpaceOverrideRows+Footer.swift": (
                1, "role: .destructive", "reset-all"
            ),
            "NativeSpacesGroup.swift": (
                1, "role: .destructive",
                "unbind; its sibling bind button is sealed"
            ),
            "LayerStripEditor.swift": (
                1, "role: .destructive",
                "delete layer; #770's hand-pairing suppressed "
                    + "its red, carried through by #771's seal "
                    + "until this fix — its sealed sibling is "
                    + "rename"
            ),
            "KeyRecorderField.swift": (
                1, ".tint(buttonTint)",
                "resolves its own tint per state: red on a "
                    + "rejected chord, ink otherwise. The recording "
                    + "signal is the chrome's own accent fill, "
                    + "which never reads the tint"
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
        #expect(
            source.occurrences(of: "buttonStyle(.bordered)") == 1,
            "the seal applies the bordered style exactly once"
        )
        #expect(
            SourceScan.adjacentPairs(
                in: source,
                line: "buttonStyle(.bordered)",
                followedBy: ".neutralButtonLabel()"
            ) == 1,
            Comment(
                rawValue:
                    "the seal's `.neutralButtonLabel()` must sit "
                    + "directly beneath its `buttonStyle"
                    + "(.bordered)` — a seal that styles without "
                    + "neutralising re-opens #759 at every call "
                    + "site at once."
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
}
