#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

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

float Fragment(const Varyings input, bool isFrontFace : FRONT_FACE_SEMANTIC) : SV_TARGET {
    const float usedDepth = Linear01Depth(input.positionHCS.z, _ZBufferParams);
    return usedDepth * (isFrontFace ? -1.0 : 1.0);
}