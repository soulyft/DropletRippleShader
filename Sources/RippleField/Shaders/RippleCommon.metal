#ifndef RIPPLE_COMMON_METAL
#define RIPPLE_COMMON_METAL

#include <metal_stdlib>
using namespace metal;

constant float rippleTau = 6.28318530718f;
constant int rippleMaxFloatCount = 64 * 4;

inline bool rippleScalarInvalid(float value) {
    return !isfinite(value);
}

inline float rippleSafeWavelength(float wavelength) {
    return max(wavelength, 1.0);
}

inline float rippleSafeRingWidth(float ringWidth) {
    return max(ringWidth, 1.0);
}

inline float rippleFalloffRadius(float2 size) {
    return 0.5 * length(size);
}

inline int rippleLimitFloatCount(int rippleFloatCount) {
    return clamp(rippleFloatCount, 0, rippleMaxFloatCount);
}

inline float rippleClampDisplacement(float disp, float safeWavelength) {
    const float maxDisp = 0.6 * safeWavelength;
    return clamp(disp, -maxDisp, maxDisp);
}

inline float rippleClampPositiveDisplacement(float disp, float safeWavelength) {
    const float maxDisp = 0.6 * safeWavelength;
    return clamp(disp, 0.0, maxDisp);
}

#endif /* RIPPLE_COMMON_METAL */
