#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

struct Attributes {
    float3 positionOS : POSITION;
};

struct Varyings {
    float4 positionHCS : SV_POSITION;
};

// To make the Unity shader SRP Batcher compatible, declare all
// properties related to a Material in a a single CBUFFER (constant buffer) block with
// the name UnityPerMaterial.
CBUFFER_START(UnityPerMaterial)
    // The following line declares the _BaseColor variable, so that you
    // can use it in the fragment shader.
    // The name must match exactly with the declaration in Parameters
    half4 _BaseColor;
CBUFFER_END

Varyings Vertex(const Attributes input) {
    Varyings output;
    output.positionHCS = TransformObjectToHClip(input.positionOS);
    return output;
}

half4 Fragment(Varyings input) : SV_TARGET {
    return _BaseColor; // We can use our color variable here
}