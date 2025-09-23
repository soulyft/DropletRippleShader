//
//  Ripple.metal
//  DropletRippleTest
//
//  Created by Corey Lofthus on 9/22/25.
//
#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/*
    Full-screen ripple distortion.
    Parameters:
      - size:      view size in pixels
      - center:    ripple origin in pixels
      - time:      seconds since touch began
      - speed:     wave temporal frequency multiplier
      - wavelength:distance between crests in pixels
      - amplitude: peak outward displacement in pixels (already decayed on Swift side)

    Returns a new sampling position (float2) per pixel.
    This must be used with SwiftUI's distortionEffect modifier.
*/
[[ stitchable ]]
float2 ripple(float2 position,
              float2 size,
              float2 center,
              float  time,
              float  speed,
              float  wavelength,
              float  amplitude,
              float  ringWidth)
{
    // Safety: pass-through if inputs are not sane
    if (!isfinite(time) || !isfinite(speed) || !isfinite(wavelength) || !isfinite(amplitude) || !isfinite(ringWidth) || amplitude <= 0.0001 || ringWidth <= 0.0001) {
        return position;
    }

    // Vector from ripple center to current pixel
    float2 toPix = position - center;
    float dist   = length(toPix);

    // Avoid division by zero exactly at the center
    float2 dir = (dist > 1e-4) ? (toPix / dist) : float2(0.0, 0.0);

    // Radial phase: sin( 2π * (dist / wavelength - time * speed) )
    const float tau = 6.28318530718; // 2π
    float phase = (dist / max(wavelength, 1.0)) - (time * speed);
    float wave  = sin(phase * tau);

    // Moving ring envelope: strongest where dist ≈ waveFront, fades elsewhere
    // Wavefront distance grows over time at speed * wavelength per second
    float waveFront = max(0.0, (time * speed) * wavelength);
    // Gaussian falloff around the wavefront; ringWidth controls thickness (in px)
    float k = (dist - waveFront) / max(ringWidth, 1.0);
    float envelope = exp(-k * k); // 1.0 at the crest, ~0 away from it

    // Optional global falloff with distance to keep far-away pixels stable
    float globalFalloff = exp(-dist / (0.9 * max(size.x, size.y)));

    // Final displacement (in pixels). Keep it modest to avoid edge sampling.
    float disp = wave * amplitude * envelope * globalFalloff;

    return position + dir * disp;
}
