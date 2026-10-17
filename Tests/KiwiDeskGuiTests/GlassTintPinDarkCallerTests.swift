import Foundation
import Testing

/// **`GlassTint.pinDark` has one caller** (#2103).
///
/// The bars' glass variant is pinned from the Fill in
/// `GlassTint.apply` (#1308), so a light Fill lifts the pin.
/// `pinDark` is the Fill-less door beside it, for a surface whose
/// own ink is fixed black — KiwiVision's plate. The one-home scan
/// in `GlassTintSeamTests` exempts the home file, so it cannot see
/// who CALLS the door: a bar surface calling it would skip the
/// Fill and keep a dark glass under a light Fill, green there.
@Suite("GlassTint.pinDark callers (#2103)")
struct GlassTintPinDarkCallerTests {
    /// The files that may call the door, each with its reason —
    /// the one copy.
    private static let callers: [String: String] = [
        "Vision/VisionPlate.swift":
            "KiwiVision's plate: no Fill, a black dim over it"
    ]

    @Test("only the ruled surfaces call pinDark")
    func pinDarkHasItsCallers() throws {
        let root = GlassTintSeamTests.coreRoot
        var found: Set<String> = []
        for file in try SourceScan.swiftSources(under: root) {
            let text = Array(try SourceScan.strippedSource(at: file))
            guard
                !SourceScan.callSites(
                    in: text,
                    for: "GlassTint.pinDark"
                ).isEmpty
            else { continue }
            let path = file.standardizedFileURL.path
            let prefix = root.standardizedFileURL.path + "/"
            found.insert(String(path.dropFirst(prefix.count)))
        }
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
}
