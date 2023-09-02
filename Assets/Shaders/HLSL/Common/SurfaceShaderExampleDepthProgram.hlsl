// GPU Instancing
#pragma multi_compile_instancing

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// We only need to output the interpolated clip space position

struct Attributes {
    float3 positionOS : POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
    float4 positionHCS : SV_POSITION;
};

Varyings Vertex(const Attributes input) {
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    output.positionHCS = TransformObjectToHClip(input.positionOS);
    return output;
}

float Fragment(const Varyings input) : SV_TARGET {
    return input.positionHCS.z;
}