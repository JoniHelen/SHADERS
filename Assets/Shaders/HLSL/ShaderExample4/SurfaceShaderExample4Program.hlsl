#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
// Lighting needs to be included

struct Attributes {
    float3 positionOS : POSITION;
    float2 uv0 :TEXCOORD0;
    float3 normalOS : NORMAL;
};

struct Varyings {
    float4 positionHCS : SV_POSITION;
    float2 uv :TEXCOORD0;
    float3 normalWS : TEXCOORD1; // We will use the second interpolator for normal data.
};

TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

CBUFFER_START(UnityPerMaterial)
    float4 _BaseMap_ST;
    half4 _BaseColor;
CBUFFER_END

Varyings Vertex(const Attributes input) {
    Varyings output;

    output.positionHCS = TransformObjectToHClip(input.positionOS);
    output.uv = TRANSFORM_TEX(input.uv0, _BaseMap);
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    // We need the normals to be in world space to calculate lighting.

    return output;
}

half4 Fragment(const Varyings input) : SV_TARGET {
    const half4 texColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
    // The lighting include contains everything you need to calculate lights for Unity.
    // However, we will do it ourselves for now.

    const Light light = GetMainLight(); // function from the lighting library

    const half NdotL = saturate(dot(input.normalWS, light.direction)); // Basic Lambertian diffuse
    
    return NdotL * half4(light.color, 1) * texColor * _BaseColor;
}