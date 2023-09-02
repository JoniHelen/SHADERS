#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

struct Attributes {
    float3 positionOS : POSITION;
    float2 uv0 :TEXCOORD0; // uv texture coordinates in each vertex
};

struct Varyings {
    float4 positionHCS : SV_POSITION;
    float2 uv :TEXCOORD0; // uv texture coordinates interpolated
};

// Define the texture as a 2D texture and specify a sampler for it.
// The TEXTURE2D and the SAMPLER macros are defined in one of the files referenced in Core.hlsl
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

CBUFFER_START(UnityPerMaterial)
    // For tiling and offset to work, it's necessary to declare the texture property with the _ST suffix in the 'CBUFFER' block.
    // The _ST suffix is necessary because Unity looks for the suffix when assigning the values.
    // The variable contains the information as tiling = xy, offset = zw
    float4 _BaseMap_ST;
    half4 _BaseColor;
CBUFFER_END

Varyings Vertex(const Attributes input) {
    Varyings output;

    output.positionHCS = TransformObjectToHClip(input.positionOS);
    output.uv = TRANSFORM_TEX(input.uv0, _BaseMap);
    // The TRANSFORM_TEX macro is defined in the Macros.hlsl file
    // When dealing with a single texture, it's easiest to use the macro,
    // but when using multiple textures, you need to scale the UV with the _ST variables
    return output;
}

half4 Fragment(const Varyings input) : SV_TARGET {
    // use the SAMPLE_TEXTURE2D macro to sample the texture:
    const half4 texColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
    // add the base color tint:
    return texColor * _BaseColor;
}