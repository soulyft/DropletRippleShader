import CoreGraphics

/// Tunable constants that describe the behaviour of a ripple field.
public struct RippleParameters {
    /// Initial displacement of the wave crest (points).
    public var amplitude: CGFloat
    /// Distance between successive wave crests (points).
    public var wavelength: CGFloat
    /// Wave propagation speed multiplier.
    public var speed: CGFloat
    /// Exponential decay coefficient applied over time.
    public var decay: CGFloat
    /// Thickness of the moving crest ring (points).
    public var ringWidth: CGFloat
    /// Ripples below this amplitude are culled to avoid needless work.
    public var minimumAmplitude: CGFloat
    /// Safety cap for the sampling radius SwiftUI is allowed to use.
    public var maximumSampleOffset: CGFloat


    public init(amplitude: CGFloat,
                wavelength: CGFloat,
                speed: CGFloat,
                decay: CGFloat,
                ringWidth: CGFloat,
                minimumAmplitude: CGFloat,
                maximumSampleOffset: CGFloat) {
        self.amplitude = amplitude
        self.wavelength = wavelength
        self.speed = speed
        self.decay = decay
        self.ringWidth = ringWidth
        self.minimumAmplitude = minimumAmplitude
        self.maximumSampleOffset = maximumSampleOffset
    }

    public static let `default` = RippleParameters(
        amplitude: 10,
        wavelength: 140,
        speed: 2.2,
        decay: 1.8,
        ringWidth: 30,
        minimumAmplitude: 0.15,
        maximumSampleOffset: 160
    )
}
