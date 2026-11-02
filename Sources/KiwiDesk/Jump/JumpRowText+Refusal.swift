import KiwiDeskCore

/// The words a KiwiHub row shows where the pick a held modifier
/// names would refuse it (#2885 ▸ Ruling, refusals shown in the
/// row): a state word in place of the route, after ⛔. Core names
/// the reason; these word it.
extension JumpRowText {
    /// Swap here's reason: the row's window's state, or yours.
    static func refusal(_ block: JumpSwapBlock) -> String {
        switch block {
        case .floating:
            L("jump.place.swap_block.floating", "Floating")
        case .fullScreen:
            L("jump.status.fullscreen", "Full Screen")
        case .sticky:
            L("jump.place.swap_block.sticky", "Sticky")
        case .pocketed:
            L("jump.status.pocketed", "In your pocket")
        case .minimized:
            L("jump.status.minimized", "Minimized")
        case .hiddenApp:
            L("jump.status.hidden", "Hidden")
        case .otherDesktop(let number?):
            desktopName(number)
        case .otherDesktop(nil):
            L("jump.place.swap_block.other_desktop", "Another Desktop")
        case .yours:
            L("jump.place.swap_block.yours", "Your window")
        case .yoursFloating:
            L("jump.place.swap_block.yours_floating", "Yours is floating")
        case .yoursFullScreen:
            L(
                "jump.place.swap_block.yours_full_screen",
                "Yours is full screen"
            )
        case .yoursSticky:
            L("jump.place.swap_block.yours_sticky", "Yours is sticky")
        case .nothingHere:
            L("jump.place.swap_block.nothing_here", "No window here")
        }
    }

    /// Move here's reason.
    static func refusal(_ block: JumpMoveBlock) -> String {
        switch block {
        case .fullScreen: L("jump.status.fullscreen", "Full Screen")
        case .sticky: L("jump.place.swap_block.sticky", "Sticky")
        }
    }

    /// What VoiceOver hears for a refused press (Ruling 8).
    static func swapRefusedSpoken(_ block: JumpSwapBlock) -> String {
        L("jump.ax.swap_refused", "Can't swap: %1$@", refusal(block))
    }

    static func moveRefusedSpoken(_ block: JumpMoveBlock) -> String {
        L("jump.ax.move_here_refused", "Can't move here: %1$@", refusal(block))
    }
}

/// A row's two refusals, worded once per build: what ⌥ and ⇧ show
/// where the pick they name would refuse it.
struct JumpRowRefusal: Equatable {
    var swap: String?
    var move: String?

    init(swap: String? = nil, move: String? = nil) {
        self.swap = swap
        self.move = move
    }

    @MainActor
    init(entry: JumpEntry) {
        swap = entry.swapBlock.map { JumpRowText.refusal($0) }
        move = entry.moveBlock.map { JumpRowText.refusal($0) }
    }
}
