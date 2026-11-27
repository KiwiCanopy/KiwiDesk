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
        guard let size = ScreenShares.size(of: fingerprint),
            let split = effective(
                splits[fingerprint],
                width: size.width,
                height: size.height
            )
        else { return [fingerprint] }
        return ScreenArea.readingOrder(split.areas).map {
            ScreenAreaKey(fingerprint: fingerprint, areaID: $0.id)
                .description
        }
    }
}
