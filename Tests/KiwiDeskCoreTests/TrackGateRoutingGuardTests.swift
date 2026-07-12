import Foundation
import Testing

@testable import KiwiDeskCore

/// Source-scan guard for the advanced-track gate's routing rule
/// (#181, review): every consumer must read track params
/// through `KiwiCore.effectiveTrack(for:)` (or the engine's
/// `layoutInput` clamp) — a direct `resolvedTrack` call returns
/// UNgated params and silently bypasses the clamp. The clamp
/// seams are convention-guarded, so this test turns the
/// convention into a red build: a new call site either routes
/// correctly or consciously joins the allow list below.
@Suite("Advanced-track gate routing guard (#181)")
struct TrackGateRoutingGuardTests {
    /// Files allowed to say `resolvedTrack(`:
    /// - its definition + the `context()` assembly (clamped by
    ///   the engine's `layoutInput` immediately after), and
    /// - the one wrapper every command path uses.
    private static let allowed: Set<String> = [
        "TilingSettings+Resolution.swift",
        "KiwiCore+TrackAdvanced.swift",
    ]

    @Test("resolvedTrack has no callers outside the clamp seams")
    func noUngatedCallers() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("Sources")
        let enumerator = try #require(
            FileManager.default.enumerator(
                at: sources,
                includingPropertiesForKeys: nil
            )
        )
        var offenders: [String] = []
        for case let url as URL in enumerator
        where url.pathExtension == "swift" {
            guard
                !Self.allowed.contains(url.lastPathComponent),
                let text = try? String(
                    contentsOf: url,
                    encoding: .utf8
                )
            else { continue }
            // Comment lines don't call anything — doc comments
            // may (and do) reference the resolver by name.
            let calls = text.split(separator: "\n").contains {
                let line = $0.trimmingCharacters(
                    in: .whitespaces
                )
                return !line.hasPrefix("//")
                    && line.contains("resolvedTrack(")
            }
            if calls {
                offenders.append(url.lastPathComponent)
            }
        }
        #expect(
            offenders.isEmpty,
            """
            resolvedTrack( called outside the clamp seams — \
            route through KiwiCore.effectiveTrack(for:) so \
            the advanced-track gate applies: \
            \(offenders.joined(separator: ", "))
            """
        )
    }
}
