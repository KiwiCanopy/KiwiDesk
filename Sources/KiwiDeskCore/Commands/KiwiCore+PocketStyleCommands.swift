import Foundation

/// `pocket.*`: the pocket mark's colour (#2671), through the marks'
/// shared `setMarkColor` — empty is Automatic — the plate's edge
/// and position along it (#2680), and its capacity (#2678).
extension KiwiCore {
    func pocketStyleCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "pocket.set_color":
            return setMarkColor(args) {
                tiler.settings.pocketStyle.color = $0
            }
        case "pocket.set_capacity":
            switch BarSettingChoice.value(args, PocketCapacity.self) {
            case .success(let capacity):
                tiler.settings.pocketStyle.capacity = capacity
                return .ok()
            case .failure(let error):
                return .fail(error.message)
            }
        case "pocket.set_edge":
            switch BarSettingChoice.value(args, AppBarEdge.self) {
            case .success(let edge):
                tiler.settings.pocketStyle.edge = edge
                return .ok()
            case .failure(let error):
                return .fail(error.message)
            }
        case "pocket.set_position":
            guard let value = args.first?.numberValue, value.isFinite
            else { return .fail("expected a percentage (0–100)") }
            tiler.settings.pocketStyle.position = CGFloat(value)
            return .ok()
        default:
            return .fail("unknown command: \(command)")
        }
    }
}
