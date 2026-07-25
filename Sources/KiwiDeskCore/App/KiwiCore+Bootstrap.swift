import AppKit
import Foundation

extension KiwiCore {
    /// Wires core subsystems, event callbacks, and service
    /// integrations during initialization (#415 architect follow-up).
    func bootstrapCoreServices() {
        crash.captureState = { [weak self] in
            self?.state.snapshot()
        }
        crash.restoreState = { [weak self] snapshot in
            self?.restore(snapshot)
        }
        crash.onLog = { [weak self] message in
            self?.onLog(message)
        }
        keys.onLog = { [weak self] message in
            self?.onLog(message)
        }
        exec.onLog = { [weak self] message in
            self?.onLog(message)
        }
        profiles.onLog = { [weak self] message in
            self?.onLog(message)
        }
        borders.onLog = { [weak self] message in
            self?.onLog(message)
        }
        wireDrag()
        appBars.onSelect = { [weak self] id in
            self?.focusWindow(id, warp: true)
        }
        spaceBars.onSelectSpace = { [weak self] id in
            _ = self?.focusSpace([.string(id.raw)])
        }
        appFont.onLoad = { [weak self] in
            self?.updateAppBar()
            self?.updateSpaceBar()
        }
        appBars.onMove = { [weak self] space, from, to in
            self?.moveBarItem(space: space, from: from, to: to)
        }
        tiler.animation.onAllAnimationsEnded = { [weak self] in
            self?.animationsDidSettle()
        }
        tiler.onFrameApplied = { [weak self] id, frame in
            self?.borders.follow(id, windowFrame: frame)
            self?.stickyMarks
                .follow(id, windowFrame: frame)
        }

        socket.handler = { [weak self] command, args in
            self?.execute(command, args: args)
                ?? .fail("core unavailable")
        }
        socket.bus = bus
        tiler.elementProvider = { [weak self] id in
            self?.eventLoop.element(for: id)
        }
        eventLoop.onEvent = { [weak self] event in
            self?.handle(event)
        }
        eventLoop.onIgnoredPanelFocus = { [weak self] pid in
            self?.ignoredPanelActive.insert(pid)
        }
        sleepWake.captureState = { [weak self] in
            self?.state.snapshot()
        }
        sleepWake.restoreState = { [weak self] snapshot in
            self?.restore(snapshot)
        }
        bus.onLog = { [weak self] message in
            self?.onLog(message)
        }
    }
}
