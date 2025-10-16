import SwiftUI

public struct RipplePrismConfiguration: Equatable {
    public var refractionStrength: CGFloat
    public var dispersion: CGFloat
    public var tintStrength: CGFloat
    public var tintColor: Color

    public init(refractionStrength: CGFloat, dispersion: CGFloat, tintStrength: CGFloat, tintColor: Color) {
        self.refractionStrength = refractionStrength
        self.dispersion = dispersion
        self.tintStrength = tintStrength
        self.tintColor = tintColor
    }
}

