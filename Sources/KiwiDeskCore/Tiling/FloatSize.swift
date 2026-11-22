import CoreGraphics

/// The size a window takes when it floats centred, in points
/// (`float_size`, #3554), in place of the derived size. Read only
/// by the centred placement and `size_floating`, never by layout
/// math. Both axes are finite and positive: the decoder refuses
/// anything else, so the value is always one a window can take.
public struct FloatSize: Sendable, Equatable {
    public let width: Double
    public let height: Double

    /// Nil unless both axes are finite and positive.
    public init?(width: Double, height: Double) {
        guard Self.admits(width), Self.admits(height) else {
            return nil
        }
        self.width = width
        self.height = height
    }

    public var size: CGSize { CGSize(width: width, height: height) }

    static func admits(_ value: Double) -> Bool {
        value.isFinite && value > 0
    }
}

extension FloatSize: Codable {
    enum CodingKeys: String, CodingKey {
        case width
        case height
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let width = try container.decode(Double.self, forKey: .width)
        let height = try container.decode(Double.self, forKey: .height)
        guard let size = FloatSize(width: width, height: height) else {
            throw DecodingError.dataCorruptedError(
                forKey: Self.admits(width) ? .height : .width,
                in: container,
                debugDescription: "float_size takes positive points"
            )
        }
        self = size
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }
}
