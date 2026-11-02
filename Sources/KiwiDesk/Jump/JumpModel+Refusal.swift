import Foundation
import KiwiDeskCore

/// A Windows-row pick through the one door that knows the
/// snapshot's refusals (#2885 ▸ refusals shown in the row).
extension JumpModel {
    /// Hands row `index` to the pick, or, where the snapshot says
    /// the pick refuses it, swells its reason and keeps the panel
    /// open (#2885 ▸ Ruling 4, 7).
    func pick(_ index: Int, _ pick: JumpPick) {
        let entry = list.results[index].entry
        guard let spoken = Self.refusalSpoken(entry, pick) else {
            onPick(entry, pick)
            return
        }
        refusedRow = index
        onRefuse(spoken)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            [weak self] in
            if self?.refusedRow == index { self?.refusedRow = nil }
        }
    }

    /// What VoiceOver hears where `pick` refuses `entry`; nil where
    /// it goes ahead.
    static func refusalSpoken(
        _ entry: JumpEntry,
        _ pick: JumpPick
    ) -> String? {
        switch pick {
        case .jump: nil
        case .moveHere:
            entry.moveBlock.map {
                JumpRowText.moveRefusedSpoken($0)
            }
        case .swapHere:
            entry.swapBlock.map {
                JumpRowText.swapRefusedSpoken($0)
            }
        }
    }
}
