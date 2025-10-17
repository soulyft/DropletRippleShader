#include <metal_stdlib>
using namespace metal;

#include "RippleCommon.metal"

[[ stitchable ]]
float2 rippleCluster(float2 position,
                     float2 size,
                     float  wavelength,
                     float  speed,
                     float  ringWidth,
                     constant float *rippleData,
                     int    rippleFloatCount)
{
    if (rippleScalarInvalid(wavelength) || rippleScalarInvalid(speed) || rippleScalarInvalid(ringWidth) ||
        rippleScalarInvalid(size.x) || rippleScalarInvalid(size.y)) {
        return position;
    }

    if (rippleData == nullptr || rippleFloatCount < 4) {
        return position;
    }

    const float safeWavelength = rippleSafeWavelength(wavelength);
    const float safeRing = rippleSafeRingWidth(ringWidth);
    const float falloffRadius = rippleFalloffRadius(size);

    int limitedFloatCount = rippleLimitFloatCount(rippleFloatCount);
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

        if (rippleScalarInvalid(cx) || rippleScalarInvalid(cy) ||
            rippleScalarInvalid(age) || rippleScalarInvalid(amp) ||
            amp <= 0.0001) {
            continue;
        }

        if (amp < 0.001) {
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
    }

    const float maxTotalDisp = 0.8 * safeWavelength;
    float totalLength = length(totalOffset);
    if (totalLength > maxTotalDisp && totalLength > 0.0) {
        totalOffset *= (maxTotalDisp / totalLength);
    }

    return position + totalOffset;
}
