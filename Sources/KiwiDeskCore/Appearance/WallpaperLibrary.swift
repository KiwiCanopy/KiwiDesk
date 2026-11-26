import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The pictures looks carry (#3478 ▸ 2026-11-24): `wallpapers/` in
/// the config folder, each file named by its content hash, so it
/// travels and syncs with the config and a look names it by value.
/// Stateless, like the look store: every read is the folder.
public struct WallpaperLibrary: Sendable {
    /// Why a file cannot join the library.
    public enum Refusal: Error, Equatable {
        /// ImageIO cannot decode it, or its type is outside
        /// `LookWallpaper.extensions`.
        case notAPicture
        case unreadable
        case couldNotWrite
    }

    /// Above this many bytes the attach asks first (#3478 ▸ Size:
    /// warn, never refuse).
    public static let largeBytes = 32 * 1024 * 1024

    public let directory: URL

    public init(configDirectory: URL) {
        directory = configDirectory.appendingPathComponent(
            Self.folderName,
            isDirectory: true
        )
    }

    static let folderName = "wallpapers"

    /// Where library picture `name` lives.
    public func url(of name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    /// Whether `name` is in this library now; a picture not yet
    /// synced is not (the look keeps its reference).
    public func has(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: url(of: name).path)
    }

    /// The bytes of picture `name`, nil while it is not here.
    public func data(of name: String) -> Data? {
        try? Data(contentsOf: url(of: name))
    }

    /// Copies `data` in under its hash name and answers the name;
    /// a file already there is kept, since its name is its bytes.
    public func add(_ data: Data) throws(Refusal) -> String {
        guard let ext = Self.fileExtension(of: data) else {
            throw .notAPicture
        }
        let name = Self.name(of: data, extension: ext)
        guard !has(name) else { return name }
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try data.write(to: url(of: name), options: .atomic)
        } catch {
            throw .couldNotWrite
        }
        return name
    }

    /// `add` over a file the user picked or dropped.
    public func add(fileAt source: URL) throws(Refusal) -> String {
        guard let data = try? Data(contentsOf: source) else {
            throw .unreadable
        }
        return try add(data)
    }

    /// Every picture here, by name.
    public func names() -> [String] {
        let files = try? FileManager.default.contentsOfDirectory(
            atPath: directory.path
        )
        return (files ?? []).filter(LookWallpaper.isLibraryName)
    }

    /// Every picture here with its bytes: what a backup carries.
    public func contents() -> [String: Data] {
        var out: [String: Data] = [:]
        for name in names() { out[name] = data(of: name) }
        return out
    }

    /// `<sha256 hex>.<ext>`: the one spelling of a library name.
    public static func name(of data: Data, extension ext: String) -> String {
        let hash = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }.joined()
        return "\(hash).\(ext)"
    }

    /// The library extension ImageIO reads `data` as, nil for bytes
    /// that are no picture or of a type looks do not carry.
    public static func fileExtension(of data: Data) -> String? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            CGImageSourceGetCount(source) > 0,
            let id = CGImageSourceGetType(source) as String?,
            let type = UTType(id)
        else { return nil }
        if type.conforms(to: .heic) || type.conforms(to: .heif) {
            return "heic"
        }
        if type.conforms(to: .jpeg) { return "jpg" }
        if type.conforms(to: .png) { return "png" }
        if type.conforms(to: .tiff) { return "tiff" }
        return nil
    }
}
