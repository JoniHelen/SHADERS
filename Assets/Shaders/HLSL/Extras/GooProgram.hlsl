#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

struct Attributes {
    float3 positionOS : POSITION;
    float2 uv0 :TEXCOORD0;
    float2 uv1 :TEXCOORD1;
    float2 uv2 :TEXCOORD2;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
    float4 positionHCS : SV_POSITION;
    float2 uv :TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    float3 normalWS : TEXCOORD2;
    float4 tangentWS : TEXCOORD3;
    half  fogFactor : TEXCOORD4;
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, sh, 5);
    #if defined(DYNAMICLIGHTMAP_ON)
    float2  dynamicLightmapUV : TEXCOORD6;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

CBUFFER_START(UnityPerMaterial)
    float _Smoothness;
    float _RayBias;
    float _DepthBias;
    float4 _BaseColor;
CBUFFER_END

Varyings Vertex(const Attributes input) {
    Varyings output;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    
    VertexPositionInputs vertPos = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs vertNormals = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    output.positionHCS = vertPos.positionCS;
    output.positionWS = vertPos.positionWS;
    output.uv = input.uv0;

    output.normalWS = vertNormals.normalWS;
    output.tangentWS = float4(vertNormals.tangentWS.xyz, input.tangentOS.w * GetOddNegativeScale());

    half fogFactor = 0;
    #if !defined(_FOG_FRAGMENT)
    fogFactor = ComputeFogFactor(input.positionHCS.z);
    #endif
    
    OUTPUT_LIGHTMAP_UV(input.uv1, unity_LightmapST, output.staticLightmapUV);
    #if defined(DYNAMICLIGHTMAP_ON)
    output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif
    OUTPUT_SH(output.normalWS.xyz, output.sh);
    output.fogFactor = fogFactor;
    return output;
}

#include "../Common/CommonGoo.hlsl"

half4 Raymarch(Varyings v) {
    
    half3 positionOS = TransformWorldToObject(v.positionWS);
    half3 viewDirOS = -GetObjectSpaceNormalizeViewDir(positionOS);

    #include "../Common/CommonGooRaymarch.hlsl"
}

half4 Fragment(Varyings input) : SV_TARGET {
    half4 raymarchCol = Raymarch(input);
    
    if (raymarchCol.a == 0) {
        clip(-1);
    }

    return raymarchCol;
}