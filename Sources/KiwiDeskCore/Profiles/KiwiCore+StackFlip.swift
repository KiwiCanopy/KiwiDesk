import Foundation

/// The per-Desktop stack flip (#2771): `stack.toggle_stack_position`
/// flips the side a Space draws on the macOS Desktop its screen
/// shows now, and on no other. Session state in
/// `DesktopMemory.stackFlips`; every reader of the side a Space
/// draws takes `stackFlip(of:)`, the one door, which the resolver
/// `TilingSettings.resolvedStack(for:flip:)` requires; which Desktop
/// is `shownDesktop(of:)`'s.
extension KiwiCore {
    /// The side `space` draws on the Desktop shown now where it
    /// was flipped there, else nil — the ONE door
    /// (`StackFlipSeamTests`).
    func stackFlip(of space: SpaceID) -> StackParams.StackPosition? {
        guard case .shown(let desktop) = shownDesktop(of: space)
        else { return nil }
        return desktopMemory.stackFlips[desktop]?[space]
    }

    /// The side `space` draws now: its flip on this Desktop, else
    /// its override, else the global value.
    func drawnStackPosition(
        of space: SpaceID
    ) -> StackParams.StackPosition {
        stackFlip(of: space)
            ?? tiler.settings.resolvedStack(for: space).stackPosition
    }

    /// `stack.toggle_stack_position([space])`: the drawn side to
    /// the opposite one on this Desktop. A flip back onto the
    /// authored side removes the entry; sizing is untouched.
    func toggleStackPosition(
        _ args: [JSONValue]
    ) -> CommandResponse {
        let space: SpaceID
        if let raw = args.first?.stringValue, !raw.isEmpty {
            space = SpaceID(raw)
            guard state.workspaces[space] != nil else {
                return .fail("unknown space: \(raw)")
            }
        } else {
            guard let active = state.workspaces.activeSpace else {
                return .fail("no active space")
            }
            space = active
        }
        guard case .shown(let desktop) = shownDesktop(of: space)
        else {
            return .fail("no desktop shown for space: \(space.raw)")
        }
        let side = drawnStackPosition(of: space).opposite
        let authored = tiler.settings.resolvedStack(for: space)
            .stackPosition
        var flips = desktopMemory.stackFlips[desktop] ?? [:]
        flips[space] = side == authored ? nil : side
        desktopMemory.stackFlips[desktop] = flips.isEmpty ? nil : flips
        return .ok()
    }

    // MARK: - Clearing doors

    /// Every Space on every Desktop: wherever the user's explicit
    /// choice replaces the authored side (#2771's ruling).
    func forgetStackFlips() {
        desktopMemory.stackFlips = [:]
    }

    /// One Space on every Desktop: its override setter and its
    /// drop (`forwardWindows(of:to:)`).
    func forgetStackFlips(of space: SpaceID) {
        desktopMemory.stackFlips = desktopMemory.stackFlips
            .mapValues { $0.filter { $0.key != space } }
            .filter { !$0.value.isEmpty }
    }

    /// A renumbered Space keeps its flips (`moveMembers`, #1655).
    func rekeyStackFlips(_ old: SpaceID, to new: SpaceID) {
        desktopMemory.stackFlips = desktopMemory.stackFlips.mapValues {
            var flips = $0
            if let side = flips.removeValue(forKey: old) {
                flips[new] = side
            }
            return flips
        }
    }
}
