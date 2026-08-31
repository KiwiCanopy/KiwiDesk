import CoreFoundation
import CoreGraphics

/// Window corner radius dynamic query via SkyLight SPI (#357).
extension SkyLight {
    typealias WindowQueryWindowsFn =
        @convention(c) (
            ConnectionID, CFArray, Int32
        ) -> Unmanaged<CFTypeRef>?
    typealias QueryResultCopyWindowsFn =
        @convention(c) (CFTypeRef) -> Unmanaged<CFTypeRef>?
    typealias IteratorGetCountFn =
        @convention(c) (CFTypeRef) -> Int32
    typealias IteratorAdvanceFn =
        @convention(c) (CFTypeRef) -> Bool
    typealias IteratorGetCornerRadiiFn =
        @convention(c) (CFTypeRef) -> Unmanaged<CFArray>?

    static let windowQueryWindows: WindowQueryWindowsFn? = symbol(
        "SLSWindowQueryWindows",
        as: WindowQueryWindowsFn.self
    )
    static let queryResultCopyWindows: QueryResultCopyWindowsFn? =
        symbol(
            "SLSWindowQueryResultCopyWindows",
            as: QueryResultCopyWindowsFn.self
        )
    static let iteratorGetCount: IteratorGetCountFn? = symbol(
        "SLSWindowIteratorGetCount",
        as: IteratorGetCountFn.self
    )
    static let iteratorAdvance: IteratorAdvanceFn? = symbol(
        "SLSWindowIteratorAdvance",
        as: IteratorAdvanceFn.self
    )
    static let iteratorGetCornerRadii: IteratorGetCornerRadiiFn? =
        symbol(
            "SLSWindowIteratorGetCornerRadii",
            as: IteratorGetCornerRadiiFn.self
        )

    /// Queries window corner radius via SkyLight (#357), or nil
    /// if unavailable — the caller substitutes
    /// `GeometryUtils.systemWindowCornerRadius` so a failed query
    /// never blocks a ring.
    static func windowCornerRadius(_ wid: CGWindowID) -> CGFloat? {
        guard let connection,
            let queryWindows = windowQueryWindows,
            let copyWindows = queryResultCopyWindows,
            let count = iteratorGetCount,
            let advance = iteratorAdvance,
            let cornerRadii = iteratorGetCornerRadii
        else { return nil }

        var raw = Int32(bitPattern: wid)
        guard
            let number = CFNumberCreate(nil, .sInt32Type, &raw)
        else { return nil }
        let targets = [number] as CFArray

        // `takeRetainedValue` matches SLS +1 returned ownership;
        // do not switch to unretained.
        guard
            let query = queryWindows(connection, targets, 0)?
                .takeRetainedValue(),
            let iterator = copyWindows(query)?.takeRetainedValue(),
            count(iterator) > 0, advance(iterator),
            let radiiRef = cornerRadii(iterator)?.takeRetainedValue(),
            CFArrayGetCount(radiiRef) > 0
        else { return nil }

        let first = unsafeBitCast(
            CFArrayGetValueAtIndex(radiiRef, 0),
            to: CFNumber.self
        )
        var value: Int32 = 0
        CFNumberGetValue(first, .sInt32Type, &value)
        return value > 0 ? CGFloat(value) : nil
    }
}
