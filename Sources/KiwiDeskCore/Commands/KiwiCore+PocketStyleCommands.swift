import Foundation

/// `pocket.*` (#2671): the pocket mark's colour, through the
/// marks' shared `setMarkColor` — empty is Automatic.
extension KiwiCore {
    func pocketStyleCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard command == "pocket.set_color" else {
            return .fail("unknown command: \(command)")
        }
        return setMarkColor(args) {
            tiler.settings.pocketStyle.color = $0
        }
    }
}
