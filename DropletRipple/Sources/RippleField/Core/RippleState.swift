import CoreGraphics

public struct RippleState: Equatable {
    public var center: CGPoint
    public var age: TimeInterval
    public var amplitude: CGFloat

    public init(center: CGPoint, age: TimeInterval, amplitude: CGFloat) {
        self.center = center
        self.age = age
        self.amplitude = amplitude
    }
}

