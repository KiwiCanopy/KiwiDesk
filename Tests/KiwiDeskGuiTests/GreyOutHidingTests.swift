import Foundation
import Testing

/// The other half of "grey, don't hide" (#171/#520): the scan
/// for views that REMOVE a control instead of dimming it. Split
/// out of `GreyOutParityTests` when that file reached the
/// 350-line ceiling (§5, split early); same lens, opposite
/// shape — that suite pins the gates that must be present, this
/// one hunts the conditional that must not.
@Suite("Grey, don't hide — no hiding")
struct GreyOutHidingTests {
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    /// The hiding shape, discovered rather than enumerated.
    /// `if <predicate> {` around settings content removes it from
    /// the tree, which loses the cue that the stored value is
    /// preserved (`docs/ui-patterns.md`). Findings A7
    /// (`if bar.enabled`) and A8 (`if !model.editingStoredProfile`)
    /// were both exactly this.
    private let hidingPredicates = [
        "if bar.enabled {",
        "if !model.editingStoredProfile {",
        "if model.editingStoredProfile {",
        "if style.wrappedValue.enabled {",
        "if visual.enabled {",
    ]

    /// OS-capability gates are the one legitimate reason to
    /// remove rather than dim: a control for a rendering path
    /// this macOS cannot perform is not "off", it does not
    /// exist (`AppBarStyle.glassAvailable`, settled in #390).
    /// Stated as prose, not as a constant: the old constant was
    /// asserted non-empty and scanned for nothing, which read
    /// like coverage of the carve-out and was not.
    ///
    /// Fail-shut exemptions, one line of reason each. The scan
    /// stays broad ON PURPOSE — narrowing the needles to the two
    /// shapes this sweep fixed would turn the lens back into a
    /// list, and site ten would be invisible again. So a NEW
    /// `if <predicate> {` in Settings fails here until someone
    /// states why it removes rather than dims.
    ///
    /// Every entry below was examined when the guard was
    /// written; all three predate #520 and none of them hides a
    /// control that exists in the other mode.
    private let hidingExempt: [String: String] = [
        // ADDS an explanatory banner in stored-profile mode.
        // Additive, so there is nothing being taken away.
        "ShortcutsSection.swift":
            "adds a banner; removes nothing",
        // Not a view at all — a `String?` computed property
        // choosing which status sentence to return.
        "ProfileHeader.swift":
            "String? branch, not a rendered control",
        // An either/or slot: every branch renders a control (or
        // EmptyView in raw-Lua mode, where a profile-copy verb
        // has no referent). Nothing is hidden that exists in the
        // other branch.
        "SettingsFooter.swift":
            "either/or slot; each mode renders its own verb",
    ]

    @Test("no settings view hides a control it should grey")
    func noHidingPredicatesRemain() throws {
        var scanned = 0
        let files = try SourceScan.swiftSources(
            under: settingsDir
        )
        for file in files {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            scanned += 1
            let name = file.lastPathComponent
            if hidingExempt[name] != nil { continue }
            for shape in hidingPredicates {
                #expect(
                    !source.contains(shape),
                    Comment(
                        rawValue:
                            "\(name) hides a control with "
                            + "`\(shape)` — grey it instead "
                            + "(#171), or add it to hidingExempt "
                            + "with a stated reason"
                    )
                )
            }
        }
        // A scan over nothing passes vacuously.
        #expect(scanned > 40)
        // An exemption for a file that no longer exists is a
        // stale excuse quietly widening the net.
        let names = Set(files.map(\.lastPathComponent))
        for (file, reason) in hidingExempt {
            #expect(
                names.contains(file),
                Comment(
                    rawValue: "stale hiding exemption: \(file)"
                )
            )
            #expect(!reason.isEmpty)
        }
    }
}
