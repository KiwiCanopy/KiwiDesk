import Foundation

/// Why a KiwiVision lens cannot turn on (#2103 rulings 16, 37).
/// Core names it through `KiwiCore.lensRefusal(_:)`; KiwiHub and
/// the CLI narrate it.
public enum LensRefusal: Equatable, Sendable {
    /// The lens holds no apps (ruling 37).
    case noApps
    /// The live profile leaves the lens out (rulings 15, 38).
    case outOfReach(profile: String)
}

/// Why what KiwiVision draws changed without the user asking for
/// that change (#2103 ruling 16).
public enum VisionChangeCause: Equatable, Sendable {
    /// The lens on does not reach the profile a switch made live.
    case outOfReach(lens: String, profile: String)
}

/// What a lens turning on tells the user when none of its apps
/// has a window and nothing opened (#3122). Core draws the pill;
/// the GUI narrates it for VoiceOver.
public enum VisionLensNotice: Equatable, Sendable {
    /// No member has a window, and none is set to open.
    case noMemberOpen(lens: String)
    /// An Auto-open member LaunchServices cannot find.
    case notInstalled(app: String)
}

/// A lens as a picker offers it: its stored name and why it cannot
/// turn on, nil where it can.
public struct VisionLensChoice: Equatable, Sendable {
    public let name: String
    public let refusal: LensRefusal?

    public init(name: String, refusal: LensRefusal? = nil) {
        self.name = name
        self.refusal = refusal
    }
}
