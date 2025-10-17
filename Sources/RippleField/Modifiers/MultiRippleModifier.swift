import SwiftUI

/// Applies a combined multi-ripple distortion using the `rippleCluster` shader.
struct MultiRippleModifier: ViewModifier {
    let states: [RippleState]
    let parameters: RippleParameters

    func body(content: Content) -> some View {
        // Adaptive sampling radius that scales with ripple count and amplitude
        let maxAmplitude = states.map(\.amplitude).max() ?? 0
        let rippleCount = Double(states.count)
        let countFactor = rippleCount > 0 ? (1.0 + 0.5 * log(max(1.0, rippleCount))) : 1.0
        let sampleRadius = CGFloat(countFactor) * maxAmplitude + parameters.ringWidth
        let maxSample = min(parameters.maximumSampleOffset,
                            max(parameters.minimumAmplitude, sampleRadius + 15))

        return content
            .compositingGroup()
            .visualEffect { effects, proxy in
                // Validate size
                let size = proxy.size
                let sizeOK = size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0

                // Clamp states to shader's max and build packed buffer [x, y, age, amp] * N
                let clamped = Array(states.prefix(64))
                var packed: [Float] = []
                packed.reserveCapacity(clamped.count * 4)
                if sizeOK {
                    for s in clamped {
                        // Guard each value; replace non-finite with 0
                        let x = Float(s.center.x).isFinite ? Float(s.center.x) : 0
                        let y = Float(s.center.y).isFinite ? Float(s.center.y) : 0
                        let a = Float(s.age).isFinite ? Float(s.age) : 0
                        let amp = Float(s.amplitude).isFinite ? Float(s.amplitude) : 0
                        if amp > 0.0001 {
                            packed.append(contentsOf: [x, y, a, amp])
                        }
                    }
                }
                let count = packed.count / 4
                // Only enable the effect when we have a sane size and at least one valid ripple
                let isEnabled = sizeOK && count > 0

                return effects.distortionEffect(
                    RippleShaderLibrary.rippleCluster(
                        .float2(size),                               // size (points)
                        .float(Float(parameters.wavelength)),        // wavelength
                        .float(Float(parameters.speed)),             // speed
                        .float(Float(parameters.ringWidth)),         // ringWidth
                        .floatArray(packed)                          // rippleData (pointer + length provided by stitching)
                    ),
                    maxSampleOffset: CGSize(width: maxSample, height: maxSample),
                    isEnabled: isEnabled
                )
            }
    }
}
