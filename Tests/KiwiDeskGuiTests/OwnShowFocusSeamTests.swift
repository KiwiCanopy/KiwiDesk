import Foundation
import Testing

/// The production wirings of the own-window door's debt (#1380)
/// that no unit test reaches — the `FollowFocusSeamTests` shape,
/// for the third `FollowFocusIntent` instance. `PlacementIntentTests`
/// holds what the door and the payer DO; what a fixture cannot
/// see is the SHAPE: a recorder that moved out of the door, a
/// second recorder owing a focus nobody drains, a payer that
/// left the `.windowCreated` arm (the one moment the arriving
/// window has an id for the command to take), or a retire that
/// vanished from the gone-for-good ender. Each needle is pinned
/// by EXACT COUNT and to its file, because this seam fails in
/// both directions — zero of any of them is the defect back, the
/// re-shown window bounced.
@Suite("The own-window door's debt stays wired (#1380)")
struct OwnShowFocusSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let core = root.appendingPathComponent(
        "Sources/KiwiDeskCore"
    )
    private static let door = "KiwiCore+PlacementBounce.swift"

    /// needle → the one Core file that may carry it. The recorder
    /// is the door's untracked arm and the drain its payer, both
    /// beside the arm they serve; the payer is called once, by
    /// the arrival arm the other two intent ledgers drain on
    /// (`FollowFocusSeamTests`, `ReturningFocusSeamTests`); the
    /// retire rides the one gone-for-good ender with theirs.
    private static let wirings: [(String, String)] = [
        ("ownShowFocus.record(", door),
        ("ownShowFocus.claim(", door),
        ("ownShowFocus.retire(", "KiwiCore+AwayWindows.swift"),
        ("payOwnShowFocus(arrived:", "KiwiCore+Events.swift"),
    ]

    @Test("each wiring exists exactly once, in its own file")
    func wiringsAreSingular() throws {
        for (needle, file) in Self.wirings {
            let sites = try SourceScan.identifierSites(
                of: needle,
                under: Self.core
            )
            #expect(
                sites.count == 1
                    && sites.allSatisfy {
                        $0.file.lastPathComponent == file
                    },
                .init(
                    rawValue: "expected one `\(needle)` in \(file), "
                        + "found "
                        + sites.map(\.site).joined(separator: ", ")
                )
            )
        }
    }

    /// The payer runs inside the `.windowCreated` arm of
    /// `handle`, after the fold and after the sibling payers.
    @Test("the payer rides the arrival arm")
    func payerRidesTheArrivalArm() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "App/KiwiCore+Events.swift"
            )
        )
        let handle = try #require(
            SourceScan.declarationBody(
                after: "func handle(_ event: KiwiEvent) {",
                in: source
            )
        )
        let start = try #require(
            handle.range(of: "case .windowCreated(let window):")
        )
        let rest = handle[start.upperBound...]
        let end =
            rest.range(of: "\n        case .")?.lowerBound
            ?? rest.endIndex
        let arm = rest[..<end]
        let own = try #require(
            arm.range(of: "payOwnShowFocus(arrived: window.id)")
        )
        // AFTER both sibling payers: the stand-down that makes a
        // window two ledgers name a single command reads the
        // focus they set, so paying first would pay twice.
        for sibling in [
            "payFollowedFocus(arrived:", "payReturningFocus(arrived:",
        ] {
            let site = try #require(arm.range(of: sibling))
            #expect(site.lowerBound < own.lowerBound, .init(rawValue: sibling))
        }
    }

    /// This instance has no re-key and no forget by construction
    /// — an own window is never a native tab, and the debt is
    /// keyed by the one window the door was told about — so a
    /// spelling of either is a new consumer nobody weighed.
    @Test("the debt is neither re-keyed nor forgotten")
    func noRekeyNoForget() throws {
        for needle in ["ownShowFocus.rekey(", "ownShowFocus.forget("] {
            let sites = try SourceScan.identifierSites(
                of: needle,
                under: Self.core
            )
            #expect(
                sites.isEmpty,
                "found \(sites.map(\.site).joined(separator: ", "))"
            )
        }
    }
}
