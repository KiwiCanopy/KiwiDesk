/// A bar colour verb's argument (#1856, #3357): a hex, or `""`,
/// Automatic, where the palette register admits it
/// (`ColorPaletteKeys.allowsAutomatic`).
enum BarColorArg {
    static func parse(
        _ args: [JSONValue],
        automatic: Bool
    ) -> Result<String, AppBarSettingError> {
        guard let hex = args.first?.stringValue,
            (automatic && hex.isEmpty) || HexColor.parse(hex) != nil
        else {
            return .failure(
                automatic
                    ? "expected #RRGGBB, #RRGGBBAA or \"\""
                    : "expected #RRGGBB or #RRGGBBAA"
            )
        }
        return .success(hex)
    }
}
