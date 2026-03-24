#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

struct TraceVertex {
    simd_float2 position;   // clip-space [-1, 1]
    float       alpha;      // edge softening factor
    float       padding;    // pad to 16 bytes
};

struct RibbonUniforms {
    float       scrollOffset;    // cumulative pixels scrolled
    float       scrollRate;      // pixels per second (1.0)
    simd_float2 viewportSize;    // in pixels
    float       traceYCenter;    // normalized Y center of trace (0.5)
    float       time;            // elapsed seconds since start
    float       padding0;
    float       padding1;
};

struct TimeMarkerVertex {
    simd_float2 position;   // clip-space
    simd_float2 texCoord;   // for label texture sampling
};

// Used in Pass 5: event annotation leader lines and labels.
struct AnnotationVertex {
    simd_float2 position;    // clip-space [-1, 1]
    simd_float2 texCoord;    // [0,1] for labels; (0,0) for leader lines
    simd_float4 tintColor;   // event tint (warm red or gray)
    float        opacity;    // fade-in 0→1 over 30 frames
    float        padding[3]; // pad to 48 bytes
};

#endif
