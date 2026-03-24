#include <metal_stdlib>
using namespace metal;
#include "ShaderTypes.h"

// MARK: - Vertex Output Types

struct ParchmentVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct TraceVertexOut {
    float4 position [[position]];
    float  alpha;
};

struct CompositeVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct LabelVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// MARK: - Full-Screen Quad Positions

constant float2 quadPositions[6] = {
    float2(-1, -1), float2(1, -1), float2(-1, 1),
    float2(-1, 1),  float2(1, -1), float2(1, 1)
};

constant float2 quadTexCoords[6] = {
    float2(0, 1), float2(1, 1), float2(0, 0),
    float2(0, 0), float2(1, 1), float2(1, 0)
};

// MARK: - Pass 1: Parchment Background

vertex ParchmentVertexOut parchmentVertex(
    uint vid [[vertex_id]],
    constant RibbonUniforms& uniforms [[buffer(0)]]
) {
    ParchmentVertexOut out;
    out.position = float4(quadPositions[vid], 0, 1);

    float2 uv = quadTexCoords[vid];
    // Scale UV to tile the 1024px texture across viewport
    uv.x *= uniforms.viewportSize.x / 1024.0;
    uv.y *= uniforms.viewportSize.y / 1024.0;
    // Shift by scroll offset for continuous scrolling
    uv.x += uniforms.scrollOffset / 1024.0;

    out.texCoord = uv;
    return out;
}

fragment float4 parchmentFragment(
    ParchmentVertexOut in [[stage_in]],
    texture2d<float> parchment [[texture(0)]]
) {
    constexpr sampler s(filter::linear, address::repeat);
    return parchment.sample(s, in.texCoord);
}

// MARK: - Pass 2: Trace Polyline

vertex TraceVertexOut traceVertex(
    const device TraceVertex* vertices [[buffer(0)]],
    uint vid [[vertex_id]]
) {
    TraceVertexOut out;
    out.position = float4(vertices[vid].position, 0, 1);
    out.alpha = vertices[vid].alpha;
    return out;
}

fragment float4 traceFragment(TraceVertexOut in [[stage_in]]) {
    // Warm near-black ink: RGB(20, 15, 10)
    return float4(20.0 / 255.0, 15.0 / 255.0, 10.0 / 255.0, in.alpha);
}

// MARK: - Pass 3: Gaussian Blur Compute (1D horizontal, sigma=1.5, 5-tap)

constant float blurWeights[5] = { 0.0545, 0.2442, 0.4026, 0.2442, 0.0545 };

kernel void gaussianBlurHorizontal(
    texture2d<float, access::read>  src [[texture(0)]],
    texture2d<float, access::write> dst [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint width = src.get_width();
    uint height = src.get_height();
    if (gid.x >= width || gid.y >= height) return;

    float4 sum = float4(0);
    for (int i = -2; i <= 2; i++) {
        uint x = uint(clamp(int(gid.x) + i, 0, int(width) - 1));
        sum += src.read(uint2(x, gid.y)) * blurWeights[i + 2];
    }
    dst.write(sum, gid);
}

// MARK: - Pass 4: Composite (parchment + trace + time markers)

vertex CompositeVertexOut compositeVertex(
    uint vid [[vertex_id]],
    constant RibbonUniforms& uniforms [[buffer(0)]]
) {
    CompositeVertexOut out;
    out.position = float4(quadPositions[vid], 0, 1);
    out.texCoord = quadTexCoords[vid];
    return out;
}

fragment float4 compositeFragment(
    CompositeVertexOut in [[stage_in]],
    constant RibbonUniforms& uniforms [[buffer(0)]],
    texture2d<float> parchmentLayer [[texture(0)]],
    texture2d<float> traceLayer [[texture(1)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);

    float4 parchment = parchmentLayer.sample(s, in.texCoord);
    float4 trace = traceLayer.sample(s, in.texCoord);

    // Alpha-blend trace over parchment
    float3 color = mix(parchment.rgb, trace.rgb, trace.a);

    // Time markers: thin vertical lines every 60px
    float pixelX = in.texCoord.x * uniforms.viewportSize.x;
    float markerPos = fmod(pixelX + uniforms.scrollOffset, 60.0);
    // Anti-aliased 0.5px line
    float markerAlpha = 1.0 - smoothstep(0.0, 1.0, abs(markerPos));
    float3 markerColor = float3(20.0 / 255.0, 15.0 / 255.0, 10.0 / 255.0);
    color = mix(color, markerColor, markerAlpha * 0.35);

    return float4(color, 1.0);
}

// MARK: - Label Rendering

vertex LabelVertexOut labelVertex(
    const device TimeMarkerVertex* vertices [[buffer(0)]],
    uint vid [[vertex_id]]
) {
    LabelVertexOut out;
    out.position = float4(vertices[vid].position, 0, 1);
    out.texCoord = vertices[vid].texCoord;
    return out;
}

fragment float4 labelFragment(
    LabelVertexOut in [[stage_in]],
    texture2d<float> labelTexture [[texture(0)]]
) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float4 texColor = labelTexture.sample(s, in.texCoord);
    // Label text is pre-rendered with alpha; use warm ink color
    float3 inkColor = float3(20.0 / 255.0, 15.0 / 255.0, 10.0 / 255.0);
    return float4(inkColor, texColor.a);
}
