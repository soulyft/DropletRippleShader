import SwiftUI

public enum RippleFieldStyle: Equatable {
    case distortionOnly
    case prismatic(RipplePrismConfiguration)
    case luminous(RippleGlowConfiguration)
}
