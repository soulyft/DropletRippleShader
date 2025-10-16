import SwiftUI

extension Color {
    var rgbVector: SIMD3<Float> {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD3(Float(r), Float(g), Float(b))
        #elseif canImport(AppKit)
        let nsColor = NSColor(self)
        let converted = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        return SIMD3(Float(converted.redComponent),
                     Float(converted.greenComponent),
                     Float(converted.blueComponent))
        #else
        return SIMD3<Float>(0, 0, 0)
        #endif
    }
}
