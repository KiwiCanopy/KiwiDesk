import Foundation

/// `pocket.*` sub-API (#2671): the pocket mark's own colour, beside
/// the bare `pocket` verb that pockets a window. `set_color` shares
/// `setMarkColor` with the sticky and floating marks, so an empty
/// string is "Automatic"; `layoutCommand`'s forced retile re-syncs
/// the marks.
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
