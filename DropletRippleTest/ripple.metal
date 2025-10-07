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

    // Clamp to capacity; convert float count to ripple count (4 floats per ripple)
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

[[ stitchable ]]
half4 rippleClusterPrismColor(float2 position,
                              SwiftUI::Layer layer,
                              float2 size,
                              float  wavelength,
                              float  speed,
                              float  ringWidth,
                              float  refractionStrength,
                              float  dispersion,
                              float  tintStrength,
                              float3 tintColor,
                              constant float *rippleData,
                              int    rippleFloatCount)
{
    if (!isfinite(wavelength) || !isfinite(speed) || !isfinite(ringWidth) ||
        !isfinite(refractionStrength) || !isfinite(dispersion) || !isfinite(tintStrength)) {
        return layer.sample(position);
    }

    if (rippleData == nullptr || rippleFloatCount < 4) {
        return layer.sample(position);
    }

    const float tau = 6.28318530718;
    const float safeWavelength = max(wavelength, 1.0);
    const float safeRing = max(ringWidth, 1.0);
    const float safeRefraction = clamp(refractionStrength, 0.0, 3.0);
    const float safeDispersion = clamp(dispersion, 0.0, 2.0);
    const float safeTint = clamp(tintStrength, 0.0, 1.0);
    const float falloffRadius = 0.5 * length(size);

    int limitedFloatCount = clamp(rippleFloatCount, 0, 64 * 4);
    int count = limitedFloatCount / 4;
    if (count <= 0) {
        return layer.sample(position);
    }

    float2 totalOffset = float2(0.0, 0.0);
    float maxEnvelope = 0.0;
    float totalMagnitude = 0.0;

    for (int i = 0; i < count; ++i) {
        int baseIndex = i * 4;
        if ((baseIndex + 3) >= limitedFloatCount) {
            break;
        }

        float cx  = rippleData[baseIndex + 0];
        float cy  = rippleData[baseIndex + 1];
        float age = rippleData[baseIndex + 2];
        float amp = rippleData[baseIndex + 3];

        if (!isfinite(cx) || !isfinite(cy) || !isfinite(age) || !isfinite(amp) || amp <= 0.0001) {
            continue;
        }

        float2 center = float2(cx, cy);
        float2 toPix  = position - center;
        float  dist   = length(toPix);

        if (!isfinite(dist)) {
            continue;
        }

        float2 dir = (dist > 1e-4) ? (toPix / dist) : float2(0.0, 0.0);

        float phase = (dist / safeWavelength) - (age * speed);
        float wave  = sin(phase * tau);
        float waveFront = max(0.0, (age * speed) * safeWavelength);
        float k = (dist - waveFront) / safeRing;
        float envelope = exp(-k * k);
        float globalFalloff = exp(-dist / falloffRadius);
        float disp = wave * amp * envelope * globalFalloff;

        const float maxDisp = 0.6 * safeWavelength;
        disp = clamp(disp, -maxDisp, maxDisp);

        totalOffset += dir * disp;
        maxEnvelope = max(maxEnvelope, envelope);
        totalMagnitude += fabs(disp);
    }

    half4 baseSample = layer.sample(position);

    float crestInfluence = clamp(maxEnvelope, 0.0, 1.0);
    float averageMagnitude = totalMagnitude / (safeWavelength * max(1.0, float(count)));
    float intensity = clamp(0.6 * crestInfluence + 0.4 * averageMagnitude, 0.0, 1.25);

    float2 refractOffset = totalOffset * safeRefraction;
    float2 offsetR = position + refractOffset * (1.0 + safeDispersion);
    float2 offsetG = position + refractOffset;
    float2 offsetB = position + refractOffset * (1.0 - safeDispersion);

    half prismR = layer.sample(offsetR).r;
    half prismG = layer.sample(offsetG).g;
    half prismB = layer.sample(offsetB).b;

    half3 refracted = half3(prismR, prismG, prismB);
    half3 tinted = mix(refracted, refracted * half3(tintColor), half(safeTint));
    half mixAmount = half(clamp(intensity, 0.0, 1.0));
    half3 finalRGB = mix(baseSample.rgb, tinted, mixAmount);
    finalRGB = clamp(finalRGB, half3(0.0), half3(1.0));

    return half4(finalRGB, baseSample.a);
}

[[ stitchable ]]
half4 rippleClusterGlowColor(float2 position,
                             SwiftUI::Layer layer,
                             float2 size,
                             float  wavelength,
                             float  speed,
                             float  ringWidth,
                             float  glowStrength,
                             float  highlightPower,
                             float  highlightBoost,
                             float3 glowColor,
                             constant float *rippleData,
                             int    rippleFloatCount)
{
    if (!isfinite(wavelength) || !isfinite(speed) || !isfinite(ringWidth) ||
        !isfinite(glowStrength) || !isfinite(highlightPower) || !isfinite(highlightBoost)) {
        return layer.sample(position);
    }

    if (rippleData == nullptr || rippleFloatCount < 4) {
        return layer.sample(position);
    }

    const float tau = 6.28318530718;
    const float safeWavelength = max(wavelength, 1.0);
    const float safeRing = max(ringWidth, 1.0);
    const float falloffRadius = 0.5 * length(size);

    int limitedFloatCount = clamp(rippleFloatCount, 0, 64 * 4);
    int count = limitedFloatCount / 4;
    if (count <= 0) {
        return layer.sample(position);
    }

    float maxEnvelope = 0.0;
    float energyAccum = 0.0;

    for (int i = 0; i < count; ++i) {
        int baseIndex = i * 4;
        if ((baseIndex + 3) >= limitedFloatCount) {
            break;
        }

        float cx  = rippleData[baseIndex + 0];
        float cy  = rippleData[baseIndex + 1];
        float age = rippleData[baseIndex + 2];
        float amp = rippleData[baseIndex + 3];

        if (!isfinite(cx) || !isfinite(cy) || !isfinite(age) || !isfinite(amp) || amp <= 0.0001) {
            continue;
        }

        float2 center = float2(cx, cy);
        float2 toPix  = position - center;
        float  dist   = length(toPix);

        if (!isfinite(dist)) {
            continue;
        }

        float phase = (dist / safeWavelength) - (age * speed);
        float wave  = sin(phase * tau);
        float waveFront = max(0.0, (age * speed) * safeWavelength);
        float k = (dist - waveFront) / safeRing;
        float envelope = exp(-k * k);
        float globalFalloff = exp(-dist / falloffRadius);
        float disp = fabs(wave * amp * envelope * globalFalloff);

        const float maxDisp = 0.6 * safeWavelength;
        disp = clamp(disp, 0.0, maxDisp);

        maxEnvelope = max(maxEnvelope, envelope);
        energyAccum += disp;
    }

    half4 baseSample = layer.sample(position);

    float energy = clamp(energyAccum / (safeWavelength * max(1.0, float(count))), 0.0, 1.5);
    float crest = clamp(maxEnvelope, 0.0, 1.0);
    float glow = clamp(glowStrength, 0.0, 3.0) * energy;
    float highlight = pow(crest, max(0.5, highlightPower));
    float halo = highlight * clamp(highlightBoost, 0.0, 3.0);

    half3 tint = half3(glowColor);
    half3 additive = tint * half(glow + halo);
    half3 result = clamp(baseSample.rgb + additive, half3(0.0), half3(1.0));

    return half4(result, baseSample.a);
}
