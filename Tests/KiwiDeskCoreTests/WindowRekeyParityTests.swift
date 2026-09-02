import CoreGraphics
import Testing

@testable import KiwiDeskCore

// Forget-proof guard for the WindowID-keyed map list the native-tab
// re-key must migrate (#308, AGENTS.md §5 mirror rule).
// `StateCoordinator.rekey` and `Space.rekey` each hand-enumerate
// every id-keyed container; forgetting one is silent data loss.
// These tests DISCOVER those containers by reflection: a full-state
// scan proves the re-key leaves no reference to the old id (and adds
// the new one), and a count pin fails red when a container is added
// to the fixture without being migrated.
//
// Two limitations, per the parity-test rule. Reflection can only see
// a map once it holds an entry, so an added-but-unpopulated map is
// not caught here — the behavioral `WindowRekeyTests` are the
// round-trip backing that a populated map is actually swapped. And
// `windowContainers` does not recurse into collection *elements*, so
// a container whose element WRAPS the id in a struct
// (`minimizeOrder`, #673) never reaches the count pin — nor does a
// bare id sitting in a struct rather than in any container at all
// (`scrollRest.slot.window`, #966). Only the `String(describing:)`
// scan sees those, because it renders the nested `WindowID` — so
// `rekeyMigratesMinimized` and the fixture's `scrollRest` are their
// net here, and the count is not.

private let old = WindowID(9001)
private let new = WindowID(9002)

private func window(_ id: WindowID) -> ManagedWindow {
    ManagedWindow(id: id, pid: 7, appName: "App", title: "T")
}

/// A coordinator with the old id populating every WindowID-keyed
/// container reachable from `StateCoordinator` and its spaces.
/// `minimizeOrder` is excluded on purpose: a live tracked window is
/// never also minimized, so that container is covered by its own
/// test below.
private func trackedFixture() -> StateCoordinator {
    var state = StateCoordinator(defaultSpace: SpaceID(1))
    state.apply(.windowCreated(window(WindowID(1))))
    state.apply(.windowCreated(window(old)))
    state.workspaces.withSpace(SpaceID(1)) { space in
        space.stackWeights[old] = 2.0
        space.trackBreaks.insert(old)
        space.trackWeights[old] = 1.5
        // Not a container — a bare id inside a struct (#966), so
        // the count pin below cannot see it and the
        // `String(describing:)` scan is its only net.
        space.scrollRest = ScrollRest(
            offset: -400,
            focus: old,
            position: 800,
            restingOn: nil
        )
    }
    state.setFloating(old, true)
    state.remember(old, in: SpaceID(1))
    state.stickyReachOverrides[old] = true
    state.departedSlots[old] = 0
    return state
}

/// The number of WindowID-keyed containers `trackedFixture`
/// populates: `WindowManager.windows`, `rememberedSpaces`,
/// `manualFloatOverrides`, `stickyReachOverrides` (#1145),
/// `departedSlots` (#1207), plus
/// each space's `windows`, `stackWeights`, `trackBreaks`,
/// `trackWeights`. Bumping the fixture with a new id-keyed map
/// must bump this — and then the scan test forces the re-key to
/// clear it. The fixture's `scrollRest` is deliberately NOT
/// counted: it holds a bare id, not a container, so reflection
/// never renders it here (see the limitations above).
private let expectedContainerCount = 9

/// `String(describing:)` of every non-empty dictionary, set, or
/// array whose keys/elements are `WindowID`, reachable by recursing
/// structs, classes, optionals, and dictionary *values* (so the
/// per-space maps inside `WorkspaceManager` are found). Empty
/// containers are skipped — their element type cannot be read.
private func windowContainers(
    _ value: Any,
    depth: Int = 8
) -> [String] {
    guard depth > 0 else { return [] }
    let mirror = Mirror(reflecting: value)
    switch mirror.displayStyle {
    case .dictionary:
        var found: [String] = []
        if firstKeyIsWindowID(mirror) {
            found.append(String(describing: value))
        }
        for child in mirror.children {
            let pair = Array(Mirror(reflecting: child.value).children)
            if let entryValue = pair.last?.value {
                found += windowContainers(entryValue, depth: depth - 1)
            }
        }
        return found
    case .set, .collection:
        return firstElementIsWindowID(mirror)
            ? [String(describing: value)] : []
    case .optional, .struct, .class, .tuple, .enum:
        return mirror.children.flatMap {
            windowContainers($0.value, depth: depth - 1)
        }
    default:
        return []
    }
}

private func firstKeyIsWindowID(_ mirror: Mirror) -> Bool {
    guard let first = mirror.children.first else { return false }
    let pair = Mirror(reflecting: first.value)
    return pair.children.first?.value is WindowID
}

private func firstElementIsWindowID(_ mirror: Mirror) -> Bool {
    mirror.children.first?.value is WindowID
}

@Suite("Window re-key map parity (#308)")
struct WindowRekeyParityTests {
    private func hasOld(_ state: StateCoordinator) -> Bool {
        String(describing: state).contains(old.description)
    }

    private func hasNew(_ state: StateCoordinator) -> Bool {
        String(describing: state).contains(new.description)
    }

    @Test("the fixture populates every discoverable id-keyed map")
    func fixtureCoversEveryContainer() {
        let containers = windowContainers(trackedFixture())
        #expect(containers.count == expectedContainerCount)
        // Every discovered container holds the old id — a new map
        // the fixture forgot would show up without it.
        #expect(
            containers.allSatisfy { $0.contains(old.description) }
        )
    }

    @Test("re-key clears the old id from every container")
    func rekeyClearsOld() {
        var state = trackedFixture()
        #expect(hasOld(state))
        state.apply(.windowRekeyed(old, new))
        let containers = windowContainers(state)
        #expect(!hasOld(state))
        #expect(hasNew(state))
        #expect(containers.count == expectedContainerCount)
        #expect(
            containers.allSatisfy { !$0.contains(old.description) }
        )
        #expect(
            containers.allSatisfy { $0.contains(new.description) }
        )
    }

    @Test("re-key migrates the minimize record too")
    func rekeyMigratesMinimized() {
        var state = StateCoordinator(defaultSpace: SpaceID(1))
        state.apply(.windowCreated(window(WindowID(1))))
        state.apply(.windowCreated(window(old)))
        // A minimize-destroy files old into `minimizeOrder` and
        // drops it from the space, so this exercises the one
        // container the tracked fixture cannot hold — and the one
        // the count pin above cannot see (struct element).
        state.apply(.windowDestroyed(old, wasMinimized: true))
        #expect(hasOld(state))
        state.apply(.windowRekeyed(old, new))
        #expect(!hasOld(state))
        #expect(hasNew(state))
    }
}
