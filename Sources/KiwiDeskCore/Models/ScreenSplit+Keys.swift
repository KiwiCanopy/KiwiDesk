import Foundation

/// The keys a stored split leaves a screen, read by every per-area
/// writer and Settings row (#3517) through the one
/// `ScreenSplit.effective`, so they never disagree with the
/// placement list about which areas a screen has.
extension ScreenSplit {
    /// The `ScreenAreaKey`s `fingerprint` lays out in under
    /// `splits`, in reading order: its fingerprint alone while it
    /// is whole, or its size cannot be read from the fingerprint.
    public static func areaKeys(
        of fingerprint: String,
        in splits: [String: ScreenSplit]
    ) -> [String] {
        let sides = Display.fingerprintParts(fingerprint).size
            .split(separator: "x").compactMap { Int($0) }
        guard sides.count == 2,
            let split = effective(
                splits[fingerprint],
                width: sides[0],
                height: sides[1]
            )
        else { return [fingerprint] }
        return ScreenArea.readingOrder(split.areas).map {
            ScreenAreaKey(fingerprint: fingerprint, areaID: $0.id)
                .description
        }
    }
}
