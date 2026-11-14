import Foundation
import Testing

@testable import KiwiDeskCore

/// The `MTTouch` record read (#1873): the touching states, the
/// buffer's end, and positions off the pad.
@Suite("Touch frame parse")
struct TouchFrameParseTests {
    private func record(
        id: Int32,
        state: Int32,
        x: Float,
        y: Float
    ) -> [UInt8] {
        var bytes = [UInt8](
            repeating: 0,
            count: MultitouchSupport.Layout.stride
        )
        func put<T>(_ value: T, at offset: Int) {
            withUnsafeBytes(of: value) { raw in
                for (index, byte) in raw.enumerated() {
                    bytes[offset + index] = byte
                }
            }
        }
        put(id, at: MultitouchSupport.Layout.identifier)
        put(state, at: MultitouchSupport.Layout.state)
        put(x, at: MultitouchSupport.Layout.x)
        put(y, at: MultitouchSupport.Layout.y)
        return bytes
    }

    @Test("touching records parse; hovering ones and overruns drop")
    func parses() {
        let bytes =
            record(id: 7, state: 4, x: 0.25, y: 0.75)
            + record(id: 8, state: 2, x: 0.5, y: 0.5)
            + record(id: 9, state: 3, x: 0.1, y: 0.2)
        let contacts = bytes.withUnsafeBytes {
            MultitouchSupport.contacts(in: $0, count: 4)
        }
        #expect(
            contacts == [
                TouchContact(id: 7, x: 0.25, y: 0.75),
                TouchContact(id: 9, x: 0.1, y: 0.2),
            ]
        )
    }

    @Test("a position off the pad is garbage and dropped")
    func offPadDrops() {
        let bytes =
            record(id: 1, state: 4, x: .nan, y: 0.5)
            + record(id: 2, state: 4, x: 0.5, y: 7)
            + record(id: 3, state: 4, x: -0.2, y: 0.5)
            + record(id: 4, state: 4, x: 1.05, y: -0.05)
        let contacts = bytes.withUnsafeBytes {
            MultitouchSupport.contacts(in: $0, count: 4)
        }
        #expect(contacts.map(\.id) == [4])
    }
}
