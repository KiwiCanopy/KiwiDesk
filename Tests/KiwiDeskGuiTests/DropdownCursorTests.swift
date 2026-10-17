import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A searchable dropdown's one cursor (owner ruling 2026-10-17):
/// the pointer moves it only by real motion — a row sliding under
/// a still pointer, the list opening there, a re-filter or a
/// scroll takes nothing (#2229's rule) — the keys take it back,
/// and leaving the list keeps it so Return has a target. Pure, so
/// it runs off the main actor.
@Suite("Dropdown cursor")
struct DropdownCursorTests {
    private let rest = CGPoint(x: 10, y: 10)
    private let moved = CGPoint(x: 10, y: 30)
    private let ids = ["a", "b", "c"]

    private func opened() -> DropdownCursor<String> {
        var cursor = DropdownCursor<String>()
        cursor.opened(at: "a", pointer: rest)
        return cursor
    }

    @Test("the open seeds the start, never the row under the pointer")
    func openSeeds() {
        var cursor = opened()
        #expect(cursor.highlighted == "a")
        // The row under the resting pointer hears it at once.
        cursor.hover("c", pointer: rest)
        #expect(cursor.highlighted == "a")
    }

    @Test("a moved pointer takes the cursor, a still one takes none")
    func movementOnly() {
        var cursor = opened()
        cursor.hover("b", pointer: moved)
        #expect(cursor.highlighted == "b")
        // A scroll slides another row under the same pointer.
        cursor.hover("c", pointer: moved)
        #expect(cursor.highlighted == "b")
    }

    @Test("a key move then a still hover keeps the key's row")
    func keyTakesItBack() {
        var cursor = opened()
        cursor.hover("b", pointer: moved)
        // The hand moved off the rows, then pressed ↓: the key
        // records where it rests now.
        let off = CGPoint(x: 200, y: 5)
        #expect(cursor.keyMove(1, in: ids, pointer: off) == "c")
        cursor.hover("a", pointer: off)
        #expect(cursor.highlighted == "c")
        cursor.hover("a", pointer: CGPoint(x: 11, y: 30))
        #expect(cursor.highlighted == "a")
    }

    @Test("keys step from the cursor and stop at the ends")
    func keySteps() {
        var cursor = opened()
        #expect(cursor.keyMove(-1, in: ids, pointer: rest) == "a")
        #expect(cursor.keyMove(1, in: ids, pointer: rest) == "b")
        #expect(cursor.keyMove(1, in: ids, pointer: rest) == "c")
        #expect(cursor.keyMove(1, in: ids, pointer: rest) == "c")
        var empty = DropdownCursor<String>()
        #expect(empty.keyMove(1, in: [], pointer: rest) == nil)
        #expect(empty.keyMove(-1, in: ids, pointer: rest) == "c")
    }

    @Test("a query edit resets the cursor and hands it to the keyboard")
    func queryResets() {
        var cursor = opened()
        cursor.hover("c", pointer: moved)
        // Typed with the pointer resting off the rows.
        let off = CGPoint(x: 200, y: 5)
        cursor.reset(to: "b", pointer: off)
        #expect(cursor.highlighted == "b")
        // The re-filtered rows slide under the still pointer.
        cursor.hover("a", pointer: off)
        #expect(cursor.highlighted == "b")
    }

    @Test("leaving the list keeps the cursor for Return")
    func leavingKeeps() {
        var cursor = opened()
        cursor.hover("b", pointer: moved)
        // The pointer leaves for the field: no row hears it.
        #expect(
            cursor.commit(in: ids, pointer: CGPoint(x: 200, y: 5)) == "b"
        )
        #expect(cursor.highlighted == "b")
    }

    @Test("Return re-records the pointer and picks only a listed row")
    func commitRecords() {
        var cursor = opened()
        #expect(cursor.commit(in: ["b"], pointer: moved) == nil)
        cursor.hover("b", pointer: moved)
        #expect(cursor.highlighted == "a")
    }

    @Test("the app picker's escape joins the sequence after the apps")
    func escapeIsReachable() {
        let lists: AppPickerSlot.Lists = (
            onScreen: [
                OnScreenApp(
                    app: AppRef(bundleID: "com.x", name: "X"),
                    name: "X"
                )
            ],
            all: [.init(bundleID: "com.y", name: "Y")]
        )
        let sequence = AppPickerSlot.sequence(of: lists)
        #expect(
            sequence == [
                .onScreen(lists.onScreen[0].key),
                .installed("com.y"), .escape,
            ]
        )
        #expect(AppPickerSlot.firstApp(of: lists) == sequence[0])
        var cursor = DropdownCursor<AppPickerSlot>()
        cursor.opened(at: sequence[0], pointer: rest)
        cursor.keyMove(1, in: sequence, pointer: rest)
        #expect(cursor.keyMove(1, in: sequence, pointer: rest) == .escape)
        let none: AppPickerSlot.Lists = (onScreen: [], all: [])
        #expect(AppPickerSlot.firstApp(of: none) == nil)
        #expect(AppPickerSlot.sequence(of: none) == [.escape])
    }
}
