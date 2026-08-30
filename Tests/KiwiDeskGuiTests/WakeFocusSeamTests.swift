import Foundation
import Testing

/// The wake focus payment's shape (#1130), which its behavior
/// suite cannot see: on a unit fixture a real `focusWindow` and
/// a bare `workspaces.focus` stamp leave identical state — no AX
/// element, so no raise — and the bare stamp IS the shipped
/// defect. `WakeFocusRestoreTests` holds what the payment does;
/// this holds that it stays a payment, singly wired.
@Suite("The wake focus payment stays wired (#1130)")
struct WakeFocusSeamTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )
    private static let core = root.appendingPathComponent(
        "Sources/KiwiDeskCore"
    )

    /// needle → its declaring file and its ONE wiring file. Two
    /// sites exactly: the `func` and the call — a second caller
    /// reds as loudly as a deleted one.
    private static let wirings: [(String, String, String)] = [
        // The wake leg's wiring: only the sleep/wake restore
        // pays; the crash leg keeps the bare replay.
        (
            "restoreAndSettleAfterWake(",
            "KiwiCore+WakeFocus.swift",
            "KiwiCore+Bootstrap.swift"
        ),
        // The disarm: an honored focus event is the payment's
        // confirmation, read at the one honored site.
        (
            "disarmWakeFocusHeal(",
            "KiwiCore+WakeFocus.swift",
            "KiwiCore+FocusEvents.swift"
        ),
        // The consume is one-shot, so a second consumer would
        // silently eat the arm before the press it exists to
        // heal — with every behavioral test green.
        (
            "consumeWakeFocusHeal(",
            "KiwiCore+WakeFocus.swift",
            "KiwiCore+FocusedCommandGuard.swift"
        ),
    ]

    @Test("each wiring is declared once and wired once")
    func wiringsAreSingular() throws {
        for (needle, declared, wired) in Self.wirings {
            let sites = try SourceScan.identifierSites(
                of: needle,
                under: Self.core
            )
            let files = sites.map(\.file.lastPathComponent)
            let expected =
                declared == wired
                ? [declared] : [declared, wired].sorted()
            #expect(
                files.sorted() == expected,
                """
                expected `\(needle)` only as declared in \
                \(declared) and wired in \(wired) — found: \
                \(sites.map(\.site).joined(separator: ", "))
                """
            )
        }
    }

    /// No behavior test can red on the wiring — every test
    /// injects the provider — so this pins it (tests.md:
    /// forget-proof the injection). Declaration, `armMachineSeams`
    /// wiring, and the one `trustedFrontmostTracked` read.
    @Test("the frontmost provider is wired and read once each")
    func providerIsWiredAndReadOnce() throws {
        let sites = try SourceScan.identifierSites(
            of: "trustedFrontmostProvider",
            under: Self.core
        )
        let files = sites.map(\.file.lastPathComponent).sorted()
        #expect(
            files
                == [
                    "KiwiCore.swift",
                    "KiwiCore+BootSeams.swift",
                    "KiwiCore+WakeFocus.swift",
                ].sorted(),
            """
            expected the provider declared in KiwiCore.swift, \
            wired in KiwiCore+BootSeams.swift, read in \
            KiwiCore+WakeFocus.swift — found: \
            \(sites.map(\.site).joined(separator: ", "))
            """
        )
    }

    @Test("the latch mutates only through its one machine")
    func latchHasOneHome() throws {
        let sites = try SourceScan.identifierSites(
            of: "wakeFocusHealArmedAt",
            under: Self.core
        )
        let files = Set(sites.map(\.file.lastPathComponent))
        #expect(
            files == [
                "KiwiCore.swift", "KiwiCore+WakeFocus.swift",
            ],
            """
            `wakeFocusHealArmedAt` may appear only in its \
            declaration and its one machine — an inline write \
            beside a call site is the #951 disarm-race shape. \
            Found: \(sites.map(\.site).joined(separator: ", "))
            """
        )
    }

    @Test("the payment performs a focus, never a bare stamp")
    func paymentPerformsAFocus() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core
                .appendingPathComponent("App")
                .appendingPathComponent(
                    "KiwiCore+WakeFocus.swift"
                )
        )
        guard
            let payer = SourceScan.declarationBody(
                after: "func restoreAndSettleAfterWake",
                in: source
            )
        else {
            Issue.record("restoreAndSettleAfterWake missing")
            return
        }
        #expect(
            payer.contains("focusWindow("),
            """
            the payment must route through `focusWindow` — a \
            bare `workspaces.focus` stamp is the #1130 defect: \
            state and the OS key app diverge and the #292 \
            preflight refuses every shortcut until a click
            """
        )
        #expect(
            !payer.contains("workspaces.focus("),
            "the payment may not stamp state beside the payer"
        )
    }
}
