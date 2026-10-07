import AppKit

/// One window as a bar list names it, read from state alone (#1946):
/// the glyph menu and the hover peek both take it, and only the
/// menu adds what needs the compositor — a row's enablement — when
/// it presents.
struct BarWindowRow: Equatable {
    let window: WindowID
    let pid: pid_t
    let app: String
    let title: String
    let icon: NSImage?
}
