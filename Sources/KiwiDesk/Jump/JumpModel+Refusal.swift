import Foundation
import KiwiDeskCore

/// A Windows-row pick through the one door that asks Core whether
/// it refuses (#2885 ▸ refusals shown in the row). Every key, click,
/// digit and VoiceOver action takes it, never `onPick` beside it.
extension JumpModel {
    /// Hands row `index` to the pick, or, where Core refuses it now,
    /// shows and swells its reason and keeps the panel open (Ruling
    /// 4, 7). A row the snapshot refused that now goes ahead reaches
    /// the verb, which stays the authority.
    func pick(_ index: Int, _ pick: JumpPick) {
        guard list.results.indices.contains(index) else { return }
        let entry = list.results[index].entry
        guard let spoken = refusalSpoken(entry, pick) else {
            onPick(entry, pick)
            return
        }
        refusedRow = index
        // A key acts on the selection while the pointer may lift
        // another row: the refused row says why until let go.
        revealedRow = index
        onRefuse(spoken)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            [weak self] in
            if self?.refusedRow == index { self?.refusedRow = nil }
        }
    }

    /// What VoiceOver hears where `pick` refuses `entry` now; nil
    /// where it goes ahead.
    func refusalSpoken(_ entry: JumpEntry, _ pick: JumpPick) -> String? {
        switch pick {
        case .jump:
            nil
        case .moveHere:
            moveRefusal(entry).map { JumpRowText.moveRefusedSpoken($0) }
        case .swapHere:
            swapRefusal(entry).map { JumpRowText.swapRefusedSpoken($0) }
        }
    }
}
