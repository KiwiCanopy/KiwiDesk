import Foundation
import Testing

/// The other half of the anchor guards (#573). Its sibling
/// `SettingsAnchorPrimitiveTests` sweeps WHERE a reveal shape may
/// appear; this one asks whether the pair it applies is
/// well-formed — the residue after the type system takes what it
/// can.
///
/// What the types own: an id can only come from a
/// `SettingsControl`, because the raw `String` halves are
/// `fileprivate` to `SettingsReveal.swift`. What they cannot say:
/// that a shape's two halves name the SAME control, and that it
/// applies both. `searchAnchorCard(a)` beside
/// `searchFlashHeader(b)`, or either one alone, compiles — and
/// fails silently, since a reveal then scrolls to one id and
/// washes another, or washes nothing.
@Suite("Settings anchor pairing")
struct SettingsAnchorPairingTests {
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    private var revealFile: URL {
        settingsDir.appendingPathComponent("SettingsReveal.swift")
    }

    private func source(of file: URL) throws -> String {
        SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
    }

    /// The raw `String` halves are `fileprivate`, which is what
    /// makes a literal id **impossible** rather than merely
    /// caught. Widening either one back to `internal` silently
    /// restores that whole failure class and nothing else would
    /// notice, so the access level itself is the invariant.
    @Test("the raw String halves stay fileprivate")
    func rawHalvesStayFilePrivate() throws {
        let text = try source(of: revealFile)
        for half in ["searchAnchor", "searchFlash"] {
            let declared = text.occurrences(of: "func \(half)(")
            let sealed = text.occurrences(
                of: "fileprivate func \(half)("
            )
            #expect(
                declared == 1 && sealed == 1,
                Comment(
                    rawValue:
                        "\(half) is declared \(declared)× with "
                        + "\(sealed) fileprivate — the typed "
                        + "modifiers are the only way in; a "
                        + "widened half re-opens literal ids"
                )
            )
        }
    }

    /// Inside `SettingsReveal` the three typed modifiers compose
    /// the raw halves by hand, so a slip there would compile.
    @Test("the halves in SettingsReveal name one control")
    func halvesNameOneControl() throws {
        try expectMatchedPair(
            in: revealFile,
            anchor: "searchAnchor(",
            flash: "searchFlash(",
            // Dotless needles, so each set also carries the
            // `fileprivate func` declaration's parameter list —
            // `!isEmpty` would hold even if every wrapper stopped
            // calling the halves. Two is the honest floor: the
            // declaration plus at least one call.
            //
            // A consequence worth knowing: renaming a half's
            // parameter is a cosmetic edit that fails this, since
            // the parameter list is one of the compared strings.
            // Loud and fail-shut, which is the right direction.
            floor: 2
        )
        for argument in try arguments(
            of: "searchAnchor(",
            in: revealFile
        ) {
            #expect(
                !argument.contains("\""),
                Comment(
                    rawValue:
                        "literal id '\(argument)' — the index "
                        + "only ever emits SettingsControl.id"
                )
            )
        }
    }

    /// And each container shape must apply both of its halves,
    /// over one control. `SettingsSection` splits them across its
    /// card and header; `SettingsDisclosure` anchors in each of
    /// its two chrome branches and flashes once — hence sets, not
    /// counts.
    @Test("each container shape's halves name one control")
    func containerHalvesNameOneControl() throws {
        for name in [
            "SettingsSection.swift", "SettingsDisclosure.swift",
        ] {
            let file = try #require(
                try SourceScan.swiftSources(under: settingsDir)
                    .first { $0.lastPathComponent == name }
            )
            try expectMatchedPair(
                in: file,
                anchor: ".searchAnchorCard(",
                flash: ".searchFlashHeader(",
                floor: 1
            )
        }
    }

    // MARK: - Shared assertion

    private func arguments(
        of needle: String,
        in file: URL
    ) throws -> Set<String> {
        Set(
            SourceScan.firstArguments(
                of: needle,
                in: try source(of: file)
            )
        )
    }

    private func expectMatchedPair(
        in file: URL,
        anchor: String,
        flash: String,
        floor: Int
    ) throws {
        let name = file.lastPathComponent
        let anchors = try arguments(of: anchor, in: file)
        let flashes = try arguments(of: flash, in: file)
        // Non-vacuity: a rename that stopped both needles
        // matching would otherwise pass while checking nothing.
        #expect(
            anchors.count >= floor && flashes.count >= floor,
            Comment(
                rawValue:
                    "\(name) yields \(anchors.count) anchor / "
                    + "\(flashes.count) flash argument(s), "
                    + "expected at least \(floor) each — a shape "
                    + "needs both halves, or a reveal has nothing "
                    + "to scroll to or nothing to wash"
            )
        )
        #expect(
            anchors == flashes,
            Comment(
                rawValue:
                    "\(name) anchors \(anchors.sorted()) but "
                    + "flashes \(flashes.sorted()) — a reveal "
                    + "would scroll to one id and wash another"
            )
        )
    }
}
