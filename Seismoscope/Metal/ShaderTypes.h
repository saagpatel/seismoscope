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

#endif
