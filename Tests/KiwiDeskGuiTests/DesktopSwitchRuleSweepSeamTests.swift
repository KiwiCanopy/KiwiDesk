import Foundation
import Testing

/// A bound Desktop's apply skips its window-rule sweep because the
/// switch's own batched sweep is requested right after the handler
/// (#2347). That promise lives in another file, so it is pinned as
/// spellings: `desktopChanged` opens the batch, runs the event,
/// then requests the reads, the handler has that one caller, and
/// the deferral wraps the binding apply in the handler alone. The
/// trade: a second path into the handler spelled through a
/// closure, not a call, is invisible here — review's.
@Suite("A bound switch's skipped sweep is the switch's (#2347)")
struct DesktopSwitchRuleSweepSeamTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    private static func body(
        of declaration: String,
        in path: String
    ) throws -> String {
        let source = try SourceScan.strippedSource(
            at: core.appendingPathComponent(path)
        )
        return try #require(
            SourceScan.declarationBody(after: declaration, in: source),
            "\(declaration) is gone from \(path)"
        )
    }

    @Test("the batch opens before the handler and reads after it")
    func sweepFollowsTheHandler() throws {
        let body = try Self.body(
            of: "func desktopChanged()",
            in: "Events/EventLoop+Apps.swift"
        )
        let open = try #require(body.range(of: "beginSwitchReconcile()"))
        let event = try #require(
            body.range(of: "onEvent(.desktopChanged)")
        )
        let sweep = try #require(body.range(of: "requestSwitchReads()"))
        // Open first, so the handler's bar refresh waits for the
        // arrivals; read after, so the bound profile's rules gate.
        #expect(open.upperBound < event.lowerBound)
        #expect(event.upperBound < sweep.lowerBound)
    }

    @Test("the handler has the switch event as its one caller")
    func handlerHasOneCaller() throws {
        let sites = try SourceScan.identifierSites(
            of: "handleDesktopChange(",
            under: Self.core
        )
        // The declaration and the `.desktopChanged` arm.
        #expect(
            sites.count == 2,
            .init(
                rawValue: "found "
                    + sites.map(\.site).joined(separator: ", ")
            )
        )
        let files = Set(sites.map(\.file.lastPathComponent))
        #expect(
            files == ["KiwiCore+Desktops.swift", "KiwiCore+Events.swift"]
        )
    }

    @Test("the deferral wraps the handler's binding apply alone")
    func deferralHasOneCaller() throws {
        let sites = try SourceScan.identifierSites(
            of: "applyBindingDeferringRuleSweep(",
            under: Self.core
        )
        #expect(sites.count == 2)
        let handler = try Self.body(
            of: "func handleDesktopChange",
            in: "Profiles/KiwiCore+Desktops.swift"
        )
        #expect(handler.contains("applyBindingDeferringRuleSweep(in:"))
        #expect(!handler.contains("applyDesktopBinding(in:"))
        let flag = try SourceScan.identifierSites(
            of: "defersRuleSweepToSwitchPass",
            under: Self.core
        )
        // Declared; read by the gate; saved, raised and restored
        // by the wrapper — per site, so a second read or raise in
        // one of those files reds too.
        let perFile = Dictionary(
            grouping: flag,
            by: \.file.lastPathComponent
        ).mapValues(\.count)
        #expect(
            perFile
                == [
                    "KiwiCore.swift": 1,
                    "KiwiCore+StructuredRules.swift": 1,
                    "KiwiCore+DesktopBindings.swift": 3,
                ]
        )
    }

    @Test("the switch event has one emitter, the switch itself")
    func switchEventHasOneEmitter() throws {
        let needles = [
            "onEvent(.desktopChanged)",
            "handle(.desktopChanged)",
        ]
        let emits = try needles.flatMap {
            try SourceScan.identifierSites(of: $0, under: Self.core)
        }
        // A second emitter enters the handler with no sweep after
        // it.
        #expect(
            emits.map(\.file.lastPathComponent)
                == ["EventLoop+Apps.swift"],
            .init(
                rawValue: "found "
                    + emits.map(\.site).joined(separator: ", ")
            )
        )
    }
}
