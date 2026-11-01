import Foundation
import Testing

/// The `.id()` census beside the anchor primitives (#277 part 2,
/// #610), split from `SettingsAnchorPrimitiveTests` at the §2.1
/// ceiling: every `.id(` in the GUI target is a counted, reasoned
/// site, so a raw search anchor cannot grow back.
@Suite("Settings anchor identity sites")
struct SettingsAnchorIdentityTests {
    /// Rooted at the whole GUI target, not `Settings/`: the
    /// modifiers are `internal` `View` extensions, so a call site
    /// in `Shortcuts/` would be just as wrong and was previously
    /// unswept. Zero hits live outside `Settings/` today, so the
    /// wider root is free and closes it permanently.
    private var guiDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
    }

    /// `file -> count` for every file containing `needle`.
    private func occurrences(
        of needle: String,
        excluding allowed: Set<String>
    ) throws -> [(name: String, count: Int)] {
        var hits: [(name: String, count: Int)] = []
        for file in try SourceScan.swiftSources(under: guiDir)
        where !allowed.contains(file.lastPathComponent) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let count = source.occurrences(of: needle)
            if count > 0 {
                hits.append((file.lastPathComponent, count))
            }
        }
        return hits
    }

    /// `searchAnchor` is a one-line `.id()` wrapper, so a raw
    /// `.id(control.id)` at a call site is a third door into the
    /// same mistake: it anchors without washing, and sealing the
    /// halves does not close it. A search hit then scrolls
    /// correctly and flashes nothing — silent, and the most
    /// plausible regression of all, since `.id()` is ordinary
    /// SwiftUI rather than anything this subsystem invented.
    /// Exact counts, not an exempt file set. A whole-file
    /// exemption would blind the guard to a SECOND `.id(` in one
    /// of these — and `KeybindingNavRow` is a real Settings row
    /// in the destination whose controls it would be tempted to
    /// anchor, so that blind spot sits exactly where the mistake
    /// would be made. Same idiom as `alternatelyMounted`: record
    /// the number, not the permission.
    ///
    /// Known limit worth naming rather than rediscovering: the
    /// needle carries a leading dot, so a *dotless* `id(...)`
    /// inside a `View` extension — the shape `searchAnchor`'s own
    /// body uses — is invisible here.
    private let identitySites: [String: Int] = [
        // Collection identity, not search identity: each keys a
        // row inside a ForEach so edits and reorders don't
        // recycle state onto the wrong row. Nothing here is a
        // reveal target.
        "KeybindingNavRow.swift": 1,
        "KeybindingAppGroup+Row.swift": 1,
        "PocketAppRows.swift": 1,
        "AdvancedLuaGroup+Row.swift": 1,
        // Locale identity: `L()` is not observable state, so a
        // language change rebuilds the whole hosting root by
        // keying it on the locale. Deliberately the coarsest
        // `.id()` in the app — the opposite end of the scale from
        // an anchor, and it would swallow one if anybody nested
        // them.
        "LocaleScopedRoot.swift": 1,
        // Navigation identity: the header search remounts per
        // destination, clearing its query and closing the
        // result panel — restored focus was re-opening stale
        // suggestions over every push/pop (owner, 2026-08-10;
        // `HomeSurfacingTests` pins the wire). Not a reveal
        // target: the field is chrome, and nothing inside the
        // remounted subtree anchors.
        "SettingsHeaderBar.swift": 1,
        // Navigation identity again, and for the same reason
        // one level out (17a): the detached preview card keeps
        // its travel in `@State`, and its structural position
        // is identical across a destination change, so without
        // a key an area you never dragged opens with its
        // preview parked where the last one was left. Not a
        // reveal target either — the card is chrome over the
        // pane, and the panel inside it anchors nothing.
        "SettingsView+Preview.swift": 1,
        // Scroll identity: a tab switch in the update window
        // opens the new tab at its top (#1666). Not a Settings
        // destination, so nothing there is a reveal target.
        "UpdateNotesScroll.swift": 1,
        // Release identity (#2308): a pick in What's new's release
        // menu reopens the notes on Highlights, since another
        // release's tabs differ. Not a reveal target either.
        "UpdateWindowView.swift": 1,
        // Animation identity (#1726): a gesture picture's hover
        // loop ends with the view that ran it, since its rest
        // frame and the loop's target are one value. Not a reveal
        // target — the picture is hidden from accessibility.
        "GestureEntry.swift": 1,
        // Scroll identity: the tour's palette and look rows
        // scroll the live pick into view (#1720, #1528). Not a
        // Settings destination, so nothing there is a reveal
        // target.
        "OnboardingLooksRows.swift": 2,
        // Animation identity (#2144): the layout plate's name
        // crossfades on a step, old name out and new one in. Not
        // a Settings destination, so nothing there is a reveal
        // target.
        "ModeCueView.swift": 1,
        // Scroll identity: Jump to window scrolls its selected
        // row into view (#1875). Not a Settings destination, so
        // nothing there is a reveal target.
        "JumpPanelView.swift": 1,
        // Scroll identity: Add binding scrolls the Shortcuts page
        // to its end, past the floating save pill (#2688). Not a
        // reveal target — the mark is the page's padded edge.
        "ShortcutsSection.swift": 1,
    ]

    @Test("no ad-hoc .id() outside collection identity")
    func identityModifiersAreConfined() throws {
        let hits = try occurrences(of: ".id(", excluding: [])
        var seen: Set<String> = []
        for hit in hits {
            seen.insert(hit.name)
            let allowed =
                identitySites[hit.name]
                .map(String.init) ?? "none"
            #expect(
                identitySites[hit.name] == hit.count,
                Comment(
                    rawValue:
                        "\(hit.name) applies .id(…) "
                        + "×\(hit.count), expected \(allowed) — "
                        + "a search anchor takes "
                        + ".searchAnchored(control) so it cannot "
                        + "anchor without washing"
                )
            )
        }
        // A renamed or deleted exempt file must not leave a stale
        // entry standing in for coverage it no longer provides.
        #expect(seen == Set(identitySites.keys))
    }
}
