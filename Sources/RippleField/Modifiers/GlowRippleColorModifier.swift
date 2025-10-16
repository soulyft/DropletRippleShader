import SwiftUI

/// Adds a luminous glow bloom that follows ripple crests.
struct GlowRippleColorModifier: ViewModifier {
    let states: [RippleState]
    let parameters: RippleParameters
    let configuration: RippleGlowConfiguration

    func body(content: Content) -> some View {
        let glow = configuration.glowColor.rgbVector
        let maxAmplitude = states.map(\.amplitude).max() ?? 0
        let rippleCount = Double(states.count)
        let countFactor = rippleCount > 0 ? (1.0 + 0.5 * log(max(1.0, rippleCount))) : 1.0
        let sampleRadius = CGFloat(countFactor) * maxAmplitude + parameters.ringWidth
        let maxSample = min(parameters.maximumSampleOffset,
                            max(parameters.minimumAmplitude, sampleRadius + 25))

        return content
            .compositingGroup()
            .visualEffect { effects, proxy in
                let size = proxy.size
                let sizeOK = size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0

                let clamped = Array(states.prefix(64))
                var packed: [Float] = []
                if sizeOK {
                    packed.reserveCapacity(clamped.count * 4)
                    for state in clamped {
                        let x = Float(state.center.x).isFinite ? Float(state.center.x) : 0
                        let y = Float(state.center.y).isFinite ? Float(state.center.y) : 0
                        let a = Float(state.age).isFinite ? Float(state.age) : 0
                        let amp = Float(state.amplitude).isFinite ? Float(state.amplitude) : 0
                        if amp > 0.0001 {
                            packed.append(contentsOf: [x, y, a, amp])
                        }
                    }
                }

                let count = packed.count / 4
                let isEnabled = sizeOK && count > 0


                return effects.layerEffect(
                    ShaderLibrary.rippleClusterGlowColor(
                        .float2(size),
                        .float(Float(parameters.wavelength)),
                        .float(Float(parameters.speed)),
                        .float(Float(parameters.ringWidth)),
                        .float(Float(configuration.glowStrength)),
                        .float(Float(configuration.highlightPower)),
                        .float(Float(configuration.highlightBoost)),
                        .float3(glow.x, glow.y, glow.z),
                        .floatArray(packed)
                    ),
                    maxSampleOffset: CGSize(width: maxSample, height: maxSample),
                    isEnabled: isEnabled
                )
            }
    }
}
