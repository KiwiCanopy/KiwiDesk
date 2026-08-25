import Foundation
import Testing

/// What the seam HANDS Sparkle (#1011).
///
/// Split from `UpdatePromptFocusTests`, which holds what the
/// driver and its policy declare. The cut follows the production
/// one: that suite reads `UpdatePromptDriver.swift`, this one
/// reads `AppUpdater.swift`, and neither can be satisfied by the
/// other's file.
///
/// **This is the half a `guard-prover` round earned.** Counting
/// the objects proved nothing about which one Sparkle is shown
/// through: rewiring `userDriver:` to a stock
/// `SPUStandardUserDriver` left every count at one, the override
/// still built, still stored, still overriding — and dead, with
/// the prompt back behind every window.
///
/// **What these needles hold is the SPELLING of the wiring, not
/// the identity of the object**, and that limit is stated rather
/// than left to be discovered. The two natural escapes are
/// closed; a `typealias` plus a local shadowing the stored
/// property still passes. Closing that needs a type-level check
/// — an `SPUUpdater` built in a test against a fake driver —
/// which is a design change rather than a needle. Read a red
/// here as "the wiring stopped saying what it said", which a
/// legal rename can also mean.
@Suite("The update seam hands Sparkle our driver (#1011)")
struct UpdatePromptWiringTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )
    private static let seam = "AppUpdater.swift"

    private static func seamSource() throws -> String {
        try SourceScan.strippedSource(
            at:
                root
                .appendingPathComponent("Sources/KiwiDesk/Updates")
                .appendingPathComponent(seam)
        )
    }

    /// Two needles for one fact. Sparkle's stock driver is
    /// SUBCLASSED here and never constructed, so any
    /// `SPUStandardUserDriver(` under the GUI tree is the
    /// rewire; and the driver named at `userDriver:` is the
    /// property the override lives on.
    ///
    /// The scan roots at `Sources/KiwiDesk` alone, which is
    /// sound rather than narrow: `Package.swift` gives the
    /// Sparkle product to that target only, so a stock-driver
    /// construction in `KiwiDeskCore` could not compile.
    @Test("Sparkle shows its UI through the overriding driver")
    func sparkleUsesTheOverridingDriver() throws {
        let stock = try SourceScan.identifierSites(
            of: "SPUStandardUserDriver(",
            under: Self.root
                .appendingPathComponent("Sources/KiwiDesk")
        )
        #expect(
            stock.isEmpty,
            .init(
                rawValue: "Sparkle's stock user driver is "
                    + "subclassed, never constructed — a "
                    + "construction is the #1011 override going "
                    + "dead: "
                    + stock.map(\.site).joined(separator: ", ")
            )
        )

        let text = try Self.seamSource()
        #expect(
            text.contains("driver = UpdatePromptDriver("),
            "the stored driver must be the overriding one"
        )
        guard
            let arguments = SourceScan.callArguments(
                of: "SPUUpdater(",
                in: text
            )
        else {
            Issue.record("no SPUUpdater construction in \(Self.seam)")
            return
        }
        #expect(
            arguments.contains("userDriver: driver"),
            .init(
                rawValue: "SPUUpdater must be handed the "
                    + "overriding driver, not another one. "
                    + "Arguments: " + arguments
            )
        )
    }

    /// The driver's answers come from our policy, not Sparkle's
    /// defaults — a `nil` delegate restores the minimize button
    /// that #1011's activation cannot undo, and drops the
    /// modal-alert activation with it.
    @Test("the driver answers from the policy")
    func driverAnswersFromThePolicy() throws {
        let text = try Self.seamSource()
        guard
            let built = SourceScan.callArguments(
                of: "UpdatePromptDriver(",
                in: text
            )
        else {
            Issue.record("no UpdatePromptDriver construction")
            return
        }
        #expect(
            built.contains("delegate: policy"),
            .init(
                rawValue: "the driver must answer from that "
                    + "policy — a nil delegate is Sparkle's "
                    + "defaults back. Arguments: " + built
            )
        )
    }
}
