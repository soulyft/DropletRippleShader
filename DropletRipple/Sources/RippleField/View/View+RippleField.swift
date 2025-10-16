import SwiftUI

public extension View {
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
    func rippleField(engine: RippleEngine,
                     parameters: RippleParameters = .default,
                     eventSpace: CoordinateSpace,
                     mode: RippleMode,
                     style: RippleFieldStyle) -> some View {
        RippleField(engine: engine,
                    parameters: parameters,
                    eventSpace: eventSpace,
                    mode: mode,
                    style: style) { self }
    }
}
