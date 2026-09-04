import Foundation
import Testing

@testable import KiwiDeskCore

/// What the stamping pass writes, and what it refuses (#1147).
/// Reaches the bridge only through `classResolverOverride`
/// (os-private-apis.md) and the topology only through
/// `spacesOverride`, so nothing here touches the host's
/// WindowServer. `.serialized`: both are process-global.
///
/// **The two clauses that assert nothing was written cannot tell
/// a refusal from an unwired writer**, and they lean on
/// `stampsAndFoldsIn` in this suite for that (`guard-prover`,
/// 2026-09-03): deleting `makeCore`'s take-back of the live
/// writer reds the positive clauses and leaves both negatives
/// green. Read neither one on its own as covering the refusal it
/// names.
@MainActor
@Suite("Desktop stamping (#1147)", .serialized)
struct DesktopStampingTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-stamp-\(UUID().uuidString)"
                )
        )
        // This suite is ABOUT the write, so it takes the live
        // writer back from `makeTestCore`'s refusing pin — with
        // the bridge faked below, so the host's WindowServer is
        // still never reached.
        core.desktopMemory.writeStamp = KiwiCore.liveStampWrite
        return core
    }

    /// The bridge answers, and every `SpaceSetValues` is captured.
    private func withBridge(_ body: () -> Void) {
        Written.reset()
        WMBridge.classResolverOverride = { name in
            switch name {
            case "CopyManagedDisplaySpacesOperation":
                return FakeCopySpaces.self
            case "SpaceSetValuesOperation":
                return FakeSetValues.self
            default: return nil
            }
        }
        defer { WMBridge.classResolverOverride = nil }
        body()
    }

    private func pin(_ spaces: [NativeSpace]) {
        NativeSpaces.spacesOverride = spaces
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        NativeSpaces.activeSpaceIDOverride = spaces.first?.id
    }

    private func reset() {
        NativeSpaces.spacesOverride = nil
        NativeSpaces.mainDisplayUUIDOverride = nil
        NativeSpaces.activeSpaceIDOverride = nil
    }

    private func space(
        _ id: UInt64,
        isUser: Bool = true,
        identity: DesktopIdentity? = nil
    ) -> NativeSpace {
        NativeSpace(
            id: id,
            displayUUID: "UUID-A",
            isCurrent: id == 1,
            isUser: isUser,
            identity: identity
        )
    }

    /// The deferred verify in one clause: the write is dispatched,
    /// and the returned snapshot does NOT carry the identity —
    /// dispatched is not applied (#884/#889), so a snapshot
    /// asserting it would hand every caller a key no later
    /// reading can name. That fold shipped and was removed
    /// (architect review, 2026-09-04).
    @Test("a stamp is dispatched, and not claimed until it lands")
    func stampsWithoutClaiming() throws {
        defer { reset() }
        pin([space(1), space(4)])
        let core = makeCore()
        withBridge {
            let snapshot = core.stampedDesktopSnapshot()
            #expect(Written.values.count == 2)
            #expect(
                snapshot.spaces.allSatisfy { $0.identity == nil }
            )
            // …so every consumer keys by the number for exactly
            // this reading, the same fallback a bridgeless host
            // lives on permanently.
            #expect(snapshot.key(of: 1) == .number(1))
            // The pass hands over the BARE key and the wrapper
            // namespaces it (#889), so what actually lands is the
            // very key the plist read door looks for — the two
            // doors proved to be one spelling.
            #expect(
                Written.values.allSatisfy {
                    Array($0.keys) == [DesktopIdentity.plistKey]
                }
            )
        }
    }

    @Test("a Desktop that already carries one is left alone")
    func stampedDesktopIsNotRewritten() {
        defer { reset() }
        pin([space(1, identity: DesktopIdentity(raw: "KEEP"))])
        let core = makeCore()
        withBridge {
            let snapshot = core.stampedDesktopSnapshot()
            #expect(Written.values.isEmpty)
            #expect(
                snapshot.spaces.first?.identity
                    == DesktopIdentity(raw: "KEEP")
            )
        }
    }

    /// A fullscreen or system space is not a Desktop and never
    /// gets written — the same `isUser` verdict #670 rules on.
    @Test("a non-user space is never stamped")
    func nonUserSpaceIsNeverStamped() {
        defer { reset() }
        pin([space(1), space(9, isUser: false)])
        let core = makeCore()
        withBridge {
            _ = core.stampedDesktopSnapshot()
            #expect(Written.values.count == 1)
        }
    }

    /// Absent is allowed, faked is not: with no bridge the pass
    /// writes nothing and every Desktop keeps its number.
    @Test("without the bridge nothing is written")
    func noBridgeNoWrite() {
        defer { reset() }
        pin([space(1), space(4)])
        let core = makeCore()
        Written.reset()
        WMBridge.classResolverOverride = { _ in nil }
        defer { WMBridge.classResolverOverride = nil }
        let snapshot = core.stampedDesktopSnapshot()
        #expect(Written.values.isEmpty)
        #expect(snapshot.spaces.allSatisfy { $0.identity == nil })
    }

    /// Performed is not applied (#884/#889). A stamp the
    /// WindowServer did not keep is noticed at the NEXT snapshot
    /// — the only place it can be — and is not retried in a loop.
    @Test("a stamp that did not land is attempted once, then dropped")
    func unlandedStampIsNotRetried() {
        defer { reset() }
        pin([space(1)])
        let core = makeCore()
        var logged: [String] = []
        core.onLog = { logged.append($0) }
        withBridge {
            _ = core.stampedDesktopSnapshot()
            #expect(Written.values.count == 1)
            // The topology still lacks it: the write was dropped.
            _ = core.stampedDesktopSnapshot()
            #expect(Written.values.count == 1)
            // …and a third call does not try again either.
            _ = core.stampedDesktopSnapshot()
            #expect(Written.values.count == 1)
        }
        #expect(
            logged.contains { $0.contains("did not keep its stamp") }
        )
    }

    /// The mirror: a stamp that DID land clears the attempt, so
    /// the Desktop is never marked unstampable.
    @Test("a stamp that lands is confirmed, not condemned")
    func landedStampIsConfirmed() {
        defer { reset() }
        pin([space(1)])
        let core = makeCore()
        withBridge {
            _ = core.stampedDesktopSnapshot()
            #expect(core.desktopMemory.stampAttempts == [1])
            // The WindowServer took it; the next read sees it.
            NativeSpaces.spacesOverride = [
                space(1, identity: DesktopIdentity(raw: "LANDED"))
            ]
            _ = core.stampedDesktopSnapshot()
            #expect(core.desktopMemory.stampAttempts.isEmpty)
            #expect(core.desktopMemory.unstampable.isEmpty)
            #expect(Written.values.count == 1)
        }
    }
}

// MARK: - Fakes

private enum Written {
    nonisolated(unsafe) static var values: [[String: Any]] = []
    static func reset() { values = [] }
}

/// Makes `WMBridge.isAvailable` answer true: availability is a
/// synchronous read that ANSWERS, never a class that resolves.
private final class FakeCopySpaces: NSObject {
    @objc override init() { super.init() }

    @objc var propertyListArray: [[String: Any]] { [] }

    @objc func performWithWMBridgeDelegate() -> NSObject { self }
}

private final class FakeSetValues: NSObject {
    @objc(initWithSpaceID:values:)
    init(spaceID: UInt64, values: [String: Any]) {
        Written.values.append(values)
    }

    @objc func performWithWMBridgeDelegate() {}
}
