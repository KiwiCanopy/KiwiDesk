import Foundation
import Testing

/// **`GlassTint`'s Fill-less doors have their callers** (#2103,
/// #2539).
///
/// The bars' glass variant is pinned from the Fill in
/// `GlassTint.apply` (#1308), so a light Fill lifts the pin.
/// `pinDark` is the Fill-less door beside it, for a surface whose
/// own ink is fixed black — KiwiVision's plate — and `followPick`
/// the one for a surface that follows the Appearance pick — the
/// Space-switch plates. The one-home scan in `GlassTintSeamTests`
/// exempts the home file, so it cannot see who CALLS a door: a bar
/// surface calling either would skip the Fill, whose dark pin
/// outranks the pick, green there.
@Suite("GlassTint Fill-less door callers (#2103)")
struct GlassTintPinDarkCallerTests {
    /// The files that may call `pinDark`, each with its reason —
    /// the one copy.
    private static let callers: [String: String] = [
        "Vision/VisionPlate.swift":
            "KiwiVision's plate: no Fill, a black dim over it"
    ]

    /// The files that may call `followPick`, each with its reason —
    /// the one copy.
    private static let pickFollowers: [String: String] = [
        "Animation/SpaceSlideOverlay+Plates.swift":
            "the slide's plates: no Fill, KiwiHub's glass"
    ]

    @Test("only the ruled surfaces call pinDark")
    func pinDarkHasItsCallers() throws {
        let found = try Self.callers(of: "GlassTint.pinDark")
        #expect(
            found == Set(Self.callers.keys),
            """
            pinDark's callers and the register disagree — a surface \
            with a Fill takes GlassTint.apply, and a new Fill-less \
            one owes an entry here: \
            \(found.symmetricDifference(Self.callers.keys))
            """
        )
    }

    @Test("only the ruled surfaces call followPick (#2539)")
    func followPickHasItsCallers() throws {
        let found = try Self.callers(of: "GlassTint.followPick")
        #expect(
            found == Set(Self.pickFollowers.keys),
            """
            followPick's callers and the register disagree — a \
            surface with a Fill takes GlassTint.apply, and a new \
            Fill-less one owes an entry here: \
            \(found.symmetricDifference(Self.pickFollowers.keys))
            """
        )
    }

    /// The Core files, relative to its root, that call `needle`.
    private static func callers(
        of needle: String
    ) throws -> Set<String> {
        let root = GlassTintSeamTests.coreRoot
        var found: Set<String> = []
        for file in try SourceScan.swiftSources(under: root) {
            let text = Array(try SourceScan.strippedSource(at: file))
            guard
                !SourceScan.callSites(in: text, for: needle).isEmpty
            else { continue }
            let path = file.standardizedFileURL.path
            let prefix = root.standardizedFileURL.path + "/"
            found.insert(String(path.dropFirst(prefix.count)))
        }
        return found
    }
}
