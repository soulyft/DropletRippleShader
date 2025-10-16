import SwiftUI

public struct RippleGlowConfiguration: Equatable {
    public var glowStrength: CGFloat
    public var highlightPower: CGFloat
    public var highlightBoost: CGFloat
    public var glowColor: Color

    public init(glowStrength: CGFloat, highlightPower: CGFloat, highlightBoost: CGFloat, glowColor: Color) {
        self.glowStrength = glowStrength
        self.highlightPower = highlightPower
        self.highlightBoost = highlightBoost
        self.glowColor = glowColor
    }
}

