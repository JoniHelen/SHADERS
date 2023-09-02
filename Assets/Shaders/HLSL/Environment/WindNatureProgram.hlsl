#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "../Common/GrassColor.hlsl"

struct Attributes {
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 uv0 :TEXCOORD0;
    float2 uv1 :TEXCOORD1;
    float2 uv2 :TEXCOORD2;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
    float4 positionHCS : SV_POSITION;
    float2 uv :TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float3 positionWS : TEXCOORD2;
    float fogFactor : TEXCOORD3;
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 4);
    #ifdef DYNAMICLIGHTMAP_ON
    float2  dynamicLightmapUV : TEXCOORD5;
    #endif
};

TEXTURE2D(_LeafTexture);  SAMPLER(sampler_LeafTexture);
TEXTURE2D(_BarkTexture);  SAMPLER(sampler_BarkTexture);

#if defined(INSTANCING_ON)
float4 _LeafTexture_ST;
float4 _BarkTexture_ST;
float _WindStrength;
float _WindDirection;
float _WindSpeed;
float _WindScale;
half4 _FlowerColor;
half4 _LeafTint;
float _LeafSaturation;
float _LeafEmission;
float _TreeHeight;

UNITY_INSTANCING_BUFFER_START(Props)
UNITY_DEFINE_INSTANCED_PROP(float4x4, _TreeMatrix)
UNITY_DEFINE_INSTANCED_PROP(float4x4, _LeafMatrix)
UNITY_INSTANCING_BUFFER_END(Props)
#else
CBUFFER_START(UnityPerMaterial)
float4 _LeafTexture_ST;
float4 _BarkTexture_ST;
float _WindStrength;
float _WindDirection;
float _WindSpeed;
float _WindScale;
half4 _FlowerColor;
half4 _LeafTint;
float _LeafSaturation;
float _LeafEmission;
float _TreeHeight;
float4x4 _TreeMatrix;
float4x4 _LeafMatrix;
CBUFFER_END
#endif

#define DEG_TO_RAD 0.0174532925

float2 AngleToDir(const float angle) {
    const float rad = angle * DEG_TO_RAD;
    return float2(cos(rad), sin(rad));
}

// Creates deterministic gradient noise along world space coordinates
float WorldPositionOffset(const float3 positionWS) {
    return GradientNoiseDeterministic(positionWS.xz + _Time.y * _WindSpeed * AngleToDir(_WindDirection), _WindScale);
}

void InitializeInputData(const Varyings input, out InputData inputData) {
    inputData = (InputData)0;
    inputData.positionWS = input.positionWS;
    inputData.normalWS = input.normalWS;
    inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
#if defined(DYNAMICLIGHTMAP_ON)
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
#else
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
#endif
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionHCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
}

inline void InitializeSurfaceData(const float3 positionWS, const float2 uv, out SurfaceData surfaceData) {
    surfaceData = (SurfaceData)0;
    surfaceData.alpha = 1;
    half3 finalColor;
    const half3 mainLightColor = GetMainLight().color;

    // Get the grass / flower stem color
    #if defined(_OBJECTTYPE_GRASS) || defined(_OBJECTTYPE_FLOWER)
    const half3 grassColor = GrassColorWS(_WindScale, positionWS);
    const half3 emissionColor = abs(WorldPositionOffset(positionWS) - 0.5) * mainLightColor * grassColor;
    const float colorMask = smoothstep(0.14, 0.93, uv.y);
    const half3 baseGrassColor = saturate(colorMask + 0.75) * grassColor;
    const half3 highlightGrassColor = 1.0 - (1.0 - emissionColor) * (1.0 - grassColor);
    finalColor = lerp(baseGrassColor, highlightGrassColor, colorMask);

    // Add the flower petal color
    #if defined(_OBJECTTYPE_FLOWER)
    const half3 flowerColor = lerp(_FlowerColor * 0.85, _FlowerColor, smoothstep(0, 0.6, uv.y));
    finalColor = lerp(flowerColor, finalColor, step(0.5, uv.x));
    #endif

    // Sample tree texture for trees
    #elif defined(_OBJECTTYPE_TREE)
    finalColor = SAMPLE_TEXTURE2D(_BarkTexture, sampler_BarkTexture, uv);
    #else
    // Compute leaf color
    const half4 leafTexColor = SAMPLE_TEXTURE2D(_LeafTexture, sampler_LeafTexture, uv);
    clip(leafTexColor.a - 0.7);
    finalColor = Desaturate(leafTexColor.rgb, _LeafSaturation) * _LeafTint;
    surfaceData.emission = finalColor * mainLightColor * _LeafEmission;
    surfaceData.alpha = leafTexColor.a;
    #endif
    
    surfaceData.albedo = finalColor;
    surfaceData.occlusion = 1;
}

// Returns the wind offset in world space
float2 VertexOffsetWS(float3 positionOS, float3 positionWS) {
    float offset;

    // This is the basic offset for grass and flowers
    #if !defined(_OBJECTTYPE_TREE)
    offset = (WorldPositionOffset(positionWS) * 2 - 1) * _WindStrength * positionOS.y;
    #if defined(_OBJECTTYPE_LEAF)
    offset *= 0.1;
    #endif
    #endif

    // With trees and leaves we have to take into account the height of the tree
    #if defined(_OBJECTTYPE_TREE) || defined(_OBJECTTYPE_LEAF)
    float height;
    // Leaves have to be transformed into tree local space to compute height
    #if defined(_OBJECTTYPE_LEAF)
    height = mul(
    #if defined(INSTANCING_ON)
    UNITY_ACCESS_INSTANCED_PROP(Props, _TreeMatrix)
    #else
    _TreeMatrix
    #endif
    , float4(positionWS, 1)).y;
    #else
    height = positionOS.y;
    #endif
    height /= _TreeHeight;
    height *= height;
    // Move leaves along with the trunk
    offset
    #if defined(_OBJECTTYPE_LEAF)
    +=
    #else
    =
    #endif
    (WorldPositionOffset(positionWS) * 2 - 1) * _WindStrength * height;
    #endif

    return AngleToDir(_WindDirection) * offset;
}

Varyings Vertex(const Attributes input) {
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    float3 positionWS = TransformObjectToWorld(input.positionOS);
    float2 offsetWS = VertexOffsetWS(input.positionOS, positionWS);
    output.positionWS = float3(positionWS.x + offsetWS.x, positionWS.y, positionWS.z + offsetWS.y);
    output.positionHCS = TransformWorldToHClip(output.positionWS);
    output.uv = input.uv0;
    // Make leaves' normals point to tree space's up
    // Other assets were authored for this
    #if defined(_OBJECTTYPE_LEAF)
    output.normalWS = mul(
    #if defined(INSTANCING_ON)
    UNITY_ACCESS_INSTANCED_PROP(Props, _LeafMatrix)
    #else
    _LeafMatrix
    #endif
    , float4(0, 1, 0, 0));
    #else
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    #endif
    output.fogFactor = ComputeFogFactor(output.positionHCS.z);
    OUTPUT_LIGHTMAP_UV(input.uv1, unity_LightmapST, output.staticLightmapUV);
    #ifdef DYNAMICLIGHTMAP_ON
    output.dynamicLightmapUV = input.uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);
    return output;
}

// Basic PBR lit fragment
float4 Fragment(const Varyings input) : SV_Target {
    InputData inputData;
    InitializeInputData(input, inputData);
    
    SurfaceData surfaceData;
    InitializeSurfaceData(input.positionWS, input.uv, surfaceData);
    half4 color = UniversalFragmentPBR(inputData, surfaceData);
    color.rgb = MixFog(color.rgb, inputData.fogCoord);

    return color;
}

// Shadow caster
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

struct AttributesLean
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    #if defined(_OBJECTTYPE_LEAF)
    float2 texcoord     : TEXCOORD0;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VaryingsLean
{
    #if defined(_OBJECTTYPE_LEAF)
    float2 uv     : TEXCOORD0;
    #endif
    float4 positionCS   : SV_POSITION;
};

float3 _LightDirection;
float3 _LightPosition;

// Vertex offsets need to be calculated in shadow and depth passes for correct images
float4 GetShadowPositionHClip(const AttributesLean input) {
    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    const float2 offsetWS = VertexOffsetWS(input.positionOS.xyz, positionWS);
    positionWS = float3(positionWS.x + offsetWS.x, positionWS.y, positionWS.z + offsetWS.y);
    const float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

#if _CASTING_PUNCTUAL_LIGHT_SHADOW
    const float3 lightDirectionWS = normalize(_LightPosition - positionWS);
#else
    const float3 lightDirectionWS = _LightDirection;
#endif

    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

#if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#else
    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#endif

    return positionCS;
}

VaryingsLean ShadowPassVertex(const AttributesLean input) {
    VaryingsLean output;
    UNITY_SETUP_INSTANCE_ID(input);

    #if defined(_OBJECTTYPE_LEAF)
    output.uv = TRANSFORM_TEX(input.texcoord, _LeafTexture);
    #endif
    output.positionCS = GetShadowPositionHClip(input);
    return output;
}

half4 ShadowPassFragment(const VaryingsLean input) : SV_TARGET {
    #if defined(_OBJECTTYPE_LEAF)
    clip(SAMPLE_TEXTURE2D(_LeafTexture, sampler_LeafTexture, input.uv).a - 0.7);
    #endif
    return 0;
}

// Depth Only

VaryingsLean DepthOnlyVertex(const AttributesLean input)
{
    VaryingsLean output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    #if defined(_OBJECTTYPE_LEAF)
    output.uv = TRANSFORM_TEX(input.texcoord, _LeafTexture);
    #endif
    const float3 positionWS = TransformObjectToWorld(input.positionOS);
    const float2 offsetWS = VertexOffsetWS(input.positionOS, positionWS);
    output.positionCS = TransformWorldToHClip(float3(positionWS.x + offsetWS.x, positionWS.y, positionWS.z + offsetWS.y));
    return output;
}

half DepthOnlyFragment(VaryingsLean input) : SV_TARGET
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    #if defined(_OBJECTTYPE_LEAF)
    clip(SAMPLE_TEXTURE2D(_LeafTexture, sampler_LeafTexture, input.uv).a - 0.7);
    #endif

    return input.positionCS.z;
}