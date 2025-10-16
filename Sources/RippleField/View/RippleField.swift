import SwiftUI
import Observation

/// Wrap any content with a reusable multi-drop ripple effect.
public struct RippleField<Content: View>: View {
    @Bindable private var engine: RippleEngine
    private let parameters: RippleParameters
    private let content: Content
    private let eventSpace: CoordinateSpace
    private let mode: RippleMode
    private let style: RippleFieldStyle
    @State private var containerFrameInEventSpace: CGRect = .zero

    public init(engine: RippleEngine,
                parameters: RippleParameters = .default,
                eventSpace: CoordinateSpace = .global,
                mode: RippleMode = .multi,
                style: RippleFieldStyle = .distortionOnly,
                @ViewBuilder content: () -> Content) {
        self._engine = Bindable(engine)
        self.parameters = parameters
        self.eventSpace = eventSpace
        self.mode = mode
        self.style = style
        self.content = content()
    }

    public var body: some View {
        // Capture the container's frame in the event space so we can convert incoming
        // event centers into this view's local space.
        let capturedContent = content
            .background(
                GeometryReader { proxy in
                    let frame = proxy.frame(in: eventSpace)
                    Color.clear
                        .onChange(of: frame, initial: true) { oldFrame, newFrame in
                            // Keep the stored frame in sync with the event space so ripple centers map correctly.
                            if oldFrame != newFrame {
                                containerFrameInEventSpace = newFrame
                            }
                        }
                }
            )

        if engine.isIdle {
            capturedContent
        } else {
            TimelineView(.animation) { timeline in
                let states = engine.rippleStates(at: timeline.date, parameters: parameters)
                let localStates = states.map { state -> RippleState in
                    guard containerFrameInEventSpace.origin.x.isFinite,
                          containerFrameInEventSpace.origin.y.isFinite,
                          containerFrameInEventSpace.width.isFinite,
                          containerFrameInEventSpace.height.isFinite else {
                        return state
                    }
                    var adjusted = state
                    adjusted.center.x -= containerFrameInEventSpace.minX
                    adjusted.center.y -= containerFrameInEventSpace.minY
                    return adjusted
                }

                if localStates.isEmpty {
                    capturedContent
                } else {
                    switch mode {
                    case .multi:
                        switch style {
                        case .distortionOnly:
                            capturedContent
                                .modifier(MultiRippleModifier(states: localStates, parameters: parameters))
                        case .prismatic(let configuration):
                            capturedContent
                                .modifier(MultiRippleModifier(states: localStates, parameters: parameters))
                                .modifier(PrismaticRippleColorModifier(states: localStates,
                                                                       parameters: parameters,
                                                                       configuration: configuration))
                        case .luminous(let configuration):
                            capturedContent
                                .modifier(MultiRippleModifier(states: localStates, parameters: parameters))
                                .modifier(GlowRippleColorModifier(states: localStates,
                                                                 parameters: parameters,
                                                                 configuration: configuration))
                        }
                    case .single:
                        if let first = localStates.first {
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
