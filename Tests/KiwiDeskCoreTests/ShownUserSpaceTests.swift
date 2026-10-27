import Testing

@testable import KiwiDeskCore

/// The shelf's stand-down reads the user-Space verdict the last
/// Desktop reading filed, not two WindowServer round trips per bar
/// pass (#2667): filed at boot and at every Desktop switch's head,
/// dropped at a display change, and read live for a screen no
/// reading named.
@Suite("Shown user-Space verdict")
@MainActor
struct ShownUserSpaceTests {
    /// MAIN shows a fullscreen Space, SIDE a Desktop.
    private func snapshot() -> DesktopSnapshot {
        DesktopSnapshot(
            authority: nil,
            mainUUID: "MAIN",
            mainCurrentSpace: 9,
            currentSpaces: ["MAIN": 9, "SIDE": 7],
            spaces: [
                NativeSpace(id: 1, displayUUID: "MAIN", isCurrent: false),
                NativeSpace(
                    id: 9,
                    displayUUID: "MAIN",
                    isCurrent: true,
                    isUser: false
                ),
                NativeSpace(id: 7, displayUUID: "SIDE", isCurrent: true),
            ]
        )
    }

    @Test("a reading files each screen's verdict")
    func readingFilesVerdicts() {
        #expect(
            snapshot().currentSpacesAreUser == ["MAIN": false, "SIDE": true]
        )
        let memory = DesktopMemory()
        memory.seed(snapshot())
        #expect(memory.shownUserSpaces == ["MAIN": false, "SIDE": true])
        #expect(memory.shownSpaces == ["MAIN": 9, "SIDE": 7])
    }

    @Test("a filed verdict answers without the live read")
    func filedAnswers() {
        var reads = 0
        let filed = ["MAIN": false]
        let answer = NativeSpaces.spaceIsUser(on: "MAIN", filed: filed) {
            _ in
            reads += 1
            return true
        }
        #expect(answer == false)
        #expect(reads == 0)
    }

    /// Shared Spaces key the one managed display by a synthetic
    /// id; its lone entry answers every screen.
    @Test("a lone shared-Spaces entry answers the screen")
    func sharedEntryAnswers() {
        var reads = 0
        let filed = ["Main": false]
        let answer = NativeSpaces.spaceIsUser(on: "REAL", filed: filed) {
            _ in
            reads += 1
            return true
        }
        #expect(answer == false)
        #expect(reads == 0)
    }

    /// Separate Spaces with one screen filed: another screen's
    /// verdict never answers for the screen just connected.
    @Test("a lone screen's entry never answers another screen")
    func loneScreenEntryReadsLive() {
        var reads = 0
        let filed = ["37D8832A-2D66-02CA-B9F7-8F30A301B230": false]
        let answer = NativeSpaces.spaceIsUser(
            on: "0E9A8D21-1D1C-4D51-A7B5-3C0B1F0D9E11",
            filed: filed
        ) { _ in
            reads += 1
            return true
        }
        #expect(answer)
        #expect(reads == 1)
    }

    @Test("a screen no reading named reads live")
    func missReadsLive() {
        var asked: [String] = []
        let filed = ["A": true, "B": true]
        let answer = NativeSpaces.spaceIsUser(on: "NEW", filed: filed) {
            asked.append($0)
            return false
        }
        #expect(answer == false)
        #expect(asked == ["NEW"])
    }

    @Test("an unknown screen stays a user Space")
    func unknownScreen() {
        var reads = 0
        let answer = NativeSpaces.spaceIsUser(on: nil, filed: [:]) { _ in
            reads += 1
            return false
        }
        #expect(answer)
        #expect(reads == 0)
    }

    @Test("a display change drops the filed verdicts")
    func displayChangeDrops() {
        let core = makeTestCore()
        core.desktopMemory.fileShown(snapshot())
        #expect(!core.desktopMemory.shownUserSpaces.isEmpty)
        core.handle(.displaysChanged([]))
        #expect(core.desktopMemory.shownUserSpaces.isEmpty)
    }
}
