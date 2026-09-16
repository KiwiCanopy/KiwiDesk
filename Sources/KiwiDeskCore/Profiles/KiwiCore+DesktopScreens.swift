import Foundation

/// Which screen a Desktop lives on, by name (#1438) — the line
/// the Desktops card draws under each row so two rows both
/// titled "Desktop 1" (each screen's own, under "Displays have
/// separate Spaces") can be told apart.
///
/// The join is `displaysByUUID()`'s — the topology's
/// `displayUUID` against the attached displays.
extension KiwiCore {
    /// Each attached display's name by the UUID a topology
    /// reading names it with. A display the UUID symbol cannot
    /// name is absent, never blank.
    func screenNamesByUUID() -> [String: String] {
        displaysByUUID().mapValues(\.name)
    }

    /// The screen each present user Desktop lives on, under
    /// every key it answers to — the live row's line, read
    /// from the snapshot in hand rather than a record.
    public func desktopScreens(
        in snapshot: DesktopSnapshot
    ) -> [DesktopKey: String] {
        let names = screenNamesByUUID()
        var screens: [DesktopKey: String] = [:]
        for space in snapshot.spaces where space.isUser {
            guard let name = names[space.displayUUID] else {
                continue
            }
            for key in snapshot.keys(of: space.id) {
                screens[key] = name
            }
        }
        return screens
    }
}
