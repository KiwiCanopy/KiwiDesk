import Foundation

/// `pocket.*`: the pocket mark's colour (#2671), through the marks'
/// shared `setMarkColor` — empty is Automatic. Where it sits and
/// when it shows are KiwiShelf's (`kiwishelf.set_pocket_*`);
/// its list's key takes no setter's pass (`pocketToggleListCommand`).
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
        default:
            return .fail("unknown command: \(command)")
        }
    }
}
