import Foundation
import Security

/// Whether a bundle on disk is the same signed program as the
/// running one (#930 ruling 3): the gate an in-place
/// `service restart` passes before it leaves the windows where
/// they are. A build that fails it — a re-signed or ad-hoc dev
/// build — is likely to lose the Accessibility grant, and would
/// strand parked windows, so the stop gathers instead.
///
/// Public Security.framework calls, after Sparkle's
/// `SUCodeSigningVerifier`, with the requirement taken from the
/// RUNNING process rather than a second bundle. It is read once,
/// at launch (`running()`), while the bundle on disk is still
/// the one that launched: a rebuild over the same path later
/// would otherwise hand the new build its own requirement.
public struct CodeIdentity: @unchecked Sendable {
    /// Why a bundle is not admitted — structure, rendered only by
    /// the log line (core-boundaries.md).
    public enum Refusal: Equatable, Sendable {
        /// The running process has no designated requirement: it
        /// is unsigned, or its signature could not be read.
        case selfUnsigned(OSStatus)
        /// Nothing signed could be read at the incoming path.
        case noStaticCode(OSStatus)
        /// The incoming bundle does not satisfy the requirement.
        case failsRequirement(OSStatus)
    }

    public enum Verdict: Equatable, Sendable {
        case admitted
        case refused(Refusal)
    }

    private let requirement: SecRequirement?
    private let selfStatus: OSStatus

    /// The running process's designated requirement, read now.
    public static func running() -> CodeIdentity {
        var code: SecCode?
        var status = SecCodeCopySelf([], &code)
        var staticCode: SecStaticCode?
        if status == errSecSuccess, let code {
            status = SecCodeCopyStaticCode(code, [], &staticCode)
        }
        var requirement: SecRequirement?
        if status == errSecSuccess, let staticCode {
            status = SecCodeCopyDesignatedRequirement(
                staticCode,
                [],
                &requirement
            )
        }
        return CodeIdentity(
            requirement: status == errSecSuccess ? requirement : nil,
            selfStatus: status
        )
    }

    /// Whether the program at `incoming` — a bundle, or an
    /// executable inside one — satisfies the running
    /// requirement, every architecture checked.
    public func admits(_ incoming: URL) -> Verdict {
        guard let requirement else {
            return .refused(.selfUnsigned(selfStatus))
        }
        var staticCode: SecStaticCode?
        let path = Self.bundle(containing: incoming) as CFURL
        let created = SecStaticCodeCreateWithPath(path, [], &staticCode)
        guard created == errSecSuccess, let staticCode else {
            return .refused(.noStaticCode(created))
        }
        let checked = SecStaticCodeCheckValidityWithErrors(
            staticCode,
            SecCSFlags(rawValue: kSecCSCheckAllArchitectures),
            requirement,
            nil
        )
        return checked == errSecSuccess
            ? .admitted : .refused(.failsRequirement(checked))
    }

    /// The `.app` whose main executable `url` is, or `url` itself
    /// otherwise: launchd starts the executable, the signature
    /// seals the bundle. Only the `X.app/Contents/MacOS/exe`
    /// shape — a tool that merely sits under some `.app` (Xcode's
    /// toolchain) is its own code.
    static func bundle(containing url: URL) -> URL {
        let macOS = url.standardizedFileURL.deletingLastPathComponent()
        let contents = macOS.deletingLastPathComponent()
        let app = contents.deletingLastPathComponent()
        guard macOS.lastPathComponent == "MacOS",
            contents.lastPathComponent == "Contents",
            app.pathExtension == "app"
        else { return url }
        return app
    }
}
