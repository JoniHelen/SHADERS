#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

struct Attributes {
    float3 positionOS : POSITION;
    float2 uv0 :TEXCOORD0;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT; // Tangent vector is needed for normal maps
};

struct Varyings {
    float4 positionHCS : SV_POSITION;
    float2 uv :TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float3 tangentWS : TEXCOORD2;
    float3 bitangentWS : TEXCOORD3;
};

TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

TEXTURE2D(_NormalMap);
SAMPLER(sampler_NormalMap);

CBUFFER_START(UnityPerMaterial)
    float4 _BaseMap_ST;
    float4 _NormalMap_ST;
    half4 _BaseColor;
CBUFFER_END

Varyings Vertex(const Attributes input) {
    Varyings output;

    // These functions do a bit of the spatial math for us
    // They are defined in ShaderVariablesFunctions.hlsl
    const VertexPositionInputs vertPos = GetVertexPositionInputs(input.positionOS);
    const VertexNormalInputs vertNormals = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    output.positionHCS = vertPos.positionCS;
    output.uv = TRANSFORM_TEX(input.uv0, _BaseMap);

    output.normalWS = vertNormals.normalWS;
    output.tangentWS = vertNormals.tangentWS;
    // Bitangent isn't required here because we could calculate it in fragment stage.
    // However, because we have interpolators to spare, we can reduce the calculations by
    // Doing them in the vertex stage.
    output.bitangentWS = vertNormals.bitangentWS;

    return output;
}

half4 Fragment(const Varyings input) : SV_TARGET {
    const half4 texColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);

    const Light light = GetMainLight();

    // sample the normal map, and decode from the Unity encoding
    const half3 texNormal = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv));
    // Transform the normal from tangent to world space for calculations
    // The transform function requires us to provide the tangent to world matrix ourselves
    const half3x3 tangentToWorld = half3x3(input.tangentWS, input.bitangentWS, input.normalWS);
    const half3 normalWS = TransformTangentToWorld(texNormal, tangentToWorld, true);

    const half NdotL = saturate(dot(normalWS, light.direction)); // Again, do the basic shading but with the new normals
    
    return NdotL * half4(light.color, 1) * texColor * _BaseColor;
}