#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

#include "RippleCommon.metal"

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
    if (rippleScalarInvalid(wavelength) || rippleScalarInvalid(speed) || rippleScalarInvalid(ringWidth) ||
        rippleScalarInvalid(glowStrength) || rippleScalarInvalid(highlightPower) || rippleScalarInvalid(highlightBoost)) {
        return layer.sample(position);
    }

    if (rippleData == nullptr || rippleFloatCount < 4) {
        return layer.sample(position);
    }

    const float safeWavelength = rippleSafeWavelength(wavelength);
    const float safeRing = rippleSafeRingWidth(ringWidth);
    const float falloffRadius = rippleFalloffRadius(size);

    int limitedFloatCount = rippleLimitFloatCount(rippleFloatCount);
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

        if (rippleScalarInvalid(cx) || rippleScalarInvalid(cy) || rippleScalarInvalid(age) || rippleScalarInvalid(amp) || amp <= 0.0001) {
            continue;
        }

        float2 center = float2(cx, cy);
        float2 toPix  = position - center;
        float  dist   = length(toPix);

        if (!isfinite(dist)) {
            continue;
        }

        float phase = (dist / safeWavelength) - (age * speed);
        float wave  = sin(phase * rippleTau);
        float waveFront = max(0.0, (age * speed) * safeWavelength);
        float k = (dist - waveFront) / safeRing;
        float envelope = exp(-k * k);
        float globalFalloff = exp(-dist / falloffRadius);
        float disp = fabs(wave * amp * envelope * globalFalloff);

        disp = rippleClampPositiveDisplacement(disp, safeWavelength);

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
