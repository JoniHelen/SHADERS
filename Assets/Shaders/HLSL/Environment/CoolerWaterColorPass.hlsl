#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

TEXTURE2D(_CollectedLight);
SAMPLER(sampler_CollectedLight);

TEXTURE2D(_UVRG);
SAMPLER(sampler_UVRG);

TEXTURE2D(_PositionWS);
SAMPLER(sampler_PositionWS);

TEXTURE2D(_PositionHCS);
SAMPLER(sampler_PositionHCS);

TEXTURE2D(_NormalWS);
SAMPLER(sampler_NormalWS);

TEXTURECUBE(_SkyColor);
SAMPLER(sampler_SkyColor);

CBUFFER_START(UnityPerMaterial)
float4 _Color;
float _Smoothness;
float _Depth;
float _Strength;
float _IOR;
float _FresnelBias;
float _Extinction;
CBUFFER_END

float DepthDifference(const float2 uv, const float clipDepth)
{
    const float depth = LinearEyeDepth(SampleSceneDepth(uv), _ZBufferParams);
    const float surface = clipDepth + _Depth;
    return (depth - surface) * _Strength * 0.1;
}

float DepthDifferenceRaw(const float2 uv, const float clipDepth)
{
    const float depth = LinearEyeDepth(SampleSceneDepth(uv), _ZBufferParams);
    const float surface = clipDepth;
    return depth - surface;
}

float FresnelApprox(const float3 V, const float3 N)
{
    const float r0 = pow(1.0 - _IOR, 2.0) / pow(1.0 + _IOR, 2.0);
    return r0 + (1.0 - r0) * pow(1.0 - dot(V, N), 5.0);
}

float3 SampleSkyColor(const float3 positionWS, const float3 normalWS)
{
    return SAMPLE_TEXTURECUBE(_SkyColor, sampler_SkyColor, reflect(positionWS - _WorldSpaceCameraPos, normalWS)).rgb * 0.5;
}

#define RAD_TO_DEG 57.2957795

// Alternate to fresnel approx
float GetWaterIncidentBlend(const float3 i, const float3 n) {
    return clamp(0.002 * exp(0.075 * RAD_TO_DEG * acos(dot(i, n))), 0, 1);
}

float LightAttenuation(float distance)
{
    return exp(-_Extinction * 0.01 * distance);
}

float4 Fragment(const BlitVaryings IN) : SV_Target {

    // Sample all of the textures for data
    const float4 positionWS = SAMPLE_TEXTURE2D(_PositionWS, sampler_PositionWS, IN.uv);
    const float4 positionHCS = SAMPLE_TEXTURE2D(_PositionHCS, sampler_PositionHCS, IN.uv);
    const float3 normalWS = SAMPLE_TEXTURE2D(_NormalWS, sampler_NormalWS, IN.uv).xyz;

    // Simple depth test
    if (saturate(DepthDifferenceRaw(IN.uv, positionHCS.w)) <= 0)
        return float4(SampleSceneColor(IN.uv), 1);

    // Populate input data
    InputData lightingInput = (InputData)0;
    lightingInput.positionWS = positionWS.xyz;
    lightingInput.positionCS = positionHCS;
    lightingInput.normalWS = normalWS;
    lightingInput.viewDirectionWS = GetWorldSpaceNormalizeViewDir(positionWS.xyz);

    // Compute water surface color
    const float4 UVRG = SAMPLE_TEXTURE2D(_UVRG, sampler_UVRG, IN.uv);
    
    float3 reflectedColor = SampleSceneColor(UVRG.zw);
    reflectedColor = SAMPLE_TEXTURE2D(_CollectedLight, sampler_CollectedLight, IN.uv).w < 1 ? SampleSkyColor(positionWS, normalWS) : reflectedColor;
    
    float3 refractedColor = SampleSceneColor(UVRG.xy);
    refractedColor = lerp(_Color.rgb, refractedColor, LightAttenuation(SAMPLE_TEXTURE2D(_CollectedLight, sampler_CollectedLight, IN.uv).z));
    /*refractedColor = 1 - (1 - refractedColor)
        * (1 - refractedColor * SAMPLE_TEXTURE2D(_CollectedLight, sampler_CollectedLight, UVRG.xy).xyz
            * (1 - clamp(DepthDifference(UVRG.xy, positionHCS.w), 0, 0.5)));*/
    
    float3 waterColor = lerp(refractedColor, reflectedColor, FresnelApprox(lightingInput.viewDirectionWS, normalWS) + _FresnelBias);

    // Populate surface data
    SurfaceData surfaceInput = (SurfaceData)0;
    surfaceInput.albedo = 0;
    surfaceInput.emission = waterColor;
    surfaceInput.alpha = 1;
    surfaceInput.smoothness = _Smoothness;
    
    return lerp(UniversalFragmentPBR(lightingInput, surfaceInput), float4(SampleSceneColor(IN.uv), 1), positionWS.w);
}