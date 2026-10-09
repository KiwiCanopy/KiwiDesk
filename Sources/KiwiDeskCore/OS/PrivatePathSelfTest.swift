import CoreGraphics
import Foundation

/// The `self_test` verb (#1889): which of KiwiDesk's private fast
/// paths this macOS still answers. Read-only — a write is looked
/// up and never called, so the desk, its Desktops and every
/// setting are left as they were.
public enum PrivatePathSelfTest {
    /// The CLI-only verb (`APIReference.cliOnly`).
    public static let command = "self_test"

    /// Every probe, grouped by the home that resolves it. A
    /// resolver literal no probe names reds in
    /// `PrivatePathCensusTests`.
    @MainActor
    static func catalog(
        _ context: PrivatePathContext
    ) -> [PrivatePathProbe] {
        SkyLight.selfTestProbes(context)
            + NativeSpaces.selfTestProbes()
            + SkyLightEventPort.selfTestProbes()
            + SkyLightWindowEvents.selfTestProbes()
            + WMBridge.selfTestProbes(context)
    }

    /// Runs each probe once, in order, into the verb's reply.
    @MainActor
    static func report(
        _ probes: [PrivatePathProbe],
        macOS: String
    ) -> JSONValue {
        var counts = Dictionary(
            uniqueKeysWithValues: PrivatePathVerdict.labels.map {
                ($0, 0)
            }
        )
        let rows = probes.map { probe -> JSONValue in
            let verdict = probe.check()
            counts[verdict.label, default: 0] += 1
            return .object([
                "name": .string(probe.name),
                "kind": .string(probe.kind.rawValue),
                "home": .string(probe.home),
                "verdict": .string(verdict.label),
                "detail": .string(detail(of: verdict, probe.kind)),
            ])
        }
        return .object([
            "macos": .string(macOS),
            "counts": .object(
                counts.mapValues { .number(Double($0)) }
            ),
            "probes": .array(rows),
        ])
    }

    static func detail(
        of verdict: PrivatePathVerdict,
        _ kind: PrivatePathProbe.Kind
    ) -> String {
        switch verdict {
        case .works(let text), .answered(let text), .failed(let text),
            .inconclusive(let text):
            return text
        case .unexercised:
            return "looked up only; the read-only run never calls it"
        case .absent:
            return kind == .symbol
                ? "lookup failed; the public fallback runs"
                : "class not found; the capability is absent"
        }
    }
}
