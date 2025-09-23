//
//  ContentView.swift
//  DropletRippleTest
//
//  Created by Corey Lofthus on 9/22/25.
//

import SwiftUI

/// A simple "home screen" with tappable icons. Tapping triggers a full-screen ripple.
struct ContentView: View {
    @State private var rippleEngine = RippleEngine()

    private let rippleParameters = RippleParameters(
        amplitude: 12,
        wavelength: 140,
        speed: 2.2,
        decay: 1.6,
        ringWidth: 36,
        minimumAmplitude: 0.15,
        maximumSampleOffset: 72
    )

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
        ZStack {
            HomeGrid(
                icons: icons,
                coordinateSpace: .named(rippleSpaceName)
            ) { iconCenter in
                rippleEngine.emit(at: iconCenter)
            }

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .rippleField(engine: rippleEngine, parameters: rippleParameters)
        .coordinateSpace(name: rippleSpaceName)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    rippleEngine.emit(at: value.location)
                }
        )
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

    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    Image(systemName: icon.systemName)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.primary)
                )
                .frame(width: 64, height: 64)
                .shadow(radius: 2, y: 1)

            Text(icon.title)
                .font(.footnote)
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .background(
            GeometryReader { proxy in
                let frame = proxy.frame(in: coordinateSpace)

                Color.clear
                    .onAppear {
                        centerInSpace = CGPoint(x: frame.midX, y: frame.midY)
                    }
                    .onChange(of: frame) { newFrame in
                        centerInSpace = CGPoint(x: newFrame.midX, y: newFrame.midY)
                    }
            }
        )
        .onTapGesture {
            tapped(centerInSpace)
        }
        .frame(height: 96) // grid cell height
    }
}

#Preview {
    ContentView()
}
