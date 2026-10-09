import CoreGraphics
import Foundation

/// What `self_test` found for one private fast path (#1889).
/// Detail strings are English: they reach the CLI only.
public enum PrivatePathVerdict: Equatable, Sendable {
    /// Resolved, and a read-only call answered and agreed with
    /// an independent re-query.
    case works(String)
    /// Present, but a write the read-only run never performs.
    case unexercised
    /// The lookup answered nil: the public fallback (or, where
    /// macOS offers none, the refusal) is what runs.
    case absent
    /// Resolved, but the read answered nothing or disagreed.
    case failed(String)
    /// Resolved, with nothing on this desk to verify against.
    case inconclusive(String)

    /// The machine-readable label, also the CLI's first column.
    public var label: String {
        switch self {
        case .works: return "works"
        case .unexercised: return "resolved"
        case .absent: return "absent"
        case .failed: return "failed"
        case .inconclusive: return "inconclusive"
        }
    }

    /// Every label, in the order the report counts them.
    public static let labels = [
        "works", "resolved", "absent", "failed", "inconclusive",
    ]
}

/// One private fast path, probed through the home that resolves
/// it — never re-resolved beside it (#1889, os-private-apis.md).
/// Building a probe reads nothing; `check` is the read.
public struct PrivatePathProbe {
    public enum Kind: String, Sendable {
        /// A C function resolved with `dlsym`.
        case symbol
        /// An `SLSBridged*Operation` class `WMBridge` resolves.
        case bridgeClass = "bridge_class"
    }

    public let name: String
    public let kind: Kind
    /// The type that resolves it: `SkyLight`, `WMBridge`, …
    public let home: String
    let check: @MainActor () -> PrivatePathVerdict

    init(
        _ name: String,
        kind: Kind = .symbol,
        home: String,
        check: @escaping @MainActor () -> PrivatePathVerdict
    ) {
        self.name = name
        self.kind = kind
        self.home = home
        self.check = check
    }

    /// A read: absent when `resolved` is false, else `verify`'s
    /// answer — which is never asked of an absent path.
    static func read(
        _ name: String,
        kind: Kind = .symbol,
        home: String,
        resolved: @escaping @MainActor () -> Bool,
        verify: @escaping @MainActor () -> PrivatePathVerdict
    ) -> PrivatePathProbe {
        PrivatePathProbe(name, kind: kind, home: home) {
            resolved() ? verify() : .absent
        }
    }

    /// A write the read-only run only looks up, never calls.
    static func write(
        _ name: String,
        kind: Kind = .symbol,
        home: String,
        resolved: @escaping @MainActor () -> Bool
    ) -> PrivatePathProbe {
        PrivatePathProbe(name, kind: kind, home: home) {
            resolved() ? .unexercised : .absent
        }
    }
}

/// What a probe may read beyond its own home: one of KiwiDesk's
/// own on-screen windows, and the two compositor doors Core
/// reads the per-Desktop census through (`DesktopCensusSeamTests`).
@MainActor
struct PrivatePathContext {
    /// One of this process's windows as the PUBLIC window list
    /// reports it — the witness a SkyLight read is checked against.
    struct OwnWindow: Equatable {
        let id: CGWindowID
        let bounds: CGRect
    }

    var ownWindow: () -> OwnWindow?
    var census: () -> DesktopCensus?
    var spaceOfWindow: (WindowID) -> WindowSpaceReading

    /// Nothing on the desk: every context read answers empty.
    static let empty = PrivatePathContext(
        ownWindow: { nil },
        census: { nil },
        spaceOfWindow: { _ in .unavailable }
    )

    /// This process's lowest-layer on-screen window, from
    /// `CGWindowListCopyWindowInfo` — public, and read-only.
    static func firstOwnWindow() -> OwnWindow? {
        guard
            let info = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else { return nil }
        let pid = ProcessInfo.processInfo.processIdentifier
        let own = info.compactMap { entry -> (Int, OwnWindow)? in
            guard (entry[kCGWindowOwnerPID as String] as? Int32) == pid,
                let number = entry[kCGWindowNumber as String] as? UInt32,
                let raw = entry[kCGWindowBounds as String]
                    as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: raw),
                bounds.width > 1, bounds.height > 1
            else { return nil }
            let layer = entry[kCGWindowLayer as String] as? Int ?? 0
            return (layer, OwnWindow(id: number, bounds: bounds))
        }
        return own.min { $0.0 < $1.0 }?.1
    }
}
