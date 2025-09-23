//
//  ContentView.swift
//  DropletRippleTest
//
//  Created by Corey Lofthus on 9/22/25.
//

import SwiftUI

/// A simple "home screen" with tappable icons. Tapping triggers a full-screen ripple.
struct ContentView: View {
    // Ripple parameters
    @State private var rippleCenter: CGPoint = .zero
    @State private var rippleStart = Date()
    @State private var isRippling = false

    // Tweakables (pixels / seconds)
    private let amplitudePx: CGFloat = 12      // initial displacement in px
    private let wavelengthPx: CGFloat = 140    // distance between ripple crests
    private let speed: CGFloat = 2.2        // wave speed factor
    private let decay: CGFloat = 1.6           // how fast amplitude decays over time
    private let ringWidthPx: CGFloat = 36      // thickness of the moving ring

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
        GeometryReader { screenGeo in
            // Base content that always renders (no frame-by-frame updates)
            let base = ZStack {
                HomeGrid(
                    icons: icons,
                    onIconTap: { iconFrameInScreen in
                        rippleCenter = CGPoint(x: iconFrameInScreen.midX, y: iconFrameInScreen.midY)
                        rippleStart = Date()
                        isRippling = true
                    }
                )
                Rectangle()
                .ignoresSafeArea()
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.5) ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                   
                   
                )
            }
            
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            // Tapping anywhere fires a ripple
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        rippleCenter = value.location
                        rippleStart = Date()
                        isRippling = true
                    }
            )

            Group {
                if isRippling {
                    TimelineView(.animation) { ctx in
                        let elapsed = rippleStart.distance(to: ctx.date)
                        let center = rippleCenter
                        let ampNow = max(0, amplitudePx * exp(-decay * elapsed))
                        let enabled = ampNow > 0.25

                        base
                            .visualEffect { effects, proxy in
                                let size = proxy.size
                                return effects
                                    .distortionEffect(
                                        ShaderLibrary.ripple(
                                            .float2(size),
                                            .float2(center),
                                            .float(Float(elapsed)),
                                            .float(Float(speed)),
                                            .float(Float(wavelengthPx)),
                                            .float(Float(ampNow)),
                                            .float(Float(ringWidthPx))
                                        ),
                                        maxSampleOffset: CGSize(width: amplitudePx, height: amplitudePx),
                                        isEnabled: enabled
                                    )
                            }
                            .onChange(of: elapsed) { old, newValue in
                                if newValue > 4 { isRippling = false }
                            }
                    }
                } else {
                    base
                }
            }
           
        }
       
    }
}

struct IconData: Identifiable {
    let id: Int
    let systemName: String
    let title: String
}

/// A grid of individual icon views.
/// Each icon calculates its own frame in screen space and reports it up when tapped.
struct HomeGrid: View {
    let icons: [IconData]
    let onIconTap: (CGRect) -> Void

    // A nice, iOS-like grid
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 24, alignment: .center), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(icons) { icon in
                IconTile(icon: icon) { frameInScreen in
                    onIconTap(frameInScreen)
                }
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
    }
}

/// A single "app icon" tile. Tapping it reports its frame (in screen coords) upward.
struct IconTile: View {
    let icon: IconData
    let tapped: (CGRect) -> Void

    @State private var frameInScreen: CGRect = .zero

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
                // This reader does not affect layout; it just captures the global frame.
                Color.clear
                    .onAppear { frameInScreen = proxy.frame(in: .global) }
                    .onChange(of: proxy.size) { _ in
                        frameInScreen = proxy.frame(in: .global)
                    }
            }
        )
        .onTapGesture {
            tapped(frameInScreen)
        }
        .frame(height: 96) // grid cell height
    }
}

#Preview {
    ContentView()
}
