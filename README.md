# DropletRippleShader

SwiftUI + Metal ripple field (single/multi) using stitchable shaders.

## Requirements
- iOS 17+, macOS 14+
- Xcode 15.4+

## Add via SPM
Use Xcode “Add Package” with:

https://github.com/soulyft/DropletRippleShader.git

## Usage
```swift
import SwiftUI
import RippleField

struct Demo: View {
  @State private var engine = RippleEngine()
  var body: some View {
    ZStack {
      Rectangle().fill(.quaternary)
        .rippleField(engine: engine, parameters: .default, mode: .multi)
    }
    .contentShape(Rectangle())
    .onTapGesture { pt in engine.emit(at: pt) }
  }
}
```

API

RippleField view / View.rippleField(...), RippleEngine, RippleParameters,
RippleMode, RippleFieldStyle, RipplePrismConfiguration, RippleGlowConfiguration.

License

MIT
