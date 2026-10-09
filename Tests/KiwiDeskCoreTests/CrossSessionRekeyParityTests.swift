import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `StateSnapshot.rekeyed` is a third hand-written copy of the
/// snapshot's records (#1385), so every stored property of
/// `StateSnapshot`, `SpaceRecord` and `WindowRecord` is classified
/// here as carried or dropped, by reflection (parity-tests.md): a
/// field added tomorrow reds until it is answered, and each answer
/// is held against what `rekeyed` actually returns.
@Suite("Cross-session rekey parity (#1385)")
struct CrossSessionRekeyParityTests {
    enum Fate {
        case carried
        case dropped
        /// Carried, its elements held by their own register below.
        case recursed
    }

    static let snapshotFields: [String: (Fate, String)] = [
        "windows": (.recursed, "the paired windows, re-keyed"),
        "spaces": (.recursed, "the Space records, re-keyed"),
        "activeSpace": (.carried, "a Space id, not a window's"),
        "capturedAt": (.carried, "when the arrangement was live"),
        "arrangement": (.carried, "whose Spaces the modes are (#1646)"),
        "arrangementRecords":
            (.dropped, "the #1230 records name only old ids"),
        "loginSession": (.dropped, "the gate's stamp; read already"),
        "frozenForLogout": (.dropped, "the file's mark; read already"),
    ]

    static let spaceFields: [String: (Fate, String)] = [
        "id": (.carried, "a Space id"),
        "mode": (.carried, "the layout the Space had"),
        "windows": (.carried, "membership and order, re-keyed"),
        "focused": (.carried, "re-keyed when its window paired"),
        "trackBreaks": (.carried, "re-keyed; unpaired breaks drop"),
        "trackWeights": (.carried, "re-keyed; unpaired heads drop"),
        "session": (.dropped, "in-place sizing never crosses a boot"),
        "held": (.dropped, "a hold names old ids; held Spaces stay"),
        "temporary": (.dropped, "temporary Spaces are not re-created"),
        "pending": (.dropped, "old ids of windows never seen"),
    ]

    static let windowFields: [String: (Fate, String)] = [
        "id": (.carried, "re-keyed to the live window"),
        "frame": (.carried, "where the window was"),
        "app": (.carried, "the stable key"),
        "title": (.carried, "the stable key"),
        "session": (.dropped, "in-place flags never cross a boot"),
        "floating": (.carried, "a stop's hand float crosses (#1864)"),
    ]

    private static let frame = CGRect(x: 1, y: 2, width: 3, height: 4)

    /// Every field away from its default.
    private func full() -> StateSnapshot {
        let w = WindowID(7)
        var space = StateSnapshot.SpaceRecord(
            space: Space(
                id: "3",
                mode: .track,
                windows: [w],
                focused: w,
                trackBreaks: [w],
                trackWeights: [w: 1.5]
            ),
            session: .init(space: Space(id: "3"), monocleShown: w),
            held: .init(
                origin: HeldOrigin(
                    name: "3",
                    screen: "S:1x1",
                    icon: nil,
                    arrangement: nil
                ),
                remembered: [WindowID(9)]
            ),
            temporary: .init(armed: true),
            pending: [WindowID(9)]
        )
        space.temporary = .init(armed: true, pin: "S:1x1")
        var snapshot = StateSnapshot(
            windows: [
                .init(
                    id: w,
                    frame: Self.frame,
                    session: .init(
                        sticky: .none,
                        stickyReach: true
                    ),
                    app: "com.a",
                    title: "A",
                    floating: true
                )
            ],
            spaces: [space],
            activeSpace: "3",
            capturedAt: Date(timeIntervalSince1970: 5),
            arrangement: .profile("P")
        )
        snapshot.arrangementRecords = .init([.profile("P"): ["3": [w]]])
        snapshot.loginSession = 4
        snapshot.frozenForLogout = true
        return snapshot
    }

    private func fields(_ value: Any) -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: value).children
                .compactMap { child in
                    child.label.map { ($0, String(describing: child.value)) }
                }
        )
    }

    /// Carried fields equal the original under the identity map;
    /// dropped ones equal the type's default.
    private func check(
        _ register: [String: (Fate, String)],
        original: Any,
        rekeyed: Any,
        blank: Any
    ) {
        let before = fields(original)
        let after = fields(rekeyed)
        let empty = fields(blank)
        #expect(Set(before.keys) == Set(register.keys))
        for (label, (fate, _)) in register where fate != .recursed {
            let expected = fate == .carried ? before[label] : empty[label]
            #expect(after[label] == expected, "\(label) is not \(fate)")
            if fate == .dropped {
                #expect(before[label] != empty[label], "\(label) unset")
            }
        }
    }

    @Test("every stored field is carried or dropped as classified")
    func everyFieldIsClassified() throws {
        let original = full()
        let w = WindowID(7)
        let rekeyed = original.rekeyed([w: w])
        check(
            Self.snapshotFields,
            original: original,
            rekeyed: rekeyed,
            blank: StateSnapshot(windows: [], spaces: [], activeSpace: nil)
        )
        check(
            Self.spaceFields,
            original: original.spaces[0],
            rekeyed: try #require(rekeyed.spaces.first),
            blank: StateSnapshot.SpaceRecord(space: Space(id: "3"))
        )
        check(
            Self.windowFields,
            original: original.windows[0],
            rekeyed: try #require(rekeyed.windows.first),
            blank: StateSnapshot.WindowRecord(id: w, frame: Self.frame)
        )
    }

    /// The carried id fields take the LIVE id, and an unpaired id
    /// leaves every one of them.
    @Test("carried ids are re-keyed and unpaired ones dropped")
    func idsAreRekeyed() throws {
        let old = WindowID(7)
        let live = WindowID(70)
        var snapshot = full()
        let other = WindowID(8)
        snapshot.spaces[0] = .init(
            space: Space(
                id: "3",
                mode: .track,
                windows: [old, other],
                focused: old,
                trackBreaks: [old, other],
                trackWeights: [old: 1.5, other: 2]
            )
        )
        let space = try #require(snapshot.rekeyed([old: live]).spaces.first)
        #expect(space.windows == [live.raw])
        #expect(space.focused == live.raw)
        #expect(space.trackBreaks == [live.raw])
        #expect(space.trackWeights == [live.raw: 1.5])
        #expect(snapshot.rekeyed([old: live]).windows.map(\.id) == [live.raw])
    }
}
