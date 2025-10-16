import Foundation
import CoreGraphics
import Observation

@MainActor
@Observable
public final class RippleEngine {
    struct Event: Identifiable, Equatable {
        let id = UUID()
        let birth: Date
        var center: CGPoint
    }

    private(set) var events: [Event] = []
    var maximumSimultaneousRipples: Int

    // Coalescing to avoid emit floods from small, rapid movements
    private var lastEmitPoint: CGPoint? = nil
    private var lastEmitTime: Date? = nil
    /// Minimum spacing to accept a new emit
    var minimumEmitInterval: TimeInterval = 0.06
    var minimumEmitDistance: CGFloat = 6

    public init(maximumSimultaneousRipples: Int = 10) {
        self.maximumSimultaneousRipples = max(1, maximumSimultaneousRipples)
        self.minimumEmitInterval = 0.06
        self.minimumEmitDistance = 6
    }

    /// Emits a new ripple originating at the provided point (in the field's coordinate space).
    public func emit(at point: CGPoint, timestamp: Date = .now) {
        // Skip if we're already at capacity.
        if events.count >= maximumSimultaneousRipples {
            return
        }

        // Drop near-duplicate emits that arrive within a tiny window in time & space
        if let t0 = lastEmitTime, timestamp.timeIntervalSince(t0) < minimumEmitInterval,
           let p0 = lastEmitPoint {
            let dx = point.x - p0.x
            let dy = point.y - p0.y
            if (dx*dx + dy*dy) < (minimumEmitDistance * minimumEmitDistance) {
                return
            }
        }

        var pending = events
        pending.append(Event(birth: timestamp, center: point))
        if pending.count > maximumSimultaneousRipples {
            pending.removeFirst(pending.count - maximumSimultaneousRipples)
        }
        lastEmitPoint = point
        lastEmitTime = timestamp
        events = pending
    }

    /// Convenience helper for rectangular sources.
    public func emit(from rect: CGRect, timestamp: Date = .now) {
        emit(at: CGPoint(x: rect.midX, y: rect.midY), timestamp: timestamp)
    }

    /// Emits a batch of ripples in the provided coordinate space.
    public func emit(points: [CGPoint], timestamp: Date = .now) {
        guard !points.isEmpty else { return }
        for point in points {
            emit(at: point, timestamp: timestamp)
        }
    }

    /// Removes all active ripples.
    public func reset() {
        events.removeAll(keepingCapacity: true)
    }

    public var isIdle: Bool { events.isEmpty }

    /// Returns the currently active ripple states.
    public func rippleStates(at date: Date, parameters: RippleParameters) -> [RippleState] {
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
