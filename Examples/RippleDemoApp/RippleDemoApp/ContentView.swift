//
//  ContentView.swift
//  DropletRippleTest
//
//  Created by Corey Lofthus on 9/22/25.
//

import SwiftUI
import QuartzCore
import RippleField

enum RippleVisualPreset: String, CaseIterable, Identifiable {
    case classic
    case prismatic
    case aquaBloom

    var id: String { rawValue }
}

struct RippleStyleDefinition: Identifiable {
    let id: RippleVisualPreset
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color
}

struct RippleStyleEntry {
    let definition: RippleStyleDefinition
    let defaultState: StyleRuntimeState
}

struct StyleRuntimeState {
    var parameters: RippleParameters
    var prism: RipplePrismConfiguration?
    var glow: RippleGlowConfiguration?

    var style: RippleFieldStyle {
        if let prism { return .prismatic(prism) }
        if let glow { return .luminous(glow) }
        return .distortionOnly
    }
}

extension RippleVisualPreset {
    static let catalog: [RippleVisualPreset: RippleStyleEntry] = {
        let baseParameters = RippleParameters(
            amplitude: 12,
            wavelength: 140,
            speed: 2.2,
            decay: 1.6,
            ringWidth: 36,
            minimumAmplitude: 0.15,
            maximumSampleOffset: 72
        )

        return [
            .classic: RippleStyleEntry(
                definition: RippleStyleDefinition(
                    id: .classic,
                    title: "Classic",
                    subtitle: "Original multi-ripple distortion",
                    systemImage: "dot.viewfinder",
                    accent: Color.cyan
                ),
                defaultState: StyleRuntimeState(parameters: baseParameters,
                                                 prism: nil,
                                                 glow: nil)
            ),
            .prismatic: RippleStyleEntry(
                definition: RippleStyleDefinition(
                    id: .prismatic,
                    title: "Prismatic",
                    subtitle: "Chromatic refraction with subtle tint",
                    systemImage: "camera.macro",
                    accent: Color.purple
                ),
                defaultState: StyleRuntimeState(
                    parameters: RippleParameters(
                        amplitude: 6.0,
                        wavelength: 139,
                        speed: 3.0,
                        decay: 0.94,
                        ringWidth: 35,
                        minimumAmplitude: baseParameters.minimumAmplitude,
                        maximumSampleOffset: 120
                    ),
                    prism: RipplePrismConfiguration(
                        refractionStrength: 1.04,
                        dispersion: 0.96,
                        tintStrength: 0.08,
                        tintColor: Color(red: 16/255, green: 130/255, blue: 254/255) //hex 1082FE
                    ),
                    glow: nil
                )
            ),
            .aquaBloom: RippleStyleEntry(
                definition: RippleStyleDefinition(
                    id: .aquaBloom,
                    title: "Aqua Bloom",
                    subtitle: "Soft luminous bloom that follows the ripples",
                    systemImage: "sparkles",
                    accent: Color.blue
                ),
                defaultState: StyleRuntimeState(
                    parameters: RippleParameters(
                        amplitude: 6.7,
                        wavelength: 160,
                        speed: 2.95,
                        decay: 0.96,
                        ringWidth: 44,
                        minimumAmplitude: baseParameters.minimumAmplitude,
                        maximumSampleOffset: 140
                    ),
                    prism: nil,
                    glow: RippleGlowConfiguration(
                        glowStrength: 1.6,
                        highlightPower: 3.0,
                        highlightBoost: 0.14,
                        glowColor: Color(red: 0.45, green: 0.8, blue: 1.0)
                    )
                )
            )
        ]
    }()

    static var defaultStates: [RippleVisualPreset: StyleRuntimeState] {
        var map: [RippleVisualPreset: StyleRuntimeState] = [:]
        for (key, entry) in catalog {
            map[key] = entry.defaultState
        }
        return map
    }
}

/// A simple "home screen" with tappable icons. Tapping triggers a full-screen ripple.
struct ContentView: View {
    @State private var rippleEngine = RippleEngine()
    @State private var isMulti: Bool = true
    @State private var selectedStyle: RippleVisualPreset = .classic
    @State private var styleStates: [RippleVisualPreset: StyleRuntimeState] = RippleVisualPreset.defaultStates
    @State private var showStyleStudio: Bool = false

    private let rippleSpaceName = "ripple-field-space"

    // Simple data model for icons
    private let icons: [IconData] = (0..<20).map { i in
        IconData(id: i, systemName: [
            "phone.fill","message.fill","music.note","camera.fill","calendar","clock.fill",
            "gearshape.fill","paperplane.fill","photo","map.fill","mail.fill","note.text",
            "safari.fill","folder.fill","gamecontroller.fill","tv.fill","creditcard.fill","flame.fill",
            "bolt.fill","sun.max.fill"
        ][i % 20], title: "App \(i+1)")
    }

    var body: some View {
        let entry = RippleVisualPreset.catalog[selectedStyle] ?? RippleVisualPreset.catalog[.classic]!
        let currentState = styleStates[selectedStyle] ?? entry.defaultState

        ZStack {

            // Interactive grid (fully visible and receives gestures)
            HomeGrid(
                icons: icons,
                coordinateSpace: .named(rippleSpaceName)
            ) { iconCenter in
                rippleEngine.emit(at: iconCenter)
            }
            .opacity(0.1)

            // Visual overlay that duplicates background + grid for the ripple effect,
            // but with hit testing disabled so taps fall through to the interactive grid.
            ZStack {
                HomeGrid(
                    icons: icons,
                    coordinateSpace: .named(rippleSpaceName)
                ) { _ in }
                Rectangle()
                    .ignoresSafeArea()
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.5)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

            }
            .allowsHitTesting(false)
            .rippleField(engine: rippleEngine,
                         parameters: currentState.parameters,
                         eventSpace: .named(rippleSpaceName),
                         mode: isMulti ? .multi : .single,
                         style: currentState.style)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .coordinateSpace(name: rippleSpaceName)
        .contentShape(Rectangle())
        .safeAreaInset(edge: .bottom) {
            RippleBottomBar(
                selectedStyle: $selectedStyle,
                showStyleStudio: $showStyleStudio,
                catalog: RippleVisualPreset.catalog
            )
        }
        .sheet(isPresented: $showStyleStudio) {
            RippleStyleControlPanel(
                selection: $selectedStyle,
                styleStates: $styleStates,
                catalog: RippleVisualPreset.catalog
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

struct IconData: Identifiable {
    let id: Int
    let systemName: String
    let title: String
}

/// A grid of individual icon views.
/// Each icon calculates its own centre in the supplied coordinate space and reports it upward when tapped.
struct HomeGrid: View {
    let icons: [IconData]
    let coordinateSpace: CoordinateSpace
    let onIconTap: (CGPoint) -> Void

    // A nice, iOS-like grid
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 24, alignment: .center), count: 4)

    init(icons: [IconData], coordinateSpace: CoordinateSpace = .local, onIconTap: @escaping (CGPoint) -> Void) {
        self.icons = icons
        self.coordinateSpace = coordinateSpace
        self.onIconTap = onIconTap
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(icons) { icon in
                IconTile(icon: icon, coordinateSpace: coordinateSpace) { center in
                    onIconTap(center)
                }
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
    }
}

/// A single "app icon" tile. Tapping it reports its centre (in the provided coordinate space) upward.
struct IconTile: View {
    let icon: IconData
    let coordinateSpace: CoordinateSpace
    let tapped: (CGPoint) -> Void

    @State private var centerInSpace: CGPoint = .zero
    @State private var lastEmitTime: CFTimeInterval = 0

    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .foregroundStyle(.white)
                .overlay(
                    Image(systemName: icon.systemName)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.primary)
                )
                .frame(width: 64, height: 64)
                .background(
                    GeometryReader { proxy in
                        let rect = proxy.frame(in: coordinateSpace)
                        Color.clear
                            .onAppear {
                                centerInSpace = CGPoint(x: rect.midX, y: rect.midY)
                            }
                            .onChange(of: rect) { _, newRect in
                                centerInSpace = CGPoint(x: newRect.midX, y: newRect.midY)
                            }
                    }
                )
                .shadow(radius: 2, y: 1)

            Text(icon.title)
                .font(.footnote)
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture {
            tapped(centerInSpace)
        }
        .frame(height: 96) // grid cell height
    }
}

/// Bottom control bar (extracted from ContentView.safeAreaInset) to isolate rendering problems.
private struct RippleBottomBar: View {
    @Binding var selectedStyle: RippleVisualPreset
    @Binding var showStyleStudio: Bool
    let catalog: [RippleVisualPreset: RippleStyleEntry]

    var body: some View {
        let items: [PresetItem] = RippleVisualPreset.allCases.compactMap { preset in
            guard let entry = catalog[preset] else { return nil }
            return PresetItem(preset: preset, definition: entry.definition)
        }

        return VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        let isSelected = (item.preset == selectedStyle)
                        PresetPill(definition: item.definition,
                                   isSelected: isSelected) {
                            selectedStyle = item.preset
                        }
                    }
                }
                .padding(.horizontal, 12)
            }

            Button {
                showStyleStudio = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                    Text("Open Ripple Studio")
                }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08))
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

// Helper types to break up generics-heavy code and simplify main bar
private struct PresetItem: Identifiable {
    let preset: RippleVisualPreset
    let definition: RippleStyleDefinition
    var id: RippleVisualPreset { preset }
}

/// A small, self-contained "pill" button for a preset. Extracted to reduce
/// type-check complexity in the main bottom bar.
private struct PresetPill: View {
    let definition: RippleStyleDefinition
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: definition.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text(definition.title)
                        .font(.footnote)
                        .fontWeight(.semibold)
                    Text(definition.subtitle)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    // Base material background
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                    // Selected tint overlay, separated so the conditional doesn't live
                    // inside a complex ShapeStyle generic.
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(definition.accent.opacity(0.85))
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

struct RippleStyleControlPanel: View {
    @Binding var selection: RippleVisualPreset
    @Binding var styleStates: [RippleVisualPreset: StyleRuntimeState]
    let catalog: [RippleVisualPreset: RippleStyleEntry]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                stylePickerSection

                if let binding = binding(for: selection),
                   let entry = catalog[selection] {
                    waveParameterSection(binding: binding)
                    if entry.defaultState.prism != nil,
                       let prismBinding = binding.prismBinding(default: entry.defaultState.prism) {
                        prismSection(binding: prismBinding)
                    }
                    if entry.defaultState.glow != nil,
                       let glowBinding = binding.glowBinding(default: entry.defaultState.glow) {
                        glowSection(binding: glowBinding)
                    }
                }
            }
            .navigationTitle("Ripple Studio")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var stylePickerSection: some View {
        Section("Style") {
            Picker("Visual Style", selection: $selection) {
                ForEach(RippleVisualPreset.allCases) { preset in
                    if let definition = catalog[preset]?.definition {
                        Text(definition.title).tag(preset)
                    }
                }
            }
            .pickerStyle(.segmented)

            if let definition = catalog[selection]?.definition {
                Text(definition.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func waveParameterSection(binding: Binding<StyleRuntimeState>) -> some View {
        Section {
            ParameterSliderRow("Amplitude",
                               value: binding.parameterBinding(\RippleParameters.amplitude),
                               range: 6...26,
                               step: 0.5,
                               suffix: " pt")
            ParameterSliderRow("Wavelength",
                               value: binding.parameterBinding(\RippleParameters.wavelength),
                               range: 100...220,
                               step: 1,
                               suffix: " pt")
            ParameterSliderRow("Speed",
                               value: binding.parameterBinding(\RippleParameters.speed),
                               range: 0.8...3.0,
                               step: 0.05,
                               suffix: " ×")
            ParameterSliderRow("Ring width",
                               value: binding.parameterBinding(\RippleParameters.ringWidth),
                               range: 20...72,
                               step: 1,
                               suffix: " pt")
            ParameterSliderRow("Decay",
                               value: binding.parameterBinding(\RippleParameters.decay),
                               range: 0.8...2.6,
                               step: 0.05,
                               suffix: " ×")
        } footer: {
            Text("These settings mirror the classic multi-ripple behaviour. Adjust them to fine-tune the wave physics for any style.")
        }
    }

    private func prismSection(binding: Binding<RipplePrismConfiguration>) -> some View {
        
        Section {
            ParameterSliderRow("Refraction",
                               value: binding.binding(for: \.refractionStrength),
                               range: 0.2...1.4,
                               step: 0.02)
            ParameterSliderRow("Dispersion",
                               value: binding.binding(for: \.dispersion),
                               range: 0...1.2,
                               step: 0.02)
            ParameterSliderRow("Tint mix",
                               value: binding.binding(for: \.tintStrength),
                               range: 0...1,
                               step: 0.02)
            ColorPicker("Tint colour",
                        selection: Binding(
                            get: { binding.wrappedValue.tintColor },
                            set: { binding.wrappedValue.tintColor = $0 }
                        ))
        } footer: {
            Text("Refraction bends the background image, while dispersion separates colour channels for a glassy fringe.")
        }
    }

    private func glowSection(binding: Binding<RippleGlowConfiguration>) -> some View {
        Section {
            ParameterSliderRow("Glow strength",
                               value: binding.binding(for: \.glowStrength),
                               range: 0...1.8,
                               step: 0.02)
            ParameterSliderRow("Highlight focus",
                               value: binding.binding(for: \.highlightPower),
                               range: 0.6...3.0,
                               step: 0.05)
            ParameterSliderRow("Halo lift",
                               value: binding.binding(for: \.highlightBoost),
                               range: 0...3.0,
                               step: 0.05)
            ColorPicker("Glow colour",
                        selection: Binding(
                            get: { binding.wrappedValue.glowColor },
                            set: { binding.wrappedValue.glowColor = $0 }
                        ))
        } footer: {
            Text("Tune the bloom that trails each crest. Increase glow strength for brighter waves or halo lift for a softer aura.")
        }
    }

    private func binding(for preset: RippleVisualPreset) -> Binding<StyleRuntimeState>? {
        guard let entry = catalog[preset] else { return nil }
        return Binding(
            get: { styleStates[preset] ?? entry.defaultState },
            set: { styleStates[preset] = $0 }
        )
    }
}

private struct ParameterSliderRow: View {
    let title: String
    let value: Binding<CGFloat>
    let range: ClosedRange<CGFloat>
    let step: CGFloat
    let suffix: String

    init(_ title: String,
         value: Binding<CGFloat>,
         range: ClosedRange<CGFloat>,
         step: CGFloat,
         suffix: String = "") {
        self.title = title
        self.value = value
        self.range = range
        self.step = max(step, 0.001)
        self.suffix = suffix
    }

    private var formattedValue: String {
        let val = value.wrappedValue
        if step >= 1 {
            return String(format: "%.0f%@", val, suffix)
        } else if step >= 0.1 {
            return String(format: "%.1f%@", val, suffix)
        } else {
            return String(format: "%.2f%@", val, suffix)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(formattedValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(
                get: { Double(value.wrappedValue) },
                set: { value.wrappedValue = CGFloat($0) }
            ), in: Double(range.lowerBound)...Double(range.upperBound), step: Double(step))
        }
        .padding(.vertical, 4)
    }
}

private extension Binding where Value == StyleRuntimeState {
    func parameterBinding(_ keyPath: WritableKeyPath<RippleParameters, CGFloat>) -> Binding<CGFloat> {
        Binding<CGFloat>(
            get: { self.wrappedValue.parameters[keyPath: keyPath] },
            set: { self.wrappedValue.parameters[keyPath: keyPath] = $0 }
        )
    }

    func prismBinding(default defaultValue: RipplePrismConfiguration?) -> Binding<RipplePrismConfiguration>? {
        guard let defaultValue else { return nil }
        return Binding<RipplePrismConfiguration>(
            get: { self.wrappedValue.prism ?? defaultValue },
            set: { newValue in
                self.wrappedValue.prism = newValue
                self.wrappedValue.glow = nil
            }
        )
    }

    func glowBinding(default defaultValue: RippleGlowConfiguration?) -> Binding<RippleGlowConfiguration>? {
        guard let defaultValue else { return nil }
        return Binding<RippleGlowConfiguration>(
            get: { self.wrappedValue.glow ?? defaultValue },
            set: { newValue in
                self.wrappedValue.glow = newValue
                self.wrappedValue.prism = nil
            }
        )
    }
}

private extension Binding where Value == RipplePrismConfiguration {
    func binding(for keyPath: WritableKeyPath<RipplePrismConfiguration, CGFloat>) -> Binding<CGFloat> {
        Binding<CGFloat>(
            get: { self.wrappedValue[keyPath: keyPath] },
            set: { self.wrappedValue[keyPath: keyPath] = $0 }
        )
    }
}

private extension Binding where Value == RippleGlowConfiguration {
    func binding(for keyPath: WritableKeyPath<RippleGlowConfiguration, CGFloat>) -> Binding<CGFloat> {
        Binding<CGFloat>(
            get: { self.wrappedValue[keyPath: keyPath] },
            set: { self.wrappedValue[keyPath: keyPath] = $0 }
        )
    }
}

#Preview {
    ContentView()
}
