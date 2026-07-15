import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// #222 arrangement geometry: the stack position decides the
/// split axis and the stack zone's lineup (left/right → a
/// vertical column, top/bottom → a horizontal row); the master
/// zone lines up along its own `master_orientation`. Piles keep
/// cascading downward regardless.
private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)

private func makeContext(
    stack: (inout StackParams) -> Void = { _ in }
) -> LayoutContext {
    var context = LayoutContext(
        bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        gaps: .uniform(10)
    )
    stack(&context.stack)
    return context
}

@Suite("Stack arrangement (#222)")
struct StackArrangementTests {
    let layout = StackLayout()

    @Test("stack_position left mirrors the split")
    func positionLeft() throws {
        let context = makeContext {
            $0.stackPosition = .left
        }
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        let master = try #require(frames[w1])
        let stack = try #require(frames[w2])
        // available = 1900 - 10 gap = 1890
        #expect(stack.minX == context.usable.minX)
        #expect(abs(stack.width - 1890 * 0.4) < 0.01)
        #expect(abs(master.minX - stack.maxX - 10) < 0.01)
        #expect(abs(master.width - 1890 * 0.6) < 0.01)
        #expect(master.height == context.usable.height)
        #expect(stack.height == context.usable.height)
    }

    @Test("stack_position top splits the height, stack first")
    func positionTop() throws {
        let context = makeContext {
            $0.stackPosition = .top
        }
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        let master = try #require(frames[w1])
        let stack = try #require(frames[w2])
        // available = 1060 - 10 gap = 1050
        #expect(stack.minY == context.usable.minY)
        #expect(abs(stack.height - 1050 * 0.4) < 0.01)
        #expect(abs(master.minY - stack.maxY - 10) < 0.01)
        #expect(abs(master.height - 1050 * 0.6) < 0.01)
        #expect(master.width == context.usable.width)
        #expect(stack.width == context.usable.width)
    }

    @Test("stack_position bottom keeps the master on top")
    func positionBottom() throws {
        let context = makeContext {
            $0.stackPosition = .bottom
        }
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        let master = try #require(frames[w1])
        let stack = try #require(frames[w2])
        #expect(master.minY == context.usable.minY)
        #expect(abs(master.height - 1050 * 0.6) < 0.01)
        #expect(abs(stack.minY - master.maxY - 10) < 0.01)
    }

    @Test("A top/bottom stack zone lines up side by side")
    func wideStackIsARow() throws {
        let context = makeContext {
            $0.stackPosition = .top
        }
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let first = try #require(frames[w2])
        let second = try #require(frames[w3])
        #expect(first.minY == second.minY)
        #expect(first.height == second.height)
        #expect(abs(second.minX - first.maxX - 10) < 0.01)
        #expect(abs(first.width - second.width) < 0.01)
    }

    @Test("A left/right stack zone stays a vertical column")
    func tallStackIsAColumn() throws {
        let context = makeContext {
            $0.stackPosition = .left
        }
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let first = try #require(frames[w2])
        let second = try #require(frames[w3])
        #expect(first.minX == second.minX)
        #expect(first.width == second.width)
        #expect(abs(second.minY - first.maxY - 10) < 0.01)
    }

    @Test("master_orientation horizontal lines masters up")
    func horizontalMasters() throws {
        let context = makeContext {
            $0.masterCount = 2
            $0.masterOrientation = .horizontal
        }
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let first = try #require(frames[w1])
        let second = try #require(frames[w2])
        #expect(first.minY == second.minY)
        #expect(first.height == second.height)
        #expect(abs(second.minX - first.maxX - 10) < 0.01)
        #expect(abs(first.width - second.width) < 0.01)
        // The stack column is untouched on the right.
        let stack = try #require(frames[w3])
        #expect(abs(stack.maxX - context.usable.maxX) < 0.01)
    }

    @Test("Master-only spaces honor the orientation too")
    func masterOnlyRow() throws {
        let context = makeContext {
            $0.masterCount = 2
            $0.masterOrientation = .horizontal
        }
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        let first = try #require(frames[w1])
        let second = try #require(frames[w2])
        #expect(first.minX == context.usable.minX)
        #expect(abs(second.maxX - context.usable.maxX) < 0.01)
        #expect(first.height == context.usable.height)
        #expect(abs(second.minX - first.maxX - 10) < 0.01)
    }

    @Test("Stack weights apply along the zone's own axis")
    func weightsFollowTheAxis() throws {
        var context = makeContext {
            $0.stackPosition = .top
        }
        context.stackWeights[w2] = 2
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let heavy = try #require(frames[w2])
        let light = try #require(frames[w3])
        #expect(abs(heavy.width - 2 * light.width) < 0.01)
        #expect(heavy.height == light.height)
    }

    @Test("A wide zone's overflow pile still cascades downward")
    func widePileIsVertical() throws {
        var context = makeContext {
            $0.stackPosition = .top
        }
        context.minWindowSize = 400
        // 1 master + 10 stack windows: a 1900 pt row fits 3
        // tiled 400 pt windows plus the pile strip; the other
        // 7 pile downward at the row's trailing end.
        let windows = (1...11).map { WindowID(UInt32($0)) }
        let frames = layout.calculateGeometry(
            for: windows,
            in: context
        )
        let buried = try #require(frames[WindowID(10)])
        let front = try #require(frames[WindowID(11)])
        #expect(buried.minX == front.minX)
        #expect(buried.width == front.width)
        #expect(abs(front.minY - buried.minY - 40) < 0.01)
    }
}

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return KiwiCore(configDirectory: directory)
}

@Suite("Stack arrangement commands (#222)", .serialized)
@MainActor
struct StackArrangementCommandTests {
    @Test("set_master_orientation updates and validates")
    func masterOrientation() {
        let core = makeCore()
        #expect(
            core.execute(
                "stack.set_master_orientation",
                args: [.string("horizontal")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.stack.masterOrientation
                == .horizontal
        )
        #expect(
            !core.execute(
                "stack.set_master_orientation",
                args: [.string("diagonal")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.stack.masterOrientation
                == .horizontal
        )
    }

    @Test("set_stack_position updates and validates")
    func stackPosition() {
        let core = makeCore()
        #expect(
            core.execute(
                "stack.set_stack_position",
                args: [.string("bottom")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.stack.stackPosition == .bottom
        )
        #expect(
            !core.execute(
                "stack.set_stack_position",
                args: [.string("center")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.stack.stackPosition == .bottom
        )
    }

    @Test("Arrangement overrides write only their space")
    func arrangementOverrides() {
        let core = makeCore()
        #expect(
            core.execute(
                "stack.set_master_orientation_override",
                args: [.string("3"), .string("horizontal")]
            ).isSuccess
        )
        #expect(
            core.execute(
                "stack.set_stack_position_override",
                args: [.string("3"), .string("left")]
            ).isSuccess
        )
        let over = core.tiler.settings.stack.override[SpaceID("3")]
        #expect(over?.masterOrientation == .horizontal)
        #expect(over?.stackPosition == .left)
        // Globals stay at their defaults.
        #expect(
            core.tiler.settings.stack.masterOrientation
                == .vertical
        )
        #expect(
            core.tiler.settings.stack.stackPosition == .right
        )
        // Bad values are rejected without writing.
        #expect(
            !core.execute(
                "stack.set_stack_position_override",
                args: [.string("4"), .string("middle")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.stack.override[SpaceID("4")]
                == nil
        )
    }
}
