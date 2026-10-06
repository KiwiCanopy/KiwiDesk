import CoreFoundation
import CoreGraphics
import Darwin

/// Process-lifetime WindowServer notification pump for focus
/// borders (#285 Tier 2). Registration has no reliable public
/// unregister seam, so callbacks never retain a `BorderManager`;
/// the current manager is a weak sink replaceable after an
/// in-process stop/start.
@MainActor
final class SkyLightWindowEvents {
    enum Kind: UInt32, CaseIterable {
        case close = 804
        case move = 806
        case resize = 807
        case reorder = 808
        case level = 811
        case unhide = 815
        case hide = 816

        var action: Action {
            switch self {
            case .move, .resize:
                return .follow
            case .reorder, .level:
                return .reorder
            case .unhide:
                return .followAndReorder
            case .hide, .close:
                return .hide
            }
        }

        /// Geometry events coalesce with an adjacent one for the
        /// same window; control events never do, so their order
        /// against geometry is preserved.
        var isGeometry: Bool {
            self == .move || self == .resize
        }
    }

    enum Action: Equatable {
        case follow
        case reorder
        case followAndReorder
        case hide
    }

    typealias RequestNotificationsFn =
        @convention(c) (
            SkyLight.ConnectionID,
            UnsafeMutablePointer<CGWindowID>?,
            Int32
        ) -> CGError

    static let shared: SkyLightWindowEvents? = SkyLightWindowEvents()
    private static weak var active: SkyLightWindowEvents?

    private static let requestNotifications: RequestNotificationsFn? =
        SkyLight.symbol(
            "SLSRequestNotificationsForWindows",
            as: RequestNotificationsFn.self
        )

    private weak var manager: BorderManager?
    private let connection: SkyLight.ConnectionID
    private var lastRequested: Set<WindowID>?
    private lazy var deliveryQueue = SkyLightWindowEventQueue {
        [weak self] event in
        self?.manager?.handleSkyLightEvent(
            event.kind,
            window: event.window
        )
    }

    private init?() {
        guard let port = SkyLightEventPort.shared,
            SkyLight.getWindowBounds != nil,
            Self.requestNotifications != nil
        else { return nil }
        for kind in Kind.allCases {
            guard
                port.register(
                    code: kind.rawValue,
                    skyLightWindowNotifyCallback
                )
            else { return nil }
        }
        connection = port.connection
        Self.active = self
        port.observeDrain(
            begin: { [weak self] in self?.deliveryQueue.beginDrain() },
            end: { [weak self] in self?.deliveryQueue.endDrain() }
        )
    }

    func attach(_ manager: BorderManager) {
        self.manager = manager
    }

    /// Requests notifications for these windows. The private API's
    /// replacement-vs-additive semantics are undocumented; stale
    /// deliveries are dropped by the manager, and an empty request
    /// is a best-effort clear, not a teardown guarantee.
    func watch(_ windows: Set<WindowID>) -> Bool {
        if lastRequested == windows { return true }
        guard let request = Self.requestNotifications else {
            return false
        }
        var ids = windows.map(\.raw)
        if ids.isEmpty {
            let success = request(connection, nil, 0) == .success
            if success { lastRequested = windows }
            return success
        }
        let success = ids.withUnsafeMutableBufferPointer { buffer in
            request(
                connection,
                buffer.baseAddress,
                Int32(buffer.count)
            ) == .success
        }
        if success { lastRequested = windows }
        return success
    }

    fileprivate static func deliver(
        code: UInt32,
        window: CGWindowID
    ) {
        guard let kind = Kind(rawValue: code) else { return }
        Self.active?.deliveryQueue.enqueue(
            kind,
            window: WindowID(window)
        )
    }
}

private let skyLightWindowNotifyCallback: SkyLightEventPort.NotifyProc = {
    event,
    data,
    length,
    _ in
    guard let data,
        length >= MemoryLayout<CGWindowID>.size
    else { return }
    // Copy before returning to SkyLight: the payload storage is
    // owned by the event currently being drained.
    let window = data.loadUnaligned(as: CGWindowID.self)
    let send: @MainActor @Sendable () -> Void = {
        SkyLightWindowEvents.deliver(
            code: event,
            window: window
        )
    }
    if pthread_main_np() != 0 {
        MainActor.assumeIsolated { send() }
    } else {
        DispatchQueue.main.async(execute: send)
    }
}
