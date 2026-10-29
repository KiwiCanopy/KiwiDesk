import Foundation

/// `pocket.*`: the pocket mark's colour (#2671), through the marks'
/// shared `setMarkColor` — empty is Automatic — and its capacity
/// (#2678). Where it sits is KiwiShelf's (`kiwishelf.set_pocket_*`).
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
            // App-wide, the running value, as every app-wide verb.
            switch BarSettingChoice.value(args, PocketCapacity.self) {
            case .success(let capacity):
                setAppWide(persisting: false) { $0.pocketCapacity = capacity }
                return .ok()
            case .failure(let error):
                return .fail(error.message)
            }
        default:
            return .fail("unknown command: \(command)")
        }
    }
}
