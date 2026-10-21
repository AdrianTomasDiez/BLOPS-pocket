import Foundation

/// Minimal 3D vector. Kept local so the gameplay core has no graphics dependency.
public struct Vec3: Equatable, Codable {
    public var x: Float
    public var y: Float
    public var z: Float

    public init(_ x: Float = 0, _ y: Float = 0, _ z: Float = 0) {
        self.x = x; self.y = y; self.z = z
    }

    public static let zero = Vec3()

    public var length: Float { (x * x + y * y + z * z).squareRoot() }
    public var horizontalLength: Float { (x * x + z * z).squareRoot() }

    public func normalized() -> Vec3 {
        let l = length
        return l < 0.0001 ? .zero : Vec3(x / l, y / l, z / l)
    }

    public static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x + b.x, a.y + b.y, a.z + b.z) }
    public static func - (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x - b.x, a.y - b.y, a.z - b.z) }
    public static func * (a: Vec3, s: Float) -> Vec3 { Vec3(a.x * s, a.y * s, a.z * s) }
    public static func += (a: inout Vec3, b: Vec3) { a = a + b }

    public func dot(_ o: Vec3) -> Float { x * o.x + y * o.y + z * o.z }

    /// Direction from yaw (radians, 0 = +Z) and pitch (radians, + = up).
    public static func direction(yaw: Float, pitch: Float) -> Vec3 {
        let cp = cos(pitch)
        return Vec3(sin(yaw) * cp, sin(pitch), cos(yaw) * cp).normalized()
    }

    public func distance(to o: Vec3) -> Float { (self - o).length }
    public func horizontalDistance(to o: Vec3) -> Float { (self - o).horizontalLength }
}

/// Deterministic RNG so gameplay is reproducible in tests.
public struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    public mutating func unit() -> Float {
        Float(next() % 10_000) / 10_000.0
    }

    public mutating func range(_ lo: Float, _ hi: Float) -> Float {
        lo + (hi - lo) * unit()
    }

    public mutating func int(_ lo: Int, _ hi: Int) -> Int {
        guard hi > lo else { return lo }
        return lo + Int(next() % UInt64(hi - lo + 1))
    }
}

/// Axis-aligned box used for walls and props.
public struct AABB: Equatable, Codable {
    public var min: Vec3
    public var max: Vec3

    public init(min: Vec3, max: Vec3) { self.min = min; self.max = max }

    public init(center: Vec3, size: Vec3) {
        min = Vec3(center.x - size.x / 2, center.y - size.y / 2, center.z - size.z / 2)
        max = Vec3(center.x + size.x / 2, center.y + size.y / 2, center.z + size.z / 2)
    }

    /// XZ footprint test with a vertical range, used for bullets and movement.
    public func contains(point: Vec3) -> Bool {
        point.x >= min.x && point.x <= max.x &&
        point.y >= min.y && point.y <= max.y &&
        point.z >= min.z && point.z <= max.z
    }

    public func touchesCircle(center: Vec3, radius: Float, height: Float) -> Bool {
        let closestX = Swift.max(min.x, Swift.min(center.x, max.x))
        let closestZ = Swift.max(min.z, Swift.min(center.z, max.z))
        let dx = center.x - closestX
        let dz = center.z - closestZ
        let withinHeight = center.y < max.y && center.y + height > min.y
        return withinHeight && (dx * dx + dz * dz) < radius * radius
    }

    /// Pushes a vertical capsule out of this box on the XZ plane.
    public func pushOut(_ position: Vec3, radius: Float, height: Float) -> Vec3 {
        guard touchesCircle(center: position, radius: radius, height: height) else { return position }
        let closestX = Swift.max(min.x, Swift.min(position.x, max.x))
        let closestZ = Swift.max(min.z, Swift.min(position.z, max.z))
        var dx = position.x - closestX
        var dz = position.z - closestZ
        var dist = (dx * dx + dz * dz).squareRoot()

        if dist < 0.0001 {
            // Centre is inside the box footprint: exit through nearest face.
            let left = position.x - min.x
            let right = max.x - position.x
            let back = position.z - min.z
            let front = max.z - position.z
            let least = Swift.min(Swift.min(left, right), Swift.min(back, front))
            if least == left { return Vec3(min.x - radius, position.y, position.z) }
            else if least == right { return Vec3(max.x + radius, position.y, position.z) }
            else if least == back { return Vec3(position.x, position.y, min.z - radius) }
            else { return Vec3(position.x, position.y, max.z + radius) }
        }
        let overlap = radius - dist
        guard overlap > 0 else { return position }
        let nx = dx / dist
        let nz = dz / dist
        return Vec3(position.x + nx * overlap, position.y, position.z + nz * overlap)
    }
}
