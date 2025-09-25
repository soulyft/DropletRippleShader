import SwiftUI
import CoreGraphics
import Observation

/// Tunable constants that describe the behaviour of a ripple field.
struct RippleParameters {
    /// Initial displacement of the wave crest (points).
    var amplitude: CGFloat
    /// Distance between successive wave crests (points).
    var wavelength: CGFloat
    /// Wave propagation speed multiplier.
    var speed: CGFloat
    /// Exponential decay coefficient applied over time.
    var decay: CGFloat
    /// Thickness of the moving crest ring (points).
    var ringWidth: CGFloat
    /// Ripples below this amplitude are culled to avoid needless work.
    var minimumAmplitude: CGFloat
    /// Safety cap for the sampling radius SwiftUI is allowed to use.
    var maximumSampleOffset: CGFloat

    static let `default` = RippleParameters(
        amplitude: 12,
        wavelength: 140,
        speed: 2.2,
        decay: 1.6,
        ringWidth: 36,
        minimumAmplitude: 0.15,
        maximumSampleOffset: 72
    )
}

/// Lightweight engine that tracks ripple birth times and centres.
@MainActor
@Observable
final class RippleEngine {
    struct Event: Identifiable, Equatable {
        let id = UUID()
        let birth: Date
        var center: CGPoint
    }

    private(set) var events: [Event] = []
    var maximumSimultaneousRipples: Int

    init(maximumSimultaneousRipples: Int = 20) {
        self.maximumSimultaneousRipples = max(1, maximumSimultaneousRipples)
    }

    /// Emits a new ripple originating at the provided point (in the field's coordinate space).
    func emit(at point: CGPoint, timestamp: Date = .now) {
        var pending = events
        pending.append(Event(birth: timestamp, center: point))
        if pending.count > maximumSimultaneousRipples {
            pending.removeFirst(pending.count - maximumSimultaneousRipples)
        }
        events = pending
    }

    /// Convenience helper for rectangular sources.
    func emit(from rect: CGRect, timestamp: Date = .now) {
        emit(at: CGPoint(x: rect.midX, y: rect.midY), timestamp: timestamp)
    }

    /// Emits a batch of ripples in the provided coordinate space.
    func emit(points: [CGPoint], timestamp: Date = .now) {
        guard !points.isEmpty else { return }
        for point in points {
            emit(at: point, timestamp: timestamp)
        }
    }

    /// Removes all active ripples.
    func reset() {
        events.removeAll(keepingCapacity: true)
    }

    var isIdle: Bool { events.isEmpty }

    /// Returns the currently active ripple states.
    func rippleStates(at date: Date, parameters: RippleParameters) -> [RippleState] {
        guard !events.isEmpty else { return [] }

        var survivors: [Event] = []
        var states: [RippleState] = []
        survivors.reserveCapacity(events.count)
        states.reserveCapacity(events.count)

        let baseAmplitude = max(parameters.amplitude, 0)
        let decayValue = max(parameters.decay, 0)

        for event in events {
            let age = max(0, date.timeIntervalSince(event.birth))
            let attenuation = decayValue > 0 ? exp(-Double(decayValue) * age) : 1.0
            let currentAmplitude = baseAmplitude * CGFloat(attenuation)
            guard currentAmplitude > parameters.minimumAmplitude else { continue }

            survivors.append(event)
            states.append(RippleState(center: event.center, age: age, amplitude: currentAmplitude))
        }

        if survivors.count != events.count {
            events = survivors
        }

        return states
    }
}

struct RippleState: Equatable {
    var center: CGPoint
    var age: TimeInterval
    var amplitude: CGFloat
}

enum RippleMode {
    case single
    case multi
}

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
                    ShaderLibrary.ripple(
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
            .allowsHitTesting(false)
    }
}

/// Applies a combined multi-ripple distortion using the `rippleCluster` shader.
struct MultiRippleModifier: ViewModifier {
    let states: [RippleState]
    let parameters: RippleParameters

    func body(content: Content) -> some View {
        // Conservative sampling radius (cap + floor)
        let maxAmplitude = states.map(\.amplitude).max() ?? 0
        let sampleRadius = maxAmplitude + parameters.ringWidth
        let maxSample = min(parameters.maximumSampleOffset,
                            max(parameters.minimumAmplitude, sampleRadius))

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
                    ShaderLibrary.rippleCluster(
                        .float2(size),                               // size (points)
                        .float(Float(parameters.wavelength)),        // wavelength
                        .float(Float(parameters.speed)),             // speed
                        .float(Float(parameters.ringWidth)),         // ringWidth
                        .floatArray(packed),                         // rippleData
                        .float(Float(count))                         // rippleCount
                    ),
                    maxSampleOffset: CGSize(width: maxSample, height: maxSample),
                    isEnabled: isEnabled
                )
            }
            .allowsHitTesting(false)
    }
}

/// Wrap any content with a reusable multi-drop ripple effect.
struct RippleField<Content: View>: View {
    @Bindable private var engine: RippleEngine
    private let parameters: RippleParameters
    private let content: Content
    private let eventSpace: CoordinateSpace
    private let mode: RippleMode
    @State private var containerFrameInEventSpace: CGRect = .zero

    init(engine: RippleEngine,
         parameters: RippleParameters = .default,
         eventSpace: CoordinateSpace = .global,
         mode: RippleMode = .multi,
         @ViewBuilder content: () -> Content) {
        self._engine = Bindable(engine)
        self.parameters = parameters
        self.eventSpace = eventSpace
        self.mode = mode
        self.content = content()
    }

    var body: some View {
        // Capture the container's frame in the event space so we can convert incoming
        // event centers into this view's local space.
        let capturedContent = content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            containerFrameInEventSpace = proxy.frame(in: eventSpace)
                        }
                        .onChange(of: proxy.size) {
                            containerFrameInEventSpace = proxy.frame(in: eventSpace)
                        }
                }
            )

        return Group {
            if engine.isIdle {
                capturedContent
            } else {
                TimelineView(.animation) { timeline in
                    let states = engine.rippleStates(at: timeline.date, parameters: parameters)

                    if states.isEmpty {
                        capturedContent
                    } else {
                        switch mode {
                        case .multi:
                            capturedContent
                                .modifier(MultiRippleModifier(states: states, parameters: parameters))
                        case .single:
                            if let first = states.first {
                                capturedContent
                                    .modifier(SingleRippleModifier(center: first.center,
                                                                   age: first.age,
                                                                   amplitude: first.amplitude,
                                                                   parameters: parameters))
                            } else {
                                capturedContent
                            }
                        }
                    }
                }
            }
        }
    }
}

extension View {
    /// Applies a multi-drop ripple distortion around the receiving view.
    func rippleField(engine: RippleEngine,
                     parameters: RippleParameters = .default) -> some View {
        RippleField(engine: engine, parameters: parameters, eventSpace: .global, mode: .multi) { self }
    }
    func rippleField(engine: RippleEngine,
                     parameters: RippleParameters = .default,
                     eventSpace: CoordinateSpace) -> some View {
        RippleField(engine: engine, parameters: parameters, eventSpace: eventSpace, mode: .multi) { self }
    }
    func rippleField(engine: RippleEngine,
                     parameters: RippleParameters = .default,
                     mode: RippleMode) -> some View {
        RippleField(engine: engine, parameters: parameters, eventSpace: .global, mode: mode) { self }
    }
    func rippleField(engine: RippleEngine,
                     parameters: RippleParameters = .default,
                     eventSpace: CoordinateSpace,
                     mode: RippleMode) -> some View {
        RippleField(engine: engine, parameters: parameters, eventSpace: eventSpace, mode: mode) { self }
    }
}
