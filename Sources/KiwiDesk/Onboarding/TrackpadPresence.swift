import IOKit

/// Whether this Mac has a trackpad (#1873 ▸ Ruling 2026-11-15, the
/// tour's Gestures step): a built-in one or a Magic Trackpad, read
/// from the public IOKit registry by its driver class, so a Magic
/// Mouse — a multitouch device too — is no trackpad. Read once when
/// the tour plans its steps; the wiring hands it to the model, which
/// a test sets itself.
enum TrackpadPresence {
    static let driverClass = "AppleMultitouchTrackpadHIDEventDriver"

    static func connected() -> Bool {
        var iterator: io_iterator_t = 0
        guard
            IOServiceGetMatchingServices(
                kIOMainPortDefault,
                IOServiceMatching(driverClass),
                &iterator
            ) == KERN_SUCCESS
        else { return false }
        defer { IOObjectRelease(iterator) }
        let first = IOIteratorNext(iterator)
        guard first != 0 else { return false }
        IOObjectRelease(first)
        return true
    }
}
