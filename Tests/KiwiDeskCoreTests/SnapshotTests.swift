import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("StateSnapshot")
struct SnapshotTests {
    private func populatedState() -> StateCoordinator {
        var state = StateCoordinator(defaultSpace: "code")
        state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 100,
                    appName: "Editor",
                    frame: CGRect(
                        x: 0,
                        y: 0,
                        width: 800,
                        height: 600
                    )
                )
            )
        )
        state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(2),
                    pid: 200,
                    appName: "Browser",
                    frame: CGRect(
                        x: 800,
                        y: 0,
                        width: 640,
                        height: 480
                    )
                )
            )
        )
        return state
    }

    @Test("Snapshot captures windows, spaces, and focus")
    func captureContents() {
        let snapshot = populatedState().snapshot()
        #expect(snapshot.windows.count == 2)
        #expect(snapshot.spaces.count == 1)
        #expect(snapshot.activeSpace == "code")
        let space = snapshot.spaces[0]
        #expect(space.windows == [1, 2])
        #expect(space.focused == 2)
        let first = snapshot.windows.first { $0.id == 1 }
        #expect(first?.frame.width == 800)
    }

    @Test("Snapshot survives a Codable round-trip")
    func codableRoundTrip() throws {
        let original = populatedState().snapshot()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            StateSnapshot.self,
            from: data
        )
        #expect(decoded == original)
    }

    @Test("Window record exposes a typed WindowID")
    func typedWindowID() {
        let record = StateSnapshot.WindowRecord(
            id: WindowID(7),
            frame: .zero
        )
        #expect(record.windowID == WindowID(7))
    }
}
