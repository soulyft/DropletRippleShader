#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

#include "RippleCommon.metal"

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
    if (rippleScalarInvalid(wavelength) || rippleScalarInvalid(speed) || rippleScalarInvalid(ringWidth) ||
        rippleScalarInvalid(refractionStrength) || rippleScalarInvalid(dispersion) || rippleScalarInvalid(tintStrength)) {
        return layer.sample(position);
    }

    if (rippleData == nullptr || rippleFloatCount < 4) {
        return layer.sample(position);
    }

    const float safeWavelength = rippleSafeWavelength(wavelength);
    const float safeRing = rippleSafeRingWidth(ringWidth);
    const float safeRefraction = clamp(refractionStrength, 0.0, 3.0);
    const float safeDispersion = clamp(dispersion, 0.0, 2.0);
    const float safeTint = clamp(tintStrength, 0.0, 1.0);
    const float falloffRadius = rippleFalloffRadius(size);

    int limitedFloatCount = rippleLimitFloatCount(rippleFloatCount);
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

        if (rippleScalarInvalid(cx) || rippleScalarInvalid(cy) || rippleScalarInvalid(age) || rippleScalarInvalid(amp) || amp <= 0.0001) {
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
        float wave  = sin(phase * rippleTau);
        float waveFront = max(0.0, (age * speed) * safeWavelength);
        float k = (dist - waveFront) / safeRing;
        float envelope = exp(-k * k);
        float globalFalloff = exp(-dist / falloffRadius);
        float disp = wave * amp * envelope * globalFalloff;

        disp = rippleClampDisplacement(disp, safeWavelength);

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
