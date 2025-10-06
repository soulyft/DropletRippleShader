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

/*
    Multi-ripple cluster distortion.
    Parameters:
      - position:    current pixel position in pixels
      - size:        view size in pixels
      - wavelength:  distance between wave crests in pixels (global)
      - speed:       wave temporal frequency multiplier (global)
      - ringWidth:   thickness of ripple rings in pixels (global)
      - rippleData:  array of ripple parameters per ripple, packed as [centerX, centerY, age, amplitude]
      - rippleFloatCount: number of floats provided in rippleData

    Returns the new sampling position (float2) after accumulating ripple displacements
    from multiple droplets. This function sums the effects of all active ripples,
    each with its own center, age, and amplitude, applying similar wave and envelope
    calculations as the single ripple function.
*/
[[ stitchable ]]
// Multi-ripple variant that accumulates contributions from several droplets.
float2 rippleCluster(float2 position,
                     float2 size,
                     float  wavelength,
                     float  speed,
                     float  ringWidth,
                     constant float *rippleData,
                     int    rippleFloatCount)
{
    // Global sanity guard for scalar params to avoid NaNs/Infs propagating
    if (!isfinite(wavelength) || !isfinite(speed) || !isfinite(ringWidth) ||
        !isfinite(size.x) || !isfinite(size.y)) {
        return position;
    }

    if (rippleData == nullptr || rippleFloatCount < 4) {
        return position;
    }

    const float tau = 6.28318530718; // 2π
    const float safeWavelength = max(wavelength, 1.0);
    const float safeRing = max(ringWidth, 1.0);
    // Use half the view diagonal; stronger falloff prevents oversampling at edges
    const float falloffRadius = 0.5 * length(size);
    int limitedFloatCount = clamp(rippleFloatCount, 0, 64 * 4);
    int count = limitedFloatCount / 4;

    float2 totalOffset = float2(0.0, 0.0);

    for (int i = 0; i < count; ++i) {
        int baseIndex = i * 4;
        if ((baseIndex + 3) >= limitedFloatCount) {
            break;
        }
        float  cx  = rippleData[baseIndex + 0];
        float  cy  = rippleData[baseIndex + 1];
        float  age = rippleData[baseIndex + 2];
        float  amp = rippleData[baseIndex + 3];

        // Per-ripple validation (skip invalid or negligible entries)
        if (!isfinite(cx) || !isfinite(cy) ||
            !isfinite(age) || !isfinite(amp) ||
            amp <= 0.0001) {
            continue;
        }

        // Skip ripples with extremely low amplitude that wouldn't contribute meaningfully
        if (amp < 0.001) {
            continue;
        }

        // Vector from ripple center to current pixel
        float2 center = float2(cx, cy);
        float2 toPix  = position - center;
        float  dist   = length(toPix);

        if (!isfinite(dist)) {
            continue;
        }

        // Avoid division by zero at center
        float2 dir   = (dist > 1e-4) ? (toPix / dist) : float2(0.0, 0.0);

        // Radial phase: sin( 2π * (dist / wavelength - age * speed) )
        float phase = (dist / safeWavelength) - (age * speed);
        float wave  = sin(phase * tau);

        // Moving ring envelope: strongest where dist ≈ waveFront, fades elsewhere
        // Wavefront distance grows over time at speed * wavelength per second
        float waveFront = max(0.0, (age * speed) * safeWavelength);
        // Gaussian falloff around the wavefront; ringWidth controls thickness (in px)
        float k = (dist - waveFront) / safeRing;
        float envelope = exp(-k * k);

        // Optional global falloff with distance to keep far-away pixels stable
        float globalFalloff = exp(-dist / falloffRadius);

        // Final displacement contribution from this ripple (in pixels)
        float disp = wave * amp * envelope * globalFalloff;

        // Clamp displacement to a safe range to prevent sampling completely off-content
        const float maxDisp = 0.6 * safeWavelength;
        disp = clamp(disp, -maxDisp, maxDisp);

        // Accumulate displacement vector
        totalOffset += dir * disp;
    }

    // Clamp total displacement magnitude to prevent extreme sampling offsets
    const float maxTotalDisp = 0.8 * safeWavelength;
    float totalLength = length(totalOffset);
    if (totalLength > maxTotalDisp && totalLength > 0.0) {
        totalOffset *= (maxTotalDisp / totalLength);
    }

    return position + totalOffset;
}
