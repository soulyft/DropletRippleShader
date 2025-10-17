import SwiftUI

struct SingleRippleModifier: ViewModifier {
    let center: CGPoint
    let age: TimeInterval
    let amplitude: CGFloat
    let parameters: RippleParameters

    func body(content: Content) -> some View {
        // Derive current amplitude (already decayed in engine state).
        let amp = max(0, amplitude)
        let enabled = amp > parameters.minimumAmplitude
        let maxSample = min(parameters.maximumSampleOffset,
                            max(parameters.minimumAmplitude, amp))

        return content
            .compositingGroup()
            .visualEffect { effects, proxy in
                return effects.distortionEffect(
                    RippleShaderLibrary.ripple(
                        .float2(proxy.size),
                        .float2(center),
                        .float(Float(age)),
                        .float(Float(parameters.speed)),
                        .float(Float(parameters.wavelength)),
                        .float(Float(amp)),
                        .float(Float(parameters.ringWidth))
                    ),
                    maxSampleOffset: CGSize(width: maxSample, height: maxSample),
                    isEnabled: enabled
                )
            }
    }
}
